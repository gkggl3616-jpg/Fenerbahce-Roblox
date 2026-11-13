--[[
	DataService
	Oyuncu verisini DataStore'dan yükler ve kaydeder.
	- Oturum kilidi: aynı hesap iki sunucuda aynı anda açılamaz.
	- Her çağrı pcall içinde, hata olursa artan bekleme ile yeniden denenir.
	- Studio'da API erişimi kapalıysa bellekte çalışır (veri kalıcı olmaz).
	- Sıralama için OrderedDataStore'a genel güç yazılır.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}

local store, board
local memoryMode = false
local cache: { [number]: any } = {}

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = deepCopy(v)
	end
	return c
end

-- Yeni oyuncunun verisi
function DataService.Default()
	return {
		version = Config.Version,
		created = false,
		name = "",
		number = 9,
		position = "",
		level = 1,
		xp = 0,
		coins = Config.Economy.StartCoins,
		stats = { Hiz = 1, TopKontrolu = 1, Pas = 1, Sut = 1, Defans = 1, Fizik = 1 },
		skills = {}, -- skills[zincir] = açılan son yeteneğin sırası
		appearance = {
			height = 180,
			build = "Atletik",
			skin = 2,
			face = 1,
			hairStyle = 1,
			hairColor = "1B1410",
			beard = 0,
			bootModel = 1,
			bootColor = "101216",
			accessories = { UzunKol = false, Bileklik = false, SacBandi = false, KisaTozluk = false },
		},
		club = {
			name = "",
			abbr = "",
			crestShape = 1,
			kitPattern = "Cubuklu",
			tier = 1,
			funds = Config.Economy.StartClubFunds,
			facilities = { Cim = 0, TribunEki = 0, Aydinlatma = 0, Soyunma = 0, Antrenman = 0, Saglik = 0 },
			season = { number = 1, played = 0, points = 0, won = 0, drawn = 0, lost = 0 },
		},
		career = { goals = 0, matches = 0, wins = 0, headerGoals = 0, atFenerbahce = false },
		claimedRewards = {},
		session = nil,
	}
end

-- Eksik alanları varsayılanla tamamlar (yeni sürümde alan eklenince eski kayıt bozulmaz)
local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" then
			reconcile(data[k], v)
		end
	end
	return data
end

local function retry(fn)
	local lastErr
	for attempt = 1, Config.Data.Retries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(0.5 * 2 ^ (attempt - 1))
	end
	return false, lastErr
end

function DataService.Init()
	local ok = pcall(function()
		store = DataStoreService:GetDataStore(Config.DataStoreName)
		board = DataStoreService:GetOrderedDataStore(Config.LeaderboardName)
		-- Erişim sınaması: Studio'da API kapalıysa burada hata verir
		store:GetAsync("__ping")
	end)
	if not ok then
		memoryMode = true
		warn("[DataService] DataStore erişimi yok, bellekte çalışılıyor. Veri kalıcı olmayacak.")
	end
end

-- Yükler ve oturum kilidini alır. Başarısızsa nil döner.
function DataService.Load(player: Player)
	local userId = player.UserId
	if memoryMode then
		cache[userId] = cache[userId] or DataService.Default()
		return cache[userId]
	end
	local locked = false
	local ok, result = retry(function()
		return store:UpdateAsync("p_" .. userId, function(old)
			local data = old or DataService.Default()
			local s = data.session
			if s and s.jobId ~= game.JobId and os.time() - (s.t or 0) < Config.Data.LockTimeout then
				locked = true
				return nil -- başka sunucuda açık, dokunma
			end
			locked = false
			data.session = { jobId = game.JobId, t = os.time() }
			return data
		end)
	end)
	if not ok or locked or not result then
		return nil
	end
	local data = reconcile(result, DataService.Default())
	cache[userId] = data
	return data
end

function DataService.Get(player: Player)
	return cache[player.UserId]
end

function DataService.Save(player: Player, release: boolean?)
	local userId = player.UserId
	local data = cache[userId]
	if not data or memoryMode then
		if release then
			-- bellek modunda veriyi oturum boyunca tut
			return true
		end
		return data ~= nil
	end
	local ok = retry(function()
		return store:UpdateAsync("p_" .. userId, function(old)
			if old and old.session and old.session.jobId ~= game.JobId then
				return nil -- kilit bizde değil, üzerine yazma
			end
			local copy = deepCopy(data)
			copy.session = if release then nil else { jobId = game.JobId, t = os.time() }
			return copy
		end)
	end)
	if ok and data.created then
		pcall(function()
			board:SetAsync(tostring(userId), Config.Power(data.stats, data.level))
		end)
	end
	if release then
		cache[userId] = nil
	end
	return ok
end

-- İlk N oyuncu: { {userId, power}, ... }
-- Kayıt bellekte mi tutuluyor? (Studio'da ya da veri deposu erişimi yokken)
function DataService.IsMemory(): boolean
	return memoryMode
end

function DataService.Top(count: number)
	if memoryMode then
		return {}
	end
	local ok, pages = pcall(function()
		return board:GetSortedAsync(false, math.clamp(count, 1, 100))
	end)
	if not ok then
		return {}
	end
	local out = {}
	for _, entry in ipairs(pages:GetCurrentPage()) do
		table.insert(out, { userId = tonumber(entry.key), power = entry.value })
	end
	return out
end

function DataService.StartAutoSave()
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutoSave)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(DataService.Save, player, false)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				DataService.Save(player, true)
				pending -= 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService

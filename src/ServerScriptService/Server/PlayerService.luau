--[[
	PlayerService
	İstemciden gelen bütün istekleri doğrular ve veriyi yalnızca sunucuda değiştirir.
	- Kariyer oluşturma: isim filtresi, mevki kilidi, görünüm aralık kontrolü
	- Özellik yükseltme, yetenek açma (sıralı kilit), tesis geliştirme
	- İstek sıklığı sınırı
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local PlayerService = {}

local lastCall: { [number]: { [string]: number } } = {}

local function allowed(player: Player, key: string): boolean
	local now = os.clock()
	local t = lastCall[player.UserId]
	if not t then
		t = {}
		lastCall[player.UserId] = t
	end
	if t[key] and now - t[key] < Config.Remote.MinInterval then
		return false
	end
	t[key] = now
	return true
end

local function isInt(v, min: number, max: number): boolean
	return type(v) == "number" and v == math.floor(v) and v >= min and v <= max
end

local function isText(v, min: number, max: number): boolean
	return type(v) == "string" and utf8.len(v) ~= nil and utf8.len(v) >= min and utf8.len(v) <= max
end

local function inList(v, list): boolean
	return type(v) == "string" and table.find(list, v) ~= nil
end

local function isHex(v): boolean
	return type(v) == "string" and string.match(v, "^%x%x%x%x%x%x$") ~= nil
end

local function filter(text: string, userId: number): string?
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, userId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok or string.find(result, "#", 1, true) then
		return nil
	end
	return result
end

-- İstemciye gidecek kopya (oturum bilgisi gönderilmez)
local function publicData(data)
	local copy = table.clone(data)
	copy.session = nil
	copy.power = Config.Power(data.stats, data.level)
	return copy
end

local function push(player: Player)
	local data = DataService.Get(player)
	if data then
		Remotes.Get("DataChanged"):FireClient(player, publicData(data))
	end
end

local function notify(player: Player, kind: string, text: string)
	Remotes.Get("Notify"):FireClient(player, kind, text)
end

-- XP ekler, seviye atlatır. Başka servisler de (maç, antrenman) bunu kullanır.
function PlayerService.AddXp(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	data.xp += amount
	while data.level < Config.MaxLevel and data.xp >= Config.XpForLevel(data.level) do
		data.xp -= Config.XpForLevel(data.level)
		data.level += 1
		notify(player, "level", "Seviye " .. data.level)
	end
	push(player)
end

function PlayerService.AddCoins(player: Player, amount: number)
	local data = DataService.Get(player)
	if data and amount > 0 then
		data.coins += math.floor(amount)
		push(player)
	end
end

local function onCreateCareer(player: Player, p)
	local data = DataService.Get(player)
	if not data or not allowed(player, "create") then
		return
	end
	if data.created then
		return notify(player, "error", "Kariyerin zaten var. İsim ve mevki değiştirilemez.")
	end
	if type(p) ~= "table" then
		return
	end
	local A = Config.Appearance
	local a = p.appearance
	local valid = isText(p.name, Config.Name.Min, Config.Name.Max)
		and inList(p.position, Config.Positions)
		and isInt(p.number, 1, 99)
		and isText(p.clubName, Config.ClubName.Min, Config.ClubName.Max)
		and type(p.clubAbbr) == "string"
		and string.match(p.clubAbbr, "^%u%u%u?$") ~= nil
		and isInt(p.crestShape, 1, A.CrestShapes)
		and inList(p.kitPattern, A.KitPatterns)
		and type(a) == "table"
		and isInt(a.height, A.HeightMin, A.HeightMax)
		and inList(a.build, A.Builds)
		and isInt(a.skin, 1, A.SkinTones)
		and isInt(a.face, 1, A.Faces)
		and isInt(a.hairStyle, 1, A.HairStyles)
		and isHex(a.hairColor)
		and isInt(a.beard, 0, A.Beards)
		and isInt(a.bootModel, 1, A.BootModels)
		and isHex(a.bootColor)
	if not valid then
		return notify(player, "error", "Bilgilerde hata var. Lütfen kontrol et.")
	end
	local name = filter(p.name, player.UserId)
	local clubName = filter(p.clubName, player.UserId)
	if not name or not clubName then
		return notify(player, "error", "Bu isim kullanılamıyor. Başka bir isim dene.")
	end
	data.name = name
	data.number = p.number
	data.position = p.position -- KİLİT: bundan sonra hiçbir istek bunu değiştirmez
	data.stats = table.clone(Config.StartStats[p.position])
	data.appearance = {
		height = a.height,
		build = a.build,
		skin = a.skin,
		face = a.face,
		hairStyle = a.hairStyle,
		hairColor = a.hairColor,
		beard = a.beard,
		bootModel = a.bootModel,
		bootColor = a.bootColor,
		accessories = {},
	}
	data.club.name = clubName
	data.club.abbr = p.clubAbbr
	data.club.crestShape = p.crestShape
	data.club.kitPattern = p.kitPattern
	-- Her zincirin ilk ücretsiz yeteneği açık başlar
	for chainId, chain in pairs(Config.SkillChains) do
		if not chain.OnlyPosition or chain.OnlyPosition == p.position then
			local first = chain.Skills[1]
			data.skills[chainId] = if first.Cost == 0 and first.Level <= 1 then 1 else 0
		end
	end
	data.created = true
	push(player)
	notify(player, "success", "Hoş geldin " .. name .. ". Kariyerin başladı.")
	task.spawn(DataService.Save, player, false)
end

local function onUpgradeStat(player: Player, stat)
	local data = DataService.Get(player)
	if not data or not data.created or not allowed(player, "stat") then
		return
	end
	if not inList(stat, Config.Stats) then
		return
	end
	local level = data.stats[stat]
	if level >= Config.StatMax then
		return notify(player, "error", Config.StatNames[stat] .. " en üst seviyede.")
	end
	local cost = Config.StatCost(level)
	if data.coins < cost then
		return notify(player, "error", "Bakiye yetersiz. Gereken: " .. cost)
	end
	data.coins -= cost
	data.stats[stat] = level + 1
	push(player)
	notify(player, "success", Config.StatNames[stat] .. " " .. (level + 1) .. " oldu.")
end

local function onUnlockSkill(player: Player, chainId)
	local data = DataService.Get(player)
	if not data or not data.created or not allowed(player, "skill") then
		return
	end
	local chain = type(chainId) == "string" and Config.SkillChains[chainId]
	if not chain then
		return
	end
	if chain.OnlyPosition and chain.OnlyPosition ~= data.position then
		return notify(player, "error", "Bu zincir senin mevkine ait değil.")
	end
	-- Sıralı kilit: yalnızca sıradaki yetenek açılabilir
	local nextIndex = (data.skills[chainId] or 0) + 1
	local skill = chain.Skills[nextIndex]
	if not skill then
		return notify(player, "error", "Bu zincirdeki bütün yetenekler açık.")
	end
	if data.level < skill.Level then
		return notify(player, "error", skill.Name .. " için seviye " .. skill.Level .. " gerekli.")
	end
	if data.coins < skill.Cost then
		return notify(player, "error", "Bakiye yetersiz. Gereken: " .. skill.Cost)
	end
	data.coins -= skill.Cost
	data.skills[chainId] = nextIndex
	push(player)
	notify(player, "unlock", skill.Name .. " açıldı")
end

local function onUpgradeFacility(player: Player, id)
	local data = DataService.Get(player)
	if not data or not data.created or not allowed(player, "facility") then
		return
	end
	local f = type(id) == "string" and Config.Facilities[id]
	if not f then
		return
	end
	local level = data.club.facilities[id] or 0
	if level >= f.Max then
		return notify(player, "error", f.Name .. " en üst seviyede.")
	end
	local cost = f.Cost[level + 1]
	if data.club.funds < cost then
		return notify(player, "error", "Kulüp kasası yetersiz. Gereken: " .. cost)
	end
	data.club.funds -= cost
	data.club.facilities[id] = level + 1
	push(player)
	notify(player, "success", f.Name .. " geliştirildi.")
end

function PlayerService.Init()
	Remotes.Get("CreateCareer").OnServerEvent:Connect(onCreateCareer)
	Remotes.Get("UpgradeStat").OnServerEvent:Connect(onUpgradeStat)
	Remotes.Get("UnlockSkill").OnServerEvent:Connect(onUnlockSkill)
	Remotes.Get("UpgradeFacility").OnServerEvent:Connect(onUpgradeFacility)
	Remotes.Get("GetData").OnServerInvoke = function(player)
		local t0 = os.clock()
		while not DataService.Get(player) and os.clock() - t0 < 10 do
			task.wait(0.1)
		end
		local data = DataService.Get(player)
		return data and publicData(data) or nil
	end

	local function onJoin(player: Player)
		local data = DataService.Load(player)
		if not data then
			player:Kick("Verin yüklenemedi ya da başka bir sunucuda açık. Biraz sonra tekrar dene.")
			return
		end
		push(player)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onJoin, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player.UserId] = nil
		DataService.Save(player, true)
	end)
end

return PlayerService

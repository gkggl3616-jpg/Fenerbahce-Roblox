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
local CharacterService = require(script.Parent.CharacterService)

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

-- Görünüm tablosunu doğrular ve temiz bir kopya döndürür (geçersizse nil)
local function cleanAppearance(a)
	local A = Config.Appearance
	local valid = type(a) == "table"
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
		return nil
	end
	local acc = {}
	if type(a.accessories) == "table" then
		for _, key in ipairs(Config.Accessories) do
			acc[key] = a.accessories[key] == true
		end
	end
	return {
		height = a.height,
		build = a.build,
		skin = a.skin,
		face = a.face,
		hairStyle = a.hairStyle,
		hairColor = a.hairColor,
		beard = a.beard,
		bootModel = a.bootModel,
		bootColor = a.bootColor,
		accessories = acc,
	}
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
	local appearance = cleanAppearance(p.appearance)
	local valid = appearance ~= nil
		and isText(p.name, Config.Name.Min, Config.Name.Max)
		and inList(p.position, Config.Positions)
		and isInt(p.number, 1, 99)
		and isText(p.clubName, Config.ClubName.Min, Config.ClubName.Max)
		and type(p.clubAbbr) == "string"
		and string.match(p.clubAbbr, "^%u%u%u?$") ~= nil
		and isInt(p.crestShape, 1, A.CrestShapes)
		and inList(p.kitPattern, A.KitPatterns)
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
	data.appearance = appearance
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
	CharacterService.Apply(player, CharacterService.LookFromData(data))
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = 16
	end
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

-- Karakter oluşturma ekranında canlı önizleme. Hiçbir şey kaydedilmez; isim gösterilmez.
local function onPreview(player: Player, p)
	local data = DataService.Get(player)
	if not data or data.created or not allowed(player, "preview") or type(p) ~= "table" then
		return
	end
	local appearance = cleanAppearance(p.appearance)
	if
		not appearance
		or not inList(p.position, Config.Positions)
		or not inList(p.kitPattern, Config.Appearance.KitPatterns)
		or not isInt(p.number, 1, 99)
	then
		return
	end
	local abbr = if type(p.clubAbbr) == "string" and string.match(p.clubAbbr, "^%u%u%u?$") then p.clubAbbr else "FK"
	CharacterService.Apply(
		player,
		{ appearance = appearance, position = p.position, kitPattern = p.kitPattern, number = p.number, name = "", abbr = abbr, level = 1 }
	)
end

-- Animasyon aktarımı: bir oyuncunun eylemi aynı sunucudaki diğer oyunculara bildirilir (onlar da görsün)
local function onAnim(player: Player, action, mirror)
	if type(action) ~= "string" or #action > 24 or not allowed(player, "anim") then
		return
	end
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			Remotes.Get("Anim"):FireClient(other, player.UserId, action, mirror == true)
		end
	end
end

-- Deneme sahasında atılan gol: küçük ödül. Bekleme süresi sunucuda tutulur.
local lastTrainingGoal: { [number]: number } = {}
local function onTrainingGoal(player: Player, kind)
	local data = DataService.Get(player)
	local R = Config.TestPitch.Reward
	if not data or not data.created then
		return
	end
	local now = os.clock()
	if now - (lastTrainingGoal[player.UserId] or 0) < R.Cooldown then
		return
	end
	lastTrainingGoal[player.UserId] = now
	local bonus = if kind == "Header" or kind == "UcanKafa" or kind == "Rovesata" or kind == "Vole" then R.HeaderBonus else 0
	if kind == "Feint" or kind == "Tackle" then
		-- çalım ve top kapma: gol ödülünün yarısı
		data.coins += math.floor(R.Coins / 2)
		PlayerService.AddXp(player, math.floor(R.Xp / 2))
		return
	end
	data.coins += R.Coins + bonus
	PlayerService.AddXp(player, R.Xp + bonus)
end

function PlayerService.Init()
	Remotes.Get("Anim").OnServerEvent:Connect(onAnim)
	Remotes.Get("TrainingGoal").OnServerEvent:Connect(onTrainingGoal)
	Remotes.Get("PreviewAppearance").OnServerEvent:Connect(onPreview)
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
		local function onCharacter(character: Model)
			local hum = character:WaitForChild("Humanoid", 10)
			if not hum then
				return
			end
			if not character:IsDescendantOf(workspace) then
				character.AncestryChanged:Wait()
			end
			task.wait(0.2)
			local d = DataService.Get(player)
			if not d then
				return
			end
			if d.created then
				CharacterService.Apply(player, CharacterService.LookFromData(d))
			else
				(hum :: Humanoid).WalkSpeed = 0 -- oluşturma ekranında yerinde dursun
				local look = CharacterService.LookFromData(d)
				look.position = "Forvet"
				look.name = ""
				look.abbr = "FK"
				CharacterService.Apply(player, look)
			end
		end
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onJoin, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player.UserId] = nil
		lastTrainingGoal[player.UserId] = nil
		DataService.Save(player, true)
	end)
end

return PlayerService

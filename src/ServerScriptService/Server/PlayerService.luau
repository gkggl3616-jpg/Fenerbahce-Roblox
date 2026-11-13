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
local Crest = require(ReplicatedStorage.Shared.Crest)
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

-- aşağıda tanımlanır (günlük görevler ve mağaza)
local wardrobe: (any) -> ()
local daily: (any, number) -> any

-- İstemciye gidecek kopya (oturum bilgisi gönderilmez)
local function publicData(data, userId: number?)
	local copy = table.clone(data)
	copy.session = nil
	if data.created then
		wardrobe(data)
		copy.owned, copy.equipped = data.owned, data.equipped
		if userId then
			copy.daily = daily(data, userId)
		end
	end
	copy.power = Config.Power(data.stats, data.level)
	return copy
end

local function push(player: Player)
	local data = DataService.Get(player)
	if data then
		Remotes.Get("DataChanged"):FireClient(player, publicData(data, player.UserId))
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
	local nextIndex = Config.SkillLevel(data.skills, chainId) + 1
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

--------------------------------------------------------------------------------
-- Günlük görevler
--------------------------------------------------------------------------------
-- Gün değiştiyse üç yeni görev seçer (oyuncuya ve güne göre hep aynı üçlü)
daily = function(data, userId: number)
	local day = math.floor(os.time() / 86400)
	if type(data.daily) ~= "table" or data.daily.day ~= day then
		local pool = table.clone(Config.DailyTasks)
		local seed = (day * 31 + userId) % 2147483647
		local tasks = {}
		for _ = 1, math.min(Config.DailyCount, #pool) do
			seed = (seed * 16807 + 11) % 2147483647
			local pick = table.remove(pool, 1 + seed % #pool)
			table.insert(tasks, { id = pick.Id, progress = 0, claimed = false })
		end
		data.daily = { day = day, tasks = tasks }
	end
	return data.daily
end

local function taskDef(id: string)
	for _, t in ipairs(Config.DailyTasks) do
		if t.Id == id then
			return t
		end
	end
	return nil
end

-- Bir sayaç ilerler (gol, maç, galibiyet, kafa golü, antrenman)
local function progress(player: Player, stat: string, amount: number)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	for _, t in ipairs(daily(data, player.UserId).tasks) do
		local def = taskDef(t.id)
		if def and def.Stat == stat and not t.claimed then
			t.progress = math.min(def.Goal, t.progress + amount)
		end
	end
end

local function onClaimDaily(player: Player, index)
	local data = DataService.Get(player)
	if not data or not data.created or not allowed(player, "daily") or not isInt(index, 1, Config.DailyCount) then
		return
	end
	local t = daily(data, player.UserId).tasks[index]
	local def = t and taskDef(t.id)
	if not t or not def then
		return
	end
	if t.claimed then
		return notify(player, "error", "Bu ödülü zaten aldın.")
	end
	if t.progress < def.Goal then
		return notify(player, "error", "Görev henüz tamamlanmadı.")
	end
	t.claimed = true
	data.coins += def.Coins
	PlayerService.AddXp(player, def.Xp)
	notify(player, "unlock", "Görev ödülü: +" .. def.Coins .. " bakiye, +" .. def.Xp .. " XP")
end

--------------------------------------------------------------------------------
-- Mağaza: görünüm eşyaları
--------------------------------------------------------------------------------
wardrobe = function(data)
	if type(data.owned) ~= "table" then
		data.owned = {}
	end
	if type(data.equipped) ~= "table" then
		data.equipped = {}
	end
	for kind, id in pairs(Config.ShopDefaults) do
		data.owned[id] = true
		data.equipped[kind] = data.equipped[kind] or id
	end
end

local function onBuyItem(player: Player, id)
	local data = DataService.Get(player)
	if not data or not data.created or not allowed(player, "shop") then
		return
	end
	local item = type(id) == "string" and Config.ShopItem(id)
	if not item then
		return
	end
	wardrobe(data)
	if data.owned[item.Id] then
		return notify(player, "error", item.Name .. " zaten sende.")
	end
	if data.level < item.Level then
		return notify(player, "error", item.Name .. " için seviye " .. item.Level .. " gerekli.")
	end
	if data.coins < item.Price then
		return notify(player, "error", "Bakiye yetersiz. Gereken: " .. item.Price)
	end
	data.coins -= item.Price
	data.owned[item.Id] = true
	data.equipped[item.Kind] = item.Id
	push(player)
	notify(player, "unlock", item.Name .. " alındı ve kuşanıldı")
end

local function onEquipItem(player: Player, id)
	local data = DataService.Get(player)
	if not data or not data.created or not allowed(player, "equip") then
		return
	end
	local item = type(id) == "string" and Config.ShopItem(id)
	if not item then
		return
	end
	wardrobe(data)
	if not data.owned[item.Id] then
		return notify(player, "error", "Önce satın almalısın.")
	end
	data.equipped[item.Kind] = item.Id
	push(player)
end

-- Fenerbahçe teklifini kabul et: forma ve stat değişir (geri dönüşü yok)
local function onAcceptOffer(player: Player)
	local data = DataService.Get(player)
	if not data or not data.created or not allowed(player, "offer") then
		return
	end
	if data.career.atFenerbahce or data.career.offer ~= true then
		return notify(player, "error", "Açık bir teklif yok.")
	end
	data.career.atFenerbahce = true
	data.career.offer = nil
	push(player)
	CharacterService.Apply(player, CharacterService.LookFromData(data))
	notify(player, "level", "Fenerbahçe'ye hoş geldin!")
end

-- Kulüp arması tasarımı
local function onSetCrest(player: Player, spec)
	local data = DataService.Get(player)
	if not data or not data.created or not allowed(player, "crest") then
		return
	end
	local clean = Crest.Clean(spec)
	if not clean then
		return notify(player, "error", "Arma kaydedilemedi: iki farklı renk seç.")
	end
	data.club.crest = clean
	data.club.crestShape = clean.shape
	push(player)
	CharacterService.Apply(player, CharacterService.LookFromData(data))
	notify(player, "success", "Kulüp arması kaydedildi.")
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
	progress(player, "training", 1)
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

-- MAÇ: istemci maçı oynatır, sunucu sonucu makullük sınamasından geçirip ödülü verir
local matchStart: { [number]: number } = {}
local function onMatchStart(player: Player)
	local data = DataService.Get(player)
	if data and data.created and allowed(player, "matchStart") then
		matchStart[player.UserId] = os.clock()
	end
end

local function onMatchEnd(player: Player, r)
	local data = DataService.Get(player)
	local MC = Config.Match
	local started = matchStart[player.UserId]
	matchStart[player.UserId] = nil
	if not data or not data.created or not started or type(r) ~= "table" then
		return
	end
	local valid = isInt(r.home, 0, MC.MaxGoals)
		and isInt(r.away, 0, MC.MaxGoals)
		and isInt(r.myGoals, 0, MC.MaxGoals)
		and isInt(r.myHeaderGoals, 0, MC.MaxGoals)
		and r.myGoals <= r.home
		and r.myHeaderGoals <= r.myGoals
	-- maç en az iki devrenin %80'i kadar sürmüş olmalı; yarıda bırakılan maç ödül vermez
	local long = os.clock() - started >= MC.HalfSeconds * 2 * 0.8
	if not valid or not long or r.forfeit == true then
		Remotes.Get("MatchResult"):FireClient(player, { ok = false })
		return
	end
	local outcome = if r.home > r.away then "Win" elseif r.home == r.away then "Draw" else "Loss"
	local tier = Config.Tiers[data.club.tier]
	local coins = MC.Reward[outcome] + (r.myGoals - r.myHeaderGoals) * MC.Reward.Goal + r.myHeaderGoals * MC.Reward.HeaderGoal
	local xp = MC.Reward.Xp[outcome] + r.myGoals * MC.Reward.Xp.Goal
	data.coins += coins
	data.club.funds += tier.MatchIncome
	data.career.matches += 1
	data.career.goals += r.myGoals
	data.career.headerGoals += r.myHeaderGoals
	if outcome == "Win" then
		data.career.wins += 1
	end
	progress(player, "matches", 1)
	progress(player, "goals", r.myGoals)
	progress(player, "headers", r.myHeaderGoals)
	progress(player, "wins", if outcome == "Win" then 1 else 0)
	local season = data.club.season
	season.played += 1
	season.points += MC.Points[outcome]
	local promoted, seasonOver = false, false
	if season.played >= Config.Season.Matches then
		seasonOver = true
		if season.points >= MC.PromotePoints and data.club.tier < 5 then
			data.club.tier += 1
			promoted = true
		end
		season.number += 1
		season.played = 0
		season.points = 0
	end
	-- Fenerbahçe teklifi: seviye ve güç yeterliyse (bir kez gelir, kabul edilene kadar açık kalır)
	local O = Config.FenerbahceOffer
	if not data.career.atFenerbahce and data.level >= O.Level and Config.Power(data.stats, data.level) >= O.Power then
		data.career.offer = true
	end
	PlayerService.AddXp(player, xp) -- veriyi de istemciye yollar
	Remotes.Get("MatchResult"):FireClient(player, {
		ok = true,
		outcome = outcome,
		coins = coins,
		xp = xp,
		income = tier.MatchIncome,
		played = season.played,
		points = season.points,
		seasonOver = seasonOver,
		promoted = promoted,
		tier = data.club.tier,
		offer = data.career.offer == true and not data.career.atFenerbahce,
	})
	task.spawn(DataService.Save, player, false)
end

function PlayerService.Init()
	Remotes.Get("MatchStart").OnServerEvent:Connect(onMatchStart)
	Remotes.Get("MatchEnd").OnServerEvent:Connect(onMatchEnd)
	Remotes.Get("Anim").OnServerEvent:Connect(onAnim)
	Remotes.Get("TrainingGoal").OnServerEvent:Connect(onTrainingGoal)
	Remotes.Get("PreviewAppearance").OnServerEvent:Connect(onPreview)
	Remotes.Get("CreateCareer").OnServerEvent:Connect(onCreateCareer)
	Remotes.Get("UpgradeStat").OnServerEvent:Connect(onUpgradeStat)
	Remotes.Get("UnlockSkill").OnServerEvent:Connect(onUnlockSkill)
	Remotes.Get("UpgradeFacility").OnServerEvent:Connect(onUpgradeFacility)
	Remotes.Get("SetCrest").OnServerEvent:Connect(onSetCrest)
	Remotes.Get("ClaimDaily").OnServerEvent:Connect(onClaimDaily)
	Remotes.Get("AcceptOffer").OnServerEvent:Connect(onAcceptOffer)
	Remotes.Get("BuyItem").OnServerEvent:Connect(onBuyItem)
	Remotes.Get("EquipItem").OnServerEvent:Connect(onEquipItem)
	-- Dünya sıralaması: genel güce göre ilk 50. Kayıt bellekteyse (Studio) liste boş gelir.
	local boardCache, boardAt = nil, 0
	Remotes.Get("GetLeaderboard").OnServerInvoke = function(player)
		local data = DataService.Get(player)
		if not boardCache or os.clock() - boardAt > 60 then
			local rows = {}
			for rank, entry in ipairs(DataService.Top(50)) do
				local ok, name = pcall(function()
					return Players:GetNameFromUserIdAsync(entry.userId)
				end)
				table.insert(rows, { rank = rank, name = if ok then name else "Oyuncu", power = entry.power, userId = entry.userId })
			end
			boardCache, boardAt = rows, os.clock()
		end
		return {
			rows = boardCache,
			offline = DataService.IsMemory(),
			me = {
				name = if data then data.name else "",
				power = if data then Config.Power(data.stats, data.level) else 0,
				userId = player.UserId,
			},
		}
	end
	Remotes.Get("GetData").OnServerInvoke = function(player)
		local t0 = os.clock()
		while not DataService.Get(player) and os.clock() - t0 < 10 do
			task.wait(0.1)
		end
		local data = DataService.Get(player)
		return data and publicData(data, player.UserId) or nil
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
		matchStart[player.UserId] = nil
		DataService.Save(player, true)
	end)
end

return PlayerService

--[[
	MatchAI
	11'e 11 maçtaki 21 botun yapay zekası (oyuncu dışındaki herkes). İstemcide çalışır.
	Her bot bir rol oynar:
	- Dizilişteki yerini korur; top ilerledikçe takım birlikte kayar.
	- Topa en yakın oyuncu topa gider (pres / top kapma).
	- Topa sahip olan oyuncu sürer, baskı altındaysa pas verir, menzildeyse şut çeker.
	- Kaleci çizgide topu izler, şutta plonjon yapar, tuttuğu topu oyuna sokar.
	Rakip savunmacı oyuncuya müdahale etmeden önce kırmızı halkayla haber verir (çalım penceresi).
	Beceri (0-1) kademeden gelir: hız, pas ve şut isabeti, top kapma ve kaleci hatası buna bağlıdır.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Animator = require(script.Parent.Parent.Anim.Animator)
local Crest = require(ReplicatedStorage.Shared.Crest)
local Ball = require(script.Parent.Ball)

local P = Config.MatchPitch
local MC = Config.Match
local D = Config.Duel
local K = Config.Keeper
local B = Config.Ball
local C = Config.Colors

local MatchAI = {}

local bots: { any } = {}
local clock = 0
local frozenUntil = 0
local skill = { home = 0.4, away = 0.4 }
local humanSlot = 11
local humanKeeper = false
-- Topu hedefe gönderen yardımcı; aşağıda tanımlanır, yukarıdaki işlevler de kullanır
local kickTo: (Vector3, number, string, string, number?) -> ()

-- Takım emri (kaptanın verdiği): "Dengeli" | "Atak" | "Defans" | "Pres"; strength 0-1 (kaptansa 1)
local order = { name = "Dengeli", strength = 1 }
local lastCarrier: any = nil
local listeners = { steal = {}, save = {}, shot = {}, telegraph = {}, foul = {}, offside = {} }
-- Oyuncu başına maç istatistiği (maç sonu puanları için)
local function newStats()
	return { goals = 0, assists = 0, shots = 0, passes = 0, tackles = 0, saves = 0, fouls = 0 }
end
local humanSt = newStats()
local humanInfo: any = nil
local gone: { any } = {} -- sahadan çıkanlar (değişiklik, kırmızı kart): { team, info, st }
local pendingKicker: any = nil -- vuruşu yapan bot (vuruş olayından hemen önce yazılır)
local lastKicker: { [string]: any } = {} -- takım -> son vuran (bot ya da "human")
local prevKicker: { [string]: any } = {} -- takım -> ondan önce vuran (asist)
local offsideSnap: any = nil -- son pas anında ofsayt konumunda olanlar
local offsideGraceUntil = 0 -- duran toplardan sonra ofsayt aranmayan süre
local offLine = { home = math.huge, away = math.huge } -- takımın geçmemesi gereken çizgi (hücum yönünde)
local lastCtx: any = nil
local minuteNow = 0
local plans: { [any]: any } = {} -- kaleci -> kurtarış planı
local stats = { shots = { home = 0, away = 0 }, possession = { home = 0, away = 0 } }

local function fire(name: string, ...)
	for _, fn in ipairs(listeners[name]) do
		task.spawn(fn, ...)
	end
end
function MatchAI.On(name: string, fn)
	table.insert(listeners[name], fn)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end
local MID_Z = (P.MinZ + P.MaxZ) / 2
local LEN = P.MaxZ - P.MinZ

-- Takımın hücum yönü: home +Z, away -Z
local function dirOf(team: string): number
	return if team == "home" then 1 else -1
end
local function goalOf(team: string): Vector3 -- takımın gol atacağı kale
	return Vector3.new(0, 0, if team == "home" then P.GoalZ else P.GoalZBack)
end

local function slotPos(team: string, slot: number): Vector3
	local f = Config.Formation[slot]
	local d = dirOf(team)
	local z = if team == "home" then P.MinZ + f[2] * LEN else P.MaxZ - f[2] * LEN
	return Vector3.new(f[1] * 92 * d, P.GroundY, z)
end

local NUMBERS = { 1, 2, 4, 5, 3, 7, 6, 8, 11, 9, 10 }

local function spawn(kind: string, team: string, slot: number, info: any?, club: any?)
	local folder = ReplicatedStorage:WaitForChild("FK_BotTemplates", 30)
	local tpl = folder and folder:FindFirstChild(kind)
	if not tpl then
		warn("[MatchAI] şablon yok: " .. kind)
		return
	end
	local model = tpl:Clone()
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = model:FindFirstChildOfClass("Humanoid")
	hrp.Anchored = true
	local offsetY = 3
	if hum then
		offsetY = hum.HipHeight + hrp.Size.Y / 2
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		pcall(function()
			hum.EvaluateStateMachine = false
		end)
	end
	-- forma numarasını dizilişe göre yaz
	local number = tostring(if info then info.number else NUMBERS[slot])
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
		elseif d:IsA("TextLabel") and tonumber(d.Text) then
			d.Text = number
		end
	end
	-- rakip kulübün renkleri (kaleci kendi formasında kalır). Gövde parçaları görevlerine göre
	-- etiketlidir: forma ve kol ana renk, şort ve şeritler ikinci renk, çorap ana renk.
	if club and team == "away" and slot ~= 1 then
		local byRole = { Shirt = club.A, Sleeve = club.A, Shorts = club.B, Sock = club.A, Trim = club.B, Stripe = club.B }
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				local c = byRole[d:GetAttribute("FK") or ""]
				if c then
					d.Color = c
				end
			elseif d:IsA("Frame") and d.Name == "Stripe" then
				d.BackgroundColor3 = club.B
			end
		end
	end
	if club then
		local spec, abbr = Crest.FromClub(club)
		for _, dsc in ipairs(model:GetDescendants()) do
			if dsc.Name == "FK_Crest" then
				for _, child in ipairs(dsc:GetChildren()) do
					child:Destroy()
				end
				Crest.Fill(dsc, spec, abbr)
			end
		end
	end
	model.Parent = Workspace
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = C.Bad
	ring.Transparency = 1
	ring.Size = Vector3.new(0.06, 6, 6)
	ring.Parent = model
	local home = slotPos(team, slot)
	local bot = {
		team = team,
		slot = slot,
		-- kadro verilmediyse (deneme) sade bir kimlik kullanılır
		info = info or {
			name = (if team == "home" then "Takım " else "Rakip ") .. tostring(NUMBERS[slot]),
			number = NUMBERS[slot],
			role = "",
			rating = 50,
		},
		pace = if info then info.pace or 1 else 1,
		keeper = slot == 1,
		model = model,
		hrp = hrp,
		animator = Animator.new(model),
		pos = home,
		home = home,
		dir = Vector3.new(0, 0, dirOf(team)),
		speed = 0,
		offsetY = offsetY,
		state = "play",
		t = 0,
		cd = 0,
		touch = 0,
		decideAt = 0,
		st = newStats(),
		freshAt = 0,
		ring = ring,
		receiveUntil = 0,
	}
	table.insert(bots, bot)
end

local function place(bot)
	local base = bot.pos + Vector3.new(0, bot.offsetY, 0)
	bot.hrp.CFrame = CFrame.lookAt(base, base + bot.dir)
	bot.ring.CFrame = CFrame.new(bot.pos + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

local function moveTo(bot, target: Vector3, speed: number, dt: number, faceTo: Vector3?)
	local to = flat(target - bot.pos)
	local dist = to.Magnitude
	local want = if dist > 0.5 then math.min(speed, dist / math.max(dt, 0.001)) else 0
	bot.speed += (want - bot.speed) * math.min(1, dt * 7)
	if dist > 0.05 then
		bot.pos += to.Unit * bot.speed * dt
	end
	bot.pos = Vector3.new(math.clamp(bot.pos.X, P.MinX - 4, P.MaxX + 4), P.GroundY, math.clamp(bot.pos.Z, P.MinZ - 3, P.MaxZ + 3))
	local look = if faceTo then flat(faceTo - bot.pos) else to
	if look.Magnitude > 0.3 then
		local nd = bot.dir:Lerp(look.Unit, math.min(1, dt * 9))
		bot.dir = if nd.Magnitude > 0.01 then nd.Unit else look.Unit
	end
end

-- Her oyuncunun kendi hızı vardır (kadrodaki Hız özelliğinden gelir)
local function runSpeed(team: string, bot: any?): number
	local pace = 1
	if bot then
		-- yorgunluk: sahada kaldıkça hız düşer (90 dakikada %9); yeni giren oyuncu dinçtir
		local tired = math.clamp((minuteNow - (bot.freshAt or 0)) / 90, 0, 1)
		pace = (bot.pace or 1) * (1 - 0.09 * tired)
	end
	return (MC.BotSpeed[1] + (MC.BotSpeed[2] - MC.BotSpeed[1]) * skill[team]) * pace
end

function MatchAI.Clear()
	for _, bot in ipairs(bots) do
		bot.animator:Destroy()
		bot.model:Destroy()
	end
	bots = {}
	plans = {}
end

-- opts = { position (oyuncunun mevkisi), awaySkill, homeSkill }
function MatchAI.Start(opts)
	MatchAI.Clear()
	skill.away = math.clamp(opts.awaySkill, 0.05, 1)
	skill.home = math.clamp(opts.homeSkill, 0.05, 1)
	humanSlot = Config.FormationSlot[opts.position] or 11
	order = { name = "Dengeli", strength = 1 }
	lastCarrier = nil
	mentality = { home = 0, away = 0 }
	local fx = opts.fixture -- Squads.Fixture: kadrolar ve oyuncu özellikleri
	humanInfo = (fx and fx.home.players[humanSlot]) or { name = "Sen", number = 9, role = "SF", rating = 50, human = true }
	humanKeeper = humanSlot == 1
	stats = { shots = { home = 0, away = 0 }, possession = { home = 0, away = 0 }, offsides = { home = 0, away = 0 } }
	humanSt = newStats()
	gone = {}
	lastKicker, prevKicker = {}, {}
	offsideSnap = nil
	offsideGraceUntil = 0
	minuteNow = 0
	for slot = 1, 11 do
		if slot ~= humanSlot then
			spawn(
				if slot == 1 then "MateKeeper" elseif slot % 2 == 0 then "Mate" else "Mate2",
				"home",
				slot,
				fx and fx.home.players[slot],
				fx and fx.home.club
			)
		end
		spawn(
			if slot == 1
				then "RivalKeeper"
				elseif slot == 10 or slot == 11 then "RivalAttacker"
				elseif slot % 2 == 0 then "Rival"
				else "Rival2",
			"away",
			slot,
			fx and fx.away.players[slot],
			fx and fx.away.club
		)
	end
	MatchAI.ResetPositions()
end

function MatchAI.HumanStart(): Vector3
	return slotPos("home", humanSlot)
end

function MatchAI.ResetPositions()
	for _, bot in ipairs(bots) do
		bot.pos = bot.home
		bot.dir = Vector3.new(0, 0, dirOf(bot.team))
		bot.speed = 0
		bot.state = "play"
		bot.cd = 0.6
		bot.ring.Transparency = 1
		bot.animator:Stop()
		place(bot)
	end
	plans = {}
end

function MatchAI.SetOrder(name: string, strength: number?)
	order = { name = name, strength = math.clamp(strength or 1, 0, 1) }
end

-- Emrin takım hattına etkisi (stud): atakta öne, defansta geriye, preste biraz öne
function MatchAI.OrderPush(): number
	local o = order.name
	return (if o == "Atak" then 30 elseif o == "Defans" then -30 elseif o == "Pres" then 12 else 0) * order.strength
end

function MatchAI.Order(): string
	return order.name
end

-- "Pas ver!": top bir takım arkadaşındaysa oyuncuya pas atar. Atıldıysa true döner.
function MatchAI.CallPass(playerPos: Vector3): boolean
	local c = lastCarrier
	if not c or c.team ~= "home" or c.state == "down" or not c.model.Parent then
		return false
	end
	if flat(c.pos - Ball.Position()).Magnitude > 4.5 or clock < frozenUntil then
		return false
	end
	local dist = flat(playerPos - c.pos).Magnitude
	if dist < 6 or dist > 190 then
		return false
	end
	c.animator:Play("Pass")
	c.cd = 0.7
	pendingKicker = c
	c.st.passes += 1
	kickTo(playerPos + Vector3.new(0, 0.6, 0), math.clamp(42 + dist * 0.5, 48, 92), "Pass", "home", if dist > 90 then 1.25 else 1)
	return true
end

-- Kırmızı kart: oyuncu sahadan çıkar
function MatchAI.SendOff(bot)
	local i = table.find(bots, bot)
	if i then
		table.remove(bots, i)
		table.insert(gone, { team = bot.team, info = bot.info, st = bot.st, slot = bot.slot, reason = "red" })
		bot.animator:Destroy()
		bot.model:Destroy()
	end
end

--[[ Duran top düzeni. spot: topun yeri, team: vuruşu kullanan takım.
	Rakipler 9,15 m (28 stud) açılır; penaltıda kaleciler dışında herkes ceza sahasının dışına çıkar.
	humanTakes: vuruşu oyuncu kullanacaksa yapay zeka topun başına geçmez. ]]
function MatchAI.SetPiece(spot: Vector3, team: string, penalty: boolean, humanTakes: boolean)
	local d = dirOf(team)
	local taker, best = nil, math.huge
	for _, bot in ipairs(bots) do
		if not bot.keeper then
			if penalty then
				-- ceza sahası dışı: topun en az 30 stud gerisi, yanlara dağılmış
				local x = (bot.slot - 6) * 16
				bot.pos = Vector3.new(x, P.GroundY, spot.Z - d * (30 + (bot.slot % 3) * 6))
			elseif bot.team ~= team then
				local away = flat(bot.pos - spot)
				if away.Magnitude < 28 then
					local dir = if away.Magnitude > 0.5 then away.Unit else Vector3.new(0, 0, d)
					bot.pos = Vector3.new(spot.X + dir.X * 28, P.GroundY, spot.Z + dir.Z * 28)
				end
			end
			bot.pos = Vector3.new(math.clamp(bot.pos.X, P.MinX + 2, P.MaxX - 2), P.GroundY, math.clamp(bot.pos.Z, P.MinZ + 2, P.MaxZ - 2))
			bot.state = "play"
			bot.speed = 0
			bot.cd = 1
			bot.ring.Transparency = 1
			if bot.team == team then
				local dist = flat(bot.pos - spot).Magnitude
				if dist < best then
					taker, best = bot, dist
				end
			end
		end
		place(bot)
	end
	if taker and not humanTakes then
		taker.pos = Vector3.new(spot.X, P.GroundY, spot.Z - d * 3)
		taker.dir = Vector3.new(0, 0, d)
		place(taker)
	end
	plans = {}
end

function MatchAI.Freeze(seconds: number)
	frozenUntil = clock + seconds
	-- duran toplardan (santra, taç, korner, aut, serbest vuruş) sonraki ilk paslarda ofsayt aranmaz
	offsideGraceUntil = math.max(offsideGraceUntil, clock + math.min(seconds, 6) + 3)
	offsideSnap = nil
end

-- Bir takımın ofsayt çizgisi (hücum yönünde): son ikinci savunmacı, top ve orta sahadan en ilerideki
local function offsideLimit(team: string, ballPos: Vector3, ctx): number
	local d = dirOf(team)
	local opp = if team == "home" then "away" else "home"
	local first, second = -math.huge, -math.huge
	local function add(z: number)
		if z > first then
			first, second = z, first
		elseif z > second then
			second = z
		end
	end
	for _, bot in ipairs(bots) do
		if bot.team == opp then
			add(bot.pos.Z * d)
		end
	end
	if opp == "home" and ctx then
		add(ctx.playerPos.Z * d)
	end
	if second == -math.huge then
		second = first
	end
	return math.max(second, ballPos.Z * d, MID_Z * d)
end
MatchAI.OffsideLimit = offsideLimit

--[[ Oyuncu değişikliği: dizilişteki yere yeni oyuncu girer (dinç gelir).
	Çıkan oyuncunun istatistikleri maç sonu puanları için saklanır. ]]
function MatchAI.Substitute(team: string, slot: number, info): boolean
	for _, bot in ipairs(bots) do
		if bot.team == team and bot.slot == slot then
			table.insert(gone, { team = team, info = bot.info, st = bot.st, slot = slot, reason = "sub" })
			bot.info = info
			bot.st = newStats()
			bot.pace = (info.pace or 1) * 1.02
			bot.freshAt = minuteNow
			for _, dsc in ipairs(bot.model:GetDescendants()) do
				if dsc:IsA("TextLabel") and tonumber(dsc.Text) then
					dsc.Text = tostring(info.number)
				end
			end
			return true
		end
	end
	return false
end

-- Sahadaki 11 (insan oyuncu dahil değil): { slot, info, tired (0-1) }
function MatchAI.Squad(team: string)
	local out = {}
	for _, bot in ipairs(bots) do
		if bot.team == team then
			table.insert(out, { slot = bot.slot, info = bot.info, tired = math.clamp((minuteNow - (bot.freshAt or 0)) / 90, 0, 1) })
		end
	end
	table.sort(out, function(x, y)
		return x.slot < y.slot
	end)
	return out
end

-- Gol kimin? Son vuran ve ondan önce vuran (asist) oyuncuya yazılır. Döner: golcü bilgisi, asist bilgisi
function MatchAI.CreditGoal(team: string)
	local function info(who: any)
		if who == "human" then
			return humanInfo, humanSt
		elseif who then
			return who.info, who.st
		end
		return nil, nil
	end
	local sInfo, sSt = info(lastKicker[team])
	local aInfo, aSt = info(prevKicker[team])
	if sSt then
		sSt.goals += 1
	end
	if aSt and aSt ~= sSt then
		aSt.assists += 1
	else
		aInfo = nil
	end
	lastKicker, prevKicker = {}, {}
	return sInfo, aInfo
end

--[[ Maç sonu oyuncu puanları. cards["home:9"] = "yellow" | "red"
	Döner: { { team, name, number, role, human, rating, goals, assists, saves, subbed, sentOff }, ... } ]]
function MatchAI.Report(homeGoals: number, awayGoals: number, cards: { [string]: string }?)
	local out = {}
	local function rate(team: string, info, st, slot: number, human: boolean, flag: string?)
		if not info then
			return
		end
		local mine = if team == "home" then homeGoals else awayGoals
		local theirs = if team == "home" then awayGoals else homeGoals
		local r = 6
			+ st.goals * 1.1
			+ st.assists * 0.6
			+ math.min(st.shots * 0.08, 0.5)
			+ math.min(st.passes * 0.03, 0.8)
			+ math.min(st.tackles * 0.2, 1)
			- st.fouls * 0.25
			+ (if mine > theirs then 0.3 elseif mine < theirs then -0.3 else 0)
		if slot == 1 then
			r += st.saves * 0.35 - theirs * 0.25 + (if theirs == 0 then 0.8 else 0)
		elseif slot <= 5 then
			r += (if theirs == 0 then 0.4 else -0.1 * theirs)
		end
		local card = cards and cards[team .. ":" .. tostring(info.number)]
		if card == "yellow" then
			r -= 0.4
		elseif card == "red" then
			r -= 1.5
		end
		-- küçük, oyuncuya özgü fark (herkes aynı puanı almasın)
		r += (((info.rating or 50) * 7 + (info.number or 0) * 13) % 10 - 5) * 0.03
		table.insert(out, {
			team = team,
			name = info.name,
			number = info.number,
			role = info.role,
			human = human,
			rating = math.floor(math.clamp(r, 3.5, 10) * 10 + 0.5) / 10,
			goals = st.goals,
			assists = st.assists,
			saves = st.saves,
			subbed = flag == "sub",
			sentOff = flag == "red",
			slot = slot,
		})
	end
	for _, bot in ipairs(bots) do
		rate(bot.team, bot.info, bot.st, bot.slot, false, nil)
	end
	rate("home", humanInfo, humanSt, humanSlot, true, nil)
	for _, g in ipairs(gone) do
		rate(g.team, g.info, g.st, g.slot, false, g.reason)
	end
	return out
end

function MatchAI.Stats()
	return stats
end

-- Radar için: { {x, z, team}, ... }
function MatchAI.Positions()
	local out = {}
	for i, bot in ipairs(bots) do
		out[i] = { bot.pos.X, bot.pos.Z, bot.team, bot.dir.X, bot.dir.Z, bot.speed, bot.animator:Current() or "", bot.keeper }
	end
	return out
end

local function nearest(team: string?, point: Vector3, exclude: any?, noKeeper: boolean?)
	local best, bd = nil, math.huge
	for _, bot in ipairs(bots) do
		if (team == nil or bot.team == team) and bot ~= exclude and not (noKeeper and bot.keeper) and bot.state ~= "down" then
			local d = flat(bot.pos - point).Magnitude
			if d < bd then
				best, bd = bot, d
			end
		end
	end
	return best, bd
end

-- Rakipler (insan oyuncu dahil) bir doğru parçasına ne kadar yakın? Pas ve şut yolunun açık olup olmadığını söyler.
local function laneGap(from: Vector3, to: Vector3, oppTeam: string, ctx, skip: any?): number
	local a, b = flat(from), flat(to)
	local ab = b - a
	local len2 = math.max(ab:Dot(ab), 0.01)
	local gap = math.huge
	local function test(p: Vector3)
		local t = math.clamp((flat(p) - a):Dot(ab) / len2, 0.08, 1)
		local dist = (flat(p) - (a + ab * t)).Magnitude
		if dist < gap then
			gap = dist
		end
	end
	for _, bot in ipairs(bots) do
		if bot.team == oppTeam and bot ~= skip and bot.state ~= "down" then
			test(bot.pos)
		end
	end
	if oppTeam == "home" and ctx and not humanKeeper then
		test(ctx.playerPos)
	end
	return gap
end

local function keeperOf(team: string): any?
	for _, bot in ipairs(bots) do
		if bot.team == team and bot.keeper then
			return bot
		end
	end
	return nil
end

-- Skor ve dakikaya göre rakip takımın oyun anlayışı: gerideyse öne çıkar, öndeyse geri yaslanır
local mentality = { home = 0, away = 0 }
local botShot = false
function MatchAI.SetScore(homeGoals: number, awayGoals: number, minute: number)
	minuteNow = minute
	local diff = awayGoals - homeGoals
	local late = math.clamp((minute - 45) / 45, 0, 1)
	mentality.away = if diff < 0 then 8 + 16 * late elseif diff > 0 then -6 - 12 * late else 0
end

-- Topu hedefe yaklaşık hızla gönderir (yerçekimi telafili)
kickTo = function(target: Vector3, speed: number, kind: string, team: string, loft: number?)
	local pos = Ball.Position()
	local delta = target - pos
	local t = math.max(0.15, flat(delta).Magnitude / speed) * (loft or 1)
	Ball.LastTeam = team
	Ball.Kick(Vector3.new(delta.X / t, delta.Y / t + 0.5 * B.Gravity * t, delta.Z / t), 0, kind)
end

--------------------------------------------------------------------------------
-- Oyuncunun eylemleri
--------------------------------------------------------------------------------
function MatchAI.Feint(playerPos: Vector3): boolean
	local won = false
	for _, bot in ipairs(bots) do
		if bot.team == "away" and bot.state == "windup" and flat(bot.pos - playerPos).Magnitude < D.FeintRange then
			bot.state = "down"
			bot.t = D.StaggerTime
			bot.cd = D.TackleCooldown
			bot.ring.Transparency = 1
			bot.animator:Stop()
			bot.animator:Play("Stagger")
			won = true
		end
	end
	return won
end

-- Dönüş: "win" | "foul" | "card" | "miss"
function MatchAI.Tackle(playerPos: Vector3, look: Vector3, sliding: boolean): string
	local reach = if sliding then D.SlideReach else D.StandReach
	local ballPos = Ball.Position()
	local ballNear = flat(ballPos - playerPos).Magnitude <= reach and ballPos.Y < P.GroundY + 2.6 and not Ball.InNet()
	local bot, d = nearest("away", playerPos, nil, true)
	if ballNear then
		Ball.LastTeam = "home"
		Ball.Deflect(flat(look).Unit * 16)
		if bot and d < 6 then
			bot.state = "down"
			bot.t = 0.9
			bot.animator:Play("Stagger")
		end
		humanSt.tackles += 1
		return "win"
	end
	if bot and d < (if sliding then D.FoulRange + 1.4 else D.FoulRange) then
		local fromBehind = bot.dir:Dot(flat(look).Unit) > 0.45
		MatchAI.LastFoul = { bot = bot, fromBehind = fromBehind, sliding = sliding, pos = bot.pos }
		humanSt.fouls += 1
		bot.state = "down"
		bot.t = 1.4
		bot.animator:Play("Stagger")
		return if fromBehind or sliding then "card" else "foul"
	end
	return "miss"
end

-- Oyuncu kaleciyse: plonjon anında el hizasında top var mı? Varsa çeler.
function MatchAI.HumanSave(handPos: Vector3): boolean
	local bp = Ball.Position()
	if Ball.InNet() or (bp - handPos).Magnitude > 5.2 then
		return false
	end
	local v = Ball.Velocity()
	Ball.LastTeam = "home"
	Ball.Deflect(Vector3.new((if bp.X > handPos.X then 1 else -1) * 20, 12, math.abs(v.Z) * 0.3 + 12))
	humanSt.saves += 1
	return true
end

--------------------------------------------------------------------------------
-- Kaleci
--------------------------------------------------------------------------------
Ball.On("kick", function(kind, v)
	if #bots == 0 or Ball.Pitch() ~= P then
		pendingKicker = nil
		return
	end
	do
		-- kim vurdu? bot (vuruştan hemen önce yazılır) ya da topun yanındaki insan oyuncu
		local team = Ball.LastTeam
		local bp = Ball.Position()
		local who: any = pendingKicker
		pendingKicker = nil
		if not who and team == "home" and lastCtx and flat(lastCtx.playerPos - bp).Magnitude < 9 then
			who = "human"
		end
		local other = if team == "home" then "away" else "home"
		lastKicker[other], prevKicker[other] = nil, nil
		if who then
			if lastKicker[team] ~= who then
				prevKicker[team] = lastKicker[team]
			end
			lastKicker[team] = who
			if who == "human" then
				if kind == "Pass" then
					humanSt.passes += 1
				elseif v.Z * dirOf(team) > K.MinShotSpeed * 0.6 then
					humanSt.shots += 1
				end
			end
		else
			lastKicker[team], prevKicker[team] = nil, nil -- duran top: gol kimseye yazılmaz
		end
		-- ofsayt: pas anında çizginin ilerisindeki takım arkadaşları işaretlenir
		offsideSnap = nil
		if who and kind ~= "Clear" and clock >= offsideGraceUntil then
			local d = dirOf(team)
			local limit = offsideLimit(team, bp, lastCtx) + 1.2
			local set, any = {}, false
			for _, bot in ipairs(bots) do
				if bot.team == team and not bot.keeper and bot ~= who and bot.pos.Z * d > limit then
					set[bot] = true
					any = true
				end
			end
			local human = team == "home" and who ~= "human" and not humanKeeper and lastCtx ~= nil and lastCtx.playerPos.Z * d > limit
			if any or human then
				offsideSnap = { team = team, set = set, human = human, at = clock }
			end
		end
	end
	if v.Magnitude >= K.MinShotSpeed then
		-- şut istatistiği: kaleye doğru giden sert vuruş
		local team = Ball.LastTeam
		if
			v.Z * dirOf(team) > K.MinShotSpeed * 0.6
			and math.abs(Ball.Position().Z - goalOf(team).Z) < MC.ShootRange + 30
			and kind ~= "Clear"
			and kind ~= "Pass"
		then
			stats.shots[team] += 1
		end
	end
	for _, k in ipairs(bots) do
		if k.keeper then
			local goalZ = if k.team == "home" then P.GoalZBack else P.GoalZ
			local sign = if k.team == "home" then -1 else 1 -- topun kaleye giderken Z yönü
			if v.Z * sign >= K.MinShotSpeed * 0.6 and v.Magnitude >= K.MinShotSpeed then
				local line = goalZ - sign * 1.2
				local p, t = Ball.PredictCross(line)
				if p and t and math.abs(p.X) <= P.GoalHalfWidth + 1.5 and p.Y <= P.GoalHeight + 1.5 then
					local hands = Vector3.new(k.pos.X, P.GroundY + 3.4, line)
					local need = (Vector3.new(p.X, p.Y, line) - hands).Magnitude
					local sk = skill[k.team]
					local can = K.BaseReach + math.max(0, t - K.Reaction * (1.4 - sk * 0.6)) * K.DiveSpeed * (0.75 + sk * 0.4)
					if botShot then
						can = can * 1.7 + 1.5
					end
					local ok = need <= can and math.random() > K.ErrorChance * (1.6 - sk)
					local side = if p.X >= k.pos.X then 1 else -1
					plans[k] = {
						at = clock + t,
						time = t,
						save = ok,
						fumble = ok and kind == "Fuze" and math.random() < K.FumbleChance,
						side = side,
						dive = need > 2.6,
						sign = sign,
						started = false,
						done = false,
					}
				else
					plans[k] = nil
				end
			end
		end
	end
end)

local function updateKeeper(k, dt: number)
	local plan = plans[k]
	local ballPos = Ball.Position()
	local goalZ = if k.team == "home" then P.GoalZBack else P.GoalZ
	if plan and not plan.done then
		local remain = plan.at - clock
		if not plan.started and remain <= 0.5 then
			plan.started = true
			if plan.dive then
				k.animator:Play("Plonjon", { Mirror = plan.side * plan.sign < 0 })
			else
				k.animator:Play("Blok")
			end
		end
		if (ballPos.Z - (goalZ - plan.sign * 1.5)) * plan.sign >= 0 or remain <= 0 then
			plan.done = true
			if plan.save and not Ball.InNet() then
				local v = Ball.Velocity()
				local out = -plan.sign
				Ball.LastTeam = k.team
				k.st.saves += 1
				if plan.fumble then
					Ball.Deflect(Vector3.new((math.random() - 0.5) * 20, 10, out * math.abs(v.Z) * 0.18))
					fire("save", k.team, "fumble")
				elseif plan.dive then
					Ball.Deflect(Vector3.new(plan.side * (18 + math.random() * 14), 10 + math.random() * 8, out * math.abs(v.Z) * 0.28))
					fire("save", k.team, "parry")
				else
					Ball.Deflect(Vector3.new(0, 4, out * math.abs(v.Z) * 0.08))
					fire("save", k.team, "catch")
					local kb = k
					task.delay(1.2, function()
						if kb.model.Parent and not Ball.InNet() and Ball.Speed() < 30 then
							Ball.Reset(kb.pos + Vector3.new(0, 0, out * 4))
							kickTo(Vector3.new((math.random() - 0.5) * 120, 0, MID_Z + out * 10), 78, "Clear", kb.team, 1.5)
						end
					end)
				end
			end
			if plan.dive then
				local kb, shift = k, plan.side * 5.4
				task.delay(1.1, function()
					if kb.model.Parent then
						kb.pos = Vector3.new(math.clamp(kb.pos.X + shift, -P.GoalHalfWidth + 1, P.GoalHalfWidth - 1), kb.pos.Y, kb.pos.Z)
					end
				end)
			end
		end
		k.speed = 0
		return
	end
	local tx = math.clamp(ballPos.X * 0.32, -P.GoalHalfWidth + 3, P.GoalHalfWidth - 3)
	if not k.animator:IsBusy() then
		moveTo(k, Vector3.new(tx, 0, k.home.Z), K.ShuffleSpeed, dt, Vector3.new(k.pos.X, 0, MID_Z))
	end
end

--------------------------------------------------------------------------------
-- Topa sahip botun kararı
--------------------------------------------------------------------------------
local function carrierThink(bot, dt: number, ctx)
	local team = bot.team
	local d = dirOf(team)
	local goal = goalOf(team)
	local ballPos = Ball.Position()
	local toGoal = flat(goal - bot.pos)
	local sk = skill[team]
	local opp = if team == "home" then "away" else "home"
	local _, pressure = nearest(opp, bot.pos, nil, true)
	if opp == "home" then
		pressure = math.min(pressure, flat(ctx.playerPos - bot.pos).Magnitude)
	end

	-- sürme yönü: kaleye doğru, yakındaki rakipten kaçarak
	local drib = toGoal.Unit
	local threat, td = nearest(opp, bot.pos + drib * 6, nil, true)
	if threat and td < 9 then
		local away = flat(bot.pos - threat.pos)
		if away.Magnitude > 0.1 then
			-- rakibin boş tarafına kır; kenar çizgisine sıkışma
			local side = away.Unit.X
			if math.abs(bot.pos.X) > P.MaxX - 14 then
				side = if bot.pos.X > 0 then -1 else 1
			end
			drib = (drib + Vector3.new(side * (0.6 + sk * 0.5), 0, 0)).Unit
		end
	end
	local spd = runSpeed(team, bot) * 0.92
	moveTo(bot, bot.pos + drib * 10, spd, dt)
	bot.touch -= dt
	if bot.touch <= 0 and flat(ballPos - bot.pos).Magnitude < 3.6 then
		bot.touch = 0.28
		Ball.LastTeam = team
		Ball.Deflect(drib * (spd * 1.16 + 3))
	end

	if clock < bot.decideAt then
		return
	end
	bot.decideAt = clock + MC.DecideEvery * (1.3 - sk * 0.6) -- becerikli oyuncu daha hızlı karar verir
	local distGoal = toGoal.Magnitude

	-- şut: açı, şut yolu ve kalecinin yeri hesaba katılır; hedef kalecinin uzak köşesidir
	if distGoal < MC.ShootRange and math.abs(bot.pos.X) < 75 then
		local keeper = keeperOf(opp)
		local kx = if keeper then keeper.pos.X elseif opp == "home" and humanKeeper then ctx.playerPos.X else 0
		local side = if kx > 0.5 then -1 elseif kx < -0.5 then 1 else (if math.random() < 0.5 then -1 else 1)
		if math.random() > 0.25 + sk * 0.75 then
			side = if math.random() < 0.5 then -1 else 1 -- az becerikli oyuncu köşe seçemez
		end
		local aimX = side * (P.GoalHalfWidth - 2.6 - (1 - sk) * 4) -- az becerikli oyuncu köşeyi tam bulamaz
		local gap = laneGap(bot.pos, Vector3.new(aimX, 0, goal.Z), opp, ctx, keeper)
		local wideAngle = math.abs(bot.pos.X) < 22 + distGoal * 0.85
		local chance = if distGoal < 40 then 0.75 elseif distGoal < 60 then 0.28 else 0.06
		if gap < 3.2 then
			chance *= 0.3 -- önü kapalı
		end
		if not wideAngle then
			chance *= 0.3 -- dar açı: pas ara
		end
		if pressure < 6 and distGoal < 65 then
			chance += 0.15 -- sıkıştı: beklemeden vur
		end
		if math.random() < chance then
			-- en iyi oyuncu bile her şutu köşeye koyamaz; uzaktan şut daha çok sapar
			local err = 3 + (1 - sk) * 6 + distGoal * 0.06
			local target = Vector3.new(
				math.clamp(aimX + (math.random() - 0.5) * err * 2, -P.GoalHalfWidth - err, P.GoalHalfWidth + err),
				1 + math.random() * 4.5 + math.random() * err * 0.6,
				goal.Z + d
			)
			bot.animator:Play("Shoot")
			local b = bot
			task.delay(0.3, function()
				if b.model.Parent and flat(Ball.Position() - b.pos).Magnitude < 5 and not Ball.InNet() then
					botShot = true -- kaleci, botların şutuna karşı daha hazırlıklıdır (maç skoru makul kalsın)
					pendingKicker = b
					b.st.shots += 1
					kickTo(target, 72 + sk * 30, "Shoot", team)
					botShot = false
					fire("shot", team)
				end
			end)
			bot.decideAt = clock + 0.9
			return
		end
	end

	-- pas: baskı altındaysa ya da iyi bir fırsat varsa. Pas yolu kapalıysa o pas seçilmez;
	-- koşan arkadaşa topu önüne, forvete ara pası atılır.
	local pressured = pressure < 8
	if pressured or math.random() < 0.22 + sk * 0.2 then
		local best, bestScore, bestPos = nil, -math.huge, nil
		local function consider(target: any, pos: Vector3, vel: Vector3?, runner: boolean)
			local dist = flat(pos - bot.pos).Magnitude
			if dist < MC.PassMin or dist > MC.PassMax then
				return
			end
			-- top varana kadar arkadaşın gideceği yer; forvete biraz daha öne (ara pası)
			local lead = pos + (vel or Vector3.zero) * (dist / 75) * sk
			if runner then
				lead += Vector3.new(0, 0, d * (4 + 10 * sk))
			end
			lead = Vector3.new(math.clamp(lead.X, P.MinX + 4, P.MaxX - 4), pos.Y, math.clamp(lead.Z, P.MinZ + 6, P.MaxZ - 6))
			local forward = (lead.Z - bot.pos.Z) * d
			local _, open = nearest(opp, lead, nil, true)
			if opp == "home" then
				open = math.min(open, flat(ctx.playerPos - lead).Magnitude)
			end
			local gap = laneGap(ballPos, lead, opp, ctx, nil)
			local score = forward * 0.9 + math.min(open, 20) * 1.6 - dist * 0.25 + math.random() * 14 * (1.3 - sk)
			if gap < 3 + dist * 0.04 then
				score -= 70 * (0.3 + sk) -- pas yolu kapalı: becerikli oyuncu bunu görür
			end
			if pos.Z * d > offLine[team] + 1.2 then
				score -= 5 + 90 * sk * sk -- arkadaşı ofsaytta (becerikli oyuncu görür, acemi çoğu zaman görmez)
			end
			if score > bestScore then
				best, bestScore, bestPos = target, score, lead
			end
		end
		for _, mate in ipairs(bots) do
			if mate.team == team and mate ~= bot and not mate.keeper and mate.state ~= "down" then
				consider(mate, mate.pos, mate.dir * mate.speed, mate.slot >= 10)
			end
		end
		if team == "home" and not humanKeeper then
			consider("human", ctx.playerPos, nil, false)
		end
		-- baskı yokken yalnızca gerçekten iyi pas atılır; yoksa top sürmeye devam
		if best and bestPos and (pressured or bestScore > 18) then
			local ownThird = (bot.pos.Z - (if team == "home" then P.MinZ else P.MaxZ)) * d < LEN * 0.3
			if pressured and bestScore < -25 and ownThird then
				-- güvenli pas yok ve kendi sahamızdayız: topu uzaklaştır
				bot.animator:Play("Shoot")
				kickTo(Vector3.new((if bot.pos.X > 0 then 1 else -1) * (P.MaxX - 20), 0, bot.pos.Z + d * 150), 78, "Clear", team, 1.5)
				bot.decideAt = clock + 0.9
				bot.cd = 0.6
				return
			end
			local dist = flat(bestPos - bot.pos).Magnitude
			local err = (1 - sk) * 0.12
			local dir = CFrame.Angles(0, (math.random() - 0.5) * 2 * err, 0):VectorToWorldSpace(flat(bestPos - ballPos).Unit)
			local speed = math.clamp(dist * 1.25 + 26, 46, 96)
			bot.animator:Play("Pass")
			Ball.LastTeam = team
			pendingKicker = bot
			bot.st.passes += 1
			Ball.Kick(dir * speed + Vector3.new(0, if dist > 75 then 20 else 0, 0), 0, "Pass")
			if best ~= "human" then
				best.receiveUntil = clock + 2.2
			end
			bot.decideAt = clock + 0.8
			bot.cd = 0.5
		end
	end
end

--------------------------------------------------------------------------------
-- Her karede
--------------------------------------------------------------------------------
-- ctx = { playerPos }
function MatchAI.Update(dt: number, ctx)
	clock += dt
	local ballPos = Ball.Position()
	local ballFlat = flat(ballPos)
	local low = ballPos.Y < P.GroundY + 3
	local live = not Ball.InNet() and clock >= frozenUntil

	-- topa kim sahip?
	local carrier, cd = nil, 3.4
	if live and low and Ball.Speed() < 60 then
		for _, bot in ipairs(bots) do
			if bot.state ~= "down" then
				local d = flat(bot.pos - ballFlat).Magnitude
				if d < cd then
					carrier, cd = bot, d
				end
			end
		end
	end
	lastCarrier = carrier
	lastCtx = ctx
	offLine.home = offsideLimit("home", ballPos, ctx)
	offLine.away = offsideLimit("away", ballPos, ctx)
	local humanDist = flat(ctx.playerPos - ballFlat).Magnitude
	local humanHas = live and low and humanDist < 4 and (not carrier or humanDist < cd)
	if humanHas then
		carrier = nil
	end
	-- ofsayt: pas anında ofsayt konumunda olan oyuncu topla buluşursa düdük çalar
	if offsideSnap then
		local snap = offsideSnap
		if clock - snap.at > 7 then
			offsideSnap = nil
		elseif humanHas then
			offsideSnap = nil
			if snap.team == "home" and snap.human then
				stats.offsides.home += 1
				fire("offside", "human", ctx.playerPos)
			end
		elseif carrier then
			offsideSnap = nil
			if carrier.team == snap.team and snap.set[carrier] then
				stats.offsides[carrier.team] += 1
				fire("offside", carrier, carrier.pos)
			end
		end
	end
	local possession = if humanHas then "home" elseif carrier then carrier.team else Ball.LastTeam
	stats.possession[possession] += dt

	-- her takımdan topa giden oyuncu (kaleci hariç); takım arkadaşı topa sahipse gitmez
	local chaser = {}
	for _, team in ipairs({ "home", "away" }) do
		local mateHas = (carrier and carrier.team == team) or (team == "home" and humanHas)
		if not mateHas then
			local best, bd = nil, math.huge
			for _, bot in ipairs(bots) do
				if bot.team == team and not bot.keeper and bot.state ~= "down" then
					local d = flat(bot.pos - ballFlat).Magnitude - (if clock < bot.receiveUntil then 30 else 0)
					if d < bd then
						best, bd = bot, d
					end
				end
			end
			-- oyuncu topa bottan daha yakınsa ev sahibi botu geride kalır (oyuncunun topu)
			if team == "home" and humanDist < bd - 4 and not humanKeeper then
				best = nil
			end
			chaser[team] = best
		end
	end

	for _, bot in ipairs(bots) do
		bot.cd = math.max(0, bot.cd - dt)
		local team = bot.team
		local d = dirOf(team)
		if clock < frozenUntil then
			bot.speed = 0
		elseif bot.keeper then
			updateKeeper(bot, dt)
		elseif bot.state == "down" then
			bot.t -= dt
			bot.speed = 0
			if bot.t <= 0 then
				bot.state = "play"
			end
		elseif bot.state == "windup" then
			-- oyuncuya müdahale hazırlığı (kırmızı halka = çalım penceresi)
			bot.t -= dt
			moveTo(bot, ballFlat, runSpeed(team, bot) * 0.7, dt, ballFlat) -- topa doğru hamle
			bot.ring.Transparency = 0.25 + 0.5 * math.abs(math.sin(clock * 22))
			if bot.t <= 0 then
				bot.ring.Transparency = 1
				bot.state = "play"
				bot.cd = D.TackleCooldown
				if low and flat(ballPos - bot.pos).Magnitude < D.StealRange and live then
					Ball.LastTeam = team
					Ball.Deflect(Vector3.new(bot.dir.X * 14, 0, d * 20))
					bot.st.tackles += 1
					fire("steal")
				elseif live and flat(ctx.playerPos - bot.pos).Magnitude < 4.2 and math.random() < 0.4 then
					-- topu kaçırıp oyuncuya girdi: faul
					local r = math.random()
					bot.st.fouls += 1
					fire("foul", bot, if r < 0.05 then "violent" elseif r < 0.3 then "reckless" else "careless", "home", ctx.playerPos)
				end
			end
		elseif bot == carrier and live then
			carrierThink(bot, dt, ctx)
		elseif bot == chaser[team] and live then
			-- topa git; top hızlıysa önünü kes
			local lead = ballFlat + flat(Ball.Velocity()) * math.clamp(flat(bot.pos - ballFlat).Magnitude / 60, 0, 0.6)
			moveTo(bot, lead, runSpeed(team, bot), dt, ballFlat)
			local dBall = flat(ballPos - bot.pos).Magnitude
			if team == "away" and humanHas then
				if dBall < D.TackleRange and bot.cd <= 0 then
					bot.state = "windup"
					bot.t = D.TackleWindup * (1.25 - skill.away * 0.4)
					fire("telegraph")
					local b, wait = bot, math.max(0, bot.t - 0.18)
					task.delay(wait, function()
						if b.state == "windup" and b.model.Parent then
							b.animator:Play("AyaktaMudahale")
						end
					end)
				end
			elseif carrier and carrier.team ~= team and dBall < 3.4 and bot.cd <= 0 then
				-- bota karşı top kapma: beceri farkına bağlı şans
				bot.cd = 0.7
				local chance = 0.3 + (skill[team] - skill[carrier.team]) * 0.35
				if team == "home" then
					-- pres ve defans emirleri top kapma şansını artırır
					chance += (if order.name == "Pres" then 0.2 elseif order.name == "Defans" then 0.1 else 0) * order.strength
				end
				if math.random() < chance then
					bot.animator:Play("AyaktaMudahale")
					carrier.state = "down"
					carrier.t = 0.6
					carrier.animator:Play("Stagger")
					Ball.LastTeam = team
					bot.st.tackles += 1
					Ball.Deflect(Vector3.new(0, 0, d * 12))
				elseif math.random() < 0.12 then
					-- botlar arası faul
					carrier.state = "down"
					carrier.t = 1.2
					carrier.animator:Play("Stagger")
					bot.st.fouls += 1
					fire("foul", bot, if math.random() < 0.22 then "reckless" else "careless", carrier.team, carrier.pos)
				end
			elseif low and dBall < 2.8 and live and Ball.Speed() >= 60 and Ball.SinceKick() > 0.2 then
				-- hızlı gelen topu kontrol et
				Ball.LastTeam = team
				Ball.Deflect(Ball.Velocity() * 0.2)
			end
		else
			-- dizilişteki yer: top ilerledikçe takım kayar
			local shift = math.clamp((ballPos.Z - MID_Z) * 0.55, -110, 110)
			local push = if possession == team then 14 * d else -10 * d
			push += mentality[team] * d
			if team == "home" then
				push += MatchAI.OrderPush() * d
			end
			local depth = Config.Formation[bot.slot][2] -- geridekiler daha az kayar
			local target = Vector3.new(bot.home.X + ballPos.X * 0.22, 0, bot.home.Z + shift * (0.55 + depth * 0.7) + push)
			-- hücumda forvetler boşa kaçar
			if possession == team and bot.slot >= (if team == "home" and order.name == "Atak" then 6 else 10) then
				target += Vector3.new(math.sin(clock * 0.9 + bot.slot) * 10, 0, d * 12)
			end
			local sk = skill[team]
			local oppTeam = if team == "home" then "away" else "home"
			if possession ~= team and bot.slot <= 9 then
				-- adam tutma: bölgesine giren rakibi, kale ile rakip arasında kalarak karşılar
				local mark, md = nearest(oppTeam, target, nil, true)
				local markPos = mark and mark.pos
				if oppTeam == "home" and not humanKeeper then
					local hd = flat(ctx.playerPos - target).Magnitude
					if hd < md then
						markPos, md = ctx.playerPos, hd
					end
				end
				if markPos and md < (if bot.slot <= 5 then 46 else 30) then
					local goalSide = Vector3.new(markPos.X * 0.92, 0, markPos.Z - d * 5)
					target = target:Lerp(goalSide, 0.3 + 0.5 * sk)
				end
			elseif possession == team then
				-- destek: yakındaki rakipten uzaklaşıp pas açısı ver
				local near, nd = nearest(oppTeam, bot.pos, nil, true)
				if near and nd < 10 then
					local away = flat(bot.pos - near.pos)
					if away.Magnitude > 0.1 then
						target += away.Unit * (4 + 6 * sk)
					end
				end
			end
			if possession == team then
				-- ofsayta düşmemek: çizginin biraz gerisinde bekle (az becerikli oyuncu ara sıra kaçırır)
				local lapse = (math.sin(clock * 0.4 + bot.slot * 1.7) + 1) / 2
				local maxZ = offLine[team] - 2 + (1 - sk * 0.8) * 8 * lapse
				if target.Z * d > maxZ then
					target = Vector3.new(target.X, 0, maxZ * d)
				end
			end
			target = Vector3.new(math.clamp(target.X, P.MinX + 4, P.MaxX - 4), 0, math.clamp(target.Z, P.MinZ + 6, P.MaxZ - 6))
			local jog = runSpeed(team, bot) * (if flat(target - bot.pos).Magnitude > 18 then 1 else 0.7)
			moveTo(bot, target, jog, dt, ballFlat)
			-- pas isteme: top oyuncudayken boştaki forvet el kaldırır
			if team == "home" and humanHas and bot.slot >= 9 and not bot.animator:IsBusy() and math.random() < dt * 0.25 then
				bot.animator:Play("TopIste")
			end
		end

		-- gövdeyle top kesme (rakibin vuruşlarına karşı)
		if
			not bot.keeper
			and bot.state ~= "down"
			and low
			and live
			and Ball.Speed() > 30
			and Ball.SinceKick() > 0.08
			and Ball.LastTeam ~= team
		then
			local off = ballFlat - flat(bot.pos)
			if off.Magnitude < 1.5 then
				local v = Ball.Velocity()
				local n = if off.Magnitude > 0.05 then off.Unit else -flat(v).Unit
				Ball.LastTeam = team
				Ball.Deflect((v - 2 * v:Dot(n) * n) * 0.4 + Vector3.new(0, 6, 0))
			end
		end

		place(bot)
		bot.animator:Update(dt, { speed = bot.speed, grounded = true, tired = false, turn = 0, vy = 0 })
	end
end

return MatchAI

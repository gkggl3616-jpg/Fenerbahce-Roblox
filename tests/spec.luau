-- Oyun mantığı sınamaları. Çalıştırma: node tests/run.mjs
local passed, failedCount = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failedCount += 1
		__fail(name .. (if detail then "  -> " .. tostring(detail) else ""))
	end
end
local function section(name)
	print("\n== " .. name)
end
local function finite(n)
	return n == n and n ~= math.huge and n ~= -math.huge
end

local RS = game:GetService("ReplicatedStorage")
local Config = require(__tree.Shared.Config)

------------------------------------------------------------------ Config
section("Config")
check("6 kademe", #Config.Tiers == 6)
check("özellik maliyeti artar", Config.StatCost(2) > Config.StatCost(1))
check("güç hesaplanır", Config.Power({ Hiz = 3, TopKontrolu = 2, Pas = 1, Sut = 3, Defans = 1, Fizik = 1 }, 1) > 20)
for id, chain in pairs(Config.SkillChains) do
	local last = 0
	for i, s in ipairs(chain.Skills) do
		check(id .. " zincirinde seviye sırası (" .. s.Id .. ")", s.Level >= last, s.Level)
		last = s.Level
	end
end
check("diziliş 11 kişi", #Config.Formation == 11)

------------------------------------------------------------------ Poses
section("Animasyon verisi")
local Poses = require(__tree.Anim.Poses)
local jointSet = { RootPos = true }
for _, j in ipairs(Poses.Joints) do
	jointSet[j] = true
end
local actionCount = 0
for name, def in pairs(Poses.Actions) do
	actionCount += 1
	local keys = def.Keys
	check(name .. ": ilk kare 0", keys[1][1] == 0)
	check(name .. ": son kare = süre", math.abs(keys[#keys][1] - def.Duration) < 1e-6, keys[#keys][1])
	for i = 2, #keys do
		check(name .. ": kareler sıralı", keys[i][1] > keys[i - 1][1])
	end
	for _, k in ipairs(keys) do
		for joint in pairs(k[2]) do
			check(name .. ": eklem adı geçerli (" .. joint .. ")", jointSet[joint] == true)
		end
	end
	for _, ev in ipairs(def.Events or {}) do
		check(name .. ": olay süre içinde (" .. ev[2] .. ")", ev[1] > 0 and ev[1] < def.Duration)
	end
	check(name .. ": toparlanma süreden kısa", (def.Recover or 0) <= def.Duration)
	check(name .. ": adı var", name == "Fren" or name == "Stagger" or Poses.Names[name] ~= nil)
end
print("  eylem sayısı: " .. actionCount)

------------------------------------------------------------------ Animator
section("Animasyon motoru")
local Animator = require(__tree.Anim.Animator)
local rig = __makeRig("Test")
rig.Parent = workspace
local an = Animator.new(rig)
local events = {}
an:OnEvent(function(ev, action)
	events[action .. ":" .. ev] = (events[action .. ":" .. ev] or 0) + 1
end)
local ctxRun = { speed = 17, grounded = true, tired = false, turn = 0, vy = 0 }
local function motorsFinite()
	for _, m in pairs(an.Motors) do
		local p = m.Transform.Position
		if not (finite(p.X) and finite(p.Y) and finite(p.Z)) then
			return false
		end
		for _, v in ipairs(m.Transform.r) do
			if not finite(v) then
				return false
			end
		end
	end
	return true
end
for i = 1, 120 do
	an:Update(1 / 60, ctxRun)
end
check("koşu döngüsü sayısal olarak sağlam", motorsFinite())
check("koşuda ayak basma olayları", (events["run:footL"] or 0) > 2 and (events["run:footR"] or 0) > 2, events["run:footL"])
for name, def in pairs(Poses.Actions) do
	an:Stop()
	for i = 1, 20 do
		an:Update(1 / 60, ctxRun)
	end
	local started = an:Play(name)
	check(name .. " başlar", started)
	local steps = math.ceil(def.Duration / (def.Rate or 1) * 60) + 4
	local ok = true
	for i = 1, steps do
		an:Update(1 / 60, ctxRun)
		ok = ok and motorsFinite()
	end
	check(name .. " boyunca sayılar sağlam", ok)
	check(name .. " biter", not an:IsBusy())
	for _, ev in ipairs(def.Events or {}) do
		check(name .. " olayı tetiklendi: " .. ev[2], (events[name .. ":" .. ev[2]] or 0) >= 1)
	end
end
-- tuşa basıştan topa temasa kadar geçen süre
local delays = {}
for _, name in ipairs({ "Pass", "Plase", "Shoot", "Fuze", "Header", "Rovesata", "AyaktaMudahale", "Kayma", "VucutCalimi" }) do
	local def = Poses.Actions[name]
	local t = def.Events[#def.Events > 1 and (name == "Header" and 2 or (name == "Kayma" and 2 or 1)) or 1][1] / (def.Rate or 1)
	table.insert(delays, string.format("%s %.2f", Poses.Names[name], t))
end
print("  basıştan temasa (sn): " .. table.concat(delays, ", "))
check("pas teması 0,15 sn'den kısa", Poses.Actions.Pass.Events[1][1] / Poses.Actions.Pass.Rate < 0.15)
check("normal şut teması 0,25 sn'den kısa", Poses.Actions.Shoot.Events[1][1] / Poses.Actions.Shoot.Rate < 0.25)

-- girdi tamponu
an:Stop()
an:Play("Shoot")
for i = 1, 6 do
	an:Update(1 / 60, ctxRun)
end
check("meşgulken ikinci eylem hemen başlamaz", an:Play("Pass") == false)
for i = 1, 40 do
	an:Update(1 / 60, ctxRun)
end
check("tampondaki eylem toparlanınca oynar", an:Current() == "Pass" or (events["Pass:start"] or 0) >= 1, an:Current())

------------------------------------------------------------------ Ball
section("Top fiziği (deneme sahası)")
local Ball = require(__tree.Match.Ball)
local T = Config.TestPitch
Ball.Init()
local goals, posts, outs = {}, 0, 0
Ball.On("goal", function(kind, side)
	table.insert(goals, { kind, side })
end)
Ball.On("post", function()
	posts += 1
end)
Ball.On("out", function()
	outs += 1
end)
local function sim(seconds, each)
	local n = math.floor(seconds * 60)
	for i = 1, n do
		Ball.Step(1 / 60)
		__advance(1 / 60)
		if each and each(i / 60) then
			return i / 60
		end
	end
	return seconds
end
-- yuvarlanan top durur
Ball.Reset(Vector3.new(0, 0, 80))
Ball.Kick(Vector3.new(30, 0, 0), 0, "Pass")
sim(8)
check("yuvarlanan top sürtünmeyle durur", Ball.Speed() < 0.01, Ball.Speed())
check("top zeminin altına düşmez", Ball.Position().Y >= T.GroundY + Config.Ball.Radius - 0.01, Ball.Position().Y)
-- sekme
Ball.Reset(Vector3.new(0, 0, 80))
Ball.Kick(Vector3.new(0, 40, 0), 0, "Pass")
local maxY, bounces, lastVy = 0, 0, 1
sim(6, function()
	maxY = math.max(maxY, Ball.Position().Y)
	local vy = Ball.Velocity().Y
	if lastVy < 0 and vy > 0 then
		bounces += 1
	end
	lastVy = vy
end)
check("top yükselir ve sekip durur", maxY > 5 and bounces >= 2 and Ball.Speed() < 0.5, "maxY=" .. maxY .. " sekme=" .. bounces)
-- şut: ceza sahası dışından, iyi güç, ortaya
local function shot(kind, power, perfect, aimX, from, statV)
	Ball.Reset(from)
	local before = #goals
	local q, target = Ball.Strike({
		kind = kind,
		from = from + Vector3.new(0, 0, -1.5),
		facing = Vector3.new(0, 0, 1),
		aimX = aimX,
		power = power,
		perfect = perfect,
		stat = statV or 10,
	})
	local t = sim(4, function()
		return #goals > before or Ball.InNet()
	end)
	return q, #goals > before, t, target
end
local q, scored, t = shot("Shoot", 0.86, true, 0, Vector3.new(0, 0, T.GoalZ - 60))
check("mükemmel şut 'perfect' döner", q == "perfect", q)
check("60 stud'dan mükemmel şut gol olur", scored)
print(string.format("  normal şut 60 stud: %.2f sn'de kaleye ulaştı", t))
local nGoal = 0
for i = 1, 40 do
	local _, s = shot("Shoot", 0.86, true, if i % 2 == 0 then 0.8 else -0.8, Vector3.new((i % 5 - 2) * 12, 0, T.GoalZ - 55), 10)
	if s then
		nGoal += 1
	end
end
check("Şut 10 ve mükemmel vuruşta köşe şutlarının çoğu kaleyi bulur", nGoal >= 30, nGoal .. "/40")
print("  Şut 10, mükemmel, köşe: " .. nGoal .. "/40 gol")
local nLow = 0
for i = 1, 40 do
	local _, s = shot("Shoot", 0.6, false, if i % 2 == 0 then 0.9 else -0.9, Vector3.new((i % 5 - 2) * 12, 0, T.GoalZ - 55), 1)
	if s then
		nLow += 1
	end
end
check("Şut 1 ve sıradan vuruş daha az isabetli", nLow < nGoal, nLow .. " vs " .. nGoal)
print("  Şut 1, sıradan, köşe: " .. nLow .. "/40 gol")
local _, over = shot("Shoot", 1.15, false, 0, Vector3.new(0, 0, T.GoalZ - 50))
check("fazla tutulan şut üstten gider (gol olmaz)", not over)
local _, fz, tf = shot("Fuze", 0.86, true, 0, Vector3.new(0, 0, T.GoalZ - 60))
check("füze normal şuttan hızlı", tf < t, tf .. " vs " .. t)
print(string.format("  füze 60 stud: %.2f sn", tf))
local nPl = 0
for i = 1, 30 do
	local _, s = shot("Plase", 0.8, true, if i % 2 == 0 then 1 else -1, Vector3.new(0, 0, T.GoalZ - 50), 8)
	if s then
		nPl += 1
	end
end
check("plase köşeye kıvrılarak çoğunlukla gol olur", nPl >= 20, nPl .. "/30")
print("  plase, köşe: " .. nPl .. "/30 gol")
-- erişim dışı
Ball.Reset(Vector3.new(0, 0, 100))
local qm = Ball.Strike({
	kind = "Shoot",
	from = Vector3.new(20, 0, 100),
	facing = Vector3.new(0, 0, 1),
	aimX = 0,
	power = 0.8,
	perfect = false,
	stat = 5,
})
check("top uzaktayken vuruş ıska", qm == "miss")
-- kafa: yükseklik penceresi
Ball.Reset(Vector3.new(0, 0, 150))
local qh = Ball.Strike({
	kind = "Header",
	from = Vector3.new(0, 0, 149),
	facing = Vector3.new(0, 0, 1),
	aimX = 0,
	power = 0.85,
	perfect = true,
	stat = 5,
	minY = 3.6,
	maxY = 9.5,
	reach = 4.2,
})
check("yerdeki topa kafa vurulamaz", qh == "miss")
-- orta ve düşüş tahmini
Ball.Cross(Vector3.new(100, 0, 170), Vector3.new(0, 3, 150), 1.75)
local land, lt = Ball.Predict()
check("ortanın düşeceği yer tahmin edilir", land ~= nil and lt ~= nil and lt > 0.8 and lt < 3, lt)
if land then
	local err = math.sqrt((land.X - 0) ^ 2 + (land.Z - 150) ^ 2)
	check("orta hedefin yakınına düşer", err < 22, string.format("%.1f stud sapma", err))
	print(string.format("  orta: %.2f sn, hedeften %.1f stud", lt, err))
end
-- sürme dokunuşu
Ball.Reset(Vector3.new(0, 0, 90))
local touched = Ball.Touch({ pos = Vector3.new(0, 0, 88.5), dir = Vector3.new(0, 0, 1), speed = 17, sprinting = false, control = 5 })
check("yakındaki topa sürme dokunuşu", touched and Ball.Velocity().Z > 17)
check(
	"uzaktaki topa dokunuş yok",
	Ball.Touch({ pos = Vector3.new(30, 0, 88), dir = Vector3.new(0, 0, 1), speed = 17, sprinting = false, control = 5 }) == false
)
-- pas hedefe yönelir
Ball.Reset(Vector3.new(0, 0, 90))
Ball.Pass(Vector3.new(0, 0, 89), Vector3.new(0.15, 0, 1).Unit, 0, 10, { Vector3.new(0, 0, 130) })
sim(2)
check("pas mankene ulaşır", math.abs(Ball.Position().X) < 5 and Ball.Position().Z > 118, Ball.Position().X .. "," .. Ball.Position().Z)

------------------------------------------------------------------ Drill botları
section("Çalışma botları (savunmacı, kaleci, hücumcu)")
local templates = Instance.new("Folder")
templates.Name = "FK_BotTemplates"
for _, n in ipairs({ "Rival", "Rival2", "RivalAttacker", "RivalKeeper", "Mate", "Mate2", "MateKeeper" }) do
	__makeRig(n).Parent = templates
end
templates.Parent = RS
local Bots = require(__tree.Match.Bots)
local ev = { steal = 0, save = 0, escape = 0, telegraph = 0 }
for k in pairs(ev) do
	Bots.On(k, function()
		ev[k] += 1
	end)
end
Bots.Start("Hucum")
-- oyuncu topla savunmacının yanında durur: müdahale hazırlığı ve top kapma beklenir
local playerPos = Vector3.new(-14, 0, T.GoalZ - 66)
Ball.Reset(playerPos + Vector3.new(0, 0, 2))
for i = 1, 60 * 6 do
	Bots.Update(1 / 60, { playerPos = playerPos })
	Ball.Step(1 / 60)
	__advance(1 / 60)
	if ev.steal > 0 then
		break
	end
end
check("savunmacı müdahaleyi haber verir", ev.telegraph >= 1, ev.telegraph)
check("çalım atılmazsa top kapılır", ev.steal >= 1, ev.steal)
-- çalım penceresi
Bots.Start("Hucum")
Ball.Reset(playerPos + Vector3.new(0, 0, 2))
ev.telegraph = 0
local feintWon = false
for i = 1, 60 * 6 do
	Bots.Update(1 / 60, { playerPos = playerPos })
	Ball.Step(1 / 60)
	__advance(1 / 60)
	if ev.telegraph > 0 and not feintWon then
		__advance(0.15) -- oyuncunun tepki süresi
		feintWon = Bots.Feint(playerPos)
		break
	end
end
check("hazırlık sırasında atılan çalım savunmacıyı sendeletir", feintWon)
check("pencere dışında çalım işe yaramaz", Bots.Feint(Vector3.new(90, 0, 60)) == false)
-- kaleci: ortaya zayıf şutları kurtarır, köşeye mükemmel şutların bir kısmı gol olur
local function keeperTrial(aimX, power, perfect, kind)
	Bots.Start("Hucum")
	local from = Vector3.new(0, 0, T.GoalZ - 62)
	Ball.Reset(from)
	local before, savesBefore = #goals, ev.save
	Ball.Strike({
		kind = kind or "Shoot",
		from = from + Vector3.new(0, 0, -1.5),
		facing = Vector3.new(0, 0, 1),
		aimX = aimX,
		power = power,
		perfect = perfect,
		stat = 8,
	})
	for i = 1, 60 * 3 do
		Bots.Update(1 / 60, { playerPos = Vector3.new(40, 0, 60) })
		Ball.Step(1 / 60)
		__advance(1 / 60)
	end
	return #goals > before, ev.save > savesBefore
end
local midGoals, midSaves, cornerGoals = 0, 0, 0
for i = 1, 30 do
	local g, s = keeperTrial(0, 0.55, false)
	if g then
		midGoals += 1
	end
	if s then
		midSaves += 1
	end
	local g2 = keeperTrial(if i % 2 == 0 then 1 else -1, 0.86, true)
	if g2 then
		cornerGoals += 1
	end
end
print(string.format("  ortaya zayıf şut: %d/30 gol, %d kurtarış;  köşeye mükemmel şut: %d/30 gol", midGoals, midSaves, cornerGoals))
check("kaleci ortaya gelen şutların çoğunu kurtarır", midSaves >= 18, midSaves)
check("köşeye mükemmel şut ortaya zayıf şuttan çok gol getirir", cornerGoals > midGoals, cornerGoals .. " vs " .. midGoals)
check("kaleci her şeyi kurtarmaz", cornerGoals >= 6, cornerGoals)
-- savunma çalışması
Bots.Start("Savunma")
ev.escape = 0
for i = 1, 60 * 14 do
	Bots.Update(1 / 60, { playerPos = Vector3.new(100, 0, 190) })
	Ball.Step(1 / 60)
	__advance(1 / 60)
end
check("durdurulmayan hücumcu kaçar", ev.escape >= 1, ev.escape)
Bots.Start("Savunma")
local res = Bots.Tackle(Ball.Position() + Vector3.new(0, 0, -2), Vector3.new(0, 0, 1), false)
check("topa yakın müdahale topu kazanır", res == "win", res)
Bots.Clear()

------------------------------------------------------------------ Maç
section("Maç yapay zekası (11'e 11, 3 sanal dakika)")
local MatchAI = require(__tree.Match.MatchAI)
local P = Config.MatchPitch
Ball.SetPitch(P)
local mg = { home = 0, away = 0 }
local deadCount, mShots, mSaves = 0, 0, 0
local midZ = (P.MinZ + P.MaxZ) / 2
local restartAt = nil
Ball.On("goal", function(kind, side)
	if Ball.Pitch() == P then
		mg[if side == "front" then "home" else "away"] += 1
		restartAt = __now() + 1
	end
end)
Ball.On("dead", function()
	deadCount += 1
	restartAt = __now() + 0.6
end)
MatchAI.On("shot", function()
	mShots += 1
end)
MatchAI.On("save", function()
	mSaves += 1
end)
MatchAI.Start({ position = "Forvet", awaySkill = 0.4, homeSkill = 0.45 })
Ball.Reset(Vector3.new(0, 0, midZ))
local human = MatchAI.HumanStart()
local okNumbers = true
for i = 1, 60 * 180 do
	MatchAI.Update(1 / 60, { playerPos = human })
	Ball.Step(1 / 60)
	__advance(1 / 60)
	local bp = Ball.Position()
	okNumbers = okNumbers and finite(bp.X) and finite(bp.Y) and finite(bp.Z)
	if restartAt and __now() >= restartAt then
		restartAt = nil
		MatchAI.ResetPositions()
		Ball.Reset(Vector3.new(0, 0, midZ))
	end
end
local st = MatchAI.Stats()
print(
	string.format(
		"  skor %d-%d, şut %d-%d, bot şutu %d, kurtarış %d, top dışarı %d kez, topa sahip olma %.0f%%-%.0f%%",
		mg.home,
		mg.away,
		st.shots.home,
		st.shots.away,
		mShots,
		mSaves,
		deadCount,
		st.possession.home / 1.8,
		st.possession.away / 1.8
	)
)
check("maç boyunca top konumu sağlam", okNumbers)
check("21 bot sahada", #MatchAI.Positions() == 21, #MatchAI.Positions())
check("botlar şut çeker", mShots >= 3, mShots)
check("iki takım da topa sahip olur", st.possession.home > 20 and st.possession.away > 20, st.possession.home .. "/" .. st.possession.away)
check("skor makul aralıkta", mg.home + mg.away <= 12, mg.home + mg.away)
local inside = true
for _, b in ipairs(MatchAI.Positions()) do
	inside = inside and b[1] >= P.MinX - 5 and b[1] <= P.MaxX + 5 and b[2] >= P.MinZ - 4 and b[2] <= P.MaxZ + 4
end
check("botlar sahanın içinde kalır", inside)
MatchAI.Clear()
Ball.SetPitch(Config.TestPitch)

------------------------------------------------------------------ Arayüz
section("Arayüz bileşenleri (kurulum ve etkileşim, çizim yok)")
local Theme = require(__tree.UI.Theme)
local UIMotion = require(__tree.UI.UIMotion)
local Components = require(__tree.UI.Components)
local Forms = require(__tree.UI.Forms)
check("büyük harf Türkçe", Theme.Upper("ışık çiçeği") == "IŞIK ÇİÇEĞİ", Theme.Upper("ışık çiçeği"))
check("sayı biçimi", Theme.FormatNumber(1234567) == "1.234.567" and Theme.FormatNumber(950) == "950", Theme.FormatNumber(1234567))
local screen = Instance.new("ScreenGui")
screen.Parent = __localPlayer.PlayerGui
local holder = Instance.new("Frame")
holder.Parent = screen
Components.SetToastHolder(holder)
local panel, content = Components.Panel({ Title = "Deneme", Size = UDim2.fromOffset(300, 200) })
panel.Parent = screen
check("panel kurulur", panel ~= nil and content ~= nil)
local clicks = 0
for _, style in ipairs({ "Primary", "Secondary", "Ghost" }) do
	local b = Components.Button({
		Text = "Buton " .. style,
		Style = style,
		Sub = "alt yazı",
		OnClick = function()
			clicks += 1
		end,
	})
	b.Parent = content
	b.MouseEnter:Fire()
	b.MouseButton1Down:Fire()
	b.MouseButton1Up:Fire()
	b.Activated:Fire()
	b.MouseLeave:Fire()
end
check("üç buton stili tıklanır", clicks == 3, clicks)
local lockedBtn = Components.Button({ Text = "Kilitli", Locked = "Seviye 5 gerekli" })
lockedBtn.Parent = content
lockedBtn.Activated:Fire()
check("kilitli buton tıklamayı işlemez, nedenini bildirir", clicks == 3 and #holder:GetChildren() >= 1)
local bar = Components.Bar({ Value = 0.2 })
bar.Set(0.9)
check("çubuk değeri sınırlanır", bar.Value == 0.9 and (bar.Set(5) or bar.Value == 1))
check("rozet kurulur", Components.Badge({ Text = "F" }) ~= nil)
for _, kind in ipairs({ "success", "error", "unlock", "level", "info" }) do
	Components.Toast(kind, "Bildirim " .. kind)
end
local lbl = Components.Label({ Text = "0" })
UIMotion.CountUp(lbl, 0, 1500)
UIMotion.In(panel, Vector2.new(0, 20))
UIMotion.Stagger({ lockedBtn }, nil, 0)
UIMotion.Shake(lockedBtn)
UIMotion.Burst(screen, "Seviye 5", "Yeni ödüller")
local wiped = false
UIMotion.Wipe(function()
	wiped = true
end)
for i = 1, 60 * 6 do
	__advance(1 / 60)
end
check("perde kapanınca geri çağrı çalışır", wiped)
check("sayaç hedefe ulaşır", lbl.Text == "1.500", lbl.Text)
check("bildirimler süresi dolunca silinir", #holder:GetChildren() == 0, #holder:GetChildren())
-- form bileşenleri
local picked
local chips = Forms.Chips({
	Options = { { Id = "a", Text = "A" }, { Id = "b", Text = "B" }, { Id = "c", Text = "C", Locked = "kilitli" } },
	Value = "a",
	OnChange = function(v)
		picked = v
	end,
})
chips.Frame:GetChildren()[3].Activated:Fire()
check("çip seçimi", picked == "b" and chips.Value == "b", tostring(picked))
local multi = Forms.Chips({ Options = { { Id = "x", Text = "X" }, { Id = "y", Text = "Y" } }, Multi = true, Values = {} })
multi.Frame:GetChildren()[2].Activated:Fire()
check("çoklu çip", multi.Values.x == true)
local sv
local slider = Forms.Slider({
	Min = 165,
	Max = 195,
	Value = 180,
	OnChange = function(v)
		sv = v
	end,
})
check("kaydırıcı başlangıcı", slider.Value == 180)
local stepV
local stepper = Forms.Stepper({
	Min = 1,
	Max = 99,
	Value = 99,
	OnChange = function(v)
		stepV = v
	end,
})
local plus
for _, c in ipairs(stepper.Frame:GetChildren()) do
	if c.ClassName == "TextButton" and c.Text == "+" then
		plus = c
	end
end
plus.MouseButton1Down:Fire()
plus.MouseButton1Up:Fire()
check("sayaç 99'dan 1'e döner", stepV == 1, tostring(stepV))
local tabs = Forms.Tabs({ Tabs = { { Id = "t1", Text = "Bir" }, { Id = "t2", Text = "İki" } } })
check("sekmeler kurulur", tabs.Value == "t1")
local sw = Forms.Swatches({ Colors = Config.SkinColors, Value = 2 })
check("renk seçici kurulur", sw.Value == 2)
local confirmed = false
Forms.Modal({
	Parent = screen,
	Title = "Emin misin?",
	Text = "Deneme",
	OnConfirm = function()
		confirmed = true
	end,
})
for i = 1, 30 do
	__advance(1 / 60)
end
check("onay penceresi kurulur", true)

------------------------------------------------------------------ Sunucu
section("Sunucu: veri ve istek doğrulama")
__isServer = true
__resetModules()
__ServerConfig = require(__tree.Shared.Config) -- sunucu modüllerinin gördüğü ayarlar
local Remotes = require(__tree.Shared.Remotes)
local DataService = require(__tree.Server.DataService)
local PlayerService = require(__tree.Server.PlayerService)
DataService.Init()
PlayerService.Init()
local plr = __localPlayer
local data = DataService.Get(plr)
check("oyuncu verisi yüklendi", data ~= nil and data.created == false)
check("başlangıç bakiyesi", data.coins == Config.Economy.StartCoins, data.coins)
local good = {
	name = "Emre Kadikoy",
	position = "Forvet",
	number = 9,
	clubName = "Moda Genclik",
	clubAbbr = "MG",
	crestShape = 1,
	kitPattern = "Cubuklu",
	appearance = {
		height = 182,
		build = "Atletik",
		skin = 2,
		face = 1,
		hairStyle = 2,
		hairColor = "1B1410",
		beard = 1,
		bootModel = 1,
		bootColor = "101216",
		accessories = { UzunKol = true, Hile = true },
	},
}
local function fire(name, ...)
	__advance(0.5) -- istek sıklığı sınırını geç
	Remotes.Get(name).OnServerEvent:Fire(plr, ...)
end
local function with(overrides)
	local c = table.clone(good)
	c.appearance = table.clone(good.appearance)
	for k, v in pairs(overrides) do
		c[k] = v
	end
	return c
end
fire("CreateCareer", with({ position = "Santrfor" }))
check("geçersiz mevki reddedilir", data.created == false)
fire("CreateCareer", with({ number = 150 }))
check("geçersiz numara reddedilir", data.created == false)
fire("CreateCareer", with({ name = "ab" }))
check("çok kısa isim reddedilir", data.created == false)
fire("CreateCareer", with({ name = "kufurlu isim" }))
check("filtreye takılan isim reddedilir", data.created == false)
fire("CreateCareer", with({ clubAbbr = "mgx1" }))
check("geçersiz kısaltma reddedilir", data.created == false)
local bad = with({})
bad.appearance.height = 250
fire("CreateCareer", bad)
check("aralık dışı boy reddedilir", data.created == false)
fire("CreateCareer", "metin")
check("tablo olmayan istek reddedilir", data.created == false)
fire("CreateCareer", good)
check("geçerli kariyer oluşur", data.created == true and data.position == "Forvet" and data.name == "Emre Kadikoy")
check("bilinmeyen aksesuar temizlenir", data.appearance.accessories.Hile == nil and data.appearance.accessories.UzunKol == true)
check("mevkiye göre başlangıç özellikleri", data.stats.Sut == 3 and data.stats.Hiz == 3)
check("ilk yetenekler açık, kaleci zinciri yok", data.skills.Sut == 1 and data.skills.Kaleci == nil)
fire("CreateCareer", with({ position = "Kaleci", name = "Baska Isim" }))
check("mevki ve isim sonradan değişmez", data.position == "Forvet" and data.name == "Emre Kadikoy")
-- özellik
local coins0 = data.coins
fire("UpgradeStat", "Pas")
check("özellik yükselir ve bakiye düşer", data.stats.Pas == 2 and data.coins == coins0 - Config.StatCost(1), data.coins)
fire("UpgradeStat", "Sut")
check("bakiye yetmezse yükselmez", data.stats.Sut == 3)
fire("UpgradeStat", "Ucma")
check("bilinmeyen özellik yok sayılır", data.stats.Ucma == nil)
-- yetenek sırası
data.coins = 100000
fire("UnlockSkill", "Sut")
check("seviye yetmezse yetenek açılmaz", data.skills.Sut == 1)
data.level = 30
fire("UnlockSkill", "Sut")
fire("UnlockSkill", "Sut")
check("yetenekler sırayla açılır", data.skills.Sut == 3, data.skills.Sut)
fire("UnlockSkill", "Kaleci")
check("başka mevkinin zinciri açılamaz", (data.skills.Kaleci or 0) == 0)
-- maç sonucu
local c1, played0 = data.coins, data.club.season.played
fire("MatchEnd", { home = 3, away = 1, myGoals = 2, myHeaderGoals = 1 })
check("başlatılmamış maçın sonucu sayılmaz", data.coins == c1)
fire("MatchStart")
fire("MatchEnd", { home = 3, away = 1, myGoals = 2, myHeaderGoals = 1 })
check("erken biten maç ödül vermez", data.coins == c1 and data.club.season.played == played0)
fire("MatchStart")
__advance(Config.Match.HalfSeconds * 2)
fire("MatchEnd", { home = 99, away = 0, myGoals = 99, myHeaderGoals = 0 })
check("imkansız skor reddedilir", data.coins == c1)
fire("MatchStart")
__advance(Config.Match.HalfSeconds * 2)
fire("MatchEnd", { home = 1, away = 0, myGoals = 3, myHeaderGoals = 0 })
check("takımdan fazla gol reddedilir", data.coins == c1)
fire("MatchStart")
__advance(Config.Match.HalfSeconds * 2)
fire("MatchEnd", { home = 3, away = 1, myGoals = 2, myHeaderGoals = 1 })
local R = Config.Match.Reward
check("galibiyet ödülü doğru", data.coins == c1 + R.Win + R.Goal + R.HeaderGoal, data.coins - c1)
check("sezon ve puan ilerler", data.club.season.played == played0 + 1 and data.club.season.points == 3)
check("kulüp kasası maç geliri alır", data.club.funds == Config.Tiers[1].MatchIncome, data.club.funds)
-- lig atlama: 10 maçta 19+ puan
for i = 1, 9 do
	fire("MatchStart")
	__advance(Config.Match.HalfSeconds * 2)
	fire("MatchEnd", { home = 2, away = 0, myGoals = 1, myHeaderGoals = 0 })
end
check("yeterli puanla lig atlanır", data.club.tier == 2 and data.club.season.played == 0 and data.club.season.number == 2, data.club.tier)
-- tesis
fire("UpgradeFacility", "Cim")
check("tesis kulüp kasasıyla gelişir", data.club.facilities.Cim == 1, data.club.funds)
-- kayıt ve oturum kilidi
check("kayıt başarılı", DataService.Save(plr, false) == true)
local raw = __stores[Config.DataStoreName]["p_" .. plr.UserId]
check(
	"veri depoya yazıldı ve oturum kilidi var",
	raw ~= nil and raw.created == true and raw.session ~= nil and raw.session.jobId == game.JobId
)
raw.session = { jobId = "baska-sunucu", t = os.time() }
check(
	"başka sunucudaki oturumun üstüne yazılmaz",
	DataService.Save(plr, false) == true and __stores[Config.DataStoreName]["p_" .. plr.UserId].session.jobId == "baska-sunucu"
)
check("kilitliyken yükleme reddedilir", DataService.Load(plr) == nil)

------------------------------------------------------------------ Oyuncu kontrolü ve maç akışı
section("Oyuncu kontrolü (tuşlarla deneme sahası)")
__isServer = false
__resetModules()
Config = require(__tree.Shared.Config)
local UIS = game:GetService("UserInputService")
local Run = game:GetService("RunService")
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
local char = __makeRig("Tester")
char.Parent = workspace
__localPlayer.Character = char
local hum = char:FindFirstChildOfClass("Humanoid")
local hrpPart = char.HumanoidRootPart
hrpPart.CFrame = CFrame.lookAt(Vector3.new(0, 3, 70), Vector3.new(0, 3, 140))
local gui2 = Instance.new("ScreenGui")
gui2.Parent = __localPlayer.PlayerGui
local PC = require(__tree.Controllers.PlayerController)
local Ball2 = require(__tree.Match.Ball)
local exited = false
PC.Start(gui2, function()
	return data
end, function()
	exited = true
end)
local function frames(n)
	for i = 1, n do
		-- sahte fizik: karakter hareket yönünde WalkSpeed ile ilerler
		local v = hum.MoveDirection * hum.WalkSpeed
		hrpPart.AssemblyLinearVelocity = Vector3.new(v.X, hrpPart.AssemblyLinearVelocity.Y, v.Z)
		hrpPart.CFrame = hrpPart.CFrame + v * (1 / 60)
		Run.Stepped:Fire(0, 1 / 60)
		__advance(1 / 60)
	end
end
local function key(code, hold)
	UIS.InputBegan:Fire({ KeyCode = code, UserInputType = Enum.UserInputType.Keyboard }, false)
	frames(hold or 2)
	UIS.InputEnded:Fire({ KeyCode = code, UserInputType = Enum.UserInputType.Keyboard }, false)
end
frames(40)
PC.SetHud(true)
frames(10)
check("deneme sahasında top hazır", Ball2.Position().Z > 70)
-- koş: hız yarım saniyede koşu hızına çıkar
hum.MoveDirection = Vector3.new(0, 0, 1)
frames(15)
local early = hum.WalkSpeed
frames(45)
check(
	"ivmelenme: hız kademeli artar",
	early < hum.WalkSpeed and math.abs(hum.WalkSpeed - Config.Movement.Run) < 1.5,
	early .. " -> " .. hum.WalkSpeed
)
-- sprint
UIS.InputBegan:Fire({ KeyCode = Config.Keys.Sprint, UserInputType = Enum.UserInputType.Keyboard }, false)
frames(60)
check("sprint hızı", hum.WalkSpeed > Config.Movement.Run + 4, hum.WalkSpeed)
frames(60 * 6)
check("dayanıklılık bitince yavaşlar", hum.WalkSpeed < Config.Movement.Run, hum.WalkSpeed)
UIS.InputEnded:Fire({ KeyCode = Config.Keys.Sprint, UserInputType = Enum.UserInputType.Keyboard }, false)
hum.MoveDirection = Vector3.zero
frames(60 * 4)
-- topun yanına git ve şut çek (basılı tut, bırak)
local function toBall()
	local bp = Ball2.Position()
	hrpPart.CFrame = CFrame.lookAt(Vector3.new(bp.X, 3, bp.Z - 2), Vector3.new(bp.X, 3, bp.Z + 50))
end
PC.SetHud(false)
PC.SetHud(true)
frames(5)
Ball2.Reset(Vector3.new(70, 0, 88)) -- savunmacılardan uzakta
toBall()
local goalsBefore = 0
local trainingGoals = 0
Ball2.On("goal", function()
	trainingGoals += 1
end)
UIS.InputBegan:Fire({ KeyCode = Config.Keys.Shoot, UserInputType = Enum.UserInputType.Keyboard }, false)
frames(math.floor(Config.Shooting.ChargeTime * 0.86 * 60))
UIS.InputEnded:Fire({ KeyCode = Config.Keys.Shoot, UserInputType = Enum.UserInputType.Keyboard }, false)
frames(20)
check("şut tuşu bırakılınca top vurulur", Ball2.Speed() > 40 or Ball2.InNet(), Ball2.Speed())
frames(60 * 4)
-- bütün eylem tuşları hatasız çalışır
for _, code in ipairs({
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Config.Keys.Pass,
	Config.Keys.Dribble,
	Config.Keys.Special,
	Enum.KeyCode.T,
	Config.Keys.Jump,
	Config.Keys.Tackle,
	Enum.KeyCode.V,
	Config.Keys.Celebrate,
	Enum.KeyCode.H,
	Enum.KeyCode.Z,
	Enum.KeyCode.X,
	Enum.KeyCode.B,
	Enum.KeyCode.N,
}) do
	key(code, 4)
	frames(80)
end
check("bütün eylem tuşları hatasız", true)
-- orta + kafa: top düşerken zıpla
key(Enum.KeyCode.N, 2)
frames(10)
key(Enum.KeyCode.B, 2)
frames(75)
key(Config.Keys.Jump, 2)
frames(120)
check("orta ve kafa akışı hatasız", true)
-- röveşata
key(Enum.KeyCode.Six, 2)
key(Enum.KeyCode.B, 2)
frames(80)
key(Config.Keys.Shoot, 6)
frames(140)
check("röveşata akışı hatasız", true)
PC.SetHud(false)
frames(30)

section("Maç akışı (kısaltılmış maç: santra, devre arası, maç sonu, ödül)")
Config.Match.HalfSeconds = 20
Config.Match.IntroTime = 1
__ServerConfig.Match.HalfSeconds = 20 -- sunucu da aynı süreyi beklesin
local MCtl = require(__tree.Match.MatchController)
local coinsBefore = data.coins
local playedBefore = data.club.season.played
local back = false
data.power = 60
MCtl.Start(gui2, data, function()
	back = true
end)
frames(30)
check("maç sahasına ışınlanır", hrpPart.Position.Z > Config.MatchPitch.MinZ, hrpPart.Position.Z)
check("skor tabelası ve radar kurulur", gui2:FindFirstChild("MatchHud") ~= nil)
hum.MoveDirection = Vector3.new(0, 0, 1)
for i = 1, 20 do
	frames(60)
	if i % 3 == 0 then
		key(Config.Keys.Pass, 3) -- (müdahale tuşu kart ve maçtan atılma getirebilir; ayrıca sınanıyor)
	elseif i % 3 == 1 then
		key(Config.Keys.Dribble, 3)
	else
		UIS.InputBegan:Fire({ KeyCode = Config.Keys.Shoot, UserInputType = Enum.UserInputType.Keyboard }, false)
		frames(40)
		UIS.InputEnded:Fire({ KeyCode = Config.Keys.Shoot, UserInputType = Enum.UserInputType.Keyboard }, false)
	end
	hum.MoveDirection = Vector3.new(math.sin(i), 0, math.cos(i * 0.7))
end
hum.MoveDirection = Vector3.zero
frames(60 * 40)
local resultPanel
for _, d in ipairs(gui2:GetDescendants()) do
	if d.Name == "Result" then
		resultPanel = d
	end
end
check("maç sonu ekranı açılır", resultPanel ~= nil)
check("sunucu maçı sezona işler", data.club.season.played == playedBefore + 1, data.club.season.played)
check("maç ödülü verilir", data.coins > coinsBefore, data.coins - coinsBefore)
-- "Lobiye dön"
if resultPanel then
	for _, d in ipairs(resultPanel:GetDescendants()) do
		if d.ClassName == "TextButton" then
			d.Activated:Fire()
		end
	end
end
frames(120)
check("maç bitince lobiye dönülür", back)
check("maç arayüzü kaldırılır", gui2:FindFirstChild("MatchHud") == nil)

print(string.format("\nSONUÇ: %d geçti, %d kaldı", passed, failedCount))

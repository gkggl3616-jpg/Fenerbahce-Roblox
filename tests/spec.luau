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
-- şablonları gerçek sunucu kodu kurar: gövde, forma, yüz ve saç bu yoldan sınanır
__isServer = true
require(__tree.Server.CharacterService).BuildBotTemplates()
__isServer = false
local templates = RS:FindFirstChild("FK_BotTemplates")
check(
	"sunucu 8 şablon kurar (7 oyuncu + hakem)",
	templates ~= nil and #templates:GetChildren() == 8,
	templates and #templates:GetChildren()
)
do
	local mate = templates:FindFirstChild("Mate")
	local extras, roles, kit, faceDecal, visibleBody = 0, {}, 0, false, 0
	for _, d in ipairs(mate:GetDescendants()) do
		if d.Name == "FK_Extra" then
			extras += 1
			local role = d:GetAttribute("FK")
			if role then
				roles[role] = true
			end
		elseif d.ClassName == "SurfaceGui" then
			kit += 1
		elseif d.ClassName == "Decal" then
			faceDecal = true
		elseif d.ClassName == "MeshPart" and d.Transparency < 1 then
			visibleBody += 1
		end
	end
	check("gövde temel şekillerden kurulur (40+ parça)", extras >= 40, extras)
	check("hazır gövde parçaları gizlenir", visibleBody == 0, visibleBody)
	check("forma, kol, şort, çorap ve şerit etiketli", roles.Shirt and roles.Sleeve and roles.Shorts and roles.Sock and roles.Trim)
	check("forma (gövdeye oturan ön ve arka baskı levhaları) ve yüz çizilir", kit == 3, kit)
	check("hazır yüz çıkartması kaldırılır", not faceDecal)
end
-- Gerçekçi mesh gövde: Studio'da içe aktarılan FK_Oyuncu şablonunun taklidi. İçe aktarıcı
-- modeli kaydırmış, döndürmüş ve ölçeklemiş olabilir; işaretler bunu geri çözer.
do
	local MeshRig = require(__tree.Shared.MeshRig)
	local MeshBody = require(__tree.Server.MeshBody)
	local Kits = require(__tree.Shared.Kits)
	local function same(a, b)
		return a ~= nil and b ~= nil and a:ToHex() == b:ToHex()
	end
	local CS = require(__tree.Server.CharacterService)
	local assets = Instance.new("Folder")
	assets.Name = "FK_Assets"
	local tpl = Instance.new("Model")
	tpl.Name = "FK_Oyuncu"
	tpl.Parent = assets
	local frame = CFrame.new(40, 2, -7) * CFrame.Angles(0, math.rad(90), 0)
	local SCALE = 0.3 -- içe aktarıcının (varsayımsal) birim dönüşümü
	local function piece(name: string, at: Vector3, size: Vector3)
		local m = Instance.new("MeshPart")
		m.Name = name
		m.Size = size * SCALE
		m.CFrame = frame * CFrame.new(at * SCALE)
		m.Parent = tpl
		return m
	end
	piece("FK_Origin", Vector3.new(0, 0, 0), Vector3.new(0.04, 0.04, 0.04))
	piece("FK_AxisX", Vector3.new(1, 0, 0), Vector3.new(0.04, 0.04, 0.04))
	piece("FK_AxisY", Vector3.new(0, 1, 0), Vector3.new(0.04, 0.04, 0.04))
	local ut = MeshRig.Parts.UpperTorso.Center
	piece("UpperTorso__Shirt__Cubuklu", ut + Vector3.new(0, 0.1, 0), Vector3.new(1.6, 1.4, 0.8))
	piece("UpperTorso__Stripe__Cubuklu", ut, Vector3.new(1.2, 1.4, 0.82))
	piece("UpperTorso__Shirt__Duz", ut, Vector3.new(1.6, 1.4, 0.8))
	piece("UpperTorso__Trim", ut + Vector3.new(0, 0.7, 0), Vector3.new(0.6, 0.1, 0.5))
	piece("Head__Hair__S2", MeshRig.Parts.Head.Center + Vector3.new(0, 0.3, 0), Vector3.new(0.7, 0.4, 0.8))
	piece("Head__Skin", MeshRig.Parts.Head.Center, Vector3.new(0.7, 0.9, 0.8))
	piece("LeftUpperArm__Skin", MeshRig.Parts.LeftUpperArm.Center, Vector3.new(0.3, 0.6, 0.3))
	piece("RightFoot__Boot", MeshRig.Parts.RightFoot.Center, Vector3.new(0.35, 0.3, 0.8))
	assets.Parent = RS
	MeshBody.Reset()
	check("mesh şablonu okunur (8 parça, işaretler hariç)", MeshBody.Load() ~= nil and #MeshBody.Load().pieces == 8)
	local plr = Instance.new("Player")
	plr.Name = "MeshDeneme"
	local char = __makeRig("MeshDeneme")
	char.Parent = workspace
	plr.Character = char
	CS.Apply(plr, {
		appearance = {
			height = 180,
			build = "Atletik",
			skin = 3,
			face = 1,
			hairStyle = 2,
			hairColor = "5A4326",
			beard = 0,
			bootModel = 1,
			bootColor = "E33A3A",
			accessories = { UzunKol = true, Bileklik = true, SacBandi = false, KisaTozluk = false },
		},
		position = "Forvet",
		kitPattern = "Cubuklu",
		number = 9,
		name = "Mesh",
		abbr = "MOD",
		level = 12,
	})
	__advance(0.5)
	local meshes, extras, fk, roles = {}, 0, {}, {}
	for _, d in ipairs(char:GetDescendants()) do
		if d.Name == "FK_Mesh" then
			table.insert(meshes, d)
			roles[d:GetAttribute("Role")] = d
			if d:GetAttribute("FK") then
				fk[d:GetAttribute("FK")] = d
			end
		elseif d.Name == "FK_Extra" then
			extras += 1
		end
	end
	check("desene uyan mesh parçaları takılır (düz forma takılmaz)", #meshes == 7, #meshes)
	check("kodla kurulan eski gövde kurulmaz (yalnız baskı ve aksesuar)", extras <= 6, extras)
	check("çubuk rengi formanın ikinci rengi", fk.Stripe ~= nil and same(fk.Stripe.Color, Kits.Club.Cubuklu.Stripe))
	check("uzun kolda kol derisi forma kolu rengini alır", fk.Sleeve ~= nil and same(fk.Sleeve.Color, Kits.Club.Cubuklu.Sleeve))
	check("saç rengi uygulanır", roles.Hair ~= nil and same(roles.Hair.Color, Color3.fromHex("5A4326")))
	check("krampon rengi uygulanır", roles.Boot ~= nil and same(roles.Boot.Color, Color3.fromHex("E33A3A")))
	-- 180 cm: boy ölçeği aralığın ortası (Config.Body); Atletik yapıda genişlik çarpanı 1
	local B = require(__tree.Shared.Config).Body
	local K = B.HeightScaleMin + (B.HeightScaleMax - B.HeightScaleMin) * 0.5
	local ls = char:FindFirstChild("LeftShoulder", true)
	local want = (MeshRig.Joints.LeftShoulder.Pivot - MeshRig.Parts.UpperTorso.Center) * K
	check("omuz eklemi mesh gövdenin omzuna taşınır", ls and (ls.C0.Position - want).Magnitude < 0.01, ls and ls.C0.Position)
	local hum = char:FindFirstChildOfClass("Humanoid")
	check("kalça yüksekliği mesh gövdeye göre", hum and math.abs(hum.HipHeight - MeshRig.HipHeight * K) < 0.01, hum and hum.HipHeight)
	-- parça, kendi R15 parçasına şablondaki göreli yerinde oturur (dönme ve ölçek geri çözüldü)
	local upper = char:FindFirstChild("UpperTorso")
	local stripe = fk.Stripe
	local rel = upper.CFrame:ToObjectSpace(stripe.CFrame).Position
	check("mesh parçası doğru yerde (işaretlerle geri çözülen konum)", rel.Magnitude < 0.01, rel)
	check("mesh parçası doğru ölçüde", math.abs(stripe.Size.X - 1.2 * K) < 0.01, stripe.Size.X)
	-- saç modeli, kısa tozluk, krampon modeli ve yüz seçenekleri
	piece("Head__Hair__S5", MeshRig.Parts.Head.Center + Vector3.new(0, 0.3, 0), Vector3.new(0.75, 0.45, 0.85))
	piece("LeftLowerLeg__SockTop", MeshRig.Parts.LeftLowerLeg.Center, Vector3.new(0.3, 0.4, 0.3))
	piece("LeftFoot__BootSole", MeshRig.Parts.LeftFoot.Center, Vector3.new(0.3, 0.1, 0.8))
	piece("Head__Brow__Kalin", MeshRig.Parts.Head.Center, Vector3.new(0.3, 0.05, 0.1))
	piece("Head__Brow__Ince", MeshRig.Parts.Head.Center, Vector3.new(0.3, 0.03, 0.1))
	MeshBody.Reset()
	local char2 = __makeRig("MeshDeneme2")
	char2.Parent = workspace
	plr.Character = char2
	CS.Apply(plr, {
		appearance = {
			height = 180,
			build = "Atletik",
			skin = 3,
			face = 2,
			hairStyle = 5,
			hairColor = "0C0C0E",
			beard = 0,
			bootModel = 2,
			bootColor = "E33A3A",
			accessories = { UzunKol = false, Bileklik = false, SacBandi = false, KisaTozluk = true },
		},
		position = "OrtaSaha",
		kitPattern = "Cubuklu",
		number = 8,
		name = "Mesh",
		abbr = "MOD",
		level = 1,
	})
	__advance(0.5)
	local got = {}
	for _, d in ipairs(char2:GetDescendants()) do
		if d.Name == "FK_Mesh" then
			got[d:GetAttribute("Role")] = (got[d:GetAttribute("Role")] or 0) + 1
			got[d:GetAttribute("Role") .. "#" .. d.Size.X] = d
		end
	end
	local hairCount = got.Hair or 0
	check("yalnız seçilen saç modeli takılır (kıvırcık)", hairCount == 1, hairCount)
	local function roleColor(role)
		for _, d in ipairs(char2:GetDescendants()) do
			if d.Name == "FK_Mesh" and d:GetAttribute("Role") == role then
				return d.Color
			end
		end
		return nil
	end
	check("kısa tozlukta tekmelik görünür", same(roleColor("SockTop"), Color3.fromRGB(237, 237, 237)))
	check("hız kramponunda beyaz taban", same(roleColor("BootSole"), Color3.fromRGB(242, 242, 242)))
	check("çift sıradaki yüzde tek kaş (kalın) takılır", got.Brow == 1, got.Brow)
	local head = char2:FindFirstChild("Head")
	local hair = nil
	for _, d in ipairs(char2:GetDescendants()) do
		if d.Name == "FK_Mesh" and d:GetAttribute("Role") == "Hair" then
			hair = d
		end
	end
	check(
		"yüz oranı kafa parçalarına uygulanır (geniş yüz)",
		hair ~= nil and math.abs(hair.Size.X - 0.75 * K * 1.05) < 0.01,
		hair and hair.Size.X
	)
	char2:Destroy()
	assets:Destroy()
	char:Destroy()
	MeshBody.Reset()
end
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
-- maç sonu oyuncu puanları
local report = MatchAI.Report(mg.home, mg.away, {})
local ratingsOk, humans = true, 0
for _, r in ipairs(report) do
	ratingsOk = ratingsOk and r.rating >= 3.5 and r.rating <= 10 and r.name ~= nil
	if r.human then
		humans += 1
	end
end
check("22 oyuncuya puan verilir", #report == 22, #report)
check("puanlar 3,5 - 10 aralığında", ratingsOk)
check("insan oyuncu raporda bir kez yer alır", humans == 1, humans)
-- oyuncu değişikliği
local before = MatchAI.Squad("away")
check("sahadaki rakip 11 listelenir", #before == 11, #before)
local subOk = MatchAI.Substitute(
	"away",
	9,
	{ name = "Y. Yedek", number = 15, role = "SLO", rating = 44, stats = { 50, 40, 40, 40, 30, 40 }, pace = 1.02 }
)
check("oyuncu değişikliği yapılır", subOk)
local swapped = false
for _, p in ipairs(MatchAI.Squad("away")) do
	if p.slot == 9 and p.info.number == 15 and p.tired == 0 then
		swapped = true
	end
end
check("giren oyuncu dizilişte ve dinç", swapped)
check("çıkan oyuncu da raporda kalır", #MatchAI.Report(mg.home, mg.away, {}) == 23)
check("olmayan mevkide değişiklik yapılmaz", MatchAI.Substitute("away", 99, {}) == false)
-- ofsayt: insan oyuncu savunma hattının gerisindeyken takım arkadaşı pas atarsa
MatchAI.Start({ position = "Forvet", awaySkill = 0.4, homeSkill = 0.45 })
local offsides = 0
MatchAI.On("offside", function(who)
	if who == "human" then
		offsides += 1
	end
end)
local deep = Vector3.new(30, 0, P.MaxZ - 8) -- rakip kalenin dibi: herkesin ilerisinde
local limit = MatchAI.OffsideLimit("home", Vector3.new(0, 0, midZ), { playerPos = human })
check("ofsayt çizgisi orta sahanın gerisinde olamaz", limit >= midZ, limit)
local passer
for _, b in ipairs(MatchAI.Positions()) do
	-- en ilerideki takım arkadaşı (pas mesafesi içinde kalsın)
	if b[3] == "home" and not b[8] and (not passer or b[2] > passer[2]) then
		passer = b
	end
end
local called = false
if passer then
	for attempt = 1, 40 do
		Ball.Reset(Vector3.new(passer[1], 0, passer[2]))
		MatchAI.Update(1 / 60, { playerPos = deep })
		__advance(1 / 60)
		if MatchAI.CallPass(deep) then
			called = true
			break
		end
	end
end
check("takım arkadaşı pas çağrısına uyar", called)
Ball.Reset(deep)
for _ = 1, 6 do
	MatchAI.Update(1 / 60, { playerPos = deep })
	__advance(1 / 60)
end
check("ofsayttaki oyuncu topla buluşunca ofsayt çalınır", offsides == 1, offsides)
-- çizginin gerisindeyken aynı pas ofsayt değildir
local onside = Vector3.new(30, 0, midZ - 30)
called = false
MatchAI.ResetPositions()
for attempt = 1, 40 do
	Ball.Reset(Vector3.new(passer[1], 0, passer[2]))
	MatchAI.Update(1 / 60, { playerPos = onside })
	__advance(1 / 60)
	if MatchAI.CallPass(onside) then
		called = true
		break
	end
end
Ball.Reset(onside)
for _ = 1, 6 do
	MatchAI.Update(1 / 60, { playerPos = onside })
	__advance(1 / 60)
end
check("kendi yarı sahasındaki oyuncuya pas ofsayt değildir", offsides == 1, offsides)
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
-- kulüp arması
local CrestS = require(__tree.Shared.Crest)
check("geçerli arma temizlenir", CrestS.Clean({ shape = 2, pattern = 3, a = 5, b = 3, symbol = 1 }) ~= nil)
check("aynı iki renk reddedilir", CrestS.Clean({ shape = 2, pattern = 3, a = 5, b = 5, symbol = 1 }) == nil)
check("sınır dışı biçim reddedilir", CrestS.Clean({ shape = 9, pattern = 1, a = 1, b = 2, symbol = 1 }) == nil)
check("kesirli değer reddedilir", CrestS.Clean({ shape = 1.5, pattern = 1, a = 1, b = 2, symbol = 1 }) == nil)
check("tablo olmayan değer reddedilir", CrestS.Clean("kalkan") == nil)
fire("SetCrest", { shape = 9, pattern = 1, a = 1, b = 2, symbol = 1 })
check("geçersiz arma kaydedilmez", data.club.crest == nil)
fire("SetCrest", { shape = 3, pattern = 4, a = 5, b = 3, symbol = 3, hile = true })
check("arma sunucuda kaydedilir", data.club.crest ~= nil and data.club.crest.shape == 3 and data.club.crest.a == 5)
check("fazladan alanlar atılır", data.club.crest ~= nil and data.club.crest.hile == nil)
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
local achievedBefore = table.clone(data.achievements or {})
fire("MatchEnd", { home = 3, away = 1, myGoals = 2, myHeaderGoals = 1 })
local R = Config.Match.Reward
-- bu maçla açılan başarımların ödülü ayrıca eklenir
local achievementBonus = 0
for _, a in ipairs(Config.Achievements) do
	if data.achievements and data.achievements[a.Id] and not achievedBefore[a.Id] then
		achievementBonus += a.Coins
	end
end
check("galibiyet ödülü doğru", data.coins == c1 + R.Win + R.Goal + R.HeaderGoal + achievementBonus, data.coins - c1)
check(
	"ilk gol ve ilk galibiyet başarımları açılır",
	data.achievements and data.achievements.IlkGol ~= nil and data.achievements.IlkGalibiyet ~= nil
)
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
frames(6)
local early = hum.WalkSpeed
frames(54)
check(
	"ivmelenme: hız kademeli artar",
	early < hum.WalkSpeed and math.abs(hum.WalkSpeed - Config.Movement.Run) < 1.5,
	early .. " -> " .. hum.WalkSpeed
)
-- sprint
UIS.InputBegan:Fire({ KeyCode = Config.Keys.Sprint, UserInputType = Enum.UserInputType.Keyboard }, false)
frames(60)
check("sprint hızı", hum.WalkSpeed > Config.Movement.Run + 4, hum.WalkSpeed)
frames(60 * 10)
-- yorulunca sprint biter ama koşu hızının altına düşmez (hız dalgalanmasın)
check("dayanıklılık bitince sprint biter, koşu hızı kalır", math.abs(hum.WalkSpeed - Config.Movement.Run) < 1.5, hum.WalkSpeed)
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
-- basit kontrol: sol tık top sendeyse şut, değilse müdahale; boşluk top sendeyse çalım
local function mouse(button, hold)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Unknown, UserInputType = button, Position = Vector3.new(400, 300, 0) }, false)
	frames(hold or 2)
	UIS.InputEnded:Fire({ KeyCode = Enum.KeyCode.Unknown, UserInputType = button, Position = Vector3.new(400, 300, 0) }, false)
end
hum.MoveDirection = Vector3.zero
frames(90)
key(Enum.KeyCode.One, 2)
local feetNow = hrpPart.Position - Vector3.new(0, 3, 0)
Ball2.Reset(Vector3.new(feetNow.X, 0, feetNow.Z + 2))
frames(4)
UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Unknown, UserInputType = Enum.UserInputType.MouseButton1 }, false)
frames(20)
check("sol tık (top sende): şut gücü dolar", PC.Debug().charge > 0.1, PC.Debug().charge)
UIS.InputEnded:Fire({ KeyCode = Enum.KeyCode.Unknown, UserInputType = Enum.UserInputType.MouseButton1 }, false)
frames(3)
check("sol tık bırakılınca şut başlar", PC.Debug().action == "Shoot", PC.Debug().action)
frames(420) -- şut gol olursa sevinç animasyonu bitsin
-- top sahanın içinde ama oyuncudan uzakta
local far = if math.abs(feetNow.Z - 120) > 30 then Vector3.new(0, 0, 120) else Vector3.new(60, 0, 70)
Ball2.Reset(far)
frames(4)
UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Unknown, UserInputType = Enum.UserInputType.MouseButton1 }, false)
frames(3)
check("sol tık (top uzakta): müdahale", PC.Debug().action == "AyaktaMudahale", PC.Debug().action)
UIS.InputEnded:Fire({ KeyCode = Enum.KeyCode.Unknown, UserInputType = Enum.UserInputType.MouseButton1 }, false)
frames(90)
Ball2.Reset(far)
frames(2)
key(Config.Keys.Jump, 2)
check("boşluk (top uzakta): zıplama", PC.Debug().action == "Jump", PC.Debug().action)
frames(120)
feetNow = hrpPart.Position - Vector3.new(0, 3, 0)
Ball2.Reset(Vector3.new(feetNow.X, 0, feetNow.Z + 2))
frames(4)
key(Config.Keys.Jump, 2)
check("boşluk (top sende): çalım", PC.Debug().action == "VucutCalimi", PC.Debug().action)
frames(90)
feetNow = hrpPart.Position - Vector3.new(0, 3, 0)
Ball2.Reset(Vector3.new(feetNow.X, 0, feetNow.Z + 2))
frames(4)
mouse(Enum.UserInputType.MouseButton2, 3)
check("sağ tık (top sende): pas", PC.Debug().action == "Pass", PC.Debug().action)
frames(90)
-- süreli antrenman: köşe avı ve pas ustası
local Training = require(__tree.Match.Training)
-- mankenler deneme sahasındaki stüdyoda: sunucu kodu kurar
__isServer = true
require(__tree.Server.CharacterService).BuildStudio()
__isServer = false
local chips
for _, d in ipairs(gui2:GetDescendants()) do
	if d.Name == "Chips" then
		chips = d
	end
end
local function chip(text)
	for _, d in ipairs(gui2:GetDescendants()) do
		if d.ClassName == "TextButton" and d:FindFirstChild("Label") and (d.Label.Text == text or d.Label.Text == string.upper(text)) then
			return d
		end
	end
	return nil
end
check("antrenman seçenekleri çizilir", chips ~= nil and chip("KÖŞE AVI") ~= nil and chip("PAS USTASI") ~= nil)
chip("KÖŞE AVI").Activated:Fire()
frames(10)
check("köşe avı başlar", Training.Active() == "Kose")
check("köşe avında savunmacı yok", require(__tree.Match.Bots).Mode() == "Bos")
local target = workspace:FindFirstChild("FK_TrainingTarget")
check("köşede parlayan hedef var", target ~= nil)
-- hedefe şut: topu hedefin önüne koyup kaleye doğru it
local hits = 0
for _ = 1, 3 do
	target = workspace:FindFirstChild("FK_TrainingTarget")
	local tp = target.Position
	Ball2.Reset(Vector3.new(tp.X, 0, tp.Z - 12))
	Ball2.Kick(Vector3.new(0, (tp.Y + 0.5 * 85 * 0.25 ^ 2) / 0.25 - 0.5 * 85 * 0.25 + 0.5, 48))
	frames(40)
	hits = Training.Score()
end
check("hedefe giren şut isabet sayılır", hits >= 2, hits)
Ball2.Reset(Vector3.new(0, 0, Config.TestPitch.GoalZ - 12))
Ball2.Kick(Vector3.new(0, 0, 60))
local beforeMiss = Training.Score()
frames(40)
check("hedef dışındaki gol isabet sayılmaz", Training.Score() == beforeMiss, Training.Score())
frames(60 * 46)
check("45 saniye sonunda antrenman biter", Training.Active() == nil)
check("rekor tutulur", Training.Best.Kose >= hits, Training.Best.Kose)
chip("PAS USTASI").Activated:Fire()
frames(10)
check("pas ustası başlar", Training.Active() == "Pas")
local lit
for _, d in ipairs(workspace.FK_Studio:GetChildren()) do
	if d.Name == "PassTarget" and d.Material == Enum.Material.Neon then
		lit = d
	end
end
check("bir manken yanar", lit ~= nil)
if lit then
	Ball2.Reset(Vector3.new(lit.Position.X, 0, lit.Position.Z - 14))
	Ball2.Kick(Vector3.new(0, 0, 40))
	frames(40)
end
check("yanan mankene pas isabet sayılır", Training.Score() == 1, Training.Score())
chip("HÜCUM").Activated:Fire()
frames(10)
check("hücum çalışmasına dönünce antrenman durur", Training.Active() == nil and require(__tree.Match.Bots).Mode() == "Hucum")
PC.SetHud(false)
frames(30)

section("Stadyum (altı kademe kurulur, ışık ayarlanır, ekran ve seyirci çalışır)")
do
	local Stadium = require(__tree.Shared.Stadium)
	local Lighting = game:GetService("Lighting")
	local last = 0
	for tier = 1, 6 do
		local model = Stadium.Build(tier, { club = "Moda Gençlik", abbr = "MOD", facilities = { TribunEki = 1, Aydinlatma = 1 } })
		local n, seats = 0, 0
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				n += 1
				if d.Name == "Seats" then
					seats += 1
				end
			end
		end
		check("kademe " .. tier .. ": parça sayısı makul (" .. n .. ")", n > 80 and n < 2500)
		check("kademe " .. tier .. ": tribün var (" .. seats .. ")", seats >= 2)
		check("kademe " .. tier .. ": tribün önceki kademeden küçük değil", seats >= last)
		last = seats
		check("kademe " .. tier .. ": dev ekran yalnızca en büyük üç statta", Stadium.HasScreen() == (tier >= 4))
		Stadium.Score("MOD", "RKP", 2, 1, 55)
		Stadium.Screen("GOL!", "MOD 55'", nil, 1)
		Stadium.Cheer()
	end
	check("gece maçında saha aydınlık (parlaklık " .. Lighting.Brightness .. ")", Lighting.Brightness >= 3)
	Stadium.Clear()
	check("stat kaldırıldı", workspace:FindFirstChild("FK_Stadium") == nil)
	check("lobi ışığı gündüz", Lighting.ClockTime > 12 and Lighting.ClockTime < 16)
	Stadium.Lobby()
	check("lobi çevresi kuruldu", workspace:FindFirstChild("FK_LobbyWorld") ~= nil)
end

local function __snapIf(name, gui)
	if __snap then
		__snap(name, gui)
	end
end
section("Yetenek ağacı, kadrolar ve maç öncesi ekranı")
do
	local Poses = require(__tree.Anim.Poses)
	for id, chain in pairs(Config.SkillChains) do
		check(id .. " zincirinde en az bir hareket var", #chain.Skills >= 1)
		if not chain.OnlyPosition then
			check(id .. " zincirinde 5 ya da daha çok hareket var", #chain.Skills >= 5, #chain.Skills)
		end
		for _, sk in ipairs(chain.Skills) do
			check(sk.Id .. " hareketinin animasyonu tanımlı", Poses.Actions[sk.Id] ~= nil)
			check(sk.Id .. " hareketinin adı tanımlı", Poses.Names[sk.Id] ~= nil)
		end
	end
	check("ilk çalım baştan açık", Config.ActionUnlocked({}, "VucutCalimi"))
	check("gökkuşağı baştan kilitli", not Config.ActionUnlocked({}, "Gokkusagi"))
	check("röveşata baştan kilitli", not Config.ActionUnlocked({ Sut = 1 }, "Rovesata"))
	check("çalım 5 olunca gökkuşağı açık", Config.ActionUnlocked({ Calim = 5 }, "Gokkusagi"))
	check("zincirde olmayan hareket (pas) her zaman açık", Config.ActionUnlocked({}, "Pass"))

	local Squads = require(__tree.Shared.Squads)
	local d = {
		name = "Deneme",
		number = 9,
		position = "Forvet",
		power = 44,
		level = 3,
		coins = 500,
		stats = { Hiz = 3, TopKontrolu = 2, Pas = 1, Sut = 3, Defans = 1, Fizik = 1 },
		skills = { Sut = 1 },
		club = { name = "Moda Gençlik", abbr = "MOD", tier = 1, crestShape = 2, season = { number = 1, played = 0, points = 0 } },
		career = { atFenerbahce = false },
	}
	local fx = Squads.Fixture(d)
	check("iki takımda 11'er oyuncu", #fx.home.players == 11 and #fx.away.players == 11)
	check("oyuncu kendi kadrosunda", fx.home.players[11].human == true and fx.home.players[11].name == "Deneme")
	check("rakibin teknik direktörü var", #fx.away.club.Coach > 3)
	local numbers, distinct = {}, true
	for _, p in ipairs(fx.home.players) do
		if numbers[p.number] then
			distinct = false
		end
		numbers[p.number] = true
		check("oyuncunun 6 özelliği var: " .. p.name, #p.stats == 6 and p.rating >= 1 and p.rating <= 99)
	end
	check("forma numaraları farklı", distinct)
	check("kulübede 5 yedek var", #fx.home.bench == 5 and #fx.away.bench == 5)
	local seen, dup = {}, false
	for _, list in ipairs({ fx.away.players, fx.away.bench }) do
		for _, p in ipairs(list) do
			if seen[p.name] then
				dup = true
			end
			seen[p.name] = true
		end
	end
	check("aynı kadroda aynı ad iki kez geçmez", not dup)
	check("yedeklerin formaları 12-16", fx.home.bench[1].number == 12 and fx.home.bench[5].number == 16)
	local fx2 = Squads.Fixture(d)
	check("aynı kulüp aynı kadroyu verir", fx2.away.players[5].name == fx.away.players[5].name)
	d.club.season.played = 1
	check("sonraki maçta rakip değişir", Squads.Fixture(d).away.club.Name ~= fx.away.club.Name)
	local different = false
	for i = 2, 11 do
		if fx.away.players[i].stats[1] ~= fx.away.players[1].stats[1] then
			different = true
		end
	end
	check("oyuncuların özellikleri birbirinden farklı", different)

	-- armalar: her biçim, desen ve simge hatasız çizilir
	local CrestM = require(__tree.Shared.Crest)
	local drawn = 0
	for shape = 1, #CrestM.Shapes do
		for pattern = 1, #CrestM.Patterns do
			for symbol = 1, #CrestM.Symbols do
				local f = CrestM.Build({ shape = shape, pattern = pattern, a = 1, b = 2, symbol = symbol }, "MOD", 100)
				if f:FindFirstChild("CrestBody") and f:FindFirstChild("CrestText") then
					drawn += 1
				end
			end
		end
	end
	check("bütün arma birleşimleri çizilir", drawn == #CrestM.Shapes * #CrestM.Patterns * #CrestM.Symbols, drawn)
	local letter = CrestM.Build({ shape = 1, pattern = 1, a = 1, b = 2, symbol = 2 }, "ŞKR", 100)
	check(
		"baş harf simgesi Türkçe harfi bölmez",
		letter:FindFirstChild("CrestText").Text == "Ş",
		letter:FindFirstChild("CrestText").Text
	)
	local oppSpec, oppAbbr = CrestM.FromClub(fx.away.club)
	check("rakibin hazır arması var", oppSpec.shape >= 1 and oppAbbr == fx.away.club.Abbr)
	d.club.crest = { shape = 4, pattern = 2, a = 6, b = 13, symbol = 1 }
	local mine = CrestM.FromClub(Squads.Fixture(d).home.club)
	check("oyuncunun tasarımı kendi kulübünde kullanılır", mine.shape == 4 and mine.a == CrestM.Colors[6])
	d.club.crest = nil

	-- puan durumu
	d.club.season = { number = 2, played = 6, points = 13 }
	local tableRows, leagueName = Squads.Table(d)
	check("puan durumunda 6 kulüp var", #tableRows == 6, #tableRows)
	local sorted, mineRow, plausible = true, nil, true
	for i, row in ipairs(tableRows) do
		if i > 1 and tableRows[i - 1].points < row.points then
			sorted = false
		end
		if row.mine then
			mineRow = row
		else
			plausible = plausible and row.won + row.drawn + row.lost == 6 and row.points == row.won * 3 + row.drawn
		end
	end
	check("tablo puana göre sıralı", sorted)
	check("oyuncunun kulübü gerçek puanıyla tabloda", mineRow ~= nil and mineRow.points == 13)
	check("diğer kulüplerin sonuçları tutarlı", plausible)
	check("lig adı gelir", leagueName == Config.Tiers[1].League, leagueName)
	check("aynı sezon aynı tabloyu verir", Squads.Table(d)[1].club.Name == tableRows[1].club.Name)
	d.club.season = { number = 1, played = 0, points = 0 }

	local sg = Instance.new("ScreenGui")
	local Lineup = require(__tree.Screens.Lineup)
	local started = false
	local root = Lineup.Show(sg, fx, function()
		started = true
	end)
	local rows = 0
	for _, t in ipairs(root:GetDescendants()) do
		if t.ClassName == "TextLabel" and string.find(t.Text, "(SEN)", 1, true) then
			rows += 1
		end
	end
	check("kadro ekranında oyuncunun satırı işaretli", rows == 1)
	for _, b in ipairs(root:GetDescendants()) do
		if b.ClassName == "TextButton" then
			b.Activated:Fire()
			break
		end
	end
	frames(60)
	check("maça çık düğmesi maçı başlatır", started)

	local SkillTree = require(__tree.Screens.SkillTree)
	SkillTree.Open(sg, function()
		return d
	end)
	local panel = sg:FindFirstChild("SkillTree")
	check("yetenek ağacı açıldı", panel ~= nil)
	local view
	for _, d in ipairs(panel:GetDescendants()) do
		if d.Name == "View" then
			view = d
		end
	end
	check("hareket önizlemesi kurulur", view ~= nil and view:FindFirstChild("WorldModel") ~= nil)
	local previewModel = view and view.WorldModel:FindFirstChild("Mate")
	check("önizlemede forma giymiş oyuncu var", previewModel ~= nil)
	-- bir düğümün üstüne gelince önizleme o hareketi oynatır
	local gokkusagi
	for _, d in ipairs(panel:GetDescendants()) do
		if d.ClassName == "TextLabel" and d.Text == "GÖKKUŞAĞI" then
			gokkusagi = d.Parent
		end
	end
	if gokkusagi then
		gokkusagi.MouseEnter:Fire()
	end
	local moved = false
	if previewModel then
		local m
		for _, d in ipairs(previewModel:GetDescendants()) do
			if d.ClassName == "Motor6D" and d.Name == "RightKnee" then
				m = d
			end
		end
		local before = m and m.Transform
		local RS2 = game:GetService("RunService")
		for _ = 1, 20 do
			RS2.RenderStepped:Fire(1 / 60)
			__advance(1 / 60)
		end
		moved = m ~= nil
			and before ~= nil
			and (m.Transform.Position - before.Position).Magnitude + math.abs(m.Transform.r[5] - before.r[5]) > 1e-4
	end
	check("önizleme hareketi oynatır", moved)
	local nodes, statButtons = 0, 0
	for _, t in ipairs(panel:GetDescendants()) do
		if
			t.ClassName == "TextLabel"
			and t.Parent.Name ~= "Preview"
			and (
				t.Text == "AÇIK"
				or string.find(t.Text, "KİLİTLİ", 1, true)
				or string.find(t.Text, "AÇ  ·", 1, true)
				or string.find(t.Text, "GEREKLİ", 1, true)
			)
		then
			nodes += 1
		elseif t.ClassName == "TextLabel" and string.sub(t.Text, 1, 2) == "+ " then
			statButtons += 1
		end
	end
	check("forvet için 4 zincir, 21 hareket düğümü", nodes == 21, nodes)
	check("6 özellik yükseltme düğmesi", statButtons == 6, statButtons)
	d.skills.Calim = 3
	SkillTree.Refresh()
	SkillTree.Close()
	frames(30)

	local LeagueScreen = require(__tree.Screens.League)
	d.club.season = { number = 1, played = 4, points = 7 }
	LeagueScreen.Open(sg, function()
		return d
	end)
	local lp = sg:FindFirstChild("League")
	check("puan durumu ekranı açıldı", lp ~= nil)
	local mineRows, otherRows = 0, 0
	for _, t in ipairs(lp:GetDescendants()) do
		if t.Name == "Mine" then
			mineRows += 1
		elseif t.Name == "Row" then
			otherRows += 1
		end
	end
	check("tabloda 5 rakip ve oyuncunun satırı var", mineRows == 1 and otherRows == 5, mineRows .. "/" .. otherRows)
	frames(60)
	__snapIf("lig", sg)
	LeagueScreen.Close()
	frames(30)
	d.club.season = { number = 1, played = 0, points = 0 }

	local Designer = require(__tree.Screens.CrestDesigner)
	Designer.Open(sg, function()
		return d
	end)
	local dp = sg:FindFirstChild("CrestDesigner")
	check("arma tasarım ekranı açıldı", dp ~= nil)
	local previews, saveButton = 0, nil
	for _, t in ipairs(dp:GetDescendants()) do
		if t.Name == "CrestBody" then
			previews += 1
		elseif t.ClassName == "TextLabel" and (t.Text == "Kaydet" or t.Text == "KAYDET") then
			saveButton = t.Parent
		end
	end
	check("üç boyutta önizleme çizilir", previews == 3, previews)
	local sent
	local conn = Remotes.Get("SetCrest").OnServerEvent:Connect(function(_, spec)
		sent = spec
	end)
	if saveButton then
		while saveButton and saveButton.ClassName ~= "TextButton" do
			saveButton = saveButton.Parent
		end
		saveButton.Activated:Fire()
	end
	frames(30)
	check("kaydet düğmesi tasarımı sunucuya yollar", sent ~= nil and sent.shape ~= nil)
	conn:Disconnect()
end

section("Maç akışı (kısaltılmış maç: santra, devre arası, maç sonu, ödül)")
Config.Match.HalfSeconds = 20
Config.Match.IntroTime = 1
__ServerConfig.Match.HalfSeconds = 20 -- sunucu da aynı süreyi beklesin
local MCtl = require(__tree.Match.MatchController)
local coinsBefore = data.coins
local playedBefore = data.club.season.played
local back = false
data.power = 60
local SquadsM = require(__tree.Shared.Squads)
local matchFixture = SquadsM.Fixture(data)
MCtl.Start(gui2, data, function()
	back = true
end, matchFixture)
-- devre arası ekranı çıkınca: bir değişiklik yap, emir ver, ikinci yarıyı başlat
local halftimeSeen, halftimeChecks = false, {}
local function handleHalftime()
	local root = gui2:FindFirstChild("Halftime")
	if not root or halftimeSeen then
		return
	end
	halftimeSeen = true
	local function named(n)
		local out = {}
		for _, t in ipairs(root:GetDescendants()) do
			if t.Name == n then
				table.insert(out, t)
			end
		end
		return out
	end
	frames(40) -- açılış animasyonu bitsin
	halftimeChecks.starters = #named("Starter")
	halftimeChecks.subs = #named("Sub")
	named("Starter")[3].Activated:Fire()
	named("Sub")[2].Activated:Fire()
	__snapIf("devre", gui2)
	local incoming = matchFixture.home.bench[2].number
	named("Swap")[1].Activated:Fire()
	halftimeChecks.subsAfter = #named("Sub")
	halftimeChecks.onPitch = false
	for _, p in ipairs(require(__tree.Match.MatchAI).Squad("home")) do
		if p.info.number == incoming then
			halftimeChecks.onPitch = true
		end
	end
	named("Order")[2].Activated:Fire()
	halftimeChecks.order = require(__tree.Match.MatchAI).Order()
	named("Continue")[1].Activated:Fire()
end
frames(30)
check("maç sahasına ışınlanır", hrpPart.Position.Z > Config.MatchPitch.MinZ, hrpPart.Position.Z)
check("skor tabelası ve radar kurulur", gui2:FindFirstChild("MatchHud") ~= nil)
-- hakem ve cezalar
frames(120)
local dbg = MCtl.Debug()
local Ref = require(__tree.Match.Referee)
check("hakem sahada", Ref.Position() ~= nil)
check("oyun başladı", dbg.state.phase == "play", dbg.state.phase)
local PM = Config.MatchPitch
local mid = Vector3.new(10, 0, (PM.MinZ + PM.MaxZ) / 2 + 20)
dbg.foul("away", { name = "A. Deneme", number = 5 }, "reckless", "home", mid)
check("faulde oyun durur", dbg.state.phase == "restart")
check("sert müdahaleye sarı kart", dbg.state.cards["away:5"] == "yellow")
local decisionShown = false
for _, d in ipairs(gui2:GetDescendants()) do
	if d.Name == "Decision" then
		decisionShown = true
	end
end
check("karar kartı ekranda", decisionShown)
frames(186)
check("serbest vuruşla oyun devam eder", dbg.state.phase == "play", dbg.state.phase)
local bp0 = Ball2.Position()
check("top faul yerine konur", math.abs(bp0.X - mid.X) < 4 and math.abs(bp0.Z - mid.Z) < 4, tostring(bp0))
check("vuruşu oyuncu kullanır: topun arkasında", math.abs(hrpPart.Position.Z - (mid.Z - 4.5)) < 3, hrpPart.Position.Z)
frames(150)
dbg.foul("away", { name = "A. Deneme", number = 5 }, "reckless", "home", mid)
check("ikinci sarı kart kırmızıdır", dbg.state.cards["away:5"] == "red")
frames(186)
frames(150)
dbg.foul("away", { name = "B. Deneme", number = 4 }, "careless", "home", Vector3.new(20, 0, PM.MaxZ - 20))
check("kontrolsüz faulde kart çıkmaz", dbg.state.cards["away:4"] == nil)
frames(186)
local bp1 = Ball2.Position()
check(
	"ceza sahasındaki faul penaltıdır (top penaltı noktasında)",
	math.abs(bp1.X) < 4 and math.abs(bp1.Z - (PM.MaxZ - 36)) < 5,
	tostring(bp1)
)
local outside = true
for _, b in ipairs(require(__tree.Match.MatchAI).Positions()) do
	if not b[8] and math.abs(b[2] - PM.MaxZ) < 54 and math.abs(b[1]) < 66 and math.abs(b[2] - bp1.Z) < 20 then
		outside = false
	end
end
check("penaltıda oyuncular topun gerisinde", outside)
frames(120)
-- takım emirleri
dbg.state.elapsed = 0
local MAI2 = require(__tree.Match.MatchAI)
check("maç dengeli emirle başlar", MAI2.Order() == "Dengeli")
Ball2.Reset(Vector3.new(0, 0, (PM.MinZ + PM.MaxZ) / 2))
dbg.setOrder("Defans")
check("emir yapay zekaya ulaşır", MAI2.Order() == "Defans")
local ordersPanel = false
for _, d in ipairs(gui2:GetDescendants()) do
	if d.Name == "Orders" then
		ordersPanel = true
	end
end
check("takım emri paneli ekranda", ordersPanel)
check("defans emri hattı geri çeker", MAI2.OrderPush() < -10, MAI2.OrderPush())
dbg.setOrder("Pres")
check("pres emri hattı biraz öne alır", MAI2.OrderPush() > 4, MAI2.OrderPush())
dbg.setOrder("Atak")
check("atak emri hattı öne çıkarır", MAI2.OrderPush() > 10, MAI2.OrderPush())
frames(120)
check("emir altında oyun sürer", dbg.state.phase == "play" or dbg.state.phase == "restart", dbg.state.phase)
key(Enum.KeyCode.T, 2)
check("T tuşu sıradaki emre geçer (Atak > Defans)", MAI2.Order() == "Defans", MAI2.Order())
dbg.setOrder("Dengeli")
dbg.state.elapsed = 0
check("oyun hâlâ sürüyor", dbg.state.phase == "play" or dbg.state.phase == "restart", dbg.state.phase)
check("topsuzken pas çağrısı hata vermez", type(MAI2.CallPass(hrpPart.Position - Vector3.new(0, 3, 0))) == "boolean")
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
	handleHalftime()
end
hum.MoveDirection = Vector3.zero
for _ = 1, 80 do
	frames(60)
	handleHalftime()
end
check("devre arası ekranı açıldı", halftimeSeen)
check(
	"devre arasında 10 takım arkadaşı ve 5 yedek listelenir",
	halftimeChecks.starters == 10 and halftimeChecks.subs == 5,
	tostring(halftimeChecks.starters) .. "/" .. tostring(halftimeChecks.subs)
)
check("değişiklikten sonra kulübede 4 yedek kalır", halftimeChecks.subsAfter == 4, halftimeChecks.subsAfter)
check("giren oyuncu sahada", halftimeChecks.onPitch == true)
check("devre arasında verilen emir uygulanır", halftimeChecks.order == "Atak", halftimeChecks.order)
local ratingsShown = false
for _, t in ipairs(gui2:GetDescendants()) do
	if t.Name == "Ratings" then
		ratingsShown = true
	end
end
check("maç sonunda oyuncu puanları gösterilir", ratingsShown)
__snapIf("sonuc", gui2)
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

section("Lobi (ana betik), mağaza, tesisler, sıralama, günlük görevler")
do
	-- sunucu tarafı: günlük görev ilerlemesi ve mağaza
	local coins0 = data.coins
	fire("BuyItem", "TopSari")
	check("mağazadan top alınır ve kuşanılır", data.owned.TopSari == true and data.equipped.Ball == "TopSari")
	check("eşyanın bedeli düşülür", data.coins == coins0 - 300, coins0 - data.coins)
	fire("BuyItem", "TopSari")
	check("aynı eşya iki kez alınmaz", data.coins == coins0 - 300)
	fire("EquipItem", "TopAltin")
	check("sahip olunmayan eşya kuşanılamaz", data.equipped.Ball == "TopSari")
	fire("EquipItem", "TopKlasik")
	check("ücretsiz eşya kuşanılır", data.equipped.Ball == "TopKlasik")
	fire("BuyItem", "OlmayanEsya")
	check("olmayan eşya yok sayılır", data.owned.OlmayanEsya == nil)
	check("günlük görevler üretilir", data.daily ~= nil and #data.daily.tasks == Config.DailyCount)
	local t1 = data.daily.tasks[1]
	local before = data.coins
	fire("ClaimDaily", 1)
	if t1.progress < 99 and not t1.claimed then
		check("tamamlanmamış görevin ödülü alınmaz", data.coins == before)
	end
	t1.progress = 99
	t1.claimed = false
	fire("ClaimDaily", 1)
	check("tamamlanan görevin ödülü verilir", t1.claimed == true and data.coins > before, data.coins - before)
	local after = data.coins
	fire("ClaimDaily", 1)
	check("ödül ikinci kez verilmez", data.coins == after)
	fire("ClaimDaily", 99)
	check("geçersiz görev sırası yok sayılır", data.coins == after)
	-- başarımlar sunucuda veri değişince kendiliğinden açılır
	data.career.hatTricks = 1
	local coinsA = data.coins
	fire("EquipItem", "TopKlasik")
	check("başarım açılır ve ödülü verilir", data.achievements and data.achievements.HatTrick ~= nil and data.coins >= coinsA + 500)
	local coinsB = data.coins
	fire("EquipItem", "TopKlasik")
	check("başarım ödülü bir kez verilir", data.coins == coinsB)
	local board = Remotes.Get("GetLeaderboard").OnServerInvoke(plr)
	check("sıralama isteği yanıt verir", type(board) == "table" and type(board.rows) == "table" and board.me.power > 0)

	-- istemci: ana betik lobiyi kurar
	local ok, err = pcall(require, __tree.Client.Main)
	check("ana betik hatasız çalışır", ok, tostring(err))
	frames(60 * 6)
	local lobby
	for _, g in ipairs(__localPlayer.PlayerGui:GetChildren()) do
		if g:FindFirstChild("Menu") then
			lobby = g
		end
	end
	check("lobi menüsü kuruldu", lobby ~= nil)
	if lobby then
		local buttons, taskRows = 0, 0
		for _, d in ipairs(lobby:GetDescendants()) do
			if d.Name == "Task" then
				taskRows += 1
			end
		end
		for _, d in ipairs(lobby.Menu:GetDescendants()) do
			if d.ClassName == "TextButton" then
				buttons += 1
			end
		end
		check("menüde 9 düğme var", buttons == 9, buttons)
		check("günlük görev satırları çizilir", taskRows == Config.DailyCount, taskRows)
		__snapIf("lobi", lobby)
		local HubS = require(__tree.Screens.Hub)
		local function getData()
			local copy = table.clone(data)
			copy.power = 44
			return copy
		end
		HubS.OpenShop(lobby, getData)
		frames(40)
		local items = 0
		for _, d in ipairs(lobby:GetDescendants()) do
			if d.Name == "Item" then
				items += 1
			end
		end
		check("mağazada top sekmesinde 5 eşya", items == 5, items)
		__snapIf("magaza", lobby)
		HubS.OpenClub(lobby, getData)
		frames(40)
		local facilities = 0
		for _, d in ipairs(lobby:GetDescendants()) do
			if d.Name == "Facility" then
				facilities += 1
			end
		end
		check("tesisler ekranında 6 tesis", facilities == 6, facilities)
		__snapIf("tesisler", lobby)
		local medal = HubS.Medal(1, 40)
		check("madalya çizilir", medal ~= nil and #medal:GetChildren() >= 3)
		if __snap then
			-- önizleme için örnek sıralama verisi (sınamada çalışmaz)
			Remotes.Get("GetLeaderboard").OnServerInvoke = function()
				local rows = {}
				for k, n in ipairs({
					"Örnek Oyuncu A",
					"Örnek Oyuncu B",
					"Örnek Oyuncu C",
					"Örnek Oyuncu D",
					"Emre Kadikoy",
					"Örnek Oyuncu E",
					"Örnek Oyuncu F",
				}) do
					table.insert(rows, { rank = k, name = n, power = 92 - k * 4, userId = if n == "Emre Kadikoy" then plr.UserId else k })
				end
				return { rows = rows, offline = false, me = { name = "Emre Kadikoy", power = 72, userId = plr.UserId } }
			end
		end
		-- kariyer sayfası: istatistik, kupa dolabı, başarımlar
		HubS.Close()
		frames(30)
		local CareerS = require(__tree.Screens.Career)
		local cdata = getData()
		cdata.career = {
			matches = 12,
			goals = 14,
			headerGoals = 3,
			wins = 7,
			hatTricks = 1,
			promotions = 1,
			trophies = { { league = Config.Tiers[1].League, season = 1, points = 22 } },
		}
		cdata.achievements = { IlkGol = 1, IlkGalibiyet = 1, Gol10 = 1, HatTrick = 1, LigAtla = 1, Kaptan = 1 }
		CareerS.Open(lobby, function()
			return cdata
		end)
		frames(40)
		local ach, trophies = 0, 0
		for _, d in ipairs(lobby:GetDescendants()) do
			if d.Name == "Achievement" then
				ach += 1
			elseif d.Name == "Trophy" then
				trophies += 1
			end
		end
		check("kariyer sayfasında 12 başarım kartı", ach == #Config.Achievements, ach)
		check("kupa dolabında 6 yer", trophies == 6, trophies)
		__snapIf("kariyer", lobby)
		CareerS.Close()
		frames(30)
		HubS.OpenRanking(lobby, getData)
		frames(40)
		check("sıralama ekranı açılır", lobby:FindFirstChild("Ranking") ~= nil)
		__snapIf("siralama", lobby)
		HubS.Close()
		frames(30)
		-- kutlama ekranları
		local Cel = require(__tree.Screens.Celebration)
		local closed = false
		Cel.Promotion(lobby, 3, function()
			closed = true
		end)
		frames(30)
		check("lig atlama ekranı açılır", lobby:FindFirstChild("Promotion") ~= nil)
		__snapIf("ligatlama", lobby)
		for _, d in ipairs(lobby.Promotion:GetDescendants()) do
			if d.ClassName == "TextButton" then
				d.Activated:Fire()
				break
			end
		end
		frames(60)
		check("lig atlama ekranı kapanır", closed and lobby:FindFirstChild("Promotion") == nil)
		local accepted = false
		Cel.Offer(lobby, { name = "Frizz", level = 25, power = 86 }, function()
			accepted = true
		end)
		frames(30)
		__snapIf("teklif", lobby)
		local signButton
		for _, d in ipairs(lobby.Offer:GetDescendants()) do
			if d.ClassName == "TextLabel" and (d.Text == "İMZALA") then
				signButton = d.Parent
			end
		end
		check("teklif ekranında imza düğmesi var", signButton ~= nil)
		if signButton then
			signButton.Activated:Fire()
		end
		frames(60)
		check("imza teklifi kabul eder", accepted)
	end
	-- sunucu: teklif kuralları
	__isServer = true
	data.career.atFenerbahce = false
	data.career.offer = nil
	fire("AcceptOffer")
	check("teklif yokken kabul edilemez", data.career.atFenerbahce == false)
	data.career.offer = true
	fire("AcceptOffer")
	check("açık teklif kabul edilir: Fenerbahçe formasına geçer", data.career.atFenerbahce == true and data.career.offer == nil)
	__isServer = false
end

print(string.format("\nSONUÇ: %d geçti, %d kaldı", passed, failedCount))

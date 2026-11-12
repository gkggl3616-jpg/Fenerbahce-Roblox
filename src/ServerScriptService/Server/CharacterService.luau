--[[
	CharacterService
	Karakterin görünümünü sunucuda uygular: gövde ölçüleri, ten, saç, forma, isim ve numara, aksesuarlar.
	Ayrıca karakter oluşturma ekranı için küçük bir stüdyo sahnesi kurar.
	Not: Gerçekçi gövde için Config.Body.Parts içine bir gövde paketi kimliği yazılmalıdır;
	boşsa oyuncunun kendi Roblox avatar gövdesi insan oranlarına ölçeklenir.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Kits = require(ReplicatedStorage.Shared.Kits)
local Crest = require(ReplicatedStorage.Shared.Crest)

local CharacterService = {}

local C = Config.Colors
local busy: { [Player]: boolean } = {}
local queued: { [Player]: any } = {}

local function hex(h: string): Color3
	local ok, c = pcall(Color3.fromHex, h)
	return if ok then c else Color3.new(0.1, 0.1, 0.1)
end

local function clear(character: Model, name: string)
	for _, d in ipairs(character:GetDescendants()) do
		if d.Name == name then
			d:Destroy()
		end
	end
end

local function weldPart(character: Model, to: BasePart, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = "FK_Extra"
	p.Size = size
	p.Shape = shape or Enum.PartType.Block
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = to.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = p
	w.Parent = p
	p.Parent = character
	return p
end

local function surface(part: BasePart, face: Enum.NormalId): SurfaceGui
	local sg = Instance.new("SurfaceGui")
	sg.Name = "FK_Kit"
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(200, 200)
	sg.LightInfluence = 1
	sg.Parent = part
	return sg
end

local function text(parent: Instance, str: string, size: UDim2, pos: UDim2, color: Color3, strokeColor: Color3)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Text = str
	l.TextScaled = true
	l.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	l.TextColor3 = color
	local s = Instance.new("UIStroke")
	s.Color = strokeColor
	s.Thickness = 3
	s.Parent = l
	l.Parent = parent
	return l
end

-- Forma desenini gövdenin ön ve arka yüzüne çizer
local function paintTorso(torso: BasePart, kit, name: string, number: number, abbr: string, crest: any?)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = surface(torso, face)
		if kit.Pattern == "Cubuklu" then
			for i = 0, 4 do
				if i % 2 == 1 then
					local f = Instance.new("Frame")
					f.BorderSizePixel = 0
					f.BackgroundColor3 = kit.Stripe
					f.Size = UDim2.fromScale(0.2, 1)
					f.Position = UDim2.fromScale(i * 0.2, 0)
					f.Parent = sg
				end
			end
		elseif kit.Pattern == "Kusakli" then
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.BackgroundColor3 = kit.Stripe
			f.Size = UDim2.fromScale(1, 0.22)
			f.Position = UDim2.fromScale(0, 0.3)
			f.Parent = sg
			local t = Instance.new("Frame")
			t.BorderSizePixel = 0
			t.BackgroundColor3 = kit.Trim
			t.Size = UDim2.fromScale(1, 0.04)
			t.Position = UDim2.fromScale(0, 0.52)
			t.Parent = sg
		end
		-- yaka
		local collar = Instance.new("Frame")
		collar.BorderSizePixel = 0
		collar.BackgroundColor3 = kit.Trim
		collar.Size = UDim2.fromScale(0.36, 0.06)
		collar.Position = UDim2.fromScale(0.32, 0)
		collar.Parent = sg
		if face == Enum.NormalId.Back then
			if name ~= "" then
				text(sg, string.upper(name), UDim2.fromScale(0.9, 0.16), UDim2.fromScale(0.05, 0.1), kit.Ink, kit.InkStroke)
			end
			text(sg, tostring(number), UDim2.fromScale(0.7, 0.58), UDim2.fromScale(0.15, 0.28), kit.Ink, kit.InkStroke)
		else
			-- göğüs: arma (yüklenmişse) ya da kulüp kısaltmalı kalkan, karşı tarafta küçük numara
			if Config.Assets.Crest ~= "" and abbr == "" then
				local img = Instance.new("ImageLabel")
				img.BackgroundTransparency = 1
				img.Image = Config.Assets.Crest
				img.Size = UDim2.fromScale(0.24, 0.24)
				img.Position = UDim2.fromScale(0.12, 0.14)
				img.Parent = sg
			else
				-- kulüp arması (oyuncunun tasarımı ya da varsayılan); maçta istemci bunu kulübe göre yeniden çizer
				local holder = Instance.new("Frame")
				holder.Name = "FK_Crest"
				holder.BackgroundTransparency = 1
				holder.Size = UDim2.fromScale(0.24, 0.24)
				holder.Position = UDim2.fromScale(0.12, 0.13)
				holder.Parent = sg
				Crest.Fill(holder, crest or Crest.Default(), if abbr ~= "" then abbr else "FB")
			end
			text(sg, tostring(number), UDim2.fromScale(0.2, 0.2), UDim2.fromScale(0.66, 0.15), kit.Ink, kit.InkStroke)
		end
	end
end

local function color(character: Model, names: { string }, c: Color3)
	for _, n in ipairs(names) do
		local p = character:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			p.Color = c
			p.Material = Enum.Material.SmoothPlastic
		end
	end
end

-- Saç: baş üstüne kaynaklı basit hacim. Gerçek saç aksesuarları yüklenince burası değişir.
local HAIR = {
	[1] = { 1.04, 0.5, 0.2 }, -- Sıfır: ince kabuk
	[2] = { 1.1, 0.62, 0.24 }, -- Kısa
	[3] = { 1.16, 0.8, 0.3 }, -- Hacimli
	[4] = { 1.2, 0.95, 0.12 }, -- Uzun
	[5] = { 1.28, 0.9, 0.3 }, -- Kıvırcık
	[6] = { 1.1, 0.62, 0.24 }, -- Topuz (ek top ile)
	[7] = { 0.92, 0.7, 0.34 }, -- Yanlar kısa
}
local function hair(character: Model, head: BasePart, style: number, c: Color3)
	local h = HAIR[style]
	if not h then
		return -- Kel
	end
	local s = head.Size
	local w = math.max(s.X, s.Z)
	local cap =
		weldPart(character, head, Vector3.new(w * h[1], s.Y * h[2], w * h[1]), CFrame.new(0, s.Y * h[3], w * 0.06), c, Enum.PartType.Ball)
	cap.Material = Enum.Material.Sand
	if style == 6 then
		weldPart(character, head, Vector3.new(w * 0.45, w * 0.45, w * 0.45), CFrame.new(0, s.Y * 0.45, w * 0.5), c, Enum.PartType.Ball).Material =
			Enum.Material.Sand
	end
end

-- Yüz: gözler, kaşlar, ağız ve sakal başın ön yüzüne çizilir
local function paintFace(head: BasePart, face: number, beard: number, hairColor: Color3, skin: Color3)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "FK_Kit"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(200, 200)
	sg.LightInfluence = 1
	sg.Parent = head
	local function shape(size: UDim2, pos: UDim2, c: Color3, round: number, rot: number?, tr: number?): Frame
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = size
		f.Position = pos
		f.BackgroundColor3 = c
		f.BackgroundTransparency = tr or 0
		f.BorderSizePixel = 0
		f.Rotation = rot or 0
		local u = Instance.new("UICorner")
		u.CornerRadius = UDim.new(round, 0)
		u.Parent = f
		f.Parent = sg
		return f
	end
	local dark = Color3.fromRGB(26, 22, 20)
	local v = (math.max(1, face) - 1) % 6
	-- sakal önce çizilir (ağız üstte kalsın)
	if beard >= 1 then
		local tr = if beard == 1 then 0.55 elseif beard == 2 then 0.25 else 0.05
		shape(UDim2.fromScale(0.74, 0.34), UDim2.fromScale(0.5, 0.84), hairColor, 0.45, 0, tr)
		if beard >= 2 then
			shape(UDim2.fromScale(0.36, 0.07), UDim2.fromScale(0.5, 0.63), hairColor, 0.5, 0, tr) -- bıyık
		end
	end
	local browTilt = ({ 0, 8, -6, 12, 4, -10 })[v + 1]
	local eyeH = ({ 0.1, 0.085, 0.11, 0.075, 0.095, 0.1 })[v + 1]
	for _, sx in ipairs({ -1, 1 }) do
		local x = 0.5 + sx * 0.17
		shape(UDim2.fromScale(0.17, eyeH), UDim2.fromScale(x, 0.43), Color3.fromRGB(246, 246, 240), 0.5)
		shape(UDim2.fromScale(0.075, eyeH * 0.92), UDim2.fromScale(x + sx * 0.005, 0.43), dark, 0.5)
		shape(UDim2.fromScale(0.2, 0.035), UDim2.fromScale(x, 0.43 - eyeH * 0.5 - 0.04), hairColor:Lerp(dark, 0.5), 0.5, sx * browTilt)
	end
	-- burun gölgesi ve ağız
	shape(UDim2.fromScale(0.05, 0.12), UDim2.fromScale(0.5, 0.53), skin:Lerp(dark, 0.22), 0.5)
	local mouthW = ({ 0.24, 0.2, 0.28, 0.18, 0.26, 0.22 })[v + 1]
	shape(UDim2.fromScale(mouthW, 0.03), UDim2.fromScale(0.5, 0.71), Color3.fromRGB(120, 60, 52), 0.5)
end

--[[
	look = {
		appearance = {...}, position, kitPattern, number, name, abbr, atFenerbahce, level
	}
]]
local function dress(character: Model?, look)
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not hum or not character:IsDescendantOf(Workspace) then
		return
	end
	local a = look.appearance
	local B = Config.Body
	local skin = Config.SkinColors[a.skin] or Config.SkinColors[2]

	-- Herkes aynı varsayılan gövdeyle başlar: oyuncunun kendi Roblox avatarı (paket gövdeler,
	-- şapkalar, kıyafetler) kullanılmaz. Boş tanım, standart R15 gövdesini verir.
	local desc = Instance.new("HumanoidDescription")
	for key, id in pairs(B.Parts) do
		if id ~= 0 then
			(desc :: any)[key] = id
		end
	end
	local h = math.clamp((a.height - Config.Appearance.HeightMin) / (Config.Appearance.HeightMax - Config.Appearance.HeightMin), 0, 1)
	desc.HeightScale = B.HeightScaleMin + (B.HeightScaleMax - B.HeightScaleMin) * h
	desc.BodyTypeScale = B.BodyTypeScale
	desc.ProportionScale = B.ProportionScale
	desc.HeadScale = B.HeadScale
	desc.WidthScale = B.Width[a.build] or B.Width.Atletik
	desc.DepthScale = B.Width[a.build] or B.Width.Atletik
	desc.HeadColor = skin
	desc.TorsoColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.LeftLegColor = skin
	desc.RightLegColor = skin
	local ok = pcall(function()
		hum:ApplyDescription(desc)
	end)
	if not ok or not character.Parent then
		return
	end

	clear(character, "FK_Extra")
	clear(character, "FK_Kit")
	-- avatardan kalan her şeyi temizle
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("CharacterMesh") then
			d:Destroy()
		elseif d:IsA("Decal") and d.Parent and d.Parent.Name == "Head" then
			d:Destroy() -- hazır yüz çıkartması; yüzü kendimiz çiziyoruz
		end
	end

	local kit = look.kit or Kits.For(look.position, look.kitPattern, look.atFenerbahce)
	local acc = a.accessories or {}
	color(character, { "UpperTorso" }, kit.Shirt)
	color(character, { "LowerTorso", "LeftUpperLeg", "RightUpperLeg" }, kit.Shorts)
	color(character, { "LeftUpperArm", "RightUpperArm" }, kit.Sleeve)
	local keeper = look.position == "Kaleci"
	local long = acc.UzunKol or keeper
	color(character, { "LeftLowerArm", "RightLowerArm" }, if long then kit.Sleeve else skin)
	color(character, { "LeftHand", "RightHand" }, if keeper then Color3.fromRGB(242, 242, 242) else skin)
	color(character, { "LeftLowerLeg", "RightLowerLeg" }, kit.Sock)
	color(character, { "LeftFoot", "RightFoot" }, hex(a.bootColor))
	color(character, { "Head" }, skin)

	local torso = character:FindFirstChild("UpperTorso")
	if torso and torso:IsA("BasePart") then
		paintTorso(torso, kit, look.name or "", look.number or 9, if look.atFenerbahce then "" else (look.abbr or ""), look.crest)
	end

	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		paintFace(head, a.face or 1, a.beard or 0, hex(a.hairColor), skin)
		hair(character, head, a.hairStyle, hex(a.hairColor))
		if acc.SacBandi then
			local s = head.Size
			weldPart(
				character,
				head,
				Vector3.new(0.14, s.Z * 1.06, s.X * 1.06),
				CFrame.new(0, s.Y * 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
				C.Yellow,
				Enum.PartType.Cylinder
			)
		end
	end
	-- tozluk üst bandı
	for _, n in ipairs({ "LeftLowerLeg", "RightLowerLeg" }) do
		local leg = character:FindFirstChild(n)
		if leg and leg:IsA("BasePart") then
			local y = if acc.KisaTozluk then 0 else leg.Size.Y * 0.38
			weldPart(character, leg, Vector3.new(leg.Size.X * 1.06, leg.Size.Y * 0.14, leg.Size.Z * 1.06), CFrame.new(0, y, 0), kit.Trim)
			if acc.KisaTozluk then
				weldPart(
					character,
					leg,
					Vector3.new(leg.Size.X * 1.03, leg.Size.Y * 0.46, leg.Size.Z * 1.03),
					CFrame.new(0, leg.Size.Y * 0.28, 0),
					skin
				)
			end
		end
	end
	-- kol ağzı bandı
	for _, n in ipairs({ "LeftUpperArm", "RightUpperArm" }) do
		local arm = character:FindFirstChild(n)
		if arm and arm:IsA("BasePart") then
			weldPart(
				character,
				arm,
				Vector3.new(arm.Size.X * 1.08, arm.Size.Y * 0.12, arm.Size.Z * 1.08),
				CFrame.new(0, -arm.Size.Y * 0.42, 0),
				kit.Trim
			)
		end
	end
	if acc.Bileklik then
		local la = character:FindFirstChild("RightLowerArm")
		if la and la:IsA("BasePart") then
			weldPart(
				character,
				la,
				Vector3.new(la.Size.X * 1.1, la.Size.Y * 0.16, la.Size.Z * 1.1),
				CFrame.new(0, -la.Size.Y * 0.36, 0),
				C.Yellow
			)
		end
	end
	if (look.level or 1) >= Config.CaptainBandLevel then
		local ua = character:FindFirstChild("LeftUpperArm")
		if ua and ua:IsA("BasePart") then
			weldPart(
				character,
				ua,
				Vector3.new(ua.Size.X * 1.12, ua.Size.Y * 0.2, ua.Size.Z * 1.12),
				CFrame.new(0, -ua.Size.Y * 0.1, 0),
				C.Gold
			)
		end
	end
	-- yaka ve krampon tabanı
	if torso and torso:IsA("BasePart") then
		local ts = torso.Size
		weldPart(character, torso, Vector3.new(ts.X * 0.46, ts.Y * 0.08, ts.Z * 1.04), CFrame.new(0, ts.Y * 0.47, 0), kit.Trim)
	end
	for _, n in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(n)
		if foot and foot:IsA("BasePart") then
			local fs = foot.Size
			weldPart(
				character,
				foot,
				Vector3.new(fs.X * 1.04, fs.Y * 0.22, fs.Z * 1.06),
				CFrame.new(0, -fs.Y * 0.42, 0),
				Color3.fromRGB(240, 240, 240)
			)
			weldPart(character, foot, Vector3.new(fs.X * 0.3, fs.Y * 0.2, fs.Z * 0.7), CFrame.new(0, fs.Y * 0.42, -fs.Z * 0.1), C.Yellow)
		end
	end
	-- şort kenar şeridi
	for _, n in ipairs({ "LeftUpperLeg", "RightUpperLeg" }) do
		local leg = character:FindFirstChild(n)
		if leg and leg:IsA("BasePart") then
			weldPart(
				character,
				leg,
				Vector3.new(leg.Size.X * 1.07, leg.Size.Y * 0.1, leg.Size.Z * 1.07),
				CFrame.new(0, -leg.Size.Y * 0.36, 0),
				kit.Trim
			)
		end
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
end

local function applyNow(player: Player, look)
	dress(player.Character, look)
end

-- Bot şablonları: rakip, rakip kaleci ve takım arkadaşı. Sunucu bir kez kurar, istemci kopyalayıp sahada kullanır.
function CharacterService.BuildBotTemplates()
	local ReplicatedStorageRef = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
	if ReplicatedStorageRef:FindFirstChild("FK_BotTemplates") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "FK_BotTemplates"
	local defs = {
		{ Name = "Rival", Kit = Kits.Rival, Position = "Defans", Number = 4, Skin = 3, Hair = 2 },
		{ Name = "Rival2", Kit = Kits.Rival, Position = "Defans", Number = 5, Skin = 1, Hair = 3 },
		{ Name = "RivalAttacker", Kit = Kits.Rival, Position = "Forvet", Number = 9, Skin = 5, Hair = 1 },
		{ Name = "RivalKeeper", Kit = Kits.RivalKeeper, Position = "Kaleci", Number = 1, Skin = 2, Hair = 2 },
		{ Name = "Mate", Kit = Kits.Club.Cubuklu, Position = "OrtaSaha", Number = 10, Skin = 4, Hair = 3 },
		{ Name = "Mate2", Kit = Kits.Club.Cubuklu, Position = "OrtaSaha", Number = 8, Skin = 2, Hair = 2 },
		{ Name = "MateKeeper", Kit = Kits.Keeper, Position = "Kaleci", Number = 1, Skin = 3, Hair = 1 },
		{ Name = "Referee", Kit = Kits.Referee, Position = "OrtaSaha", Number = 0, Skin = 2, Hair = 2 },
	}
	for i, d in ipairs(defs) do
		local ok, rig = pcall(function()
			return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
		end)
		if ok and rig then
			rig.Name = d.Name
			local hrp = rig:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				hrp.Anchored = true
			end
			rig:PivotTo(CFrame.new(i * 12, -150, 0))
			rig.Parent = Workspace
			local okDress, err = pcall(dress, rig, {
				appearance = {
					height = 176 + i * 3,
					build = "Atletik",
					skin = d.Skin,
					face = 1,
					hairStyle = d.Hair,
					hairColor = Config.HairColors[(i % #Config.HairColors) + 1],
					beard = 0,
					bootModel = 1,
					bootColor = "1A1A1A",
					accessories = {},
				},
				position = d.Position,
				kit = d.Kit,
				number = d.Number,
				name = if d.Name == "Referee" then "HAKEM" elseif d.Name == "Mate" then "TAKIM" else "RAKIP",
				abbr = "RK",
				level = 1,
			})
			if not okDress then
				warn("[CharacterService] bot giydirilemedi: " .. tostring(err))
			end
			for _, sc in ipairs(rig:GetDescendants()) do
				if sc:IsA("LuaSourceContainer") then
					sc:Destroy()
				end
			end
			rig.Parent = folder
		else
			warn("[CharacterService] bot şablonu oluşturulamadı: " .. tostring(rig))
		end
	end
	folder.Parent = ReplicatedStorageRef
end

-- Art arda gelen istekleri sıraya koyar: aynı anda tek uygulama, en son istek kazanır
function CharacterService.Apply(player: Player, look)
	queued[player] = look
	if busy[player] then
		return
	end
	busy[player] = true
	task.spawn(function()
		while queued[player] do
			local l = queued[player]
			queued[player] = nil
			local ok, err = pcall(applyNow, player, l)
			if not ok then
				warn("[CharacterService] " .. tostring(err))
			end
		end
		busy[player] = nil
	end)
end

function CharacterService.LookFromData(data)
	return {
		appearance = data.appearance,
		position = data.position,
		kitPattern = data.club.kitPattern,
		number = data.number,
		name = data.name,
		abbr = data.club.abbr,
		crest = data.club.crest,
		atFenerbahce = data.career.atFenerbahce,
		level = data.level,
	}
end

-- Karakter oluşturma ekranı ve ilk doğma için stüdyo sahnesi
function CharacterService.BuildStudio()
	if Workspace:FindFirstChild("FK_Studio") then
		return
	end
	local m = Instance.new("Model")
	m.Name = "FK_Studio"
	local function part(size: Vector3, cf: CFrame, c: Color3, material: Enum.Material?)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = c
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	part(Vector3.new(80, 1, 80), CFrame.new(0, -0.5, 0), Color3.fromRGB(14, 26, 85))
	-- Stüdyonun önünde deneme çimi (hareket ve animasyonları sınamak için)
	local grass = part(Vector3.new(240, 1, 160), CFrame.new(0, -0.52, 120), Color3.fromRGB(47, 143, 67), Enum.Material.Grass)
	grass.Name = "TestPitch"
	for i = -5, 5 do
		if i % 2 == 0 then
			part(Vector3.new(21.8, 0.02, 160), CFrame.new(i * 21.8, -0.01, 120), Color3.fromRGB(56, 158, 78), Enum.Material.Grass).CanCollide =
				false
		end
	end
	local disc = part(Vector3.new(0.2, 14, 14), CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Navy)
	disc.Shape = Enum.PartType.Cylinder
	local ring = part(Vector3.new(0.22, 14.6, 14.6), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Yellow, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	-- arka duvar: lacivert zemin üstünde ince sarı çubuklar
	part(Vector3.new(80, 30, 1), CFrame.new(0, 15, -22), Color3.fromRGB(10, 18, 56))
	for i = -9, 9 do
		part(Vector3.new(0.5, 30, 0.2), CFrame.new(i * 4, 15, -21.4), if i % 2 == 0 then C.Yellow else C.Blue).Transparency = 0.55
	end
	-- Deneme sahası: kale, çizgiler, pas mankenleri
	local T = Config.TestPitch
	local white = Color3.fromRGB(245, 245, 245)
	local function post(size: Vector3, cf: CFrame)
		local p = part(size, cf, white)
		p.Shape = Enum.PartType.Cylinder
		p.Material = Enum.Material.Metal
		return p
	end
	local gw, gh, gz = T.GoalHalfWidth, T.GoalHeight, T.GoalZ
	post(Vector3.new(gh, 0.5, 0.5), CFrame.new(-gw, gh / 2, gz) * CFrame.Angles(0, 0, math.rad(90)))
	post(Vector3.new(gh, 0.5, 0.5), CFrame.new(gw, gh / 2, gz) * CFrame.Angles(0, 0, math.rad(90)))
	post(Vector3.new(gw * 2 + 0.5, 0.5, 0.5), CFrame.new(0, gh, gz))
	local function net(size: Vector3, cf: CFrame)
		local p = part(size, cf, white, Enum.Material.ForceField)
		p.Name = "Net"
		p.Transparency = 0.6
		p.CanCollide = false
		return p
	end
	net(Vector3.new(gw * 2, gh, 0.1), CFrame.new(0, gh / 2, gz + 5))
	net(Vector3.new(0.1, gh, 5), CFrame.new(-gw, gh / 2, gz + 2.5))
	net(Vector3.new(0.1, gh, 5), CFrame.new(gw, gh / 2, gz + 2.5))
	net(Vector3.new(gw * 2, 0.1, 5), CFrame.new(0, gh, gz + 2.5))
	local function line(size: Vector3, pos: Vector3)
		local p = part(size, CFrame.new(pos), white)
		p.CanCollide = false
		p.Material = Enum.Material.SmoothPlastic
		return p
	end
	line(Vector3.new(236, 0.04, 0.4), Vector3.new(0, 0, gz)) -- kale çizgisi
	line(Vector3.new(132, 0.04, 0.4), Vector3.new(0, 0, gz - 54)) -- ceza sahası
	line(Vector3.new(0.4, 0.04, 54), Vector3.new(-66, 0, gz - 27))
	line(Vector3.new(0.4, 0.04, 54), Vector3.new(66, 0, gz - 27))
	line(Vector3.new(60, 0.04, 0.4), Vector3.new(0, 0, gz - 18)) -- altı pas
	line(Vector3.new(0.4, 0.04, 18), Vector3.new(-30, 0, gz - 9))
	line(Vector3.new(0.4, 0.04, 18), Vector3.new(30, 0, gz - 9))
	line(Vector3.new(1, 0.05, 1), Vector3.new(0, 0, gz - 36)) -- penaltı noktası
	for i, x in ipairs({ -34, 0, 34 }) do
		local d = part(Vector3.new(2, 5.6, 0.5), CFrame.new(x, 2.8, gz - 62 - (i % 2) * 14), C.Yellow)
		d.Name = "PassTarget"
		d.CanCollide = false
		part(Vector3.new(1.3, 1.3, 0.5), CFrame.new(x, 6.2, gz - 62 - (i % 2) * 14), C.Navy).CanCollide = false
	end

	local function light(pos: Vector3, c: Color3, brightness: number)
		local p = part(Vector3.new(1, 1, 1), CFrame.new(pos), c)
		p.Transparency = 1
		p.CanCollide = false
		local l = Instance.new("PointLight")
		l.Color = c
		l.Brightness = brightness
		l.Range = 40
		l.Parent = p
	end
	light(Vector3.new(6, 9, 9), Color3.fromRGB(255, 244, 226), 2.2)
	light(Vector3.new(-9, 7, -6), Color3.fromRGB(143, 176, 255), 1.6)
	light(Vector3.new(9, 4, -7), C.Yellow, 0.7)
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(4, 1, 4)
	spawn.CFrame = CFrame.new(0, -0.45, 0) * CFrame.Angles(0, math.pi, 0) -- karakter +Z'ye (kameraya) baksın
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = m
	m.Parent = Workspace
end

-- İki kaleli maç sahası
function CharacterService.BuildMatchPitch()
	if Workspace:FindFirstChild("FK_MatchPitch") then
		return
	end
	local P = Config.MatchPitch
	local m = Instance.new("Model")
	m.Name = "FK_MatchPitch"
	local white = Color3.fromRGB(245, 245, 245)
	local function part(size: Vector3, cf: CFrame, c: Color3, material: Enum.Material?, collide: boolean?)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = c
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.CanCollide = collide ~= false
		p.Parent = m
		return p
	end
	local midZ, len, wid = (P.MinZ + P.MaxZ) / 2, P.MaxZ - P.MinZ, P.MaxX - P.MinX
	part(Vector3.new(wid + 60, 1, len + 70), CFrame.new(0, P.GroundY - 0.5, midZ), Color3.fromRGB(47, 143, 67), Enum.Material.Grass)
	for i = 0, 15 do
		if i % 2 == 0 then
			part(
				Vector3.new(wid, 0.02, len / 16),
				CFrame.new(0, P.GroundY + 0.01, P.MinZ + (i + 0.5) * len / 16),
				Color3.fromRGB(56, 158, 78),
				Enum.Material.Grass,
				false
			)
		end
	end
	local y = P.GroundY + 0.03
	local function line(sx: number, sz: number, x: number, z: number)
		part(Vector3.new(sx, 0.04, sz), CFrame.new(x, y, z), white, nil, false)
	end
	line(wid, 0.4, 0, P.MinZ)
	line(wid, 0.4, 0, P.MaxZ)
	line(0.4, len, P.MinX, midZ)
	line(0.4, len, P.MaxX, midZ)
	line(wid, 0.4, 0, midZ)
	-- orta daire (24 parçalı çokgen)
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		part(
			Vector3.new(7.9, 0.04, 0.4),
			CFrame.new(math.cos(a) * 30, y, midZ + math.sin(a) * 30) * CFrame.Angles(0, -a + math.pi / 2, 0),
			white,
			nil,
			false
		)
	end
	line(1.2, 1.2, 0, midZ)
	local gw, gh = P.GoalHalfWidth, P.GoalHeight
	for _, e in ipairs({ { P.MinZ, 1 }, { P.MaxZ, -1 } }) do
		local gz, d = e[1], e[2] -- d: sahanın içine doğru yön
		line(132, 0.4, 0, gz + d * 54)
		line(0.4, 54, -66, gz + d * 27)
		line(0.4, 54, 66, gz + d * 27)
		line(60, 0.4, 0, gz + d * 18)
		line(0.4, 18, -30, gz + d * 9)
		line(0.4, 18, 30, gz + d * 9)
		line(1, 1, 0, gz + d * 36)
		for _, x in ipairs({ -gw, gw }) do
			local p =
				part(Vector3.new(gh, 0.5, 0.5), CFrame.new(x, gh / 2, gz) * CFrame.Angles(0, 0, math.rad(90)), white, Enum.Material.Metal)
			p.Shape = Enum.PartType.Cylinder
		end
		local bar = part(Vector3.new(gw * 2 + 0.5, 0.5, 0.5), CFrame.new(0, gh, gz), white, Enum.Material.Metal)
		bar.Shape = Enum.PartType.Cylinder
		local function net(size: Vector3, cf: CFrame)
			local n = part(size, cf, white, Enum.Material.ForceField, false)
			n.Name = "Net"
			n.Transparency = 0.6
		end
		net(Vector3.new(gw * 2, gh, 0.1), CFrame.new(0, gh / 2, gz - d * 5))
		net(Vector3.new(0.1, gh, 5), CFrame.new(-gw, gh / 2, gz - d * 2.5))
		net(Vector3.new(0.1, gh, 5), CFrame.new(gw, gh / 2, gz - d * 2.5))
		net(Vector3.new(gw * 2, 0.1, 5), CFrame.new(0, gh, gz - d * 2.5))
	end
	-- saha kenarı reklam panoları (sarı-lacivert)
	for i = -4, 4 do
		for _, sx in ipairs({ -1, 1 }) do
			part(
				Vector3.new(0.6, 3, 30),
				CFrame.new(sx * (P.MaxX + 12), 1.5, midZ + i * 34),
				if (i + (if sx > 0 then 1 else 0)) % 2 == 0 then C.Yellow else C.Navy,
				nil,
				false
			)
		end
	end
	m.Parent = Workspace
end

return CharacterService

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
local function paintTorso(torso: BasePart, kit, name: string, number: number, abbr: string)
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
				local sh = Instance.new("Frame")
				sh.BorderSizePixel = 0
				sh.BackgroundColor3 = C.Navy
				sh.Size = UDim2.fromScale(0.22, 0.2)
				sh.Position = UDim2.fromScale(0.13, 0.15)
				local cr = Instance.new("UICorner")
				cr.CornerRadius = UDim.new(0.25, 0)
				cr.Parent = sh
				local st = Instance.new("UIStroke")
				st.Color = C.Yellow
				st.Thickness = 2
				st.Parent = sh
				sh.Parent = sg
				text(sh, if abbr ~= "" then abbr else "FB", UDim2.fromScale(0.86, 0.7), UDim2.fromScale(0.07, 0.15), C.Yellow, C.Navy)
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

--[[
	look = {
		appearance = {...}, position, kitPattern, number, name, abbr, atFenerbahce, level
	}
]]
local function applyNow(player: Player, look)
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not hum or not character:IsDescendantOf(Workspace) then
		return
	end
	local a = look.appearance
	local B = Config.Body
	local skin = Config.SkinColors[a.skin] or Config.SkinColors[2]

	local desc = hum:GetAppliedDescription()
	desc.Shirt = 0
	desc.Pants = 0
	desc.GraphicTShirt = 0
	desc.HatAccessory = ""
	desc.HairAccessory = ""
	desc.FaceAccessory = ""
	desc.NeckAccessory = ""
	desc.ShouldersAccessory = ""
	desc.FrontAccessory = ""
	desc.BackAccessory = ""
	desc.WaistAccessory = ""
	pcall(function()
		desc:SetAccessories({}, true)
	end)
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

	local kit = Kits.For(look.position, look.kitPattern, look.atFenerbahce)
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
		paintTorso(torso, kit, look.name or "", look.number or 9, if look.atFenerbahce then "" else (look.abbr or ""))
	end

	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
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
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
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
	local disc = part(Vector3.new(0.2, 14, 14), CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Navy)
	disc.Shape = Enum.PartType.Cylinder
	local ring = part(Vector3.new(0.22, 14.6, 14.6), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Yellow, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	-- arka duvar: lacivert zemin üstünde ince sarı çubuklar
	part(Vector3.new(80, 30, 1), CFrame.new(0, 15, -22), Color3.fromRGB(10, 18, 56))
	for i = -9, 9 do
		part(Vector3.new(0.5, 30, 0.2), CFrame.new(i * 4, 15, -21.4), if i % 2 == 0 then C.Yellow else C.Blue).Transparency = 0.55
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

return CharacterService

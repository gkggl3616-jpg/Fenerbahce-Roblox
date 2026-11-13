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
local Theme = require(ReplicatedStorage.UI.Theme)

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
					f.Name = "Stripe"
					f.BorderSizePixel = 0
					f.BackgroundColor3 = kit.Stripe
					f.Size = UDim2.fromScale(0.2, 1)
					f.Position = UDim2.fromScale(i * 0.2, 0)
					f.Parent = sg
				end
			end
		elseif kit.Pattern == "Kusakli" then
			local f = Instance.new("Frame")
			f.Name = "Stripe"
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
				text(sg, Theme.Upper(name), UDim2.fromScale(0.9, 0.16), UDim2.fromScale(0.05, 0.1), kit.Ink, kit.InkStroke)
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

--------------------------------------------------------------------------------
-- Gövde: hazır R15 parçaları gizlenir, görünen her şey temel şekillerden (kutu, silindir,
-- elips) kurulur. Böylece karakter, hangi Roblox gövdesi yüklenirse yüklensin aynı görünür
-- ve bütün ölçüler iskeletin kendi parça ölçülerinden ve eklem noktalarından türetilir.
--------------------------------------------------------------------------------
local BODY_PARTS = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

-- Parçanın görevi (maçta rakip kulübün renklerine boyamak için): Shirt, Sleeve, Shorts, Sock, Trim
local function tag(p: BasePart, role: string): BasePart
	p:SetAttribute("FK", role)
	return p
end

-- Yuvarlak hacim: her ölçüde elips çizen küre ağı (baş, saç, eklem, el)
local function blob(character: Model, to: BasePart, size: Vector3, offset: CFrame, c: Color3): BasePart
	local p = weldPart(character, to, size, offset, c)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

-- Dikey silindir: parçanın kendi Y ekseninde y1..y2 arası, (x, z) kaymasıyla (kol, bacak, bant)
local function tube(character: Model, to: BasePart, y1: number, y2: number, radius: number, x: number, z: number, c: Color3): BasePart
	local len = math.max(0.02, math.abs(y1 - y2))
	return weldPart(
		character,
		to,
		Vector3.new(len, radius * 2, radius * 2),
		CFrame.new(x, (y1 + y2) / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
		c,
		Enum.PartType.Cylinder
	)
end

-- Eklem noktası: Motor6D'nin üst parçadaki (C0) ve alt parçadaki (C1) yeri
local function pivots(character: Model, name: string): (Vector3?, Vector3?)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name == name then
			return d.C0.Position, d.C1.Position
		end
	end
	return nil, nil
end

-- Başın görünen genişliği ve yüksekliği. Eski tip başta parça 2x1x1 olup ağ ölçeklidir;
-- yeni tipte parça ölçüsü doğrudan baştır.
-- Görünen baş, iskeletin baş parçasından küçüktür (sporcu oranı); aşağı kaydırılır ki boyuna otursun.
-- Döner: genişlik, yükseklik, dikey kayma
local HEAD_W, HEAD_H = 0.82, 0.88
local function headDims(head: BasePart): (number, number, number)
	local s = head.Size
	local mesh = head:FindFirstChildOfClass("SpecialMesh")
	local k = if mesh then mesh.Scale.X else 1
	local rawH = s.Y * k
	return math.min(s.X, s.Z) * k * HEAD_W, rawH * HEAD_H, -rawH * (1 - HEAD_H) * 0.45
end

-- Saç: başın ölçüsüne göre birkaç yuvarlak hacimden kurulur (ön = -Z, yüzün olduğu taraf)
local function hair(character: Model, head: BasePart, style: number, c: Color3)
	local w, h, dy = headDims(head)
	local function lock(sx: number, sy: number, sz: number, x: number, y: number, z: number): BasePart
		return blob(character, head, Vector3.new(w * sx, h * sy, w * sz), CFrame.new(w * x, h * y + dy, w * z), c)
	end
	if style == 1 then
		lock(1.0, 0.62, 1.03, 0, 0.25, 0.03).Transparency = 0.2 -- sıfıra yakın
	elseif style == 2 then
		lock(1.05, 0.66, 1.08, 0, 0.28, 0.05) -- kısa
		lock(0.86, 0.3, 0.5, 0, 0.44, -0.3) -- perçem
	elseif style == 3 then
		lock(1.09, 0.8, 1.1, 0, 0.31, 0.05) -- hacimli
		lock(0.8, 0.5, 0.6, 0, 0.54, -0.26)
	elseif style == 4 then
		lock(1.07, 0.7, 1.1, 0, 0.28, 0.06) -- uzun: enseye iner
		lock(1.02, 1.0, 0.5, 0, -0.1, 0.36)
	elseif style == 5 then
		lock(1.07, 0.7, 1.08, 0, 0.29, 0.05) -- kıvırcık: çevrede bukleler
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			lock(0.42, 0.34, 0.42, math.sin(a) * 0.4, 0.46, 0.04 + math.cos(a) * 0.4)
		end
		lock(0.5, 0.36, 0.5, 0, 0.62, 0.02)
	elseif style == 6 then
		lock(1.05, 0.66, 1.08, 0, 0.28, 0.05) -- topuz
		lock(0.44, 0.4, 0.44, 0, 0.52, 0.42)
	elseif style == 7 then
		lock(1.0, 0.56, 1.03, 0, 0.22, 0.03).Transparency = 0.25 -- yanlar kısa
		lock(0.56, 0.5, 1.02, 0, 0.49, 0.0) -- üstte uzun şerit
	end
end

-- Yüz: gözler, kaşlar, ağız ve bıyık, başın önündeki görünmez ince plakaya çizilir
-- (plaka, baş parçası hangi tipte olursa olsun yüzü doğru ölçüde tutar)
local function paintFace(character: Model, head: BasePart, face: number, beard: number, hairColor: Color3, skin: Color3)
	local w, h, dy = headDims(head)
	local plate = weldPart(character, head, Vector3.new(w * 0.84, h * 0.84, 0.02), CFrame.new(0, dy, -w * 0.53), skin)
	plate.Transparency = 1
	plate.CastShadow = false
	local sg = Instance.new("SurfaceGui")
	sg.Name = "FK_Kit"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(200, 200)
	sg.LightInfluence = 1
	sg.Parent = plate
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
	local browTilt = ({ 0, 8, -6, 12, 4, -10 })[v + 1]
	local eyeH = ({ 0.12, 0.1, 0.13, 0.09, 0.115, 0.12 })[v + 1]
	for _, sx in ipairs({ -1, 1 }) do
		local x = 0.5 + sx * 0.19
		shape(UDim2.fromScale(0.19, eyeH), UDim2.fromScale(x, 0.4), Color3.fromRGB(246, 246, 240), 0.5)
		shape(UDim2.fromScale(0.085, eyeH * 0.92), UDim2.fromScale(x + sx * 0.005, 0.4), dark, 0.5)
		shape(UDim2.fromScale(0.22, 0.04), UDim2.fromScale(x, 0.4 - eyeH * 0.5 - 0.045), hairColor:Lerp(dark, 0.5), 0.5, sx * browTilt)
	end
	local mouthW = ({ 0.24, 0.2, 0.28, 0.18, 0.26, 0.22 })[v + 1]
	if beard >= 2 then
		shape(UDim2.fromScale(0.4, 0.075), UDim2.fromScale(0.5, 0.635), hairColor, 0.5) -- bıyık
	end
	shape(UDim2.fromScale(mouthW, 0.032), UDim2.fromScale(0.5, 0.71), Color3.fromRGB(120, 60, 52), 0.5)
end

-- Gövde oranları (her biri ilgili iskelet parçasının genişliğine ya da yüksekliğine oranla)
local K = {
	ShirtW = 0.7, -- forma genişliği / üst gövde genişliği (yanlara göğüs kanatları eklenir: V gövde)
	ShirtD = 0.84,
	HipW = 0.7,
	ArmAxis = 0.33, -- kol ekseninin gövdeye doğru kayması / kol genişliği
	UpperArmR = 0.215,
	LowerArmR = 0.185,
	ShoulderW = 0.72,
	ShoulderH = 0.5,
	SleeveLen = 0.5, -- kısa kolun üst kolda kapladığı oran
	HandW = 0.36,
	HandH = 0.46,
	ThighR = 0.32,
	ShortsR = 0.415,
	ShortsLen = 0.54, -- şortun uylukta kapladığı oran
	CalfR = 0.265,
	BootW = 0.56,
}

local function buildBody(character: Model, look, kit, skin: Color3)
	local a = look.appearance
	local acc = a.accessories or {}
	local keeper = look.position == "Kaleci"
	local long = acc.UzunKol == true or keeper
	local boot = hex(a.bootColor)
	local hairColor = hex(a.hairColor)
	local glove = Color3.fromRGB(242, 242, 242)
	local function part(name: string): BasePart?
		local p = character:FindFirstChild(name)
		return if p and p:IsA("BasePart") then p else nil
	end
	for _, n in ipairs(BODY_PARTS) do
		local p = part(n)
		if p then
			p.Transparency = 1 -- hazır gövde görünmez; iskelet olarak kalır
			p.Color = skin
		end
	end
	-- kısaltmalar: role etiketli silindir / elips
	local function T(to: BasePart, y1: number, y2: number, r: number, x: number, c: Color3, role: string?): BasePart
		local p = tube(character, to, y1, y2, r, x, 0, c)
		return if role then tag(p, role) else p
	end
	local function B(to: BasePart, size: Vector3, at: Vector3, c: Color3, role: string?): BasePart
		local p = blob(character, to, size, CFrame.new(at), c)
		return if role then tag(p, role) else p
	end

	---------------------------------------------------------------- gövde ve boyun
	local ut = part("UpperTorso")
	if ut then
		local s = ut.Size
		local shirt =
			tag(weldPart(character, ut, Vector3.new(s.X * K.ShirtW, s.Y * 1.02, s.Z * K.ShirtD), CFrame.new(), kit.Shirt), "Shirt")
		paintTorso(shirt, kit, look.name or "", look.number or 9, if look.atFenerbahce then "" else (look.abbr or ""), look.crest)
		-- V gövde: göğüs kanatları üstte dışa açılır, belde daralır
		for _, sx in ipairs({ -1, 1 }) do
			tag(
				weldPart(
					character,
					ut,
					Vector3.new(s.X * 0.16, s.Y * 0.66, s.Z * K.ShirtD * 0.94),
					CFrame.new(sx * s.X * 0.36, s.Y * 0.15, 0) * CFrame.Angles(0, 0, -sx * math.rad(11)),
					kit.Shirt
				),
				"Shirt"
			)
		end
		-- omuz hattı (trapez): kutunun köşeli üstünü yumuşatır
		B(ut, Vector3.new(s.X * 0.92, s.Y * 0.3, s.Z * K.ShirtD * 0.96), Vector3.new(0, s.Y * 0.4, 0), kit.Shirt, "Shirt")
		local neck0 = pivots(character, "Neck")
		local ny = if neck0 then neck0.Y else s.Y / 2
		T(ut, ny - s.Y * 0.04, ny + s.Y * 0.2, s.X * 0.1, 0, skin) -- boyun
		T(ut, ny - s.Y * 0.02, ny + s.Y * 0.035, s.X * 0.135, 0, kit.Trim, "Trim") -- yaka
	end
	local lt = part("LowerTorso")
	if lt then
		local s = lt.Size
		tag(weldPart(character, lt, Vector3.new(s.X * K.HipW, s.Y * 1.3, s.Z * 0.87), CFrame.new(0, -s.Y * 0.1, 0), kit.Shorts), "Shorts")
		tag(weldPart(character, lt, Vector3.new(s.X * 0.34, s.Y * 1.3, s.Z * 0.74), CFrame.new(0, -s.Y * 1.0, 0), kit.Shorts), "Shorts")
	end

	---------------------------------------------------------------- baş, yüz, saç
	local head = part("Head")
	if head then
		local w, h, dy = headDims(head)
		local function H(x: number, y: number, z: number): Vector3
			return Vector3.new(x, y + dy, z)
		end
		B(head, Vector3.new(w * 0.97, h * 1.05, w), H(0, 0, 0), skin)
		-- çene: yüzün alt kısmını daraltır (yumurta biçimi)
		B(head, Vector3.new(w * 0.8, h * 0.5, w * 0.82), H(0, -h * 0.25, -w * 0.06), skin)
		paintFace(character, head, a.face or 1, a.beard or 0, hairColor, skin)
		-- burun ve kulaklar
		B(head, Vector3.new(w * 0.15, h * 0.2, w * 0.16), H(0, -h * 0.03, -w * 0.49), skin:Lerp(Color3.new(0, 0, 0), 0.07))
		for _, sx in ipairs({ -1, 1 }) do
			B(head, Vector3.new(w * 0.1, h * 0.22, w * 0.18), H(sx * w * 0.485, h * 0.02, w * 0.02), skin)
		end
		-- sakal: çeneyi önden saran kabuk; enseye taşmasın diye öne kaydırılır (1 kirli, 2 sakal, 3 gür)
		local beard = a.beard or 0
		if beard >= 1 then
			local big = beard >= 3
			-- derinliği kısa tutulur ki sakal kulakların gerisine, enseye sarmasın
			local shell = B(
				head,
				Vector3.new(w * (if big then 1.04 else 0.975), h * (if big then 0.72 else 0.6), w * (if big then 0.78 else 0.7)),
				H(0, -h * (if big then 0.23 else 0.2), -w * (if big then 0.18 else 0.17)),
				hairColor
			)
			if beard == 1 then
				shell.Transparency = 0.55
			end
		end
		hair(character, head, a.hairStyle, hairColor)
		if acc.SacBandi then
			tag(tube(character, head, h * 0.2 + dy, h * 0.31 + dy, w * 0.535, 0, w * 0.02, C.Yellow), "Trim")
		end
	end

	---------------------------------------------------------------- kollar ve bacaklar
	for _, side in ipairs({ "Left", "Right" }) do
		local ua, la, hand = part(side .. "UpperArm"), part(side .. "LowerArm"), part(side .. "Hand")
		local _, shoulder1 = pivots(character, side .. "Shoulder")
		local elbow0, elbow1 = pivots(character, side .. "Elbow")
		local wrist0, wrist1 = pivots(character, side .. "Wrist")
		-- içe (gövdeye) doğru yön: omuz ekleminin üst koldaki yeri gövde tarafındadır
		local inward = if side == "Left" then 1 else -1
		if shoulder1 and math.abs(shoulder1.X) > 0.01 then
			inward = if shoulder1.X > 0 then 1 else -1
		end
		if ua then
			local s = ua.Size
			local ax = inward * s.X * K.ArmAxis
			local top = if shoulder1 then shoulder1.Y else s.Y * 0.34
			local bottom = if elbow0 then elbow0.Y else -s.Y * 0.29
			local r = s.X * K.UpperArmR
			B(
				ua,
				Vector3.new(s.X * K.ShoulderW, s.X * K.ShoulderH, s.Z * 0.7),
				Vector3.new(ax + inward * s.X * 0.03, top - s.X * 0.02, 0),
				kit.Sleeve,
				"Sleeve"
			)
			if long then
				T(ua, top, bottom, r * 1.12, ax, kit.Sleeve, "Sleeve")
				B(ua, Vector3.new(r * 2.3, r * 2.3, r * 2.3), Vector3.new(ax, bottom, 0), kit.Sleeve, "Sleeve") -- dirsek
			else
				T(ua, top, bottom, r, ax, skin)
				local hem = top - (top - bottom) * K.SleeveLen
				T(ua, top + s.X * 0.03, hem, r * 1.22, ax, kit.Sleeve, "Sleeve") -- kısa kol
				T(ua, hem + s.X * 0.05, hem - s.X * 0.02, r * 1.28, ax, kit.Trim, "Trim") -- kol ağzı
				B(ua, Vector3.new(r * 2.04, r * 2.04, r * 2.04), Vector3.new(ax, bottom, 0), skin) -- dirsek
			end
			-- pazı: kısa kolun altında görünen kas hacmi
			local bicep = top - (top - bottom) * 0.62
			B(
				ua,
				Vector3.new(r * 2.35, (top - bottom) * 0.52, r * 2.3),
				Vector3.new(ax, bicep, -r * 0.08),
				if long then kit.Sleeve else skin,
				if long then "Sleeve" else nil
			)
			if side == "Left" and (look.level or 1) >= Config.CaptainBandLevel then
				local mid = top - (top - bottom) * 0.3
				T(ua, mid + s.X * 0.08, mid - s.X * 0.08, r * 1.34, ax, C.Gold) -- kaptanlık bandı
			end
		end
		if la then
			local s = la.Size
			local ax = inward * s.X * K.ArmAxis
			local top = if elbow1 then elbow1.Y else s.Y * 0.25
			local bottom = if wrist0 then wrist0.Y else -s.Y * 0.47
			local r = s.X * K.LowerArmR
			if long then
				T(la, top, bottom, r * 1.12, ax, kit.Sleeve, "Sleeve")
				T(la, bottom + s.X * 0.08, bottom, r * 1.2, ax, kit.Trim, "Trim") -- manşet
			else
				T(la, top, bottom, r, ax, skin)
			end
			-- ön kol kası: dirseğe yakın kalın, bileğe doğru incelir
			B(
				la,
				Vector3.new(r * 2.3, (top - bottom) * 0.55, r * 2.25),
				Vector3.new(ax, top - (top - bottom) * 0.32, 0),
				if long then kit.Sleeve else skin,
				if long then "Sleeve" else nil
			)
			if acc.Bileklik and side == "Right" and not keeper then
				T(la, bottom + s.X * 0.2, bottom + s.X * 0.06, r * 1.22, ax, C.Yellow)
			end
			if keeper then
				T(la, bottom + s.X * 0.16, bottom - s.X * 0.02, r * 1.3, ax, glove) -- eldiven bileği
			end
		end
		if hand then
			local s = hand.Size
			local ax = inward * s.X * K.ArmAxis
			local wy = if wrist1 then wrist1.Y else s.Y * 0.4
			if keeper then
				B(hand, Vector3.new(s.X * 0.46, s.X * 0.52, s.X * 0.5), Vector3.new(ax, wy - s.X * 0.2, 0), glove)
			else
				B(hand, Vector3.new(s.X * K.HandW, s.X * K.HandH, s.X * 0.4), Vector3.new(ax, wy - s.X * 0.18, 0), skin)
			end
		end

		local ul, ll, foot = part(side .. "UpperLeg"), part(side .. "LowerLeg"), part(side .. "Foot")
		local _, hip1 = pivots(character, side .. "Hip")
		local knee0, knee1 = pivots(character, side .. "Knee")
		local ankle0 = pivots(character, side .. "Ankle")
		if ul then
			local s = ul.Size
			local top = if hip1 then hip1.Y else s.Y * 0.35
			local bottom = if knee0 then knee0.Y else -s.Y * 0.33
			local r = s.X * K.ThighR
			T(ul, top, bottom, r, 0, skin) -- uyluk
			B(ul, Vector3.new(r * 2.3, (top - bottom) * 0.86, r * 2.3), Vector3.new(0, top - (top - bottom) * 0.48, -r * 0.08), skin) -- ön bacak kası
			local hem = top - (top - bottom) * K.ShortsLen
			T(ul, top + s.X * 0.16, hem, s.X * K.ShortsR, 0, kit.Shorts, "Shorts") -- şort paçası
			T(ul, hem + s.X * 0.05, hem - s.X * 0.015, s.X * (K.ShortsR + 0.012), 0, kit.Trim, "Trim")
			B(ul, Vector3.new(r * 1.96, r * 1.96, r * 1.96), Vector3.new(0, bottom, 0), skin) -- diz
		end
		if ll then
			local s = ll.Size
			local top = if knee1 then knee1.Y else s.Y * 0.32
			local bottom = if ankle0 then ankle0.Y else -s.Y * 0.46
			local r = s.X * K.CalfR
			T(ll, top, bottom, r, 0, skin) -- baldır
			local calfY = top - (top - bottom) * 0.32
			local sockOverCalf = not acc.KisaTozluk
			B(
				ll,
				Vector3.new(r * 2.2, (top - bottom) * 0.5, r * 2.35),
				Vector3.new(0, calfY, r * 0.18),
				if sockOverCalf then kit.Sock else skin,
				if sockOverCalf then "Sock" else nil
			) -- baldır kası
			local sockTop = if acc.KisaTozluk then bottom + (top - bottom) * 0.42 else top - s.X * 0.17
			T(ll, sockTop, bottom, r * 1.08, 0, kit.Sock, "Sock") -- çorap
			T(ll, sockTop + s.X * 0.02, sockTop - s.X * 0.07, r * 1.15, 0, kit.Trim, "Trim")
			T(ll, bottom + s.X * 0.13, -s.Y / 2, r * 1.17, 0, boot) -- krampon boğazı
		end
		if foot then
			local s = foot.Size
			-- krampon: yuvarlatılmış gövde (burun öne uzanır) + topuk
			B(foot, Vector3.new(s.X * K.BootW, s.Y * 1.35, s.Z * 1.12), Vector3.new(0, s.Y * 0.08, -s.Z * 0.2), boot)
			weldPart(character, foot, Vector3.new(s.X * (K.BootW - 0.04), s.Y * 0.9, s.Z * 0.36), CFrame.new(0, 0, s.Z * 0.22), boot) -- topuk
			weldPart(
				character,
				foot,
				Vector3.new(s.X * (K.BootW + 0.01), s.Y * 0.16, s.Z * 1.0),
				CFrame.new(0, -s.Y * 0.43, -s.Z * 0.15),
				Color3.fromRGB(226, 226, 226)
			) -- taban
		end
	end
end

--[[
	look = {
		appearance = {...}, position, kitPattern, number, name, abbr, atFenerbahce, level, crest
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
	if not ok then
		-- gövde paketi yüklenemedi: standart gövdeyle yeniden dene
		for key in pairs(B.Parts) do
			(desc :: any)[key] = 0
		end
		ok = pcall(function()
			hum:ApplyDescription(desc)
		end)
	end
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
	buildBody(character, look, kit, skin)
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

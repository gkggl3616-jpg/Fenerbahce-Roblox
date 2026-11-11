--[[
	Stadium
	Kulübün kademesine göre maç sahasının çevresini kurar: tribünler, seyirci, çatı,
	projektörler, LED panolar, dev ekran, şehir ve ağaçlar. Işık ve atmosfer de buradan ayarlanır.

	Her şey istemcide kurulur (tek kişilik maç): her oyuncu kendi kulübünün stadını görür.
	Model yüklemeden, yalnızca parçalarla ve yüzey arayüzleriyle çalışır.

	Stadium.Build(tier, info)   -> stadı kurar, ışığı ayarlar
	Stadium.Clear()             -> stadı kaldırır, lobi ışığına döner
	Stadium.Lobby()             -> lobi/deneme sahası ışığı ve çevresi
	Stadium.Cheer()             -> seyirci zıplar
	Stadium.Screen(title, text, color, hold) -> dev ekranda olay gösterir (ekranı olan statlarda)
	Stadium.Score(home, away, homeGoals, awayGoals, minute) -> skor tabelası / dev ekran
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.UI.Theme)

local Stadium = {}

local C = Config.Colors
local rgb = Color3.fromRGB
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

local CONCRETE = rgb(150, 154, 162)
local DARK = rgb(52, 57, 72)
local SKIN = rgb(226, 184, 150)

local current: Model? = nil
local crowdLayers: { Frame } = {}
local screens: { { title: TextLabel, text: TextLabel, score: TextLabel, bar: Frame } } = {}
local boards: { TextLabel } = {}
local screenToken = 0

--------------------------------------------------------------------------------
-- Işık ve atmosfer
--------------------------------------------------------------------------------
local MOODS = {
	Lobi = {
		Clock = 14.2,
		Brightness = 3,
		Ambient = rgb(120, 126, 150),
		Outdoor = rgb(150, 155, 170),
		Top = rgb(255, 244, 220),
		Exposure = 0.15,
		Density = 0.28,
		Haze = 1.2,
		Air = rgb(205, 220, 245),
		Decay = rgb(120, 150, 200),
		Bloom = 0.35,
		Saturation = 0.12,
		Contrast = 0.06,
		Tint = rgb(255, 255, 255),
		Rays = 0.08,
	},
	BulutluGunduz = {
		Clock = 13,
		Brightness = 2.2,
		Ambient = rgb(140, 144, 150),
		Outdoor = rgb(165, 168, 172),
		Top = rgb(235, 238, 245),
		Exposure = 0.1,
		Density = 0.42,
		Haze = 2.4,
		Air = rgb(200, 205, 212),
		Decay = rgb(150, 156, 165),
		Bloom = 0.2,
		Saturation = -0.04,
		Contrast = 0.04,
		Tint = rgb(246, 248, 255),
		Rays = 0.02,
	},
	OgledenSonra = {
		Clock = 15.4,
		Brightness = 3.2,
		Ambient = rgb(118, 122, 140),
		Outdoor = rgb(150, 152, 160),
		Top = rgb(255, 238, 205),
		Exposure = 0.12,
		Density = 0.3,
		Haze = 1.4,
		Air = rgb(210, 222, 240),
		Decay = rgb(140, 160, 200),
		Bloom = 0.3,
		Saturation = 0.14,
		Contrast = 0.07,
		Tint = rgb(255, 252, 244),
		Rays = 0.1,
	},
	GunBatimi = {
		Clock = 17.55,
		Brightness = 2.8,
		Ambient = rgb(128, 112, 120),
		Outdoor = rgb(160, 138, 130),
		Top = rgb(255, 196, 130),
		Exposure = 0.2,
		Density = 0.34,
		Haze = 2,
		Air = rgb(255, 205, 160),
		Decay = rgb(240, 130, 70),
		Bloom = 0.5,
		Saturation = 0.18,
		Contrast = 0.08,
		Tint = rgb(255, 244, 232),
		Rays = 0.18,
	},
	Alacakaranlik = {
		Clock = 18.25,
		Brightness = 2.2,
		Ambient = rgb(128, 128, 150),
		Outdoor = rgb(150, 150, 172),
		Top = rgb(255, 214, 180),
		Exposure = 0.35,
		Density = 0.32,
		Haze = 1.8,
		Air = rgb(170, 170, 215),
		Decay = rgb(200, 110, 110),
		Bloom = 0.65,
		Saturation = 0.16,
		Contrast = 0.08,
		Tint = rgb(246, 244, 255),
		Rays = 0.06,
	},
	-- Gece: ay tepeye yakın tutulur ve güçlendirilir; saha projektör altındaymış gibi aydınlık kalır
	Gece = {
		Clock = 0.4,
		Brightness = 3.4,
		Ambient = rgb(118, 124, 150),
		Outdoor = rgb(132, 138, 165),
		Top = rgb(232, 240, 255),
		Exposure = 0.45,
		Density = 0.3,
		Haze = 1.6,
		Air = rgb(70, 84, 130),
		Decay = rgb(30, 40, 80),
		Bloom = 0.8,
		Saturation = 0.2,
		Contrast = 0.1,
		Tint = rgb(244, 247, 255),
		Rays = 0,
	},
	GeceMaci = {
		Clock = 0.2,
		Brightness = 3.8,
		Ambient = rgb(124, 130, 158),
		Outdoor = rgb(140, 146, 176),
		Top = rgb(238, 244, 255),
		Exposure = 0.5,
		Density = 0.33,
		Haze = 1.9,
		Air = rgb(60, 76, 140),
		Decay = rgb(24, 34, 86),
		Bloom = 0.95,
		Saturation = 0.24,
		Contrast = 0.12,
		Tint = rgb(246, 248, 255),
		Rays = 0,
	},
}

local function effect(class: string): Instance
	local name = "FK_" .. class
	local e = Lighting:FindFirstChild(name)
	if not e then
		e = Instance.new(class)
		e.Name = name
		e.Parent = Lighting
	end
	return e
end

local function mood(name: string)
	local m = MOODS[name] or MOODS.Lobi
	Lighting.ClockTime = m.Clock
	Lighting.GeographicLatitude = 28
	Lighting.Brightness = m.Brightness
	Lighting.Ambient = m.Ambient
	Lighting.OutdoorAmbient = m.Outdoor
	Lighting.ColorShift_Top = m.Top
	Lighting.ColorShift_Bottom = rgb(40, 60, 40)
	Lighting.ExposureCompensation = m.Exposure
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.FogEnd = 100000

	local a = effect("Atmosphere") :: any
	a.Density = m.Density
	a.Offset = 0.1
	a.Haze = m.Haze
	a.Glare = 0.2
	a.Color = m.Air
	a.Decay = m.Decay

	local b = effect("BloomEffect") :: any
	b.Intensity = m.Bloom
	b.Size = 28
	b.Threshold = 1.6

	local cc = effect("ColorCorrectionEffect") :: any
	cc.Saturation = m.Saturation
	cc.Contrast = m.Contrast
	cc.Brightness = 0.02
	cc.TintColor = m.Tint

	local r = effect("SunRaysEffect") :: any
	r.Intensity = m.Rays
	r.Spread = 0.6
end

--------------------------------------------------------------------------------
-- Yardımcılar
--------------------------------------------------------------------------------
-- Aynı kademe her zaman aynı stadı versin diye kendi sayı üretecimiz
local function rng(seed: number): () -> number
	local s = seed % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return function()
		s = (s * 16807) % 2147483647
		return (s - 1) / 2147483646
	end
end

local function builder(model: Model)
	return function(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shadow: boolean?): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = shadow == true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
end

local function surface(part: BasePart, pps: number, bright: number?): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps
	g.LightInfluence = if bright then 0 else 1
	g.Brightness = bright or 1
	g.ResetOnSpawn = false
	g.Parent = part
	return g
end

local function label(parent: Instance, text: string, color: Color3, size: UDim2?, pos: UDim2?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size or UDim2.fromScale(1, 1)
	t.Position = pos or UDim2.fromScale(0, 0)
	t.FontFace = FONT
	t.Text = text
	t.TextColor3 = color
	t.TextScaled = true
	t.Parent = parent
	return t
end

--------------------------------------------------------------------------------
-- Stat kurucu
--------------------------------------------------------------------------------
type Info = { club: string?, abbr: string?, facilities: { [string]: number }?, stadium: string? }

local function build(model: Model, tier: number, info: Info, pitch, withMood: boolean)
	local part = builder(model)
	local R = rng(tier * 7919 + 13)
	local night = tier >= 5
	local dusk = tier == 4
	local midZ = (pitch.MinZ + pitch.MaxZ) / 2
	local hx, hz = (pitch.MaxX - pitch.MinX) / 2, (pitch.MaxZ - pitch.MinZ) / 2
	local gy = pitch.GroundY
	local fac = info.facilities or {}
	local clubName = if info.club and info.club ~= "" then Theme.Upper(info.club) else "FENER KARİYER"

	-- Tribün çerçeveleri: yerel +Z sahadan dışarı bakar, başlangıç noktası çizginin ortasıdır
	local FR = {
		N = CFrame.new(0, gy, midZ + hz),
		S = CFrame.new(0, gy, midZ - hz) * CFrame.Angles(0, math.pi, 0),
		E = CFrame.new(hx, gy, midZ) * CFrame.Angles(0, math.pi / 2, 0),
		W = CFrame.new(-hx, gy, midZ) * CFrame.Angles(0, -math.pi / 2, 0),
	}
	local HALF = { N = hx, S = hx, E = hz, W = hz }
	local function corner(sx: number, sz: number): CFrame
		return CFrame.new(sx * hx, gy, midZ + sz * hz) * CFrame.Angles(0, math.atan2(sx, sz), 0)
	end

	local seatA = if tier >= 6 then C.Navy elseif tier >= 4 then rgb(24, 40, 110) else rgb(70, 82, 110)
	local seatB = if tier >= 6 then C.Yellow elseif tier >= 4 then rgb(230, 205, 30) else rgb(96, 104, 124)
	local wallC = if tier >= 6 then rgb(22, 30, 78) elseif tier >= 4 then rgb(70, 76, 96) else CONCRETE
	local shirts = { C.Yellow, C.Navy, rgb(245, 245, 245) }

	-- Seyirci: eğimli koltuk yüzeyine noktalarla çizilir (gövde + baş), iki katman şaşırtmalı
	local function crowd(slab: Part, lenPx: number, heightPx: number, density: number)
		local g = surface(slab, 10)
		local ts = 38
		local cols = math.max(4, math.floor(lenPx / (ts * 0.6)))
		local rows = math.max(1, math.floor(heightPx / (ts * 1.32)))
		for layer = 0, 1 do
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromScale(1, 1)
			holder.Position = UDim2.fromOffset(layer * ts * 0.3, layer * ts * 0.66)
			holder.Parent = g
			local body = { {}, {}, {} }
			local head = {}
			for _ = 1, rows do
				local line = { {}, {}, {} }
				local hl = {}
				for c = 1, cols do
					local who = 0
					if R() < density then
						local r = R()
						who = if r < 0.5 then 1 elseif r < 0.82 then 2 else 3
					end
					for k = 1, 3 do
						line[k][c] = if who == k then "•" else " "
					end
					hl[c] = if who > 0 then "•" else " "
				end
				for k = 1, 3 do
					table.insert(body[k], table.concat(line[k]))
				end
				table.insert(head, table.concat(hl))
			end
			local function dots(lines: { string }, color: Color3, dy: number)
				local t = Instance.new("TextLabel")
				t.BackgroundTransparency = 1
				t.Size = UDim2.fromScale(1, 1)
				t.Position = UDim2.fromOffset(0, dy)
				t.FontFace = MONO
				t.TextSize = ts
				t.TextColor3 = color
				t.TextXAlignment = Enum.TextXAlignment.Left
				t.TextYAlignment = Enum.TextYAlignment.Top
				t.Text = table.concat(lines, "\n")
				t.Parent = holder
			end
			for k = 1, 3 do
				dots(body[k], shirts[k], 0)
			end
			dots(head, SKIN, -ts * 0.24)
			table.insert(crowdLayers, holder)
		end
	end

	--[[ Bir tribün bloğu.
		len: uzunluk, margin: çizgiden uzaklık, depth: derinlik, y0: ön yükseklik, rise: yükselme,
		density: doluluk (0-1), solid: altı dolu mu, offset: uzunluk ekseninde kaydırma ]]
	local function stand(frame: CFrame, o)
		local len, margin, depth, y0, rise = o.len, o.margin, o.depth, o.y0, o.rise
		local off = o.offset or 0
		local a = math.atan2(rise, depth)
		local slope = math.sqrt(depth * depth + rise * rise)
		local segs = math.max(1, math.ceil(len / 100))
		local segLen = len / segs
		for i = 1, segs do
			local x = off - len / 2 + (i - 0.5) * segLen
			local slab = part(
				Vector3.new(segLen, slope, 0.6),
				frame * CFrame.new(x, y0 + rise / 2, margin + depth / 2) * CFrame.Angles(math.pi / 2 - a, 0, 0),
				if (i + (o.flip or 0)) % 2 == 0 then seatA else seatB,
				Enum.Material.SmoothPlastic,
				true
			)
			slab.Name = "Seats"
			if o.density and o.density > 0 then
				crowd(slab, segLen * 10, slope * 10, o.density)
			end
		end
		-- ön duvar
		part(Vector3.new(len, y0 + 1.2, 1), frame * CFrame.new(off, (y0 + 1.2) / 2, margin - 0.5), wallC, Enum.Material.Concrete, true)
		if o.solid ~= false then
			-- altını dolduran basamaklı gövde
			for k = 1, 3 do
				local h = y0 + rise * k / 4 - 0.8
				if h > 0.5 then
					part(
						Vector3.new(len, h, depth / 4),
						frame * CFrame.new(off, h / 2, margin + depth * (k + 0.5) / 4),
						wallC,
						Enum.Material.Concrete,
						false
					)
				end
			end
		else
			-- üst kat: alt yüzey ve kirişler
			part(
				Vector3.new(len, slope, 1.6),
				frame * CFrame.new(off, y0 + rise / 2 - 1.3, margin + depth / 2 + 0.6) * CFrame.Angles(math.pi / 2 - a, 0, 0),
				DARK,
				Enum.Material.Concrete,
				true
			)
			part(Vector3.new(len, 2.6, 1.2), frame * CFrame.new(off, y0 - 0.2, margin - 0.4), if tier >= 6 then C.Yellow else wallC)
		end
		-- arka duvar
		local top = y0 + rise
		part(
			Vector3.new(len, top + 4, 1.4),
			frame * CFrame.new(off, (top + 4) / 2, margin + depth + 0.7),
			wallC,
			Enum.Material.Concrete,
			true
		)
		return top, margin + depth
	end

	-- Çatı: arkadan öne uzanan konsol, ön kenarında sarı şerit
	local function roof(frame: CFrame, len: number, zFront: number, zBack: number, y: number, glow: boolean)
		local span = zBack - zFront + 4
		local tilt = math.rad(5)
		local cf = frame * CFrame.new(0, y, (zFront + zBack) / 2 + 2) * CFrame.Angles(-tilt, 0, 0)
		part(Vector3.new(len, 1.2, span), cf, if tier >= 5 then rgb(176, 184, 204) else rgb(140, 146, 158), Enum.Material.Metal, true)
		local edge = part(
			Vector3.new(len, 2.2, 0.8),
			cf * CFrame.new(0, -0.5, -span / 2),
			C.Yellow,
			if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		)
		edge.Name = "RoofEdge"
		if glow then
			-- çatı altı ışık hattı
			part(Vector3.new(len * 0.96, 0.5, 1.6), cf * CFrame.new(0, -1, -span / 2 + 3), rgb(255, 250, 235), Enum.Material.Neon)
		end
		local n = math.max(2, math.floor(len / 60))
		for i = 0, n do
			local x = -len / 2 + 3 + (len - 6) * i / n
			part(Vector3.new(1.6, y, 1.6), frame * CFrame.new(x, y / 2, zBack + 3), DARK, Enum.Material.Metal, true)
			-- çapraz kiriş
			part(Vector3.new(0.8, 0.8, span * 0.7), cf * CFrame.new(x, -1.2, span * 0.12), DARK, Enum.Material.Metal)
		end
	end

	-- Projektör direği
	local function tower(x: number, z: number, h: number, head: number, on: boolean)
		local pos = Vector3.new(x, gy, midZ + z)
		local look = CFrame.lookAt(pos + Vector3.new(0, h, 0), Vector3.new(0, gy + h * 0.2, midZ))
		local pole = part(
			Vector3.new(h, 2.2, 2.2),
			CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			DARK,
			Enum.Material.Metal,
			true
		)
		pole.Shape = Enum.PartType.Cylinder
		part(Vector3.new(head * 1.5, head, 1.2), look, rgb(40, 44, 54), Enum.Material.Metal, true)
		local lamp = part(
			Vector3.new(head * 1.5 - 1, head - 1, 0.4),
			look * CFrame.new(0, 0, -0.7),
			if on then rgb(255, 250, 232) else rgb(200, 205, 212),
			if on then Enum.Material.Neon else Enum.Material.Glass
		)
		if on then
			local l = Instance.new("SpotLight")
			l.Face = Enum.NormalId.Front
			l.Angle = 70
			l.Range = 60
			l.Brightness = 3
			l.Color = rgb(255, 248, 230)
			l.Parent = lamp
		end
	end

	-- Sahaya bakan tabela (yazı önden okunur)
	local function sign(cf: CFrame, w: number, h: number, text: string, fg: Color3, bg: Color3, glow: boolean?): TextLabel
		local p = part(Vector3.new(w, h, 0.5), cf, bg, if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic)
		local g = surface(p, math.clamp(1200 / w, 4, 30), if glow then 1.6 else nil)
		return label(g, text, fg, UDim2.fromScale(0.94, 0.8), UDim2.fromScale(0.03, 0.1))
	end

	-- Dev ekran / skor tabelası
	local function screen(cf: CFrame, w: number, h: number, big: boolean)
		part(Vector3.new(w + 3, h + 3, 1.4), cf * CFrame.new(0, 0, 0.9), rgb(18, 20, 28), Enum.Material.Metal, true)
		local p = part(Vector3.new(w, h, 0.4), cf, rgb(6, 10, 30), Enum.Material.SmoothPlastic)
		local g = surface(p, math.clamp(1100 / w, 5, 24), 1.8)
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = rgb(8, 14, 46)
		bg.BorderSizePixel = 0
		bg.Parent = g
		local grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Color = ColorSequence.new(rgb(20, 34, 104), rgb(5, 9, 30))
		grad.Parent = bg
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(1, 0.05)
		bar.BackgroundColor3 = C.Yellow
		bar.BorderSizePixel = 0
		bar.Parent = bg
		local title = label(bg, if big then clubName else "SKOR", C.Yellow, UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.05, 0.08))
		local score = label(bg, "0 - 0", C.White, UDim2.fromScale(0.9, 0.42), UDim2.fromScale(0.05, 0.3))
		local text = label(bg, "", rgb(200, 210, 245), UDim2.fromScale(0.9, 0.18), UDim2.fromScale(0.05, 0.76))
		if big then
			table.insert(screens, { title = title, text = text, score = score, bar = bar })
		else
			table.insert(boards, score)
			title.Text = clubName
			text.Text = info.stadium or ""
		end
	end

	-- Çevre: bina, ağaç, çit
	local function city(n: number, rmin: number, rmax: number, hmin: number, hmax: number)
		local tones = { rgb(196, 188, 172), rgb(168, 172, 180), rgb(206, 196, 178), rgb(150, 156, 170), rgb(182, 164, 150) }
		for _ = 1, n do
			local a = R() * math.pi * 2
			local r = rmin + R() * (rmax - rmin)
			local w, d, h = 26 + R() * 34, 26 + R() * 30, hmin + R() * (hmax - hmin)
			local cf = CFrame.new(math.cos(a) * r, gy, midZ + math.sin(a) * r * 1.15)
				* CFrame.Angles(0, math.floor(R() * 4) * math.pi / 2 + (R() - 0.5) * 0.3, 0)
			local tone = tones[1 + math.floor(R() * #tones)]
			part(
				Vector3.new(w, h, d),
				cf * CFrame.new(0, h / 2, 0),
				if night then tone:Lerp(rgb(30, 36, 60), 0.55) else tone,
				Enum.Material.Concrete,
				not night
			)
			part(Vector3.new(w + 1.5, 1.2, d + 1.5), cf * CFrame.new(0, h + 0.6, 0), DARK, Enum.Material.Concrete)
			-- pencere şeritleri
			local floors = math.min(5, math.floor(h / 14))
			for f = 1, floors do
				local lit = (night or dusk) and R() < 0.7
				local wc = if lit then rgb(255, 214, 140) else rgb(70, 88, 120)
				local y = h * f / (floors + 1)
				local s = part(
					Vector3.new(w + 0.3, 3.2, d + 0.3),
					cf * CFrame.new(0, y, 0),
					wc,
					if lit then Enum.Material.Neon else Enum.Material.Glass
				)
				s.Transparency = if lit then 0.15 else 0
			end
		end
	end

	local function trees(n: number, rmin: number, rmax: number)
		for _ = 1, n do
			local a = R() * math.pi * 2
			local r = rmin + R() * (rmax - rmin)
			local x, z = math.cos(a) * r, midZ + math.sin(a) * r * 1.2
			local h = 16 + R() * 12
			local trunk = part(
				Vector3.new(h, 2.4, 2.4),
				CFrame.new(x, gy + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
				rgb(92, 66, 44),
				Enum.Material.Wood,
				true
			)
			trunk.Shape = Enum.PartType.Cylinder
			local g = if night then rgb(28, 62, 44) else rgb(52 + R() * 24, 122 + R() * 30, 58)
			for k = 0, 2 do
				local s = (15 - k * 3) + R() * 4
				local leaf = part(
					Vector3.new(s, s, s),
					CFrame.new(x + (R() - 0.5) * 5, gy + h + k * 5 - 2, z + (R() - 0.5) * 5),
					g,
					Enum.Material.Grass,
					true
				)
				leaf.Shape = Enum.PartType.Ball
			end
		end
	end

	local function fence(mx: number, mz: number, h: number)
		local c = rgb(120, 126, 132)
		for _, sx in ipairs({ -1, 1 }) do
			local f = part(Vector3.new(0.3, h, (hz + mz) * 2), CFrame.new(sx * (hx + mx), gy + h / 2, midZ), c, Enum.Material.DiamondPlate)
			f.Transparency = 0.55
		end
		for _, sz in ipairs({ -1, 1 }) do
			local f =
				part(Vector3.new((hx + mx) * 2, h, 0.3), CFrame.new(0, gy + h / 2, midZ + sz * (hz + mz)), c, Enum.Material.DiamondPlate)
			f.Transparency = 0.55
		end
		local n = 14
		for i = 0, n do
			for _, sx in ipairs({ -1, 1 }) do
				part(
					Vector3.new(0.6, h + 1, 0.6),
					CFrame.new(sx * (hx + mx), gy + (h + 1) / 2, midZ - hz - mz + (hz + mz) * 2 * i / n),
					DARK,
					Enum.Material.Metal
				)
			end
		end
	end

	-- LED pano hattı (kademe 3 ve üstü): parlayan şeritler ve kayan yazı
	local function led(frame: CFrame, len: number, margin: number)
		local words = { clubName, "FENER KARİYER", "SARI LACİVERT", Theme.Upper(info.stadium or "STADYUM"), "1907" }
		local n = math.max(2, math.floor(len / 52))
		local w = len / n
		for i = 1, n do
			local x = -len / 2 + (i - 0.5) * w
			local yellow = i % 2 == 0
			sign(
				frame * CFrame.new(x, 2, margin),
				w - 0.6,
				3.4,
				words[1 + (i % #words)],
				if yellow then C.Navy else C.Yellow,
				if yellow then C.Yellow else rgb(14, 26, 92),
				true
			)
		end
	end

	------------------------------------------------------------------ zemin
	local groundC = if tier == 1 then rgb(122, 116, 96) elseif tier <= 3 then rgb(92, 122, 78) else rgb(56, 60, 70)
	part(
		Vector3.new(2400, 1, 2400),
		CFrame.new(0, gy - 1.2, midZ),
		groundC,
		if tier <= 3 then Enum.Material.Grass else Enum.Material.Asphalt
	)
	if tier >= 2 then
		-- saha çevresi koşu yolu / beton
		part(
			Vector3.new(hx * 2 + 56, 0.2, hz * 2 + 66),
			CFrame.new(0, gy - 0.12, midZ),
			if tier >= 4 then rgb(64, 70, 84) else rgb(150, 92, 74),
			Enum.Material.Concrete
		)
	end

	if tier == 1 then
		-- yıpranmış çim: kale önleri ve orta saha toprak
		local dirt = rgb(132, 110, 76)
		for _, s in ipairs({ { 0, -hz + 14, 34, 22 }, { 0, hz - 14, 34, 22 }, { 0, 0, 22, 22 }, { -50, 60, 26, 16 }, { 56, -70, 30, 18 } }) do
			local d = part(
				Vector3.new(0.05, s[4] * 2, s[3] * 2),
				CFrame.new(s[1], gy + 0.02, midZ + s[2]) * CFrame.Angles(0, 0, math.pi / 2),
				dirt,
				Enum.Material.Ground
			)
			d.Shape = Enum.PartType.Cylinder
			d.Transparency = 0.35
		end
	end

	------------------------------------------------------------------ kademeler
	local ext = 60 -- stadın en dış yarıçapı için pay
	local glow = night
	if tier == 1 then
		-- Mahalle sahası: tek küçük tribün, tel örgü, kulüp binası
		stand(FR.W, { len = 110, margin = 22, depth = 12, y0 = 2, rise = 6, density = 0.22 })
		if (fac.TribunEki or 0) >= 1 then
			stand(FR.E, { len = 80 + 40 * fac.TribunEki, margin = 22, depth = 10, y0 = 2, rise = 5, density = 0.2 })
		end
		fence(18, 20, 9)
		-- kulüp binası
		local hut = CFrame.new(-hx - 52, gy, midZ - 96)
		part(Vector3.new(36, 13, 50), hut * CFrame.new(0, 6.5, 0), rgb(214, 206, 188), Enum.Material.Concrete, true)
		part(Vector3.new(40, 1.4, 54), hut * CFrame.new(0, 13.7, 0), rgb(140, 62, 50), Enum.Material.Slate, true)
		sign(hut * CFrame.new(18.4, 9, 0) * CFrame.Angles(0, -math.pi / 2, 0), 40, 5, clubName, C.Yellow, C.Navy)
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			tower(c[1] * (hx + 26), c[2] * (hz + 6), 42, 5, (fac.Aydinlatma or 0) >= 1)
		end
		screen(FR.N * CFrame.new(60, 13, 26), 26, 12, false)
		ext = 60
	elseif tier == 2 then
		local top, back = stand(FR.W, { len = 230, margin = 22, depth = 26, y0 = 3, rise = 13, density = 0.5 })
		roof(FR.W, 230, 26, back, top + 13, false)
		stand(FR.E, { len = 150 + 40 * (fac.TribunEki or 0), margin = 22, depth = 14, y0 = 3, rise = 7, density = 0.4 })
		fence(20, 24, 8)
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			tower(c[1] * (hx + 46), c[2] * (hz + 10), 62, 8, false)
		end
		screen(FR.N * CFrame.new(0, 16, 30), 40, 16, false)
		ext = 80
	elseif tier == 3 then
		for _, s in ipairs({ "W", "E" }) do
			local top, back =
				stand(FR[s], { len = 300, margin = 22, depth = 34, y0 = 3, rise = 18, density = 0.68, flip = if s == "E" then 1 else 0 })
			roof(FR[s], 300, 30, back, top + 14, false)
		end
		stand(FR.N, { len = 190, margin = 26, depth = 22, y0 = 3, rise = 11, density = 0.6 })
		stand(FR.S, { len = 190, margin = 26, depth = 22, y0 = 3, rise = 11, density = 0.55 })
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			tower(c[1] * (hx + 64), c[2] * (hz + 44), 96, 12, false)
		end
		screen(FR.N * CFrame.new(0, 26, 52), 56, 22, false)
		ext = 110
	else
		-- Kapalı çanak: dört tribün + köşeler; 5 ve 6'da çift kat
		local depth = if tier == 4 then 44 else 40
		local rise = if tier == 4 then 26 else 20
		local dens = if tier == 4 then 0.8 elseif tier == 5 then 0.9 else 0.97
		local margin = 22
		local upperD, upperR = if tier == 6 then 44 else 38, if tier == 6 then 34 else 28
		local outer = margin + depth
		local roofY = 0
		local i = 0
		for name, frame in pairs(FR) do
			i += 1
			local len = HALF[name] * 2 + margin * 2
			local top, back = stand(frame, { len = len, margin = margin, depth = depth, y0 = 3.5, rise = rise, density = dens, flip = i })
			if tier >= 5 then
				local um = margin + depth * 0.72
				top, back = stand(frame, {
					len = len + (um - margin) * 2,
					margin = um,
					depth = upperD,
					y0 = top + 7,
					rise = upperR,
					density = dens,
					solid = false,
					flip = i + 1,
				})
				part(
					Vector3.new(len + 40, top + 4, 3),
					frame * CFrame.new(0, (top + 4) / 2, back + 2.5),
					wallC,
					Enum.Material.Concrete,
					true
				)
			end
			roofY = top + 16
			outer = back
			roof(frame, len + (back - margin - depth) * 2, back - (if tier >= 5 then 46 else 30), back, roofY, glow)
		end
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			local frame = corner(c[1], c[2])
			local m = margin * 1.42
			local top, back =
				stand(frame, { len = depth * 1.5, margin = m, depth = depth * 1.05, y0 = 3.5, rise = rise, density = dens, flip = 1 })
			if tier >= 5 then
				top, back = stand(frame, {
					len = (depth + upperD) * 1.55,
					margin = m + depth * 0.8,
					depth = upperD * 1.05,
					y0 = top + 7,
					rise = upperR,
					density = dens,
					solid = false,
				})
			end
			-- köşe çatısı ve dış kule
			part(
				Vector3.new((back - m) * 1.9, 1.2, back - m + 10),
				frame * CFrame.new(0, roofY - 1.5, (m + back) / 2 + 12),
				if tier >= 5 then rgb(176, 184, 204) else rgb(140, 146, 158),
				Enum.Material.Metal,
				true
			)
			part(Vector3.new(16, roofY + 6, 16), frame * CFrame.new(0, (roofY + 6) / 2, back + 16), wallC, Enum.Material.Concrete, true)
			if tier == 4 then
				tower(c[1] * (hx + outer + 26), c[2] * (hz + outer + 26), roofY + 60, 16, true)
			end
		end
		-- dış cephe: sarı-lacivert dikmeler ve stat adı
		for name, frame in pairs(FR) do
			local len = HALF[name] * 2 + (outer + 4) * 2
			local n = math.floor(len / 22)
			for k = 0, n do
				local x = -len / 2 + len * k / n
				part(
					Vector3.new(2.4, roofY + 2, 2.4),
					frame * CFrame.new(x, (roofY + 2) / 2, outer + 6),
					if tier >= 6 then (if k % 2 == 0 then C.Yellow else C.Navy) else rgb(110, 118, 140),
					Enum.Material.Metal,
					true
				)
			end
			sign(
				frame * CFrame.new(0, roofY * 0.62, outer + 7.6) * CFrame.Angles(0, math.pi, 0),
				math.min(len * 0.6, 260),
				roofY * 0.2,
				if tier >= 6 then "FENERBAHÇE" else Theme.Upper(info.stadium or "STADYUM"),
				C.Yellow,
				C.Navy,
				night
			)
		end
		-- dev ekranlar: kale arkası üst köşelerde
		local sw, sh = if tier == 6 then 84 else 66, if tier == 6 then 34 else 27
		local sy = roofY - sh / 2 - 6
		screen(FR.N * CFrame.new(0, sy, outer - 8), sw, sh, true)
		screen(FR.S * CFrame.new(0, sy, outer - 8), sw, sh, true)
		ext = outer + 40
	end

	if tier >= 3 then
		led(FR.N, hx * 2 - 20, 15)
		led(FR.S, hx * 2 - 20, 15)
		led(FR.E, hz * 2 - 10, 17)
		led(FR.W, hz * 2 - 10, 17)
	end
	-- yedek kulübeleri
	if tier >= 2 then
		for _, z in ipairs({ -44, 44 }) do
			local f = FR.W * CFrame.new(z, 0, 9)
			part(Vector3.new(30, 0.8, 5), f * CFrame.new(0, 0.4, 0), DARK, Enum.Material.Concrete)
			part(Vector3.new(28, 1.6, 2), f * CFrame.new(0, 1.6, 1), C.Navy)
			local glass = part(Vector3.new(30, 6, 0.4), f * CFrame.new(0, 3.6, 2.8), rgb(160, 200, 235), Enum.Material.Glass)
			glass.Transparency = 0.55
			local top = part(Vector3.new(30, 0.4, 5.6), f * CFrame.new(0, 6.6, 0.4), rgb(160, 200, 235), Enum.Material.Glass, true)
			top.Transparency = 0.45
		end
	end

	------------------------------------------------------------------ çevre
	local r0 = math.sqrt((hx + ext) ^ 2 + (hz + ext) ^ 2) * 0.86
	if tier == 1 then
		trees(34, r0 + 10, r0 + 170)
		city(16, r0 + 70, r0 + 330, 28, 56)
	elseif tier == 2 then
		trees(40, r0 + 20, r0 + 200)
		city(20, r0 + 90, r0 + 380, 30, 70)
	elseif tier == 3 then
		trees(34, r0 + 20, r0 + 190)
		city(26, r0 + 90, r0 + 420, 36, 96)
	else
		trees(22, r0 + 30, r0 + 150)
		city(if tier == 6 then 44 else 34, r0 + 80, r0 + 520, 50, if tier == 6 then 190 else 140)
	end

	if withMood then
		mood(Config.Tiers[tier].Light)
	end
end

--------------------------------------------------------------------------------
-- Dış arayüz
--------------------------------------------------------------------------------
function Stadium.Clear()
	if current then
		current:Destroy()
		current = nil
	end
	crowdLayers = {}
	screens = {}
	boards = {}
	screenToken += 1
	mood("Lobi")
end

-- info: { club, abbr, facilities, atFenerbahce }
function Stadium.Build(tier: number, info: Info?)
	Stadium.Clear()
	tier = math.clamp(tier, 1, #Config.Tiers)
	local model = Instance.new("Model")
	model.Name = "FK_Stadium"
	local i: Info = info or {}
	i.stadium = i.stadium or Config.Tiers[tier].Stadium
	build(model, tier, i, Config.MatchPitch, true)
	model.Parent = Workspace
	current = model
	return model
end

-- Lobi ve deneme sahası: ışık + çevre (bir kez kurulur)
local lobbyBuilt = false
function Stadium.Lobby()
	mood("Lobi")
	if lobbyBuilt then
		return
	end
	lobbyBuilt = true
	local model = Instance.new("Model")
	model.Name = "FK_LobbyWorld"
	local part = builder(model)
	local R = rng(4242)
	local T = Config.TestPitch
	local cz = (T.MinZ + T.MaxZ) / 2
	part(Vector3.new(2000, 1, 2000), CFrame.new(0, T.GroundY - 1.3, cz), rgb(96, 128, 82), Enum.Material.Grass)
	-- antrenman tesisi: çit, küçük tribün, binalar, ağaçlar
	for _, sx in ipairs({ -1, 1 }) do
		local f = part(Vector3.new(0.3, 10, 200), CFrame.new(sx * 128, 5, cz), rgb(120, 126, 132), Enum.Material.DiamondPlate)
		f.Transparency = 0.55
		for i = 0, 8 do
			part(Vector3.new(0.7, 11, 0.7), CFrame.new(sx * 128, 5.5, cz - 100 + i * 25), DARK, Enum.Material.Metal)
		end
	end
	local back = part(Vector3.new(256, 10, 0.3), CFrame.new(0, 5, T.MaxZ + 22), rgb(120, 126, 132), Enum.Material.DiamondPlate)
	back.Transparency = 0.55
	for i = 0, 5 do
		local a = R() * 0.2
		local x = -330 + i * 132
		local h = 40 + R() * 50
		local cf = CFrame.new(x, 0, T.MaxZ + 190 + R() * 80) * CFrame.Angles(0, a, 0)
		part(Vector3.new(60, h, 44), cf * CFrame.new(0, h / 2, 0), rgb(200, 192, 176), Enum.Material.Concrete, true)
		for f = 1, 3 do
			part(Vector3.new(60.4, 3.4, 44.4), cf * CFrame.new(0, h * f / 4, 0), rgb(70, 88, 120), Enum.Material.Glass)
		end
	end
	for _ = 1, 46 do
		local a = R() * math.pi * 2
		local r = 190 + R() * 240
		local x, z = math.cos(a) * r, cz + math.sin(a) * r
		if z > 30 or math.abs(x) > 70 then
			local h = 16 + R() * 12
			local trunk = part(
				Vector3.new(h, 2.4, 2.4),
				CFrame.new(x, h / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
				rgb(92, 66, 44),
				Enum.Material.Wood,
				true
			)
			trunk.Shape = Enum.PartType.Cylinder
			for k = 0, 2 do
				local s = (15 - k * 3) + R() * 4
				local leaf = part(
					Vector3.new(s, s, s),
					CFrame.new(x + (R() - 0.5) * 5, h + k * 5 - 2, z + (R() - 0.5) * 5),
					rgb(52 + R() * 24, 122 + R() * 30, 58),
					Enum.Material.Grass,
					true
				)
				leaf.Shape = Enum.PartType.Ball
			end
		end
	end
	-- tesis tabelası
	local p = part(Vector3.new(120, 14, 1), CFrame.new(0, 16, T.MaxZ + 24), C.Navy)
	local g = surface(p, 10)
	label(g, "FENER KARİYER  •  ANTRENMAN TESİSİ", C.Yellow, UDim2.fromScale(0.94, 0.7), UDim2.fromScale(0.03, 0.15))
	for _, x in ipairs({ -58, 58 }) do
		part(Vector3.new(2, 24, 2), CFrame.new(x, 12, T.MaxZ + 24.5), DARK, Enum.Material.Metal, true)
	end
	model.Parent = Workspace
end

-- Seyirci zıplaması (golde)
function Stadium.Cheer()
	for i, holder in ipairs(crowdLayers) do
		local base = holder.Position
		local up = UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale, base.Y.Offset - 9)
		local tw = TweenService:Create(
			holder,
			TweenInfo.new(0.16 + (i % 3) * 0.02, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 7, true),
			{ Position = up }
		)
		tw:Play()
	end
end

-- Dev ekranda olay: başlık + açıklama; süre bitince skora döner
function Stadium.Screen(title: string, text: string, color: Color3?, hold: number?)
	screenToken += 1
	local token = screenToken
	for _, s in ipairs(screens) do
		s.title.Text = title
		s.title.TextColor3 = color or C.Yellow
		s.bar.BackgroundColor3 = color or C.Yellow
		s.text.Text = text
	end
	task.delay(hold or 5, function()
		if token ~= screenToken then
			return
		end
		for _, s in ipairs(screens) do
			s.title.TextColor3 = C.Yellow
			s.bar.BackgroundColor3 = C.Yellow
			s.text.Text = ""
		end
	end)
end

function Stadium.HasScreen(): boolean
	return #screens > 0
end

function Stadium.Score(home: string, away: string, hg: number, ag: number, minute: number?)
	local line = string.format("%s  %d - %d  %s", home, hg, ag, away)
	for _, s in ipairs(screens) do
		s.score.Text = line
		if s.text.Text == "" or string.sub(s.text.Text, -1) == "'" then
			s.text.Text = if minute then tostring(minute) .. "'" else ""
		end
	end
	for _, b in ipairs(boards) do
		b.Text = string.format("%d - %d", hg, ag)
	end
end

return Stadium

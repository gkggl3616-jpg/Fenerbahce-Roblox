--[[
	Crest
	Kulüp arması: biçim + desen + iki renk + simge. Hem arayüzde hem forma göğsünde aynı kodla çizilir
	(ölçüler orantılıdır; içine konduğu kutuyu doldurur). Oyuncu kendi armasını tasarlar,
	rakip kulüplerin armaları hazırdır.

	spec = { shape, pattern, a, b, symbol }   a ve b: Crest.Colors içindeki sıra numaraları
	Crest.Fill(parent, spec, abbr)            armayı parent kutusuna çizer
	Crest.Build(spec, abbr, pixels) -> Frame  sabit ölçülü arma
	Crest.Clean(spec) -> spec | nil           sunucu doğrulaması
	Crest.FromClub(club) -> spec, abbr        hazır kulüp tanımından (Squads) arma
]]

local Crest = {}

local rgb = Color3.fromRGB
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)

Crest.Shapes = { "Kalkan", "Daire", "Altıgen", "Flama", "Elmas" }
Crest.Patterns = { "Düz", "Çapraz şerit", "Dikey çubuk", "Yatay kuşak", "Yarı yarıya", "Çerçeve" }
Crest.Symbols = { "Kısaltma", "Baş harf", "Yıldızlı", "Toplu" }
Crest.Colors = {
	rgb(255, 230, 0), -- sarı
	rgb(11, 23, 71), -- lacivert
	rgb(250, 250, 250), -- beyaz
	rgb(20, 20, 24), -- siyah
	rgb(200, 36, 44), -- kırmızı
	rgb(120, 20, 46), -- bordo
	rgb(232, 120, 24), -- turuncu
	rgb(28, 140, 84), -- yeşil
	rgb(18, 84, 60), -- koyu yeşil
	rgb(40, 110, 200), -- mavi
	rgb(96, 190, 235), -- açık mavi
	rgb(112, 60, 160), -- mor
	rgb(196, 160, 72), -- altın
	rgb(130, 136, 148), -- gri
}

function Crest.Default()
	return { shape = 1, pattern = 2, a = 2, b = 1, symbol = 1 }
end

local function isInt(v: any, min: number, max: number): boolean
	return type(v) == "number" and v == math.floor(v) and v >= min and v <= max
end

-- İstemciden gelen tasarımı doğrular; geçersizse nil
function Crest.Clean(spec: any)
	if type(spec) ~= "table" then
		return nil
	end
	if
		not isInt(spec.shape, 1, #Crest.Shapes)
		or not isInt(spec.pattern, 1, #Crest.Patterns)
		or not isInt(spec.a, 1, #Crest.Colors)
		or not isInt(spec.b, 1, #Crest.Colors)
		or not isInt(spec.symbol, 1, #Crest.Symbols)
	then
		return nil
	end
	if spec.a == spec.b then
		return nil -- iki renk aynı olursa desen ve yazı görünmez
	end
	return { shape = spec.shape, pattern = spec.pattern, a = spec.a, b = spec.b, symbol = spec.symbol }
end

local function hash(text: string): number
	local h = 7
	for i = 1, #text do
		h = (h * 31 + string.byte(text, i)) % 2147483647
	end
	return h
end

-- Hazır kulüp (Squads.Clubs) ya da oyuncunun kulübü için çizim bilgisi
function Crest.FromClub(club)
	if club.CrestSpec then
		local s = club.CrestSpec
		return { shape = s.shape, pattern = s.pattern, a = Crest.Colors[s.a], b = Crest.Colors[s.b], symbol = s.symbol }, club.Abbr
	end
	return {
		shape = club.Crest or 1,
		pattern = 1 + hash(club.Name or "") % #Crest.Patterns,
		a = club.A,
		b = club.B,
		symbol = 1 + hash(club.Abbr or "") % 2 * 2, -- kısaltma ya da yıldızlı
	},
		club.Abbr
end

local function color(v: any): Color3
	-- sayı: paletteki sıra; değilse doğrudan renk (hazır kulüpler)
	return if type(v) == "number" then (Crest.Colors[v] or Crest.Colors[1]) else v
end

local function frame(parent: Instance, size: UDim2, pos: UDim2, c: Color3, rot: number?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = c
	f.BorderSizePixel = 0
	f.Rotation = rot or 0
	f.Parent = parent
	return f
end

local function round(o: Instance, r: number)
	local u = Instance.new("UICorner")
	u.CornerRadius = UDim.new(r, 0)
	u.Parent = o
end

-- Açık renk üstüne koyu, koyu renk üstüne açık yazı
local function ink(bg: Color3): Color3
	local lum = bg.R * 0.299 + bg.G * 0.587 + bg.B * 0.114
	return if lum > 0.6 then rgb(12, 16, 40) else rgb(255, 255, 255)
end

function Crest.Fill(parent: Instance, spec, abbr: string?)
	local a, b = color(spec.a), color(spec.b)
	local kind = spec.shape or 1
	-- gövde: köşeleri yuvarlatılmış ve içeriği kırpan tuval
	local body = Instance.new("CanvasGroup")
	body.Name = "CrestBody"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.BackgroundColor3 = a
	body.BorderSizePixel = 0
	local diamond = kind == 5
	if kind == 2 then
		body.Size = UDim2.fromScale(0.92, 0.92)
		round(body, 0.5)
	elseif kind == 3 then
		body.Size = UDim2.fromScale(0.86, 0.94)
		round(body, 0.28)
	elseif kind == 4 then
		body.Size = UDim2.fromScale(0.72, 0.96)
		round(body, 0.1)
	elseif diamond then
		body.Size = UDim2.fromScale(0.68, 0.68)
		body.Rotation = 45
		round(body, 0.12)
	else
		body.Size = UDim2.fromScale(0.8, 0.94)
		round(body, 0.3)
	end
	local edge = Instance.new("UIStroke")
	edge.Color = b
	edge.Thickness = 2
	edge.Parent = body
	body.Parent = parent
	-- elmasta desen, döndürülmüş gövdenin içinde düz dursun diye ters çevrilir
	local back = if diamond then -45 else 0

	local p = spec.pattern or 1
	if p == 2 then
		frame(body, UDim2.fromScale(0.3, 2.2), UDim2.fromScale(0.5, 0.5), b, 28 + back)
	elseif p == 3 then
		for _, x in ipairs({ 0.22, 0.5, 0.78 }) do
			frame(body, UDim2.fromScale(0.13, 2.2), UDim2.fromScale(x, 0.5), b, back)
		end
	elseif p == 4 then
		frame(body, UDim2.fromScale(2.2, 0.3), UDim2.fromScale(0.5, 0.5), b, back)
	elseif p == 5 then
		frame(body, UDim2.fromScale(1.2, 2.4), UDim2.fromScale(1.1, 0.5), b, back)
	elseif p == 6 then
		local inner = frame(body, UDim2.fromScale(0.74, 0.74), UDim2.fromScale(0.5, 0.5), a)
		round(inner, if kind == 2 then 0.5 else 0.2)
		local st = Instance.new("UIStroke")
		st.Color = b
		st.Thickness = 3
		st.Parent = inner
	end

	-- simge: gövdenin üstünde, hep düz durur
	local sym = spec.symbol or 1
	local textValue = abbr or ""
	if sym == 2 then
		textValue = string.sub(textValue, 1, 1)
		-- Türkçe harfler iki bayt olabilir
		for _, code in utf8.codes(abbr or "") do
			textValue = utf8.char(code)
			break
		end
	end
	local onColor = if p == 1 or p == 6 then a else b:Lerp(a, 0.5)
	local label = Instance.new("TextLabel")
	label.Name = "CrestText"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, if sym >= 3 then 0.62 else 0.5)
	label.Size = if sym == 2 then UDim2.fromScale(0.5, 0.56) else UDim2.fromScale(0.62, if sym >= 3 then 0.26 else 0.34)
	label.FontFace = FONT
	label.Text = textValue
	label.TextScaled = true
	label.TextColor3 = ink(onColor)
	local ts = Instance.new("UIStroke")
	ts.Color = if ink(onColor).R > 0.5 then rgb(12, 16, 40) else rgb(255, 255, 255)
	ts.Thickness = 1.5
	ts.Parent = label
	label.Parent = parent
	if sym == 3 then
		-- yıldız: üst üste iki kare (sekiz köşeli)
		for _, rot in ipairs({ 0, 45 }) do
			local s = frame(parent, UDim2.fromScale(0.2, 0.2), UDim2.fromScale(0.5, 0.33), rgb(255, 214, 64), rot)
			local st = Instance.new("UIStroke")
			st.Color = rgb(12, 16, 40)
			st.Thickness = 1
			st.Parent = s
		end
		frame(parent, UDim2.fromScale(0.16, 0.16), UDim2.fromScale(0.5, 0.33), rgb(255, 214, 64), 22)
	elseif sym == 4 then
		-- top: beyaz daire, ortasında koyu beşgen yerine nokta
		local ball = frame(parent, UDim2.fromScale(0.24, 0.24), UDim2.fromScale(0.5, 0.33), rgb(250, 250, 250))
		round(ball, 0.5)
		local st = Instance.new("UIStroke")
		st.Color = rgb(12, 16, 40)
		st.Thickness = 1.5
		st.Parent = ball
		local dot = frame(ball, UDim2.fromScale(0.42, 0.42), UDim2.fromScale(0.5, 0.5), rgb(12, 16, 40), 45)
		round(dot, 0.2)
	end
	return body
end

function Crest.Build(spec, abbr: string?, pixels: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Crest"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(pixels, pixels)
	Crest.Fill(holder, spec, abbr)
	return holder
end

return Crest

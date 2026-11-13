--[[
	Career
	Kariyer sayfası: istatistikler, kupa dolabı (lig atlamalar ve Fenerbahçe) ve başarımlar.

	Career.Open(gui, getData) · Career.Close() · Career.Refresh()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Components = require(ReplicatedStorage.UI.Components)
local Icons = require(ReplicatedStorage.UI.Icons)
local Theme = require(ReplicatedStorage.UI.Theme)
local UIMotion = require(ReplicatedStorage.UI.UIMotion)

local Career = {}

local C = Theme.Color
local DARK = Color3.fromRGB(16, 24, 70)
local open: any = nil

local function corner(o: Instance, r: number)
	local u = Instance.new("UICorner")
	u.CornerRadius = UDim.new(0, r)
	u.Parent = o
end

local function label(
	parent: Instance,
	text: string,
	size: number,
	color: Color3,
	x: number,
	y: number,
	w: number,
	h: number,
	font: Font?,
	align: Enum.TextXAlignment?
)
	local l = Components.Label({
		Text = text,
		Size = size,
		Color = color,
		Font = font or Theme.Font.Title,
		Frame = UDim2.fromOffset(w, h),
		Align = align,
	})
	l.Position = UDim2.fromOffset(x, y)
	l.Parent = parent
	return l
end

-- Kupa: kulplu kupa gövdesi, ayak ve kaide (altın, gümüş ya da sönük)
local function trophy(color: Color3, size: number, dim: boolean): Frame
	local f = Instance.new("Frame")
	f.Name = "Trophy"
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(size, size)
	local function piece(x: number, y: number, w: number, h: number, round: number): Frame
		local p = Instance.new("Frame")
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Position = UDim2.fromScale(x, y)
		p.Size = UDim2.fromScale(w, h)
		p.BackgroundColor3 = color
		p.BackgroundTransparency = if dim then 0.75 else 0
		p.BorderSizePixel = 0
		local u = Instance.new("UICorner")
		u.CornerRadius = UDim.new(round, 0)
		u.Parent = p
		if not dim then
			local g = Instance.new("UIGradient")
			g.Rotation = 30
			g.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4), color:Lerp(Color3.new(0, 0, 0), 0.25))
			g.Parent = p
		end
		p.Parent = f
		return p
	end
	for _, sx in ipairs({ 0.2, 0.8 }) do
		local h = piece(sx, 0.3, 0.2, 0.26, 0.5)
		h.BackgroundTransparency = 1
		local st = Instance.new("UIStroke")
		st.Color = color
		st.Thickness = math.max(2, size * 0.05)
		st.Transparency = if dim then 0.75 else 0
		st.Parent = h
	end
	piece(0.5, 0.32, 0.52, 0.42, 0.35) -- kupa
	piece(0.5, 0.62, 0.12, 0.2, 0.1) -- ayak
	piece(0.5, 0.78, 0.4, 0.1, 0.3) -- taban
	piece(0.5, 0.9, 0.56, 0.12, 0.2).BackgroundColor3 = Color3.fromRGB(60, 40, 30) -- kaide
	return f
end

local function draw()
	if not open then
		return
	end
	local data = open.getData()
	local body = open.body
	for _, child in ipairs(body:GetChildren()) do
		child:Destroy()
	end
	if not data then
		return
	end
	local career = data.career or {}
	local matches = career.matches or 0
	local wins = career.wins or 0

	-- istatistikler
	label(body, "İSTATİSTİKLER", 16, C.Yellow, 0, 0, 400, 22, Theme.Font.Display)
	local stats = {
		{ "Maç", tostring(matches) },
		{ "Gol", tostring(career.goals or 0) },
		{ "Kafa golü", tostring(career.headerGoals or 0) },
		{ "Galibiyet", tostring(wins) },
		{ "Galibiyet %", if matches > 0 then tostring(math.floor(wins / matches * 100 + 0.5)) else "0" },
		{ "Hat-trick", tostring(career.hatTricks or 0) },
	}
	for i, st in ipairs(stats) do
		local card = Instance.new("Frame")
		card.Name = "Stat"
		card.Size = UDim2.fromOffset(176, 78)
		card.Position = UDim2.fromOffset((i - 1) * 186, 28)
		card.BackgroundColor3 = DARK
		card.BorderSizePixel = 0
		corner(card, 10)
		card.Parent = body
		label(card, Theme.Upper(st[1]), 11, C.Muted, 12, 8, 160, 16)
		local v = label(card, st[2], 32, C.Yellow, 12, 26, 160, 40, Theme.Font.Number)
		UIMotion.CountUp(v, 0, tonumber(st[2]) or 0)
	end

	-- kupa dolabı: her kademe için bir raf yeri; kazanılanlar parlar
	label(body, "KUPA DOLABI", 16, C.Yellow, 0, 124, 400, 22, Theme.Font.Display)
	local shelf = Instance.new("Frame")
	shelf.Name = "Cabinet"
	shelf.Size = UDim2.fromOffset(1106, 150)
	shelf.Position = UDim2.fromOffset(0, 152)
	shelf.BackgroundColor3 = Color3.fromRGB(40, 26, 18)
	shelf.BorderSizePixel = 0
	corner(shelf, 10)
	shelf.Parent = body
	local wood = Instance.new("UIGradient")
	wood.Rotation = 90
	wood.Color = ColorSequence.new(Color3.fromRGB(120, 80, 50), Color3.fromRGB(60, 38, 24))
	wood.Parent = shelf
	local won: { [string]: any } = {}
	for _, t in ipairs(career.trophies or {}) do
		won[t.league] = t
	end
	local slots = {}
	for tier = 1, 5 do
		table.insert(
			slots,
			{ name = Config.Tiers[tier].League .. " yükselişi", key = Config.Tiers[tier].League, color = Color3.fromRGB(205, 140, 70) }
		)
	end
	table.insert(slots, { name = "Fenerbahçe forması", key = "__fener", color = C.Gold })
	for i, sl in ipairs(slots) do
		local got = if sl.key == "__fener" then career.atFenerbahce == true else won[sl.key] ~= nil
		local x = 18 + (i - 1) * 182
		local t = trophy(if got then sl.color else Color3.fromRGB(200, 200, 210), 86, not got)
		t.Position = UDim2.fromOffset(x + 40, 8)
		t.Parent = shelf
		if got then
			UIMotion.ShineLoop(t, 3 + i * 0.3)
		end
		label(shelf, sl.name, 12, if got then C.White else C.Muted, x, 98, 170, 18, nil, Enum.TextXAlignment.Center)
		local sub = if sl.key == "__fener"
			then (if got then "İmzalandı" else "Seviye 25 · güç 85")
			elseif got then won[sl.key].season .. ". sezon · " .. won[sl.key].points .. " puan"
			else "Henüz yok"
		label(shelf, sub, 11, if got then C.Gold else C.Muted, x, 118, 170, 16, Theme.Font.Body, Enum.TextXAlignment.Center)
	end

	-- başarımlar
	local achieved = data.achievements or {}
	local doneCount = 0
	for _, a in ipairs(Config.Achievements) do
		if achieved[a.Id] then
			doneCount += 1
		end
	end
	label(body, "BAŞARIMLAR", 16, C.Yellow, 0, 318, 400, 22, Theme.Font.Display)
	label(body, doneCount .. " / " .. #Config.Achievements, 14, C.Text, 906, 318, 200, 22, Theme.Font.Number, Enum.TextXAlignment.Right)
	for i, a in ipairs(Config.Achievements) do
		local done = achieved[a.Id] ~= nil
		local value = math.min(a.Goal, Config.AchievementValue(data, a.Stat))
		local card = Instance.new("Frame")
		card.Name = "Achievement"
		card.Size = UDim2.fromOffset(266, 66)
		card.Position = UDim2.fromOffset(((i - 1) % 4) * 280, 346 + math.floor((i - 1) / 4) * 74)
		card.BackgroundColor3 = if done then Color3.fromRGB(60, 52, 18) else DARK
		card.BorderSizePixel = 0
		corner(card, 10)
		local st = Instance.new("UIStroke")
		st.Color = if done then C.Gold else C.Blue
		st.Thickness = if done then 2 else 1
		st.Parent = card
		card.Parent = body
		local icon = Icons.Build(if done then "Star" else "Trophy", 30, if done then C.Gold else C.Muted)
		icon.Position = UDim2.fromOffset(10, 18)
		icon.Parent = card
		label(card, Theme.Upper(a.Name), 14, if done then C.White else C.Text, 50, 6, 210, 18)
		label(card, a.Text, 11, C.Muted, 50, 24, 210, 14, Theme.Font.Body)
		local barBg = Instance.new("Frame")
		barBg.Size = UDim2.fromOffset(140, 6)
		barBg.Position = UDim2.fromOffset(50, 46)
		barBg.BackgroundColor3 = C.Ground
		barBg.BorderSizePixel = 0
		corner(barBg, 3)
		barBg.Parent = card
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(value / a.Goal, 1)
		bar.BackgroundColor3 = if done then C.Gold else C.Yellow
		bar.BorderSizePixel = 0
		corner(bar, 3)
		bar.Parent = barBg
		label(
			card,
			if done then "+" .. a.Coins .. " ✓" else value .. "/" .. a.Goal .. " · +" .. a.Coins,
			11,
			if done then C.Gold else C.Muted,
			196,
			40,
			64,
			16,
			Theme.Font.Number,
			Enum.TextXAlignment.Right
		)
	end
end

function Career.Refresh()
	draw()
end

function Career.Close()
	if open then
		local root = open.root
		open = nil
		UIMotion.Out(root, Vector2.new(0, 20), true)
	end
end

function Career.Open(gui: ScreenGui, getData: () -> any)
	if open then
		return
	end
	local dim = Instance.new("TextButton")
	dim.Name = "Career"
	dim.AutoButtonColor = false
	dim.Text = ""
	dim.BackgroundColor3 = C.Ground
	dim.BackgroundTransparency = 0.25
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 120
	dim.Parent = gui
	local panel, content = Components.Panel({
		Name = "CareerPanel",
		Size = UDim2.fromOffset(1140, 720),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Title = "Kariyer ve Kupa Dolabı",
	})
	panel.ZIndex = 121
	panel.Parent = dim
	local closeB =
		Components.Button({ Text = "Kapat", Style = "Ghost", TextSize = 15, Size = UDim2.fromOffset(120, 38), OnClick = Career.Close })
	closeB.AnchorPoint = Vector2.new(1, 0)
	closeB.Position = UDim2.new(1, -80, 0, -2)
	closeB.Parent = content
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, 46)
	body.Size = UDim2.new(1, 0, 1, -46)
	body.Parent = content
	open = { root = dim, body = body, getData = getData }
	draw()
	UIMotion.In(panel, Vector2.new(0, 30))
end

return Career

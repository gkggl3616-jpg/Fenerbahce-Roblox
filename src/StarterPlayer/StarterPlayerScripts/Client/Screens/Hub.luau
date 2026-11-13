--[[
	Hub
	Lobiden açılan üç ekran: mağaza (top, şut izi, gol sevinci), kulüp tesisleri ve dünya sıralaması.

	Hub.OpenShop(gui, getData) · Hub.OpenClub(gui, getData) · Hub.OpenRanking(gui, getData)
	Hub.Refresh()  veri değişince açık ekranı yeniden çizer
	Hub.Close()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Components = require(ReplicatedStorage.UI.Components)
local Icons = require(ReplicatedStorage.UI.Icons)
local Theme = require(ReplicatedStorage.UI.Theme)
local UIMotion = require(ReplicatedStorage.UI.UIMotion)

local Hub = {}

local C = Theme.Color
local DARK = Color3.fromRGB(16, 24, 70)
local open: { root: Instance, body: Frame, draw: () -> () }? = nil

local function corner(o: Instance, r: number)
	local u = Instance.new("UICorner")
	u.CornerRadius = UDim.new(0, r)
	u.Parent = o
end

local function text(
	parent: Instance,
	str: string,
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
		Text = str,
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

function Hub.Close()
	if open then
		local root = open.root
		open = nil
		UIMotion.Out(root :: any, Vector2.new(0, 20), true)
	end
end

function Hub.Refresh()
	if open then
		open.draw()
	end
end

-- Ortak pencere: karartma + panel + kapat düğmesi; gövdeyi çizen işlev verilir
local function window(gui: ScreenGui, name: string, title: string, w: number, h: number, draw: (Frame) -> ())
	Hub.Close()
	local dim = Instance.new("TextButton")
	dim.Name = name
	dim.AutoButtonColor = false
	dim.Text = ""
	dim.BackgroundColor3 = C.Ground
	dim.BackgroundTransparency = 0.25
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 120
	dim.Parent = gui
	local panel, content = Components.Panel({
		Name = name .. "Panel",
		Size = UDim2.fromOffset(w, h),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Title = title,
	})
	panel.ZIndex = 121
	panel.Parent = dim
	local close =
		Components.Button({ Text = "Kapat", Style = "Ghost", TextSize = 15, Size = UDim2.fromOffset(120, 38), OnClick = Hub.Close })
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -80, 0, -2)
	close.Parent = content
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, 46)
	body.Size = UDim2.new(1, 0, 1, -46)
	body.Parent = content
	open = {
		root = dim,
		body = body,
		draw = function()
			for _, child in ipairs(body:GetChildren()) do
				child:Destroy()
			end
			draw(body)
		end,
	}
	open.draw()
	UIMotion.In(panel, Vector2.new(0, 30))
end

--------------------------------------------------------------------------------
-- Mağaza
--------------------------------------------------------------------------------
local TABS = { { "Ball", "Top" }, { "Trail", "Şut izi" }, { "Celebration", "Gol sevinci" } }

-- Eşyanın küçük önizlemesi
local function preview(parent: Instance, item)
	local box = Instance.new("Frame")
	box.Size = UDim2.new(1, -24, 0, 96)
	box.Position = UDim2.fromOffset(12, 12)
	box.BackgroundColor3 = C.Ground
	box.BackgroundTransparency = 0.2
	box.BorderSizePixel = 0
	corner(box, 8)
	box.Parent = parent
	if item.Kind == "Ball" then
		-- top: desen gerçek topla aynı mantıkla çizilir (kuşak, yıldız, dikiş, yaldız)
		local ball = Instance.new("CanvasGroup")
		ball.AnchorPoint = Vector2.new(0.5, 0.5)
		ball.Position = UDim2.fromScale(0.5, 0.5)
		ball.Size = UDim2.fromOffset(74, 74)
		ball.BackgroundColor3 = item.A
		ball.BorderSizePixel = 0
		corner(ball, 37)
		ball.Parent = box
		local function dot(x: number, y: number, s: number, c: Color3, rot: number?, round: number?): Frame
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(x, y)
			f.Size = UDim2.fromScale(s, s)
			f.BackgroundColor3 = c
			f.BorderSizePixel = 0
			f.Rotation = rot or 0
			local u = Instance.new("UICorner")
			u.CornerRadius = UDim.new(round or 0.25, 0)
			u.Parent = f
			f.Parent = ball
			return f
		end
		local function band(y: number, h: number, c: Color3, rot: number?): Frame
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5, y)
			f.Size = UDim2.fromScale(1.4, h)
			f.BackgroundColor3 = c
			f.BorderSizePixel = 0
			f.Rotation = rot or 0
			f.Parent = ball
			return f
		end
		local p = item.Pattern or "Klasik"
		if p == "Kusak" then
			band(0.5, 0.26, item.B)
			band(0.24, 0.06, item.B)
			band(0.76, 0.06, item.B)
		elseif p == "Yildiz" then
			for _, d in ipairs({ { 0.3, 0.3 }, { 0.68, 0.24 }, { 0.5, 0.55 }, { 0.24, 0.72 }, { 0.78, 0.7 }, { 0.5, 0.86 } }) do
				dot(d[1], d[2], 0.13, item.B, 45, 0.1)
				dot(d[1], d[2], 0.13, item.B, 0, 0.1)
			end
			local glow = Instance.new("UIStroke")
			glow.Color = item.B
			glow.Thickness = 3
			glow.Transparency = 0.3
			glow.Parent = box
		elseif p == "Dikis" then
			-- eğri dikişler: büyük halkaların ince kenarları
			for _, d in ipairs({ { -0.1, 0.5, 1.1 }, { 1.1, 0.5, 1.1 }, { 0.5, -0.15, 1.0 } }) do
				local ring = dot(d[1], d[2], d[3], item.A, 0, 0.5)
				ring.BackgroundTransparency = 1
				local st = Instance.new("UIStroke")
				st.Color = item.B
				st.Thickness = 3
				st.Parent = ring
			end
		elseif p == "Altin" then
			local g = Instance.new("UIGradient")
			g.Rotation = 35
			g.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 244, 170)),
				ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 196, 40)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(176, 112, 10)),
			})
			g.Parent = ball
			for _, d in ipairs({ { 0.32, 0.34 }, { 0.7, 0.42 }, { 0.45, 0.74 } }) do
				dot(d[1], d[2], 0.14, item.B, 45, 0.1)
				dot(d[1], d[2], 0.14, item.B, 0, 0.1)
			end
			band(0.3, 0.08, Color3.fromRGB(255, 255, 255), -35).BackgroundTransparency = 0.45 -- parıltı
			UIMotion.ShineLoop(box, 2.2)
		else
			for _, d in ipairs({ { 0.5, 0.5 }, { 0.16, 0.3 }, { 0.84, 0.3 }, { 0.28, 0.88 }, { 0.72, 0.88 }, { 0.5, 0.06 } }) do
				dot(d[1], d[2], 0.27, item.B, 18)
			end
		end
		-- gölge ve parlama (küre hissi)
		local shade = Instance.new("UIGradient")
		shade.Rotation = 90
		shade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.25) })
		if p ~= "Altin" then
			shade.Parent = ball
		end
		local hi = dot(0.32, 0.26, 0.2, Color3.new(1, 1, 1), 0, 0.5)
		hi.BackgroundTransparency = 0.55
	elseif item.Kind == "Trail" then
		for i = 1, 5 do
			local seg = Instance.new("Frame")
			seg.AnchorPoint = Vector2.new(0, 0.5)
			seg.Position = UDim2.new(0, 16 + (i - 1) * 30, 0.5, 0)
			seg.Size = UDim2.fromOffset(26, 4 + i * 5)
			seg.BackgroundColor3 = item.A:Lerp(item.B, 1 - i / 5)
			seg.BackgroundTransparency = 0.7 - i * 0.14
			seg.BorderSizePixel = 0
			corner(seg, 4)
			seg.Parent = box
		end
		local ball = Instance.new("Frame")
		ball.AnchorPoint = Vector2.new(0.5, 0.5)
		ball.Position = UDim2.new(1, -28, 0.5, 0)
		ball.Size = UDim2.fromOffset(30, 30)
		ball.BackgroundColor3 = C.White
		ball.BorderSizePixel = 0
		corner(ball, 15)
		ball.Parent = box
	else
		local icon = Icons.Build("Star", 56, C.Yellow)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Parent = box
	end
end

function Hub.OpenShop(gui: ScreenGui, getData: () -> any)
	local tab = "Ball"
	window(gui, "Shop", "Mağaza", 1040, 640, function(body)
		local data = getData()
		if not data then
			return
		end
		text(body, "BAKİYE", 11, C.Muted, 660, -44, 120, 14, nil, Enum.TextXAlignment.Right)
		text(body, Theme.FormatNumber(data.coins or 0), 22, C.Yellow, 660, -32, 120, 24, Theme.Font.Number, Enum.TextXAlignment.Right)
		for i, t in ipairs(TABS) do
			local on = tab == t[1]
			local b = Components.Button({
				Text = t[2],
				Style = if on then "Primary" else "Secondary",
				TextSize = 15,
				Size = UDim2.fromOffset(170, 40),
				OnClick = function()
					tab = t[1]
					Hub.Refresh()
				end,
			})
			b.Name = "Tab"
			b.Position = UDim2.fromOffset((i - 1) * 180, 0)
			b.Parent = body
		end
		local n = 0
		for _, item in ipairs(Config.Shop) do
			if item.Kind == tab then
				local card = Instance.new("Frame")
				card.Name = "Item"
				card.Size = UDim2.fromOffset(236, 232)
				card.Position = UDim2.fromOffset((n % 4) * 250, 58 + math.floor(n / 4) * 246)
				card.BackgroundColor3 = DARK
				card.BorderSizePixel = 0
				corner(card, 10)
				local owned = data.owned and data.owned[item.Id] == true
				local equipped = Config.Equipped(data, item.Kind).Id == item.Id
				local st = Instance.new("UIStroke")
				st.Color = if equipped then C.Yellow elseif owned then C.Good else C.Blue
				st.Thickness = if equipped then 2 else 1.5
				st.Parent = card
				card.Parent = body
				preview(card, item)
				text(card, Theme.Upper(item.Name), 15, C.White, 12, 116, 212, 20)
				text(
					card,
					if equipped
						then "Kuşanıldı"
						elseif owned then "Sende var"
						else "Seviye " .. item.Level .. " · " .. Theme.FormatNumber(item.Price),
					12,
					if equipped then C.Yellow elseif owned then C.Good else C.Muted,
					12,
					138,
					212,
					16
				)
				local locked = (data.level or 1) < item.Level
				local poor = (data.coins or 0) < item.Price
				local b = Components.Button({
					Text = if equipped
						then "Kuşanıldı"
						elseif owned then "Kuşan"
						elseif locked then "Sv " .. item.Level
						elseif item.Price == 0 then "Al"
						else "Al · " .. Theme.FormatNumber(item.Price),
					Style = if equipped then "Ghost" elseif owned or not (locked or poor) then "Primary" else "Secondary",
					TextSize = 15,
					Size = UDim2.fromOffset(212, 44),
					OnClick = function()
						if equipped then
							return
						elseif owned then
							Remotes.Get("EquipItem"):FireServer(item.Id)
						elseif locked then
							Components.Toast("error", item.Name .. " için seviye " .. item.Level .. " gerekli.")
						elseif poor then
							Components.Toast("error", "Bakiye yetersiz. Gereken: " .. Theme.FormatNumber(item.Price))
						else
							UIMotion.Sound("ConfirmSound")
							Remotes.Get("BuyItem"):FireServer(item.Id)
						end
					end,
				})
				b.Position = UDim2.fromOffset(12, 176)
				b.Parent = card
				n += 1
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Kulüp tesisleri
--------------------------------------------------------------------------------
local FACILITY_ORDER = { "Cim", "TribunEki", "Aydinlatma", "Soyunma", "Antrenman", "Saglik" }
-- Tesis açıklaması: gerçek etki, şimdiki ve bir sonraki seviyedeki değeriyle
local function facilityInfo(id: string, level: number, max: number): string
	local e = Config.FacilityEffects[id]
	if not e then
		return ""
	end
	local per = e.Control or e.Income or e.Light or e.Xp or e.Training or e.Regen or 0
	local function value(lv: number): string
		local v = per * lv
		if e.Control then
			return string.format("%.1f", v)
		end
		return tostring(math.floor(v * 100 + 0.5))
	end
	local now = string.format(e.Info, value(level))
	if level < max then
		now ..= "  ›  sonraki: " .. string.format(e.Info, value(level + 1)):match("^[^·]+")
	end
	return now
end

function Hub.OpenClub(gui: ScreenGui, getData: () -> any)
	window(gui, "Club", "Kulüp Tesisleri", 900, 640, function(body)
		local data = getData()
		if not data then
			return
		end
		local tier = Config.Tiers[data.club.tier]
		text(
			body,
			Theme.Upper(
				(if data.club.name ~= "" then data.club.name else "Kulübüm") .. "  ·  " .. tier.League .. "  ·  " .. tier.Stadium
			),
			14,
			C.Muted,
			0,
			0,
			560,
			20
		)
		text(body, "KULÜP KASASI", 11, C.Muted, 520, -44, 140, 14, nil, Enum.TextXAlignment.Right)
		text(body, Theme.FormatNumber(data.club.funds or 0), 22, C.Yellow, 520, -32, 140, 24, Theme.Font.Number, Enum.TextXAlignment.Right)
		text(
			body,
			"Kasa her maçtan sonra dolar; tesisler bakiye ile değil kasa ile geliştirilir.",
			12,
			C.Muted,
			0,
			22,
			700,
			18,
			Theme.Font.Body
		)
		for i, id in ipairs(FACILITY_ORDER) do
			local f = Config.Facilities[id]
			local level = (data.club.facilities and data.club.facilities[id]) or 0
			local row = Instance.new("Frame")
			row.Name = "Facility"
			row.Size = UDim2.new(1, 0, 0, 72)
			row.Position = UDim2.fromOffset(0, 52 + (i - 1) * 80)
			row.BackgroundColor3 = DARK
			row.BorderSizePixel = 0
			corner(row, 10)
			row.Parent = body
			local icon = Icons.Build("Building", 36, C.Yellow)
			icon.Position = UDim2.fromOffset(16, 18)
			icon.Parent = row
			text(row, Theme.Upper(f.Name), 16, C.White, 68, 12, 320, 22)
			local info = text(row, facilityInfo(id, level, f.Max), 12, C.Muted, 68, 34, 390, 34, Theme.Font.Body)
			info.TextWrapped = true
			info.TextYAlignment = Enum.TextYAlignment.Top
			for k = 1, f.Max do
				local pip = Instance.new("Frame")
				pip.Size = UDim2.fromOffset(34, 12)
				pip.Position = UDim2.fromOffset(470 + (k - 1) * 40, 30)
				pip.BackgroundColor3 = if k <= level then C.Yellow else C.Ground
				pip.BorderSizePixel = 0
				corner(pip, 4)
				pip.Parent = row
			end
			local maxed = level >= f.Max
			local cost = if maxed then 0 else f.Cost[level + 1]
			local b = Components.Button({
				Text = if maxed then "Tam" else "Geliştir · " .. Theme.FormatNumber(cost),
				Style = if maxed then "Ghost" elseif (data.club.funds or 0) >= cost then "Primary" else "Secondary",
				TextSize = 15,
				Size = UDim2.fromOffset(210, 46),
				OnClick = function()
					if maxed then
						return
					elseif (data.club.funds or 0) < cost then
						Components.Toast("error", "Kulüp kasası yetersiz. Gereken: " .. Theme.FormatNumber(cost))
					else
						UIMotion.Sound("ConfirmSound")
						Remotes.Get("UpgradeFacility"):FireServer(id)
					end
				end,
			})
			b.AnchorPoint = Vector2.new(1, 0)
			b.Position = UDim2.new(1, -12, 0, 13)
			b.Parent = row
		end
	end)
end

--------------------------------------------------------------------------------
-- Dünya sıralaması
--------------------------------------------------------------------------------
local MEDALS = {
	{ Color3.fromRGB(255, 205, 60), Color3.fromRGB(196, 140, 20), Color3.fromRGB(200, 30, 40) }, -- altın
	{ Color3.fromRGB(226, 232, 240), Color3.fromRGB(150, 160, 175), Color3.fromRGB(30, 80, 190) }, -- gümüş
	{ Color3.fromRGB(226, 146, 84), Color3.fromRGB(150, 84, 40), Color3.fromRGB(20, 130, 80) }, -- bronz
}
-- Madalya: iki kurdele + parlak disk + iç halka + sıra numarası
function Hub.Medal(rank: number, size: number): Frame
	local m = MEDALS[rank]
	local holder = Instance.new("Frame")
	holder.Name = "Medal"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size)
	for i, x in ipairs({ 0.36, 0.64 }) do
		local ribbon = Instance.new("Frame")
		ribbon.AnchorPoint = Vector2.new(0.5, 0)
		ribbon.Position = UDim2.fromScale(x, -0.02)
		ribbon.Size = UDim2.fromScale(0.22, 0.5)
		ribbon.Rotation = if i == 1 then 18 else -18
		ribbon.BackgroundColor3 = m[3]
		ribbon.BorderSizePixel = 0
		ribbon.Parent = holder
		local edge = Instance.new("Frame")
		edge.Size = UDim2.fromScale(0.3, 1)
		edge.Position = UDim2.fromScale(0.35, 0)
		edge.BackgroundColor3 = Color3.new(1, 1, 1)
		edge.BackgroundTransparency = 0.4
		edge.BorderSizePixel = 0
		edge.Parent = ribbon
	end
	local disc = Instance.new("Frame")
	disc.AnchorPoint = Vector2.new(0.5, 1)
	disc.Position = UDim2.fromScale(0.5, 1)
	disc.Size = UDim2.fromScale(0.72, 0.72)
	disc.BackgroundColor3 = m[1]
	disc.BorderSizePixel = 0
	corner(disc, size)
	local g = Instance.new("UIGradient")
	g.Rotation = 40
	g.Color = ColorSequence.new(m[1]:Lerp(Color3.new(1, 1, 1), 0.35), m[2])
	g.Parent = disc
	local st = Instance.new("UIStroke")
	st.Color = m[2]
	st.Thickness = math.max(2, size * 0.05)
	st.Parent = disc
	disc.Parent = holder
	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.7, 0.7)
	inner.BackgroundTransparency = 1
	corner(inner, size)
	local ist = Instance.new("UIStroke")
	ist.Color = m[2]
	ist.Thickness = math.max(1, size * 0.025)
	ist.Transparency = 0.2
	ist.Parent = inner
	inner.Parent = disc
	local n = Components.Label({
		Text = tostring(rank),
		Size = math.floor(size * 0.36),
		Font = Theme.Font.Display,
		Color = Color3.fromRGB(255, 255, 255),
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.fromScale(1, 1),
	})
	local ns = Instance.new("UIStroke")
	ns.Color = m[2]:Lerp(Color3.new(0, 0, 0), 0.4)
	ns.Thickness = 2
	ns.Parent = n
	n.Parent = disc
	return holder
end
function Hub.OpenRanking(gui: ScreenGui, getData: () -> any)
	local result: any = nil
	window(gui, "Ranking", "Dünya Sıralaması", 760, 660, function(body)
		if not result then
			text(body, "Sıralama yükleniyor...", 15, C.Muted, 0, 20, 500, 22)
			return
		end
		local rows = result.rows or {}
		text(body, "#", 11, C.Muted, 10, 0, 30, 18)
		text(body, "OYUNCU", 11, C.Muted, 60, 0, 300, 18)
		text(body, "GENEL GÜÇ", 11, C.Muted, 560, 0, 140, 18, nil, Enum.TextXAlignment.Right)
		local shown = 0
		for i, r in ipairs(rows) do
			if i > 10 then
				break
			end
			local mine = r.userId == result.me.userId
			local row = Instance.new("Frame")
			row.Name = "Rank"
			row.Size = UDim2.new(1, 0, 0, 40)
			row.Position = UDim2.fromOffset(0, 24 + (i - 1) * 46)
			row.BackgroundColor3 = if mine then C.Yellow else (if i % 2 == 0 then C.Blue else DARK)
			row.BackgroundTransparency = if mine then 0 else 0.2
			row.BorderSizePixel = 0
			corner(row, 8)
			row.Parent = body
			local ink = if mine then C.Navy else C.Text
			if r.rank <= 3 then
				local medal = Hub.Medal(r.rank, 40)
				medal.Position = UDim2.fromOffset(6, 0)
				medal.Parent = row
				if r.rank == 1 then
					UIMotion.ShineLoop(row, 3)
				end
			else
				text(row, tostring(r.rank), 18, if mine then C.Navy else C.Muted, 10, 0, 40, 40, Theme.Font.Number)
			end
			text(row, r.name, 16, ink, 60, 0, 400, 40)
			text(
				row,
				tostring(r.power),
				20,
				if mine then C.Navy else C.Yellow,
				560,
				0,
				140,
				40,
				Theme.Font.Number,
				Enum.TextXAlignment.Right
			)
			shown += 1
		end
		if shown == 0 then
			text(
				body,
				if result.offline
					then "Sıralama, oyun yayınlanınca ve veri deposu açıkken çalışır. Studio'da kayıt bellekte tutulduğu için liste boş."
					else "Henüz sıralamaya giren oyuncu yok. İlk maçını oyna, listeye gir.",
				14,
				C.Text,
				0,
				40,
				700,
				60,
				Theme.Font.Body
			).TextWrapped =
				true
		end
		local me = Instance.new("Frame")
		me.Name = "Me"
		me.AnchorPoint = Vector2.new(0, 1)
		me.Position = UDim2.fromScale(0, 1)
		me.Size = UDim2.new(1, 0, 0, 54)
		me.BackgroundColor3 = DARK
		me.BorderSizePixel = 0
		corner(me, 8)
		me.Parent = body
		local icon = Icons.Build("Trophy", 32, C.Yellow)
		icon.Position = UDim2.fromOffset(12, 11)
		icon.Parent = me
		text(me, "SENİN GÜCÜN", 11, C.Muted, 60, 6, 200, 16)
		text(me, if result.me.name ~= "" then result.me.name else "Oyuncu", 17, C.White, 60, 22, 400, 24)
		text(me, tostring(result.me.power), 26, C.Yellow, 560, 8, 140, 38, Theme.Font.Number, Enum.TextXAlignment.Right)
	end)
	task.spawn(function()
		local ok, res = pcall(function()
			return Remotes.Get("GetLeaderboard"):InvokeServer()
		end)
		local data = getData()
		result = if ok and type(res) == "table"
			then res
			else {
				rows = {},
				offline = true,
				me = { name = if data then data.name else "", power = if data then data.power or 0 else 0, userId = 0 },
			}
		Hub.Refresh()
	end)
end

return Hub

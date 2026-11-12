--[[
	Halftime
	Devre arası ekranı: ilk yarının özeti, takım emri ve oyuncu değişikliği.
	Sahadan bir oyuncu ve kulübeden bir yedek seçilip "Değiştir" denir (en çok 3 değişiklik).
	Oyuncunun kendisi değiştirilemez.

	Halftime.Show(gui, ctx, onContinue)
	ctx = {
		homeName, awayName, home, away,            skor
		stats = MatchAI.Stats(),                   şut ve topa sahip olma
		squad = () -> { {slot, info, tired} },     sahadaki takım arkadaşları (güncel)
		bench = { info, ... },                     yedekler (kullanılan çıkarılır)
		subsLeft = () -> number,
		substitute = (slot, benchIndex) -> boolean,
		order = () -> string, setOrder = (name) -> (),
		me = { name, number },
	}
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(ReplicatedStorage.UI.Components)
local Theme = require(ReplicatedStorage.UI.Theme)
local UIMotion = require(ReplicatedStorage.UI.UIMotion)

local Halftime = {}

local C = Theme.Color
local ORDERS = { "Dengeli", "Atak", "Defans", "Pres" }

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

local function ratingColor(v: number): Color3
	return if v >= 80 then C.Gold elseif v >= 65 then C.Good elseif v >= 45 then C.Yellow else C.Muted
end

function Halftime.Show(gui: ScreenGui, ctx, onContinue: () -> ())
	local root = Instance.new("Frame")
	root.Name = "Halftime"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(6, 11, 36)
	root.BackgroundTransparency = 0.08
	root.BorderSizePixel = 0
	root.ZIndex = 140
	root.Parent = gui
	local panel, content = Components.Panel({
		Name = "HalftimePanel",
		Size = UDim2.fromOffset(1180, 700),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Title = "Devre Arası",
	})
	panel.ZIndex = 141
	panel.Parent = root

	-- özet
	text(
		content,
		string.format("%s  %d - %d  %s", ctx.homeName, ctx.home, ctx.away, ctx.awayName),
		30,
		C.White,
		0,
		40,
		520,
		40,
		Theme.Font.Display
	)
	local st = ctx.stats
	local total = math.max(1, st.possession.home + st.possession.away)
	text(
		content,
		string.format(
			"Şut %d - %d   ·   Topa sahip olma %%%d - %%%d",
			st.shots.home,
			st.shots.away,
			math.floor(st.possession.home / total * 100 + 0.5),
			math.floor(st.possession.away / total * 100 + 0.5)
		),
		15,
		C.Muted,
		0,
		82,
		700,
		22
	)

	local selectedSlot: number? = nil
	local selectedBench: number? = nil
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, 118)
	body.Size = UDim2.new(1, 0, 1, -118)
	body.Parent = content

	local draw: () -> ()
	local function row(parent: Instance, y: number, w: number, selected: boolean, disabled: boolean, onClick: (() -> ())?): TextButton
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Text = ""
		b.Size = UDim2.fromOffset(w, 36)
		b.Position = UDim2.fromOffset(0, y)
		b.BackgroundColor3 = if selected then C.Yellow elseif disabled then C.Ground else C.Blue
		b.BackgroundTransparency = if selected then 0 else 0.3
		b.BorderSizePixel = 0
		local u = Instance.new("UICorner")
		u.CornerRadius = UDim.new(0, 6)
		u.Parent = b
		b.Parent = parent
		if onClick and not disabled then
			b.Activated:Connect(onClick)
		end
		return b
	end

	draw = function()
		for _, child in ipairs(body:GetChildren()) do
			child:Destroy()
		end
		-- sahadakiler
		local left = Instance.new("Frame")
		left.BackgroundTransparency = 1
		left.Size = UDim2.fromOffset(470, 540)
		left.Parent = body
		text(left, "SAHADAKİLER", 13, C.Yellow, 0, 0, 300, 20)
		text(left, "GÜÇ", 11, C.Muted, 330, 2, 50, 18, nil, Enum.TextXAlignment.Center)
		text(left, "YORGUNLUK", 11, C.Muted, 384, 2, 86, 18, nil, Enum.TextXAlignment.Center)
		local list = ctx.squad()
		local y = 26
		for _, p in ipairs(list) do
			local on = selectedSlot == p.slot
			local b = row(left, y, 470, on, false, function()
				selectedSlot = if selectedSlot == p.slot then nil else p.slot
				draw()
			end)
			b.Name = "Starter"
			local ink = if on then C.Navy else C.Text
			text(
				b,
				tostring(p.info.number),
				15,
				if on then C.Navy else C.Yellow,
				8,
				0,
				34,
				36,
				Theme.Font.Number,
				Enum.TextXAlignment.Center
			)
			text(b, p.info.name, 15, ink, 50, 0, 200, 36)
			text(b, p.info.role, 12, if on then C.Navy else C.Muted, 258, 0, 60, 36)
			text(
				b,
				tostring(p.info.rating),
				17,
				if on then C.Navy else ratingColor(p.info.rating),
				330,
				0,
				50,
				36,
				Theme.Font.Number,
				Enum.TextXAlignment.Center
			)
			-- yorgunluk çubuğu
			local track = Instance.new("Frame")
			track.Size = UDim2.fromOffset(70, 8)
			track.Position = UDim2.fromOffset(392, 14)
			track.BackgroundColor3 = C.Ground
			track.BorderSizePixel = 0
			track.Parent = b
			local fill = Instance.new("Frame")
			fill.Size = UDim2.fromScale(math.clamp(p.tired, 0.04, 1), 1) -- devre arasında yarıya kadar dolar
			fill.BackgroundColor3 = if p.tired > 0.7 then C.Bad elseif p.tired > 0.35 then C.Gold else C.Good
			fill.BorderSizePixel = 0
			fill.Parent = track
			y += 40
		end
		local me = row(left, y, 470, false, true, nil)
		me.Name = "Me"
		text(me, tostring(ctx.me.number), 15, C.Yellow, 8, 0, 34, 36, Theme.Font.Number, Enum.TextXAlignment.Center)
		text(me, Theme.Upper(ctx.me.name) .. "  (SEN · değiştirilemez)", 14, C.Muted, 50, 0, 400, 36)

		-- yedekler
		local mid = Instance.new("Frame")
		mid.BackgroundTransparency = 1
		mid.Position = UDim2.fromOffset(500, 0)
		mid.Size = UDim2.fromOffset(330, 540)
		mid.Parent = body
		text(mid, "YEDEKLER", 13, C.Yellow, 0, 0, 200, 20)
		text(mid, "Kalan değişiklik: " .. ctx.subsLeft(), 12, C.Muted, 150, 0, 180, 20, nil, Enum.TextXAlignment.Right)
		local by = 26
		for i, info in ipairs(ctx.bench) do
			local on = selectedBench == i
			local b = row(mid, by, 330, on, false, function()
				selectedBench = if selectedBench == i then nil else i
				draw()
			end)
			b.Name = "Sub"
			local ink = if on then C.Navy else C.Text
			text(b, tostring(info.number), 15, if on then C.Navy else C.Yellow, 8, 0, 34, 36, Theme.Font.Number, Enum.TextXAlignment.Center)
			text(b, info.name, 15, ink, 50, 0, 170, 36)
			text(b, info.role, 12, if on then C.Navy else C.Muted, 222, 0, 50, 36)
			text(
				b,
				tostring(info.rating),
				17,
				if on then C.Navy else ratingColor(info.rating),
				276,
				0,
				46,
				36,
				Theme.Font.Number,
				Enum.TextXAlignment.Center
			)
			by += 40
		end
		if #ctx.bench == 0 then
			text(mid, "Kulübede oyuncu kalmadı.", 13, C.Muted, 0, 30, 330, 20)
		end
		local can = selectedSlot ~= nil and selectedBench ~= nil and ctx.subsLeft() > 0
		local swap = Components.Button({
			Text = "Değiştir",
			Style = if can then "Primary" else "Secondary",
			Sub = if ctx.subsLeft() <= 0
				then "Değişiklik hakkın bitti"
				elseif can then "Seçilen ikiliyi değiştir"
				else "Bir sahadan, bir kulübeden seç",
			Size = UDim2.fromOffset(330, 60),
			OnClick = function()
				if not can then
					Components.Toast(
						"info",
						if ctx.subsLeft() <= 0 then "Değişiklik hakkın bitti." else "Sahadan bir oyuncu ve kulübeden bir yedek seç."
					)
					return
				end
				if ctx.substitute(selectedSlot :: number, selectedBench :: number) then
					UIMotion.Sound("ConfirmSound")
					selectedSlot, selectedBench = nil, nil
					draw()
				end
			end,
		})
		swap.Name = "Swap"
		swap.Position = UDim2.fromOffset(0, by + 14)
		swap.Parent = mid

		-- takım emri
		local right = Instance.new("Frame")
		right.BackgroundTransparency = 1
		right.Position = UDim2.fromOffset(860, 0)
		right.Size = UDim2.fromOffset(288, 540)
		right.Parent = body
		text(right, "İKİNCİ YARI EMRİ", 13, C.Yellow, 0, 0, 288, 20)
		for i, name in ipairs(ORDERS) do
			local on = ctx.order() == name
			local b = row(right, 26 + (i - 1) * 44, 288, on, false, function()
				ctx.setOrder(name)
				draw()
			end)
			b.Size = UDim2.fromOffset(288, 40)
			b.Name = "Order"
			text(b, Theme.Upper(name), 15, if on then C.Navy else C.Text, 0, 0, 288, 40, nil, Enum.TextXAlignment.Center)
		end
	end
	draw()

	local go = Components.Button({
		Text = "İkinci yarı",
		Style = "Primary",
		Sub = "Rakibin santrasıyla başlar",
		Size = UDim2.fromOffset(288, 64),
		OnClick = function()
			UIMotion.Wipe(function()
				root:Destroy()
				onContinue()
			end)
		end,
	})
	go.Name = "Continue"
	go.AnchorPoint = Vector2.new(1, 1)
	go.Position = UDim2.fromScale(1, 1)
	go.Parent = content
	UIMotion.In(panel, Vector2.new(0, 30))
	return root
end

return Halftime

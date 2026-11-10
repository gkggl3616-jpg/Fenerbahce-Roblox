--[[
	Components
	Ortak arayüz parçaları: Panel, Button, Bar, Badge, Label, Stripes, Toast.
	Hepsi Theme ve UIMotion kullanır. Ekranlar bu parçalardan kurulur.
]]

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local UIMotion = require(script.Parent.UIMotion)

local C = Theme.Color
local Components = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or Theme.Stroke
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function padding(parent: Instance, px: number, py: number?)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, py or px)
	p.PaddingBottom = UDim.new(0, py or px)
	p.Parent = parent
	return p
end
Components.Corner = corner
Components.Stroke = stroke
Components.Padding = padding

-- Metin. props: Text, Size (TextSize), Color, Font, Upper, Align
function Components.Label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = props.Font or Theme.Font.Body
	l.TextSize = props.Size or 16
	l.TextColor3 = props.Color or C.Text
	l.Text = if props.Upper then Theme.Upper(props.Text or "") else (props.Text or "")
	l.TextXAlignment = props.Align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextWrapped = props.Wrap == true
	l.TextTruncate = if props.Wrap then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd
	l.AutomaticSize = props.Auto or Enum.AutomaticSize.None
	l.Size = props.Frame or UDim2.new(1, 0, 0, (props.Size or 16) + 6)
	l.LayoutOrder = props.Order or 0
	return l
end

-- Eğik sarı-lacivert çubuk şeridi (panel köşesi süsü). Üst öğe CanvasGroup olmalı ki kırpılsın.
function Components.Stripes(count: number?, width: number?)
	local holder = Instance.new("Frame")
	holder.Name = "Stripes"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset((count or 5) * (width or 10) * 1.6, 60)
	for i = 1, count or 5 do
		local b = Instance.new("Frame")
		b.BorderSizePixel = 0
		b.BackgroundColor3 = if i % 2 == 0 then C.Blue else C.Yellow
		b.BackgroundTransparency = if i % 2 == 0 then 0.2 else 0.05
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Size = UDim2.new(0, width or 10, 2, 0)
		b.Position = UDim2.new(0, (i - 0.5) * (width or 10) * 1.6, 0.5, 0)
		b.Rotation = Theme.Skew
		b.Parent = holder
	end
	return holder
end

-- Cam panel. props: Size, Position, AnchorPoint, Title, Accent (köşe çubukları), Gold
-- Dönen: panel (CanvasGroup), içerik (Frame)
function Components.Panel(props)
	local p = Instance.new("CanvasGroup")
	p.Name = props.Name or "Panel"
	p.Size = props.Size or UDim2.fromOffset(320, 200)
	p.Position = props.Position or UDim2.new()
	p.AnchorPoint = props.AnchorPoint or Vector2.zero
	p.BackgroundColor3 = C.Navy
	p.BackgroundTransparency = Theme.PanelTransparency
	p.BorderSizePixel = 0
	corner(p, Theme.Corner.Medium)

	-- Dikey renk geçişi: üstte açık, altta koyu (cam hissi)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.fromRGB(215, 225, 255), Color3.fromRGB(150, 160, 215))
	g.Parent = p

	-- Çerçeve: üstte sarı, alta doğru sönen çizgi
	local s = stroke(p, if props.Gold then C.Gold else C.Yellow, Theme.Stroke, 0.15)
	local sg = Instance.new("UIGradient")
	sg.Rotation = 90
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.35, 0.75),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	sg.Parent = s

	-- Üst parlak kenar
	local hi = Instance.new("Frame")
	hi.Name = "Highlight"
	hi.BorderSizePixel = 0
	hi.BackgroundColor3 = C.White
	hi.BackgroundTransparency = 0.82
	hi.Size = UDim2.new(1, 0, 0, 1)
	hi.Parent = p

	if props.Accent ~= false then
		local st = Components.Stripes(4, 8)
		st.AnchorPoint = Vector2.new(1, 0)
		st.Position = UDim2.new(1, 6, 0, -14)
		st.Parent = p
	end

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = p
	padding(content, 16, 14)

	if props.Title then
		local t = Components.Label({ Text = props.Title, Size = 18, Font = Theme.Font.Display, Color = C.Yellow, Upper = true })
		t.Parent = content
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = C.Yellow
		line.Size = UDim2.fromOffset(34, 3)
		line.Position = UDim2.fromOffset(0, 26)
		line.Parent = content
	end
	return p, content
end

-- Buton. props: Text, Style ("Primary" | "Secondary" | "Ghost"), Size, Locked (neden kilitli metni), OnClick
function Components.Button(props)
	local style = props.Style or "Primary"
	local locked = props.Locked ~= nil
	local b = Instance.new("TextButton")
	b.Name = props.Name or "Button"
	b.AutoButtonColor = false
	b.Text = ""
	b.Size = props.Size or UDim2.new(1, 0, 0, 52)
	b.BorderSizePixel = 0
	b.ClipsDescendants = true
	b.LayoutOrder = props.Order or 0
	b.BackgroundColor3 = if locked
		then Color3.fromRGB(42, 52, 112)
		elseif style == "Primary" then C.Yellow
		elseif style == "Secondary" then C.Blue
		else C.Navy
	b.BackgroundTransparency = if style == "Ghost" and not locked then 0.6 else 0
	corner(b, Theme.Corner.Small)
	if style == "Ghost" then
		stroke(b, C.Yellow, Theme.Stroke, 0.1)
	elseif style == "Secondary" then
		stroke(b, C.White, 1, 0.85)
	end
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(C.White, Color3.fromRGB(205, 205, 215))
	grad.Parent = b

	local scale = Instance.new("UIScale")
	scale.Parent = b

	local textColor = if locked then C.Muted elseif style == "Primary" then C.Navy elseif style == "Ghost" then C.Yellow else C.Text
	local label = Components.Label({
		Text = props.Text,
		Size = props.TextSize or 19,
		Font = Theme.Font.Display,
		Color = textColor,
		Upper = true,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.fromScale(1, 1),
	})
	label.Parent = b

	-- Sol kenarda eğik vurgu çizgisi (birincil butonda lacivert, diğerlerinde sarı)
	if not locked then
		local slash = Instance.new("Frame")
		slash.BorderSizePixel = 0
		slash.BackgroundColor3 = if style == "Primary" then C.Navy else C.Yellow
		slash.BackgroundTransparency = if style == "Primary" then 0.8 else 0.25
		slash.AnchorPoint = Vector2.new(0.5, 0.5)
		slash.Size = UDim2.new(0, 6, 2, 0)
		slash.Position = UDim2.new(0, 14, 0.5, 0)
		slash.Rotation = Theme.Skew
		slash.Parent = b
	end

	local hover = false
	b.MouseEnter:Connect(function()
		hover = true
		UIMotion.Tween(scale, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 1.04 })
		if not locked then
			UIMotion.Shine(b)
		end
	end)
	b.MouseLeave:Connect(function()
		hover = false
		UIMotion.Tween(scale, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		UIMotion.Tween(scale, 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 0.96 })
	end)
	b.MouseButton1Up:Connect(function()
		UIMotion.Tween(scale, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = if hover then 1.04 else 1 })
	end)
	b.Activated:Connect(function(input)
		if locked then
			UIMotion.Sound("ErrorSound")
			UIMotion.Shake(b)
			Components.Toast("error", props.Locked)
			return
		end
		UIMotion.Sound("ClickSound")
		local pos
		if input and input.Position then
			pos = Vector2.new(input.Position.X, input.Position.Y)
		else
			local m = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
			pos = m
		end
		UIMotion.Ripple(b, pos)
		if props.OnClick then
			props.OnClick(b)
		end
	end)
	return b, label
end

-- İlerleme çubuğu. Dönen nesne: { Frame, Set(oran, anında?) }
function Components.Bar(props)
	local track = Instance.new("Frame")
	track.Name = "Bar"
	track.BorderSizePixel = 0
	track.BackgroundColor3 = C.Ground
	track.Size = props.Size or UDim2.new(1, 0, 0, 10)
	track.LayoutOrder = props.Order or 0
	track.ClipsDescendants = true
	corner(track, 5)
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = props.Color or C.Yellow
	fill.Size = UDim2.fromScale(0, 1)
	corner(fill, 5)
	fill.Parent = track
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(190, 190, 190), C.White)
	g.Parent = fill
	-- Uçta parlama
	local tip = Instance.new("Frame")
	tip.BorderSizePixel = 0
	tip.BackgroundColor3 = C.White
	tip.BackgroundTransparency = 0.35
	tip.AnchorPoint = Vector2.new(1, 0)
	tip.Position = UDim2.fromScale(1, 0)
	tip.Size = UDim2.new(0, 6, 1, 0)
	tip.Parent = fill
	local api = { Frame = track, Value = 0 }
	function api.Set(ratio: number, instant: boolean?)
		ratio = math.clamp(ratio, 0, 1)
		api.Value = ratio
		if instant then
			fill.Size = UDim2.fromScale(ratio, 1)
		else
			UIMotion.Tween(fill, 0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Size = UDim2.fromScale(ratio, 1) })
		end
	end
	api.Set(props.Value or 0, true)
	return api
end

-- Kalkan rozet. props: Text, Size (piksel), Color, Image (arma)
function Components.Badge(props)
	local size = props.Size or 56
	local g = Instance.new("CanvasGroup")
	g.Name = "Badge"
	g.BackgroundTransparency = 1
	g.Size = UDim2.fromOffset(size, size * 1.16)
	g.LayoutOrder = props.Order or 0
	if props.Image and props.Image ~= "" then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = props.Image
		img.Size = UDim2.fromScale(1, 1)
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = g
		return g
	end
	local color = props.Color or C.Yellow
	local top = Instance.new("Frame")
	top.BorderSizePixel = 0
	top.BackgroundColor3 = color
	top.Size = UDim2.fromScale(1, 0.62)
	top.Parent = g
	local tipHolder = Instance.new("Frame")
	tipHolder.BorderSizePixel = 0
	tipHolder.BackgroundColor3 = color
	tipHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	tipHolder.Position = UDim2.fromScale(0.5, 0.62)
	tipHolder.Size = UDim2.fromOffset(size * 0.7072, size * 0.7072)
	tipHolder.Rotation = 45
	tipHolder.Parent = g
	local l = Components.Label({
		Text = props.Text or "F",
		Size = size * 0.44,
		Font = Theme.Font.Display,
		Color = props.TextColor or C.Navy,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.fromScale(1, 0.72),
	})
	l.ZIndex = 2
	l.Parent = g
	return g
end

-- Bildirimler: sağ üstten kayar. kind: success | error | unlock | level | info
local toastHolder: Frame? = nil
function Components.SetToastHolder(holder: Frame)
	toastHolder = holder
end

function Components.Toast(kind: string, text: string)
	if not toastHolder then
		return
	end
	local color = if kind == "error"
		then C.Bad
		elseif kind == "success" then C.Good
		elseif kind == "unlock" or kind == "level" then C.Gold
		else C.Yellow
	local card = Instance.new("CanvasGroup")
	card.Name = "Toast"
	card.Size = UDim2.new(1, 0, 0, 54)
	card.BackgroundColor3 = C.Navy
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel = 0
	corner(card, Theme.Corner.Small)
	stroke(card, color, Theme.Stroke, 0.2)
	local bar = Instance.new("Frame")
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = color
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.new(0, 10, 0.5, 0)
	bar.Size = UDim2.new(0, 7, 2, 0)
	bar.Rotation = Theme.Skew
	bar.Parent = card
	local l = Components.Label({ Text = text, Size = 15, Wrap = true, Frame = UDim2.new(1, -40, 1, 0) })
	l.Position = UDim2.fromOffset(30, 0)
	l.Parent = card
	card.Parent = toastHolder
	UIMotion.Sound(if kind == "error" then "ErrorSound" elseif kind == "unlock" or kind == "level" then "RewardSound" else "ConfirmSound")
	-- Liste düzeni konumu yönettiği için giriş saydamlık + ölçekle yapılır
	card.GroupTransparency = 1
	UIMotion.Tween(card, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { GroupTransparency = 0 })
	UIMotion.Pop(card, 0.85)
	task.delay(3.2, function()
		local tw = UIMotion.Tween(card, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { GroupTransparency = 1 })
		tw.Completed:Once(function()
			card:Destroy()
		end)
	end)
end

return Components

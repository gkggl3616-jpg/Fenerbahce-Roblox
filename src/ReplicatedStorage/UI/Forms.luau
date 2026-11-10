--[[
	Forms
	Girdi bileşenleri: TextInput, Chips (tekli/çoklu seçim), Slider, Stepper, Swatches, Tabs, Modal.
	Hepsi Theme ve UIMotion kullanır; her değişiklikte küçük bir tepki animasyonu oynar.
]]

local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local UIMotion = require(script.Parent.UIMotion)
local Components = require(script.Parent.Components)

local C = Theme.Color
local Forms = {}

local Q, OUT = Enum.EasingStyle.Quad, Enum.EasingDirection.Out

local function row(gap: number, height: number?, order: number?)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, height or 40)
	f.LayoutOrder = order or 0
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Wraps = true
	l.Parent = f
	f.AutomaticSize = Enum.AutomaticSize.Y
	return f
end
Forms.Row = row

-- Küçük başlık etiketi
function Forms.Caption(text: string, order: number?)
	return Components.Label({
		Text = text,
		Size = 12,
		Color = C.Muted,
		Font = Theme.Font.Title,
		Upper = true,
		Order = order,
		Frame = UDim2.new(1, 0, 0, 16),
	})
end

-- Metin kutusu. props: Text, Placeholder, MaxLength, Width, Upper, OnChange(text)
function Forms.TextInput(props)
	local holder = Instance.new("Frame")
	holder.Name = "TextInput"
	holder.BackgroundColor3 = C.Ground
	holder.BorderSizePixel = 0
	holder.Size = props.Size or UDim2.new(1, 0, 0, 40)
	holder.LayoutOrder = props.Order or 0
	Components.Corner(holder, Theme.Corner.Small)
	local st = Components.Stroke(holder, C.White, 1.5, 0.84)
	local box = Instance.new("TextBox")
	box.BackgroundTransparency = 1
	box.Size = UDim2.new(1, -24, 1, 0)
	box.Position = UDim2.fromOffset(12, 0)
	box.ClearTextOnFocus = false
	box.FontFace = Theme.Font.Body
	box.TextSize = 17
	box.TextColor3 = C.Text
	box.PlaceholderColor3 = C.Muted
	box.PlaceholderText = props.Placeholder or ""
	box.Text = props.Text or ""
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Parent = holder
	local max = props.MaxLength or 16
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local t = box.Text
		if props.Upper then
			t = string.upper(t)
		end
		if props.Pattern then
			t = string.gsub(t, props.Pattern, "")
		end
		if utf8.len(t) and utf8.len(t) > max then
			t = string.sub(t, 1, utf8.offset(t, max + 1) - 1)
		end
		if t ~= box.Text then
			box.Text = t
			return
		end
		if props.OnChange then
			props.OnChange(t)
		end
	end)
	box.Focused:Connect(function()
		UIMotion.Tween(st, 0.15, Q, OUT, { Color = C.Yellow, Transparency = 0 })
	end)
	box.FocusLost:Connect(function()
		UIMotion.Tween(st, 0.15, Q, OUT, { Color = C.White, Transparency = 0.84 })
	end)
	return holder, box
end

-- Seçim çipleri. props: Options = { {Id, Text, Locked?} }, Value (tekli) veya Values (çoklu tablo), Multi, OnChange
function Forms.Chips(props)
	local holder = row(6, 34, props.Order)
	holder.Name = "Chips"
	local chips = {}
	local api = { Frame = holder, Value = props.Value, Values = props.Values or {} }
	local function paint()
		for id, chip in pairs(chips) do
			local on = if props.Multi then api.Values[id] == true else api.Value == id
			UIMotion.Tween(chip, 0.12, Q, OUT, { BackgroundColor3 = if on then C.Yellow else C.Ground })
			chip.Label.TextColor3 = if on then C.Navy else (if chip:GetAttribute("Locked") then C.Muted else C.Text)
			chip.Stroke.Transparency = if on then 1 else 0.8
		end
	end
	for i, opt in ipairs(props.Options) do
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Text = ""
		b.BackgroundColor3 = C.Ground
		b.BorderSizePixel = 0
		b.Size = UDim2.fromOffset(props.ChipWidth or 0, 34)
		b.AutomaticSize = if props.ChipWidth then Enum.AutomaticSize.None else Enum.AutomaticSize.X
		b.LayoutOrder = i
		Components.Corner(b, Theme.Corner.Small)
		local st = Components.Stroke(b, C.White, 1, 0.8)
		st.Name = "Stroke"
		local l = Components.Label({
			Text = opt.Text,
			Size = 14,
			Font = Theme.Font.Title,
			Upper = true,
			Align = Enum.TextXAlignment.Center,
			Frame = UDim2.new(0, 0, 1, 0),
			Auto = Enum.AutomaticSize.X,
		})
		l.Name = "Label"
		if props.ChipWidth then
			l.Size = UDim2.fromScale(1, 1)
			l.AutomaticSize = Enum.AutomaticSize.None
		end
		l.Parent = b
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, if props.ChipWidth then 0 else 12)
		pad.PaddingRight = UDim.new(0, if props.ChipWidth then 0 else 12)
		pad.Parent = b
		local sc = Instance.new("UIScale")
		sc.Parent = b
		b:SetAttribute("Locked", opt.Locked ~= nil)
		b.Activated:Connect(function()
			if opt.Locked then
				UIMotion.Sound("ErrorSound")
				UIMotion.Shake(b)
				Components.Toast("error", opt.Locked)
				return
			end
			UIMotion.Sound("ClickSound")
			if props.Multi then
				api.Values[opt.Id] = not api.Values[opt.Id]
			else
				api.Value = opt.Id
			end
			sc.Scale = 0.9
			UIMotion.Tween(sc, 0.25, Enum.EasingStyle.Back, OUT, { Scale = 1 })
			paint()
			if props.OnChange then
				props.OnChange(if props.Multi then api.Values else api.Value)
			end
		end)
		b.Parent = holder
		chips[opt.Id] = b
	end
	paint()
	return api
end

-- Renk daireleri. props: Colors = { Color3 }, Value (indeks), OnChange(indeks)
function Forms.Swatches(props)
	local holder = row(8, 36, props.Order)
	holder.Name = "Swatches"
	local api = { Frame = holder, Value = props.Value or 1 }
	local rings = {}
	local function paint()
		for i, ring in ipairs(rings) do
			ring.Transparency = if i == api.Value then 0 else 1
		end
	end
	for i, col in ipairs(props.Colors) do
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Text = ""
		b.BackgroundColor3 = col
		b.BorderSizePixel = 0
		b.Size = UDim2.fromOffset(34, 34)
		b.LayoutOrder = i
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(1, 0)
		cr.Parent = b
		local ring = Components.Stroke(b, C.Yellow, 3, 1)
		rings[i] = ring
		local sc = Instance.new("UIScale")
		sc.Parent = b
		b.Activated:Connect(function()
			UIMotion.Sound("ClickSound")
			api.Value = i
			sc.Scale = 0.8
			UIMotion.Tween(sc, 0.25, Enum.EasingStyle.Back, OUT, { Scale = 1 })
			paint()
			if props.OnChange then
				props.OnChange(i)
			end
		end)
		b.Parent = holder
	end
	paint()
	return api
end

-- Kaydırıcı. props: Min, Max, Value, Format(value) -> string, OnChange(value)
function Forms.Slider(props)
	local holder = Instance.new("Frame")
	holder.Name = "Slider"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 40)
	holder.LayoutOrder = props.Order or 0
	local track = Instance.new("TextButton")
	track.AutoButtonColor = false
	track.Text = ""
	track.BackgroundColor3 = C.Ground
	track.BorderSizePixel = 0
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 0, 0.5, 0)
	track.Size = UDim2.new(1, -86, 0, 10)
	Components.Corner(track, 5)
	track.Parent = holder
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = C.Yellow
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	Components.Corner(fill, 5)
	fill.Parent = track
	local knob = Instance.new("Frame")
	knob.BackgroundColor3 = C.White
	knob.BorderSizePixel = 0
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(22, 22)
	knob.Position = UDim2.fromScale(0, 0.5)
	local kc = Instance.new("UICorner")
	kc.CornerRadius = UDim.new(1, 0)
	kc.Parent = knob
	Components.Stroke(knob, C.Yellow, 3, 0)
	local ks = Instance.new("UIScale")
	ks.Parent = knob
	knob.Parent = track
	local value = Components.Label({
		Text = "",
		Size = 18,
		Font = Theme.Font.Number,
		Color = C.Yellow,
		Align = Enum.TextXAlignment.Right,
		Frame = UDim2.new(0, 80, 1, 0),
	})
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.fromScale(1, 0)
	value.Parent = holder

	local api = { Frame = holder, Value = props.Value or props.Min }
	local function set(v: number, fire: boolean)
		v = math.clamp(math.floor(v + 0.5), props.Min, props.Max)
		local changed = v ~= api.Value
		api.Value = v
		local r = (v - props.Min) / (props.Max - props.Min)
		fill.Size = UDim2.fromScale(r, 1)
		knob.Position = UDim2.fromScale(r, 0.5)
		value.Text = if props.Format then props.Format(v) else tostring(v)
		if fire and changed and props.OnChange then
			props.OnChange(v)
		end
	end
	local dragging = false
	local function fromX(x: number)
		local r = (x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X)
		set(props.Min + r * (props.Max - props.Min), true)
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			UIMotion.Tween(ks, 0.1, Q, OUT, { Scale = 1.25 })
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			UIMotion.Tween(ks, 0.2, Enum.EasingStyle.Back, OUT, { Scale = 1 })
		end
	end)
	set(api.Value, false)
	return api
end

-- Artı/eksi sayacı. props: Min, Max, Value, OnChange
function Forms.Stepper(props)
	local holder = Instance.new("Frame")
	holder.Name = "Stepper"
	holder.BackgroundColor3 = C.Ground
	holder.BorderSizePixel = 0
	holder.Size = props.Size or UDim2.fromOffset(130, 40)
	holder.LayoutOrder = props.Order or 0
	Components.Corner(holder, Theme.Corner.Small)
	Components.Stroke(holder, C.White, 1.5, 0.84)
	local api = { Frame = holder, Value = props.Value or props.Min }
	local value = Components.Label({
		Text = tostring(api.Value),
		Size = 20,
		Font = Theme.Font.Number,
		Color = C.Yellow,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.fromScale(1, 1),
	})
	value.Parent = holder
	local function side(text: string, x: number, delta: number)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.Text = text
		b.FontFace = Theme.Font.Display
		b.TextSize = 24
		b.TextColor3 = C.Text
		b.Size = UDim2.new(0, 40, 1, 0)
		b.AnchorPoint = Vector2.new(x, 0)
		b.Position = UDim2.fromScale(x, 0)
		b.Parent = holder
		local holding = false
		local function step()
			local v = api.Value + delta
			if v > props.Max then
				v = props.Min
			elseif v < props.Min then
				v = props.Max
			end
			api.Value = v
			value.Text = tostring(v)
			UIMotion.Pop(value, 1.2)
			if props.OnChange then
				props.OnChange(v)
			end
		end
		b.MouseButton1Down:Connect(function()
			holding = true
			UIMotion.Sound("ClickSound")
			step()
			task.delay(0.4, function()
				while holding do
					step()
					task.wait(0.06)
				end
			end)
		end)
		b.MouseButton1Up:Connect(function()
			holding = false
		end)
		b.MouseLeave:Connect(function()
			holding = false
		end)
	end
	side("−", 0, -1)
	side("+", 1, 1)
	return api
end

-- Sekmeler. props: Tabs = { {Id, Text} }, Value, OnChange(id)
function Forms.Tabs(props)
	local holder = Instance.new("Frame")
	holder.Name = "Tabs"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 38)
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 4)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = holder
	local api = { Frame = holder, Value = props.Value or props.Tabs[1].Id }
	local items = {}
	local function paint()
		for id, it in pairs(items) do
			local on = id == api.Value
			it.Label.TextColor3 = if on then C.Yellow else C.Muted
			UIMotion.Tween(it.Line, 0.2, Enum.EasingStyle.Quint, OUT, { Size = UDim2.new(if on then 1 else 0, 0, 0, 3) })
		end
	end
	for i, tab in ipairs(props.Tabs) do
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.Text = ""
		b.Size = UDim2.new(1 / #props.Tabs, -4, 1, 0)
		b.LayoutOrder = i
		local label = Components.Label({
			Text = tab.Text,
			Size = 15,
			Font = Theme.Font.Display,
			Upper = true,
			Align = Enum.TextXAlignment.Center,
			Frame = UDim2.new(1, 0, 1, -4),
		})
		label.Name = "Label"
		label.Parent = b
		local line = Instance.new("Frame")
		line.Name = "Line"
		line.BackgroundColor3 = C.Yellow
		line.BorderSizePixel = 0
		line.AnchorPoint = Vector2.new(0.5, 1)
		line.Position = UDim2.fromScale(0.5, 1)
		line.Size = UDim2.new(0, 0, 0, 3)
		line.Parent = b
		b.Activated:Connect(function()
			if api.Value == tab.Id then
				return
			end
			UIMotion.Sound("ClickSound")
			api.Value = tab.Id
			paint()
			if props.OnChange then
				props.OnChange(tab.Id)
			end
		end)
		b.Parent = holder
		items[tab.Id] = b
	end
	paint()
	return api
end

-- Onay penceresi. props: Parent (ScreenGui), Title, Text, Confirm, Cancel, OnConfirm, Gold
function Forms.Modal(props)
	local dim = Instance.new("TextButton")
	dim.Name = "Modal"
	dim.AutoButtonColor = false
	dim.Text = ""
	dim.BackgroundColor3 = C.Ground
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 200
	dim.Parent = props.Parent
	UIMotion.Tween(dim, 0.2, Q, OUT, { BackgroundTransparency = 0.35 })
	local panel, content = Components.Panel({
		Size = UDim2.fromOffset(460, 250),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Title = props.Title,
		Gold = props.Gold,
	})
	panel.ZIndex = 201
	panel.Parent = dim
	local body = Components.Label({ Text = props.Text, Size = 16, Wrap = true, Frame = UDim2.new(1, 0, 0, 100) })
	body.Position = UDim2.fromOffset(0, 44)
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Parent = content
	local function close()
		UIMotion.Tween(dim, 0.15, Q, Enum.EasingDirection.In, { BackgroundTransparency = 1 })
		UIMotion.Out(panel, Vector2.new(0, 20), false)
		task.delay(0.25, function()
			dim:Destroy()
		end)
	end
	local ok = Components.Button({
		Text = props.Confirm or "Onayla",
		Style = "Primary",
		Size = UDim2.new(0.5, -6, 0, 52),
		OnClick = function()
			close()
			if props.OnConfirm then
				props.OnConfirm()
			end
		end,
	})
	ok.AnchorPoint = Vector2.new(1, 1)
	ok.Position = UDim2.fromScale(1, 1)
	ok.Parent = content
	local cancel =
		Components.Button({ Text = props.Cancel or "Vazgeç", Style = "Ghost", Size = UDim2.new(0.5, -6, 0, 52), OnClick = close })
	cancel.AnchorPoint = Vector2.new(0, 1)
	cancel.Position = UDim2.fromScale(0, 1)
	cancel.Parent = content
	UIMotion.In(panel, Vector2.new(0, 30))
	UIMotion.Pop(panel, 0.9)
	return close
end

return Forms

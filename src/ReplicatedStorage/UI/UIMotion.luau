--[[
	UIMotion
	Arayüzdeki bütün hareketlerin tek kaynağı. Kural: hiçbir şey aniden belirmez.
	FadeSlide (giriş/çıkış), Stagger (sıralı giriş), Pop, CountUp, Shine, Shake, Pulse, Wipe, Ripple.
	"Hareket azaltma" ayarı açıksa süreler sıfıra yakın olur.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Theme)

local M = Config.Motion
local UIMotion = {}

UIMotion.Reduced = false

local function dur(t: number): number
	return if UIMotion.Reduced then 0.01 else t
end

local function tween(obj: Instance, t: number, style: Enum.EasingStyle, dir: Enum.EasingDirection, props)
	local tw = TweenService:Create(obj, TweenInfo.new(dur(t), style, dir), props)
	tw:Play()
	return tw
end
UIMotion.Tween = tween

local function scaleOf(gui: GuiObject): UIScale
	local s = gui:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Parent = gui
	end
	return s
end

function UIMotion.Sound(key: string)
	local id = Config.Assets[key]
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 0.5
	SoundService:PlayLocalSound(s)
	s:Destroy()
end

-- Giriş: kayarak ve saydamlıktan gelerek. offset: başlangıç kayması (piksel).
function UIMotion.In(gui: GuiObject, offset: Vector2?, delay: number?)
	local target = gui:GetAttribute("RestPos") or gui.Position
	gui:SetAttribute("RestPos", target)
	local o = offset or Vector2.new(0, 24)
	gui.Position = target + UDim2.fromOffset(o.X, o.Y)
	gui.Visible = true
	if gui:IsA("CanvasGroup") then
		gui.GroupTransparency = 1
	end
	task.delay(dur(delay or 0), function()
		tween(gui, M.In, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Position = target })
		if gui:IsA("CanvasGroup") then
			tween(gui, M.In * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { GroupTransparency = 0 })
		end
	end)
end

-- Çıkış: kısa ve hızlı. Bitince gizler (destroy = true ise siler).
function UIMotion.Out(gui: GuiObject, offset: Vector2?, destroy: boolean?)
	local rest = gui:GetAttribute("RestPos") or gui.Position
	local o = offset or Vector2.new(0, 16)
	local tw = tween(gui, M.Out, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Position = rest + UDim2.fromOffset(o.X, o.Y) })
	if gui:IsA("CanvasGroup") then
		tween(gui, M.Out, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { GroupTransparency = 1 })
	end
	tw.Completed:Once(function()
		if destroy then
			gui:Destroy()
		else
			gui.Visible = false
			gui.Position = rest
		end
	end)
end

-- Öğeleri sırayla getirir.
function UIMotion.Stagger(list: { GuiObject }, offset: Vector2?, startDelay: number?)
	for i, gui in ipairs(list) do
		local delay = (startDelay or 0) + (i - 1) * M.Stagger
		if gui.Parent and gui.Parent:FindFirstChildOfClass("UIListLayout") then
			-- Liste düzeni konumu yönetir; burada kayma yerine sırayla yaylanarak belirir
			gui.Visible = false
			task.delay(dur(delay), function()
				gui.Visible = true
				UIMotion.Pop(gui, 0.8)
			end)
		else
			UIMotion.In(gui, offset, delay)
		end
	end
end

-- Küçükten yaylanarak büyür (vurgu).
function UIMotion.Pop(gui: GuiObject, from: number?)
	local s = scaleOf(gui)
	s.Scale = from or 0.7
	tween(s, M.In, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
end

-- Sayı sayarak artar. format: sayıyı metne çeviren işlev.
function UIMotion.CountUp(label: TextLabel, from: number, to: number, format: ((number) -> string)?)
	local fmt = format or Theme.FormatNumber
	local v = Instance.new("NumberValue")
	v.Value = from
	local conn = v.Changed:Connect(function(n)
		label.Text = fmt(n)
	end)
	local tw = tween(v, M.CountUp, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { Value = to })
	tw.Completed:Once(function()
		conn:Disconnect()
		label.Text = fmt(to)
		v:Destroy()
	end)
	UIMotion.Pop(label, 1.18)
end

-- Üzerinden parlaklık süpürmesi geçer. gui ClipsDescendants = true olmalı.
function UIMotion.Shine(gui: GuiObject)
	local f = Instance.new("Frame")
	f.Name = "Shine"
	f.BackgroundColor3 = Theme.Color.White
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(0.45, 1)
	f.Position = UDim2.fromScale(-0.5, 0)
	f.ZIndex = gui.ZIndex + 5
	local g = Instance.new("UIGradient")
	g.Rotation = 20
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.65),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	f.Parent = gui
	local tw = tween(f, 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Position = UDim2.fromScale(1.05, 0) })
	tw.Completed:Once(function()
		f:Destroy()
	end)
end

-- Sağa sola sallanır (kilitli öğe, hata).
function UIMotion.Shake(gui: GuiObject)
	local rest = gui:GetAttribute("RestPos") or gui.Position
	gui:SetAttribute("RestPos", rest)
	task.spawn(function()
		for _, dx in ipairs({ -8, 7, -5, 4, -2, 0 }) do
			tween(gui, 0.045, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, { Position = rest + UDim2.fromOffset(dx, 0) })
			task.wait(dur(0.045))
		end
		gui.Position = rest
	end)
end

-- Nabız gibi sürekli büyüyüp küçülür. Durdurmak için dönen işlevi çağır.
function UIMotion.Pulse(gui: GuiObject, amount: number?, period: number?)
	local s = scaleOf(gui)
	local tw = TweenService:Create(
		s,
		TweenInfo.new(period or 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1 + (amount or 0.05) }
	)
	if not UIMotion.Reduced then
		tw:Play()
	end
	return function()
		tw:Cancel()
		s.Scale = 1
	end
end

-- Tıklama noktasından yayılan dalga halkası. gui ClipsDescendants = true olmalı.
function UIMotion.Ripple(gui: GuiObject, screenPos: Vector2?)
	local abs, size = gui.AbsolutePosition, gui.AbsoluteSize
	local p = screenPos and (screenPos - abs) or size / 2
	local c = Instance.new("Frame")
	c.Name = "Ripple"
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Position = UDim2.fromOffset(p.X, p.Y)
	c.Size = UDim2.fromOffset(0, 0)
	c.BackgroundColor3 = Theme.Color.White
	c.BackgroundTransparency = 0.7
	c.BorderSizePixel = 0
	c.ZIndex = gui.ZIndex + 4
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = c
	c.Parent = gui
	local d = math.max(size.X, size.Y) * 2.2
	local tw =
		tween(c, 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Size = UDim2.fromOffset(d, d), BackgroundTransparency = 1 })
	tw.Completed:Once(function()
		c:Destroy()
	end)
end

-- Çubuklu perde: sarı-lacivert çubuklar ekranı kapatır, onCovered çalışır, sonra açılır.
function UIMotion.Wipe(onCovered: (() -> ())?)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local sg = Instance.new("ScreenGui")
	sg.Name = "Wipe"
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 1000
	sg.ResetOnSpawn = false
	sg.Parent = playerGui
	local n = 10
	local bars = {}
	for i = 1, n do
		local b = Instance.new("Frame")
		b.BorderSizePixel = 0
		b.BackgroundColor3 = if i % 2 == 0 then Theme.Color.Navy else Theme.Color.Yellow
		b.AnchorPoint = Vector2.new(0, if i % 2 == 0 then 0 else 1)
		b.Position = UDim2.fromScale((i - 1) / n, if i % 2 == 0 then 0 else 1)
		b.Size = UDim2.new(1 / n, 2, 0, 0)
		b.Parent = sg
		bars[i] = b
	end
	UIMotion.Sound("WhooshSound")
	for i, b in ipairs(bars) do
		task.delay(dur((i - 1) * 0.025), function()
			tween(b, M.Wipe * 0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Size = UDim2.new(1 / n, 2, 1, 0) })
		end)
	end
	task.delay(dur(M.Wipe * 0.6 + n * 0.025), function()
		if onCovered then
			onCovered()
		end
		task.wait(dur(0.08))
		for i, b in ipairs(bars) do
			task.delay(dur((i - 1) * 0.025), function()
				tween(b, M.Wipe * 0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.In, { Size = UDim2.new(1 / n, 2, 0, 0) })
			end)
		end
		task.delay(dur(M.Wipe * 0.6 + n * 0.025 + 0.1), function()
			sg:Destroy()
		end)
	end)
end

return UIMotion

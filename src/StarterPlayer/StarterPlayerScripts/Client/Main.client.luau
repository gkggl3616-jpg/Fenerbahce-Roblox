--[[
	Main (istemci)
	Adım 1-2 vitrini: yükleme ekranı, çubuklu perde geçişi ve bileşen kütüphanesini kullanan
	lobi katmanı (oyuncu kartı, bakiye, menü, görevler, bildirimler). Sunucu verisiyle canlı çalışır.
	Sonraki adımlarda bu dosya ekran yöneticisine dönüşecek.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.UI.Theme)
local UIMotion = require(ReplicatedStorage.UI.UIMotion)
local Components = require(ReplicatedStorage.UI.Components)

local C = Theme.Color
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "FenerUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function list(parent: Instance, gap: number, horizontal: boolean?)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top
	l.Parent = parent
	return l
end

-- Bildirim alanı (sağ üst)
local toasts = Instance.new("Frame")
toasts.Name = "Toasts"
toasts.BackgroundTransparency = 1
toasts.AnchorPoint = Vector2.new(1, 0)
toasts.Position = UDim2.new(1, -20, 0, 96)
toasts.Size = UDim2.fromOffset(320, 400)
toasts.ZIndex = 50
toasts.Parent = gui
list(toasts, 8)
Components.SetToastHolder(toasts)

--------------------------------------------------------------------------------
-- YÜKLEME EKRANI
--------------------------------------------------------------------------------
local TIPS = {
	"Mevkin kariyer boyunca değişmez. İyi seç.",
	"Şut barını yeşil pencerede bırakırsan mükemmel vuruş olur.",
	"Rakip müdahaleye girdiği anda çalım at, dengesini kaybeder.",
	"Sezonu ilk ikide bitir, stadyumun büyüsün.",
	"Havadan gelen topta halka en dar olduğunda zıpla.",
}

local function showLoading(onDone: () -> ())
	local bg = Instance.new("Frame")
	bg.Name = "Loading"
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = C.Ground
	bg.Size = UDim2.fromScale(1, 1)
	bg.ZIndex = 100
	bg.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 130, 190))
	grad.Parent = bg

	-- Arka planda yavaşça kayan eğik çubuklar
	local stripes = Instance.new("CanvasGroup")
	stripes.BackgroundTransparency = 1
	stripes.GroupTransparency = 0.9
	stripes.Size = UDim2.fromScale(1, 1)
	stripes.ZIndex = 100
	stripes.Parent = bg
	for i = 0, 15 do
		local b = Instance.new("Frame")
		b.BorderSizePixel = 0
		b.BackgroundColor3 = if i % 2 == 0 then C.Yellow else C.Blue
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Size = UDim2.new(0.035, 0, 2, 0)
		b.Position = UDim2.fromScale(i / 14, 0.5)
		b.Rotation = Theme.Skew
		b.Parent = stripes
		UIMotion.Tween(b, 6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, { Position = UDim2.fromScale(i / 14 + 0.07, 0.5) })
	end

	local badge = Components.Badge({ Text = "F", Size = 120, Image = Config.Assets.Crest })
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.5, 0.38)
	badge.ZIndex = 101
	badge.Parent = bg
	UIMotion.Pop(badge, 0.5)
	local stopPulse = UIMotion.Pulse(badge, 0.06, 0.9)

	local title = Components.Label({
		Text = "Fener Kariyer",
		Size = 44,
		Font = Theme.Font.Display,
		Color = C.Yellow,
		Upper = true,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.new(1, 0, 0, 50),
	})
	title.Position = UDim2.fromScale(0, 0.56)
	title.ZIndex = 101
	title.Parent = bg
	local sub = Components.Label({
		Text = "1907'den beri · Kadıköy",
		Size = 16,
		Color = C.Muted,
		Upper = true,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.new(1, 0, 0, 22),
	})
	sub.Position = UDim2.new(0, 0, 0.56, 52)
	sub.ZIndex = 101
	sub.Parent = bg

	local bar = Components.Bar({ Size = UDim2.new(0.36, 0, 0, 10) })
	bar.Frame.AnchorPoint = Vector2.new(0.5, 0)
	bar.Frame.Position = UDim2.fromScale(0.5, 0.74)
	bar.Frame.ZIndex = 101
	bar.Frame.Parent = bg

	local tip =
		Components.Label({ Text = TIPS[1], Size = 15, Color = C.Text, Align = Enum.TextXAlignment.Center, Frame = UDim2.new(1, 0, 0, 22) })
	tip.Position = UDim2.new(0, 0, 0.74, 24)
	tip.ZIndex = 101
	tip.Parent = bg

	task.spawn(function()
		for step = 1, 4 do
			bar.Set(step / 4)
			tip.Text = TIPS[(step % #TIPS) + 1]
			UIMotion.Pop(tip, 0.92)
			task.wait(0.55)
		end
		stopPulse()
		UIMotion.Wipe(function()
			bg:Destroy()
			onDone()
		end)
	end)
end

--------------------------------------------------------------------------------
-- LOBİ KATMANI (bileşen vitrini)
--------------------------------------------------------------------------------
local state = { data = nil :: any, coinsShown = 0, rendered = false }
local refs: { [string]: any } = {}

local function buildLobby()
	-- Oyuncu kartı (sol üst)
	local card, cc = Components.Panel({ Name = "PlayerCard", Size = UDim2.fromOffset(340, 104), Position = UDim2.fromOffset(20, 20) })
	card.Parent = gui
	local badge = Components.Badge({ Text = "F", Size = 54, Image = Config.Assets.Crest })
	badge.Parent = cc
	refs.name = Components.Label({ Text = "...", Size = 20, Font = Theme.Font.Display, Upper = true, Frame = UDim2.new(1, -70, 0, 24) })
	refs.name.Position = UDim2.fromOffset(68, 0)
	refs.name.Parent = cc
	refs.sub = Components.Label({ Text = "", Size = 13, Color = C.Muted, Frame = UDim2.new(1, -70, 0, 18) })
	refs.sub.Position = UDim2.fromOffset(68, 24)
	refs.sub.Parent = cc
	refs.level = Components.Label({
		Text = "Seviye 1",
		Size = 13,
		Font = Theme.Font.Title,
		Color = C.Yellow,
		Upper = true,
		Frame = UDim2.fromOffset(90, 18),
	})
	refs.level.Position = UDim2.fromOffset(68, 48)
	refs.level.Parent = cc
	refs.xp = Components.Bar({ Size = UDim2.new(1, -164, 0, 8) })
	refs.xp.Frame.Position = UDim2.fromOffset(160, 53)
	refs.xp.Frame.Parent = cc

	-- Bakiye (sağ üst)
	local coin, coinC = Components.Panel({
		Name = "Coins",
		Size = UDim2.fromOffset(220, 64),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Accent = false,
	})
	coin.Parent = gui
	local coinLabel = Components.Label({ Text = "Bakiye", Size = 12, Color = C.Muted, Upper = true, Frame = UDim2.new(1, 0, 0, 14) })
	coinLabel.Parent = coinC
	refs.coins = Components.Label({ Text = "0", Size = 26, Font = Theme.Font.Number, Color = C.Yellow, Frame = UDim2.new(1, 0, 0, 28) })
	refs.coins.Position = UDim2.fromOffset(0, 14)
	refs.coins.Parent = coinC

	-- Menü (sol)
	local menu, mc = Components.Panel({
		Name = "Menu",
		Size = UDim2.fromOffset(280, 356),
		Position = UDim2.fromOffset(20, 140),
		Title = "Kariyer Merkezi",
	})
	menu.Parent = gui
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(0, 40)
	holder.Size = UDim2.new(1, 0, 1, -40)
	holder.Parent = mc
	list(holder, 8)
	local buttons = {}
	local function add(text: string, style: string, locked: string?, onClick: (() -> ())?)
		local b = Components.Button({ Text = text, Style = style, Locked = locked, Order = #buttons + 1, OnClick = onClick })
		b.Parent = holder
		table.insert(buttons, b)
	end
	add("Maça çık", "Primary", nil, function()
		UIMotion.Wipe(function()
			Components.Toast("info", "Maç sistemi 5. adımda geliyor.")
		end)
	end)
	add("Pası geliştir", "Secondary", nil, function()
		Remotes.Get("UpgradeStat"):FireServer("Pas")
	end)
	add("Plase aç", "Secondary", nil, function()
		Remotes.Get("UnlockSkill"):FireServer("Sut")
	end)
	add("Kulüp", "Ghost", nil, function()
		Components.Toast("info", "Kulüp binası 13. adımda geliyor.")
	end)
	add("Sıralama", "Secondary", "Dünya sıralaması için önce bir maç oyna.")

	-- Görevler (sağ)
	local tasks, tc = Components.Panel({
		Name = "Tasks",
		Size = UDim2.fromOffset(300, 214),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 500),
		Title = "Günlük görevler",
	})
	tasks.Position = UDim2.new(1, -20, 1, -234)
	tasks.Parent = gui
	local th = Instance.new("Frame")
	th.BackgroundTransparency = 1
	th.Position = UDim2.fromOffset(0, 40)
	th.Size = UDim2.new(1, 0, 1, -40)
	th.Parent = tc
	list(th, 6)
	local bars = {}
	for i, t in ipairs({ { "2 gol at", 0.5, C.Yellow }, { "1 antrenman yap", 1, C.Good }, { "Kafayla gol at", 0, C.Yellow } }) do
		local l = Components.Label({ Text = t[1], Size = 14, Order = i * 2 - 1 })
		l.Parent = th
		local b = Components.Bar({ Color = t[3], Order = i * 2, Value = 0 })
		b.Frame.Parent = th
		bars[i] = { b, t[2] }
	end

	-- Sahneye giriş: paneller farklı yönlerden, butonlar sırayla
	UIMotion.In(card, Vector2.new(-40, 0), 0.05)
	UIMotion.In(coin, Vector2.new(40, 0), 0.1)
	UIMotion.In(menu, Vector2.new(-40, 0), 0.15)
	UIMotion.In(tasks, Vector2.new(40, 0), 0.2)
	UIMotion.Stagger(buttons, Vector2.new(-24, 0), 0.3)
	task.delay(0.6, function()
		for _, b in ipairs(bars) do
			b[1].Set(b[2])
		end
	end)
end

local function render(data)
	local first = state.data == nil or not state.rendered
	state.data = data
	if not refs.name then
		return
	end
	state.rendered = true
	if data.created then
		refs.name.Text = Theme.Upper(data.name)
		refs.sub.Text = Config.PositionNames[data.position] .. " · " .. data.number .. " · " .. data.club.name
	else
		refs.name.Text = "YENİ FUTBOLCU"
		refs.sub.Text = "Kariyer henüz oluşturulmadı"
	end
	refs.level.Text = "SEVİYE " .. data.level
	refs.xp.Set(data.xp / Config.XpForLevel(data.level), first)
	if data.coins ~= state.coinsShown then
		UIMotion.CountUp(refs.coins, state.coinsShown, data.coins)
		state.coinsShown = data.coins
	end
end

Remotes.Get("DataChanged").OnClientEvent:Connect(render)
Remotes.Get("Notify").OnClientEvent:Connect(function(kind, text)
	Components.Toast(kind, text)
end)

local Creator = require(script.Parent.Screens.Creator)

-- Ekran ölçeği: 1600x900 tasarım ölçüsüne göre küçük ekranlarda arayüz orantılı küçülür
local uiScale = Instance.new("UIScale")
uiScale.Parent = gui
local function fit()
	local v = workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.clamp(math.min(v.X / 1600, v.Y / 900), 0.45, 1.25)
end
fit()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

showLoading(function()
	local data = Remotes.Get("GetData"):InvokeServer()
	if not data then
		Components.Toast("error", "Veri alınamadı. Oyundan çıkıp tekrar gir.")
		return
	end
	if data.created then
		buildLobby()
		render(data)
	else
		Creator.Open(gui, function()
			buildLobby()
			if state.data then
				local d = state.data
				state.data = nil
				render(d)
			end
			Components.Toast("success", "Kariyerin başladı. Mahalle sahasında görüşürüz.")
		end)
	end
end)

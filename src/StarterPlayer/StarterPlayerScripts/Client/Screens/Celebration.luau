--[[
	Celebration
	Kariyerin büyük anları için tam ekran kutlama:
	  Celebration.Promotion(gui, tierId, onClose)  lig atlama: yeni lig, yeni stat, kapasite
	  Celebration.Offer(gui, data, onAccept, onLater)  Fenerbahçe transfer teklifi
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Components = require(ReplicatedStorage.UI.Components)
local Icons = require(ReplicatedStorage.UI.Icons)
local Theme = require(ReplicatedStorage.UI.Theme)
local UIMotion = require(ReplicatedStorage.UI.UIMotion)

local Celebration = {}

local C = Theme.Color

-- Ortak arka plan: koyu lacivert + dönen sarı ışınlar + konfeti şeritleri
local function backdrop(gui: ScreenGui, name: string): Frame
	local root = Instance.new("Frame")
	root.Name = name
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(5, 9, 32)
	root.BackgroundTransparency = 0.04
	root.BorderSizePixel = 0
	root.ZIndex = 180
	root.ClipsDescendants = true
	root.Parent = gui
	local rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.42)
	rays.Size = UDim2.fromOffset(1800, 1800)
	rays.BackgroundTransparency = 1
	rays.Parent = root
	for i = 0, 11 do
		local r = Instance.new("Frame")
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Position = UDim2.fromScale(0.5, 0.5)
		r.Size = UDim2.fromOffset(110, 1800)
		r.Rotation = i * 15
		r.BackgroundColor3 = if i % 2 == 0 then C.Yellow else C.Blue
		r.BackgroundTransparency = if i % 2 == 0 then 0.9 else 0.8
		r.BorderSizePixel = 0
		r.Parent = rays
	end
	TweenService:Create(rays, TweenInfo.new(30, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 }):Play()
	-- konfeti
	math.randomseed(7)
	for i = 1, 40 do
		local c = Instance.new("Frame")
		c.Name = "Confetti"
		c.Size = UDim2.fromOffset(8 + (i % 3) * 3, 14)
		c.Position = UDim2.new(math.random(), 0, math.random() * 0.9, 0)
		c.Rotation = math.random(0, 180)
		c.BackgroundColor3 = if i % 3 == 0 then C.White elseif i % 3 == 1 then C.Yellow else C.Blue
		c.BorderSizePixel = 0
		c.Parent = root
		local fall = TweenService:Create(
			c,
			TweenInfo.new(3 + (i % 5) * 0.6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
			{ Position = UDim2.new(c.Position.X.Scale, 0, 1.1, 0), Rotation = c.Rotation + 360 }
		)
		fall:Play()
	end
	return root
end

local function big(parent: Instance, text: string, size: number, color: Color3, y: number, height: number)
	local holder, label = Components.Label3D({
		Text = text,
		Size = size,
		Color = color,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.new(1, 0, 0, height),
	})
	holder.Position = UDim2.new(0, 0, 0, y)
	holder.Parent = parent
	return holder, label
end

function Celebration.Promotion(gui: ScreenGui, tierId: number, onClose: (() -> ())?)
	local tier = Config.Tiers[math.clamp(tierId, 1, #Config.Tiers)]
	local prev = Config.Tiers[math.max(1, tierId - 1)]
	local root = backdrop(gui, "Promotion")
	local stage = Instance.new("Frame")
	stage.BackgroundTransparency = 1
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromOffset(1100, 760)
	stage.Parent = root
	local trophy = Icons.Build("Trophy", 120, C.Gold)
	trophy.AnchorPoint = Vector2.new(0.5, 0)
	trophy.Position = UDim2.new(0.5, 0, 0, 20)
	trophy.Parent = stage
	big(stage, "LİG ATLADIN!", 86, C.Yellow, 150, 100)
	big(stage, Theme.Upper(prev.League) .. "  ›  " .. Theme.Upper(tier.League), 30, C.White, 262, 44)
	-- yeni stat kartı
	local card = Instance.new("Frame")
	card.Name = "Stadium"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 340)
	card.Size = UDim2.fromOffset(640, 190)
	card.BackgroundColor3 = C.Navy
	card.BorderSizePixel = 0
	local cu = Instance.new("UICorner")
	cu.CornerRadius = UDim.new(0, 14)
	cu.Parent = card
	local cs = Instance.new("UIStroke")
	cs.Color = C.Yellow
	cs.Thickness = 2
	cs.Parent = card
	card.Parent = stage
	local icon = Icons.Build("Building", 64, C.Yellow)
	icon.Position = UDim2.fromOffset(32, 30)
	icon.Parent = card
	local function line(text: string, size: number, color: Color3, y: number, font: Font)
		local l = Components.Label({ Text = text, Size = size, Color = color, Font = font, Frame = UDim2.new(1, -140, 0, size + 8) })
		l.Position = UDim2.fromOffset(120, y)
		l.Parent = card
	end
	line("YENİ STADIN", 13, C.Muted, 26, Theme.Font.Title)
	line(Theme.Upper(tier.Stadium), 32, C.White, 46, Theme.Font.Display)
	line(
		Theme.FormatNumber(tier.Capacity) .. " seyirci  ·  maç başına kasa " .. Theme.FormatNumber(tier.MatchIncome),
		16,
		C.Yellow,
		96,
		Theme.Font.Title
	)
	line("Rakipler artık daha güçlü: takım gücü " .. tier.BotPower[1] .. "-" .. tier.BotPower[2], 14, C.Text, 130, Theme.Font.Body)
	local go = Components.Button({
		Text = "Yeni sezona başla",
		Style = "Primary",
		Sub = "Stat, ışık ve rakipler değişti",
		Size = UDim2.fromOffset(380, 66),
		OnClick = function()
			UIMotion.Wipe(function()
				root:Destroy()
				if onClose then
					onClose()
				end
			end)
		end,
	})
	go.AnchorPoint = Vector2.new(0.5, 0)
	go.Position = UDim2.new(0.5, 0, 0, 580)
	go.Parent = stage
	UIMotion.Pop(trophy, 0.3)
	UIMotion.In(card, Vector2.new(0, 40), 0.3)
	UIMotion.In(go, Vector2.new(0, 40), 0.5)
	UIMotion.Sound("RewardSound")
	return root
end

function Celebration.Offer(gui: ScreenGui, data, onAccept: () -> (), onLater: (() -> ())?)
	local root = backdrop(gui, "Offer")
	local stage = Instance.new("Frame")
	stage.BackgroundTransparency = 1
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromOffset(1100, 760)
	stage.Parent = root
	-- sarı-lacivert çubuklu büyük kalkan
	local shield = Instance.new("CanvasGroup")
	shield.AnchorPoint = Vector2.new(0.5, 0)
	shield.Position = UDim2.new(0.5, 0, 0, 10)
	shield.Size = UDim2.fromOffset(150, 176)
	shield.BackgroundColor3 = C.Navy
	shield.BorderSizePixel = 0
	local su = Instance.new("UICorner")
	su.CornerRadius = UDim.new(0.3, 0)
	su.Parent = shield
	shield.Parent = stage
	for i = 0, 4 do
		if i % 2 == 1 then
			local st = Instance.new("Frame")
			st.Size = UDim2.fromScale(0.2, 1)
			st.Position = UDim2.fromScale(i * 0.2, 0)
			st.BackgroundColor3 = C.Yellow
			st.BorderSizePixel = 0
			st.Parent = shield
		end
	end
	local ss = Instance.new("UIStroke")
	ss.Color = C.Yellow
	ss.Thickness = 4
	ss.Parent = shield
	big(stage, "TRANSFER TEKLİFİ", 30, C.Muted, 200, 40)
	big(stage, "FENERBAHÇE SENİ İSTİYOR", 66, C.Yellow, 240, 84)
	local body = Components.Label({
		Text = string.format(
			"%s, sarı-lacivertli forma artık seni bekliyor. Seviye %d ve %d genel güçle kulübün dikkatini çektin. Kabul edersen Şükrü Saracoğlu'nda, gece maçlarında, en güçlü rakiplere karşı oynayacaksın.",
			data.name or "Kaptan",
			data.level or 1,
			data.power or 0
		),
		Size = 18,
		Color = C.Text,
		Wrap = true,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.new(0, 820, 0, 90),
	})
	body.AnchorPoint = Vector2.new(0.5, 0)
	body.Position = UDim2.new(0.5, 0, 0, 340)
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Parent = stage
	local accept = Components.Button({
		Text = "İmzala",
		Style = "Primary",
		Sub = "Fenerbahçe formasını giy",
		Size = UDim2.fromOffset(340, 70),
		OnClick = function()
			UIMotion.Sound("RewardSound")
			UIMotion.Wipe(function()
				root:Destroy()
				onAccept()
			end)
		end,
	})
	accept.AnchorPoint = Vector2.new(0, 0)
	accept.Position = UDim2.new(0.5, 10, 0, 470)
	accept.Parent = stage
	local later = Components.Button({
		Text = "Sonra düşüneyim",
		Style = "Ghost",
		Size = UDim2.fromOffset(300, 70),
		OnClick = function()
			root:Destroy()
			if onLater then
				onLater()
			end
		end,
	})
	later.AnchorPoint = Vector2.new(1, 0)
	later.Position = UDim2.new(0.5, -10, 0, 470)
	later.Parent = stage
	UIMotion.Pop(shield, 0.3)
	UIMotion.In(accept, Vector2.new(0, 40), 0.4)
	UIMotion.In(later, Vector2.new(0, 40), 0.45)
	UIMotion.Sound("RewardSound")
	return root
end

return Celebration

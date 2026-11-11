--[[
	SkillTree
	Yetenek ağacı sayfası. Solda zincirler (Şut, Çalım, Hava, Defans, kaleciyse Kaleci): her zincirde
	hareketler sırayla açılır ve aynı tuş, açılan en üst hareketi oynatır. Sağda özellikler
	(hız, top kontrolü, pas, şut, defans, fizik) bakiye ile yükseltilir.

	SkillTree.Open(gui, getData)   sayfayı açar
	SkillTree.Refresh()            veri değişince yeniden çizer (açıksa)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Components = require(ReplicatedStorage.UI.Components)
local Theme = require(ReplicatedStorage.UI.Theme)
local UIMotion = require(ReplicatedStorage.UI.UIMotion)

local SkillTree = {}

local C = Theme.Color
local open: { root: Frame, body: Frame, getData: () -> any, coins: TextLabel, level: TextLabel }? = nil

local function corner(o: Instance, r: number)
	local u = Instance.new("UICorner")
	u.CornerRadius = UDim.new(0, r)
	u.Parent = o
end

local function stroke(o: Instance, color: Color3, thickness: number, tr: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = tr or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = o
	return s
end

local function text(
	parent: Instance,
	str: string,
	size: number,
	color: Color3,
	pos: UDim2,
	frame: UDim2,
	font: Font?,
	align: Enum.TextXAlignment?
)
	local l = Components.Label({ Text = str, Size = size, Color = color, Font = font or Theme.Font.Body, Frame = frame, Align = align })
	l.Position = pos
	l.Parent = parent
	return l
end

local DARK = Color3.fromRGB(16, 24, 70)
local STAT_INFO = {
	Hiz = "Koşu ve sprint hızı",
	TopKontrolu = "Top sürme, ilk dokunuş",
	Pas = "Pas isabeti ve sertliği",
	Sut = "Şut isabeti",
	Defans = "Müdahale başarısı",
	Fizik = "Dayanıklılık, kafa gücü",
}

local function draw()
	if not open then
		return
	end
	local data = open.getData()
	if not data then
		return
	end
	local body = open.body
	for _, child in ipairs(body:GetChildren()) do
		child:Destroy()
	end
	open.coins.Text = Theme.FormatNumber(data.coins or 0)
	open.level.Text = "SEVİYE " .. tostring(data.level or 1)

	-- zincirler
	local chains = {}
	for _, id in ipairs(Config.SkillChainOrder) do
		local chain = Config.SkillChains[id]
		if chain and (not chain.OnlyPosition or chain.OnlyPosition == data.position) then
			table.insert(chains, id)
		end
	end
	local areaW = 900
	local colW = math.floor(areaW / #chains) - 12
	local nodeH, gap = 84, 12
	for ci, id in ipairs(chains) do
		local chain = Config.SkillChains[id]
		local level = Config.SkillLevel(data.skills, id)
		local x = (ci - 1) * (colW + 12)
		text(body, Theme.Upper(chain.Name), 20, C.Yellow, UDim2.fromOffset(x, 0), UDim2.fromOffset(colW, 26), Theme.Font.Display)
		text(body, chain.Hint or "", 11, C.Muted, UDim2.fromOffset(x, 26), UDim2.fromOffset(colW, 16))
		text(
			body,
			string.format("%d / %d", level, #chain.Skills),
			14,
			C.Text,
			UDim2.fromOffset(x, 0),
			UDim2.fromOffset(colW, 26),
			Theme.Font.Number,
			Enum.TextXAlignment.Right
		)
		-- bağlantı çizgisi
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = C.Blue
		line.Size = UDim2.fromOffset(4, (#chain.Skills - 1) * (nodeH + gap))
		line.Position = UDim2.fromOffset(x + 24, 52 + nodeH / 2)
		line.Parent = body
		local fill = Instance.new("Frame")
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = C.Yellow
		fill.Size = UDim2.fromOffset(4, math.max(0, level - 1) * (nodeH + gap))
		fill.Parent = line
		for i, sk in ipairs(chain.Skills) do
			local unlocked = i <= level
			local isNext = i == level + 1
			local node = Instance.new("TextButton")
			node.AutoButtonColor = false
			node.Text = ""
			node.Size = UDim2.fromOffset(colW, nodeH)
			node.Position = UDim2.fromOffset(x, 52 + (i - 1) * (nodeH + gap))
			node.BackgroundColor3 = if unlocked then C.Blue elseif isNext then DARK else C.Ground
			node.BackgroundTransparency = if unlocked or isNext then 0 else 0.35
			node.BorderSizePixel = 0
			corner(node, 10)
			local st = stroke(
				node,
				if unlocked then C.Yellow elseif isNext then C.Gold else C.Blue,
				if isNext then 2 else 1.5,
				if unlocked or isNext then 0 else 0.5
			)
			node.Parent = body
			-- sıra rozeti
			local badge = Instance.new("Frame")
			badge.Size = UDim2.fromOffset(34, 34)
			badge.Position = UDim2.fromOffset(8, 8)
			badge.BackgroundColor3 = if unlocked then C.Yellow else DARK
			badge.BorderSizePixel = 0
			corner(badge, 17)
			stroke(badge, if unlocked then C.Navy else C.Blue, 1.5)
			badge.Parent = node
			text(
				badge,
				tostring(i),
				16,
				if unlocked then C.Navy else C.Muted,
				UDim2.new(),
				UDim2.fromScale(1, 1),
				Theme.Font.Number,
				Enum.TextXAlignment.Center
			)
			local ink = if unlocked then C.White elseif isNext then C.Text else C.Muted
			text(node, Theme.Upper(sk.Name), 15, ink, UDim2.fromOffset(50, 8), UDim2.fromOffset(colW - 58, 20), Theme.Font.Title)
			local info = text(
				node,
				sk.Info or "",
				11,
				if unlocked then C.Text else C.Muted,
				UDim2.fromOffset(50, 28),
				UDim2.fromOffset(colW - 58, 28)
			)
			info.TextWrapped = true
			info.TextYAlignment = Enum.TextYAlignment.Top
			local state = if unlocked
				then "AÇIK"
				elseif sk.Level > (data.level or 1) then "SEVİYE " .. sk.Level .. " GEREKLİ"
				else "AÇ  ·  " .. Theme.FormatNumber(sk.Cost)
			local canBuy = isNext and (data.level or 1) >= sk.Level and (data.coins or 0) >= sk.Cost
			local tag = text(
				node,
				state,
				12,
				if unlocked then C.Good elseif canBuy then C.Yellow elseif isNext then C.Gold else C.Muted,
				UDim2.fromOffset(50, nodeH - 24),
				UDim2.fromOffset(colW - 58, 18),
				Theme.Font.Title
			)
			if isNext then
				if canBuy then
					UIMotion.Glow(st, 0, 0.6, 0.9)
				end
				node.Activated:Connect(function()
					if (data.level or 1) < sk.Level then
						Components.Toast("error", sk.Name .. " için seviye " .. sk.Level .. " gerekli.")
						UIMotion.Shake(node)
					elseif (data.coins or 0) < sk.Cost then
						Components.Toast("error", "Bakiye yetersiz. Gereken: " .. Theme.FormatNumber(sk.Cost))
						UIMotion.Shake(node)
					else
						UIMotion.Flash(node)
						UIMotion.Sound("ConfirmSound")
						Remotes.Get("UnlockSkill"):FireServer(id)
					end
				end)
			elseif not unlocked then
				tag.Text = "KİLİTLİ  ·  SV " .. sk.Level
				node.Activated:Connect(function()
					Components.Toast("info", "Önce bir önceki hareketi aç.")
				end)
			end
		end
	end

	-- özellikler
	local sx = areaW + 24
	local sw = 1216 - sx
	text(body, "ÖZELLİKLER", 20, C.Yellow, UDim2.fromOffset(sx, 0), UDim2.fromOffset(sw, 26), Theme.Font.Display)
	text(body, "Bakiye ile yükselt (en çok " .. Config.StatMax .. ")", 11, C.Muted, UDim2.fromOffset(sx, 26), UDim2.fromOffset(sw, 16))
	for i, key in ipairs(Config.Stats) do
		local v = (data.stats and data.stats[key]) or 1
		local y = 52 + (i - 1) * 92
		local card = Instance.new("Frame")
		card.Size = UDim2.fromOffset(sw, 80)
		card.Position = UDim2.fromOffset(sx, y)
		card.BackgroundColor3 = DARK
		card.BorderSizePixel = 0
		corner(card, 10)
		stroke(card, C.Blue, 1.5)
		card.Parent = body
		text(
			card,
			Theme.Upper(Config.StatNames[key]),
			15,
			C.White,
			UDim2.fromOffset(12, 8),
			UDim2.fromOffset(sw - 120, 20),
			Theme.Font.Title
		)
		text(card, STAT_INFO[key] or "", 11, C.Muted, UDim2.fromOffset(12, 28), UDim2.fromOffset(sw - 120, 16))
		text(
			card,
			tostring(v),
			26,
			C.Yellow,
			UDim2.fromOffset(sw - 196, 6),
			UDim2.fromOffset(80, 30),
			Theme.Font.Number,
			Enum.TextXAlignment.Right
		)
		-- 10 bölmeli çubuk
		for k = 1, Config.StatMax do
			local seg = Instance.new("Frame")
			seg.Size = UDim2.fromOffset((sw - 124 - (Config.StatMax - 1) * 3) / Config.StatMax, 10)
			seg.Position = UDim2.fromOffset(12 + (k - 1) * ((sw - 124) / Config.StatMax), 56)
			seg.BackgroundColor3 = if k <= v then C.Yellow else C.Ground
			seg.BorderSizePixel = 0
			corner(seg, 3)
			seg.Parent = card
		end
		local maxed = v >= Config.StatMax
		local cost = if maxed then 0 else Config.StatCost(v)
		local b = Components.Button({
			Text = if maxed then "TAM" else "+ " .. Theme.FormatNumber(cost),
			Style = if maxed then "Ghost" elseif (data.coins or 0) >= cost then "Primary" else "Secondary",
			TextSize = 15,
			Size = UDim2.fromOffset(96, 44),
			OnClick = function()
				if maxed then
					return
				end
				if (data.coins or 0) < cost then
					Components.Toast("error", "Bakiye yetersiz. Gereken: " .. Theme.FormatNumber(cost))
					return
				end
				Remotes.Get("UpgradeStat"):FireServer(key)
			end,
		})
		b.Position = UDim2.fromOffset(sw - 106, 18)
		b.Parent = card
	end
end

function SkillTree.Refresh()
	if open then
		draw()
	end
end

function SkillTree.Close()
	if not open then
		return
	end
	local root = open.root
	open = nil
	UIMotion.Out(root, Vector2.new(0, 20), true)
end

function SkillTree.Open(gui: ScreenGui, getData: () -> any)
	if open then
		return
	end
	local dim = Instance.new("TextButton")
	dim.Name = "SkillTree"
	dim.AutoButtonColor = false
	dim.Text = ""
	dim.BackgroundColor3 = C.Ground
	dim.BackgroundTransparency = 0.25
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 120
	dim.Parent = gui
	local panel, content = Components.Panel({
		Name = "SkillPanel",
		Size = UDim2.fromOffset(1280, 760),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Title = "Yetenek Ağacı",
	})
	panel.ZIndex = 121
	panel.Parent = dim
	local coinsCap = text(
		content,
		"BAKİYE",
		11,
		C.Muted,
		UDim2.new(1, -520, 0, 0),
		UDim2.fromOffset(120, 14),
		Theme.Font.Title,
		Enum.TextXAlignment.Right
	)
	coinsCap.Name = "CoinsCap"
	local coins =
		text(content, "0", 22, C.Yellow, UDim2.new(1, -520, 0, 12), UDim2.fromOffset(120, 24), Theme.Font.Number, Enum.TextXAlignment.Right)
	local level = text(
		content,
		"SEVİYE 1",
		16,
		C.Text,
		UDim2.new(1, -380, 0, 8),
		UDim2.fromOffset(140, 24),
		Theme.Font.Title,
		Enum.TextXAlignment.Right
	)
	local closeB =
		Components.Button({ Text = "Kapat", Style = "Ghost", TextSize = 15, Size = UDim2.fromOffset(120, 38), OnClick = SkillTree.Close })
	closeB.AnchorPoint = Vector2.new(1, 0)
	closeB.Position = UDim2.new(1, -80, 0, -2)
	closeB.Parent = content
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, 50)
	body.Size = UDim2.new(1, 0, 1, -50)
	body.Parent = content
	open = { root = dim, body = body, getData = getData, coins = coins, level = level }
	draw()
	UIMotion.In(panel, Vector2.new(0, 30))
end

return SkillTree

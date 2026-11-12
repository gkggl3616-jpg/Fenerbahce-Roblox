--[[
	Lineup
	Maç öncesi tanıtım: iki kulüp, armalar, teknik direktörler, diziliş ve 11'ler.
	Her futbolcunun genel gücü ve altı özelliği görünür. "Maça çık" ile santraya geçilir.

	Lineup.Show(gui, fixture, onStart, onCancel)   fixture: Squads.Fixture(data)
	Lineup.Crest(club, size) -> Frame               kulüp arması (başka ekranlar da kullanır)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crest = require(ReplicatedStorage.Shared.Crest)
local Squads = require(ReplicatedStorage.Shared.Squads)
local Components = require(ReplicatedStorage.UI.Components)
local Theme = require(ReplicatedStorage.UI.Theme)
local UIMotion = require(ReplicatedStorage.UI.UIMotion)

local Lineup = {}

local C = Theme.Color

local function corner(o: Instance, r: number)
	local u = Instance.new("UICorner")
	u.CornerRadius = UDim.new(r, 0)
	u.Parent = o
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

-- Arma: kulübün tasarımı (oyuncununki) ya da hazır arması (rakipler)
function Lineup.Crest(club, size: number): Frame
	local spec, abbr = Crest.FromClub(club)
	return Crest.Build(spec, abbr, size)
end

local function average(players): number
	local sum = 0
	for _, p in ipairs(players) do
		sum += p.rating
	end
	return math.floor(sum / #players + 0.5)
end

local function ratingColor(v: number): Color3
	return if v >= 80 then C.Gold elseif v >= 65 then C.Good elseif v >= 45 then C.Yellow else C.Muted
end

local function side(parent: Instance, team, x: number, home: boolean)
	local W = 700
	local col = Instance.new("Frame")
	col.BackgroundTransparency = 1
	col.Size = UDim2.fromOffset(W, 720)
	col.Position = UDim2.fromOffset(x, 96)
	col.Parent = parent

	-- başlık: arma, kulüp, teknik direktör, takım gücü
	local crest = Lineup.Crest(team.club, 104)
	crest.Position = UDim2.fromOffset(0, 0)
	crest.Parent = col
	text(col, Theme.Upper(team.club.Name), 30, C.White, UDim2.fromOffset(120, 6), UDim2.fromOffset(W - 240, 36), Theme.Font.Display)
	text(col, "TEKNİK DİREKTÖR", 12, C.Muted, UDim2.fromOffset(120, 48), UDim2.fromOffset(300, 16), Theme.Font.Title)
	text(col, team.club.Coach, 18, C.Text, UDim2.fromOffset(120, 64), UDim2.fromOffset(300, 24), Theme.Font.Title)
	text(col, "DİZİLİŞ 4-4-2", 12, C.Muted, UDim2.fromOffset(120, 90), UDim2.fromOffset(300, 16), Theme.Font.Title)
	local avg = average(team.players)
	local badge = Instance.new("Frame")
	badge.Size = UDim2.fromOffset(96, 96)
	badge.Position = UDim2.fromOffset(W - 100, 4)
	badge.BackgroundColor3 = C.Navy
	badge.BorderSizePixel = 0
	corner(badge, 0.16)
	local bs = Instance.new("UIStroke")
	bs.Color = ratingColor(avg)
	bs.Thickness = 2
	bs.Parent = badge
	badge.Parent = col
	text(
		badge,
		tostring(avg),
		44,
		ratingColor(avg),
		UDim2.fromOffset(0, 10),
		UDim2.new(1, 0, 0, 50),
		Theme.Font.Number,
		Enum.TextXAlignment.Center
	)
	text(badge, "TAKIM GÜCÜ", 10, C.Muted, UDim2.fromOffset(0, 66), UDim2.new(1, 0, 0, 16), Theme.Font.Title, Enum.TextXAlignment.Center)

	-- sütun başlıkları
	local head = Instance.new("Frame")
	head.BackgroundTransparency = 1
	head.Size = UDim2.fromOffset(W, 22)
	head.Position = UDim2.fromOffset(0, 124)
	head.Parent = col
	text(head, "#", 11, C.Muted, UDim2.fromOffset(10, 0), UDim2.fromOffset(30, 22), Theme.Font.Title)
	text(head, "OYUNCU", 11, C.Muted, UDim2.fromOffset(50, 0), UDim2.fromOffset(200, 22), Theme.Font.Title)
	text(head, "MEVKİ", 11, C.Muted, UDim2.fromOffset(262, 0), UDim2.fromOffset(60, 22), Theme.Font.Title)
	text(head, "GEN", 11, C.Muted, UDim2.fromOffset(326, 0), UDim2.fromOffset(44, 22), Theme.Font.Title, Enum.TextXAlignment.Center)
	for i, name in ipairs(Squads.StatOrder) do
		text(
			head,
			Theme.Upper(name),
			11,
			C.Muted,
			UDim2.fromOffset(384 + (i - 1) * 52, 0),
			UDim2.fromOffset(48, 22),
			Theme.Font.Title,
			Enum.TextXAlignment.Center
		)
	end

	local rows = {}
	for i, p in ipairs(team.players) do
		local row = Instance.new("Frame")
		row.Size = UDim2.fromOffset(W, 40)
		row.Position = UDim2.fromOffset(0, 148 + (i - 1) * 44)
		row.BackgroundColor3 = if p.human then C.Yellow else (if i % 2 == 0 then C.Blue else C.Navy)
		row.BackgroundTransparency = if p.human then 0 else 0.35
		row.BorderSizePixel = 0
		corner(row, 0.18)
		row.Parent = col
		local ink = if p.human then C.Navy else C.Text
		-- forma numarası rozeti (kulüp renginde)
		local num = Instance.new("Frame")
		num.Size = UDim2.fromOffset(32, 28)
		num.Position = UDim2.fromOffset(6, 6)
		num.BackgroundColor3 = team.club.A
		num.BorderSizePixel = 0
		corner(num, 0.25)
		local ns = Instance.new("UIStroke")
		ns.Color = team.club.B
		ns.Thickness = 1.5
		ns.Parent = num
		num.Parent = row
		local nl = text(
			num,
			tostring(p.number),
			15,
			Color3.new(1, 1, 1),
			UDim2.new(),
			UDim2.fromScale(1, 1),
			Theme.Font.Number,
			Enum.TextXAlignment.Center
		)
		local nst = Instance.new("UIStroke")
		nst.Color = Color3.fromRGB(10, 12, 30)
		nst.Thickness = 1.5
		nst.Parent = nl
		text(
			row,
			if p.human then Theme.Upper(p.name) .. "  (SEN)" else p.name,
			16,
			ink,
			UDim2.fromOffset(50, 0),
			UDim2.fromOffset(208, 40),
			Theme.Font.Title
		)
		text(row, p.role, 13, if p.human then C.Navy else C.Muted, UDim2.fromOffset(262, 0), UDim2.fromOffset(60, 40), Theme.Font.Title)
		text(
			row,
			tostring(p.rating),
			20,
			if p.human then C.Navy else ratingColor(p.rating),
			UDim2.fromOffset(326, 0),
			UDim2.fromOffset(44, 40),
			Theme.Font.Number,
			Enum.TextXAlignment.Center
		)
		for k = 1, 6 do
			text(
				row,
				tostring(p.stats[k]),
				14,
				if p.human then C.Navy else C.Text,
				UDim2.fromOffset(384 + (k - 1) * 52, 0),
				UDim2.fromOffset(48, 40),
				Theme.Font.Number,
				Enum.TextXAlignment.Center
			)
		end
		table.insert(rows, row)
	end
	UIMotion.In(crest, Vector2.new(if home then -60 else 60, 0), 0.1)
	UIMotion.Stagger(rows, Vector2.new(if home then -30 else 30, 0), 0.35)
end

function Lineup.Show(gui: ScreenGui, fixture, onStart: () -> (), onCancel: (() -> ())?)
	local root = Instance.new("Frame")
	root.Name = "Lineup"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(6, 11, 36)
	root.BorderSizePixel = 0
	root.ZIndex = 150
	root.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(34, 52, 150), Color3.fromRGB(8, 12, 40))
	grad.Parent = root
	-- tasarım 1600x900; ortalanır
	local stage = Instance.new("Frame")
	stage.BackgroundTransparency = 1
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromOffset(1560, 860)
	stage.Parent = root

	local top = text(
		stage,
		Theme.Upper(string.format("%s  ·  %d. MAÇ  ·  %s", fixture.league, fixture.matchNo, fixture.stadium)),
		16,
		C.Yellow,
		UDim2.fromOffset(0, 8),
		UDim2.new(1, 0, 0, 24),
		Theme.Font.Title,
		Enum.TextXAlignment.Center
	)
	local title = text(
		stage,
		"MAÇ ÖNCESİ",
		34,
		C.White,
		UDim2.fromOffset(0, 34),
		UDim2.new(1, 0, 0, 44),
		Theme.Font.Display,
		Enum.TextXAlignment.Center
	)
	UIMotion.In(top, Vector2.new(0, -20))
	UIMotion.In(title, Vector2.new(0, -20), 0.05)

	side(stage, fixture.home, 20, true)
	side(stage, fixture.away, 840, false)

	local vs = text(
		stage,
		"VS",
		54,
		C.Yellow,
		UDim2.new(0.5, -60, 0, 116),
		UDim2.fromOffset(120, 70),
		Theme.Font.Display,
		Enum.TextXAlignment.Center
	)
	UIMotion.Pop(vs, 1.8)

	local function close(fn: (() -> ())?)
		UIMotion.Wipe(function()
			root:Destroy()
			if fn then
				fn()
			end
		end)
	end
	local go = Components.Button({
		Text = "Maça çık",
		Style = "Primary",
		Sub = "Santra ile başlar",
		Size = UDim2.fromOffset(320, 64),
		OnClick = function()
			close(onStart)
		end,
	})
	go.AnchorPoint = Vector2.new(0.5, 1)
	go.Position = UDim2.new(0.5, 90, 1, -6)
	go.Parent = stage
	local back = Components.Button({
		Text = "Geri",
		Style = "Ghost",
		Size = UDim2.fromOffset(160, 64),
		OnClick = function()
			close(onCancel)
		end,
	})
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.new(0.5, -164, 1, -6)
	back.Parent = stage
	UIMotion.In(go, Vector2.new(0, 30), 0.9)
	UIMotion.In(back, Vector2.new(0, 30), 0.95)
	return root
end

return Lineup

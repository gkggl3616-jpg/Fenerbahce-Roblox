--[[
	League
	Puan durumu ekranı: ligdeki altı kulüp, oynanan maç, galibiyet/beraberlik/mağlubiyet ve puan.
	Oyuncunun kulübü sarı satırdadır. Lig atlama çizgisi tabloda gösterilir.

	League.Open(gui, getData)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Crest = require(ReplicatedStorage.Shared.Crest)
local Squads = require(ReplicatedStorage.Shared.Squads)
local Components = require(ReplicatedStorage.UI.Components)
local Theme = require(ReplicatedStorage.UI.Theme)
local UIMotion = require(ReplicatedStorage.UI.UIMotion)

local League = {}

local C = Theme.Color
local open: Instance? = nil

local function text(
	parent: Instance,
	str: string,
	size: number,
	color: Color3,
	x: number,
	w: number,
	font: Font?,
	align: Enum.TextXAlignment?
)
	local l = Components.Label({
		Text = str,
		Size = size,
		Color = color,
		Font = font or Theme.Font.Title,
		Frame = UDim2.new(0, w, 1, 0),
		Align = align,
	})
	l.Position = UDim2.fromOffset(x, 0)
	l.Parent = parent
	return l
end

function League.Close()
	if open then
		local root = open
		open = nil
		UIMotion.Out(root :: any, Vector2.new(0, 20), true)
	end
end

function League.Open(gui: ScreenGui, getData: () -> any)
	if open then
		return
	end
	local data = getData()
	if not data then
		return
	end
	local rows, league, seasonNo = Squads.Table(data)
	local dim = Instance.new("TextButton")
	dim.Name = "League"
	dim.AutoButtonColor = false
	dim.Text = ""
	dim.BackgroundColor3 = C.Ground
	dim.BackgroundTransparency = 0.25
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 120
	dim.Parent = gui
	open = dim
	local panel, content = Components.Panel({
		Name = "LeaguePanel",
		Size = UDim2.fromOffset(820, 600),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Title = "Puan Durumu",
	})
	panel.ZIndex = 121
	panel.Parent = dim
	local sub = Components.Label({
		Text = string.format("%s  ·  %d. sezon  ·  %d / %d maç", league, seasonNo, rows[1].played, Config.Season.Matches),
		Upper = true,
		Size = 13,
		Color = C.Muted,
		Font = Theme.Font.Title,
		Frame = UDim2.new(1, -160, 0, 18),
	})
	sub.Position = UDim2.fromOffset(0, 34)
	sub.Parent = content

	local COL = { rank = 8, crest = 50, name = 96, o = 440, g = 500, b = 556, m = 612, p = 680 }
	local head = Instance.new("Frame")
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 22)
	head.Position = UDim2.fromOffset(0, 66)
	head.Parent = content
	text(head, "#", 11, C.Muted, COL.rank, 30)
	text(head, "KULÜP", 11, C.Muted, COL.name, 300)
	for key, label in pairs({ o = "O", g = "G", b = "B", m = "M", p = "PUAN" }) do
		text(head, label, 11, C.Muted, COL[key], if key == "p" then 80 else 50, nil, Enum.TextXAlignment.Center)
	end

	local list = {}
	for i, row in ipairs(rows) do
		local f = Instance.new("Frame")
		f.Name = if row.mine then "Mine" else "Row"
		f.Size = UDim2.new(1, 0, 0, 54)
		f.Position = UDim2.fromOffset(0, 92 + (i - 1) * 60)
		f.BackgroundColor3 = if row.mine then C.Yellow else (if i % 2 == 0 then C.Blue else C.Navy)
		f.BackgroundTransparency = if row.mine then 0 else 0.35
		f.BorderSizePixel = 0
		local u = Instance.new("UICorner")
		u.CornerRadius = UDim.new(0, 8)
		u.Parent = f
		f.Parent = content
		local ink = if row.mine then C.Navy else C.Text
		text(f, tostring(i), 20, if row.mine then C.Navy elseif i == 1 then C.Gold else C.Muted, COL.rank, 30, Theme.Font.Number)
		local spec, abbr = Crest.FromClub(row.club)
		local crest = Crest.Build(spec, abbr, 42)
		crest.Position = UDim2.fromOffset(COL.crest - 6, 6)
		crest.Parent = f
		text(f, if row.mine then Theme.Upper(row.club.Name) else row.club.Name, 17, ink, COL.name, 330)
		text(f, tostring(row.played), 16, ink, COL.o, 50, Theme.Font.Number, Enum.TextXAlignment.Center)
		-- oyuncunun kulübü için galibiyet dökümü tutulmuyor; yalnızca puanı gerçektir
		text(f, if row.won then tostring(row.won) else "–", 16, ink, COL.g, 50, Theme.Font.Number, Enum.TextXAlignment.Center)
		text(f, if row.drawn then tostring(row.drawn) else "–", 16, ink, COL.b, 50, Theme.Font.Number, Enum.TextXAlignment.Center)
		text(f, if row.lost then tostring(row.lost) else "–", 16, ink, COL.m, 50, Theme.Font.Number, Enum.TextXAlignment.Center)
		text(f, tostring(row.points), 24, if row.mine then C.Navy else C.Yellow, COL.p, 80, Theme.Font.Number, Enum.TextXAlignment.Center)
		table.insert(list, f)
	end

	local need = Config.Match.PromotePoints
	local mine = 0
	for _, row in ipairs(rows) do
		if row.mine then
			mine = row.points
		end
	end
	local note = Components.Label({
		Text = if mine >= need
			then "Lig atlama puanına ulaştın. Sezon bitince üst lige çıkarsın."
			else string.format("Lig atlamak için sezon sonunda en az %d puan gerekir. Kalan: %d puan.", need, need - mine),
		Size = 14,
		Color = if mine >= need then C.Good else C.Text,
		Frame = UDim2.new(1, -170, 0, 40),
		Wrap = true,
	})
	note.AnchorPoint = Vector2.new(0, 1)
	note.Position = UDim2.fromScale(0, 1)
	note.Parent = content
	local close = Components.Button({ Text = "Kapat", Style = "Ghost", Size = UDim2.fromOffset(150, 52), OnClick = League.Close })
	close.AnchorPoint = Vector2.new(1, 1)
	close.Position = UDim2.fromScale(1, 1)
	close.Parent = content
	UIMotion.In(panel, Vector2.new(0, 30))
	UIMotion.Stagger(list, Vector2.new(-24, 0), 0.15)
end

return League

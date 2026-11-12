--[[
	CrestDesigner
	Kulüp arması tasarım ekranı: biçim, desen, simge ve iki renk seçilir; sonuç anında önizlenir.
	Kaydedilen arma forma göğsünde, maç öncesi kadro ekranında ve takım arkadaşlarının formasında görünür.

	CrestDesigner.Open(gui, getData)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crest = require(ReplicatedStorage.Shared.Crest)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Components = require(ReplicatedStorage.UI.Components)
local Forms = require(ReplicatedStorage.UI.Forms)
local Theme = require(ReplicatedStorage.UI.Theme)
local UIMotion = require(ReplicatedStorage.UI.UIMotion)

local CrestDesigner = {}

local C = Theme.Color
local open: Instance? = nil

local function options(names: { string })
	local out = {}
	for i, n in ipairs(names) do
		out[i] = { Id = i, Text = n }
	end
	return out
end

function CrestDesigner.Close()
	if open then
		local root = open
		open = nil
		UIMotion.Out(root :: any, Vector2.new(0, 20), true)
	end
end

function CrestDesigner.Open(gui: ScreenGui, getData: () -> any)
	if open then
		return
	end
	local data = getData()
	if not data then
		return
	end
	local abbr = if data.club.abbr ~= "" then data.club.abbr else "FK"
	local saved = data.club.crest or Crest.Default()
	local spec = { shape = saved.shape, pattern = saved.pattern, a = saved.a, b = saved.b, symbol = saved.symbol }

	local dim = Instance.new("TextButton")
	dim.Name = "CrestDesigner"
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
		Name = "CrestPanel",
		Size = UDim2.fromOffset(1080, 660),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Title = "Kulüp Arması",
	})
	panel.ZIndex = 121
	panel.Parent = dim

	-- önizleme (sol)
	local left = Instance.new("Frame")
	left.BackgroundColor3 = C.Ground
	left.BackgroundTransparency = 0.3
	left.BorderSizePixel = 0
	left.Position = UDim2.fromOffset(0, 46)
	left.Size = UDim2.fromOffset(320, 500)
	local lc = Instance.new("UICorner")
	lc.CornerRadius = UDim.new(0, 10)
	lc.Parent = left
	left.Parent = content
	local name = Components.Label({
		Text = if data.club.name ~= "" then data.club.name else "Kulübüm",
		Upper = true,
		Size = 20,
		Font = Theme.Font.Display,
		Color = C.White,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.new(1, 0, 0, 28),
	})
	name.Position = UDim2.fromOffset(0, 300)
	name.Parent = left
	local note = Components.Label({
		Text = "Forma göğsünde, kadro ekranında ve takım arkadaşlarının formasında görünür.",
		Size = 12,
		Color = C.Muted,
		Wrap = true,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.new(1, -30, 0, 40),
	})
	note.Position = UDim2.fromOffset(15, 440)
	note.Parent = left
	local holders = {}
	for _, h in ipairs({ { 230, 45, 40 }, { 86, 70, 340 }, { 52, 190, 356 } }) do
		local f = Instance.new("Frame")
		f.Name = "Preview"
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromOffset(h[1], h[1])
		f.Position = UDim2.fromOffset(h[2], h[3])
		f.Parent = left
		table.insert(holders, f)
	end
	local function redraw()
		for i, f in ipairs(holders) do
			for _, child in ipairs(f:GetChildren()) do
				child:Destroy()
			end
			Crest.Fill(f, spec, abbr)
			if i == 1 then
				UIMotion.Pop(f, 0.94)
			end
		end
	end

	-- seçenekler (sağ)
	local right = Instance.new("Frame")
	right.BackgroundTransparency = 1
	right.Position = UDim2.fromOffset(344, 46)
	right.Size = UDim2.new(1, -344, 0, 500)
	right.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = right
	local controls = {}
	local function chips(caption: string, key: string, names: { string }, order: number)
		Forms.Caption(caption, order).Parent = right
		local api = Forms.Chips({
			Options = options(names),
			Value = spec[key],
			Order = order + 1,
			OnChange = function(v)
				spec[key] = v
				redraw()
			end,
		})
		api.Frame.Parent = right
		controls[key] = api
	end
	local function swatches(caption: string, key: string, order: number)
		Forms.Caption(caption, order).Parent = right
		local api = Forms.Swatches({
			Colors = Crest.Colors,
			Value = spec[key],
			Order = order + 1,
			OnChange = function(i)
				spec[key] = i
				redraw()
			end,
		})
		api.Frame.Parent = right
		controls[key] = api
	end
	chips("Biçim", "shape", Crest.Shapes, 1)
	chips("Desen", "pattern", Crest.Patterns, 3)
	chips("Simge", "symbol", Crest.Symbols, 5)
	swatches("Ana renk", "a", 7)
	swatches("İkinci renk (desen ve çerçeve)", "b", 9)

	-- düğmeler
	local save = Components.Button({
		Text = "Kaydet",
		Style = "Primary",
		Size = UDim2.fromOffset(240, 56),
		OnClick = function()
			if spec.a == spec.b then
				Components.Toast("error", "İki renk aynı olamaz; desen görünmez.")
				return
			end
			Remotes.Get("SetCrest"):FireServer(spec)
			UIMotion.Sound("ConfirmSound")
			CrestDesigner.Close()
		end,
	})
	save.AnchorPoint = Vector2.new(1, 1)
	save.Position = UDim2.fromScale(1, 1)
	save.Parent = content
	local random = Components.Button({
		Text = "Rastgele",
		Style = "Ghost",
		Size = UDim2.fromOffset(170, 56),
		OnClick = function()
			spec.shape = math.random(1, #Crest.Shapes)
			spec.pattern = math.random(1, #Crest.Patterns)
			spec.symbol = math.random(1, #Crest.Symbols)
			spec.a = math.random(1, #Crest.Colors)
			repeat
				spec.b = math.random(1, #Crest.Colors)
			until spec.b ~= spec.a
			redraw()
		end,
	})
	random.AnchorPoint = Vector2.new(1, 1)
	random.Position = UDim2.new(1, -252, 1, 0)
	random.Parent = content
	local close = Components.Button({ Text = "Vazgeç", Style = "Ghost", Size = UDim2.fromOffset(150, 56), OnClick = CrestDesigner.Close })
	close.AnchorPoint = Vector2.new(0, 1)
	close.Position = UDim2.fromScale(0, 1)
	close.Parent = content

	redraw()
	UIMotion.In(panel, Vector2.new(0, 30))
end

return CrestDesigner

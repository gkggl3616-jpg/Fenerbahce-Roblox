--[[
	Creator (karakter ve kulüp oluşturma ekranı)
	Solda sekmeli seçenek paneli, sağda stüdyo sahnesinde dönen gerçek karakter.
	Her seçim sunucuya önizleme isteği gönderir; sunucu doğrular ve karaktere uygular.
	İsim ve mevki onaydan sonra kalıcıdır.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.UI.Theme)
local UIMotion = require(ReplicatedStorage.UI.UIMotion)
local Components = require(ReplicatedStorage.UI.Components)
local Forms = require(ReplicatedStorage.UI.Forms)

local C = Theme.Color
local player = Players.LocalPlayer

local Creator = {}

local POSITION_INFO = {
	Kaleci = { "KL", "Kaleci", "Fizik ve defansla başlar. Özel zincir: plonjon, yumruk, bire bir." },
	Defans = { "DF", "Defans", "Defans ve fizikle başlar. Müdahale ve blokta güçlü." },
	OrtaSaha = { "OS", "Orta Saha", "Pas ve top kontrolüyle başlar. Oyunu yönetir." },
	Forvet = { "FV", "Forvet", "Hız ve şutla başlar. Gol yollarında etkili." },
}

local function hexToColor(list: { string }): { Color3 }
	local out = {}
	for i, h in ipairs(list) do
		out[i] = Color3.fromHex(h)
	end
	return out
end

function Creator.Open(gui: ScreenGui, onCreated: () -> ())
	local state = {
		name = "",
		number = 9,
		clubName = "",
		clubAbbr = "",
		position = "Forvet",
		kitPattern = "Cubuklu",
		crestShape = 1,
		appearance = {
			height = 180,
			build = "Atletik",
			skin = 2,
			face = 1,
			hairStyle = 2,
			hairColor = Config.HairColors[1],
			beard = 0,
			bootModel = 1,
			bootColor = Config.BootColors[1],
			accessories = {},
		},
	}
	local alive = true
	local conns = {}

	----------------------------------------------------------------------------
	-- Kamera: karakterin çevresinde döner, sürükleyerek çevrilir
	----------------------------------------------------------------------------
	local cam = Workspace.CurrentCamera
	local angle, targetAngle, dragging, lastX = 0.35, 0.35, false, 0
	local zoom = 0 -- 0 tam boy, 1 yüz
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 30
	RunService:BindToRenderStep("FK_CreatorCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		if not dragging then
			targetAngle += dt * 0.12
		end
		angle += (targetAngle - angle) * math.min(1, dt * 8)
		local focus = hrp.Position + Vector3.new(0, 0.2 + zoom * 1.9, 0)
		local dist = 13.5 - zoom * 8
		local pos = focus + Vector3.new(math.sin(angle) * dist, 0.6, math.cos(angle) * dist)
		-- karakter ekranın sağında dursun diye kamera sola kaydırılır
		cam.CFrame = CFrame.lookAt(pos, focus) * CFrame.new(-2.3 + zoom * 1.4, 0, 0)
	end)

	local dragArea = Instance.new("TextButton")
	dragArea.Name = "DragArea"
	dragArea.AutoButtonColor = false
	dragArea.Text = ""
	dragArea.BackgroundTransparency = 1
	dragArea.AnchorPoint = Vector2.new(1, 0)
	dragArea.Position = UDim2.fromScale(1, 0)
	dragArea.Size = UDim2.new(1, -620, 1, 0)
	dragArea.Parent = gui
	dragArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			lastX = input.Position.X
		end
	end)
	table.insert(
		conns,
		UserInputService.InputChanged:Connect(function(input)
			if
				dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
			then
				targetAngle -= (input.Position.X - lastX) * 0.01
				lastX = input.Position.X
			end
		end)
	)
	table.insert(
		conns,
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
	)

	----------------------------------------------------------------------------
	-- Önizleme isteği (sık değişikliklerde en sonuncusu gönderilir)
	----------------------------------------------------------------------------
	local pending = false
	local function preview()
		if pending then
			return
		end
		pending = true
		task.delay(0.25, function()
			pending = false
			if alive then
				Remotes.Get("PreviewAppearance"):FireServer({
					appearance = state.appearance,
					position = state.position,
					kitPattern = state.kitPattern,
					number = state.number,
					clubAbbr = state.clubAbbr,
				})
			end
		end)
	end

	----------------------------------------------------------------------------
	-- Sol panel
	----------------------------------------------------------------------------
	local panel, content = Components.Panel({ Name = "Creator", Size = UDim2.new(0, 580, 1, -40), Position = UDim2.fromOffset(20, 20) })
	panel.Parent = gui

	local header = Components.Label({
		Text = "Kariyerini oluştur",
		Size = 26,
		Font = Theme.Font.Display,
		Color = C.Yellow,
		Upper = true,
		Frame = UDim2.new(1, 0, 0, 30),
	})
	header.Parent = content

	local pages: { [string]: CanvasGroup } = {}
	local current = "Kimlik"
	local function page(id: string): CanvasGroup
		local p = Instance.new("CanvasGroup")
		p.Name = id
		p.BackgroundTransparency = 1
		p.Position = UDim2.fromOffset(0, 88)
		p.Size = UDim2.new(1, 0, 1, -164)
		p.Visible = id == current
		local l = Instance.new("UIListLayout")
		l.Padding = UDim.new(0, 8)
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Parent = p
		p.Parent = content
		pages[id] = p
		return p
	end

	local tabs = Forms.Tabs({
		Tabs = {
			{ Id = "Kimlik", Text = "Kimlik" },
			{ Id = "Yuz", Text = "Yüz" },
			{ Id = "Sac", Text = "Saç" },
			{ Id = "Vucut", Text = "Vücut" },
			{ Id = "Forma", Text = "Forma" },
			{ Id = "Aksesuar", Text = "Aksesuar" },
		},
		Value = current,
		OnChange = function(id)
			pages[current].Visible = false
			current = id
			UIMotion.In(pages[id], Vector2.new(24, 0))
			zoom = if id == "Yuz" or id == "Sac" then 1 else 0
		end,
	})
	tabs.Frame.Position = UDim2.fromOffset(0, 40)
	tabs.Frame.Parent = content

	-- İsim plakası (sağ alt)
	local plate = Instance.new("CanvasGroup")
	plate.BackgroundTransparency = 1
	plate.AnchorPoint = Vector2.new(1, 1)
	plate.Position = UDim2.new(1, -30, 1, -30)
	plate.Size = UDim2.fromOffset(560, 90)
	plate.Parent = gui
	local plateName = Components.Label({
		Text = "FUTBOLCU",
		Size = 46,
		Font = Theme.Font.Display,
		Color = C.Yellow,
		Upper = true,
		Align = Enum.TextXAlignment.Right,
		Frame = UDim2.new(1, 0, 0, 52),
	})
	plateName.Parent = plate
	local plateSub = Components.Label({
		Text = "",
		Size = 17,
		Color = C.Text,
		Font = Theme.Font.Title,
		Upper = true,
		Align = Enum.TextXAlignment.Right,
		Frame = UDim2.new(1, 0, 0, 22),
	})
	plateSub.Position = UDim2.fromOffset(0, 56)
	plateSub.Parent = plate
	local function refreshPlate()
		plateName.Text = if state.name ~= "" then Theme.Upper(state.name) else "FUTBOLCU"
		plateSub.Text = Theme.Upper(
			POSITION_INFO[state.position][2] .. " · " .. state.number .. (if state.clubName ~= "" then " · " .. state.clubName else "")
		)
	end

	local hint = Components.Label({
		Text = "Çevirmek için sürükle",
		Size = 13,
		Color = C.Muted,
		Upper = true,
		Align = Enum.TextXAlignment.Right,
		Frame = UDim2.fromOffset(300, 18),
	})
	hint.AnchorPoint = Vector2.new(1, 0)
	hint.Position = UDim2.new(1, -30, 0, 26)
	hint.Parent = gui

	---------------------------------------------------------------- Kimlik
	do
		local p = page("Kimlik")
		Forms.Caption("Futbolcu adı (sonradan değişmez)", 1).Parent = p
		local r1 = Forms.Row(8, 40, 2)
		r1.Parent = p
		local nameBox = Forms.TextInput({
			Placeholder = "Adını yaz",
			MaxLength = Config.Name.Max,
			Size = UDim2.new(1, -146, 0, 40),
			Order = 1,
			OnChange = function(t)
				state.name = t
				refreshPlate()
			end,
		})
		nameBox.Parent = r1
		local num = Forms.Stepper({
			Min = 1,
			Max = 99,
			Value = 9,
			Order = 2,
			OnChange = function(v)
				state.number = v
				refreshPlate()
				preview()
			end,
		})
		num.Frame.Parent = r1

		Forms.Caption("Kulübünün adı ve kısaltması", 3).Parent = p
		local r2 = Forms.Row(8, 40, 4)
		r2.Parent = p
		local clubBox = Forms.TextInput({
			Placeholder = "Kulüp adı",
			MaxLength = Config.ClubName.Max,
			Size = UDim2.new(1, -146, 0, 40),
			Order = 1,
			OnChange = function(t)
				state.clubName = t
				refreshPlate()
			end,
		})
		clubBox.Parent = r2
		local abbrBox = Forms.TextInput({
			Placeholder = "KIS",
			MaxLength = 3,
			Upper = true,
			Pattern = "[^A-Z]",
			Size = UDim2.fromOffset(130, 40),
			Order = 2,
			OnChange = function(t)
				state.clubAbbr = t
				if #t >= 2 then
					preview()
				end
			end,
		})
		abbrBox.Parent = r2

		Forms.Caption("Mevki (bir kez seçilir, kariyer boyunca değişmez)", 5).Parent = p
		local cards = Instance.new("Frame")
		cards.BackgroundTransparency = 1
		cards.Size = UDim2.new(1, 0, 0, 92)
		cards.LayoutOrder = 6
		cards.Parent = p
		local info = Components.Label({
			Text = POSITION_INFO.Forvet[3],
			Size = 14,
			Color = C.Text,
			Wrap = true,
			Order = 7,
			Frame = UDim2.new(1, 0, 0, 40),
		})
		info.Parent = p
		local posCards = {}
		local function paintPos()
			for id, card in pairs(posCards) do
				local on = id == state.position
				card.Stroke.Color = if on then C.Yellow else C.White
				card.Stroke.Transparency = if on then 0 else 0.85
				card.Code.TextColor3 = if on then C.Yellow else C.Text
			end
		end
		for i, id in ipairs(Config.Positions) do
			local b = Instance.new("TextButton")
			b.AutoButtonColor = false
			b.Text = ""
			b.BackgroundColor3 = C.Ground
			b.BackgroundTransparency = 0.2
			b.BorderSizePixel = 0
			b.Size = UDim2.new(0.25, -6, 1, 0)
			b.Position = UDim2.new((i - 1) * 0.25, (i - 1) * 2, 0, 0)
			Components.Corner(b, Theme.Corner.Medium)
			Components.Stroke(b, C.White, 2, 0.85).Name = "Stroke"
			local code = Components.Label({
				Text = POSITION_INFO[id][1],
				Size = 30,
				Font = Theme.Font.Display,
				Align = Enum.TextXAlignment.Center,
				Frame = UDim2.new(1, 0, 0, 40),
			})
			code.Name = "Code"
			code.Position = UDim2.fromOffset(0, 14)
			code.Parent = b
			local nm = Components.Label({
				Text = POSITION_INFO[id][2],
				Size = 13,
				Color = C.Muted,
				Upper = true,
				Align = Enum.TextXAlignment.Center,
				Frame = UDim2.new(1, 0, 0, 18),
			})
			nm.Position = UDim2.fromOffset(0, 58)
			nm.Parent = b
			local sc = Instance.new("UIScale")
			sc.Parent = b
			b.Activated:Connect(function()
				UIMotion.Sound("ClickSound")
				state.position = id
				info.Text = POSITION_INFO[id][3]
				sc.Scale = 0.92
				UIMotion.Tween(sc, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
				paintPos()
				refreshPlate()
				preview()
			end)
			b.Parent = cards
			posCards[id] = b
		end
		paintPos()
	end

	---------------------------------------------------------------- Yüz
	do
		local p = page("Yuz")
		Forms.Caption("Ten", 1).Parent = p
		Forms.Swatches({
			Colors = Config.SkinColors,
			Value = state.appearance.skin,
			Order = 2,
			OnChange = function(i)
				state.appearance.skin = i
				preview()
			end,
		}).Frame.Parent =
			p
		Forms.Caption("Yüz", 3).Parent = p
		local faces = {}
		for i = 1, Config.Appearance.Faces do
			faces[i] = { Id = i, Text = "Yüz " .. i }
		end
		Forms.Chips({
			Options = faces,
			Value = 1,
			Order = 4,
			OnChange = function(v)
				state.appearance.face = v
				preview()
			end,
		}).Frame.Parent =
			p
		Forms.Caption("Sakal", 5).Parent = p
		local beards = {}
		for i = 0, Config.Appearance.Beards do
			table.insert(beards, { Id = i, Text = Config.BeardNames[i] })
		end
		Forms.Chips({
			Options = beards,
			Value = 0,
			Order = 6,
			OnChange = function(v)
				state.appearance.beard = v
				preview()
			end,
		}).Frame.Parent =
			p
		Components.Label({
			Text = "Yüz ve sakal görselleri topluluk dosyaları yüklenince görünür; seçimin şimdiden kaydedilir.",
			Size = 13,
			Color = C.Muted,
			Wrap = true,
			Order = 7,
			Frame = UDim2.new(1, 0, 0, 36),
		}).Parent =
			p
	end

	---------------------------------------------------------------- Saç
	do
		local p = page("Sac")
		Forms.Caption("Saç modeli", 1).Parent = p
		local styles = {}
		for i, n in ipairs(Config.HairStyleNames) do
			styles[i] = { Id = i, Text = n }
		end
		Forms.Chips({
			Options = styles,
			Value = state.appearance.hairStyle,
			Order = 2,
			OnChange = function(v)
				state.appearance.hairStyle = v
				preview()
			end,
		}).Frame.Parent =
			p
		Forms.Caption("Saç rengi", 3).Parent = p
		Forms.Swatches({
			Colors = hexToColor(Config.HairColors),
			Value = 1,
			Order = 4,
			OnChange = function(i)
				state.appearance.hairColor = Config.HairColors[i]
				preview()
			end,
		}).Frame.Parent =
			p
	end

	---------------------------------------------------------------- Vücut
	do
		local p = page("Vucut")
		Forms.Caption("Boy", 1).Parent = p
		Forms.Slider({
			Min = Config.Appearance.HeightMin,
			Max = Config.Appearance.HeightMax,
			Value = state.appearance.height,
			Order = 2,
			Format = function(v)
				return v .. " cm"
			end,
			OnChange = function(v)
				state.appearance.height = v
				preview()
			end,
		}).Frame.Parent =
			p
		Forms.Caption("Yapı", 3).Parent = p
		local builds = {}
		for i, id in ipairs(Config.Appearance.Builds) do
			builds[i] = { Id = id, Text = Config.BuildNames[id] }
		end
		Forms.Chips({
			Options = builds,
			Value = state.appearance.build,
			ChipWidth = 120,
			Order = 4,
			OnChange = function(v)
				state.appearance.build = v
				preview()
			end,
		}).Frame.Parent =
			p
		Components.Label({
			Text = "Boy ve yapı yalnızca görünümdür; maçta herkesin isabet alanı aynıdır.",
			Size = 13,
			Color = C.Muted,
			Wrap = true,
			Order = 5,
			Frame = UDim2.new(1, 0, 0, 36),
		}).Parent =
			p
	end

	---------------------------------------------------------------- Forma
	do
		local p = page("Forma")
		Forms.Caption("Kulüp forma deseni", 1).Parent = p
		local pats = {}
		for i, id in ipairs(Config.Appearance.KitPatterns) do
			pats[i] = { Id = id, Text = Config.KitPatternNames[id] }
		end
		Forms.Chips({
			Options = pats,
			Value = state.kitPattern,
			ChipWidth = 120,
			Order = 2,
			OnChange = function(v)
				state.kitPattern = v
				preview()
			end,
		}).Frame.Parent =
			p
		Forms.Caption("Arma şekli", 3).Parent = p
		local shapes = {}
		for i = 1, Config.Appearance.CrestShapes do
			shapes[i] = { Id = i, Text = "Kalkan " .. i }
		end
		Forms.Chips({
			Options = shapes,
			Value = 1,
			Order = 4,
			OnChange = function(v)
				state.crestShape = v
			end,
		}).Frame.Parent =
			p
		Forms.Caption("Krampon", 5).Parent = p
		local boots = {}
		for i = 1, Config.Appearance.BootModels do
			boots[i] = { Id = i, Text = "Model " .. i }
		end
		Forms.Chips({
			Options = boots,
			Value = 1,
			Order = 6,
			OnChange = function(v)
				state.appearance.bootModel = v
			end,
		}).Frame.Parent =
			p
		Forms.Swatches({
			Colors = hexToColor(Config.BootColors),
			Value = 1,
			Order = 7,
			OnChange = function(i)
				state.appearance.bootColor = Config.BootColors[i]
				preview()
			end,
		}).Frame.Parent =
			p
		Components.Label({
			Text = "Kaleci seçersen forman yeşil olur. Renkler sarı-lacivert ailesiyle sınırlıdır.",
			Size = 13,
			Color = C.Muted,
			Wrap = true,
			Order = 8,
			Frame = UDim2.new(1, 0, 0, 36),
		}).Parent =
			p
	end

	---------------------------------------------------------------- Aksesuar
	do
		local p = page("Aksesuar")
		Forms.Caption("Aksesuarlar (birden fazla seçilebilir)", 1).Parent = p
		local opts = {}
		for i, id in ipairs(Config.Accessories) do
			opts[i] = { Id = id, Text = Config.AccessoryNames[id] }
		end
		table.insert(
			opts,
			{ Id = "Kaptan", Text = "Kaptan bandı", Locked = "Kaptan bandı seviye " .. Config.CaptainBandLevel .. " ödülüdür." }
		)
		Forms.Chips({
			Options = opts,
			Multi = true,
			Values = state.appearance.accessories,
			Order = 2,
			OnChange = function(values)
				values.Kaptan = nil
				state.appearance.accessories = values
				preview()
			end,
		}).Frame.Parent =
			p
	end

	----------------------------------------------------------------------------
	-- Alt butonlar
	----------------------------------------------------------------------------
	local startBtn
	startBtn = Components.Button({
		Text = "Kariyere başla",
		Style = "Primary",
		Size = UDim2.new(0.62, -6, 0, 56),
		OnClick = function()
			local nameLen = utf8.len(state.name) or 0
			local clubLen = utf8.len(state.clubName) or 0
			if nameLen < Config.Name.Min then
				UIMotion.Shake(startBtn)
				return Components.Toast("error", "Futbolcu adı en az " .. Config.Name.Min .. " harf olmalı.")
			end
			if clubLen < Config.ClubName.Min then
				UIMotion.Shake(startBtn)
				return Components.Toast("error", "Kulüp adı en az " .. Config.ClubName.Min .. " harf olmalı.")
			end
			if #state.clubAbbr < 2 then
				UIMotion.Shake(startBtn)
				return Components.Toast("error", "Kulüp kısaltması 2 ya da 3 harf olmalı.")
			end
			Forms.Modal({
				Parent = gui,
				Title = "Emin misin?",
				Text = "Mevkin "
					.. POSITION_INFO[state.position][2]
					.. " olarak kilitlenecek ve adın "
					.. state.name
					.. " olarak kalacak. Bu ikisi sonradan değiştirilemez. Görünümünü mağazadan değiştirebilirsin.",
				Confirm = "Kilitle ve başla",
				Cancel = "Geri dön",
				OnConfirm = function()
					Remotes.Get("CreateCareer"):FireServer({
						name = state.name,
						number = state.number,
						position = state.position,
						clubName = state.clubName,
						clubAbbr = state.clubAbbr,
						crestShape = state.crestShape,
						kitPattern = state.kitPattern,
						appearance = state.appearance,
					})
				end,
			})
		end,
	})
	startBtn.AnchorPoint = Vector2.new(1, 1)
	startBtn.Position = UDim2.fromScale(1, 1)
	startBtn.Parent = content

	local randomBtn = Components.Button({
		Text = "Rastgele",
		Style = "Ghost",
		Size = UDim2.new(0.38, -6, 0, 56),
		OnClick = function()
			local a = state.appearance
			a.height = math.random(Config.Appearance.HeightMin, Config.Appearance.HeightMax)
			a.build = Config.Appearance.Builds[math.random(1, 3)]
			a.skin = math.random(1, Config.Appearance.SkinTones)
			a.hairStyle = math.random(1, Config.Appearance.HairStyles)
			a.hairColor = Config.HairColors[math.random(1, #Config.HairColors)]
			a.bootColor = Config.BootColors[math.random(1, #Config.BootColors)]
			preview()
			Components.Toast("info", "Rastgele görünüm uygulandı. Sekmelerden ince ayar yapabilirsin.")
		end,
	})
	randomBtn.AnchorPoint = Vector2.new(0, 1)
	randomBtn.Position = UDim2.fromScale(0, 1)
	randomBtn.Parent = content

	-- Sahneye giriş
	UIMotion.In(panel, Vector2.new(-50, 0), 0.05)
	UIMotion.In(plate, Vector2.new(40, 0), 0.2)
	refreshPlate()
	preview()

	-- Sunucu kariyeri oluşturunca kapan
	table.insert(
		conns,
		Remotes.Get("DataChanged").OnClientEvent:Connect(function(data)
			if alive and data.created then
				alive = false
				UIMotion.Wipe(function()
					RunService:UnbindFromRenderStep("FK_CreatorCam")
					for _, c in ipairs(conns) do
						c:Disconnect()
					end
					panel:Destroy()
					plate:Destroy()
					hint:Destroy()
					dragArea:Destroy()
					cam.CameraType = Enum.CameraType.Custom
					cam.FieldOfView = 70
					onCreated()
				end)
			end
		end)
	)
end

return Creator

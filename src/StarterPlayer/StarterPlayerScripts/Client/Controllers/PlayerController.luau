--[[
	PlayerController
	Oyuncunun hareketi, dayanıklılığı, eylem girdileri, efektleri ve saha içi arayüzü.
	- Hareket: ivmelenme, yavaşlama, ani dönüşte hız kaybı ve fren animasyonu, sprint ve yorgunluk.
	- Eylemler: şut türleri, pas, çalımlar, kafa, röveşata, müdahaleler, plonjon, sevinç. Klavye ve dokunmatik.
	- Efektler: ayak tozu, vuruş halkası, kamera sarsıntısı, hıza göre görüş açısı.
	Top henüz yok (5. adım); bu adım hareket hissini ve animasyonları sınamak içindir.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.UI.Theme)
local UIMotion = require(ReplicatedStorage.UI.UIMotion)
local Components = require(ReplicatedStorage.UI.Components)
local Animator = require(script.Parent.Parent.Anim.Animator)
local Poses = require(script.Parent.Parent.Anim.Poses)

local C = Theme.Color
local M = Config.Movement
local player = Players.LocalPlayer

local Controller = {}

local SHOTS = { "Shoot", "Plase", "Fuze", "Asirtma", "Vole", "Rovesata" }
-- Eylemin hangi yetenekle açıldığı: { zincir, sıra }
local REQUIRES = {
	Shoot = { "Sut", 1 },
	Plase = { "Sut", 2 },
	Fuze = { "Sut", 3 },
	Asirtma = { "Sut", 4 },
	Vole = { "Sut", 5 },
	Rovesata = { "Sut", 6 },
	VucutCalimi = { "Calim", 1 },
	Marsilya = { "Calim", 3 },
	Elastico = { "Calim", 5 },
	Jump = { "Hava", 1 },
	Header = { "Hava", 2 },
	UcanKafa = { "Hava", 4 },
	AyaktaMudahale = { "Defans", 1 },
	Kayma = { "Defans", 4 },
	Blok = { "Defans", 5 },
	Plonjon = { "Kaleci", 1 },
}

local state = {
	animator = nil :: any,
	hum = nil :: Humanoid?,
	hrp = nil :: BasePart?,
	speed = 0,
	stamina = M.StaminaMax,
	tired = false,
	sprintHeld = false,
	lastDir = Vector3.zero,
	shot = 1,
	hud = false,
	getData = nil :: any,
}
local ui: { [string]: any } = {}

--------------------------------------------------------------------------------
-- Efektler
--------------------------------------------------------------------------------
local fxPart: Part? = nil
local dust: ParticleEmitter? = nil
local function ensureFx()
	if fxPart and fxPart.Parent then
		return
	end
	local p = Instance.new("Part")
	p.Name = "FK_Fx"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Parent = Workspace
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(190, 200, 150), Color3.fromRGB(120, 150, 90))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2.2) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.35, 0.7)
	e.Speed = NumberRange.new(2, 6)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Acceleration = Vector3.new(0, 4, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = p
	fxPart, dust = p, e
end

local function puff(pos: Vector3, count: number)
	ensureFx()
	if fxPart and dust then
		fxPart.CFrame = CFrame.new(pos)
		dust:Emit(count)
	end
end

local function ring(pos: Vector3, color: Color3, size: number)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.25
	p.Size = Vector3.new(0.08, 1, 1)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = Workspace
	local tw = TweenService:Create(
		p,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.08, size, size), Transparency = 1 }
	)
	tw:Play()
	tw.Completed:Once(function()
		p:Destroy()
	end)
end

local function shake(amount: number)
	local hum = state.hum
	if not hum or UIMotion.Reduced then
		return
	end
	task.spawn(function()
		for i = 1, 5 do
			local k = amount * (1 - i / 6)
			hum.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
			task.wait(0.03)
		end
		hum.CameraOffset = Vector3.zero
	end)
end

local function footPos(side: string): Vector3
	local char = player.Character
	local foot = char and char:FindFirstChild(side .. "Foot")
	if foot and foot:IsA("BasePart") then
		return foot.Position - Vector3.new(0, foot.Size.Y / 2, 0)
	end
	return if state.hrp then state.hrp.Position - Vector3.new(0, 3, 0) else Vector3.zero
end

--------------------------------------------------------------------------------
-- Saha içi arayüz
--------------------------------------------------------------------------------
local function banner(text: string, color: Color3?)
	local l = ui.banner
	if not l then
		return
	end
	l.Text = Theme.Upper(text)
	l.TextColor3 = color or C.Yellow
	l.TextTransparency = 0
	ui.bannerStroke.Transparency = 0
	UIMotion.Pop(l, 0.6)
	ui.bannerToken = (ui.bannerToken or 0) + 1
	local token = ui.bannerToken
	task.delay(0.9, function()
		if ui.bannerToken == token then
			UIMotion.Tween(l, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { TextTransparency = 1 })
			UIMotion.Tween(ui.bannerStroke, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Transparency = 1 })
		end
	end)
end

local function unlocked(action: string): boolean
	if Config.Debug.UnlockAllActions then
		return true
	end
	local req = REQUIRES[action]
	local data = state.getData and state.getData()
	if not req or not data then
		return true
	end
	return (data.skills[req[1]] or 0) >= req[2]
end

local function paintShots()
	for i, slot in ipairs(ui.slots or {}) do
		local on = i == state.shot
		local open = unlocked(SHOTS[i])
		UIMotion.Tween(slot, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundColor3 = if on then C.Yellow else C.Navy })
		slot.Name_.TextColor3 = if on then C.Navy elseif open then C.Text else C.Muted
		slot.Key.TextColor3 = if on then C.Navy else C.Muted
	end
end

local function selectShot(i: number)
	if not SHOTS[i] then
		return
	end
	if not unlocked(SHOTS[i]) then
		UIMotion.Shake(ui.slots[i])
		return Components.Toast("error", Poses.Names[SHOTS[i]] .. " henüz açılmadı.")
	end
	state.shot = i
	UIMotion.Pop(ui.slots[i], 0.85)
	paintShots()
end

--------------------------------------------------------------------------------
-- Eylemler
--------------------------------------------------------------------------------
local function play(action: string, opts: any?)
	local an = state.animator
	if not an or not state.hud then
		return
	end
	if not unlocked(action) then
		return Components.Toast("error", Poses.Names[action] .. " henüz açılmadı.")
	end
	local def = Poses.Actions[action]
	if def.Mask == "Full" and state.hum and state.hum.FloorMaterial == Enum.Material.Air and action ~= "Vole" and action ~= "Rovesata" then
		return -- havadayken yeni yer hareketi başlamaz
	end
	an:Play(action, opts)
end

local function doShoot()
	play(SHOTS[state.shot])
end
local function doTackle()
	play(if state.speed > M.Run + 2 then "Kayma" else "AyaktaMudahale")
end
local function doCelebrate()
	play(if state.speed > 8 then "DizKaymasi" else "Sevinc")
end
local function doJump()
	play(if state.speed > M.Run + 2 then "UcanKafa" else "Header")
end

local KEYMAP: { [Enum.KeyCode]: () -> () } = {
	[Config.Keys.Shoot] = doShoot,
	[Config.Keys.Pass] = function()
		play("Pass")
	end,
	[Config.Keys.Dribble] = function()
		play("VucutCalimi", { Mirror = math.random() < 0.5 })
	end,
	[Config.Keys.Special] = function()
		play("Marsilya")
	end,
	[Enum.KeyCode.T] = function()
		play("Elastico")
	end,
	[Config.Keys.Jump] = doJump,
	[Config.Keys.Tackle] = doTackle,
	[Enum.KeyCode.V] = function()
		play("Blok")
	end,
	[Config.Keys.Celebrate] = doCelebrate,
	[Enum.KeyCode.H] = function()
		play("TopIste")
	end,
	[Enum.KeyCode.Z] = function()
		play("Plonjon", { Mirror = true })
	end,
	[Enum.KeyCode.X] = function()
		play("Plonjon")
	end,
}
local NUMBER_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }

local function onEvent(event: string, action: string)
	local hrp, hum = state.hrp, state.hum
	if not hrp or not hum then
		return
	end
	local look = hrp.CFrame.LookVector
	if event == "start" then
		if action ~= "Fren" then
			banner(Poses.Names[action] or action)
		end
	elseif event == "strike" then
		local power = if action == "Fuze" then 1 elseif action == "Rovesata" or action == "UcanKafa" then 0.8 else 0.5
		shake(0.25 + power * 0.5)
		local pos = if action == "Header" or action == "UcanKafa"
			then hrp.Position + look * 1.5 + Vector3.new(0, 2.2, 0)
			else footPos("Right") + look * 1.2
		ring(pos, if action == "Fuze" then Color3.fromRGB(255, 120, 60) else C.Yellow, 4 + power * 5)
		UIMotion.Sound("ConfirmSound")
		if action == "Rovesata" then
			banner("Röveşata!", C.Gold)
		end
	elseif event == "jump" then
		local v = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(v.X, math.sqrt(2 * Workspace.Gravity * M.JumpHeight), v.Z)
	elseif event == "slide" then
		hrp.AssemblyLinearVelocity = look * (if action == "DizKaymasi" then 26 else 34) + Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
		puff(footPos("Right"), 14)
	elseif event == "tackle" or event == "block" or event == "save" then
		ring(footPos("Right") + look * 1.5, C.White, 4)
	elseif event == "feint" then
		ring(hrp.Position - Vector3.new(0, 2.8, 0), C.Yellow, 6)
	elseif event == "land" then
		puff(hrp.Position - Vector3.new(0, 2.8, 0), 10)
		shake(0.2)
	elseif event == "skid" then
		puff(footPos("Left"), 8)
	elseif event == "footL" or event == "footR" then
		if action == "sprint" then
			puff(footPos(if event == "footL" then "Left" else "Right"), 2)
		end
	elseif event == "end" then
		local def = Poses.Actions[action]
		if def and def.EndShift then
			local s = def.EndShift
			local mirror = action == "Plonjon" and ui.lastMirror
			hrp.CFrame = hrp.CFrame * CFrame.new(if mirror then -s.X else s.X, s.Y, s.Z)
		end
	end
end

--------------------------------------------------------------------------------
-- Her karede: hareket + animasyon
--------------------------------------------------------------------------------
local function step(dt: number)
	local hum, hrp, an = state.hum, state.hrp, state.animator
	if not hum or not hrp or not an or hum.Health <= 0 then
		return
	end
	-- Görünüm yenilenince eklemler değişir; eski eklemlere yazmamak için yeniden bağlan
	local waist = an.Motors.Waist
	if (not waist or not waist:IsDescendantOf(an.Character)) and os.clock() - (ui.lastRebind or 0) > 1 then
		ui.lastRebind = os.clock()
		Controller.Rebind()
		return
	end
	local dir = hum.MoveDirection
	local moving = dir.Magnitude > 0.1
	local wantSprint = state.sprintHeld and moving and not state.tired and state.stamina > 0

	-- dayanıklılık
	if wantSprint then
		state.stamina = math.max(0, state.stamina - M.SprintDrain * dt)
		if state.stamina <= 0 then
			state.tired = true
			banner("Yoruldun", C.Bad)
		end
	else
		state.stamina = math.min(M.StaminaMax, state.stamina + M.Regen * dt * (if moving then 0.6 else 1))
		if state.tired and state.stamina >= M.TiredUntil then
			state.tired = false
		end
	end

	-- hedef hız ve ivme
	local target = 0
	if moving then
		target = if wantSprint then M.Sprint else M.Run
		if state.tired then
			target *= M.TiredFactor
		end
	end
	if moving and state.lastDir.Magnitude > 0.1 and state.lastDir:Dot(dir) < M.TurnDot and state.speed > M.Run * 0.7 then
		state.speed *= M.TurnLoss
		an:Play("Fren")
	end
	if moving then
		state.lastDir = dir
	end
	local rate = if target > state.speed then M.Sprint / M.AccelTime else M.Sprint / M.DecelTime
	state.speed += math.clamp(target - state.speed, -rate * dt, rate * dt)
	local factor = an:SpeedFactor()
	hum.WalkSpeed = if hum:GetAttribute("FK_Frozen") then 0 else math.max(state.speed, if moving then 3 else 0) * factor
	hum.JumpHeight = 0 -- zıplama eylemle yapılır

	-- görüş açısı hıza göre genişler
	local cam = Workspace.CurrentCamera
	if cam.CameraType == Enum.CameraType.Custom then
		local k = math.clamp((state.speed - M.Run) / (M.Sprint - M.Run), 0, 1)
		cam.FieldOfView += ((M.FovBase + (M.FovSprint - M.FovBase) * k) - cam.FieldOfView) * math.min(1, dt * 5)
	end

	-- dönüş yönü (yana yatma için)
	local turn = 0
	if moving then
		turn = math.clamp(hrp.CFrame.RightVector:Dot(dir) * 2, -1, 1)
	end
	local vel = hrp.AssemblyLinearVelocity
	an:Update(dt, {
		speed = Vector3.new(vel.X, 0, vel.Z).Magnitude,
		sprinting = wantSprint,
		tired = state.tired,
		grounded = hum.FloorMaterial ~= Enum.Material.Air,
		turn = turn,
		vy = vel.Y,
	})

	-- arayüz
	if ui.stamina then
		local r = state.stamina / M.StaminaMax
		if math.abs(r - ui.stamina.Value) > 0.004 then
			ui.stamina.Set(r, true)
		end
		ui.staminaFill.BackgroundColor3 = if state.tired then C.Bad elseif r < 0.3 then C.Gold else C.Good
		ui.speed.Text = string.format("%d", math.floor(state.speed + 0.5))
	end
end

local function bindCharacter(character: Model)
	local hum = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not hum or not hrp then
		return
	end
	task.wait(0.3) -- görünüm uygulanırken parçalar yenilenebilir
	if state.animator then
		state.animator:Destroy()
	end
	state.hum, state.hrp = hum, hrp
	state.animator = Animator.new(character)
	state.animator:OnEvent(onEvent)
	state.speed = 0
end

-- Görünüm değişince (ApplyDescription) eklemler yenilenir; animatörü yeniden kur
function Controller.Rebind()
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
end

--------------------------------------------------------------------------------
-- Arayüz kurulumu
--------------------------------------------------------------------------------
local function roundButton(text: string, size: number, primary: boolean, onDown: () -> (), onUp: (() -> ())?)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Text = ""
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundColor3 = if primary then C.Yellow else C.Navy
	b.BackgroundTransparency = if primary then 0 else 0.15
	b.BorderSizePixel = 0
	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(1, 0)
	cr.Parent = b
	Components.Stroke(b, if primary then C.White else C.Yellow, 2.5, if primary then 0.6 else 0.1)
	local l = Components.Label({
		Text = text,
		Size = if size > 100 then 22 else 16,
		Font = Theme.Font.Display,
		Color = if primary then C.Navy else C.Text,
		Upper = true,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.fromScale(1, 1),
	})
	l.Parent = b
	local sc = Instance.new("UIScale")
	sc.Parent = b
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			UIMotion.Tween(sc, 0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 0.9 })
			onDown()
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			UIMotion.Tween(sc, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
			if onUp then
				onUp()
			end
		end
	end)
	return b
end

local function buildHud(gui: ScreenGui, onExit: () -> ())
	local root = Instance.new("Frame")
	root.Name = "PitchHud"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = gui
	ui.root = root

	-- Dayanıklılık (sol alt)
	local sp, sc = Components.Panel({
		Name = "Stamina",
		Size = UDim2.fromOffset(320, 78),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -20),
		Accent = false,
	})
	sp.Parent = root
	local cap = Components.Label({
		Text = "Dayanıklılık",
		Size = 12,
		Color = C.Muted,
		Font = Theme.Font.Title,
		Upper = true,
		Frame = UDim2.new(1, -80, 0, 14),
	})
	cap.Parent = sc
	ui.stamina = Components.Bar({ Size = UDim2.new(1, -80, 0, 12), Color = C.Good, Value = 1 })
	ui.stamina.Frame.Position = UDim2.fromOffset(0, 22)
	ui.stamina.Frame.Parent = sc
	ui.staminaFill = ui.stamina.Frame:FindFirstChildOfClass("Frame")
	ui.speed = Components.Label({
		Text = "0",
		Size = 30,
		Font = Theme.Font.Number,
		Color = C.Yellow,
		Align = Enum.TextXAlignment.Right,
		Frame = UDim2.fromOffset(70, 34),
	})
	ui.speed.AnchorPoint = Vector2.new(1, 0)
	ui.speed.Position = UDim2.fromScale(1, 0)
	ui.speed.Parent = sc
	local unit = Components.Label({
		Text = "hız",
		Size = 11,
		Color = C.Muted,
		Upper = true,
		Align = Enum.TextXAlignment.Right,
		Frame = UDim2.fromOffset(70, 14),
	})
	unit.AnchorPoint = Vector2.new(1, 0)
	unit.Position = UDim2.new(1, 0, 0, 34)
	unit.Parent = sc

	-- Şut yuvaları (alt orta)
	local slots = Instance.new("Frame")
	slots.BackgroundTransparency = 1
	slots.AnchorPoint = Vector2.new(0.5, 1)
	slots.Position = UDim2.new(0.5, 0, 1, -20)
	slots.Size = UDim2.fromOffset(#SHOTS * 108 - 8, 62)
	slots.Parent = root
	ui.slots = {}
	for i, id in ipairs(SHOTS) do
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Text = ""
		b.BackgroundColor3 = C.Navy
		b.BackgroundTransparency = 0.08
		b.BorderSizePixel = 0
		b.Size = UDim2.fromOffset(100, 62)
		b.Position = UDim2.fromOffset((i - 1) * 108, 0)
		Components.Corner(b, Theme.Corner.Small)
		Components.Stroke(b, C.Yellow, 1.5, 0.55)
		local key =
			Components.Label({ Text = tostring(i), Size = 12, Font = Theme.Font.Number, Color = C.Muted, Frame = UDim2.fromOffset(20, 16) })
		key.Name = "Key"
		key.Position = UDim2.fromOffset(8, 4)
		key.Parent = b
		local nm = Components.Label({
			Text = Poses.Names[id],
			Size = 15,
			Font = Theme.Font.Display,
			Upper = true,
			Align = Enum.TextXAlignment.Center,
			Frame = UDim2.new(1, 0, 0, 20),
		})
		nm.Name = "Name_"
		nm.Position = UDim2.fromOffset(0, 26)
		nm.Parent = b
		b.Activated:Connect(function()
			selectShot(i)
		end)
		b.Parent = slots
		ui.slots[i] = b
	end

	-- Eylem adı (orta üst)
	local bn = Components.Label({
		Text = "",
		Size = 54,
		Font = Theme.Font.Display,
		Color = C.Yellow,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.new(1, 0, 0, 64),
	})
	bn.Position = UDim2.fromScale(0, 0.2)
	bn.TextTransparency = 1
	ui.bannerStroke = Components.Stroke(bn, C.Navy, 4, 1)
	ui.bannerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	bn.Parent = root
	ui.banner = bn

	-- Çıkış (sağ üst, bakiyenin altında)
	local exit =
		Components.Button({ Text = "Lobiye dön", Style = "Ghost", Size = UDim2.fromOffset(180, 44), TextSize = 16, OnClick = onExit })
	exit.AnchorPoint = Vector2.new(1, 0)
	exit.Position = UDim2.new(1, -20, 0, 96)
	exit.Parent = root

	if UserInputService.TouchEnabled then
		-- Dokunmatik butonlar (sağ alt)
		local pad = Instance.new("Frame")
		pad.BackgroundTransparency = 1
		pad.AnchorPoint = Vector2.new(1, 1)
		pad.Position = UDim2.new(1, -24, 1, -100)
		pad.Size = UDim2.fromOffset(380, 300)
		pad.Parent = root
		local function place(b: GuiObject, x: number, y: number)
			b.AnchorPoint = Vector2.new(1, 1)
			b.Position = UDim2.new(1, -x, 1, -y)
			b.Parent = pad
		end
		place(roundButton("Şut", 120, true, doShoot), 0, 0)
		place(
			roundButton("Pas", 88, false, function()
				play("Pass")
			end),
			132,
			0
		)
		place(
			roundButton("Sprint", 88, false, function()
				state.sprintHeld = true
			end, function()
				state.sprintHeld = false
			end),
			232,
			0
		)
		place(
			roundButton("Çalım", 88, false, function()
				play("VucutCalimi", { Mirror = math.random() < 0.5 })
			end),
			16,
			132
		)
		place(roundButton("Zıpla", 88, false, doJump), 116, 104)
		place(roundButton("Müdahale", 88, false, doTackle), 216, 104)
		place(roundButton("Sevinç", 76, false, doCelebrate), 60, 232)
		place(
			roundButton("Marsilya", 76, false, function()
				play("Marsilya")
			end),
			150,
			208
		)
	else
		-- Tuş ipuçları (sağ alt)
		local hp, hc = Components.Panel({
			Name = "Keys",
			Size = UDim2.fromOffset(330, 250),
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -20, 1, -20),
			Title = "Tuşlar",
		})
		hp.Parent = root
		local lines = {
			{ "Shift", "Sprint" },
			{ "F", "Şut (1-6 ile tür seç)" },
			{ "E", "Pas" },
			{ "Q / R / T", "Vücut çalımı / Marsilya / Elastico" },
			{ "Boşluk", "Kafa (koşarken uçan kafa)" },
			{ "C / V", "Müdahale (koşarken kayma) / Blok" },
			{ "Z / X", "Plonjon sol / sağ" },
			{ "G / H", "Sevinç / Top iste" },
		}
		for i, ln in ipairs(lines) do
			local k =
				Components.Label({ Text = ln[1], Size = 13, Font = Theme.Font.Number, Color = C.Yellow, Frame = UDim2.fromOffset(84, 20) })
			k.Position = UDim2.fromOffset(0, 36 + (i - 1) * 23)
			k.Parent = hc
			local t = Components.Label({ Text = ln[2], Size = 13, Frame = UDim2.new(1, -90, 0, 20) })
			t.Position = UDim2.fromOffset(90, 36 + (i - 1) * 23)
			t.Parent = hc
		end
	end
	paintShots()
end

function Controller.SetHud(visible: boolean)
	state.hud = visible
	if ui.root then
		ui.root.Visible = visible
		if visible then
			for _, child in ipairs(ui.root:GetChildren()) do
				if child:IsA("CanvasGroup") then
					UIMotion.In(child, Vector2.new(0, 30), 0.05)
				end
			end
			banner("Deneme sahası")
		end
	end
end

function Controller.Start(gui: ScreenGui, getData: () -> any, onExit: () -> ())
	state.getData = getData
	buildHud(gui, onExit)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Config.Keys.Sprint or input.KeyCode == Enum.KeyCode.ButtonR2 then
			state.sprintHeld = true
			return
		end
		local idx = table.find(NUMBER_KEYS, input.KeyCode)
		if idx and state.hud then
			return selectShot(idx)
		end
		if input.KeyCode == Enum.KeyCode.Z then
			ui.lastMirror = true
		elseif input.KeyCode == Enum.KeyCode.X then
			ui.lastMirror = false
		end
		local fn = KEYMAP[input.KeyCode]
		if fn then
			fn()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Config.Keys.Sprint or input.KeyCode == Enum.KeyCode.ButtonR2 then
			state.sprintHeld = false
		end
	end)

	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	-- Eklemler her fizik adımından önce yazılır
	RunService.Stepped:Connect(function(_, dt)
		step(dt)
	end)
end

return Controller

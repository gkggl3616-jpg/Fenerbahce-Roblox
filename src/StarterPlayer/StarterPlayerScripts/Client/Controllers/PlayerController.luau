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
local Ball = require(script.Parent.Parent.Match.Ball)
local TimeScale = require(script.Parent.Parent.Match.TimeScale)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Bots = require(script.Parent.Parent.Match.Bots)
local Forms = require(ReplicatedStorage.UI.Forms)

local C = Theme.Color
local M = Config.Movement
local player = Players.LocalPlayer

local Controller = {}

local SHOTS = { "Shoot", "Plase", "Fuze", "Asirtma", "Vole", "Rovesata" }
-- Eylemin hangi yetenekle açıldığı: { zincir, sıra }

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
	charging = false,
	charge = 0,
	pending = nil :: any, -- bırakılan şutun gücü ve nişanı; vuruş anında kullanılır
	passPower = 0,
	goals = 0,
	combo = 0,
	turboUntil = 0,
	yellow = false,
	lastMirror = false,
}
local SH = Config.Shooting
local TP: any = Config.TestPitch
local matchApi: any = nil -- maç sürerken MatchController kancaları
local DU = Config.Duel
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

-- Hakem kartı: ekranın ortasında dönerek belirir
local function showCard(color: Color3, text: string)
	if not ui.root then
		return
	end
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.42)
	card.Size = UDim2.fromOffset(110, 160)
	card.BackgroundColor3 = color
	card.BorderSizePixel = 0
	card.Rotation = -200
	card.ZIndex = 40
	Components.Corner(card, 10)
	Components.Stroke(card, C.White, 3, 0.2)
	card.Parent = ui.root
	UIMotion.Pop(card, 0.2)
	UIMotion.Tween(card, 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Rotation = 8 })
	banner(text, color)
	task.delay(1.4, function()
		local tw = UIMotion.Tween(
			card,
			0.25,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In,
			{ Position = UDim2.fromScale(0.5, -0.3), Rotation = 60 }
		)
		tw.Completed:Once(function()
			card:Destroy()
		end)
	end)
end

local function setCombo(n: number)
	state.combo = n
	if ui.combo then
		ui.combo.Text = if n > 0 then "KOMBO x" .. n else ""
		if n > 0 then
			UIMotion.Pop(ui.combo, 1.5)
		end
	end
end

local function unlocked(action: string): boolean
	if Config.Debug.UnlockAllActionsInStudio and RunService:IsStudio() then
		return true
	end
	local data = state.getData and state.getData()
	if not data then
		return true
	end
	return Config.ActionUnlocked(data.skills, action)
end

-- Bir zincirde verilen hareketlerden açık olan en üsttekini seçer (liste alttan üste sıralıdır)
local function best(list: { string }): string
	local pick = list[1]
	for _, a in ipairs(list) do
		if unlocked(a) then
			pick = a
		end
	end
	return pick
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
		return Components.Toast("error", (Poses.Names[action] or action) .. " henüz açılmadı. Yetenek ağacından aç.")
	end
	local def = Poses.Actions[action]
	if def.Mask == "Full" and state.hum and state.hum.FloorMaterial == Enum.Material.Air and action ~= "Vole" and action ~= "Rovesata" then
		return -- havadayken yeni yer hareketi başlamaz
	end
	an:Play(action, opts)
end

local function stat(name: string): number
	local data = state.getData and state.getData()
	return (data and data.stats and data.stats[name]) or 1
end

local function aimInput(): number
	local hum = state.hum
	return if hum then math.clamp(hum.MoveDirection.X * 1.4, -1, 1) else 0
end

-- Şut: basılı tut (güç dolar), bırak (vuruş başlar)
local function shootDown()
	if not state.hud or state.charging then
		return
	end
	if not unlocked(SHOTS[state.shot]) then
		return Components.Toast("error", Poses.Names[SHOTS[state.shot]] .. " henüz açılmadı.")
	end
	state.charging = true
	state.charge = 0
end
local function shootUp()
	if not state.charging then
		return
	end
	state.charging = false
	local p = state.charge
	state.pending = { power = p, perfect = p >= SH.PerfectFrom and p <= SH.PerfectTo, over = p > SH.OverFrom, aimX = aimInput() }
	play(SHOTS[state.shot])
end
local passAt = 0
local function passDown()
	passAt = os.clock()
end
local function passUp()
	if passAt > 0 then
		state.passPower = math.clamp((os.clock() - passAt) / 0.5, 0, 1)
		passAt = 0
		play("Pass")
	end
end
local function cross()
	local hrp = state.hrp
	if not hrp or not state.hud then
		return
	end
	local side = if math.random() < 0.5 then -1 else 1
	local target = hrp.Position + hrp.CFrame.LookVector * 5 + Vector3.new(0, 3, 0)
	Ball.Cross(Vector3.new(side * 100, 0, math.min(TP.GoalZ - 14, target.Z + 30)), target, 1.75)
end
local function fetchBall()
	local hrp = state.hrp
	if hrp and state.hud then
		Ball.Reset(hrp.Position + hrp.CFrame.LookVector * 5)
	end
end
-- Tek tuş, açılan en üst hareket: yetenek ağacında ilerledikçe aynı tuş daha gösterişli hareketi yapar
local function doTackle()
	if state.speed > M.Run + 2 and unlocked("Kayma") then
		play("Kayma")
	else
		play(best({ "AyaktaMudahale", "Omuz" }))
	end
end
local function doDribble()
	play(best({ "VucutCalimi", "Bisiklet", "Marsilya", "Elastico", "Gokkusagi" }), { Mirror = math.random() < 0.5 })
end
local function doBlock()
	play(best({ "AyaktaMudahale", "Blok", "UcanBlok" }))
end
local function doCelebrate()
	play(if state.speed > 8 then "DizKaymasi" else "Sevinc")
end
local function doJump()
	if state.speed > M.Run + 2 and unlocked("UcanKafa") then
		play(best({ "UcanKafa", "Makas" }))
	else
		play(best({ "Jump", "Header", "GucluKafa" }))
	end
end

--------------------------------------------------------------------------------
-- Basit kontrol: fare + boşluk. Aynı tuş, topun sende olup olmamasına göre iş değiştirir.
--   Sol tık  : top sendeyse şut (basılı tut, bırak) · değilse müdahale · kaleciysen plonjon
--   Sağ tık  : top sendeyse pas · değilse top iste
--   Boşluk   : top sendeyse çalım · değilse zıpla / kafa
--------------------------------------------------------------------------------
local function ballInfo(): (number, number)
	local hrp = state.hrp
	if not hrp then
		return math.huge, 0
	end
	local bp = Ball.Position()
	local feet = hrp.Position - Vector3.new(0, 3, 0)
	return Vector3.new(bp.X - feet.X, 0, bp.Z - feet.Z).Magnitude, bp.Y - feet.Y
end
local function hasBall(): boolean
	local dist, height = ballInfo()
	return dist < SH.Reach + 1.5 and height < 3
end
local function isKeeper(): boolean
	local data = state.getData and state.getData()
	return matchApi ~= nil and data ~= nil and data.position == "Kaleci"
end
local primaryShooting = false
local function primaryDown()
	if not state.hud then
		return
	end
	local dist, height = ballInfo()
	if isKeeper() and not hasBall() then
		-- topun geldiği yana uzan
		local hrp = state.hrp
		if hrp then
			state.lastMirror = (Ball.Position() - hrp.Position):Dot(hrp.CFrame.RightVector) < 0
			play("Plonjon", { Mirror = state.lastMirror })
		end
	elseif hasBall() then
		primaryShooting = true
		shootDown()
	elseif dist < 9 and height >= 3 then
		-- havadaki top: açıksa gelişine vur, değilse kafa
		if unlocked("Vole") then
			play(best({ "Vole", "Rovesata" }))
		else
			doJump()
		end
	else
		doTackle()
	end
end
local function primaryUp()
	if primaryShooting then
		primaryShooting = false
		shootUp()
	end
end
local function secondary()
	if not state.hud then
		return
	end
	if hasBall() then
		state.passPower = 0.4
		play("Pass")
	else
		-- "Pas ver!": top takım arkadaşındaysa sana atar
		play("TopIste")
		local hrp = state.hrp
		if hrp and matchApi and matchApi.CallPass then
			matchApi.CallPass(hrp.Position - Vector3.new(0, 3, 0))
		end
	end
end
local function contextSpace()
	if hasBall() then
		doDribble()
	else
		doJump()
	end
end

local KEYMAP: { [Enum.KeyCode]: () -> () } = {
	[Config.Keys.Shoot] = shootDown,
	[Config.Keys.Pass] = passDown,
	[Enum.KeyCode.B] = cross,
	[Enum.KeyCode.N] = fetchBall,
	[Config.Keys.Dribble] = doDribble,
	[Config.Keys.Special] = function()
		play("VucutCalimi", { Mirror = math.random() < 0.5 }) -- hızlı, sade çalım her zaman elde
	end,
	[Config.Keys.Jump] = contextSpace,
	[Enum.KeyCode.T] = function()
		if matchApi and matchApi.CycleOrder then
			matchApi.CycleOrder() -- takım emri: Dengeli > Atak > Defans > Pres
		end
	end,
	[Config.Keys.Tackle] = doTackle,
	[Enum.KeyCode.V] = doBlock,
	[Config.Keys.Celebrate] = doCelebrate,
	[Enum.KeyCode.H] = function()
		if not hasBall() then
			secondary()
		end
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
		Remotes.Get("Anim"):FireServer(action, state.lastMirror) -- diğer oyuncular da görsün
	elseif event == "strike" then
		local feet = hrp.Position - Vector3.new(0, 3, 0)
		local near = (Ball.Position() - hrp.Position).Magnitude < 9
		if action == "Pass" then
			local targets = {}
			local studio = Workspace:FindFirstChild("FK_Studio")
			if studio then
				for _, d in ipairs(studio:GetChildren()) do
					if d.Name == "PassTarget" then
						table.insert(targets, (d :: BasePart).Position)
					end
				end
			end
			if Ball.Pass(feet, look, state.passPower or 0, stat("Pas"), targets) then
				ring(Ball.Position(), C.White, 4)
				shake(0.2)
			end
			return
		end
		-- zamanlamaya dayalı vuruşlar: { en alçak, en yüksek, erişim, ideal yükseklik }
		local WINDOW = {
			Header = { 3.6, 9.5, 4.2, 6.2 },
			UcanKafa = { 1.6, 6.8, 5.4, 4 },
			Vole = { 1.3, 5.2, 4, 3 },
			Rovesata = { 2.4, 9.5, 4.4, 6 },
			GucluKafa = { 3.4, 10, 4.8, 6.4 },
			Makas = { 1.6, 7.2, 5.2, 3.6 },
		}
		local win = WINDOW[action]
		local pending = state.pending or { power = 0.7, perfect = false, aimX = aimInput() }
		state.pending = nil
		local opts: any = {
			kind = action,
			from = feet,
			facing = look,
			aimX = pending.aimX,
			power = pending.power,
			perfect = pending.perfect,
			stat = stat("Sut"),
		}
		if win then
			local h = Ball.Position().Y - TP.GroundY
			opts.minY, opts.maxY, opts.reach = win[1], win[2], win[3]
			opts.power = 0.85
			opts.aimX = aimInput()
			opts.perfect = math.abs(h - win[4]) < 1.3 -- top tam ideal yükseklikteyken vurulduysa
			if action == "Header" or action == "UcanKafa" or action == "GucluKafa" then
				opts.stat = stat("Fizik")
			end
		end
		local quality, target = Ball.Strike(opts)
		if quality ~= "miss" and matchApi then
			matchApi.OnHumanKick()
		end
		if quality == "miss" then
			if near then
				banner("Iska", C.Bad)
				UIMotion.Sound("ErrorSound")
			end
			return
		end
		local strength = if action == "Fuze" then 1 elseif win then 0.8 else 0.5
		local color = if action == "Fuze" then Color3.fromRGB(255, 120, 60) elseif quality == "perfect" then C.Gold else C.Yellow
		ring(Ball.Position(), color, 5 + strength * 6)
		UIMotion.Sound("ConfirmSound")
		if quality == "perfect" then
			banner("Mükemmel!", C.Gold)
			TimeScale.Set(0.05, SH.HitStop) -- vuruş anında kısa duraksama
			shake(0.9)
			ring(Ball.Position(), C.White, 12)
		else
			shake(0.3 + strength * 0.5)
			if pending.over and not win then
				banner("Fazla tuttun", C.Bad)
			end
		end
		if action == "Rovesata" or action == "UcanKafa" or action == "Makas" then
			task.delay(SH.HitStop + 0.02, function()
				TimeScale.Set(SH.SlowMo, SH.SlowMoTime) -- yavaş çekim
			end)
			banner((Poses.Names[action] or action) .. "!", C.Gold)
		end
		if target and ui.aim then
			ui.aimHold = os.clock() + 0.8
		end
	elseif event == "jump" then
		local v = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(v.X, math.sqrt(2 * Workspace.Gravity * M.JumpHeight), v.Z)
	elseif event == "slide" then
		hrp.AssemblyLinearVelocity = look * (if action == "DizKaymasi" then 26 else 34) + Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
		puff(footPos("Right"), 14)
	elseif event == "tackle" then
		ring(footPos("Right") + look * 1.5, C.White, 4)
		if matchApi or Bots.Mode() == "Savunma" then
			local tackle = if matchApi then matchApi.Tackle else Bots.Tackle
			local result = tackle(hrp.Position - Vector3.new(0, 3, 0), look, action == "Kayma")
			if result == "win" then
				banner("Top sende!", C.Good)
				shake(0.6)
				ring(Ball.Position(), C.Good, 9)
				UIMotion.Sound("ConfirmSound")
				if not matchApi then
					Remotes.Get("TrainingGoal"):FireServer("Tackle")
				end
			elseif result == "foul" then
				if not matchApi then
					banner("Faul!", C.Bad)
				end
				UIMotion.Sound("ErrorSound")
				shake(0.5)
			elseif result == "card" then
				UIMotion.Sound("ErrorSound")
				shake(0.7)
				if matchApi then
					-- maçta kararı hakem verir (MatchController)
				elseif state.yellow then
					state.yellow = false
					showCard(C.Bad, "Kırmızı kart!")
					if matchApi then
						task.delay(1.6, matchApi.Forfeit) -- kırmızı kart: maç senin için biter
					end
				else
					state.yellow = true
					showCard(C.Yellow, "Sarı kart")
				end
			end
		end
	elseif event == "flick" then
		-- Gökkuşağı: top ayaktaysa topukla öne ve yukarı aşırılır
		local feet = hrp.Position - Vector3.new(0, 3, 0)
		if (Ball.Position() - feet).Magnitude < SH.Reach + 1.5 then
			Ball.Kick(look * 34 + Vector3.new(0, 44, 0))
			ring(Ball.Position(), C.Gold, 7)
			UIMotion.Sound("ConfirmSound")
		end
	elseif event == "block" or event == "save" then
		ring(footPos("Right") + look * 1.5, C.White, 4)
		if event == "block" then
			-- önümüzden hızlı geçen top gövdeye çarpar
			local bp, bv = Ball.Position(), Ball.Velocity()
			local reach = if action == "UcanBlok" then 7 else 4.5
			if (bp - hrp.Position).Magnitude < reach and bv.Magnitude > 30 and bv:Dot(look) < 0 then
				Ball.Deflect(-bv * 0.35 + Vector3.new(0, 12, 0))
				banner("Blok!", C.Good)
				shake(0.6)
				UIMotion.Sound("ConfirmSound")
			end
		end
		if event == "save" and matchApi then
			-- oyuncu kaleciyse: plonjon yönündeki el hizasında top varsa çeler
			local side = if state.lastMirror then -1 else 1
			local hand = hrp.Position + hrp.CFrame.RightVector * side * 3.6 + Vector3.new(0, 0.6, 0)
			if matchApi.HumanSave(hand) then
				banner("Kurtardın!", C.Gold)
				shake(0.9)
				TimeScale.Set(0.05, SH.HitStop)
				UIMotion.Sound("RewardSound")
			end
		end
	elseif event == "feint" then
		ring(hrp.Position - Vector3.new(0, 2.8, 0), C.Yellow, 6)
		local feint = if matchApi then matchApi.Feint else Bots.Feint
		if feint(hrp.Position - Vector3.new(0, 3, 0)) then
			setCombo(state.combo + 1)
			banner("Çalım!", C.Gold)
			ring(hrp.Position - Vector3.new(0, 2.8, 0), C.Gold, 12)
			shake(0.4)
			UIMotion.Sound("ConfirmSound")
			if not matchApi then
				Remotes.Get("TrainingGoal"):FireServer("Feint")
			end
			if state.combo >= DU.ComboForTurbo then
				setCombo(0)
				state.turboUntil = os.clock() + DU.TurboTime
				banner("Turbo!", C.Gold)
				UIMotion.Sound("RewardSound")
			end
		end
	elseif event == "land" then
		puff(hrp.Position - Vector3.new(0, 2.8, 0), 10)
		shake(0.2)
	elseif event == "skid" then
		puff(footPos("Left"), 8)
	elseif event == "footL" or event == "footR" then
		if action == "sprint" then
			puff(footPos(if event == "footL" then "Left" else "Right"), 2)
		end
		-- sürme: her adımda top öne itilir
		if state.hud and hum.MoveDirection.Magnitude > 0.1 then
			Ball.Touch({
				pos = hrp.Position - Vector3.new(0, 3, 0),
				dir = hum.MoveDirection,
				speed = state.speed,
				sprinting = action == "sprint",
				control = stat("TopKontrolu"),
			})
		end
	elseif event == "end" then
		local def = Poses.Actions[action]
		if def and def.EndShift then
			local s = def.EndShift
			local mirror = action == "Plonjon" and state.lastMirror
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
	-- Roblox'un kendi animasyonları eklemleri ezmesin
	if os.clock() - (ui.lastTrackSweep or 0) > 0.5 then
		ui.lastTrackSweep = os.clock()
		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				if not track:GetAttribute("FK") then
					track:Stop(0)
				end
			end
		end
	end
	local dir = hum.MoveDirection
	local moving = dir.Magnitude > 0.1
	local wantSprint = state.sprintHeld and moving and not state.tired and state.stamina > 0

	-- dayanıklılık
	if wantSprint then
		-- Fizik özelliği dayanıklılığı artırır (her seviye %5 daha az harcar)
		state.stamina = math.max(0, state.stamina - M.SprintDrain * (1 - (stat("Fizik") - 1) * 0.05) * dt)
		if state.stamina <= 0 then
			state.tired = true
			banner("Yoruldun", C.Bad)
		end
	else
		state.stamina = math.min(M.StaminaMax, state.stamina + M.Regen * dt * (if moving then 0.6 else 1))
		-- Yorgunluk, sprint tuşu bırakılmadan geçmez: tuş basılıyken hız gidip gelmesin
		if state.tired and state.stamina >= M.TiredUntil and not state.sprintHeld then
			state.tired = false
		end
	end

	-- hedef hız ve ivme
	local target = 0
	if moving then
		-- Hız özelliği koşu ve sprint hızını artırır (her seviye %2)
		target = (if wantSprint then M.Sprint else M.Run) * (1 + (stat("Hiz") - 1) * 0.02)
		if state.tired then
			target *= M.TiredFactor
		end
		if os.clock() < state.turboUntil then
			target *= DU.TurboBoost -- kombo ödülü: kısa süreli hız
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
	local ts = TimeScale.Value
	local sdt = dt * ts
	hum.WalkSpeed = math.max(state.speed, if moving then 3 else 0) * factor * ts
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
	an:Update(sdt, {
		speed = Vector3.new(vel.X, 0, vel.Z).Magnitude,
		sprinting = wantSprint,
		tired = state.tired,
		grounded = hum.FloorMaterial ~= Enum.Material.Air,
		turn = turn,
		vy = vel.Y,
	})

	-- turbo parlaması
	local turbo = os.clock() < state.turboUntil
	if ui.aura and ui.aura.Parent ~= (if turbo then an.Character else nil) then
		ui.aura.Parent = if turbo then an.Character else nil
	end

	-- top
	if state.hud then
		local ctx = { playerPos = hrp.Position - Vector3.new(0, 3, 0) }
		if matchApi then
			matchApi.Update(sdt, ctx)
		else
			Bots.Update(sdt, ctx)
		end
		Ball.Carry(sdt, {
			pos = hrp.Position - Vector3.new(0, 3, 0),
			dir = if moving then dir else Vector3.zero,
			speed = state.speed,
			control = stat("TopKontrolu"),
		})
		Ball.Step(sdt)
		-- düşüş halkası: havadan gelen topun ineceği yer; halka daraldıkça zıplama zamanı yaklaşır
		local land, t = Ball.Predict()
		if ui.landRing then
			if land and t and t > 0.05 then
				local sz = 2.5 + t * 7
				ui.landRing.Size = Vector3.new(0.06, sz, sz)
				ui.landRing.CFrame = CFrame.new(land.X, TP.GroundY + 0.05, land.Z) * CFrame.Angles(0, 0, math.rad(90))
				ui.landRing.Color = if t < 0.5 then C.Good else C.Yellow
				ui.landRing.Transparency = 0.35
			else
				ui.landRing.Transparency = 1
			end
		end
		-- şut gücü
		if state.charging then
			state.charge = math.min(SH.MaxCharge, state.charge + dt / SH.ChargeTime)
			if state.charge >= SH.MaxCharge then
				shootUp()
			end
		end
		if ui.powerHolder then
			ui.powerHolder.Visible = state.charging
			if state.charging then
				ui.powerFill.Size = UDim2.fromScale(state.charge / SH.MaxCharge, 1)
				local perfect = state.charge >= SH.PerfectFrom and state.charge <= SH.PerfectTo
				ui.powerFill.BackgroundColor3 = if state.charge > SH.OverFrom then C.Bad elseif perfect then C.Good else C.Yellow
			end
		end
		if ui.aim then
			if state.charging then
				local shot = Config.Shots[SHOTS[state.shot]]
				local ap = Ball.AimPoint(aimInput(), state.charge, shot.Lift)
				local spread = 1.2 + (11 - stat("Sut")) * 0.28 * shot.Error
				ui.aim.Size = Vector3.new(0.06, spread * 2, spread * 2)
				ui.aim.CFrame = CFrame.new(ap.X, math.min(ap.Y, TP.GoalHeight + 6), TP.GoalZ - 0.3) * CFrame.Angles(0, math.rad(90), 0)
				ui.aim.Transparency = 0.3
			elseif os.clock() > (ui.aimHold or 0) then
				ui.aim.Transparency = 1
			end
		end
	end

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
	local exit = Components.Button({
		Text = "Lobiye dön",
		Style = "Ghost",
		Size = UDim2.fromOffset(180, 44),
		TextSize = 16,
		OnClick = function()
			if matchApi then
				matchApi.Forfeit()
			else
				onExit()
			end
		end,
	})
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
		place(roundButton("Şut", 120, true, shootDown, shootUp), 0, 0)
		place(roundButton("Pas", 88, false, passDown, passUp), 132, 0)
		place(roundButton("Orta", 76, false, cross), 250, 220)
		place(roundButton("Top", 76, false, fetchBall), 340, 220)
		place(
			roundButton("Sprint", 88, false, function()
				state.sprintHeld = true
			end, function()
				state.sprintHeld = false
			end),
			232,
			0
		)
		place(roundButton("Çalım", 88, false, doDribble), 16, 132)
		place(roundButton("Zıpla", 88, false, doJump), 116, 104)
		place(roundButton("Müdahale", 88, false, doTackle), 216, 104)
		place(roundButton("Sevinç", 76, false, doCelebrate), 60, 232)
		place(roundButton("Blok", 76, false, doBlock), 150, 208)
	else
		-- Tuş ipuçları (sağ alt)
		local hp, hc = Components.Panel({
			Name = "Keys",
			Size = UDim2.fromOffset(340, 274),
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -20, 1, -20),
			Title = "Tuşlar",
		})
		hp.Parent = root
		ui.keysPanel = hp
		local lines = {
			{ "WASD", "Koş  ·  Shift: sprint" },
			{ "Sol tık", "Şut: basılı tut, yeşilde bırak" },
			{ "", "Top sende değilse: müdahale" },
			{ "Sağ tık", 'Pas  ·  topsuzken: "pas ver!"' },
			{ "Boşluk", "Çalım  ·  topsuzken: kafa" },
			{ "T", "Takım emri: atak / defans / pres" },
			{ "1 - 6", "Şut türü" },
			{ "B / G", "Orta aç  /  sevinç" },
			{ "N", "Topu getir (deneme sahası)" },
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
	-- Şut gücü barı (şut yuvalarının üstünde): sarı dolar, yeşil pencere mükemmel, kırmızı fazla
	local ph = Instance.new("Frame")
	ph.Name = "Power"
	ph.AnchorPoint = Vector2.new(0.5, 1)
	ph.Position = UDim2.new(0.5, 0, 1, -96)
	ph.Size = UDim2.fromOffset(460, 22)
	ph.BackgroundColor3 = C.Ground
	ph.BackgroundTransparency = 0.15
	ph.BorderSizePixel = 0
	ph.Visible = false
	ph.ClipsDescendants = true
	Components.Corner(ph, 6)
	Components.Stroke(ph, C.Yellow, 1.5, 0.3)
	ph.Parent = root
	local function zone(from: number, to: number, color: Color3, tr: number)
		local z = Instance.new("Frame")
		z.BorderSizePixel = 0
		z.BackgroundColor3 = color
		z.BackgroundTransparency = tr
		z.Position = UDim2.fromScale(from / SH.MaxCharge, 0)
		z.Size = UDim2.fromScale((to - from) / SH.MaxCharge, 1)
		z.Parent = ph
	end
	zone(SH.PerfectFrom, SH.PerfectTo, C.Good, 0.45)
	zone(SH.OverFrom, SH.MaxCharge, C.Bad, 0.6)
	local pf = Instance.new("Frame")
	pf.BorderSizePixel = 0
	pf.BackgroundColor3 = C.Yellow
	pf.BackgroundTransparency = 0.1
	pf.Size = UDim2.fromScale(0, 1)
	pf.Parent = ph
	ui.powerHolder, ui.powerFill = ph, pf

	-- Gol sayacı (üst orta)
	local gp, gc = Components.Panel({
		Name = "Goals",
		Size = UDim2.fromOffset(200, 60),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 20),
		Accent = false,
	})
	gp.Parent = root
	ui.goalsPanel = gp
	local gl = Components.Label({
		Text = "Gol",
		Size = 12,
		Color = C.Muted,
		Font = Theme.Font.Title,
		Upper = true,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.new(1, 0, 0, 14),
	})
	gl.Parent = gc
	ui.goals = Components.Label({
		Text = "0",
		Size = 26,
		Font = Theme.Font.Number,
		Color = C.Yellow,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.new(1, 0, 0, 28),
	})
	ui.goals.Position = UDim2.fromOffset(0, 12)
	ui.goals.Parent = gc

	-- Sahadaki işaretler: nişan halkası ve düşüş halkası
	local function marker(color: Color3)
		local m = Instance.new("Part")
		m.Shape = Enum.PartType.Cylinder
		m.Anchored = true
		m.CanCollide = false
		m.CanQuery = false
		m.Material = Enum.Material.Neon
		m.Color = color
		m.Transparency = 1
		m.Size = Vector3.new(0.06, 3, 3)
		m.Parent = Workspace
		return m
	end
	ui.aim = marker(C.Yellow)
	ui.landRing = marker(C.Yellow)

	-- Kombo sayacı (gol sayacının sağında)
	ui.combo = Components.Label({ Text = "", Size = 26, Font = Theme.Font.Display, Color = C.Gold, Frame = UDim2.fromOffset(220, 32) })
	ui.combo.Position = UDim2.new(0.5, 116, 0, 34)
	Components.Stroke(ui.combo, C.Navy, 3, 0).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ui.combo.Parent = root

	-- Çalışma modu (gol sayacının altında)
	local modes = Forms.Chips({
		Options = { { Id = "Hucum", Text = "Hücum çalışması" }, { Id = "Savunma", Text = "Savunma çalışması" } },
		Value = "Hucum",
		OnChange = function(id)
			state.yellow = false
			setCombo(0)
			Bots.Start(id)
			if id == "Hucum" and state.hrp then
				Ball.Reset(state.hrp.Position + state.hrp.CFrame.LookVector * 6)
			end
			banner(if id == "Hucum" then "Savunmayı geç, gol at" else "Rakibi durdur, topu al")
		end,
	})
	modes.Frame.AnchorPoint = Vector2.new(0.5, 0)
	modes.Frame.Position = UDim2.new(0.5, 0, 0, 88)
	modes.Frame.Size = UDim2.fromOffset(400, 34)
	modes.Frame.Parent = root
	ui.modesFrame = modes.Frame
	local ml = modes.Frame:FindFirstChildOfClass("UIListLayout")
	if ml then
		ml.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end

	-- Turbo parlaması
	local aura = Instance.new("Highlight")
	aura.FillColor = C.Yellow
	aura.FillTransparency = 0.75
	aura.OutlineColor = C.Yellow
	aura.OutlineTransparency = 0
	ui.aura = aura
	paintShots()
end

-- Gol, direk ve aut tepkileri
local function bindBall()
	local function back(delay: number)
		task.delay(delay, function()
			local hrp = state.hrp
			if hrp and state.hud then
				Ball.Reset(hrp.Position + hrp.CFrame.LookVector * 5)
			end
		end)
	end
	Ball.On("goal", function(kind)
		if matchApi then
			return -- maçta golü MatchController yönetir
		end
		state.goals += 1
		if ui.goals then
			ui.goals.Text = tostring(state.goals)
			UIMotion.Pop(ui.goals, 1.6)
		end
		local head = kind == "Header" or kind == "UcanKafa"
		banner(if head then "Kafa golü!" elseif kind == "Rovesata" then "Röveşata golü!" else "Gol!", C.Gold)
		shake(1.2)
		UIMotion.Sound("RewardSound")
		-- konfeti
		local burst = Instance.new("Part")
		burst.Anchored = true
		burst.CanCollide = false
		burst.Transparency = 1
		burst.Size = Vector3.new(TP.GoalHalfWidth * 2, 1, 1)
		burst.CFrame = CFrame.new(0, TP.GoalHeight + 2, TP.GoalZ - 2)
		burst.Parent = Workspace
		for _, col in ipairs({ C.Yellow, C.Navy, C.White }) do
			local e = Instance.new("ParticleEmitter")
			e.Enabled = false
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(col)
			e.Size = NumberSequence.new(0.6)
			e.Lifetime = NumberRange.new(1.2, 2.2)
			e.Speed = NumberRange.new(14, 30)
			e.SpreadAngle = Vector2.new(70, 70)
			e.Acceleration = Vector3.new(0, -26, 0)
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-200, 200)
			e.EmissionDirection = Enum.NormalId.Top
			e.Parent = burst
			e:Emit(40)
		end
		task.delay(3, function()
			burst:Destroy()
		end)
		-- file dalgalanması
		local studio = Workspace:FindFirstChild("FK_Studio")
		if studio then
			for _, d in ipairs(studio:GetChildren()) do
				if d.Name == "Net" and d:IsA("BasePart") then
					d.Transparency = 0.15
					TweenService:Create(d, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 0.6 })
						:Play()
				end
			end
		end
		Remotes.Get("TrainingGoal"):FireServer(kind)
		if state.animator and not state.animator:IsBusy() then
			state.animator:Play("Sevinc")
		end
		back(2.4)
	end)
	Ball.On("post", function()
		banner("Direk!", C.White)
		shake(0.8)
		UIMotion.Sound("ErrorSound")
	end)
	Ball.On("out", function()
		if matchApi then
			return
		end
		banner("Aut", C.Muted)
		if Bots.Mode() == "Hucum" then
			back(1.4)
		end
	end)
	Bots.On("steal", function()
		setCombo(0)
		banner("Top kaptırdın", C.Bad)
		UIMotion.Sound("ErrorSound")
		back(2.2)
	end)
	Bots.On("save", function(kind)
		banner(
			if kind == "fumble" then "Kaleci elinden kaçırdı!" elseif kind == "catch" then "Kaleci tuttu" else "Kaleci çeldi!",
			C.White
		)
		shake(0.5)
	end)
	Bots.On("escape", function()
		banner("Rakip kaçtı", C.Bad)
		UIMotion.Sound("ErrorSound")
	end)
	Bots.On("telegraph", function()
		UIMotion.Sound("ClickSound") -- müdahale geliyor: şimdi çalım at
	end)
end

-- Telefonda Roblox'un kendi zıplama butonunu gizle (zıplama "Zıpla" butonuyla yapılır)
local function hideDefaultJump()
	task.spawn(function()
		local pg = player:WaitForChild("PlayerGui")
		local touch = pg:WaitForChild("TouchGui", 15)
		local frame = touch and touch:WaitForChild("TouchControlFrame", 10)
		local jump = frame and frame:WaitForChild("JumpButton", 10)
		if jump and jump:IsA("GuiObject") then
			jump.Visible = false
			jump:GetPropertyChangedSignal("Visible"):Connect(function()
				if jump.Visible then
					jump.Visible = false
				end
			end)
		end
	end)
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
			Ball.Init()
			if not matchApi then
				banner("Deneme sahası")
				Bots.Start("Hucum")
			end
			local hrp = state.hrp
			if hrp and not matchApi then
				Ball.Reset(hrp.Position + hrp.CFrame.LookVector * 6)
			end
			-- yalnızca deneme sahasına ait parçalar maçta gizlenir
			for _, key in ipairs({ "goalsPanel", "modesFrame", "keysPanel" }) do
				if ui[key] then
					ui[key].Visible = matchApi == nil
				end
			end
		end
		if not visible then
			Bots.Clear()
		end
		for _, key in ipairs({ "aim", "landRing" }) do
			if ui[key] and not visible then
				ui[key].Transparency = 1
			end
		end
		local ballPart = Workspace:FindFirstChild("FK_Ball")
		if ballPart and ballPart:IsA("BasePart") then
			ballPart.Transparency = if visible then 0 else 1
		end
	end
end

-- Maç kancaları: api = { Update, Feint, Tackle, HumanSave, OnHumanKick, Forfeit } ya da nil (deneme sahası)
function Controller.SetMatch(api: any, pitch: any)
	matchApi = api
	TP = pitch or Config.TestPitch
	setCombo(0)
	state.yellow = false
	if api then
		Bots.Clear()
	end
end

-- Anlık durum (sınama ve kayıt araçları için)
function Controller.Debug()
	return {
		action = state.animator and state.animator:Current() or "",
		speed = state.speed,
		stamina = state.stamina,
		charge = if state.charging then state.charge else 0,
	}
end

-- Dışarıdan eylem oynatma (gol sevinci, üzülme)
function Controller.PlayAction(name: string)
	if state.animator then
		state.animator:Play(name)
	end
end

function Controller.Start(gui: ScreenGui, getData: () -> any, onExit: () -> ())
	state.getData = getData
	buildHud(gui, onExit)
	bindBall()
	if UserInputService.TouchEnabled then
		hideDefaultJump()
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Config.Keys.Sprint or input.KeyCode == Enum.KeyCode.ButtonR2 then
			state.sprintHeld = true
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			return primaryDown()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			-- sağ tık: kısa dokunuş pas sayılır; basılı sürükleme kamerayı çevirmeye devam eder
			state.rmb = { at = os.clock(), pos = input.Position }
			return
		end
		local idx = table.find(NUMBER_KEYS, input.KeyCode)
		if idx and state.hud then
			return selectShot(idx)
		end
		if input.KeyCode == Enum.KeyCode.Z then
			state.lastMirror = true
		elseif input.KeyCode == Enum.KeyCode.X then
			state.lastMirror = false
		end
		local fn = KEYMAP[input.KeyCode]
		if fn then
			fn()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Config.Keys.Sprint or input.KeyCode == Enum.KeyCode.ButtonR2 then
			state.sprintHeld = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			primaryUp()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			local r = state.rmb
			state.rmb = nil
			if r and os.clock() - r.at < 0.3 then
				local moved = if r.pos and input.Position then (input.Position - r.pos).Magnitude else 0
				if moved < 12 then
					secondary()
				end
			end
		elseif input.KeyCode == Config.Keys.Shoot then
			shootUp()
		elseif input.KeyCode == Config.Keys.Pass then
			passUp()
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

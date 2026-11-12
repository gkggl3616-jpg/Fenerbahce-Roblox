--[[
	MatchController
	Maçın akışı ve arayüzü:
	VS ekranı > başlama vuruşu > ilk yarı > devre arası > ikinci yarı > maç sonu > ödüller.
	- Skor tabelası, dakika, radar, olay bildirimleri.
	- Gol: kutlama, konfeti, santra. Taç, korner ve aut kısa bir duraklamayla yeniden başlar.
	- Maç sonunda sonuç sunucuya gönderilir; ödül, kulüp kasası ve lig puanı oradan gelir.
	Oyuncunun kendi kontrolü PlayerController'dadır; bu modül ona maç kancalarını verir.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
-- Stat modülü isteğe bağlıdır: yoksa maç sade sahada oynanır
local stadiumModule = ReplicatedStorage.Shared:FindFirstChild("Stadium")
local Stadium = if stadiumModule
	then require(stadiumModule) :: any
	else { Build = function() end, Clear = function() end, Cheer = function() end, Score = function() end, Screen = function() end }
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.UI.Theme)
local UIMotion = require(ReplicatedStorage.UI.UIMotion)
local Components = require(ReplicatedStorage.UI.Components)
local Ball = require(script.Parent.Ball)
local MatchAI = require(script.Parent.MatchAI)
local Referee = require(script.Parent.Referee)
local PlayerController = require(script.Parent.Parent.Controllers.PlayerController)

local P = Config.MatchPitch
local MC = Config.Match
local C = Theme.Color
local player = Players.LocalPlayer

local MatchController = {}

local M: any = nil -- süren maçın durumu
local ui: { [string]: any } = {}
local MID_Z = (P.MinZ + P.MaxZ) / 2

local function hrp(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function teleport(pos: Vector3, lookAt: Vector3)
	local h = hrp()
	if h then
		h.AssemblyLinearVelocity = Vector3.zero
		h.CFrame = CFrame.lookAt(pos + Vector3.new(0, 4, 0), Vector3.new(lookAt.X, pos.Y + 4, lookAt.Z))
	end
end

--------------------------------------------------------------------------------
-- Arayüz
--------------------------------------------------------------------------------
local function big(text: string, color: Color3, hold: number?)
	local l = ui.big
	if not l then
		return
	end
	l.Text = Theme.Upper(text)
	l.TextColor3 = color
	l.TextTransparency = 0
	ui.bigStroke.Transparency = 0
	UIMotion.Pop(l, 0.4)
	ui.bigToken = (ui.bigToken or 0) + 1
	local token = ui.bigToken
	task.delay(hold or 1.6, function()
		if ui.bigToken == token then
			UIMotion.Tween(l, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { TextTransparency = 1 })
			UIMotion.Tween(ui.bigStroke, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Transparency = 1 })
		end
	end)
end

local function setScore(pulse: boolean?)
	if ui.score then
		ui.score.Text = M.home .. " - " .. M.away
		if pulse then
			UIMotion.Pop(ui.score, 1.8)
			UIMotion.Shine(ui.board)
		end
	end
end

local function buildHud(gui: ScreenGui)
	local root = Instance.new("Frame")
	root.Name = "MatchHud"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	ui.root = root

	-- Skor tabelası (üst orta)
	local board = Instance.new("CanvasGroup")
	board.Name = "Scoreboard"
	board.AnchorPoint = Vector2.new(0.5, 0)
	board.Position = UDim2.new(0.5, 0, 0, 18)
	board.Size = UDim2.fromOffset(520, 58)
	board.BackgroundColor3 = C.Navy
	board.BackgroundTransparency = 0.06
	board.BorderSizePixel = 0
	Components.Corner(board, Theme.Corner.Medium)
	Components.Stroke(board, C.Yellow, Theme.Stroke, 0.35)
	board.Parent = root
	ui.board = board
	local homeBg = Instance.new("Frame")
	homeBg.BackgroundColor3 = C.Yellow
	homeBg.BorderSizePixel = 0
	homeBg.Size = UDim2.new(0, 170, 1, 0)
	homeBg.Parent = board
	local homeName = Components.Label({
		Text = M.homeName,
		Size = 20,
		Font = Theme.Font.Display,
		Color = C.Navy,
		Upper = true,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.new(0, 170, 1, 0),
	})
	homeName.Parent = board
	ui.score = Components.Label({
		Text = "0 - 0",
		Size = 32,
		Font = Theme.Font.Number,
		Color = C.White,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.new(0, 110, 1, 0),
	})
	ui.score.Position = UDim2.fromOffset(170, 0)
	ui.score.Parent = board
	local awayName = Components.Label({
		Text = M.awayName,
		Size = 20,
		Font = Theme.Font.Display,
		Upper = true,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.new(0, 150, 1, 0),
	})
	awayName.Position = UDim2.fromOffset(280, 0)
	awayName.Parent = board
	local sep = Instance.new("Frame")
	sep.BackgroundColor3 = C.White
	sep.BackgroundTransparency = 0.8
	sep.BorderSizePixel = 0
	sep.Position = UDim2.fromOffset(430, 10)
	sep.Size = UDim2.new(0, 1, 1, -20)
	sep.Parent = board
	ui.clock = Components.Label({
		Text = "0'",
		Size = 22,
		Font = Theme.Font.Number,
		Color = C.Yellow,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.new(0, 88, 1, 0),
	})
	ui.clock.Position = UDim2.fromOffset(432, 0)
	ui.clock.Parent = board

	-- Radar (sol üst, oyuncu kartının altında)
	local radar = Instance.new("CanvasGroup")
	radar.Name = "Radar"
	radar.Position = UDim2.fromOffset(20, 140)
	radar.Size = UDim2.fromOffset(150, 228)
	radar.BackgroundColor3 = Color3.fromRGB(31, 110, 56)
	radar.BackgroundTransparency = 0.15
	radar.BorderSizePixel = 0
	Components.Corner(radar, Theme.Corner.Small)
	Components.Stroke(radar, C.White, 1.5, 0.4)
	radar.Parent = root
	local half = Instance.new("Frame")
	half.BackgroundColor3 = C.White
	half.BackgroundTransparency = 0.5
	half.BorderSizePixel = 0
	half.Position = UDim2.fromScale(0, 0.5)
	half.Size = UDim2.new(1, 0, 0, 1)
	half.Parent = radar
	ui.radar = radar
	ui.dots = {}
	local function dot(color: Color3, size: number)
		local d = Instance.new("Frame")
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Size = UDim2.fromOffset(size, size)
		d.BackgroundColor3 = color
		d.BorderSizePixel = 0
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(1, 0)
		cr.Parent = d
		d.Parent = radar
		return d
	end
	for i = 1, 21 do
		ui.dots[i] = dot(C.White, 7)
	end
	ui.meDot = dot(C.Yellow, 10)
	Components.Stroke(ui.meDot, C.White, 2, 0)
	ui.ballDot = dot(C.White, 5)

	-- Büyük yazı (gol, devre arası)
	local l = Components.Label({
		Text = "",
		Size = 84,
		Font = Theme.Font.Display,
		Color = C.Gold,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.new(1, 0, 0, 96),
	})
	l.Position = UDim2.fromScale(0, 0.3)
	l.TextTransparency = 1
	ui.bigStroke = Components.Stroke(l, C.Navy, 5, 1)
	ui.bigStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	l.ZIndex = 30
	l.Parent = root
	ui.big = l

	UIMotion.In(board, Vector2.new(0, -40), 0.1)
	UIMotion.In(radar, Vector2.new(-40, 0), 0.2)
end

-- Radar: saha kuşbakışı; yukarısı rakip kale
local function radarPos(x: number, z: number): UDim2
	return UDim2.fromScale(math.clamp((P.MaxX - x) / (P.MaxX - P.MinX), 0, 1), math.clamp((P.MaxZ - z) / (P.MaxZ - P.MinZ), 0, 1))
end

local function updateRadar()
	if not ui.dots then
		return
	end
	local list = MatchAI.Positions()
	for i, d in ipairs(ui.dots) do
		local b = list[i]
		d.Visible = b ~= nil
		if b then
			d.Position = radarPos(b[1], b[2])
			d.BackgroundColor3 = if b[3] == "home" then C.Yellow else C.Bad
		end
	end
	local h = hrp()
	if h then
		ui.meDot.Position = radarPos(h.Position.X, h.Position.Z)
	end
	local bp = Ball.Position()
	ui.ballDot.Position = radarPos(bp.X, bp.Z)
end

local function confetti(z: number)
	local burst = Instance.new("Part")
	burst.Anchored = true
	burst.CanCollide = false
	burst.Transparency = 1
	burst.Size = Vector3.new(P.GoalHalfWidth * 2, 1, 1)
	burst.CFrame = CFrame.new(0, P.GoalHeight + 2, z)
	burst.Parent = Workspace
	for _, col in ipairs({ C.Yellow, C.Navy, C.White }) do
		local e = Instance.new("ParticleEmitter")
		e.Enabled = false
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(col)
		e.Size = NumberSequence.new(0.7)
		e.Lifetime = NumberRange.new(1.4, 2.6)
		e.Speed = NumberRange.new(16, 34)
		e.SpreadAngle = Vector2.new(75, 75)
		e.Acceleration = Vector3.new(0, -26, 0)
		e.RotSpeed = NumberRange.new(-200, 200)
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = burst
		e:Emit(60)
	end
	task.delay(3.5, function()
		burst:Destroy()
	end)
	local pitch = Workspace:FindFirstChild("FK_MatchPitch")
	if pitch then
		for _, d in ipairs(pitch:GetChildren()) do
			if d.Name == "Net" and d:IsA("BasePart") and math.abs(d.Position.Z - z) < 8 then
				d.Transparency = 0.15
				TweenService:Create(d, TweenInfo.new(0.8), { Transparency = 0.6 }):Play()
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Yeniden başlatmalar
--------------------------------------------------------------------------------
local function kickoff(team: string)
	MatchAI.ResetPositions()
	local start = MatchAI.HumanStart()
	teleport(start, Vector3.new(start.X, 0, P.MaxZ))
	Ball.Reset(Vector3.new(0, 0, MID_Z + (if team == "home" then -2 else 2)))
	Ball.LastTeam = team
	MatchAI.Freeze(MC.RestartPause)
	M.phase = "play"
	Referee.Whistle("short")
end

-- Top dışarı çıktı
local function onDead(kind: string, pos: Vector3)
	if not M or M.phase ~= "play" then
		return
	end
	local last = Ball.LastTeam
	local other = if last == "home" then "away" else "home"
	M.phase = "restart"
	local label, action
	if kind == "side" then
		label = "Taç"
		local x = math.clamp(pos.X, P.MinX + 2, P.MaxX - 2)
		local z = math.clamp(pos.Z, P.MinZ + 4, P.MaxZ - 4)
		action = function()
			Ball.Reset(Vector3.new(x, 0, z))
			Ball.LastTeam = other
		end
	else
		local front = kind == "endFront" -- rakip kale çizgisi
		local attackers = if front then "home" else "away"
		if last == attackers then
			label = "Aut"
			action = function()
				-- kale vuruşu: kaleci uzun vurur
				local d = if front then -1 else 1
				Ball.Reset(Vector3.new(0, 0, (if front then P.MaxZ else P.MinZ) + d * 16))
				Ball.LastTeam = other
				Ball.Kick(Vector3.new((math.random() - 0.5) * 50, 34, d * 70), 0, "Clear")
			end
		else
			label = "Korner"
			action = function()
				-- korner: köşeden ceza sahasına orta
				local side = if pos.X >= 0 then 1 else -1
				local z = if front then P.MaxZ else P.MinZ
				local d = if front then -1 else 1
				local target = Vector3.new((math.random() - 0.5) * 20, 3, z + d * (22 + math.random() * 10))
				local h = hrp()
				if front and h and M.position ~= "Kaleci" then
					-- bizim kornerimiz: orta oyuncunun önüne gelir (kafa şansı)
					target = Vector3.new(math.clamp(h.Position.X, -40, 40), 3, math.clamp(h.Position.Z, z - 50, z - 14))
				end
				Ball.LastTeam = attackers
				Ball.Cross(Vector3.new(side * (P.MaxX - 1), 0, z + d * 1), target, 1.7)
			end
		end
	end
	big(label, C.White, 1)
	MatchAI.Freeze(MC.RestartPause)
	task.delay(MC.RestartPause * 0.75, function()
		if M and M.phase == "restart" then
			action()
			M.phase = "play"
		end
	end)
end

local function onGoal(kind: string, side: string)
	if not M or M.phase ~= "play" then
		return
	end
	M.phase = "goal"
	local scorer = Ball.LastTeam
	Stadium.Cheer()
	task.defer(function()
		if M then
			Stadium.Score(M.homeName, M.awayName, M.home, M.away, M.minute)
			Stadium.Screen("GOL!", (if side == "front" then M.homeName else M.awayName) .. "  " .. tostring(M.minute) .. "'", nil, 6)
		end
	end)
	-- kendi kalemize giren top rakibin, rakip kaleye giren bizim golümüzdür
	local team = if side == "front" then "home" else "away"
	if team == "home" then
		M.home += 1
		if scorer == "home" and M.lastHumanKick and os.clock() - M.lastHumanKick < 6 then
			M.myGoals += 1
			if kind == "Header" or kind == "UcanKafa" then
				M.myHeaderGoals += 1
			end
			big(
				if kind == "Header" or kind == "UcanKafa" then "Kafa golü!" elseif kind == "Rovesata" then "Röveşata golü!" else "Gol!",
				C.Gold,
				2.4
			)
			PlayerController.PlayAction("DizKaymasi")
		else
			big("Gol!", C.Gold, 2.4)
			PlayerController.PlayAction("Sevinc")
		end
		UIMotion.Sound("RewardSound")
		confetti(P.GoalZ - 2)
	else
		M.away += 1
		big("Rakip gol attı", C.Bad, 2.2)
		UIMotion.Sound("ErrorSound")
		PlayerController.PlayAction("Uzulme")
	end
	setScore(true)
	Components.Toast(
		if team == "home" then "unlock" else "error",
		M.minute .. "' Gol: " .. (if team == "home" then M.homeName else M.awayName)
	)
	MatchAI.Freeze(MC.GoalPause)
	task.delay(MC.GoalPause, function()
		if M and M.phase == "goal" then
			UIMotion.Wipe(function()
				if M then
					kickoff(if team == "home" then "away" else "home")
				end
			end)
		end
	end)
end

--------------------------------------------------------------------------------
-- Maç sonu
--------------------------------------------------------------------------------
local function resultScreen(gui: ScreenGui, result, onClose: () -> ())
	local s = MatchAI.Stats()
	local dim = Instance.new("Frame")
	dim.BackgroundColor3 = C.Ground
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 60
	dim.Parent = gui
	UIMotion.Tween(dim, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundTransparency = 0.3 })
	local win, draw = M.home > M.away, M.home == M.away
	local panel, content = Components.Panel({
		Name = "Result",
		Size = UDim2.fromOffset(640, 500),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Gold = win,
	})
	panel.ZIndex = 61
	panel.Parent = dim
	local title = Components.Label({
		Text = if win then "Galibiyet" elseif draw then "Beraberlik" else "Mağlubiyet",
		Size = 46,
		Font = Theme.Font.Display,
		Color = if win then C.Gold elseif draw then C.White else C.Bad,
		Upper = true,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.new(1, 0, 0, 52),
	})
	title.Parent = content
	local sc = Components.Label({
		Text = M.homeName .. "  " .. M.home .. " - " .. M.away .. "  " .. M.awayName,
		Size = 22,
		Font = Theme.Font.Title,
		Upper = true,
		Align = Enum.TextXAlignment.Center,
		Frame = UDim2.new(1, 0, 0, 28),
	})
	sc.Position = UDim2.fromOffset(0, 54)
	sc.Parent = content

	-- karşılaştırmalı istatistik çubukları (sırayla dolar)
	local totalPos = math.max(1, s.possession.home + s.possession.away)
	local rows = {
		{ "Şut", s.shots.home, s.shots.away },
		{ "Topa sahip olma %", math.floor(s.possession.home / totalPos * 100 + 0.5), math.floor(s.possession.away / totalPos * 100 + 0.5) },
		{ "Senin golün", M.myGoals, 0 },
	}
	for i, r in ipairs(rows) do
		local y = 100 + (i - 1) * 46
		local name = Components.Label({
			Text = r[1],
			Size = 14,
			Color = C.Muted,
			Upper = true,
			Align = Enum.TextXAlignment.Center,
			Frame = UDim2.new(1, 0, 0, 18),
		})
		name.Position = UDim2.fromOffset(0, y)
		name.Parent = content
		local total = math.max(1, r[2] + r[3])
		local lv = Components.Label({
			Text = tostring(r[2]),
			Size = 20,
			Font = Theme.Font.Number,
			Color = C.Yellow,
			Frame = UDim2.fromOffset(60, 22),
		})
		lv.Position = UDim2.fromOffset(0, y + 16)
		lv.Parent = content
		local rv = Components.Label({
			Text = tostring(r[3]),
			Size = 20,
			Font = Theme.Font.Number,
			Color = C.Bad,
			Align = Enum.TextXAlignment.Right,
			Frame = UDim2.fromOffset(60, 22),
		})
		rv.AnchorPoint = Vector2.new(1, 0)
		rv.Position = UDim2.new(1, 0, 0, y + 16)
		rv.Parent = content
		local lb = Components.Bar({ Size = UDim2.new(0.5, -70, 0, 10), Color = C.Yellow })
		lb.Frame.Position = UDim2.new(0, 64, 0, y + 22)
		lb.Frame.Parent = content
		local rb = Components.Bar({ Size = UDim2.new(0.5, -70, 0, 10), Color = C.Bad })
		rb.Frame.Position = UDim2.new(0.5, 6, 0, y + 22)
		rb.Frame.Parent = content
		task.delay(0.5 + i * 0.18, function()
			lb.Set(r[2] / total)
			rb.Set(r[3] / total)
		end)
	end

	-- ödüller
	local rewardY = 250
	local line = Instance.new("Frame")
	line.BackgroundColor3 = C.Yellow
	line.BackgroundTransparency = 0.6
	line.BorderSizePixel = 0
	line.Position = UDim2.fromOffset(0, rewardY - 8)
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Parent = content
	local function reward(label: string, value: number, x: number, color: Color3)
		local cap = Components.Label({
			Text = label,
			Size = 13,
			Color = C.Muted,
			Upper = true,
			Align = Enum.TextXAlignment.Center,
			Frame = UDim2.new(1 / 3, 0, 0, 18),
		})
		cap.Position = UDim2.new(x, 0, 0, rewardY)
		cap.Parent = content
		local v = Components.Label({
			Text = "0",
			Size = 34,
			Font = Theme.Font.Number,
			Color = color,
			Align = Enum.TextXAlignment.Center,
			Frame = UDim2.new(1 / 3, 0, 0, 40),
		})
		v.Position = UDim2.new(x, 0, 0, rewardY + 18)
		v.Parent = content
		task.delay(1.3, function()
			UIMotion.CountUp(v, 0, value, function(n)
				return "+" .. Theme.FormatNumber(n)
			end)
		end)
	end
	if result and result.ok then
		reward("Bakiye", result.coins, 0, C.Yellow)
		reward("XP", result.xp, 1 / 3, C.Good)
		reward("Kulüp kasası", result.income, 2 / 3, C.Gold)
		local season = if result.promoted
			then "Sezon bitti: LİG ATLADIN! Yeni lig: " .. Config.Tiers[result.tier].League
			elseif result.seasonOver then "Sezon bitti. Puan yetmedi, aynı ligde yeni sezon başlıyor."
			else "Sezon: "
				.. result.played
				.. " / "
				.. Config.Season.Matches
				.. " maç · "
				.. result.points
				.. " puan (lig atlamak için "
				.. MC.PromotePoints
				.. ")"
		local sl = Components.Label({
			Text = season,
			Size = 15,
			Color = if result.promoted then C.Gold else C.Text,
			Wrap = true,
			Align = Enum.TextXAlignment.Center,
			Frame = UDim2.new(1, 0, 0, 40),
		})
		sl.Position = UDim2.fromOffset(0, rewardY + 68)
		sl.Parent = content
	else
		local sl = Components.Label({
			Text = "Maç tamamlanmadığı için ödül verilmedi.",
			Size = 16,
			Color = C.Muted,
			Align = Enum.TextXAlignment.Center,
			Frame = UDim2.new(1, 0, 0, 40),
		})
		sl.Position = UDim2.fromOffset(0, rewardY + 20)
		sl.Parent = content
	end
	local btn = Components.Button({
		Text = "Lobiye dön",
		Style = "Primary",
		Size = UDim2.new(0.5, 0, 0, 56),
		OnClick = function()
			UIMotion.Wipe(function()
				dim:Destroy()
				onClose()
			end)
		end,
	})
	btn.AnchorPoint = Vector2.new(0.5, 1)
	btn.Position = UDim2.fromScale(0.5, 1)
	btn.Parent = content
	UIMotion.In(panel, Vector2.new(0, 40))
	UIMotion.Pop(panel, 0.92)
	if result and result.promoted then
		task.delay(1.6, function()
			Components.Toast("level", "Lig atladın! Yeni stadyum yakında.")
		end)
	end
end

local function finish(gui: ScreenGui, forfeit: boolean)
	if not M or M.phase == "over" then
		return
	end
	M.phase = "over"
	MatchAI.Freeze(999)
	big(if forfeit then "Maç bırakıldı" else "Maç bitti", C.White, 2)
	Referee.Whistle("long")
	local done = false
	local conn
	local function show(result)
		if done then
			return
		end
		done = true
		if conn then
			conn:Disconnect()
		end
		resultScreen(gui, result, function()
			local onDone = M.onDone
			PlayerController.SetMatch(nil, nil)
			PlayerController.SetHud(false)
			MatchAI.Clear()
			Referee.Clear()
			Stadium.Clear()
			Ball.SetPitch(Config.TestPitch)
			if ui.root then
				ui.root:Destroy()
			end
			ui = {}
			M = nil
			teleport(Vector3.new(0, 0, 4), Vector3.new(0, 0, 40))
			onDone()
		end)
	end
	conn = Remotes.Get("MatchResult").OnClientEvent:Connect(show)
	Remotes.Get("MatchEnd")
		:FireServer({ home = M.home, away = M.away, myGoals = M.myGoals, myHeaderGoals = M.myHeaderGoals, forfeit = forfeit })
	task.delay(4, function()
		show(nil) -- sunucu yanıt vermezse ekran yine açılır
	end)
end

--------------------------------------------------------------------------------
-- PlayerController kancaları
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Hakem kararları: faul, kart, serbest vuruş, penaltı
--------------------------------------------------------------------------------
local REASON = {
	careless = "Kontrolsüz müdahale",
	reckless = "Sert müdahale",
	violent = "Ciddi faullü oyun",
}

-- Ekranın üstünde karar kartı: kart rengi, oyuncu, sebep ve karar
local function decision(cardColor: Color3?, title: string, who: string, reason: string, verdict: string)
	if not ui.root then
		return
	end
	if ui.decision then
		ui.decision:Destroy()
	end
	local f = Instance.new("Frame")
	f.Name = "Decision"
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Position = UDim2.new(0.5, 0, 0, 150)
	f.Size = UDim2.fromOffset(560, 116)
	f.BackgroundColor3 = C.Navy
	f.BackgroundTransparency = 0.08
	f.BorderSizePixel = 0
	local u = Instance.new("UICorner")
	u.CornerRadius = UDim.new(0, 10)
	u.Parent = f
	local st = Instance.new("UIStroke")
	st.Color = cardColor or C.White
	st.Thickness = 2
	st.Parent = f
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(54, 76)
	card.Position = UDim2.fromOffset(22, 20)
	card.Rotation = -8
	card.BackgroundColor3 = cardColor or C.White
	card.BorderSizePixel = 0
	local cu = Instance.new("UICorner")
	cu.CornerRadius = UDim.new(0, 6)
	cu.Parent = card
	card.Parent = f
	if not cardColor then
		-- kartsız karar: düdük simgesi yerine "F" (faul)
		local l = Components.Label({
			Text = "F",
			Size = 40,
			Font = Theme.Font.Display,
			Color = C.Navy,
			Align = Enum.TextXAlignment.Center,
			Frame = UDim2.fromScale(1, 1),
		})
		l.Parent = card
	end
	local function line(text: string, size: number, color: Color3, y: number, font: Font)
		local l = Components.Label({ Text = text, Size = size, Font = font, Color = color, Frame = UDim2.new(1, -110, 0, size + 6) })
		l.Position = UDim2.fromOffset(98, y)
		l.Parent = f
	end
	line(Theme.Upper(title), 24, cardColor or C.White, 10, Theme.Font.Display)
	line(who, 17, C.Text, 42, Theme.Font.Title)
	line(reason, 14, C.Muted, 66, Theme.Font.Body)
	line("KARAR: " .. Theme.Upper(verdict), 14, C.Yellow, 88, Theme.Font.Title)
	f.Parent = ui.root
	ui.decision = f
	UIMotion.In(f, Vector2.new(0, -30))
	task.delay(3.4, function()
		if ui.decision == f then
			ui.decision = nil
			UIMotion.Out(f, Vector2.new(0, -20), true)
		end
	end)
end

--[[ Faul. by: faulü yapan takım, offender: { name, number, human?, bot? },
	severity: "careless" (kartsız) | "reckless" (sarı) | "violent" (kırmızı),
	victim: faul yapılan takım, pos: faulün yeri ]]
local function foul(by: string, offender, severity: string, victim: string, pos: Vector3, reason: string?)
	if not M or M.phase ~= "play" then
		return
	end
	M.phase = "restart"
	MatchAI.Freeze(4)
	Referee.Whistle("short")

	local key = by .. ":" .. tostring(offender.number)
	local card: string? = nil
	local why = reason or REASON[severity]
	if severity == "violent" then
		card = "red"
	elseif severity == "reckless" then
		if M.cards[key] == "yellow" then
			card = "red"
			why = why .. " · ikinci sarı kart"
		else
			card = "yellow"
		end
	end
	if card then
		M.cards[key] = card
	end
	-- Faul, yapanın kendi ceza sahasındaysa penaltı
	local ownGoalZ = if by == "home" then P.MinZ else P.MaxZ
	local inBox = math.abs(pos.X) <= 66 and math.abs(pos.Z - ownGoalZ) <= 54
	local verdict = if inBox then "Penaltı" else "Serbest vuruş"
	local club = if by == "home" then M.homeName else M.awayName
	local who = string.format("%d  %s  ·  %s", offender.number, offender.name, club)
	local color = if card == "red" then C.Bad elseif card == "yellow" then C.Yellow else nil
	local title = if card == "red" then "Kırmızı kart" elseif card == "yellow" then "Sarı kart" else "Faul"
	decision(color, title, who, why, verdict)
	Stadium.Screen(Theme.Upper(title), who .. "  ·  " .. why .. "  ·  " .. verdict, color, 6)
	if color then
		task.delay(0.6, function()
			Referee.Card(color)
		end)
	end
	UIMotion.Sound("ErrorSound")

	task.delay(3, function()
		if not M or M.phase ~= "restart" then
			return
		end
		if card == "red" then
			if offender.human then
				-- oyuncu atıldı: maç onun için biter
				Components.Toast("error", "Kırmızı kart gördün, oyundan atıldın.")
				finish(M.gui, true)
				return
			elseif offender.bot then
				MatchAI.SendOff(offender.bot)
			end
		end
		local d = if victim == "home" then 1 else -1 -- vuruşu kullanan takımın hücum yönü
		local spot = if inBox
			then Vector3.new(0, 0, ownGoalZ + (if by == "home" then 36 else -36))
			else Vector3.new(math.clamp(pos.X, P.MinX + 4, P.MaxX - 4), 0, math.clamp(pos.Z, P.MinZ + 6, P.MaxZ - 6))
		Ball.Reset(spot)
		Ball.LastTeam = victim
		local humanTakes = victim == "home" and M.position ~= "Kaleci"
		MatchAI.SetPiece(spot, victim, inBox, humanTakes)
		local h = hrp()
		if humanTakes then
			-- vuruşu sen kullanırsın: topun arkasına geç
			teleport(Vector3.new(spot.X, 0, spot.Z - d * 4.5), Vector3.new(0, 0, if d > 0 then P.MaxZ else P.MinZ))
			big(if inBox then "Penaltı: vuruş senin" else "Serbest vuruş: senin", C.Yellow, 1.6)
		elseif h and M.position ~= "Kaleci" then
			-- rakibin vuruşu: baraj mesafesine açıl (9,15 m)
			local away = Vector3.new(h.Position.X - spot.X, 0, h.Position.Z - spot.Z)
			if inBox then
				teleport(Vector3.new(30, 0, spot.Z - d * 34), spot)
			elseif away.Magnitude < 28 then
				local dir = if away.Magnitude > 0.5 then away.Unit else Vector3.new(0, 0, -d)
				teleport(Vector3.new(spot.X + dir.X * 28, 0, spot.Z + dir.Z * 28), spot)
			end
			big(verdict, C.White, 1.2)
		end
		MatchAI.Freeze(if humanTakes then 1.8 else 1)
		Referee.Whistle("short")
		M.phase = "play"
	end)
end

-- Oyuncunun müdahalesi: sonucu yapay zeka verir, cezayı hakem
local function humanTackle(pos: Vector3, look: Vector3, sliding: boolean): string
	local result = MatchAI.Tackle(pos, look, sliding)
	local f = MatchAI.LastFoul
	if M and f and (result == "foul" or result == "card") then
		local severity = if f.sliding and f.fromBehind then "violent" elseif f.sliding or f.fromBehind then "reckless" else "careless"
		local reason = if f.sliding and f.fromBehind
			then "Arkadan kayarak müdahale: ciddi faullü oyun"
			elseif f.fromBehind then "Arkadan müdahale"
			elseif f.sliding then "Topa değil, rakibe kayarak müdahale"
			else "Kontrolsüz müdahale"
		foul("home", M.me, severity, "away", f.pos, reason)
	end
	MatchAI.LastFoul = nil
	return result
end

local function update(dt: number, ctx)
	if not M then
		return
	end
	MatchAI.Update(dt, ctx)
	Referee.Update(dt, M.phase == "play")
	updateRadar()
	if M.phase == "play" then
		M.elapsed += dt
		local half = MC.HalfSeconds
		local total = math.min(M.elapsed, half) + (if M.half == 2 then half else 0)
		M.minute = math.min(90, math.floor(total / (half * 2) * 90))
		if ui.clock then
			ui.clock.Text = M.minute .. "'"
		end
		if M.elapsed >= half then
			if M.half == 1 then
				M.phase = "halftime"
				big("Devre arası", C.White, 2.2)
				Referee.Whistle("double")
				MatchAI.Freeze(3.2)
				task.delay(3, function()
					if M and M.phase == "halftime" then
						UIMotion.Wipe(function()
							if M then
								M.half = 2
								M.elapsed = 0
								kickoff("away")
								big("İkinci yarı", C.Yellow, 1.4)
							end
						end)
					end
				end)
			else
				finish(M.gui, false)
			end
		end
	end
end

--[[
	Maçı başlatır.
	gui: ScreenGui, data: oyuncu verisi, onDone: lobiye dönüldüğünde çağrılır
]]
function MatchController.Start(gui: ScreenGui, data, onDone: () -> (), fixture: any?)
	if M then
		return
	end
	local tier = Config.Tiers[data.club.tier]
	local avg = (tier.BotPower[1] + tier.BotPower[2]) / 2
	M = {
		gui = gui,
		onDone = onDone,
		phase = "intro",
		half = 1,
		elapsed = 0,
		minute = 0,
		home = 0,
		away = 0,
		myGoals = 0,
		myHeaderGoals = 0,
		lastHumanKick = nil,
		position = data.position,
		cards = {}, -- cards["home:9"] = "yellow" | "red"
		me = { name = data.name, number = data.number or 9, human = true },
		homeName = if fixture then fixture.home.club.Abbr elseif data.club.abbr ~= "" then data.club.abbr else "EV",
		awayName = if fixture then fixture.away.club.Abbr else "RKP",
	}
	Remotes.Get("MatchStart"):FireServer()
	Stadium.Build(if data.career and data.career.atFenerbahce then 6 else data.club.tier, {
		club = data.club.name,
		abbr = data.club.abbr,
		facilities = data.club.facilities,
	})
	Stadium.Score(M.homeName, M.awayName, 0, 0, 0)
	Ball.SetPitch(P)
	Ball.Init()
	MatchAI.Start({
		position = data.position,
		fixture = fixture,
		awaySkill = (avg - 28) / 70,
		homeSkill = (avg - 28) / 70 + 0.04 + ((data.power or 30) - avg) / 200,
	})
	PlayerController.SetMatch({
		Update = update,
		Feint = MatchAI.Feint,
		Tackle = humanTackle,
		HumanSave = MatchAI.HumanSave,
		OnHumanKick = function()
			if M then
				M.lastHumanKick = os.clock()
			end
		end,
		Forfeit = function()
			finish(gui, true)
		end,
	}, P)
	Referee.Spawn()
	PlayerController.SetHud(true)
	buildHud(gui)
	setScore(false)
	kickoff("home")
	M.phase = "intro"
	MatchAI.Freeze(MC.IntroTime)
	big(M.homeName .. "  vs  " .. M.awayName, C.Yellow, MC.IntroTime - 0.6)
	Components.Toast("info", tier.League .. " · " .. tier.Stadium)
	task.delay(MC.IntroTime, function()
		if M and M.phase == "intro" then
			M.phase = "play"
			big("Başla!", C.Good, 0.9)
		end
	end)
end

-- Sınamalar için: süren maçın durumu ve hakem kararı
function MatchController.Debug()
	return { state = M, foul = foul }
end

-- Bir kez bağlanır
Ball.On("goal", function(kind, side)
	if M then
		onGoal(kind, side)
	end
end)
Ball.On("dead", function(kind, pos)
	if M then
		onDead(kind, pos)
	end
end)
MatchAI.On("foul", function(bot, severity, victim, pos)
	if M then
		local info = bot.info
		foul(
			bot.team,
			{ name = if info then info.name else "Oyuncu", number = if info then info.number else bot.slot, bot = bot },
			severity,
			victim,
			pos
		)
	end
end)
MatchAI.On("steal", function()
	if M then
		Components.Toast("error", "Top kaptırdın")
	end
end)
MatchAI.On("save", function(team, kind)
	if M then
		big(
			if team == "home" then "Kalecimiz kurtardı" elseif kind == "fumble" then "Kaleci elinden kaçırdı!" else "Kaleci kurtardı",
			C.White,
			1
		)
	end
end)
MatchAI.On("telegraph", function()
	UIMotion.Sound("ClickSound")
end)

return MatchController

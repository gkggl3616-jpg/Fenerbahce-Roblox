--[[
	Bots
	Deneme sahasındaki yapay zekalı oyuncular. Maç tek oyunculu olduğu için istemcide çalışır.
	- Savunmacı: topun önünü keser (kademe), yaklaşınca müdahale hazırlığı yapar. Hazırlık sırasında
	  çalım yerse sendeler; yemezse topu kapar ve uzaklaştırır.
	- Kaleci: çizgide topu izler; şutta topun kaleye gireceği noktayı hesaplar, tepki süresi ve
	  plonjon hızına göre yetişir ya da yetişemez. Füze şutunda topu elinden kaçırabilir.
	- Hücumcu (savunma çalışması): topu sürerek kaçmaya çalışır; oyuncu müdahaleyle topu almalıdır.
	Botlar kodla canlandırılır (Animator) ve gövdeleriyle topu keser.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Animator = require(script.Parent.Parent.Anim.Animator)
local Ball = require(script.Parent.Ball)

local D = Config.Duel
local K = Config.Keeper
local T = Config.TestPitch
local C = Config.Colors

local Bots = {}

local list: { any } = {}
local mode = "Hucum"
local listeners = { steal = {}, save = {}, escape = {}, telegraph = {} }
local keeperPlan: any = nil
local respawnAt = 0
local clock = 0

local function fire(name: string, ...)
	for _, fn in ipairs(listeners[name]) do
		task.spawn(fn, ...)
	end
end
function Bots.On(name: string, fn)
	table.insert(listeners[name], fn)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function spawn(kind: string, role: string, home: Vector3, facing: Vector3)
	local folder = ReplicatedStorage:WaitForChild("FK_BotTemplates", 30)
	local tpl = folder and folder:FindFirstChild(kind)
	if not tpl then
		warn("[Bots] şablon yok: " .. kind)
		return nil
	end
	local model = tpl:Clone()
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = model:FindFirstChildOfClass("Humanoid")
	hrp.Anchored = true
	local offsetY = 3
	if hum then
		offsetY = hum.HipHeight + hrp.Size.Y / 2
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		pcall(function()
			hum.EvaluateStateMachine = false -- gövdeyi biz taşıyoruz
		end)
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	model.Parent = Workspace
	-- müdahale habercisi: botun altında beliren kırmızı halka
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = C.Bad
	ring.Transparency = 1
	ring.Size = Vector3.new(0.06, 6, 6)
	ring.Parent = model
	local bot = {
		kind = kind,
		role = role,
		model = model,
		hrp = hrp,
		animator = Animator.new(model),
		pos = Vector3.new(home.X, T.GroundY, home.Z),
		home = Vector3.new(home.X, T.GroundY, home.Z),
		dir = flat(facing).Unit,
		speed = 0,
		offsetY = offsetY,
		state = "hold",
		t = 0,
		cd = 0,
		ring = ring,
		touch = 0,
		fouled = false,
	}
	table.insert(list, bot)
	return bot
end

local function place(bot)
	bot.hrp.CFrame = CFrame.lookAt(bot.pos + Vector3.new(0, bot.offsetY, 0), bot.pos + Vector3.new(0, bot.offsetY, 0) + bot.dir)
	bot.ring.CFrame = CFrame.new(bot.pos + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

local function moveTo(bot, target: Vector3, speed: number, dt: number, faceTo: Vector3?)
	local to = flat(target - bot.pos)
	local dist = to.Magnitude
	local want = if dist > 0.4 then math.min(speed, dist / math.max(dt, 0.001)) else 0
	bot.speed += (want - bot.speed) * math.min(1, dt * 8)
	if dist > 0.05 then
		bot.pos += to.Unit * bot.speed * dt
	end
	local look = if faceTo then flat(faceTo - bot.pos) else to
	if look.Magnitude > 0.2 then
		bot.dir = bot.dir:Lerp(look.Unit, math.min(1, dt * 10))
		if bot.dir.Magnitude < 0.01 then
			bot.dir = look.Unit
		else
			bot.dir = bot.dir.Unit
		end
	end
end

function Bots.Clear()
	for _, bot in ipairs(list) do
		bot.animator:Destroy()
		bot.model:Destroy()
	end
	list = {}
	keeperPlan = nil
end

function Bots.Mode(): string
	return mode
end

-- "Hucum": iki savunmacı ve kaleciye karşı gol at. "Savunma": top süren hücumcuyu durdur.
function Bots.Start(newMode: string)
	Bots.Clear()
	mode = newMode
	if mode == "Hucum" then
		spawn("Rival", "defender", Vector3.new(-14, 0, T.GoalZ - 58), Vector3.new(0, 0, -1))
		spawn("Rival2", "defender", Vector3.new(16, 0, T.GoalZ - 40), Vector3.new(0, 0, -1))
		spawn("RivalKeeper", "keeper", Vector3.new(0, 0, T.GoalZ - 1.6), Vector3.new(0, 0, -1))
	else
		local a = spawn("RivalAttacker", "attacker", Vector3.new(math.random(-30, 30), 0, T.GoalZ - 40), Vector3.new(0, 0, -1))
		if a then
			Ball.Reset(a.pos + Vector3.new(0, 0, -3))
		end
	end
	for _, bot in ipairs(list) do
		place(bot)
	end
end

--------------------------------------------------------------------------------
-- Oyuncunun eylemleri
--------------------------------------------------------------------------------
-- Çalım: müdahale hazırlığındaki savunmacı menzildeyse sendeler. Dönüş: başarılı mı
function Bots.Feint(playerPos: Vector3): boolean
	local won = false
	for _, bot in ipairs(list) do
		if bot.role == "defender" and bot.state == "windup" and flat(bot.pos - playerPos).Magnitude < D.FeintRange then
			bot.state = "stagger"
			bot.t = D.StaggerTime
			bot.cd = D.TackleCooldown
			bot.ring.Transparency = 1
			bot.animator:Stop()
			bot.animator:Play("Stagger")
			won = true
		end
	end
	return won
end

-- Müdahale (savunma çalışması). Dönüş: "win" | "foul" | "card" | "miss"
function Bots.Tackle(playerPos: Vector3, look: Vector3, sliding: boolean): string
	local reach = if sliding then D.SlideReach else D.StandReach
	local ballPos = Ball.Position()
	local ballNear = flat(ballPos - playerPos).Magnitude <= reach and ballPos.Y < T.GroundY + 2.6
	for _, bot in ipairs(list) do
		if bot.role == "attacker" and bot.state ~= "down" then
			local toBot = flat(bot.pos - playerPos)
			if ballNear then
				Ball.Kick(flat(look).Unit * 20, 0, "Tackle")
				bot.state = "down"
				bot.t = 1.2
				bot.animator:Play("Stagger")
				respawnAt = clock + 2.6
				return "win"
			elseif toBot.Magnitude < (if sliding then D.FoulRange + 1.4 else D.FoulRange) then
				local fromBehind = bot.dir:Dot(flat(look).Unit) > 0.45
				bot.state = "down"
				bot.t = 1.4
				bot.animator:Play("Stagger")
				respawnAt = clock + 3
				return if fromBehind or sliding then "card" else "foul"
			end
		end
	end
	return "miss"
end

--------------------------------------------------------------------------------
-- Kaleci
--------------------------------------------------------------------------------
local function keeper()
	for _, bot in ipairs(list) do
		if bot.role == "keeper" then
			return bot
		end
	end
	return nil
end

-- Şut atıldığında kaleci kararını verir
Ball.On("kick", function(kind, v)
	local k = keeper()
	if not k or v.Z < K.MinShotSpeed * 0.6 or v.Magnitude < K.MinShotSpeed then
		return
	end
	local line = T.GoalZ - 1.2
	local p, t = Ball.PredictCross(line)
	if not p or not t then
		return
	end
	local w, h = T.GoalHalfWidth, T.GoalHeight
	if math.abs(p.X) > w + 1.5 or p.Y > h + 1.5 then
		keeperPlan = nil -- kaleyi bulmuyor, kıpırdamaz
		return
	end
	local hands = Vector3.new(k.pos.X, T.GroundY + 3.4, line)
	local need = (Vector3.new(p.X, p.Y, line) - hands).Magnitude
	local can = K.BaseReach + math.max(0, t - K.Reaction) * K.DiveSpeed
	local reach = need <= can and math.random() > K.ErrorChance
	keeperPlan = {
		point = p,
		time = t,
		at = clock + t,
		save = reach,
		fumble = reach and kind == "Fuze" and math.random() < K.FumbleChance,
		side = if p.X >= k.pos.X then 1 else -1,
		dive = need > 2.6,
		started = false,
		done = false,
		kind = kind,
	}
end)

local function updateKeeper(k, dt: number)
	local plan = keeperPlan
	local ballPos = Ball.Position()
	if plan and not plan.done then
		local remain = plan.at - clock
		-- plonjon, topun gelişine yetişecek şekilde başlar (animasyonun kurtarış anı 0,30 sn)
		if not plan.started and remain <= math.max(0.3, plan.time - K.Reaction) and remain <= 0.34 + 0.2 then
			plan.started = true
			if plan.dive then
				-- kaleci -Z'ye bakar; sağı dünya +X yönüdür
				k.animator:Play("Plonjon", { Mirror = plan.side < 0 })
			else
				k.animator:Play("Blok")
			end
		end
		if ballPos.Z >= T.GoalZ - 1.5 or remain <= 0 then
			plan.done = true
			if plan.save and not Ball.InNet() then
				local v = Ball.Velocity()
				if plan.fumble then
					-- elinden kaçırdı: top yavaşlayıp önüne düşer
					Ball.Deflect(Vector3.new((math.random() - 0.5) * 20, 10, -math.abs(v.Z) * 0.18))
					fire("save", "fumble")
				elseif plan.dive then
					Ball.Deflect(Vector3.new(plan.side * (18 + math.random() * 14), 10 + math.random() * 8, -math.abs(v.Z) * 0.28))
					fire("save", "parry")
				else
					Ball.Deflect(Vector3.new(0, 4, -math.abs(v.Z) * 0.08))
					fire("save", "catch")
					-- topu tutar, kısa süre sonra oyuna sokar
					local kb = k
					task.delay(1.2, function()
						if kb.model.Parent and not Ball.InNet() then
							Ball.Reset(kb.pos + Vector3.new(0, 0, -4))
							Ball.Kick(Vector3.new((math.random() - 0.5) * 30, 16, -52), 0, "Clear")
						end
					end)
				end
			end
			-- plonjondan sonra yerine döner
			if plan.dive then
				task.delay(1.1, function()
					if k.model.Parent then
						k.pos =
							Vector3.new(math.clamp(k.pos.X + plan.side * 5.4, -T.GoalHalfWidth + 1, T.GoalHalfWidth - 1), k.pos.Y, k.pos.Z)
					end
				end)
			end
		end
		k.speed = 0
	else
		-- çizgi üzerinde topu izler
		local tx = math.clamp(ballPos.X * 0.32, -T.GoalHalfWidth + 3, T.GoalHalfWidth - 3)
		if not k.animator:IsBusy() then
			moveTo(k, Vector3.new(tx, 0, k.home.Z), K.ShuffleSpeed, dt, Vector3.new(k.pos.X, 0, k.pos.Z - 10))
		end
	end
end

--------------------------------------------------------------------------------
-- Her karede
--------------------------------------------------------------------------------
-- ctx = { playerPos }
function Bots.Update(dt: number, ctx)
	clock += dt
	local ballPos = Ball.Position()
	local ballFlat = flat(ballPos)
	local low = ballPos.Y < T.GroundY + 3
	local goalPoint = Vector3.new(0, 0, T.GoalZ)

	for _, bot in ipairs(list) do
		bot.cd = math.max(0, bot.cd - dt)
		if bot.role == "keeper" then
			updateKeeper(bot, dt)
		elseif bot.role == "defender" then
			if bot.state == "stagger" then
				bot.t -= dt
				bot.speed = 0
				if bot.t <= 0 then
					bot.state = "hold"
				end
			elseif bot.state == "windup" then
				bot.t -= dt
				-- hazırlık sırasında topa doğru hamle yapar
				moveTo(bot, ballFlat, D.DefenderSpeed * 0.7, dt, ballFlat)
				bot.ring.Transparency = 0.25 + 0.5 * math.abs(math.sin(clock * 22))
				if bot.t <= 0 then
					bot.ring.Transparency = 1
					bot.state = "hold"
					bot.cd = D.TackleCooldown
					if low and flat(ballPos - bot.pos).Magnitude < D.StealRange and not Ball.InNet() then
						-- topu kaptı: kaleden uzağa vurur
						Ball.Kick(Vector3.new((math.random() - 0.5) * 40, 12, -(55 + math.random() * 20)), 0, "Clear")
						fire("steal")
					end
				end
			else
				-- kademe: topla kale arasına girer
				local near = flat(ballPos - bot.home).Magnitude < 60 and not Ball.InNet()
				local target = bot.home
				if near then
					local toGoal = flat(goalPoint - ballFlat)
					local gdir = if toGoal.Magnitude > 0.1 then toGoal.Unit else Vector3.new(0, 0, 1)
					target = ballFlat + gdir * D.JockeyDistance
				end
				moveTo(bot, target, D.DefenderSpeed, dt, if near then ballFlat else nil)
				local dBall = flat(ballPos - bot.pos).Magnitude
				local carried = flat(ballPos - ctx.playerPos).Magnitude < 6
				if near and low and carried and dBall < D.TackleRange and bot.cd <= 0 and Ball.Speed() < 45 then
					bot.state = "windup"
					bot.t = D.TackleWindup
					fire("telegraph", bot.pos)
					-- animasyonun müdahale anı (0,18 sn) hazırlığın sonuna denk gelsin
					local b = bot
					task.delay(math.max(0, D.TackleWindup - 0.18), function()
						if b.state == "windup" and b.model.Parent then
							b.animator:Play("AyaktaMudahale")
						end
					end)
				end
			end
		elseif bot.role == "attacker" then
			if bot.state == "down" then
				bot.t -= dt
				bot.speed = 0
			else
				-- hafif zikzakla kaçış çizgisine koşar, topu her 0,28 sn'de iter
				local weave = math.sin(clock * 1.6) * 0.45
				local dir = Vector3.new(weave, 0, -1).Unit
				moveTo(bot, bot.pos + dir * 10, D.AttackerSpeed, dt)
				bot.touch -= dt
				if bot.touch <= 0 and low and flat(ballPos - bot.pos).Magnitude < 3.4 then
					bot.touch = 0.28
					Ball.Deflect(dir * (D.AttackerSpeed * 1.16 + 3))
				end
				if bot.pos.Z < D.EscapeZ then
					bot.state = "down"
					bot.t = 0.1
					respawnAt = clock + 1.6
					fire("escape")
				end
			end
		end

		-- gövdeyle top kesme
		if bot.role ~= "keeper" and bot.state ~= "down" and low and Ball.Speed() > 22 and Ball.SinceKick() > 0.06 then
			local off = ballFlat - flat(bot.pos)
			if off.Magnitude < 1.5 then
				local v = Ball.Velocity()
				local n = if off.Magnitude > 0.05 then off.Unit else -flat(v).Unit
				local reflected = v - 2 * v:Dot(n) * n
				Ball.Deflect(reflected * 0.4 + Vector3.new(0, 6, 0))
			end
		end

		place(bot)
		bot.animator:Update(dt, { speed = bot.speed, grounded = true, tired = false, turn = 0, vy = 0 })
	end

	if mode == "Savunma" and respawnAt > 0 and clock >= respawnAt then
		respawnAt = 0
		Bots.Start("Savunma")
	end
end

return Bots

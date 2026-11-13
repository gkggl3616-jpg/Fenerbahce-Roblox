--[[
	Training
	Deneme sahasında süreli antrenman oyunları (savunmacı ve kaleci yoktur):
	  "Kose" - Köşe avı: kalenin parlayan köşesine gol at. Her isabet +1 puan, hedef yer değiştirir.
	  "Pas"  - Pas ustası: yanan mankene pas ver. Her isabet +1 puan, başka manken yanar.
	Süre 45 saniye. En iyi puan oturum boyunca tutulur; her isabet sunucuya antrenman başarısı olarak gider.

	Training.Start(kind, onScore, onEnd) · Training.Stop() · Training.Active() -> string?
	Training.Update(dt)  her karede (oyuncu denetleyicisi çağırır)
	Training.Goal()      deneme sahasında gol olunca çağrılır; köşe avında isabet mi döner
	Training.Remaining() -> number
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ball = require(script.Parent.Ball)

local Training = {}

local T = Config.TestPitch
local C = Config.Colors
Training.Duration = 45

local state: any = nil
Training.Best = { Kose = 0, Pas = 0 }

-- Kalenin dört köşesi ve ortası (x, y): hedefler
local SPOTS = { { -1, 1 }, { 1, 1 }, { -1, 0 }, { 1, 0 } }

local function makeTarget(): Part
	local p = Instance.new("Part")
	p.Name = "FK_TrainingTarget"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = C.Yellow
	p.Transparency = 0.35
	p.Size = Vector3.new(7.4, 3.6, 0.25)
	p.Parent = Workspace
	return p
end

local function placeCorner()
	local pick = SPOTS[math.random(1, #SPOTS)]
	while state.spot and pick == state.spot and #SPOTS > 1 do
		pick = SPOTS[math.random(1, #SPOTS)]
	end
	state.spot = pick
	local x = pick[1] * (T.GoalHalfWidth - 3.9)
	local y = if pick[2] == 1 then T.GoalHeight - 2.0 else 2.0
	state.target.CFrame = CFrame.new(x, y, T.GoalZ + 0.4)
	state.targetPos = Vector3.new(x, y, T.GoalZ)
end

local function mannequins(): { BasePart }
	local out = {}
	local studio = Workspace:FindFirstChild("FK_Studio")
	if studio then
		for _, d in ipairs(studio:GetChildren()) do
			if d.Name == "PassTarget" and d:IsA("BasePart") then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function lightMannequin()
	local list = mannequins()
	if state.lit then
		state.lit.Color = C.Yellow
		state.lit.Material = Enum.Material.SmoothPlastic
	end
	if #list == 0 then
		state.lit = nil
		return
	end
	local pick = list[math.random(1, #list)]
	if #list > 1 then
		while pick == state.lit do
			pick = list[math.random(1, #list)]
		end
	end
	pick.Color = C.Good
	pick.Material = Enum.Material.Neon
	state.lit = pick
end

function Training.Active(): string?
	return state and state.kind
end

function Training.Remaining(): number
	return if state then math.max(0, state.endsAt - state.clock) else 0
end

function Training.Score(): number
	return if state then state.score else 0
end

local function hit()
	state.score += 1
	state.onScore(state.score)
	pcall(function()
		Remotes.Get("TrainingGoal"):FireServer("Drill")
	end)
end

function Training.Stop()
	if not state then
		return
	end
	local s = state
	state = nil
	if s.target then
		s.target:Destroy()
	end
	if s.lit then
		s.lit.Color = C.Yellow
		s.lit.Material = Enum.Material.SmoothPlastic
	end
	local best = Training.Best[s.kind] or 0
	local record = s.score > best
	if record then
		Training.Best[s.kind] = s.score
	end
	if s.onEnd then
		s.onEnd(s.score, record)
	end
end

function Training.Start(kind: string, onScore: (number) -> (), onEnd: ((number, boolean) -> ())?)
	Training.Stop()
	state = { kind = kind, score = 0, clock = 0, endsAt = Training.Duration, onScore = onScore, onEnd = onEnd, passing = false }
	if kind == "Kose" then
		state.target = makeTarget()
		placeCorner()
	else
		lightMannequin()
	end
end

-- Köşe avı: gol anında topun kale çizgisini geçtiği yer hedefin içindeyse isabet
function Training.Goal(): boolean
	if not state or state.kind ~= "Kose" then
		return false
	end
	local p = Ball.Position()
	local t = state.targetPos
	if math.abs(p.X - t.X) <= 4.6 and math.abs(p.Y - t.Y) <= 2.8 then
		hit()
		placeCorner()
		return true
	end
	return false
end

function Training.Update(dt: number)
	if not state then
		return
	end
	state.clock += dt
	if state.target then
		-- hedef nabız gibi parlar
		state.target.Transparency = 0.3 + 0.2 * math.sin(state.clock * 6)
	end
	if state.kind == "Pas" and state.lit then
		-- top yanan mankenin yakınından geçerse isabet
		local bp = Ball.Position()
		local mp = state.lit.Position
		if Vector3.new(bp.X - mp.X, 0, bp.Z - mp.Z).Magnitude < 3.6 and Ball.Speed() > 8 and bp.Y < 6 then
			hit()
			lightMannequin()
		end
	end
	if state.clock >= state.endsAt then
		Training.Stop()
	end
end

return Training

--[[
	Referee
	Sahadaki hakem: oyunu çaprazdan takip eder, düdük çalar, kart gösterir.
	Kurallar ve cezalar MatchController'da uygulanır; burası hakemin sahadaki bedeni ve sesidir.

	Referee.Spawn()            hakemi orta sahaya koyar
	Referee.Update(dt, live)   her karede: topu takip eder (live = oyun oynanıyor mu)
	Referee.Whistle(kind)      "short" (faul, başlama) | "double" (devre) | "long" (maç sonu)
	Referee.Card(color)        kartı havaya kaldırır
	Referee.Clear()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Animator = require(script.Parent.Parent.Anim.Animator)
local Ball = require(script.Parent.Ball)

local P = Config.MatchPitch

local Referee = {}

local ref: any = nil

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Referee.Clear()
	if ref then
		ref.animator:Destroy()
		ref.model:Destroy()
		ref = nil
	end
end

function Referee.Spawn()
	Referee.Clear()
	local folder = ReplicatedStorage:WaitForChild("FK_BotTemplates", 30)
	local tpl = folder and (folder:FindFirstChild("Referee") or folder:FindFirstChild("RivalKeeper"))
	if not tpl then
		return
	end
	local model = tpl:Clone()
	model.Name = "FK_Referee"
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = model:FindFirstChildOfClass("Humanoid")
	hrp.Anchored = true
	local offsetY = 3
	if hum then
		offsetY = hum.HipHeight + hrp.Size.Y / 2
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		pcall(function()
			hum.EvaluateStateMachine = false
		end)
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
		elseif d:IsA("TextLabel") and tonumber(d.Text) then
			d.Text = "" -- hakemin forma numarası olmaz
		end
	end
	model.Parent = Workspace
	local midZ = (P.MinZ + P.MaxZ) / 2
	ref = {
		model = model,
		hrp = hrp,
		animator = Animator.new(model),
		pos = Vector3.new(26, P.GroundY, midZ - 10),
		dir = Vector3.new(-1, 0, 0),
		speed = 0,
		offsetY = offsetY,
	}
end

function Referee.Position(): Vector3?
	return ref and ref.pos
end

function Referee.Update(dt: number, live: boolean)
	if not ref then
		return
	end
	local ball = flat(Ball.Position())
	-- Topun çaprazında, oyunu önünde tutacak şekilde durur; oyunculara karışmaz
	local side = if ball.X > 0 then -1 else 1
	local target = Vector3.new(math.clamp(ball.X + side * 26, P.MinX + 8, P.MaxX - 8), 0, math.clamp(ball.Z - 16, P.MinZ + 14, P.MaxZ - 14))
	local to = flat(target - ref.pos)
	local dist = to.Magnitude
	local want = if live and dist > 6 then math.min(21, dist * 1.6) else 0
	ref.speed += (want - ref.speed) * math.min(1, dt * 5)
	if dist > 0.1 then
		ref.pos += to.Unit * ref.speed * dt
	end
	ref.pos = Vector3.new(ref.pos.X, P.GroundY, ref.pos.Z)
	local look = flat(ball - ref.pos)
	if look.Magnitude > 0.5 then
		local nd = ref.dir:Lerp(look.Unit, math.min(1, dt * 6))
		ref.dir = if nd.Magnitude > 0.01 then nd.Unit else look.Unit
	end
	local base = ref.pos + Vector3.new(0, ref.offsetY, 0)
	ref.hrp.CFrame = CFrame.lookAt(base, base + ref.dir)
	ref.animator:Update(dt, { speed = ref.speed, grounded = true, tired = false, turn = 0, vy = 0 })
end

-- Düdük. Config.Assets.Whistle doluysa o ses çalar; boşsa kısa, tiz bir yedek ses kullanılır.
local function beep(speed: number, volume: number)
	local custom = Config.Assets.Whistle
	local s = Instance.new("Sound")
	if custom and custom ~= "" then
		s.SoundId = custom
		s.PlaybackSpeed = 1
	else
		s.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		s.PlaybackSpeed = speed
	end
	s.Volume = volume
	SoundService:PlayLocalSound(s)
	s:Destroy()
end

function Referee.Whistle(kind: string?)
	local custom = Config.Assets.Whistle
	local count = if kind == "long" then 3 elseif kind == "double" then 2 else 1
	if not custom or custom == "" then
		count *= 3 -- yedek ses kısa olduğu için art arda çalınarak düdük gibi uzatılır
	end
	for i = 0, count - 1 do
		task.delay(i * (if custom and custom ~= "" then 0.7 else 0.085), function()
			beep(2.7, 0.9)
		end)
	end
	if ref then
		ref.animator:Play("TopIste") -- kol havada
	end
end

-- Kart: hakemin başının üstünde, elinde tutuyormuş gibi görünür
function Referee.Card(color: Color3)
	if not ref then
		return
	end
	local head = ref.model:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Card"
	bb.Size = UDim2.fromScale(1.5, 2.1)
	bb.StudsOffset = Vector3.new(1.2, 2.6, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	local u = Instance.new("UICorner")
	u.CornerRadius = UDim.new(0.12, 0)
	u.Parent = f
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(20, 20, 24)
	st.Thickness = 2
	st.Parent = f
	f.Parent = bb
	bb.Parent = head
	ref.animator:Play("TopIste")
	task.delay(2.6, function()
		bb:Destroy()
	end)
end

return Referee

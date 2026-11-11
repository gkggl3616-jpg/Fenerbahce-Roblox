-- Maç kaydı: oyunun kendi kodunu çalıştırır ve her karedeki konumları JSON satırı olarak yazar.
-- Çalıştırma: node tests/replay.mjs <tohum>   (çıktı: konum kayıtları)
local Config = require(__tree.Shared.Config)
local RS = game:GetService("ReplicatedStorage")
math.randomseed(__seed)

-- sunucu
__isServer = true
local Remotes = require(__tree.Shared.Remotes)
local DataService = require(__tree.Server.DataService)
local PlayerService = require(__tree.Server.PlayerService)
DataService.Init()
PlayerService.Init()
Remotes.Get("CreateCareer").OnServerEvent:Fire(__localPlayer, {
	name = "Emre Kadikoy",
	position = "Forvet",
	number = 9,
	clubName = "Moda Genclik",
	clubAbbr = "MG",
	crestShape = 1,
	kitPattern = "Cubuklu",
	appearance = {
		height = 182,
		build = "Atletik",
		skin = 2,
		face = 1,
		hairStyle = 2,
		hairColor = "1B1410",
		beard = 1,
		bootModel = 1,
		bootColor = "101216",
		accessories = {},
	},
})
local data = DataService.Get(__localPlayer)
data.stats.Sut = 6
data.stats.TopKontrolu = 6
data.power = 45

-- bot şablonları
local templates = Instance.new("Folder")
templates.Name = "FK_BotTemplates"
for _, n in ipairs({ "Rival", "Rival2", "RivalAttacker", "RivalKeeper", "Mate", "Mate2", "MateKeeper" }) do
	__makeRig(n).Parent = templates
end
templates.Parent = RS

-- istemci
__isServer = false
__resetModules()
Config = require(__tree.Shared.Config)
Config.Match.IntroTime = 0.6
local UIS = game:GetService("UserInputService")
local Run = game:GetService("RunService")
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
local char = __makeRig("Tester")
char.Parent = workspace
__localPlayer.Character = char
local hum = char:FindFirstChildOfClass("Humanoid")
local hrp = char.HumanoidRootPart
hrp.CFrame = CFrame.lookAt(Vector3.new(0, 3, 70), Vector3.new(0, 3, 140))
local gui = Instance.new("ScreenGui")
gui.Parent = __localPlayer.PlayerGui
local PC = require(__tree.Controllers.PlayerController)
local Ball = require(__tree.Match.Ball)
local MatchAI = require(__tree.Match.MatchAI)
local MC = require(__tree.Match.MatchController)
PC.Start(gui, function()
	return data
end, function() end)
local facing = Vector3.new(0, 0, 1)
local function frame()
	local v = hum.MoveDirection * hum.WalkSpeed
	hrp.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
	if hum.MoveDirection.Magnitude > 0.1 then
		facing = facing:Lerp(hum.MoveDirection.Unit, 0.25).Unit
	end
	local pos = hrp.CFrame.Position + v * (1 / 60)
	hrp.CFrame = CFrame.lookAt(pos, pos + facing)
	Run.Stepped:Fire(0, 1 / 60)
	__advance(1 / 60)
end
for i = 1, 40 do
	frame()
end
local goals = { home = 0, away = 0 }
Ball.On("goal", function(_, side)
	goals[if side == "front" then "home" else "away"] += 1
end)
MC.Start(gui, data, function() end)

local P = Config.MatchPitch
local SH = Config.Shooting
local big
for _, d in ipairs(gui:GetDescendants()) do
	if d.ClassName == "TextLabel" and d.ZIndex == 30 then
		big = d
	end
end
local charging, chargeFrames, shots = false, 0, 0
local out = {}
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
for i = 1, 60 * __seconds do
	-- senaryo: topa koş, kaleye sür, menzile girince köşeye mükemmel şut
	local me = hrp.CFrame.Position
	local bp = Ball.Position()
	local toBall = flat(bp - me)
	local goal = Vector3.new(0, 0, P.GoalZ)
	local hasBall = toBall.Magnitude < 3.6 and not Ball.InNet()
	local distGoal = flat(goal - me).Magnitude
	if charging then
		chargeFrames += 1
		hum.MoveDirection = Vector3.new(if me.X > 0 then -0.75 else 0.75, 0, 0.66).Unit
		if chargeFrames >= math.floor(SH.ChargeTime * 0.86 * 60) then
			UIS.InputEnded:Fire({ KeyCode = Config.Keys.Shoot, UserInputType = Enum.UserInputType.Keyboard }, false)
			charging = false
			shots += 1
		end
	elseif hasBall and distGoal < 78 and PC.Debug().action == "" then
		UIS.InputBegan:Fire({ KeyCode = Config.Keys.Shoot, UserInputType = Enum.UserInputType.Keyboard }, false)
		charging, chargeFrames = true, 0
	elseif hasBall then
		local aim = flat(Vector3.new(me.X * 0.5, 0, P.GoalZ) - me)
		hum.MoveDirection = aim.Unit
		UIS.InputBegan:Fire({ KeyCode = Config.Keys.Sprint, UserInputType = Enum.UserInputType.Keyboard }, false)
	elseif toBall.Magnitude > 1.5 and not Ball.InNet() then
		hum.MoveDirection = flat(bp + flat(Ball.Velocity()) * 0.25 - me).Unit
	else
		hum.MoveDirection = Vector3.zero
	end
	frame()
	if i % 3 == 0 then
		local bots = {}
		for _, b in ipairs(MatchAI.Positions()) do
			table.insert(
				bots,
				string.format(
					'[%.2f,%.2f,%d,%.2f,%.2f,%.1f,"%s",%d]',
					b[1],
					b[2],
					if b[3] == "home" then 1 else 0,
					b[4],
					b[5],
					b[6],
					b[7],
					if b[8] then 1 else 0
				)
			)
		end
		local dbg = PC.Debug()
		local b2 = Ball.Position()
		local banner = if big and big.TextTransparency < 0.5 then big.Text else ""
		table.insert(
			out,
			string.format(
				'{"t":%.2f,"me":[%.2f,%.2f,%.2f,%.2f,%.1f,"%s",%.2f,%.0f],"ball":[%.2f,%.2f,%.2f],"bots":[%s],"score":[%d,%d],"banner":"%s"}',
				i / 60,
				me.X,
				me.Z,
				facing.X,
				facing.Z,
				dbg.speed,
				dbg.action,
				dbg.charge,
				dbg.stamina,
				b2.X,
				b2.Y,
				b2.Z,
				table.concat(bots, ","),
				goals.home,
				goals.away,
				banner
			)
		)
	end
end
__emit(
	string.format('{"seed":%d,"shots":%d,"home":%d,"away":%d}', __seed, shots, goals.home, goals.away),
	"[" .. table.concat(out, ",") .. "]"
)

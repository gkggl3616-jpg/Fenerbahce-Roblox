--[[
	RemoteAnim
	Aynı sunucudaki diğer oyuncuların karakterlerini de kodla canlandırır.
	Koşu döngüsü onların hızından üretilir; eylemler sunucudan gelen bildirimle oynar.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Animator = require(script.Parent.Parent.Anim.Animator)

local RemoteAnim = {}
local animators: { [Player]: any } = {}

local function get(plr: Player)
	local char = plr.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		animators[plr] = nil
		return nil
	end
	local an = animators[plr]
	local waist = an and an.Motors.Waist
	if not an or an.Character ~= char or not waist or not waist:IsDescendantOf(char) then
		an = Animator.new(char)
		animators[plr] = an
	end
	return an
end

function RemoteAnim.Start()
	local me = Players.LocalPlayer
	Remotes.Get("Anim").OnClientEvent:Connect(function(userId, action, mirror)
		local plr = Players:GetPlayerByUserId(userId)
		local an = plr and plr ~= me and get(plr)
		if an and type(action) == "string" then
			an:Play(action, { Mirror = mirror == true })
		end
	end)
	Players.PlayerRemoving:Connect(function(plr)
		animators[plr] = nil
	end)
	RunService.Stepped:Connect(function(_, dt)
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= me then
				local an = get(plr)
				if an then
					local char = plr.Character :: Model
					local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
					local hum = char:FindFirstChildOfClass("Humanoid")
					local v = hrp.AssemblyLinearVelocity
					an:Update(dt, {
						speed = Vector3.new(v.X, 0, v.Z).Magnitude,
						grounded = hum == nil or hum.FloorMaterial ~= Enum.Material.Air,
						tired = false,
						turn = 0,
						vy = v.Y,
					})
				end
			end
		end
	end)
end

return RemoteAnim

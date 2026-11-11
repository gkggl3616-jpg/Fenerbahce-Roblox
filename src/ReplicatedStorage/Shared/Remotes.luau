--[[
	Remotes
	Bütün RemoteEvent ve RemoteFunction nesnelerini tek yerden oluşturur (sunucu) veya bulur (istemci).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"DataChanged",
	"Notify",
	"CreateCareer",
	"UpgradeStat",
	"UnlockSkill",
	"UpgradeFacility",
	"PreviewAppearance",
	"Anim",
	"TrainingGoal",
}
local FUNCTIONS = { "GetData" }

local Remotes = {}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(EVENTS) do
		if not folder:FindFirstChild(name) then
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = folder
		end
	end
	for _, name in ipairs(FUNCTIONS) do
		if not folder:FindFirstChild(name) then
			local f = Instance.new("RemoteFunction")
			f.Name = name
			f.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

function Remotes.Get(name: string): any
	if RunService:IsServer() then
		return folder:FindFirstChild(name)
	end
	return folder:WaitForChild(name)
end

return Remotes

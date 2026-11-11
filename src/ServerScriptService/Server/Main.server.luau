--[[
	Main (sunucu)
	Servisleri sırayla başlatır.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local CharacterService = require(script.Parent.CharacterService)

CharacterService.BuildStudio()
DataService.Init()
PlayerService.Init()
DataService.StartAutoSave()

task.spawn(CharacterService.BuildBotTemplates)

print("[FenerKariyer] Sunucu hazır")

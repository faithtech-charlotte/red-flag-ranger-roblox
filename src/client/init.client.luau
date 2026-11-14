--[[
	Red Flag Rangers client entry point. Builds one ScreenGui and starts the
	controllers. Controllers only display state and send requests; the
	server decides every outcome.
]]

local Players = game:GetService("Players")

local Controllers = script.Controllers
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "RedFlagRangersUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local controllers = {
	State = require(Controllers.State),
	HUD = require(Controllers.HUDController),
	Adoption = require(Controllers.AdoptionController),
	Dialogue = require(Controllers.DialogueController),
	Shop = require(Controllers.ShopController),
	Pet = require(Controllers.PetController),
	ActionBar = require(Controllers.ActionBarController),
	Petting = require(Controllers.PettingController),
	Ball = require(Controllers.BallController),
	Activity = require(Controllers.ActivityController),
	Missions = require(Controllers.MissionsController),
	World = require(Controllers.WorldController),
}

controllers.HUD.start(gui, controllers)
controllers.Dialogue.start(gui, controllers)
controllers.Shop.start(gui, controllers)
controllers.Adoption.start(gui, controllers)
controllers.Pet.start()
controllers.ActionBar.start(gui, controllers)
controllers.Petting.start(gui, controllers)
controllers.Ball.start(gui, controllers)
controllers.Activity.start(gui, controllers)
controllers.Missions.start(gui, controllers)
controllers.World.start(gui, controllers)

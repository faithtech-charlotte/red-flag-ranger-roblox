--[[
	Red Flag Rangers server entry point.

	Every service exposes init(services) and start(). All inits run first
	(register actions, create remotes, build the world), then all starts
	(connect events, begin loops). Services reach each other through the
	shared `services` table, so there are no require cycles.
]]

local Services = script.Services
local Core = script.Core

local services = {
	Net = require(Core.Net),
	World = require(Services.WorldBuilder),
	Data = require(Services.PlayerDataService),
	Economy = require(Services.EconomyService),
	Inventory = require(Services.InventoryService),
	Appearance = require(Services.PetAppearanceService),
	Bond = require(Services.PetBondService),
	Pet = require(Services.PetService),
	Interaction = require(Services.PetInteractionService),
	Activity = require(Services.ActivityService),
	Quest = require(Services.QuestService),
	NPC = require(Services.NPCService),
	Encounter = require(Services.EncounterService),
	InteractionState = require(Services.InteractionState),
}

local order = {
	"Net",
	"World",
	"Data",
	"Economy",
	"Inventory",
	"Appearance",
	"Bond",
	"Pet",
	"Interaction",
	"Activity",
	"Quest",
	"NPC",
	"Encounter",
	"InteractionState",
}

for _, name in order do
	services[name].init(services)
end
for _, name in order do
	local start = services[name].start
	if start then
		start()
	end
end

print("[RedFlagRangers] server ready")

--[[
	Content index: everything writers/reviewers edit lives in this folder.
	Validated at server start (see EncounterService) and in tests.

	Campaign/* (the practice-story campaign) is aggregated here:
	  encounters   legacy Encounters + every campaign scene, one table
	  facts        factId -> { beat, concerning, says, leeReply }
	  factOrder    menu order of fact ids
	  moments      beat -> tell-menu moment label
	  factBeats    beats in menu order (e1..e5)
	  campaign     shared conventions (speakers, bar, tip, feedback, cards)
	  beatScenes   scheduler beat -> the live scene that plays it
	Each encounter carries its own `beat` / `roleplayFor`, which
	ProgressionService reads to credit the right beat.
]]

local encountersModule = require(script.Encounters)
local Facts = require(script.Campaign.Facts)
local Shared = require(script.Campaign.Shared)

local SCENE_MODULES = {
	script.Campaign.Onboarding,
	script.Campaign.Sparkz,
	script.Campaign.Healthy,
	script.Campaign.Cara,
	script.Campaign.Lee,
	script.Campaign.Roleplays,
}

local encounters = {}
for id, def in encountersModule do
	if id ~= "SafetyFeedback" then
		encounters[id] = def
	end
end

local beatScenes = {}
for _, module in SCENE_MODULES do
	for id, def in require(module) :: any do
		assert(encounters[id] == nil, `duplicate encounter id {id}`)
		encounters[id] = def
		if def.beat and not def.roleplayFor then
			beatScenes[def.beat] = id
		end
	end
end

return {
	npcs = require(script.NPCs),
	arcs = require(script.StoryArcs),
	encounters = encounters,
	safetyFeedback = encountersModule.SafetyFeedback,
	facts = Facts.facts,
	factOrder = Facts.order,
	moments = Facts.moments,
	factBeats = Facts.beatOrder,
	campaign = Shared,
	beatScenes = beatScenes,
}

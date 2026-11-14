--[[
	Content index: everything writers/reviewers edit lives in this folder.
	Validated at server start (see EncounterService) and in tests.
]]

local encountersModule = require(script.Encounters)

local encounters = {}
for id, def in encountersModule do
	if id ~= "SafetyFeedback" then
		encounters[id] = def
	end
end

return {
	npcs = require(script.NPCs),
	arcs = require(script.StoryArcs),
	encounters = encounters,
	safetyFeedback = encountersModule.SafetyFeedback,
}

--[[
	Conditions: pure evaluator for the small condition language used by
	encounters, story arcs and choices. A list of conditions means "all".

	Context fields:
	  profile     the player's Profile
	  locationId  where the NPC being talked to stands
	  arc         the player's ArcProgress for the arc being evaluated (optional)
]]

export type Condition = { type: string, [string]: any }
export type Context = {
	profile: any,
	locationId: string?,
	arc: any?,
}

local Conditions = {}

local evaluators: { [string]: (c: Condition, ctx: Context) -> boolean } = {}

local function evalOne(c: Condition, ctx: Context): boolean
	local fn = evaluators[c.type]
	if not fn then
		warn(`[Conditions] unknown condition type {c.type}`)
		return false
	end
	return fn(c, ctx)
end

function Conditions.evaluate(conditions: { Condition }?, ctx: Context): boolean
	if not conditions then
		return true
	end
	for _, c in conditions do
		if not evalOne(c, ctx) then
			return false
		end
	end
	return true
end

evaluators.all = function(c, ctx)
	return Conditions.evaluate(c.conditions, ctx)
end

evaluators.any = function(c, ctx)
	for _, sub in c.conditions do
		if evalOne(sub, ctx) then
			return true
		end
	end
	return false
end

evaluators["not"] = function(c, ctx)
	return not evalOne(c.condition, ctx)
end

evaluators.hasPet = function(_c, ctx)
	return ctx.profile.activePetId ~= nil
end

evaluators.activityCompleted = function(c, ctx)
	local a = ctx.profile.activities[c.activityId]
	return a ~= nil and a.count >= (c.min or 1)
end

evaluators.questDone = function(c, ctx)
	return ctx.profile.quests[c.questId] == true
end

evaluators.unlocked = function(c, ctx)
	return ctx.profile.unlocks[c.activityId] == true
end

evaluators.atLocation = function(c, ctx)
	return ctx.locationId == c.locationId
end

evaluators.encounterCompleted = function(c, ctx)
	local arc = ctx.profile.arcs[c.arcId]
	return arc ~= nil and arc.completed[c.encounterId] == true
end

evaluators.activitiesSinceStage = function(c, ctx)
	return ctx.arc ~= nil and ctx.arc.activitiesSinceStage >= (c.min or 1)
end

evaluators.arcFlag = function(c, ctx)
	return ctx.arc ~= nil and ctx.arc.flags[c.key] == c.equals
end

-- Practice-story campaign (profile.campaign is EncounterScheduler state;
-- profile.learningV2 is LearningProgress state). Read-only checks.
evaluators.campaignBeat = function(c, ctx)
	local campaign = ctx.profile.campaign
	local status = campaign and campaign.beats and campaign.beats[c.beat] or "not_started"
	if c.statuses then
		return table.find(c.statuses, status) ~= nil
	end
	return status == c.status
end

evaluators.showEligible = function(_c, ctx)
	local campaign = ctx.profile.campaign
	return campaign ~= nil and (campaign.completedActivities or 0) >= 4
end

evaluators.factSeen = function(c, ctx)
	local ledger = ctx.profile.learningV2
	local facts = ledger and ledger.seenFacts and ledger.seenFacts[c.beat]
	return facts ~= nil and facts[c.fact] == true
end

evaluators.hasTitle = function(c, ctx)
	local ledger = ctx.profile.learningV2
	return ledger ~= nil and ledger.titles ~= nil and ledger.titles[c.title] == true
end

-- Phase 2 story conditions (read-only). profile.story is StoryRules state.
local ASSESSED = { "e2", "e3", "e4", "e5" }

local function story(ctx)
	return ctx.profile.story or {}
end

-- A missing flag reads as false.
evaluators.storyFlag = function(c, ctx)
	return (story(ctx)[c.key] == true) == (c.equals ~= false)
end

evaluators.palChoice = function(c, ctx)
	return (story(ctx).palChoice or "none") == c.equals
end

evaluators.evidenceMissing = function(c, ctx)
	local ledger = ctx.profile.learningV2
	local points = ledger and ledger.evidence and ledger.evidence[c.slot] or 0
	return points < 1
end

evaluators.toldLee = function(c, ctx)
	local ledger = ctx.profile.learningV2
	local told = ledger ~= nil and ledger.toldLee ~= nil and ledger.toldLee[c.beat] == true
	return told == (c.equals ~= false)
end

evaluators.factsOnFile = function(c, ctx)
	local ledger = ctx.profile.learningV2
	local facts = ledger and ledger.seenFacts and ledger.seenFacts[c.beat]
	return facts ~= nil and next(facts) ~= nil
end

evaluators.anyFactOnFile = function(_c, ctx)
	local ledger = ctx.profile.learningV2
	for _, facts in ledger and ledger.seenFacts or {} do
		if next(facts) ~= nil then
			return true
		end
	end
	return false
end

-- A concerning beat (e2-e5) has facts on file that Lee hasn't heard yet.
evaluators.untoldStory = function(_c, ctx)
	local ledger = ctx.profile.learningV2
	if not ledger or not ledger.seenFacts then
		return false
	end
	for _, beat in ASSESSED do
		local facts = ledger.seenFacts[beat]
		if facts and next(facts) ~= nil and not (ledger.toldLee and ledger.toldLee[beat]) then
			return true
		end
	end
	return false
end

evaluators.npcBlocked = function(c, ctx)
	local state = ctx.profile.npcs and ctx.profile.npcs[c.npcId]
	return state ~= nil and state.blocked == true
end

function Conditions.knownTypes(): { [string]: boolean }
	local set = {}
	for k in evaluators do
		set[k] = true
	end
	return set
end

return Conditions

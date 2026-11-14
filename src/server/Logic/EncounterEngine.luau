--[[
	EncounterEngine: the data-driven dialogue state machine. Pure logic over
	content tables and a Profile, so it is unit-tested without Studio.

	Content shapes (see Server.Content.*):

	  NPCDefinition   { id, displayName, role, arcs = {arcId}, encounters = {encId}, ... }
	  StoryArcDefinition {
	    id, version, npcIds, entryConditions?,
	    stages = { { id, encounter, transitions? = { [outcome] = stageId | "done" } } },
	  }
	  EncounterDefinition {
	    id, npcId, arcId?, repeatable?, conditions?, start, onWalkAway?,
	    completeOnSafetyTool?, curriculum?,
	    nodes = { [nodeId] = { speaker = "npc" | "tip", text, choices = {
	      { id, text, next? = nodeId, outcome?, actions?, conditions? } } } },
	    onComplete? = actions,
	  }

	A choice without `next` ends the encounter with its `outcome`
	(default "done"). Per-player progress lives in profile.arcs[arcId].
]]

local Conditions = require(script.Parent.Conditions)

export type Content = {
	npcs: { [string]: any },
	encounters: { [string]: any },
	arcs: { [string]: any },
}

local EncounterEngine = {}

local function stageIndex(arcDef, stageId): number?
	for i, stage in arcDef.stages do
		if stage.id == stageId then
			return i
		end
	end
	return nil
end

local function firstOpenStage(arcDef, progress): string?
	for _, stage in arcDef.stages do
		if not progress.completed[stage.encounter] then
			return stage.id
		end
	end
	return nil
end

-- Gets (creating or upgrading if needed) this player's progress on an arc.
function EncounterEngine.ensureArc(profile, arcDef)
	local progress = profile.arcs[arcDef.id]
	if not progress then
		progress = {
			contentVersion = arcDef.version,
			stage = arcDef.stages[1] and arcDef.stages[1].id,
			completed = {},
			decisions = {},
			flags = {},
			activitiesSinceStage = 0,
			done = false,
		}
		profile.arcs[arcDef.id] = progress
	elseif progress.contentVersion ~= arcDef.version then
		-- Content changed since this player's last visit: keep what they
		-- completed, and resume at the first stage they haven't done.
		progress.contentVersion = arcDef.version
		if not progress.done and (progress.stage == nil or stageIndex(arcDef, progress.stage) == nil) then
			progress.stage = firstOpenStage(arcDef, progress)
			progress.done = progress.stage == nil
		end
	end
	return progress
end

-- Which encounter (if any) should start when this player talks to this NPC.
-- Returns (encounterDef?, arcId?, reason?)
function EncounterEngine.select(content: Content, profile, npcId: string, locationId: string?)
	local npc = content.npcs[npcId]
	if not npc then
		return nil, nil, "unknown_npc"
	end
	local npcState = profile.npcs[npcId]
	if npcState and npcState.blocked then
		return nil, nil, "blocked"
	end

	for _, arcId in npc.arcs or {} do
		local arcDef = content.arcs[arcId]
		-- An unscheduled arc keeps its saved progress but never starts.
		if arcDef and arcDef.scheduled ~= false then
			local progress = EncounterEngine.ensureArc(profile, arcDef)
			if not progress.done and progress.stage then
				local idx = stageIndex(arcDef, progress.stage)
				local stage = idx and arcDef.stages[idx]
				local enc = stage and content.encounters[stage.encounter]
				local ctx = { profile = profile, locationId = locationId, arc = progress }
				if
					enc
					and enc.npcId == npcId
					and Conditions.evaluate(arcDef.entryConditions, ctx)
					and Conditions.evaluate(enc.conditions, ctx)
				then
					return enc, arcId, nil
				end
			end
		end
	end

	for _, encId in npc.encounters or {} do
		local enc = content.encounters[encId]
		if enc and (enc.repeatable or not profile.claims["enc:" .. encId]) then
			local ctx = { profile = profile, locationId = locationId }
			if Conditions.evaluate(enc.conditions, ctx) then
				return enc, nil, nil
			end
		end
	end

	return nil, nil, "nothing"
end

-- Visible choices for a node (choices whose conditions pass).
function EncounterEngine.visibleChoices(enc, nodeId: string, ctx)
	local node = enc.nodes[nodeId]
	local list = {}
	if not node then
		return list
	end
	for _, choice in node.choices or {} do
		if Conditions.evaluate(choice.conditions, ctx) then
			table.insert(list, choice)
		end
	end
	return list
end

-- Validates a choice. Returns a result table or (nil, error).
function EncounterEngine.choose(enc, nodeId: string, choiceId: any, ctx)
	if typeof(choiceId) ~= "string" then
		return nil, "bad choice"
	end
	for _, choice in EncounterEngine.visibleChoices(enc, nodeId, ctx) do
		if choice.id == choiceId then
			local nextNode = choice.next
			if nextNode and not enc.nodes[nextNode] then
				return nil, "broken content"
			end
			return {
				nextNodeId = nextNode,
				ended = nextNode == nil,
				outcome = choice.outcome or "done",
				actions = choice.actions,
				choice = choice,
			}
		end
	end
	return nil, "choice not available"
end

-- Records completion and moves the arc forward. Idempotent: completing an
-- encounter twice has no further effect. Returns true if this call was the
-- first completion (so one-time rewards may be granted).
function EncounterEngine.complete(content: Content, profile, enc, arcId: string?, outcome: string): boolean
	if arcId then
		local arcDef = content.arcs[arcId]
		local progress = EncounterEngine.ensureArc(profile, arcDef)
		if progress.completed[enc.id] then
			return false
		end
		progress.completed[enc.id] = true
		progress.decisions[enc.id] = outcome
		local idx = stageIndex(arcDef, progress.stage)
		local stage = idx and arcDef.stages[idx]
		local nextStage: string? = nil
		if stage and stage.encounter == enc.id then
			local t = stage.transitions or {}
			nextStage = t[outcome] or t.default
			if nextStage == nil then
				local following = arcDef.stages[(idx :: number) + 1]
				nextStage = following and following.id or "done"
			end
		else
			nextStage = firstOpenStage(arcDef, progress) or "done"
		end
		if nextStage == "done" then
			progress.stage = nil
			progress.done = true
		else
			progress.stage = nextStage
		end
		progress.activitiesSinceStage = 0
		return true
	else
		local key = "enc:" .. enc.id
		local first = not profile.claims[key]
		if not enc.repeatable then
			profile.claims[key] = true
		end
		return first
	end
end

-- Called whenever the player completes an activity.
function EncounterEngine.noteActivity(profile)
	for _, progress in profile.arcs do
		if not progress.done then
			progress.activitiesSinceStage += 1
		end
	end
end

function EncounterEngine.format(text: string, vars: { [string]: string }): string
	return (text:gsub("{(%w+)}", function(key)
		return vars[key] or ""
	end))
end

-- Content validation: returns a list of problems (empty when content is sound).
function EncounterEngine.validate(content: Content, actionExists: (string) -> boolean): { string }
	local problems = {}
	local condTypes = Conditions.knownTypes()
	local function checkConditions(where, list)
		for _, c in list or {} do
			if not condTypes[c.type] then
				table.insert(problems, `{where}: unknown condition {c.type}`)
			end
			if c.conditions then
				checkConditions(where, c.conditions)
			end
			if c.condition then
				checkConditions(where, { c.condition })
			end
		end
	end
	local function checkActions(where, list)
		for _, a in list or {} do
			if not actionExists(a.action) then
				table.insert(problems, `{where}: unknown action {a.action}`)
			end
		end
	end

	for id, enc in content.encounters do
		if enc.id ~= id then
			table.insert(problems, `encounter {id}: id mismatch`)
		end
		if not content.npcs[enc.npcId] then
			table.insert(problems, `encounter {id}: unknown npc {enc.npcId}`)
		end
		if not enc.nodes[enc.start] then
			table.insert(problems, `encounter {id}: missing start node {enc.start}`)
		end
		if enc.onWalkAway and not enc.nodes[enc.onWalkAway] then
			table.insert(problems, `encounter {id}: missing walk-away node`)
		end
		checkConditions(`encounter {id}`, enc.conditions)
		checkActions(`encounter {id}`, enc.onComplete)
		for nodeId, node in enc.nodes do
			if typeof(node.text) ~= "string" or #node.text == 0 then
				table.insert(problems, `encounter {id}.{nodeId}: missing text`)
			end
			if not node.choices or #node.choices == 0 then
				table.insert(problems, `encounter {id}.{nodeId}: node has no choices (dead end)`)
			end
			for _, choice in node.choices or {} do
				if choice.next and not enc.nodes[choice.next] then
					table.insert(problems, `encounter {id}.{nodeId}: choice {choice.id} -> missing {choice.next}`)
				end
				checkActions(`encounter {id}.{nodeId}.{choice.id}`, choice.actions)
				checkConditions(`encounter {id}.{nodeId}.{choice.id}`, choice.conditions)
			end
		end
	end

	for id, arc in content.arcs do
		if typeof(arc.version) ~= "number" then
			table.insert(problems, `arc {id}: missing numeric version`)
		end
		local stageIds = {}
		for _, stage in arc.stages do
			stageIds[stage.id] = true
			if not content.encounters[stage.encounter] then
				table.insert(problems, `arc {id}: stage {stage.id} -> missing encounter {stage.encounter}`)
			end
		end
		for _, stage in arc.stages do
			for outcome, target in stage.transitions or {} do
				if target ~= "done" and not stageIds[target] then
					table.insert(problems, `arc {id}: stage {stage.id} outcome {outcome} -> missing stage {target}`)
				end
			end
		end
		checkConditions(`arc {id}`, arc.entryConditions)
	end

	for id, npc in content.npcs do
		for _, arcId in npc.arcs or {} do
			if not content.arcs[arcId] then
				table.insert(problems, `npc {id}: missing arc {arcId}`)
			end
		end
		for _, encId in npc.encounters or {} do
			if not content.encounters[encId] then
				table.insert(problems, `npc {id}: missing encounter {encId}`)
			end
		end
	end

	return problems
end

return EncounterEngine

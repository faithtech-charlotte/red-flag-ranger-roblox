--[[
	ContentCheck: graph checks EncounterEngine.validate does not do. Pure.

	check(content, registries) -> { string } problems (empty when sound)

	content = {
	  encounters = { [id] = EncounterDefinition },
	  facts      = { [factId] = true }?,      -- known fact ids
	  reviewSets = { [setId] = { cards = { { id, slot, kind, answer } } } }?,
	}
	registries = {
	  actionExists    = (name) -> boolean,
	  conditionExists = (type) -> boolean,
	}

	Checks:
	  - start (and onWalkAway, if any) exist; every node is reachable from them
	  - every choice's `next` exists; choice ids are unique within a node
	  - no node without choices; every node can reach an ending choice
	    (a choice with no `next`), so every branch terminates or recovers
	  - actions and condition types are known (nested all/any/not included)
	  - node.facts (optional list) only names known fact ids
	  - review sets: exactly 6 cards, slots 1-6 once each, slots 1-3 benign
	    and 4-6 concerning, card ids unique across all sets, answer present
]]

local ContentCheck = {}

ContentCheck.REVIEW_CARDS = 6
ContentCheck.BENIGN_SLOTS = 3

local function sortedKeys(t: { [any]: any }): { any }
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

local function checkConditions(problems, where: string, list: any, registries)
	if list == nil then
		return
	end
	if typeof(list) ~= "table" then
		table.insert(problems, `{where}: conditions must be a list`)
		return
	end
	for _, c in list do
		if typeof(c) ~= "table" or typeof(c.type) ~= "string" then
			table.insert(problems, `{where}: malformed condition`)
		else
			if not registries.conditionExists(c.type) then
				table.insert(problems, `{where}: unknown condition {c.type}`)
			end
			if c.conditions ~= nil then
				checkConditions(problems, where, c.conditions, registries)
			end
			if c.condition ~= nil then
				checkConditions(problems, where, { c.condition }, registries)
			end
		end
	end
end

local function checkActions(problems, where: string, list: any, registries)
	if list == nil then
		return
	end
	if typeof(list) ~= "table" then
		table.insert(problems, `{where}: actions must be a list`)
		return
	end
	for _, a in list do
		if typeof(a) ~= "table" or typeof(a.action) ~= "string" then
			table.insert(problems, `{where}: malformed action`)
		elseif not registries.actionExists(a.action) then
			table.insert(problems, `{where}: unknown action {a.action}`)
		end
	end
end

local function checkEncounter(problems, id: string, enc, content, registries)
	local where = `encounter {id}`
	if typeof(enc) ~= "table" or typeof(enc.nodes) ~= "table" then
		table.insert(problems, `{where}: not an encounter definition`)
		return
	end
	local nodes = enc.nodes
	local knownFacts = if typeof(content.facts) == "table" then content.facts else {}

	checkConditions(problems, where, enc.conditions, registries)
	checkActions(problems, where, enc.onComplete, registries)

	-- Roots
	local roots = {}
	if typeof(enc.start) ~= "string" or nodes[enc.start] == nil then
		table.insert(problems, `{where}: missing start node {tostring(enc.start)}`)
	else
		table.insert(roots, enc.start)
	end
	if enc.onWalkAway ~= nil then
		if typeof(enc.onWalkAway) ~= "string" or nodes[enc.onWalkAway] == nil then
			table.insert(problems, `{where}: missing walk-away node {tostring(enc.onWalkAway)}`)
		else
			table.insert(roots, enc.onWalkAway)
		end
	end

	-- Per node / per choice
	local nodeIds = sortedKeys(nodes)
	for _, nodeId in nodeIds do
		local node = nodes[nodeId]
		local nwhere = `{where}.{tostring(nodeId)}`
		if typeof(node) ~= "table" then
			table.insert(problems, `{nwhere}: malformed node`)
			continue
		end
		local choices = node.choices
		if typeof(choices) ~= "table" or #choices == 0 then
			table.insert(problems, `{nwhere}: node has no choices (dead end)`)
		else
			local seenChoice = {}
			for i, choice in choices do
				if typeof(choice) ~= "table" or typeof(choice.id) ~= "string" then
					table.insert(problems, `{nwhere}: choice #{i} is malformed`)
					continue
				end
				local cwhere = `{nwhere}.{choice.id}`
				if seenChoice[choice.id] then
					table.insert(problems, `{nwhere}: duplicate choice id {choice.id}`)
				end
				seenChoice[choice.id] = true
				if choice.next ~= nil and (typeof(choice.next) ~= "string" or nodes[choice.next] == nil) then
					table.insert(problems, `{cwhere}: next -> missing node {tostring(choice.next)}`)
				end
				checkActions(problems, cwhere, choice.actions, registries)
				checkConditions(problems, cwhere, choice.conditions, registries)
			end
		end
		if node.facts ~= nil then
			if typeof(node.facts) ~= "table" then
				table.insert(problems, `{nwhere}: facts must be a list`)
			else
				for _, fact in node.facts do
					if typeof(fact) ~= "string" or not knownFacts[fact] then
						table.insert(problems, `{nwhere}: unknown fact {tostring(fact)}`)
					end
				end
			end
		end
	end

	-- Reachability from start / walk-away
	local reached = {}
	local queue = table.clone(roots)
	while #queue > 0 do
		local nodeId = table.remove(queue, 1)
		if not reached[nodeId] then
			reached[nodeId] = true
			local node = nodes[nodeId]
			if typeof(node) == "table" and typeof(node.choices) == "table" then
				for _, choice in node.choices do
					if typeof(choice) == "table" and typeof(choice.next) == "string" and nodes[choice.next] ~= nil then
						table.insert(queue, choice.next)
					end
				end
			end
		end
	end
	for _, nodeId in nodeIds do
		if not reached[nodeId] then
			table.insert(problems, `{where}.{tostring(nodeId)}: unreachable node`)
		end
	end

	-- Termination: a node can end if one of its choices ends (no next) or
	-- leads to a node that can end. Fixpoint over the graph.
	local canEnd = {}
	local grew = true
	while grew do
		grew = false
		for _, nodeId in nodeIds do
			local node = nodes[nodeId]
			if not canEnd[nodeId] and typeof(node) == "table" and typeof(node.choices) == "table" then
				for _, choice in node.choices do
					if typeof(choice) == "table" and typeof(choice.id) == "string" then
						if choice.next == nil or canEnd[choice.next] then
							canEnd[nodeId] = true
							grew = true
							break
						end
					end
				end
			end
		end
	end
	for _, nodeId in nodeIds do
		local node = nodes[nodeId]
		if not canEnd[nodeId] and typeof(node) == "table" and typeof(node.choices) == "table" and #node.choices > 0 then
			table.insert(problems, `{where}.{tostring(nodeId)}: no path to an ending (branch never terminates)`)
		end
	end
end

local function checkReviewSets(problems, reviewSets)
	if typeof(reviewSets) ~= "table" then
		table.insert(problems, "reviewSets must be a table")
		return
	end
	local cardIds = {}
	for _, setId in sortedKeys(reviewSets) do
		local set = reviewSets[setId]
		local where = `review set {tostring(setId)}`
		local cards = typeof(set) == "table" and set.cards
		if typeof(cards) ~= "table" then
			table.insert(problems, `{where}: missing cards`)
			continue
		end
		if #cards ~= ContentCheck.REVIEW_CARDS then
			table.insert(problems, `{where}: has {#cards} cards, needs {ContentCheck.REVIEW_CARDS}`)
		end
		local slotSeen = {}
		for i, card in cards do
			local cwhere = `{where} card #{i}`
			if typeof(card) ~= "table" then
				table.insert(problems, `{cwhere}: malformed card`)
				continue
			end
			if typeof(card.id) ~= "string" or #card.id == 0 then
				table.insert(problems, `{cwhere}: missing id`)
			elseif cardIds[card.id] then
				table.insert(problems, `{cwhere}: duplicate card id {card.id}`)
			else
				cardIds[card.id] = true
			end
			local slot = card.slot
			if typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > ContentCheck.REVIEW_CARDS then
				table.insert(problems, `{cwhere}: bad slot {tostring(slot)}`)
			else
				if slotSeen[slot] then
					table.insert(problems, `{where}: slot {slot} used twice`)
				end
				slotSeen[slot] = true
				local expected = if slot <= ContentCheck.BENIGN_SLOTS then "benign" else "concerning"
				if card.kind ~= expected then
					table.insert(problems, `{cwhere}: slot {slot} must be {expected}, is {tostring(card.kind)}`)
				end
			end
			if card.answer == nil then
				table.insert(problems, `{cwhere}: missing answer`)
			end
		end
		for slot = 1, ContentCheck.REVIEW_CARDS do
			if not slotSeen[slot] then
				table.insert(problems, `{where}: slot {slot} missing`)
			end
		end
	end
end

function ContentCheck.check(content, registries): { string }
	local problems = {}
	if typeof(content) ~= "table" or typeof(content.encounters) ~= "table" then
		return { "content.encounters missing" }
	end
	if typeof(registries) ~= "table"
		or typeof(registries.actionExists) ~= "function"
		or typeof(registries.conditionExists) ~= "function"
	then
		return { "registries need actionExists and conditionExists" }
	end
	if content.facts ~= nil and typeof(content.facts) ~= "table" then
		table.insert(problems, "facts must be a table")
	end

	for _, id in sortedKeys(content.encounters) do
		checkEncounter(problems, tostring(id), content.encounters[id], content, registries)
	end

	if content.reviewSets ~= nil then
		checkReviewSets(problems, content.reviewSets)
	end
	return problems
end

return ContentCheck

--[[
	LeeTell: Ranger Lee's tell scene (docs/campaign-script.md 3.2). Pure.

	The menus are built only from facts on file (ledger.seenFacts, i.e.
	facts a node actually presented) and drop each fact once it has been
	told in this visit. "That's all I want to say." (`done`) is on every
	node. Telling one fact is enough for full credit; nothing requires
	telling everything.

	  open(reg, onFile, mode, beat?, withCara?) -> state
	  view(state, def, reg, onFile) -> { nodeId, text, choices = { {id, text} } }
	  choose(state, def, reg, onFile, choiceId) -> (ok, result?)
	      result = { told = factId?, beat = beat?, ended = boolean }
	  leave(state) -> boolean ended   (closing the panel = `done`)

	reg     = { facts = { [id] = { beat, says, leeReply } }, order = { id },
	            moments = { [beat] = label }, beatOrder = { beat } }
	onFile  = { [beat] = { [factId] = true } }
	def     = the lee_tell encounter definition (node text)

	The caller turns `told` into ledger events (Lee rule); E1 facts earn
	nothing there. State is per visit and never saved.
]]

local LeeTell = {}

local ASSESSED = { e2 = true, e3 = true, e4 = true, e5 = true }

local function untold(state, reg, onFile, beat: string?): { string }
	local list = {}
	local onBeat = beat and onFile[beat]
	if not onBeat then
		return list
	end
	for _, id in reg.order do
		local fact = reg.facts[id]
		if fact and fact.beat == beat and onBeat[id] and not state.told[id] then
			table.insert(list, id)
		end
	end
	return list
end

local function beatsWithUntold(state, reg, onFile): { string }
	local list = {}
	for _, beat in reg.beatOrder do
		if #untold(state, reg, onFile, beat) > 0 then
			table.insert(list, beat)
		end
	end
	return list
end

local function anyAssessedOnFile(onFile): boolean
	for beat, facts in onFile do
		if ASSESSED[beat] and next(facts) ~= nil then
			return true
		end
	end
	return false
end

function LeeTell.open(reg, onFile, mode: string, beat: string?, withCara: boolean?)
	local state = {
		mode = if mode == "ctx" then "ctx" else "general",
		beat = beat,
		withCara = withCara == true,
		node = if mode == "ctx" then "open_ctx" else "open_general",
		focus = beat,
		listFrom = nil :: string?,
		told = {},
		toldCount = 0,
		coreSaid = false,
		e5Said = false,
		lastFact = nil :: string?,
		ackCore = false,
		ackE5 = false,
		prefixOpen = false,
	}
	if state.mode == "general" then
		-- Only one beat has facts: skip the moment list (3.2 open_general).
		local beats = beatsWithUntold(state, reg, onFile)
		if #beats == 1 then
			state.node = "facts"
			state.focus = beats[1]
			state.prefixOpen = true
		end
	end
	return state
end

local function textOf(def, nodeId: string): string
	local node = def.nodes[nodeId]
	return node and node.text or ""
end

local function choiceText(def, nodeId: string, choiceId: string): string
	local node = def.nodes[nodeId]
	for _, c in node and node.choices or {} do
		if c.id == choiceId then
			return c.text
		end
	end
	return choiceId
end

local function factChoices(state, reg, onFile, beat: string?, out)
	for _, id in untold(state, reg, onFile, beat) do
		table.insert(out, { id = id, text = reg.facts[id].says })
	end
end

local function momentChoices(state, reg, onFile, out)
	for _, beat in beatsWithUntold(state, reg, onFile) do
		table.insert(out, { id = `moment_{beat}`, text = reg.moments[beat] or beat })
	end
end

-- "Same list as the node the player came from" (not_sure, agreed_first).
local function sameList(state, reg, onFile, out)
	local from = state.listFrom
	if from == "open_general" then
		momentChoices(state, reg, onFile, out)
	elseif from == "open_ctx" then
		factChoices(state, reg, onFile, state.beat, out)
	elseif from == "facts" then
		factChoices(state, reg, onFile, state.focus, out)
	end
end

function LeeTell.view(state, def, reg, onFile)
	local node = state.node
	local choices = {}
	local text = textOf(def, node)
	local function add(id: string)
		table.insert(choices, { id = id, text = choiceText(def, node, id) })
	end

	if node == "open_general" then
		momentChoices(state, reg, onFile, choices)
		add("not_sure")
		if anyAssessedOnFile(onFile) then
			add("agreed_first")
		end
		add("done")
	elseif node == "open_ctx" then
		if state.withCara and def.nodes.open_ctx.withCaraText then
			text = def.nodes.open_ctx.withCaraText
		end
		factChoices(state, reg, onFile, state.beat, choices)
		for _, beat in beatsWithUntold(state, reg, onFile) do
			if beat ~= state.beat then
				add("other")
				break
			end
		end
		add("not_sure")
		add("agreed_first")
		add("done")
	elseif node == "facts" then
		if state.prefixOpen then
			text = `{textOf(def, "open_general")} {text}`
		end
		factChoices(state, reg, onFile, state.focus, choices)
		add("back")
		add("done")
	elseif node == "ack" then
		local fact = state.lastFact and reg.facts[state.lastFact]
		local parts = { fact and fact.leeReply or "" }
		if state.ackCore then
			table.insert(parts, textOf(def, "ack"))
		end
		if state.ackE5 and def.nodes.ack.e5Text then
			table.insert(parts, def.nodes.ack.e5Text)
		end
		text = table.concat(parts, " ")
		add("more")
		add("done")
	elseif node == "not_sure" then
		sameList(state, reg, onFile, choices)
		add("just_checking")
		add("done")
	elseif node == "agreed_first" then
		sameList(state, reg, onFile, choices)
		add("done")
	elseif node == "close" then
		if state.toldCount == 0 and def.nodes.close.nothingText then
			text = def.nodes.close.nothingText
		end
		add("bye")
	end
	return { nodeId = node, text = text, choices = choices }
end

local function goTo(state, node: string)
	if node ~= "facts" then
		state.prefixOpen = false
	end
	state.node = node
end

function LeeTell.choose(state, def, reg, onFile, choiceId: any): (boolean, any)
	if typeof(choiceId) ~= "string" then
		return false, nil
	end
	local offered = false
	for _, c in LeeTell.view(state, def, reg, onFile).choices do
		if c.id == choiceId then
			offered = true
			break
		end
	end
	if not offered then
		return false, nil
	end

	local result = { ended = false, told = nil :: string?, beat = nil :: string? }
	local fact = reg.facts[choiceId]
	local momentBeat = string.match(choiceId, "^moment_(.+)$")

	if fact then
		state.told[choiceId] = true
		state.toldCount += 1
		state.lastFact = choiceId
		state.focus = fact.beat
		state.ackCore = not state.coreSaid
		state.coreSaid = true
		state.ackE5 = fact.beat == "e5" and not state.e5Said
		if state.ackE5 then
			state.e5Said = true
		end
		goTo(state, "ack")
		result.told = choiceId
		result.beat = fact.beat
	elseif momentBeat then
		state.focus = momentBeat
		goTo(state, "facts")
	elseif choiceId == "not_sure" or choiceId == "agreed_first" then
		state.listFrom = state.node
		goTo(state, choiceId)
	elseif choiceId == "other" or choiceId == "back" then
		goTo(state, "open_general")
	elseif choiceId == "more" then
		if #untold(state, reg, onFile, state.focus) > 0 then
			goTo(state, "facts")
		else
			goTo(state, "open_general")
		end
	elseif choiceId == "done" or choiceId == "just_checking" then
		goTo(state, "close")
	elseif choiceId == "bye" then
		result.ended = true
	end
	return true, result
end

-- Closing the panel or walking away = "That's all I want to say."
function LeeTell.leave(state): boolean
	if state.node == "close" then
		return true
	end
	goTo(state, "close")
	return false
end

return LeeTell

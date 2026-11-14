--[[
	EncounterService: runs conversations. One active session per player.

	Flow: ProximityPrompt -> interact() -> EncounterEngine.select() picks the
	encounter for THIS player's progress -> nodes are sent to the client ->
	the client picks a choice id -> the server validates it against the
	current node, runs its actions, and moves on.

	Safety tools (Block / Report / Get help) are offered in every conversation
	with a "peer" NPC, not just suspicious ones, the way real chat tools are.
	"Get help" is also always available from the HUD with no conditions.

	Rewards and story progress can only change on the server, and completing
	an encounter is idempotent (EncounterEngine.complete).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionService = require(script.Parent.Parent.Core.ActionService)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local Content = require(script.Parent.Parent.Content)
local EncounterEngine = require(script.Parent.Parent.Logic.EncounterEngine)
local SessionRules = require(script.Parent.Parent.Logic.SessionRules)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local TALK_DISTANCE = 16 -- prompt is 10; allow for latency
local WALK_AWAY_DISTANCE = 30
local HELP_NPC = "ranger_lee"
local HELP_ENCOUNTER = "help_lee"

type Session = {
	id: number,
	npcId: string,
	model: Model?,
	locationId: string?,
	remote: boolean,
	enc: any?,
	arcId: string?,
	nodeId: string?,
	feedback: { text: string, outcome: string, complete: boolean }?,
	rev: number, -- bumped on every node sent; requests must echo it
	exited: boolean?, -- the exit event was already published (safety tool)
	facts: { [string]: boolean }, -- facts presented so far in this session
}

local Encounter = {}
local S
local sessions: { [Player]: Session } = {}
local nextSessionId = 0

local function vars(player: Player, npcDef): { [string]: string }
	local profile = S.Data.get(player)
	local pet = profile and ProfileSchema.activePet(profile)
	return {
		petName = pet and pet.displayName or "your dog",
		npcName = npcDef and npcDef.displayName or "them",
	}
end

local function ctxFor(player: Player, session: Session)
	local profile = S.Data.get(player)
	return {
		profile = profile,
		locationId = session.locationId,
		arc = session.arcId and profile and profile.arcs[session.arcId] or nil,
	}
end

local function currentNode(player: Player, session: Session)
	local npcDef = Content.npcs[session.npcId]
	if session.feedback then
		return {
			speaker = "tip",
			text = session.feedback.text,
			choices = SessionRules.FEEDBACK_CHOICES,
		}
	end
	if not session.enc then
		return {
			speaker = "npc",
			text = npcDef.idleLine or "Hi!",
			choices = { { id = "bye", text = "Bye!" } },
		}
	end
	local node = session.enc.nodes[session.nodeId]
	return {
		speaker = node.speaker,
		text = node.text,
		choices = EncounterEngine.visibleChoices(session.enc, session.nodeId :: string, ctxFor(player, session)),
	}
end

local function send(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local npcDef = Content.npcs[session.npcId]
	local node = currentNode(player, session)
	local v = vars(player, npcDef)
	session.rev += 1
	-- Facts are recorded when the node that presents them is shown, never
	-- for nodes the player didn't see. Tip/feedback text adds no facts.
	local authored = session.enc and not session.feedback and session.enc.nodes[session.nodeId]
	if authored and authored.facts then
		local fresh = {}
		for _, fact in authored.facts do
			if not session.facts[fact] then
				session.facts[fact] = true
				table.insert(fresh, fact)
			end
		end
		if #fresh > 0 then
			EventBus.publish("encounter.facts_presented", player, {
				encounterId = session.enc.id,
				npcId = session.npcId,
				nodeId = session.nodeId,
				facts = fresh,
			})
		end
	end
	local choices = {}
	for _, c in node.choices do
		table.insert(choices, { id = c.id, text = EncounterEngine.format(c.text, v) })
	end
	S.Net.push(player, Remotes.PushKinds.Dialogue, {
		sessionId = session.id,
		rev = session.rev,
		npcId = session.npcId,
		npcName = npcDef.displayName,
		subtitle = npcDef.subtitle,
		speaker = node.speaker,
		text = EncounterEngine.format(node.text, v),
		choices = choices,
		safetyTools = npcDef.role == "peer",
	})
end

-- Every way a conversation can end goes through here, with a kind:
--   completed   the graph reached an outcome (outcome given)
--   walk_away   the player closed the panel or walked out of range
--   help        Help preempted it
--   blocked / reported   a practice safety tool (published when the tool is
--               used, before its feedback card)
--   replaced    another conversation started
--   respawn / disconnect
-- The exit event carries the facts this session presented, so listeners
-- (story progress) can tell "left before anything concerning" from "left
-- after a concerning request" without guessing.
local publishExit: (Player, Session, string, string?) -> ()

local function endSession(player: Player, kind: string?, outcome: string?)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	if player.Parent then
		S.Net.push(player, Remotes.PushKinds.DialogueClose)
	end
	if session.enc and not session.exited then
		publishExit(player, session, kind or "walk_away", outcome)
	end
end

-- Exactly one exit event per session.
publishExit = function(player: Player, session: Session, kind: string, outcome: string?)
	if session.exited then
		return
	end
	session.exited = true
	do
		local facts = {}
		for fact in session.facts do
			table.insert(facts, fact)
		end
		EventBus.publish("encounter.exited", player, {
			encounterId = session.enc.id,
			npcId = session.npcId,
			arcId = session.arcId,
			nodeId = session.nodeId,
			kind = kind,
			outcome = outcome,
			facts = facts,
		})
	end
end

local function finish(player: Player, outcome: string, kind: string?)
	local session = sessions[player]
	endSession(player, kind or "completed", outcome)
	if not session or not session.enc then
		return
	end
	local profile = S.Data.get(player)
	if not profile then
		return
	end
	local first = EncounterEngine.complete(Content, profile, session.enc, session.arcId, outcome)
	if first then
		ActionService.run(player, session.enc.onComplete, { npcId = session.npcId, arcId = session.arcId, encounterId = session.enc.id })
		EventBus.publish("encounter.completed", player, {
			encounterId = session.enc.id,
			npcId = session.npcId,
			arcId = session.arcId,
			outcome = outcome,
		})
	end
	S.Data.pushState(player)
end

local function begin(player: Player, npcId: string, model: Model?, locationId: string?, remote: boolean, forced: any?)
	local profile = S.Data.get(player)
	local npcDef = Content.npcs[npcId]
	if not profile or not npcDef then
		return
	end
	local enc, arcId, reason
	if forced then
		enc = forced
	else
		enc, arcId, reason = EncounterEngine.select(Content, profile, npcId, locationId)
	end
	if reason == "blocked" then
		S.Net.toast(player, `You blocked {npcDef.displayName}. You can unblock them from the Help menu.`, "info")
		return
	end
	endSession(player, "replaced")
	nextSessionId += 1
	sessions[player] = {
		rev = 0,
		facts = {},
		id = nextSessionId,
		npcId = npcId,
		model = model,
		locationId = locationId,
		remote = remote,
		enc = enc,
		arcId = arcId,
		nodeId = enc and enc.start or nil,
	}
	send(player)
end

-- True while the player is in any conversation or Help scene.
function Encounter.isActive(player: Player): boolean
	return sessions[player] ~= nil
end

-- Opens Ranger Lee's help conversation from anywhere. Never gated. Help
-- preempts whatever conversation is open; that scene ends with exit kind
-- "help", and the facts it already presented go with the exit event, so
-- the story keeps its context (what was seen) and Lee can respond to it.
function Encounter.startHelp(player: Player)
	endSession(player, "help")
	local profile = S.Data.get(player)
	if profile then
		profile.learning.toolsPracticed.help = true
	end
	begin(player, HELP_NPC, nil, nil, true, Content.encounters[HELP_ENCOUNTER])
	S.Net.push(player, Remotes.PushKinds.Waypoint, { placeId = "ranger_station", reason = "help" })
	S.Pet.react(player, "comfort")
end

function Encounter.interact(player: Player, model: Model)
	local npcId = model:GetAttribute("NpcId")
	local npcDef = npcId and Content.npcs[npcId]
	local profile = S.Data.get(player)
	if not npcDef or not profile then
		return
	end
	if not S.NPC.isNear(player, model, TALK_DISTANCE) then
		return
	end
	if npcDef.interaction == "shop" then
		endSession(player, "replaced")
		S.Net.push(player, Remotes.PushKinds.OpenShop, {
			npcName = npcDef.displayName,
			line = npcDef.idleLine,
			shop = npcDef.shop or "salon",
		})
		return
	end
	if npcDef.interaction == "adopt" and not profile.activePetId then
		endSession(player, "replaced")
		S.Net.push(player, Remotes.PushKinds.OpenAdoption)
		return
	end
	begin(player, npcId, model, model:GetAttribute("LocationId"), false, nil)
end

local function validSession(player: Player, payload: any): Session?
	local session = sessions[player]
	if not session or typeof(payload) ~= "table" or payload.sessionId ~= session.id then
		return nil
	end
	-- A request for an earlier node of this same conversation is stale.
	if payload.rev ~= session.rev then
		return nil
	end
	if not session.remote and session.model and not S.NPC.isNear(player, session.model, WALK_AWAY_DISTANCE) then
		endSession(player, "walk_away")
		return nil
	end
	return session
end

local function choose(player: Player, payload: any): (boolean, string?)
	local session = validSession(player, payload)
	if not session then
		return false, nil
	end
	local choiceId = payload.choiceId

	if session.feedback then
		if not SessionRules.isFeedbackChoice(choiceId) then
			return false, "unknown choice"
		end
		local fb = session.feedback
		if fb.complete then
			finish(player, fb.outcome)
		else
			endSession(player, fb.outcome)
		end
		if choiceId == "help" then
			Encounter.startHelp(player)
		end
		return true
	end

	if not session.enc then
		endSession(player)
		return true
	end

	local result, err = EncounterEngine.choose(session.enc, session.nodeId :: string, choiceId, ctxFor(player, session))
	if not result then
		return false, err
	end
	local actx = { npcId = session.npcId, arcId = session.arcId, encounterId = session.enc.id, openHelp = false, endNow = false }
	ActionService.run(player, result.actions, actx)
	if result.ended or actx.endNow then
		finish(player, result.outcome)
		if actx.openHelp then
			Encounter.startHelp(player)
		end
	else
		session.nodeId = result.nextNodeId
		send(player)
		if actx.openHelp then
			Encounter.startHelp(player)
		end
	end
	S.Data.pushState(player)
	return true
end

-- Closing the window. Walking away is always allowed; in encounters with an
-- onWalkAway node the player sees one short, supportive note first.
local function close(player: Player, payload: any): (boolean, string?)
	local current = sessions[player]
	if not SessionRules.closeTargets(current and current.id, payload) then
		return true -- stale or unknown close: never touch a newer conversation
	end
	local session = validSession(player, payload)
	if not session then
		-- Either a stale request for an older node (ignored) or the player
		-- walked out of range (validSession already ended it).
		return true
	end
	if session.feedback or not session.enc then
		return choose(player, { sessionId = session.id, rev = session.rev, choiceId = "ok" })
	end
	local enc = session.enc
	local node = enc.nodes[session.nodeId]
	if node.speaker == "tip" then
		-- Closing a tip card = its first choice (keeps the outcome recorded).
		-- A forced close (another panel took over) must not move on to a
		-- further node, which would reopen the conversation.
		local first = node.choices[1]
		if payload.force ~= true or first.next == nil then
			return choose(player, { sessionId = session.id, rev = session.rev, choiceId = first.id })
		end
		endSession(player, "walk_away")
		return true
	end
	if enc.onWalkAway and session.nodeId ~= enc.onWalkAway and payload.force ~= true then
		session.nodeId = enc.onWalkAway
		send(player)
		return true
	end
	endSession(player, "walk_away")
	return true
end

local function safety(player: Player, payload: any): (boolean, string?)
	local session = validSession(player, payload)
	if not session then
		return false, nil
	end
	-- One safety tool per scene: once its feedback card is showing (and its
	-- exit published), further tool requests are refused.
	if session.feedback or session.exited then
		return false, nil
	end
	local tool = payload.tool
	local npcDef = Content.npcs[session.npcId]
	local enc = session.enc
	local completes = enc ~= nil and enc.completeOnSafetyTool == true

	if tool == "help" then
		if completes then
			finish(player, "sought_help", "help") -- a safe exit, not a plain completion
		end
		Encounter.startHelp(player) -- ends any remaining scene with kind "help"
		return true
	end
	if npcDef.role ~= "peer" or (tool ~= "block" and tool ~= "report") then
		return false, "Not available here."
	end
	local action = tool == "block" and "simulate_block" or "simulate_report"
	ActionService.run(player, { { action = action, npcId = session.npcId } }, { npcId = session.npcId })
	-- The exit is committed before the feedback card shows, so the choice
	-- (and any evidence) is recorded even if the player disconnects or
	-- respawns while reading it. The later close publishes nothing more.
	if enc then
		EventBus.publish("encounter.safety_tool", player, {
			encounterId = enc.id,
			npcId = session.npcId,
			tool = tool,
		})
		publishExit(player, session, tool == "block" and "blocked" or "reported", nil)
	end
	session.feedback = {
		text = EncounterEngine.format(Content.safetyFeedback[tool], vars(player, npcDef)),
		outcome = tool == "block" and "blocked" or "reported",
		complete = completes,
	}
	send(player)
	return true
end

function Encounter.init(services)
	S = services

	local function npcState(player: Player, npcId: string)
		local profile = S.Data.get(player)
		if not profile or not Content.npcs[npcId] then
			return nil, profile
		end
		profile.npcs[npcId] = profile.npcs[npcId] or {}
		return profile.npcs[npcId], profile
	end

	ActionService.register("simulate_block", function(player, spec, ctx)
		local state, profile = npcState(player, spec.npcId or ctx.npcId)
		if not state then
			return false, "unknown npc"
		end
		state.blocked = true
		profile.learning.toolsPracticed.block = true
		S.Data.pushState(player)
		return true
	end)
	ActionService.register("simulate_report", function(player, spec, ctx)
		local state, profile = npcState(player, spec.npcId or ctx.npcId)
		if not state then
			return false, "unknown npc"
		end
		state.reported = true
		profile.learning.toolsPracticed.report = true
		return true
	end)
	ActionService.register("open_help", function(player, _spec, ctx)
		if ctx.encounterId then
			ctx.openHelp = true -- opened after the current conversation closes
		else
			Encounter.startHelp(player)
		end
		return true
	end)
	ActionService.register("end_conversation", function(_player, _spec, ctx)
		ctx.endNow = true
		return true
	end)
	ActionService.register("record_learning", function(player, spec)
		local profile = S.Data.get(player)
		if profile and typeof(spec.topic) == "string" then
			profile.learning.topicsSeen[spec.topic] = true
		end
		return true
	end)
	ActionService.register("set_arc_flag", function(player, spec, ctx)
		local profile = S.Data.get(player)
		local arc = profile and ctx.arcId and profile.arcs[ctx.arcId]
		if not arc then
			return false, "no arc"
		end
		arc.flags[spec.key] = spec.value
		return true
	end)
	ActionService.register("show_waypoint", function(player, spec)
		S.Net.push(player, Remotes.PushKinds.Waypoint, { placeId = spec.placeId })
		return true
	end)
end

function Encounter.start()
	local problems = EncounterEngine.validate(Content, ActionService.has)
	for _, problem in problems do
		warn("[Content] " .. problem)
	end

	EventBus.subscribe("activity.completed", function(player)
		local profile = S.Data.get(player)
		if profile then
			EncounterEngine.noteActivity(profile)
		end
	end)

	S.Net.on(Remotes.RequestKinds.DialogueChoose, choose, 0.15)
	S.Net.on(Remotes.RequestKinds.DialogueClose, close, 0.15)
	S.Net.on(Remotes.RequestKinds.DialogueSafety, safety, 0.3)
	S.Net.on(Remotes.RequestKinds.RequestHelp, function(player)
		Encounter.startHelp(player)
		return true
	end, 1)
	S.Net.on(Remotes.RequestKinds.Unblock, function(player, payload)
		local profile = S.Data.get(player)
		local npcId = typeof(payload) == "table" and payload.npcId or nil
		local state = profile and typeof(npcId) == "string" and profile.npcs[npcId]
		if not state then
			return false, "Not blocked."
		end
		state.blocked = false
		S.Data.pushState(player)
		return true
	end, 0.5)

	-- Leaving while a completing feedback card is open still completes the
	-- encounter (its exit was already published by the safety tool).
	local function settle(player: Player, kind: string)
		local session = sessions[player]
		if session and session.feedback and session.feedback.complete then
			finish(player, session.feedback.outcome, kind)
		else
			endSession(player, kind)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		settle(player, "disconnect")
	end)
	local function watchRespawn(player: Player)
		player.CharacterAdded:Connect(function()
			local session = sessions[player]
			if session and not session.remote then
				settle(player, "respawn")
			end
		end)
	end
	Players.PlayerAdded:Connect(watchRespawn)
	for _, player in Players:GetPlayers() do
		watchRespawn(player)
	end
end

return Encounter

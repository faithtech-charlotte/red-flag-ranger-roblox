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
			choices = {
				{ id = "ok", text = "Okay" },
				{ id = "help", text = "Talk to a trusted adult" },
			},
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
	local choices = {}
	for _, c in node.choices do
		table.insert(choices, { id = c.id, text = EncounterEngine.format(c.text, v) })
	end
	S.Net.push(player, Remotes.PushKinds.Dialogue, {
		sessionId = session.id,
		npcId = session.npcId,
		npcName = npcDef.displayName,
		subtitle = npcDef.subtitle,
		speaker = node.speaker,
		text = EncounterEngine.format(node.text, v),
		choices = choices,
		safetyTools = npcDef.role == "peer",
	})
end

local function endSession(player: Player)
	if sessions[player] then
		sessions[player] = nil
		S.Net.push(player, Remotes.PushKinds.DialogueClose)
	end
end

local function finish(player: Player, outcome: string)
	local session = sessions[player]
	endSession(player)
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
	endSession(player)
	nextSessionId += 1
	sessions[player] = {
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

-- Opens Ranger Lee's help conversation from anywhere. Never gated.
function Encounter.startHelp(player: Player)
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
		endSession(player)
		S.Net.push(player, Remotes.PushKinds.OpenShop, { npcName = npcDef.displayName, line = npcDef.idleLine })
		return
	end
	if npcDef.interaction == "adopt" and not profile.activePetId then
		endSession(player)
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
	if not session.remote and session.model and not S.NPC.isNear(player, session.model, WALK_AWAY_DISTANCE) then
		endSession(player)
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
		local fb = session.feedback
		if fb.complete then
			finish(player, fb.outcome)
		else
			endSession(player)
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
	local session = validSession(player, payload)
	if not session then
		endSession(player)
		return true
	end
	if session.feedback or not session.enc then
		return choose(player, { sessionId = session.id, choiceId = "ok" })
	end
	local enc = session.enc
	local node = enc.nodes[session.nodeId]
	if node.speaker == "tip" then
		-- Closing a tip card = its first choice (keeps the outcome recorded).
		local first = node.choices[1]
		return choose(player, { sessionId = session.id, choiceId = first.id })
	end
	if enc.onWalkAway and session.nodeId ~= enc.onWalkAway then
		session.nodeId = enc.onWalkAway
		send(player)
		return true
	end
	endSession(player)
	return true
end

local function safety(player: Player, payload: any): (boolean, string?)
	local session = validSession(player, payload)
	if not session then
		return false, nil
	end
	local tool = payload.tool
	local npcDef = Content.npcs[session.npcId]
	local enc = session.enc
	local completes = enc ~= nil and enc.completeOnSafetyTool == true

	if tool == "help" then
		if completes then
			finish(player, "sought_help")
		else
			endSession(player)
		end
		Encounter.startHelp(player)
		return true
	end
	if npcDef.role ~= "peer" or (tool ~= "block" and tool ~= "report") then
		return false, "Not available here."
	end
	local action = tool == "block" and "simulate_block" or "simulate_report"
	ActionService.run(player, { { action = action, npcId = session.npcId } }, { npcId = session.npcId })
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

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return Encounter

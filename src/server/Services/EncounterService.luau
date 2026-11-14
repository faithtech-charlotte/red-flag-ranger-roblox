--[[
	EncounterService: runs conversations. One active session per player.

	Flow: ProximityPrompt -> interact() -> EncounterEngine.select() picks the
	encounter for THIS player's progress -> nodes are sent to the client ->
	the client picks a choice id -> the server validates it against the
	current node, runs its actions, and moves on.

	Session kinds:
	  scene  an authored encounter (legacy or a campaign scene)
	  card   a small card before a scene: the invitation (Talk / Later /
	         Skip this story) or Cara's follow-up offer. StoryService makes
	         cards and decides what their choices do.
	  tell   Ranger Lee's tell menu (Logic/LeeTell), built from facts on file

	Every node carries a button bar (campaign-script 1.3, Logic/StoryRules):
	Leave and Help are always there (Help except with Lee himself); Block /
	Report / "Something feels off" follow the scene's bar rule. Block and
	Report are practice tools. The first bar with them shows
	tip_practice_tools once.

	Rewards and story progress can only change on the server, and completing
	an encounter is idempotent (EncounterEngine.complete). Campaign scenes
	grant no coins; their evidence comes from `learning` actions and from
	exit rules (ProgressionService), never from text.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionService = require(script.Parent.Parent.Core.ActionService)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local Content = require(script.Parent.Parent.Content)
local Conditions = require(script.Parent.Parent.Logic.Conditions)
local EncounterEngine = require(script.Parent.Parent.Logic.EncounterEngine)
local LeeTell = require(script.Parent.Parent.Logic.LeeTell)
local SessionRules = require(script.Parent.Parent.Logic.SessionRules)
local StoryRules = require(script.Parent.Parent.Logic.StoryRules)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local PetCatalog = require(ReplicatedStorage.Shared.Catalogs.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local TALK_DISTANCE = 16 -- prompt is 10; allow for latency
local WALK_AWAY_DISTANCE = 30
local HELP_NPC = "ranger_lee"
local HELP_ENCOUNTER = "help_lee"
local TELL_ENCOUNTER = "lee_tell"

local Shared = Content.campaign
local FACT_REG = {
	facts = Content.facts,
	order = Content.factOrder,
	moments = Content.moments,
	beatOrder = Content.factBeats,
}
local PAL_CHOICES = {
	{ id = "pal_accept", text = "Accept" },
	{ id = "pal_decline", text = "Decline" },
}

-- Campaign-scene state for one session. Never saved, never sent.
type Story = {
	kind: string?, -- sceneKind
	beat: string?, -- the live beat this scene plays (scheduler + ledger)
	creditBeat: string?, -- the beat credited (beat or roleplayFor)
	aboutBeat: string?, -- the beat a follow-up / walk / tell is about
	concern: boolean, -- a concerning fact was presented (bar rule A)
	refused: boolean, -- said no at the request
	agreed: boolean, -- picked a simulated agreement
	outcome: string?, -- settled outcome (roleplay debrief)
	returnTo: string?, -- node "Something feels off" was pressed on
	narrator: string?, -- "ranger_lee" when Lee runs a roleplay
	visited: { [string]: boolean },
}

type Card = {
	kind: string, -- "campaign" | "ambient" | "followUp"
	sceneId: string,
	beat: string?,
	npcId: string,
	text: string,
	choices: { { id: string, text: string } },
	skipped: boolean?,
}

type Session = {
	id: number,
	kind: string, -- "scene" | "card" | "tell"
	npcId: string,
	model: Model?,
	locationId: string?,
	remote: boolean,
	enc: any?,
	arcId: string?,
	nodeId: string?,
	feedback: { text: string, outcome: string, complete: boolean, choices: any, thenNode: string? }?,
	rev: number, -- bumped on every node sent; requests must echo it
	exited: boolean?, -- the exit event was already published (safety tool)
	exitInfo: any?, -- the published exit, repeated in encounter.closed
	facts: { [string]: boolean }, -- facts presented so far in this session
	story: Story?,
	card: Card?,
	tell: any?,
	tipPending: boolean?,
	rendered: { nodeId: string, text: string, facts: { string }, pal: any? }?,
	palAnswered: { [string]: boolean },
}

local Encounter = {}
local S
local sessions: { [Player]: Session } = {}
local nextSessionId = 0
local lastActivity: { [Player]: string } = {}
-- The beat of a scene that just ended after a concerning request, so Help
-- opened a moment later from the HUD (whose popup closes the dialogue
-- first) still gives Lee that context.
local recentConcern: { [Player]: { beat: string, at: number } } = {}
local RECENT_SECONDS = 60

local function profileOf(player: Player)
	return S.Data.get(player)
end

local function storyFlags(profile)
	if profile and typeof(profile.story) ~= "table" then
		profile.story = StoryRules.defaultStory()
	end
	return profile and profile.story
end

local function vars(player: Player, npcDef): { [string]: string }
	local profile = profileOf(player)
	local pet = profile and ProfileSchema.activePet(profile)
	local breed = pet and PetCatalog.get(pet.breedId)
	return {
		petName = pet and pet.displayName or "your dog",
		npcName = npcDef and npcDef.displayName or "them",
		breed = breed and string.lower(breed.displayName) or "dog",
		activity = StoryRules.activityPhrase(lastActivity[player]),
	}
end

local function ctxFor(player: Player, session: Session)
	local profile = profileOf(player)
	return {
		profile = profile,
		locationId = session.locationId,
		arc = session.arcId and profile and profile.arcs[session.arcId] or nil,
	}
end

local function onFile(player: Player)
	local profile = profileOf(player)
	local ledger = profile and profile.learningV2
	return ledger and ledger.seenFacts or {}
end

local function aboutOutcome(player: Player, session: Session): string?
	local profile = profileOf(player)
	local story = session.story
	local flags = storyFlags(profile)
	return story and story.aboutBeat and flags and flags.outcomes[story.aboutBeat] or nil
end

-- Who is speaking, and the dialogue label ("Story character", ...).
local function speakerOf(session: Session, node): (string, string?)
	local npcDef = Content.npcs[session.npcId]
	local sid = node and node.speakerId
	local story = session.story
	if sid and story and story.narrator == HELP_NPC then
		if sid == "cara" then
			sid = HELP_NPC
		elseif sid == "cara_pretend" then
			return "Ranger Lee (pretending)", "Practice roleplay"
		end
	end
	local sp = sid and Shared.speakers[sid]
	if sp then
		return sp.name, sp.label
	end
	return npcDef.displayName, (session.enc and session.enc.label) or npcDef.label
end

-- Visible choices with generated fact lists expanded (cara_tell).
local function choicesFor(player: Player, session: Session)
	local enc = session.enc
	local node = enc.nodes[session.nodeId]
	local list = {}
	local profile = profileOf(player)
	for _, choice in EncounterEngine.visibleChoices(enc, session.nodeId :: string, ctxFor(player, session)) do
		if choice.generated == "facts" then
			local story = session.story
			local beat = node.factsBeat or (story and (story.aboutBeat or story.creditBeat))
			local facts = beat and onFile(player)[beat]
			if facts and profile then
				for _, factId in Content.factOrder do
					local def = Content.facts[factId]
					if facts[factId] and def.beat == beat then
						local c = table.clone(choice)
						c.id = factId
						c.text = def.says
						c.generated = nil
						table.insert(list, c)
					end
				end
			end
		else
			table.insert(list, choice)
		end
	end
	return list
end

local function isLeeSpeaking(session: Session, node): boolean
	if node and node.pretend then
		return false
	end
	return session.npcId == HELP_NPC or (session.story ~= nil and session.story.narrator == HELP_NPC)
end

local function barOf(session: Session, kind: string): { string }
	local npcDef = Content.npcs[session.npcId]
	local enc = session.enc
	local node = enc and session.nodeId and enc.nodes[session.nodeId] or nil
	local story = session.story
	-- When Lee runs a roleplay, his own lines are a trusted adult's.
	local leeNarrates = story ~= nil and story.narrator == HELP_NPC and not (node ~= nil and node.pretend)
	return StoryRules.barFor({
		campaign = enc ~= nil and enc.campaign == true,
		role = if leeNarrates then "trusted_adult" else npcDef.role,
		isLee = isLeeSpeaking(session, node),
		rule = enc and enc.bar,
		concern = story ~= nil and story.concern,
		kind = kind,
		recovery = node ~= nil and node.recovery == true,
		pretend = node ~= nil and node.pretend == true,
		inReflect = (story ~= nil and story.returnTo ~= nil) or (node ~= nil and node.speaker == "tip"),
		hasReflect = enc ~= nil and enc.reflect ~= nil,
	})
end

-- What the client is shown now: { kind, speaker, name, label, text,
-- choices, bar, pal? }. Choice tables are the authored ones (ids/text are
-- formatted at send time).
local function currentView(player: Player, session: Session)
	local npcDef = Content.npcs[session.npcId]
	if session.kind == "card" then
		local card = session.card :: Card
		return {
			kind = "card",
			speaker = "card",
			name = npcDef.displayName,
			label = npcDef.label,
			text = if card.skipped then Shared.invitation.skipped else card.text,
			choices = if card.skipped then Shared.invitation.skippedChoices else card.choices,
			bar = barOf(session, "card"),
		}
	end
	if session.kind == "tell" then
		local view = LeeTell.view(session.tell, session.enc, FACT_REG, onFile(player))
		return {
			kind = "node",
			speaker = "npc",
			name = npcDef.displayName,
			label = npcDef.label,
			text = view.text,
			choices = view.choices,
			bar = { "leave" },
		}
	end
	if session.tipPending then
		return {
			kind = "tip",
			speaker = "tip",
			name = npcDef.displayName,
			text = Shared.practiceTip.text,
			choices = Shared.practiceTip.choices,
			bar = barOf(session, "tip"),
		}
	end
	if session.feedback then
		return {
			kind = "feedback",
			speaker = "tip",
			name = npcDef.displayName,
			text = session.feedback.text,
			choices = session.feedback.choices,
			bar = barOf(session, "feedback"),
		}
	end
	if not session.enc then
		return {
			kind = "node",
			speaker = "npc",
			name = npcDef.displayName,
			label = npcDef.label,
			text = npcDef.idleLine or "Hi!",
			choices = { { id = "bye", text = "Bye!" } },
			bar = barOf(session, "node"),
		}
	end
	local node = session.enc.nodes[session.nodeId]
	local name, label = speakerOf(session, node)
	local rendered = session.rendered
	local pal = rendered and rendered.nodeId == session.nodeId and rendered.pal or nil
	return {
		kind = if node.speaker == "tip" then "tip" else "node",
		speaker = node.speaker,
		name = name,
		label = label,
		text = if rendered and rendered.nodeId == session.nodeId then rendered.text else node.text,
		choices = choicesFor(player, session),
		bar = barOf(session, "node"),
		pal = if pal and not session.palAnswered[session.nodeId] then pal else nil,
	}
end

-- Facts are recorded when the node that presents them is shown, never for
-- nodes the player didn't see. Tip/feedback text adds no facts.
local function recordFacts(player: Player, session: Session)
	local enc = session.enc
	local node = enc and session.nodeId and enc.nodes[session.nodeId]
	if not node or session.kind ~= "scene" then
		return
	end
	local list = table.clone(node.facts or {})
	local rendered = session.rendered
	if rendered and rendered.nodeId == session.nodeId then
		for _, f in rendered.facts do
			table.insert(list, f)
		end
	end
	local fresh = {}
	for _, fact in list do
		if not session.facts[fact] then
			session.facts[fact] = true
			table.insert(fresh, fact)
		end
		local def = Content.facts[fact]
		if session.story and def and def.concerning then
			session.story.concern = true
		end
	end
	if #fresh > 0 then
		EventBus.publish("encounter.facts_presented", player, {
			encounterId = enc.id,
			npcId = session.npcId,
			nodeId = session.nodeId,
			facts = fresh,
		})
	end
end

local function send(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local npcDef = Content.npcs[session.npcId]
	local view = currentView(player, session)
	-- tip_practice_tools: once, the first time a bar with Block/Report shows.
	if view.kind == "node" and session.kind == "scene" then
		local flags = storyFlags(profileOf(player))
		if StoryRules.needsPracticeTip(flags, view.bar) then
			flags.practiceTipShown = true
			session.tipPending = true
			view = currentView(player, session)
		end
	end
	session.rev += 1
	if not session.tipPending and not session.feedback then
		recordFacts(player, session)
	end
	local v = vars(player, npcDef)
	local choices = {}
	for _, c in view.choices do
		table.insert(choices, { id = c.id, text = EncounterEngine.format(c.text, v) })
	end
	local pal = nil
	if view.pal then
		pal = { text = EncounterEngine.format(view.pal.text, v), choices = PAL_CHOICES }
	end
	S.Net.push(player, Remotes.PushKinds.Dialogue, {
		sessionId = session.id,
		rev = session.rev,
		npcId = session.npcId,
		npcName = view.name,
		subtitle = npcDef.subtitle,
		label = view.label,
		speaker = view.speaker,
		text = EncounterEngine.format(view.text, v),
		choices = choices,
		bar = view.bar,
		pal = pal,
		safetyTools = StoryRules.hasBarTool(view.bar, "block"),
	})
end

-- Moves a scene to a node: renders its text once (addText conditions are
-- read now, before the node's own marks), applies marks, then sends.
local function enterNode(player: Player, session: Session, nodeId: string)
	session.nodeId = nodeId
	local node = session.enc.nodes[nodeId]
	local ctx = ctxFor(player, session)
	local text = node.text
	if node.variants then
		local key = if node.variantBy == "aboutOutcome"
			then aboutOutcome(player, session)
			else (session.story and session.story.outcome)
		text = key and node.variants[key] or text
	end
	local extraFacts = {}
	local pal = node.palCard
	for _, extra in node.addText or {} do
		if ctx.profile and Conditions.evaluate(extra.conditions, ctx) then
			text ..= " " .. extra.text
			for _, f in extra.facts or {} do
				table.insert(extraFacts, f)
			end
			if extra.palCard then
				pal = extra.palCard
			end
		end
	end
	session.rendered = { nodeId = nodeId, text = text, facts = extraFacts, pal = pal }
	local flags = storyFlags(ctx.profile)
	if flags then
		for _, mark in node.marks or {} do
			flags[mark] = true
		end
	end
	if session.story then
		session.story.visited[nodeId] = true
	end
	send(player)
end

-- Every way a conversation can end goes through here, with a kind:
--   completed   the graph reached an outcome (outcome given)
--   walk_away   the player closed the panel or walked out of range
--   help        Help preempted it
--   blocked / reported   a practice safety tool (published when the tool is
--               used, before its feedback card)
--   replaced    another conversation started
--   forced      another panel took over (cards only)
--   respawn / disconnect
-- The exit event carries the facts this session presented, so listeners
-- (story progress) can tell "left before anything concerning" from "left
-- after a concerning request" without guessing. Campaign scenes add their
-- outcome code (StoryRules.exitOutcome) and scene details.
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
	if session.kind == "card" then
		local card = session.card :: Card
		if not card.skipped and S.Story then
			S.Story.onCardDismissed(player, card, kind or "walk_away")
		end
		return
	end
	if session.enc and not session.exited then
		publishExit(player, session, kind or "walk_away", outcome)
	end
	local story = session.story
	if story and story.concern and story.creditBeat and kind ~= "help" then
		recentConcern[player] = { beat = story.creditBeat, at = os.clock() }
	end
	if session.exitInfo then
		EventBus.publish("encounter.closed", player, session.exitInfo)
	end
end

-- Exactly one exit event per session.
publishExit = function(player: Player, session: Session, kind: string, outcome: string?)
	if session.exited then
		return
	end
	session.exited = true
	local facts = {}
	for fact in session.facts do
		table.insert(facts, fact)
	end
	local story = session.story
	local node = session.enc.nodes[session.nodeId or ""]
	local atRecovery = node ~= nil and node.recovery == true
	local final = outcome
	if story then
		if story.outcome and kind == "completed" then
			final = story.outcome
		else
			final = StoryRules.exitOutcome(story, kind, outcome, atRecovery)
		end
	end
	local visited = {}
	for nodeId in story and story.visited or {} do
		table.insert(visited, nodeId)
	end
	local info = {
		encounterId = session.enc.id,
		npcId = session.npcId,
		arcId = session.arcId,
		nodeId = session.nodeId,
		kind = kind,
		outcome = final,
		facts = facts,
		sceneKind = story and story.kind,
		beat = story and story.beat,
		aboutBeat = story and story.aboutBeat,
		atRecovery = atRecovery,
		visited = visited,
	}
	session.exitInfo = info
	EventBus.publish("encounter.exited", player, info)
end

local function finish(player: Player, outcome: string, kind: string?)
	local session = sessions[player]
	endSession(player, kind or "completed", outcome)
	if not session or not session.enc then
		return
	end
	local profile = profileOf(player)
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

type BeginOpts = { aboutBeat: string?, narrator: string? }

local function begin(player: Player, npcId: string, model: Model?, locationId: string?, remote: boolean, forced: any?, opts: BeginOpts?)
	local profile = profileOf(player)
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
	local story: Story? = nil
	if enc and enc.campaign then
		story = {
			kind = enc.sceneKind,
			beat = if enc.roleplayFor then nil else enc.beat,
			creditBeat = enc.roleplayFor or enc.beat,
			aboutBeat = (opts and opts.aboutBeat) or enc.aboutBeat,
			concern = false,
			refused = false,
			agreed = false,
			outcome = nil,
			returnTo = nil,
			narrator = opts and opts.narrator,
			visited = {},
		}
	end
	local session: Session = {
		kind = "scene",
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
		story = story,
		palAnswered = {},
	}
	sessions[player] = session
	if story and story.beat then
		-- Talk on the invitation, or walking up to the beat's character.
		S.Progression.schedule(player, { kind = "accepted", beat = story.beat })
	end
	if enc then
		enterNode(player, session, enc.start)
	else
		send(player)
	end
end

-- True while the player is in any conversation, card or Help scene.
function Encounter.isActive(player: Player): boolean
	return sessions[player] ~= nil
end

-- The id of the scene the player is in, if any (cards and tell included).
function Encounter.currentId(player: Player): string?
	local session = sessions[player]
	if not session then
		return nil
	end
	if session.kind == "card" then
		return "card:" .. (session.card :: Card).sceneId
	end
	return session.enc and session.enc.id or nil
end

-- Starts a campaign scene in place (remote: no walking needed).
function Encounter.startScene(player: Player, sceneId: string, opts: BeginOpts?)
	local enc = Content.encounters[sceneId]
	if not enc then
		warn(`[Encounter] unknown scene {sceneId}`)
		return
	end
	if sceneId == TELL_ENCOUNTER then
		Encounter.startTell(player, "general", opts and opts.aboutBeat, false)
		return
	end
	begin(player, enc.npcId, nil, nil, true, enc, opts)
end

-- Ranger Lee's tell menu. mode "ctx" is tied to one beat; without a beat
-- (or with no facts on file at all) it opens in general mode.
function Encounter.startTell(player: Player, mode: string, beat: string?, withCara: boolean?)
	local profile = profileOf(player)
	if not profile then
		return
	end
	endSession(player, "replaced")
	nextSessionId += 1
	local useCtx = mode == "ctx" and beat ~= nil
	sessions[player] = {
		kind = "tell",
		rev = 0,
		facts = {},
		id = nextSessionId,
		npcId = HELP_NPC,
		remote = true,
		enc = Content.encounters[TELL_ENCOUNTER],
		nodeId = nil,
		tell = LeeTell.open(FACT_REG, onFile(player), if useCtx then "ctx" else "general", beat, withCara),
		palAnswered = {},
	}
	send(player)
end

-- Opens a card (invitation or follow-up offer). Never over another
-- conversation. Returns whether it showed.
function Encounter.offer(player: Player, card: Card): boolean
	if sessions[player] or not Content.npcs[card.npcId] then
		return false
	end
	nextSessionId += 1
	sessions[player] = {
		kind = "card",
		rev = 0,
		facts = {},
		id = nextSessionId,
		npcId = card.npcId,
		remote = true,
		card = card,
		palAnswered = {},
	}
	send(player)
	return true
end

-- Opens help from anywhere. Never gated. Help preempts whatever is open;
-- that scene ends with exit kind "help" (owner decision: a safe exit,
-- Sparkz never resumes that pressure). After a concerning request Lee
-- opens his tell menu for that beat (contextual); otherwise the general
-- help hub.
function Encounter.startHelp(player: Player)
	local session = sessions[player]
	local story = session and session.story
	local beat = story and story.concern and story.creditBeat or nil
	local recent = recentConcern[player]
	if not beat and not session and recent and os.clock() - recent.at <= RECENT_SECONDS then
		beat = recent.beat
	end
	recentConcern[player] = nil
	endSession(player, "help")
	local profile = profileOf(player)
	if profile then
		profile.learning.toolsPracticed.help = true
	end
	if beat then
		Encounter.startTell(player, "ctx", beat, false)
	else
		begin(player, HELP_NPC, nil, nil, true, Content.encounters[HELP_ENCOUNTER])
	end
	S.Net.push(player, Remotes.PushKinds.Waypoint, { placeId = "ranger_station", reason = "help" })
	S.Pet.react(player, "comfort")
end

function Encounter.interact(player: Player, model: Model)
	local npcId = model:GetAttribute("NpcId")
	local npcDef = npcId and Content.npcs[npcId]
	local profile = profileOf(player)
	if not npcDef or not profile then
		return
	end
	if not S.NPC.isNear(player, model, TALK_DISTANCE) then
		return
	end
	-- Story-only characters exist for a player only while their story is open.
	if npcDef.storyOnly and not (S.Story and S.Story.presence(player)[npcId]) then
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

-- After a scene ends by a choice: run what the choice asked for next.
local function afterChoice(player: Player, session: Session, choice, actx)
	if choice.farewell then
		local name = speakerOf(session, session.enc and session.enc.nodes[session.nodeId])
		S.Net.toast(player, `{name}: {choice.farewell}`, "info")
	end
	local spec = actx.openScene
	if spec then
		local story = session.story
		local beat = spec.beat or (story and (story.creditBeat or story.aboutBeat))
		if spec.scene == TELL_ENCOUNTER then
			Encounter.startTell(player, spec.mode or "general", beat, false)
		else
			Encounter.startScene(player, spec.scene, {
				aboutBeat = beat,
				narrator = spec.narrator or (story and story.narrator),
			})
		end
	elseif actx.openHelp then
		Encounter.startHelp(player)
	end
end

local function chooseCard(player: Player, session: Session, choiceId: any): (boolean, string?)
	local card = session.card :: Card
	local shown = if card.skipped then Shared.invitation.skippedChoices else card.choices
	local valid = false
	for _, c in shown do
		if c.id == choiceId then
			valid = true
		end
	end
	if not valid then
		return false, "choice not available"
	end
	if card.skipped then
		endSession(player, "completed")
		return true
	end
	if choiceId == "skip" then
		S.Story.onCard(player, card, choiceId)
		card.skipped = true
		send(player)
		return true
	end
	-- Close the card quietly first, so a scene it starts isn't a "replace".
	card.skipped = true
	endSession(player, "completed")
	card.skipped = false
	S.Story.onCard(player, card, choiceId)
	return true
end

local function chooseTell(player: Player, session: Session, choiceId: any): (boolean, string?)
	local ok, result = LeeTell.choose(session.tell, session.enc, FACT_REG, onFile(player), choiceId)
	if not ok then
		return false, "choice not available"
	end
	if result.told then
		-- Lee rule: both Reach Out slots for an e2-e5 beat; E1 earns nothing
		-- (the ledger refuses unassessed beats).
		ActionService.run(player, {
			{ action = "learning", kind = "told_lee", beat = result.beat },
			{ action = "learning", kind = "coaching_cleared", beat = result.beat },
		}, { encounterId = TELL_ENCOUNTER })
	end
	if result.ended then
		finish(player, "done")
	else
		send(player)
	end
	return true
end

local function choose(player: Player, payload: any): (boolean, string?)
	local session = validSession(player, payload)
	if not session then
		return false, nil
	end
	local choiceId = payload.choiceId

	if session.kind == "card" then
		return chooseCard(player, session, choiceId)
	end
	if session.kind == "tell" then
		return chooseTell(player, session, choiceId)
	end

	if session.tipPending then
		if choiceId ~= "ok" then
			return false, "unknown choice"
		end
		session.tipPending = false
		send(player)
		return true
	end

	if session.feedback then
		local fb = session.feedback
		local valid = false
		for _, c in fb.choices do
			if c.id == choiceId then
				valid = true
			end
		end
		if not valid then
			return false, "unknown choice"
		end
		if fb.thenNode then
			-- Roleplay: the pretend player was blocked/reported; on to the debrief.
			session.feedback = nil
			enterNode(player, session, fb.thenNode)
			return true
		end
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

	-- The practice Pal Request card: recorded only, scores nothing.
	local rendered = session.rendered
	if (choiceId == "pal_accept" or choiceId == "pal_decline")
		and rendered and rendered.nodeId == session.nodeId and rendered.pal
		and not session.palAnswered[session.nodeId]
	then
		session.palAnswered[session.nodeId] = true
		local flags = storyFlags(profileOf(player))
		local key = rendered.pal.record
		if flags and (key == "palChoice" or key == "palRepeat") then
			flags[key] = if choiceId == "pal_accept" then "accepted" else "declined"
		end
		send(player)
		return true
	end

	local choice = nil
	if typeof(choiceId) == "string" then
		for _, c in choicesFor(player, session) do
			if c.id == choiceId then
				choice = c
				break
			end
		end
	end
	if not choice then
		return false, "choice not available"
	end
	if choice.next and not session.enc.nodes[choice.next] then
		return false, "broken content"
	end

	local story = session.story
	local actx = {
		npcId = session.npcId,
		arcId = session.arcId,
		encounterId = session.enc.id,
		aboutBeat = story and (story.aboutBeat or story.creditBeat),
		openHelp = false,
		endNow = false,
		openScene = nil,
	}
	ActionService.run(player, choice.actions, actx)
	if story then
		if choice.refused then
			story.refused = true
		end
		if choice.agree then
			story.agreed = true
		end
		if choice.settle then
			story.outcome = choice.settle
		end
	end

	if choice.back then
		local target = story and story.returnTo or session.enc.start
		if story then
			story.returnTo = nil
		end
		enterNode(player, session, target)
	elseif choice.next == nil or actx.endNow then
		finish(player, choice.outcome or "done")
		afterChoice(player, session, choice, actx)
	else
		enterNode(player, session, choice.next)
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
	local force = payload.force == true
	if session.kind == "card" then
		endSession(player, if force then "forced" else "walk_away")
		return true
	end
	if session.kind == "tell" then
		-- Leave = "That's all I want to say." Lee still gets a warm last line.
		if force or LeeTell.leave(session.tell) then
			endSession(player, "walk_away")
		else
			send(player)
		end
		return true
	end
	if session.tipPending then
		endSession(player, "walk_away")
		return true
	end
	if session.feedback or not session.enc then
		return choose(player, { sessionId = session.id, rev = session.rev, choiceId = "ok" })
	end
	local enc = session.enc
	local node = enc.nodes[session.nodeId]
	local story = session.story
	if story and node.pretend and not force then
		-- Roleplay: Leave stops the pretend player and goes to the debrief,
		-- with the same credit as leaving a live scene (rule A).
		if story.concern then
			ActionService.run(player, { { action = "learning", kind = "left_after_request" } }, { encounterId = enc.id })
		end
		story.outcome = StoryRules.exitOutcome(story, "walk_away", nil)
		enterNode(player, session, "debrief")
		return true
	end
	if node.speaker == "tip" then
		if story then
			-- A campaign tip (a reflection) never picks an answer on close.
			endSession(player, "walk_away")
			return true
		end
		-- Closing a tip card = its first choice (keeps the outcome recorded).
		-- A forced close (another panel took over) must not move on to a
		-- further node, which would reopen the conversation.
		local first = node.choices[1]
		if not force or first.next == nil then
			return choose(player, { sessionId = session.id, rev = session.rev, choiceId = first.id })
		end
		endSession(player, "walk_away")
		return true
	end
	if enc.onWalkAway and session.nodeId ~= enc.onWalkAway and not force then
		enterNode(player, session, enc.onWalkAway)
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
	local tool = payload.tool
	local enc = session.enc
	if tool == "help" then
		-- Help is never refused, from any node, card or feedback.
		if session.kind == "scene" and enc and enc.completeOnSafetyTool == true and not session.exited then
			finish(player, "sought_help", "help") -- a safe exit, not a plain completion
		end
		Encounter.startHelp(player) -- ends any remaining scene with kind "help"
		return true
	end
	-- One safety tool per scene: once its feedback card is showing (and its
	-- exit published), further tool requests are refused.
	if session.kind ~= "scene" or session.feedback or session.exited or session.tipPending then
		return false, nil
	end
	local view = currentView(player, session)
	if typeof(tool) ~= "string" or not StoryRules.hasBarTool(view.bar, tool) then
		return false, "Not available here."
	end
	local npcDef = Content.npcs[session.npcId]
	local story = session.story
	local node = enc and enc.nodes[session.nodeId]

	if tool == "off" then
		-- "Something feels off": the scene's reflection, then back.
		if not story or not enc.reflect then
			return false, "Not available here."
		end
		story.returnTo = session.nodeId
		enterNode(player, session, enc.reflect)
		return true
	end
	if tool ~= "block" and tool ~= "report" then
		return false, "Not available here."
	end

	if story and node and node.pretend then
		-- Blocking the pretend player never blocks Cara (section 8).
		if story.concern then
			ActionService.run(player, { { action = "learning", kind = "left_after_request" } }, { encounterId = enc.id })
		end
		story.outcome = if tool == "block" then "blocked" else "reported"
		session.feedback = {
			text = if tool == "block" then Shared.feedback.fb_block_roleplay else Shared.feedback.fb_report_roleplay,
			outcome = story.outcome,
			complete = false,
			choices = Shared.feedback.choices,
			thenNode = "debrief",
		}
		send(player)
		return true
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
	local campaign = enc ~= nil and enc.campaign == true
	local text
	if campaign then
		text = if tool == "block" then Shared.feedback.fb_block else Shared.feedback.fb_report
	else
		text = Content.safetyFeedback[tool]
	end
	session.feedback = {
		text = EncounterEngine.format(text, vars(player, npcDef)),
		outcome = tool == "block" and "blocked" or "reported",
		complete = enc ~= nil and enc.completeOnSafetyTool == true,
		choices = if campaign then Shared.feedback.choices else SessionRules.FEEDBACK_CHOICES,
	}
	send(player)
	return true
end

function Encounter.init(services)
	S = services

	local function npcState(player: Player, npcId: string)
		local profile = profileOf(player)
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
	-- Opens another campaign scene after this one ends (lee_tell, a Cara
	-- walk, a roleplay). The new scene inherits the beat it is about.
	ActionService.register("open_scene", function(player, spec, ctx)
		if typeof(spec.scene) ~= "string" or Content.encounters[spec.scene] == nil then
			return false, "unknown scene"
		end
		if ctx.encounterId then
			ctx.openScene = spec
		else
			Encounter.startScene(player, spec.scene, { aboutBeat = spec.beat, narrator = spec.narrator })
		end
		return true
	end)
	ActionService.register("end_conversation", function(_player, _spec, ctx)
		ctx.endNow = true
		return true
	end)
	ActionService.register("record_learning", function(player, spec)
		local profile = profileOf(player)
		if profile and typeof(spec.topic) == "string" then
			profile.learning.topicsSeen[spec.topic] = true
		end
		return true
	end)
	ActionService.register("set_arc_flag", function(player, spec, ctx)
		local profile = profileOf(player)
		local arc = profile and ctx.arcId and profile.arcs[ctx.arcId]
		if not arc then
			return false, "no arc"
		end
		arc.flags[spec.key] = spec.value
		return true
	end)
	ActionService.register("show_waypoint", function(player, spec)
		S.Net.push(player, Remotes.PushKinds.Waypoint, { placeId = spec.placeId, seconds = spec.seconds })
		return true
	end)
end

function Encounter.start()
	local problems = EncounterEngine.validate(Content, ActionService.has)
	for _, problem in problems do
		warn("[Content] " .. problem)
	end

	EventBus.subscribe("activity.completed", function(player, info)
		local profile = profileOf(player)
		if profile then
			EncounterEngine.noteActivity(profile)
		end
		if typeof(info.activityId) == "string" then
			lastActivity[player] = info.activityId
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
		local profile = profileOf(player)
		local npcId = typeof(payload) == "table" and payload.npcId or nil
		local state = profile and typeof(npcId) == "string" and profile.npcs[npcId]
		if not state then
			return false, "Not blocked."
		end
		state.blocked = false
		EventBus.publish("encounter.unblocked", player, { npcId = npcId })
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
		lastActivity[player] = nil
		recentConcern[player] = nil
	end)
	local function watchRespawn(player: Player)
		player.CharacterAdded:Connect(function()
			local session = sessions[player]
			-- Help, Lee's tell menu and cards survive a respawn; a story
			-- beat started in place (from its invitation) does not.
			if session and (not session.remote or (session.story ~= nil and session.story.beat ~= nil)) then
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

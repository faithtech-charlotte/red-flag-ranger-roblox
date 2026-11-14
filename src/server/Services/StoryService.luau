--[[
	StoryService: the practice-story flow around the scenes themselves.

	  * Onboarding: Lee's welcome by park radio right after adoption, then
	    Cara's intro, then the campaign starts (scheduler onboarding_done).
	    Any exit marks a scene seen. If the welcome closed before the
	    practice-story disclosure, the first invitation card carries it.
	  * Invitation cards (Talk / Later / Skip this story) for the beat or
	    ambient scene ProgressionService.consider picked.
	  * Cara's follow-up offer after a beat ("Cara waves." Talk / Not now):
	    at most one per beat, never after skip, defer, help or recovery.
	  * Cara's "Let's talk to Lee together" walk: a waypoint to Ranger HQ;
	    arriving opens Lee's tell menu for that beat with Cara. Leaving the
	    path quietly times out. Remote Help always works.
	  * Presence: which story-only NPCs (Sparkz_Pup) a player can see.

	Everything here is decided on the server from the player's own profile.
	Clients only ever send choice ids.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionService = require(script.Parent.Parent.Core.ActionService)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local Content = require(script.Parent.Parent.Content)
local StoryRules = require(script.Parent.Parent.Logic.StoryRules)
local Places = require(ReplicatedStorage.Shared.Places)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LOOP_SECONDS = 1
local ONBOARD_DELAY = 2 -- seconds after load/adoption before Lee's radio call
local WALK_SECONDS = 180
local FOLLOW_UP_WINDOW = 60 -- a busy player still gets the offer within this

local Story = {}
local S
local loadedAt: { [Player]: number } = {}
local walks: { [Player]: { beat: string, untilTime: number } } = {}
local pendingFollowUp: { [Player]: { beat: string, untilTime: number } } = {}

-- Beats that have a live scene in this build ({ [beat] = true }).
local available: { [string]: boolean } = {}
for beat in Content.beatScenes do
	available[beat] = true
end
Story.available = available

local function flags(profile)
	if typeof(profile.story) ~= "table" then
		profile.story = StoryRules.defaultStory()
	end
	return profile.story
end

local function blocked(profile, npcId: string): boolean
	local state = profile.npcs[npcId]
	return state ~= nil and state.blocked == true
end

function Story.presence(player: Player): { [string]: boolean }
	local profile = S.Data.get(player)
	if not profile then
		return {}
	end
	return StoryRules.presence(profile.campaign, profile.npcs, available)
end

-- The ambient Cara scene to offer now, if any (for the scheduler).
function Story.ambient(player: Player): string?
	local profile = S.Data.get(player)
	if not profile then
		return nil
	end
	return StoryRules.ambientFor(profile.campaign, flags(profile), profile.npcs)
end

-- A Cara walk in progress suppresses new invitations.
function Story.busy(player: Player): boolean
	return walks[player] ~= nil
end

local function cardText(profile, text: string): string
	local f = flags(profile)
	if f.disclosurePending then
		f.disclosurePending = false
		return `{Content.campaign.invitation.disclosure} {text}`
	end
	return text
end

-- Shows the invitation for a scheduler decision. Returns whether a card
-- (or a silent skip) happened.
function Story.invite(player: Player, decision): boolean
	local profile = S.Data.get(player)
	if not profile or S.Encounter.isActive(player) then
		return false
	end
	if decision.kind == "campaign" then
		local sceneId = Content.beatScenes[decision.beat]
		local enc = sceneId and Content.encounters[sceneId]
		if not enc then
			return false
		end
		if not S.Progression.schedule(player, { kind = "invited", beat = decision.beat }) then
			return false
		end
		if blocked(profile, enc.npcId) then
			-- A blocked healthy character: the step is satisfied, quietly.
			S.Progression.schedule(player, { kind = "skip", beat = decision.beat })
			return true
		end
		local shown = S.Encounter.offer(player, {
			kind = "campaign",
			sceneId = sceneId,
			beat = decision.beat,
			npcId = enc.npcId,
			text = cardText(profile, enc.invitation.text),
			choices = Content.campaign.invitation.choices,
		})
		if not shown then
			-- Something opened in between: hand the beat back (gap stays).
			S.Progression.schedule(player, { kind = "interrupted", beat = decision.beat })
		end
		return shown
	elseif decision.kind == "ambient" then
		local enc = Content.encounters[decision.id]
		if not enc or blocked(profile, enc.npcId) then
			return false
		end
		S.Progression.schedule(player, { kind = "ambient_invited" })
		return S.Encounter.offer(player, {
			kind = "ambient",
			sceneId = decision.id,
			npcId = enc.npcId,
			text = cardText(profile, enc.invitation.text),
			choices = Content.campaign.invitation.choices,
		})
	end
	return false
end

-- A card choice (the card is already closed, except for "skip").
function Story.onCard(player: Player, card, choiceId: string)
	local profile = S.Data.get(player)
	if not profile then
		return
	end
	if card.kind == "campaign" then
		if choiceId == "talk" then
			S.Encounter.startScene(player, card.sceneId)
		elseif choiceId == "later" then
			S.Progression.schedule(player, { kind = "later", beat = card.beat })
		elseif choiceId == "skip" then
			S.Progression.schedule(player, { kind = "skip", beat = card.beat })
		end
	elseif card.kind == "ambient" then
		if choiceId == "talk" then
			S.Encounter.startScene(player, card.sceneId)
		elseif choiceId == "skip" then
			flags(profile).seen[card.sceneId] = true
			S.Data.checkpoint(player, "story")
		end
	elseif card.kind == "followUp" then
		if choiceId == "talk" then
			S.Encounter.startScene(player, card.sceneId, { aboutBeat = card.beat })
		end
		-- "Not now": no line, no nag.
	end
end

-- A card closed without a choice. Closing it yourself = Later; anything
-- else (another panel, Help, a new conversation, leaving) only interrupts,
-- and the pacing gap keeps it from coming straight back.
function Story.onCardDismissed(player: Player, card, kind: string)
	if card.kind ~= "campaign" then
		return
	end
	if kind == "walk_away" then
		S.Progression.schedule(player, { kind = "later", beat = card.beat })
	else
		S.Progression.schedule(player, { kind = "interrupted", beat = card.beat })
	end
end

local function offerFollowUp(player: Player, beat: string): boolean
	local profile = S.Data.get(player)
	local sceneId = `cara_fu_{beat}`
	if not profile or not Content.encounters[sceneId] then
		return true -- nothing to offer; drop it
	end
	local f = flags(profile)
	if f.followUpOffered[beat] or blocked(profile, StoryRules.CARA_NPC) then
		return true
	end
	if S.InteractionState.busy(player) then
		return false
	end
	local card = Content.campaign.followUpCard
	if S.Encounter.offer(player, {
		kind = "followUp",
		sceneId = sceneId,
		beat = beat,
		npcId = StoryRules.CARA_NPC,
		text = card.text,
		choices = card.choices,
	}) then
		f.followUpOffered[beat] = true
		S.Data.checkpoint(player, "story")
		return true
	end
	return false
end

-- A scene ended (exit info from EncounterService).
local function onClosed(player: Player, info)
	local profile = S.Data.get(player)
	if not profile then
		return
	end
	local f = flags(profile)
	local id = info.encounterId
	if info.beat and info.outcome and not StoryRules.INTERRUPTIONS[info.kind] then
		f.outcomes[info.beat] = info.outcome
	end
	local def = id and Content.encounters[id]
	if def and def.campaign and (def.sceneKind == "onboarding" or def.sceneKind == "ambient") then
		f.seen[id] = true
		if id == "onb_lee_welcome" and not f.disclosed then
			f.disclosurePending = true
		end
	end
	if info.beat and StoryRules.followUpAllowed(info.sceneKind, info.kind, info.outcome or "", info.atRecovery == true) then
		pendingFollowUp[player] = { beat = info.beat, untilTime = os.clock() + FOLLOW_UP_WINDOW }
	end
	S.Data.checkpoint(player, "story")
end

-- Onboarding, one step per loop pass while the player is free.
local function onboard(player: Player, profile)
	if profile.campaign.onboarded or not profile.activePetId then
		return
	end
	if os.clock() - (loadedAt[player] or os.clock()) < ONBOARD_DELAY then
		return
	end
	if S.InteractionState.busy(player) then
		return
	end
	local f = flags(profile)
	if not f.seen.onb_lee_welcome then
		S.Encounter.startScene(player, "onb_lee_welcome")
	elseif not f.seen.onb_cara_intro and not blocked(profile, StoryRules.CARA_NPC) then
		S.Encounter.startScene(player, "onb_cara_intro")
	else
		S.Progression.schedule(player, { kind = "onboarding_done" })
	end
end

local function stepWalk(player: Player)
	local walk = walks[player]
	if not walk then
		return
	end
	if os.clock() > walk.untilTime or S.Activity.current(player) then
		walks[player] = nil -- left the path: cancel quietly
		return
	end
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp and Places.isInside("ranger_station", hrp.Position) and not S.Encounter.isActive(player) then
		walks[player] = nil
		S.Encounter.startTell(player, "ctx", walk.beat, true)
	end
end

local function loop()
	for _, player in Players:GetPlayers() do
		local profile = S.Data.get(player)
		if profile then
			local ok, err = pcall(function()
				onboard(player, profile)
				stepWalk(player)
				local pending = pendingFollowUp[player]
				if pending then
					if os.clock() > pending.untilTime or offerFollowUp(player, pending.beat) then
						pendingFollowUp[player] = nil
					end
				end
			end)
			if not ok then
				warn(`[Story] {err}`)
			end
		end
	end
end

function Story.init(services)
	S = services
	ActionService.register("walk_to_lee", function(player, _spec, ctx)
		local beat = ctx.aboutBeat
		if typeof(beat) ~= "string" then
			return false, "no beat"
		end
		walks[player] = { beat = beat, untilTime = os.clock() + WALK_SECONDS }
		S.Net.push(player, Remotes.PushKinds.Waypoint, { placeId = "ranger_station", seconds = WALK_SECONDS, reason = "cara" })
		return true
	end)
end

function Story.start()
	S.Data.onLoaded(function(player, profile)
		profile.story = StoryRules.sanitize(profile.story)
		loadedAt[player] = os.clock()
	end)
	EventBus.subscribe("pet.adopted", function(player)
		loadedAt[player] = os.clock()
	end)
	EventBus.subscribe("encounter.closed", onClosed)
	task.spawn(function()
		while true do
			task.wait(LOOP_SECONDS)
			loop()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		loadedAt[player] = nil
		walks[player] = nil
		pendingFollowUp[player] = nil
	end)
end

return Story

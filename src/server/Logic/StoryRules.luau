--[[
	StoryRules: pure rules for how practice-story scenes behave
	(docs/campaign-script.md section 1). EncounterService and StoryService
	call these; tests/StoryRules.spec and tests/StoryFlow.spec check them.

	  sanitize(raw)            profile.story: small, bounded story flags
	  barFor(info)             which bar buttons a node shows (1.3)
	  exitOutcome(...)         the outcome code a scene ends with (1.7)
	  followUpAllowed(...)     may Cara offer her follow-up card (4.4)
	  presence(...)            which story-only NPCs a player can see
	  ambientFor(...)          the ordinary Cara scene to offer, if any
	  needsPracticeTip(...)    tip_practice_tools shows once (1.5)
	  activityPhrase(id)       {activity} placeholder text (1.1)

	profile.story holds no evidence and no answers, only flags that change
	what text is shown (Pal choice, first recovery seen, the tip, which
	scenes were seen, each beat's last outcome for Cara's opener). It never
	leaves the server.
]]

local StoryRules = {}

StoryRules.MAX_SEEN = 64
StoryRules.MAX_ID = 40

local PAL = { none = true, accepted = true, declined = true }
local FLAGS = { "recoverySeen", "practiceTipShown", "disclosed", "disclosurePending" }
local BEATS = { e1 = true, green_riley = true, e2 = true, e3 = true, e4 = true, e5 = true }
local OUTCOMES = {
	friendly = true, left = true, refused_held = true, refused_left = true,
	left_after_request = true, help_after_request = true, blocked = true, reported = true,
	agreed_retry_ok = true, agreed_to_lee = true, agreed_kept_playing = true,
}

StoryRules.SPARKZ_NPC = "sparkz_pup"
StoryRules.CARA_NPC = "cara"
StoryRules.SPARKZ_BEATS = { "e1", "e2", "e3", "e4" }
-- Statuses in which a beat's character is around to be walked up to.
StoryRules.OPEN = { eligible = true, invited = true, active = true, deferred = true }
StoryRules.DONE = { resolved = true, skipped = true, skipped_by_block = true }
StoryRules.INTERRUPTIONS = { replaced = true, respawn = true, disconnect = true }

local function validId(v: any): boolean
	return typeof(v) == "string" and #v > 0 and #v <= StoryRules.MAX_ID
end

function StoryRules.defaultStory()
	return {
		seen = {},
		palChoice = "none",
		palRepeat = "none",
		recoverySeen = false,
		practiceTipShown = false,
		disclosed = false,
		disclosurePending = false,
		outcomes = {},
		followUpOffered = {},
	}
end

function StoryRules.sanitize(raw)
	local s = StoryRules.defaultStory()
	if typeof(raw) ~= "table" then
		return s
	end
	if typeof(raw.seen) == "table" then
		local n = 0
		for id, v in raw.seen do
			if v == true and validId(id) and n < StoryRules.MAX_SEEN then
				s.seen[id] = true
				n += 1
			end
		end
	end
	if PAL[raw.palChoice] then
		s.palChoice = raw.palChoice
	end
	if PAL[raw.palRepeat] then
		s.palRepeat = raw.palRepeat
	end
	for _, flag in FLAGS do
		if typeof(raw[flag]) == "boolean" then
			s[flag] = raw[flag]
		end
	end
	if typeof(raw.outcomes) == "table" then
		for beat, outcome in raw.outcomes do
			if BEATS[beat] and OUTCOMES[outcome] then
				s.outcomes[beat] = outcome
			end
		end
	end
	if typeof(raw.followUpOffered) == "table" then
		for beat, v in raw.followUpOffered do
			if BEATS[beat] and v == true then
				s.followUpOffered[beat] = true
			end
		end
	end
	return s
end

--[[
	info = {
	  campaign: boolean      a campaign scene (else legacy rules)
	  role: string           the scene NPC's role
	  isLee: boolean         talking with Ranger Lee (Help would be redundant)
	  rule: "A"|"B"|"C"?     the scene's declared bar rule
	  concern: boolean       a concerning fact was shown in this scene
	  kind: "node"|"tip"|"card"|"feedback"
	  recovery, pretend, inReflect, hasReflect: boolean
	}
	Returns the bar ids in display order. Leave is always first and Help is
	always there (except with Lee himself), so exit and help never hide.
]]
function StoryRules.barFor(info): { string }
	local bar = { "leave" }
	if not info.isLee then
		table.insert(bar, "help")
	end
	if info.kind ~= "node" or info.recovery or info.inReflect then
		return bar
	end
	local peer = info.role == "peer"
	if not info.campaign then
		if peer then
			table.insert(bar, "block")
			table.insert(bar, "report")
		end
		return bar
	end
	if peer then
		table.insert(bar, "block")
		table.insert(bar, "report")
	end
	local rule = StoryRules.effectiveRule(info)
	if rule ~= "C" and info.hasReflect then
		table.insert(bar, "off")
	end
	return bar
end

-- A pretend node is rule A; a Cara/rookie scene stays C; otherwise A from
-- the first concerning fact, B before it.
function StoryRules.effectiveRule(info): string
	if info.pretend then
		return "A"
	end
	if info.rule == "C" then
		return "C"
	end
	if info.concern then
		return "A"
	end
	return "B"
end

function StoryRules.hasBarTool(bar: { string }, tool: string): boolean
	return table.find(bar, tool) ~= nil
end

--[[
	The outcome code a scene ends with (1.7, bar rules A/B).
	  story = { concern, refused, agreed }
	  kind  = exit kind (completed / walk_away / help / blocked / reported /
	          replaced / respawn / disconnect)
	  choiceOutcome = the authored outcome when kind == "completed"
	  atRecovery = the scene ended on a recover_* card
	Respawn and disconnect behave like Leave for credit (1.3). Leaving the
	recovery card is "Keep playing"; Help from it is "Talk to Lee".
]]
function StoryRules.exitOutcome(story, kind: string, choiceOutcome: string?, atRecovery: boolean?): string
	local o: string
	if atRecovery and kind ~= "completed" then
		return if kind == "help" then "agreed_to_lee" else "agreed_kept_playing"
	end
	if kind == "completed" then
		o = choiceOutcome or "friendly"
	elseif kind == "blocked" then
		o = "blocked"
	elseif kind == "reported" then
		o = "reported"
	elseif kind == "help" then
		o = if story.concern then "help_after_request" else "left"
	elseif story.concern and story.refused then
		o = "refused_left"
	elseif story.concern then
		o = "left_after_request"
	else
		o = "left"
	end
	-- After a simulated agreement, a later safe ending is a recovery.
	if story.agreed and (o == "refused_held" or o == "refused_left" or o == "left_after_request") then
		o = "agreed_retry_ok"
	end
	return o
end

local NO_FOLLOW_UP = {
	skipped = true,
	deferred = true,
	help_after_request = true, -- the player is with Lee; one card at most
	agreed_to_lee = true,
	agreed_kept_playing = true, -- ended in recovery, already Cara's card
}

-- May Cara offer her follow-up card after this beat scene?
function StoryRules.followUpAllowed(sceneKind: string?, kind: string, outcome: string, atRecovery: boolean): boolean
	if sceneKind ~= "beat" then
		return false
	end
	if StoryRules.INTERRUPTIONS[kind] or kind == "help" then
		return false
	end
	if atRecovery or NO_FOLLOW_UP[outcome] then
		return false
	end
	return true
end

--[[
	Which story-only NPCs this player can see. Sparkz is around while one of
	the player's Sparkz beats that has a scene is open, and never once
	blocked. Combined with blocking on the client into one rule.
	  campaign  EncounterScheduler state
	  npcs      profile.npcs
	  available { [beat] = true } beats that have a live scene
]]
function StoryRules.presence(campaign, npcs, available): { [string]: boolean }
	local out = {}
	local blocked = npcs and npcs[StoryRules.SPARKZ_NPC] and npcs[StoryRules.SPARKZ_NPC].blocked == true
	local visible = false
	if not blocked and typeof(campaign) == "table" and typeof(campaign.beats) == "table" then
		for _, beat in StoryRules.SPARKZ_BEATS do
			local status = campaign.beats[beat] or "not_started"
			if available[beat] and StoryRules.OPEN[status] then
				visible = true
				break
			end
		end
	end
	out[StoryRules.SPARKZ_NPC] = visible
	return out
end

-- The ordinary Cara scene to offer between beats, if any (Phase 2:
-- cara_talk_1 between E2 and E3).
function StoryRules.ambientFor(campaign, story, npcs): string?
	if typeof(campaign) ~= "table" or typeof(story) ~= "table" then
		return nil
	end
	local cara = npcs and npcs[StoryRules.CARA_NPC]
	if cara and cara.blocked then
		return nil
	end
	local e2 = campaign.beats and campaign.beats.e2 or "not_started"
	if StoryRules.DONE[e2] and not story.seen.cara_talk_1 then
		return "cara_talk_1"
	end
	return nil
end

function StoryRules.needsPracticeTip(story, bar: { string }): boolean
	if typeof(story) ~= "table" or story.practiceTipShown == true then
		return false
	end
	return StoryRules.hasBarTool(bar, "block") or StoryRules.hasBarTool(bar, "report")
end

local PHRASES = {
	fetch = "fetch",
	agility = "agility run",
	grooming = "spa day",
	trail_walk = "trail walk",
	trick_training = "trick practice", -- not in the 1.1 table; neutral phrase
}

function StoryRules.activityPhrase(activityId: string?): string
	return activityId and PHRASES[activityId] or "play"
end

return StoryRules

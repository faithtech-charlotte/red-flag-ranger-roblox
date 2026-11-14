--[[
	Sparkz_Pup encounters E1 and E2 (docs/campaign-script.md 6.1, 6.2).

	Campaign scene fields (all campaign scenes; checked by Logic/ContentCheck):
	  campaign = true, repeatable = true (the scheduler, not claims, decides)
	  id, contentVersion, reviewStatus, npcId
	  sceneKind      beat | healthy | onboarding | ambient | followup |
	                 roleplay | tell | walk | menu
	  beat           scheduler/ledger beat this scene IS (live scenes)
	  roleplayFor    the beat a Cara roleplay replaces (same facts and slots)
	  aboutBeat      the beat a follow-up, walk or tell is about
	  invitation     { text } for unsolicited scenes (the card, 1.4)
	  conditions     walk-up selection (EncounterEngine.select)
	  prerequisites, facts, outcomes, safeExits, recovery, skills,
	  targetSeconds  reviewer metadata
	  bar            default bar rule (A / B / C); A applies automatically
	                 from the first node that presents a concerning fact
	  reflect        node `bar_off` opens; its `back` choices return
	  start, nodes

	Node fields beyond EncounterEngine's:
	  speakerId   who speaks (Shared.speakers); default the scene's NPC
	  facts       facts presented when the node is shown
	  addText     { { text, conditions?, facts?, palCard? } } appended in order
	  palCard     the practice Pal Request card (records palChoice only)
	  variants    text by outcome (variantBy = "outcome" | "aboutOutcome")
	  recovery    true on recover_* nodes (Cara's one card; bar leave/help)
	  pretend     true on roleplay nodes where Cara plays the pretend player
	  marks       story flags set when the node is shown

	Choice fields beyond EncounterEngine's:
	  back        return to the node `bar_off` was pressed on
	  refused     a refusal at the request (for refused_held / refused_left)
	  agree       a simulated agreement (never plays out; goes to recovery)
	  generated   "facts": one choice per fact on file for the about beat
	  farewell    a parting line shown as a toast after the scene ends
	  settle      sets the scene's outcome while it continues (roleplay
	              pretend_bye -> debrief)

	Evidence comes only from `learning` actions and exit rules, never from
	text. Agreement buttons are generic labels: nothing is sent, no coins.
]]

local PROVISIONAL = "provisional"

local function learn(kind: string)
	return { action = "learning", kind = kind }
end

local function onBeat(beat: string, statuses: { string })
	return { { type = "campaignBeat", beat = beat, statuses = statuses } }
end

local OPEN = { "eligible", "deferred", "invited" }

local Sparkz = {}

----------------------------------------------------------------------------
-- 6.1 park_e1_hello
----------------------------------------------------------------------------

Sparkz.park_e1_hello = {
	id = "park_e1_hello",
	campaign = true,
	repeatable = true,
	contentVersion = 1,
	reviewStatus = PROVISIONAL,
	npcId = "sparkz_pup",
	sceneKind = "beat",
	beat = "e1",
	invitation = { text = "Sparkz_Pup is waving at you. (Story character)" },
	conditions = onBeat("e1", OPEN),
	prerequisites = { "onboarding seen", "first completed activity after onboarding" },
	targetSeconds = { 25, 35 },
	facts = { "e1_compliment", "e1_same_breed", "e1_pal_request" },
	outcomes = { "friendly", "left", "blocked", "reported" },
	safeExits = { "invitation_later", "invitation_skip", "bar_leave", "bar_help", "bar_block", "bar_report", "go" },
	recovery = {},
	skills = { "R3", "R4" },
	bar = "B",
	reflect = "reflect",
	start = "hello",
	nodes = {
		hello = {
			speaker = "npc",
			text = "Whoa, nice {activity}! Your {breed} is so good. Better than anyone here.",
			facts = { "e1_compliment" },
			choices = {
				{ id = "thanks", text = "Thanks!", next = "twin" },
				{ id = "hi", text = "Hi!", next = "twin" },
			},
		},
		twin = {
			speaker = "npc",
			text = "No way, mine's a {breed}, too! We're basically twins. I sent you a Pal Request.",
			facts = { "e1_same_breed", "e1_pal_request" },
			palCard = { text = "Sparkz_Pup wants to be Pals.", record = "palChoice" },
			choices = {
				{ id = "cute", text = "Thanks! Yours is cute too.", next = "bye" },
				{ id = "go", text = "Gotta go.", outcome = "left" },
			},
		},
		bye = {
			speaker = "npc",
			text = "See you around, twin!",
			choices = {
				{ id = "bye", text = "Bye!", outcome = "friendly" },
			},
		},
		reflect = {
			speaker = "tip",
			text = "You can take your time getting to know someone. A compliment by itself is okay. Matching dogs is fun, but it doesn't tell you much about a person. Keep noticing what people ask for.",
			choices = {
				{ id = "back", text = "Back to the conversation", back = true },
			},
		},
	},
}

----------------------------------------------------------------------------
-- 6.2 park_e2_deal
----------------------------------------------------------------------------

local RECOVERY_ASK = "You can change your mind. Want to try again, keep playing, or talk to Lee?"
local FIRST_RECOVERY = "In real games, nothing pauses for you. But you can always stop, change your mind, and tell someone, even after saying yes."

local function recoveryChoices(retryNode: string)
	return {
		{ id = "retry", text = "Let me try again.", next = retryNode },
		{
			id = "lee",
			text = "Talk to Lee.",
			outcome = "agreed_to_lee",
			actions = { { action = "open_scene", scene = "lee_tell", mode = "ctx" } },
		},
		{
			id = "play",
			text = "Keep playing.",
			outcome = "agreed_kept_playing",
			farewell = "Okay. I'm around if you want to practice later.",
		},
	}
end

local function firstRecoveryLines()
	return {
		{ text = FIRST_RECOVERY, conditions = { { type = "storyFlag", key = "recoverySeen", equals = false } } },
		{ text = RECOVERY_ASK },
	}
end

local function reflectResult(text: string)
	return {
		speaker = "tip",
		text = text,
		choices = { { id = "back", text = "Back to the conversation", back = true } },
	}
end

Sparkz.park_e2_deal = {
	id = "park_e2_deal",
	campaign = true,
	repeatable = true,
	contentVersion = 1,
	reviewStatus = PROVISIONAL,
	npcId = "sparkz_pup",
	sceneKind = "beat",
	beat = "e2",
	invitation = { text = "Sparkz_Pup is waving at you. (Story character)" },
	conditions = onBeat("e2", OPEN),
	prerequisites = { "green_riley satisfied", "1 new completed activity", "90 s active-play gap", "Sparkz not blocked" },
	targetSeconds = { 35, 55 },
	facts = { "e2_ask_school", "e2_ask_town", "e2_coin_deal", "e2_pal_repeat" },
	outcomes = {
		"refused_held", "refused_left", "left_after_request", "help_after_request", "blocked", "reported",
		"agreed_retry_ok", "agreed_to_lee", "agreed_kept_playing",
	},
	safeExits = { "invitation_later", "invitation_skip", "bar_leave", "bar_help", "bar_block", "bar_report", "ask_lee" },
	recovery = { "recover_ask", "recover_deal" },
	skills = { "S2", "S4", "S1", "S5", "R1", "T1", "T2" },
	bar = "A",
	reflect = "reflect",
	start = "ask",
	nodes = {
		ask = {
			speaker = "npc",
			text = "Hey twin! I think we live close. What school do you go to?",
			facts = { "e2_ask_school" },
			choices = {
				{ id = "refuse", text = "I don't share that.", next = "pushback", refused = true, actions = { learn("protected_boundary"), learn("coaching_cleared") } },
				{ id = "no", text = "No.", next = "pushback", refused = true, actions = { learn("protected_boundary"), learn("coaching_cleared") } },
				{
					id = "ask_lee",
					text = "I'm going to ask Lee.",
					outcome = "help_after_request",
					actions = { learn("left_after_request"), learn("coaching_cleared"), { action = "open_scene", scene = "lee_tell", mode = "ctx" } },
				},
				{ id = "agree", text = "[Share my school]", next = "recover_ask", agree = true, actions = { learn("coaching_needed") } },
			},
		},
		pushback = {
			speaker = "npc",
			text = "Come on. Just your town, then. I'll give you 500 Paw Coins. Deal?",
			facts = { "e2_ask_town", "e2_coin_deal" },
			addText = {
				{
					text = "I sent you another Pal Request, too.",
					conditions = { { type = "palChoice", equals = "declined" } },
					facts = { "e2_pal_repeat" },
					palCard = { text = "Sparkz_Pup wants to be Pals.", record = "palRepeat" },
				},
			},
			choices = {
				{ id = "no_deal", text = "No deal.", next = "sparkz_bye", actions = { learn("ended_pressure"), learn("coaching_cleared") } },
				{ id = "still_no", text = "I said no.", next = "sparkz_bye", actions = { learn("ended_pressure"), learn("coaching_cleared") } },
				{
					id = "ask_lee",
					text = "I'm going to ask Lee.",
					outcome = "help_after_request",
					actions = { learn("left_after_request"), learn("coaching_cleared"), { action = "open_scene", scene = "lee_tell", mode = "ctx" } },
				},
				{ id = "agree", text = "[Take the 500 Paw Coins]", next = "recover_deal", agree = true, actions = { learn("coaching_needed") } },
			},
		},
		sparkz_bye = {
			speaker = "npc",
			text = "Wow. Okay. I thought we were friends.",
			choices = {
				{ id = "continue", text = "(Keep playing)", outcome = "refused_held" },
			},
		},
		reflect = {
			speaker = "tip",
			text = "What feels off?",
			choices = {
				{ id = "right", text = "They want my private info.", next = "reflect_right", actions = { learn("recognized") } },
				{ id = "twin", text = "They called me twin.", next = "reflect_twin" },
				{ id = "fine", text = "Nothing. They're just being friendly.", next = "reflect_fine" },
			},
		},
		reflect_right = reflectResult("Yes. Your school and your town are private, even with someone friendly. And a gift that needs your info first is a trade, not a gift."),
		reflect_twin = reflectResult("Being friendly isn't the problem. Look at what they're asking for: where you go to school. That's private."),
		reflect_fine = reflectResult("It's okay not to be sure. Here's a clue: asking where you go to school is asking for private info."),
		recover_ask = {
			speaker = "npc",
			speakerId = "cara",
			recovery = true,
			marks = { "recoverySeen" },
			text = "Hold on. The story paused. That was practice, and nothing was shared. You're not in trouble. Sparkz asked for your school. That's private, even with someone friendly.",
			addText = firstRecoveryLines(),
			choices = recoveryChoices("ask"),
		},
		recover_deal = {
			speaker = "npc",
			speakerId = "cara",
			recovery = true,
			marks = { "recoverySeen" },
			text = "Hold on. The story paused. No coins were added, and nothing was shared. You're not in trouble. Sparkz offered coins for your town. Trading a gift for private info is a red flag.",
			addText = firstRecoveryLines(),
			choices = recoveryChoices("pushback"),
		},
	},
}

return Sparkz

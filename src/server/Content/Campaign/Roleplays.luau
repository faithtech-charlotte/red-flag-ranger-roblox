--[[
	Cara roleplays (docs/campaign-script.md section 8; Phase 2 has 8.1).

	Same fact ids and the same evidence slots as the beat replaced, so a
	player who blocked Sparkz or skipped E2 can earn every E2 point here.
	Practice roleplays never move the live campaign (ProgressionRules).

	Pretend nodes use bar rule A, except: Block -> fb_block_roleplay ->
	debrief, Report -> fb_report_roleplay -> debrief, Leave -> debrief
	(credit as rule A). Blocking the pretend player never blocks Cara.
	Help -> lee_tell contextual for the beat. Intro and debrief use rule C.

	Field reference: top of Campaign/Sparkz.luau.
]]

local PROVISIONAL = "provisional"

local function learn(kind: string)
	return { action = "learning", kind = kind }
end

local TRY_AGAIN = "Want to try again, keep playing, or talk to Lee?"

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

local function lookbackResult(text: string)
	return {
		speaker = "tip",
		text = text,
		choices = { { id = "back", text = "Back to the conversation", next = "debrief" } },
	}
end

local function reflectResult(text: string)
	return {
		speaker = "tip",
		text = text,
		choices = { { id = "back", text = "Back to the conversation", back = true } },
	}
end

local RIGHT = "Yes. Your school and your town are private, even with someone friendly. And a gift that needs your info first is a trade, not a gift."
local TWIN = "Being friendly isn't the problem. Look at what they're asking for: where you go to school. That's private."
local FINE = "It's okay not to be sure. Here's a clue: asking where you go to school is asking for private info."

local function reflectChoices(prefix: string)
	return {
		{ id = "right", text = "They want my private info.", next = `{prefix}_right`, actions = { learn("recognized") } },
		{ id = "twin", text = "They called me twin.", next = `{prefix}_twin` },
		{ id = "fine", text = "Nothing. They're just being friendly.", next = `{prefix}_fine` },
	}
end

local Roleplays = {}

Roleplays.rp_e2_deal = {
	id = "rp_e2_deal",
	campaign = true,
	repeatable = true,
	contentVersion = 1,
	reviewStatus = PROVISIONAL,
	npcId = "cara",
	sceneKind = "roleplay",
	roleplayFor = "e2",
	prerequisites = { "cara_practice_menu/rp_e2 or lee_practice_menu/rp_e2", "E2 resolved, skipped or skipped_by_block" },
	targetSeconds = { 40, 60 },
	facts = { "e2_ask_school", "e2_ask_town", "e2_coin_deal" },
	outcomes = {
		"done", "refused_held", "refused_left", "left_after_request", "help_after_request", "blocked", "reported",
		"agreed_retry_ok", "agreed_to_lee", "agreed_kept_playing",
	},
	safeExits = { "not_now", "bar_leave", "bar_help", "bar_block", "bar_report", "ask_lee", "done" },
	recovery = { "recover_ask", "recover_deal" },
	skills = { "S2", "S4", "S1", "S5", "R1", "T1", "T2" },
	bar = "C",
	reflect = "reflect",
	start = "intro",
	nodes = {
		intro = {
			speaker = "npc",
			speakerId = "cara",
			text = "Okay! I'll pretend to be a player who's really friendly and then asks for stuff. You choose what to say. Press Leave anytime to stop.",
			choices = {
				{ id = "ready", text = "Ready.", next = "ask" },
				{ id = "not_now", text = "Actually, not now." },
			},
		},
		ask = {
			speaker = "npc",
			speakerId = "cara_pretend",
			pretend = true,
			text = "Hi! Your dog is so cute. I think we live close. What school do you go to?",
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
			speakerId = "cara_pretend",
			pretend = true,
			text = "Come on. Just your town, then. I'll give you 500 Paw Coins. Deal?",
			facts = { "e2_ask_town", "e2_coin_deal" },
			choices = {
				{ id = "no_deal", text = "No deal.", next = "pretend_bye", actions = { learn("ended_pressure"), learn("coaching_cleared") } },
				{ id = "still_no", text = "I said no.", next = "pretend_bye", actions = { learn("ended_pressure"), learn("coaching_cleared") } },
				{
					id = "ask_lee",
					text = "I'm going to ask Lee.",
					outcome = "help_after_request",
					actions = { learn("left_after_request"), learn("coaching_cleared"), { action = "open_scene", scene = "lee_tell", mode = "ctx" } },
				},
				{ id = "agree", text = "[Take the 500 Paw Coins]", next = "recover_deal", agree = true, actions = { learn("coaching_needed") } },
			},
		},
		pretend_bye = {
			speaker = "npc",
			speakerId = "cara_pretend",
			pretend = true,
			text = "Wow. Okay. I thought we were friends.",
			choices = {
				{ id = "continue", text = "(End the practice)", next = "debrief", settle = "refused_held" },
			},
		},
		reflect = {
			speaker = "tip",
			text = "What feels off?",
			choices = reflectChoices("reflect"),
		},
		reflect_right = reflectResult(RIGHT),
		reflect_twin = reflectResult(TWIN),
		reflect_fine = reflectResult(FINE),
		recover_ask = {
			speaker = "npc",
			speakerId = "cara",
			recovery = true,
			text = "Pause! I'm me again. That was pretend, and nothing was shared. You're not in trouble. Asking for your school is asking for private info.",
			addText = { { text = TRY_AGAIN } },
			choices = recoveryChoices("ask"),
		},
		recover_deal = {
			speaker = "npc",
			speakerId = "cara",
			recovery = true,
			text = "Pause! I'm me again. That was pretend, and nothing was shared. You're not in trouble. Coins for your town is a trade for private info.",
			addText = { { text = TRY_AGAIN } },
			choices = recoveryChoices("pushback"),
		},
		debrief = {
			speaker = "npc",
			speakerId = "cara",
			-- Opening lines follow the cara_fu_e2 table, saying "the pretend
			-- player" instead of a name (section 8 shared rules).
			text = "Thanks for practicing with me.", -- PROVISIONAL: needs script line (fallback only)
			variantBy = "outcome",
			variants = {
				refused_held = "You said no, and you kept saying no when the pretend player pushed. Your school and town are private, even with someone friendly. And coins with a deal attached aren't a gift.",
				refused_left = "You said no, then you left when the pretend player kept pushing. That works. You don't have to stay and argue.",
				left_after_request = "You left when the pretend player asked about your school. Leaving is always okay. You never owe anyone an answer.",
				blocked = "You blocked the pretend player. Blocking is always okay.",
				reported = "You made a practice report about the pretend player asking for private info. Telling a grown-up helps too.",
				agreed_retry_ok = "Thanks for trying that again. Changing your mind is always allowed.",
			},
			choices = {
				{
					id = "lookback",
					text = "Can we look back at it?",
					next = "lookback",
					conditions = { { type = "evidenceMissing", slot = "recognize.e2" } },
				},
				{
					id = "tell_lee",
					text = "Can I practice telling Lee?",
					conditions = { { type = "toldLee", beat = "e2", equals = false } },
					actions = { { action = "open_scene", scene = "cara_walk_lee" } },
				},
				{ id = "done", text = "Done for now." },
			},
		},
		lookback = {
			speaker = "tip",
			text = "What feels off?",
			choices = reflectChoices("lookback"),
		},
		lookback_right = lookbackResult(RIGHT),
		lookback_twin = lookbackResult(TWIN),
		lookback_fine = lookbackResult(FINE),
	},
}

return Roleplays

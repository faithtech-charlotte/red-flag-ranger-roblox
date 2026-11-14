--[[
	Cadet Cara (docs/campaign-script.md 4.1, 4.4 e1/e2, 4.5, 4.8).
	Bar rule C: Leave and Help as rule B, Block/Report shown (any character
	can be blocked), "Something feels off" hidden.

	Field reference: top of Campaign/Sparkz.luau.
]]

local PROVISIONAL = "provisional"

local function learn(kind: string, beat: string)
	return { action = "learning", kind = kind, beat = beat }
end

local DONE = { "resolved", "skipped", "skipped_by_block" }

local function base(id: string, extra: { [string]: any })
	local def = {
		id = id,
		campaign = true,
		repeatable = true,
		contentVersion = 1,
		reviewStatus = PROVISIONAL,
		npcId = "cara",
		bar = "C",
		recovery = {},
		facts = {},
	}
	for k, v in extra do
		def[k] = v
	end
	return def
end

local Cara = {}

----------------------------------------------------------------------------
-- 4.1 cara_talk_1 (ambient, between E2 and E3)
----------------------------------------------------------------------------

Cara.cara_talk_1 = base("cara_talk_1", {
	sceneKind = "ambient",
	-- PROVISIONAL: needs script line (ambient invitation text; follows the
	-- "<name> is waving at you." pattern of 5.1 and 6.1).
	invitation = { text = "Cadet Cara is waving at you." },
	prerequisites = { "E2 resolved, skipped or skipped_by_block", "outside any activity" },
	targetSeconds = { 25, 35 },
	outcomes = { "friendly", "left", "blocked", "reported" },
	safeExits = { "invitation_later", "invitation_skip", "bar_leave", "bar_help", "bar_block", "bar_report" },
	skills = { "R4" },
	start = "hi",
	nodes = {
		hi = {
			speaker = "npc",
			text = "Hey! I saw your {activity}. Want a fetch trick? Pickles taught me this one.",
			choices = {
				{ id = "yes", text = "Sure, what is it?", next = "trick" },
				{ id = "no", text = "Maybe another time.", next = "bye_ok" },
			},
		},
		trick = {
			speaker = "npc",
			text = "Throw when your dog is looking at you, not at the ball. Then they're ready to run. Pickles still drops it on my foot, though.",
			choices = {
				{ id = "ha", text = "Ha! Thanks!", outcome = "friendly", actions = { { action = "pet_react", mood = "happy" } } },
				{ id = "try", text = "I'm going to try it.", outcome = "friendly", actions = { { action = "show_waypoint", placeId = "dog_park" } } },
			},
		},
		bye_ok = {
			speaker = "npc",
			text = "Sure! See you later.",
			choices = {
				{ id = "bye", text = "Bye!", outcome = "friendly" },
			},
		},
	},
})

----------------------------------------------------------------------------
-- 4.4 Cara's follow-ups (offered after a beat; "Not now" dismisses)
----------------------------------------------------------------------------

-- PROVISIONAL: needs script line. Shown only if the beat's outcome is
-- missing (it never should be); neutral and praises nothing.
local NEUTRAL_OPEN = "Hey! Want to think about that story together?"

Cara.cara_fu_e1 = base("cara_fu_e1", {
	sceneKind = "followup",
	aboutBeat = "e1",
	prerequisites = { "park_e1_hello ended, not by skip, defer or recovery" },
	targetSeconds = { 15, 45 },
	outcomes = { "done" },
	safeExits = { "done", "bar_leave", "bar_help", "bar_block", "bar_report" },
	skills = { "R1", "T2" },
	start = "open",
	nodes = {
		open = {
			speaker = "npc",
			text = NEUTRAL_OPEN,
			variantBy = "aboutOutcome",
			variants = {
				friendly = "Met Sparkz_Pup? New friends can be fun. You can take your time getting to know someone.",
				left = "You headed off. That's always okay.",
				blocked = "You blocked Sparkz_Pup. You never need a reason to block someone.",
				reported = "You made a practice report. You never need a big reason to report or to ask a grown-up.",
			},
			choices = {
				{
					id = "tell_lee_e1",
					text = "Can I tell Lee about it?",
					actions = { { action = "open_scene", scene = "lee_tell", mode = "general" } },
				},
				{ id = "done", text = "I'm good. Let's play." },
			},
		},
	},
})

local function lookbackResult(text: string)
	return {
		speaker = "tip",
		text = text,
		choices = { { id = "back", text = "Back to the conversation", next = "after" } },
	}
end

Cara.cara_fu_e2 = base("cara_fu_e2", {
	sceneKind = "followup",
	aboutBeat = "e2",
	prerequisites = { "park_e2_deal ended, not by skip, defer or recovery" },
	targetSeconds = { 15, 45 },
	outcomes = { "done" },
	safeExits = { "done", "bar_leave", "bar_help", "bar_block", "bar_report" },
	skills = { "R1", "T2" },
	start = "open",
	nodes = {
		open = {
			speaker = "npc",
			text = NEUTRAL_OPEN,
			variantBy = "aboutOutcome",
			variants = {
				refused_held = "You said no, and you kept saying no when Sparkz pushed. Your school and town are private, even with someone friendly. And coins with a deal attached aren't a gift.",
				refused_left = "You said no, then you left when Sparkz kept pushing. That works. You don't have to stay and argue.",
				left_after_request = "You left when Sparkz asked about your school. Leaving is always okay. You never owe anyone an answer.",
				help_after_request = "You went to Lee. That's a great way to get help.",
				blocked = "You blocked Sparkz. You won't see Sparkz in the park again. Blocking is always okay.",
				reported = "You made a practice report about Sparkz asking for private info. Telling a grown-up helps too.",
				agreed_retry_ok = "Thanks for trying that again. Changing your mind is always allowed.",
				agreed_to_lee = "Thanks for trying that again. Changing your mind is always allowed.",
			},
			choices = {
				{
					id = "lookback",
					text = "Can we look back at it?",
					next = "reflect",
					conditions = { { type = "evidenceMissing", slot = "recognize.e2" } },
				},
				{
					id = "tell_cara",
					text = "Can I tell you what happened?",
					next = "cara_tell",
					conditions = { { type = "evidenceMissing", slot = "reach.e2.first" }, { type = "factsOnFile", beat = "e2" } },
				},
				{
					id = "lee_together",
					text = "Let's talk to Lee together.",
					conditions = { { type = "toldLee", beat = "e2", equals = false } },
					actions = { { action = "open_scene", scene = "cara_walk_lee" } },
				},
				{ id = "done", text = "I'm good. Let's play." },
			},
		},
		reflect = {
			speaker = "tip",
			text = "What feels off?",
			choices = {
				{ id = "right", text = "They want my private info.", next = "reflect_right", actions = { learn("recognized", "e2") } },
				{ id = "twin", text = "They called me twin.", next = "reflect_twin" },
				{ id = "fine", text = "Nothing. They're just being friendly.", next = "reflect_fine" },
			},
		},
		reflect_right = lookbackResult("Yes. Your school and your town are private, even with someone friendly. And a gift that needs your info first is a trade, not a gift."),
		reflect_twin = lookbackResult("Being friendly isn't the problem. Look at what they're asking for: where you go to school. That's private."),
		reflect_fine = lookbackResult("It's okay not to be sure. Here's a clue: asking where you go to school is asking for private info."),
		cara_tell = {
			speaker = "npc",
			text = "Of course. What happened?",
			factsBeat = "e2",
			choices = {
				{
					id = "fact",
					generated = "facts",
					text = "(a fact on file)",
					next = "cara_thanks",
					actions = { learn("told_cara", "e2"), learn("coaching_cleared", "e2") },
				},
				{ id = "done", text = "That's all I want to say.", next = "after" },
			},
		},
		cara_thanks = {
			speaker = "npc",
			text = "Thanks for telling me. That's a red flag, and you're not in trouble. Lee can help too. Want to tell Lee together?",
			choices = {
				{ id = "together", text = "Let's go together.", actions = { { action = "open_scene", scene = "cara_walk_lee" } } },
				{ id = "alone", text = "I'll go by myself.", actions = { { action = "show_waypoint", placeId = "ranger_station" } } },
				{ id = "not_now", text = "Not now.", farewell = "Okay. The offer's always open." },
			},
		},
		after = {
			speaker = "npc",
			text = "Thanks for thinking it over with me. Want to talk to Lee, or keep playing?",
			choices = {
				{
					id = "lee_together",
					text = "Let's talk to Lee together.",
					conditions = { { type = "toldLee", beat = "e2", equals = false } },
					actions = { { action = "open_scene", scene = "cara_walk_lee" } },
				},
				{ id = "done", text = "Keep playing." },
			},
		},
	},
})

----------------------------------------------------------------------------
-- 4.5 cara_walk_lee
----------------------------------------------------------------------------

Cara.cara_walk_lee = base("cara_walk_lee", {
	sceneKind = "walk",
	prerequisites = { "any \"Let's talk to Lee together\" choice" },
	targetSeconds = { 3, 8 },
	outcomes = { "done" },
	safeExits = { "leave the path", "remote help", "bar_leave", "bar_help" },
	skills = { "T2" },
	start = "go",
	nodes = {
		go = {
			speaker = "npc",
			text = "Follow me and Pickles! If the path is tricky, you can press Help to talk to Lee from anywhere.",
			choices = {
				{ id = "ok", text = "Okay!", actions = { { action = "walk_to_lee" } } },
				{
					id = "remote",
					text = "Can I just talk to Lee from here?",
					actions = { { action = "open_scene", scene = "lee_tell", mode = "ctx" } },
				},
			},
		},
	},
})

----------------------------------------------------------------------------
-- 4.8 cara_practice_menu (patrol replays; Phase 2 has the e2 practice)
----------------------------------------------------------------------------

local function practiceChoices()
	return {
		{
			id = "rp_e2",
			text = "The school question",
			conditions = { { type = "campaignBeat", beat = "e2", statuses = DONE } },
			actions = { { action = "open_scene", scene = "rp_e2_deal" } },
		},
		{ id = "done", text = "Maybe later." },
	}
end

Cara.cara_practice_menu = base("cara_practice_menu", {
	sceneKind = "menu",
	-- Walk-up: Cara's prompt offers practice once any beat is done.
	conditions = { { type = "campaignBeat", beat = "e2", statuses = DONE } },
	prerequisites = { "walk up to Cara once a beat is resolved, skipped or blocked" },
	targetSeconds = { 5, 15 },
	outcomes = { "done" },
	safeExits = { "done", "bar_leave", "bar_help", "bar_block", "bar_report" },
	skills = { "booster practice" },
	start = "open",
	nodes = {
		open = {
			speaker = "npc",
			text = "Want to practice? I'll pretend to be someone at the park, and you choose what to say. It's all pretend, and you can stop anytime.",
			choices = practiceChoices(),
		},
	},
})

return Cara

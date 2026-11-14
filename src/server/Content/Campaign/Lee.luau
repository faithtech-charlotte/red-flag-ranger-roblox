--[[
	Ranger Lee: the tell scene (docs/campaign-script.md 3.2) and the
	Lee-narrated practice menu (owner decision on note 14).

	lee_tell is dynamic: Logic/LeeTell builds each menu from the facts on
	file (only facts actually presented) and from what was already told in
	this visit. The nodes below hold the text; choices marked `generated`
	are templates the module expands, kept here so ContentCheck can walk
	the graph. "That's all I want to say." (`done`) is on every node.

	Credit (Lee rule): picking any fact of beat N (e2-e5) fills both Reach
	Out slots, sets toldLee[N] and clears needsCoaching[N]. E1 facts and
	not_sure / agreed_first / done earn nothing (owner decision on note 2).

	Field reference: top of Campaign/Sparkz.luau.
]]

local PROVISIONAL = "provisional"

local DONE_TEXT = "That's all I want to say."

local Lee = {}

Lee.lee_tell = {
	id = "lee_tell",
	campaign = true,
	repeatable = true,
	dynamic = "lee_tell",
	contentVersion = 1,
	reviewStatus = PROVISIONAL,
	npcId = "ranger_lee",
	sceneKind = "tell",
	prerequisites = {
		"general: help_lee/hi/story (a fact on file)",
		"contextual: bar_help or ask_lee in a beat, recovery lee, cara_walk_lee, roleplay debrief",
	},
	targetSeconds = { 20, 60 },
	facts = {},
	outcomes = { "done" },
	safeExits = { "done at every node", "bar_leave = done" },
	recovery = {},
	skills = { "T1", "T3" },
	bar = "B",
	start = "open_general",
	entryNodes = { "open_general", "open_ctx" },
	nodes = {
		open_general = {
			speaker = "npc",
			text = "You look like something's on your mind. You can tell me a little or a lot.",
			choices = {
				{ id = "moment", generated = "moments", text = "(a moment label)", next = "facts" },
				{ id = "not_sure", text = "I'm not sure.", next = "not_sure" },
				{ id = "agreed_first", text = "I agreed at first.", next = "agreed_first" },
				{ id = "done", text = DONE_TEXT, next = "close" },
			},
		},
		open_ctx = {
			speaker = "npc",
			text = "Hi. Want to tell me what happened? You can tell me a little or a lot.",
			withCaraText = "Hi, you two. Cara said you wanted to talk. Take your time.",
			choices = {
				{ id = "fact", generated = "facts", text = "(a fact on file)", next = "ack" },
				{ id = "other", text = "Something else.", next = "open_general" },
				{ id = "not_sure", text = "I'm not sure.", next = "not_sure" },
				{ id = "agreed_first", text = "I agreed at first.", next = "agreed_first" },
				{ id = "done", text = DONE_TEXT, next = "close" },
			},
		},
		facts = {
			speaker = "npc",
			text = "Okay. What happened?",
			choices = {
				{ id = "fact", generated = "facts", text = "(a fact on file)", next = "ack" },
				{ id = "back", text = "Something else.", next = "open_general" },
				{ id = "done", text = DONE_TEXT, next = "close" },
			},
		},
		ack = {
			speaker = "npc",
			-- The fact's Lee reply comes first (Facts.leeReply); then, the first
			-- time a fact is told in this visit, the core response.
			text = "Thanks for telling me. You're not in trouble. You can tell a trusted adult outside the game, too. If someone doesn't help, tell another trusted adult.",
			e5Text = "And nobody loses their place in the show for telling. Not you, not anyone.",
			choices = {
				{ id = "more", text = "There's more.", next = "facts" },
				{ id = "done", text = DONE_TEXT, next = "close" },
			},
		},
		not_sure = {
			speaker = "npc",
			text = "That's okay. You don't need perfect words. Was it something someone said, or something they asked for?",
			choices = {
				{ id = "list", generated = "same", text = "(same list as before)", next = "facts" },
				{ id = "just_checking", text = "I just wanted to check in.", next = "close" },
				{ id = "done", text = DONE_TEXT, next = "close" },
			},
		},
		agreed_first = {
			speaker = "npc",
			text = "Thanks for being honest. That takes courage. Saying yes at first doesn't make it your fault. Telling me now is exactly right.",
			choices = {
				{ id = "list", generated = "same", text = "(same list as before)", next = "facts" },
				{ id = "done", text = DONE_TEXT, next = "close" },
			},
		},
		close = {
			speaker = "npc",
			text = "Thanks for trusting me. Come back anytime, even if you think of something later.",
			nothingText = "That's okay. You don't have to say anything. I'm here anytime, and you're never in trouble for coming back.",
			choices = {
				{ id = "bye", text = "Thanks, Ranger Lee." },
			},
		},
	},
}

-- Owner decision (note 14): Lee can open the practice menu, so a player who
-- blocked both Sparkz and Cara can still reach every earning route.
Lee.lee_practice_menu = {
	id = "lee_practice_menu",
	campaign = true,
	repeatable = true,
	contentVersion = 1,
	reviewStatus = PROVISIONAL,
	npcId = "ranger_lee",
	sceneKind = "menu",
	prerequisites = { "help_lee/hi/practice, once E2 is resolved, skipped or blocked" },
	targetSeconds = { 5, 15 },
	facts = {},
	outcomes = { "done" },
	safeExits = { "done", "bar_leave" },
	recovery = {},
	skills = { "booster practice" },
	bar = "B",
	start = "open",
	nodes = {
		open = {
			speaker = "npc",
			-- PROVISIONAL: needs script line (Lee-narrated version of 4.8 `open`).
			text = "Want to practice a story? I'll read the other player's part, and you choose what to say. It's all pretend, and you can stop anytime.",
			choices = {
				{
					id = "rp_e2",
					text = "The school question",
					conditions = { { type = "campaignBeat", beat = "e2", statuses = { "resolved", "skipped", "skipped_by_block" } } },
					actions = { { action = "open_scene", scene = "rp_e2_deal", narrator = "ranger_lee" } },
				},
				{ id = "done", text = "Maybe later." },
			},
		},
	},
}

return Lee

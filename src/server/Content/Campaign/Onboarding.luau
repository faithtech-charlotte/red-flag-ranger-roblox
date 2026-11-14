--[[
	Onboarding (docs/campaign-script.md section 2). Pushed by StoryService
	right after adoption: Lee's welcome by park radio, then Cara's intro.
	Any exit marks a scene seen and onboarding continues.

	Campaign scene fields are described at the top of Campaign/Sparkz.luau.
]]

local PROVISIONAL = "provisional"

local Onboarding = {}

Onboarding.onb_lee_welcome = {
	id = "onb_lee_welcome",
	campaign = true,
	repeatable = true,
	contentVersion = 1,
	reviewStatus = PROVISIONAL,
	npcId = "ranger_lee",
	sceneKind = "onboarding",
	prerequisites = { "adoption finished", "pushed once" },
	targetSeconds = { 15, 25 },
	facts = {},
	outcomes = { "friendly", "left" },
	safeExits = { "bar_leave", "close" },
	recovery = {},
	skills = { "T1", "R4" },
	bar = "B",
	start = "welcome",
	nodes = {
		welcome = {
			speaker = "npc",
			speakerId = "ranger_lee",
			text = "Welcome to the park! I'm Ranger Lee. Play anything you like, in any order. Finish four activities and the Pet Show opens.",
			choices = {
				{ id = "ok", text = "Sounds fun!", next = "practice" },
			},
		},
		practice = {
			speaker = "npc",
			speakerId = "ranger_lee",
			text = "One more thing. Some park characters have practice stories. They're labeled Story character. You can leave any conversation or ask for help. Come find me at Ranger HQ anytime. You're never in trouble for asking.",
			marks = { "disclosed" },
			choices = {
				{ id = "play", text = "Let's play!", outcome = "friendly" },
				{
					id = "where",
					text = "Where's Ranger HQ?",
					outcome = "friendly",
					actions = { { action = "show_waypoint", placeId = "ranger_station", seconds = 10 } },
				},
			},
		},
	},
}

Onboarding.onb_cara_intro = {
	id = "onb_cara_intro",
	campaign = true,
	repeatable = true,
	contentVersion = 1,
	reviewStatus = PROVISIONAL,
	npcId = "cara",
	sceneKind = "onboarding",
	prerequisites = { "onb_lee_welcome ended" },
	targetSeconds = { 8, 12 },
	facts = {},
	outcomes = { "friendly", "left", "blocked", "reported" },
	safeExits = { "bar_leave", "close", "bar_help", "bar_block", "bar_report" },
	recovery = {},
	skills = { "T2" },
	bar = "C",
	start = "hi",
	nodes = {
		hi = {
			speaker = "npc",
			speakerId = "cara",
			text = "Hi! I'm Cadet Cara, and this is Pickles. Cute {breed}! I'm around the park a lot. If you ever want to talk something over, find me or Lee.",
			choices = {
				{ id = "bye", text = "See you around!", outcome = "friendly" },
				{ id = "pickles", text = "Hi, Pickles!", outcome = "friendly", actions = { { action = "pet_react", mood = "happy" } } },
			},
		},
	},
}

return Onboarding

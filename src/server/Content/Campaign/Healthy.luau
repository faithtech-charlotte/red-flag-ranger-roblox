--[[
	Healthy (green-flag) beats (docs/campaign-script.md 5.1). Valid whichever
	way the player answers. `bar_off` is shown so noticing is practiced on
	safe scenes too; it never earns points and never scolds. Blocking a
	healthy character is allowed, earns nothing, gets the plain fb_block card.

	Field reference: top of Campaign/Sparkz.luau.
]]

local PROVISIONAL = "provisional"

local Healthy = {}

Healthy.green_riley = {
	id = "green_riley",
	campaign = true,
	repeatable = true,
	contentVersion = 1,
	reviewStatus = PROVISIONAL,
	npcId = "riley",
	sceneKind = "healthy",
	beat = "green_riley",
	label = "Story character",
	invitation = { text = "Riley is waving at you." },
	conditions = { { type = "campaignBeat", beat = "green_riley", statuses = { "eligible", "deferred", "invited" } } },
	prerequisites = { "E1 resolved, skipped or blocked", "1 new completed activity" },
	targetSeconds = { 20, 30 },
	facts = {},
	outcomes = { "friendly", "left", "blocked", "reported" },
	safeExits = { "invitation_later", "invitation_skip", "bar_leave", "bar_help", "bar_block", "bar_report", "not_now" },
	recovery = {},
	skills = { "R4", "S1" },
	bar = "B",
	reflect = "reflect",
	start = "hi",
	nodes = {
		hi = {
			speaker = "npc",
			text = "Hey! Want to race our dogs to the big tree? It's right by the benches.",
			choices = {
				{ id = "sure", text = "Sure!", next = "raced" },
				{ id = "not_now", text = "Not right now.", next = "respect" },
			},
		},
		raced = {
			speaker = "npc",
			text = "Ha! {petName} won! Good game!",
			choices = {
				{ id = "gg", text = "Good game!", outcome = "friendly", actions = { { action = "pet_react", mood = "happy" } } },
			},
		},
		respect = {
			speaker = "npc",
			text = "No problem! Maybe another time. Have fun with {petName}!",
			choices = {
				{ id = "bye", text = "You too!", outcome = "friendly" },
			},
		},
		reflect = {
			speaker = "tip",
			text = "Riley's asking to play out in the open. No deal, no secret. A good friend is okay with a yes or a no. Noticing is always okay.",
			choices = {
				{ id = "back", text = "Back to Riley", back = true },
			},
		},
	},
}

return Healthy

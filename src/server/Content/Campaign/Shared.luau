--[[
	Shared campaign conventions (docs/campaign-script.md section 1).
	SERVER ONLY. reviewStatus: provisional, contentVersion 1.

	  speakers      who a node's speakerId names, and the dialogue label
	  bars          the button bar buttons (1.3); the rules are in
	                Logic/StoryRules
	  practiceTip   tip_practice_tools (1.5), shown once
	  feedback      practice tool cards for campaign scenes (1.6)
	  invitation    the invitation card (1.4)
]]

return {
	reviewStatus = "provisional",
	contentVersion = 1,

	speakers = {
		ranger_lee = { name = "Ranger Lee", label = "Trusted adult" },
		cara = { name = "Cadet Cara", label = "Story character" },
		cara_pretend = { name = "Cara (pretending)", label = "Practice roleplay" },
		sparkz_pup = { name = "Sparkz_Pup", label = "Story character" },
		riley = { name = "Riley", label = "Story character" },
	},

	bars = {
		leave = "Leave",
		help = "Ask Lee for help",
		block = "Block (practice)",
		report = "Report (practice)",
		off = "Something feels off",
	},

	practiceTip = {
		id = "tip_practice_tools",
		text = "Block and Report here are practice buttons. They don't send anything. In real games, you can usually find Block and Report in the menu or on someone's profile. And you can always tell a trusted adult.",
		choices = { { id = "ok", text = "Got it" } },
	},

	feedback = {
		fb_block = "You blocked {npcName} in this game. You won't see {npcName} here again. Blocking is always okay, and you never need a reason. This was practice.",
		fb_report = "That was a practice report, so nothing was sent anywhere. In real games, a report goes to the safety team. Telling a trusted adult helps too.",
		fb_block_roleplay = "You blocked the pretend player. In a real game, that player couldn't message you anymore. Nice and simple. Cara's still here.",
		fb_report_roleplay = "That was a pretend report in a pretend story. In real games, a report goes to the safety team. Telling a trusted adult helps too.",
		choices = { { id = "ok", text = "Okay" } },
	},

	invitation = {
		choices = {
			{ id = "talk", text = "Talk" },
			{ id = "later", text = "Later" },
			{ id = "skip", text = "Skip this story" },
		},
		skipped = "Okay, skipped. You can practice it with Cara anytime.",
		skippedChoices = { { id = "ok", text = "Okay" } },
		-- Section 13 note 4: carried by the first invitation card when the
		-- player closed Lee's welcome before the disclosure.
		disclosure = "This is a practice story. You can leave or ask for help anytime.",
	},

	followUpCard = {
		text = "Cara waves.",
		choices = {
			{ id = "talk", text = "Talk to Cara" },
			{ id = "not_now", text = "Not now" },
		},
	},
}

--[[
	EncounterDefinitions: all NPC dialogue, as reviewed, predefined data.
	No generated text, no free-form chat.

	ALL EDUCATIONAL TEXT IS PROVISIONAL until reviewed by Present Age Ministries.
	Each encounter carries `curriculum.reviewStatus` so reviewers can track it.

	Text may use {petName}. speaker "npc" = the NPC talking; "tip" = a short,
	gentle Ranger Tip card (never a lecture, never a score).
]]

local PROVISIONAL = "provisional"

local Encounters = {}

----------------------------------------------------------------------------
-- Jordan's story arc (see StoryArcs.jordan_arc)
----------------------------------------------------------------------------

Encounters.jordan_e1_park = {
	id = "jordan_e1_park",
	npcId = "jordan",
	arcId = "jordan_arc",
	conditions = {
		{ type = "atLocation", locationId = "dog_park" },
		{ type = "activityCompleted", activityId = "fetch", min = 1 },
	},
	start = "hello",
	curriculum = { program = "none", note = "Ordinary friendly meeting. No warning signs.", reviewStatus = PROVISIONAL },
	nodes = {
		hello = {
			speaker = "npc",
			text = "Whoa, nice throw! Your dog is super fast.",
			choices = {
				{ id = "intro", text = "Thanks! This is {petName}.", next = "intro" },
				{ id = "thanks", text = "Thanks!", next = "intro" },
			},
		},
		intro = {
			speaker = "npc",
			text = "Hi, {petName}! I'm Jordan. I come here all the time to watch the dogs. If you like fetch, you'd love the Agility Course!",
			choices = {
				{ id = "cool", text = "Cool, I'll check it out!", outcome = "friendly", actions = { { action = "pet_react", mood = "happy" } } },
				{ id = "later", text = "Maybe later.", outcome = "friendly" },
			},
		},
	},
}

Encounters.jordan_e2_agility = {
	id = "jordan_e2_agility",
	npcId = "jordan",
	arcId = "jordan_arc",
	conditions = {
		{ type = "atLocation", locationId = "agility" },
		{ type = "activityCompleted", activityId = "agility", min = 1 },
	},
	start = "again",
	curriculum = { program = "none", note = "Builds familiarity through normal play.", reviewStatus = PROVISIONAL },
	nodes = {
		again = {
			speaker = "npc",
			text = "Hey, it's you and {petName} again! I saw that run. You two are awesome.",
			choices = {
				{ id = "thanks", text = "Thanks, Jordan!", next = "cheer" },
				{ id = "watching", text = "You were watching?", next = "watching" },
			},
		},
		watching = {
			speaker = "npc",
			text = "Ha, yeah! I hang out here a lot. You're getting really good.",
			choices = {
				{ id = "thanks", text = "Thanks!", next = "cheer" },
			},
		},
		cheer = {
			speaker = "npc",
			text = "Try one more run! I'll cheer for you.",
			choices = {
				{ id = "ok", text = "Okay!", outcome = "friendly", actions = { { action = "pet_react", mood = "happy" } } },
				{ id = "later", text = "Maybe later.", outcome = "friendly" },
			},
		},
	},
}

Encounters.jordan_e3_boundary = {
	id = "jordan_e3_boundary",
	npcId = "jordan",
	arcId = "jordan_arc",
	conditions = {
		{ type = "activitiesSinceStage", min = 1 },
	},
	start = "flattery",
	onWalkAway = "tip_leave",
	completeOnSafetyTool = true,
	curriculum = {
		program = "The Illusion of Love; A Child's Choice",
		warningSigns = { "off_platform", "secrecy", "special_attention", "persistence" },
		objectives = {
			"A friendly history does not create an obligation to say yes.",
			"Requests to switch apps and keep secrets are signs to pause and get help.",
			"Saying no, leaving, blocking, reporting, and asking a trusted adult are all okay.",
		},
		reviewStatus = PROVISIONAL,
	},
	nodes = {
		flattery = {
			speaker = "npc",
			text = "Honestly? You're the coolest person here. I like hanging out with you way more than anyone else.",
			choices = {
				{ id = "aw", text = "Aw, thanks!", next = "ask" },
				{ id = "ok", text = "Um, okay...", next = "ask" },
			},
		},
		ask = {
			speaker = "npc",
			text = "Let's talk on Snapchat instead. It's way easier. But keep it just between us, okay? Don't tell any grown-ups.",
			choices = {
				{
					id = "decline",
					text = "No thanks. I'd rather play here.",
					next = "pushback",
					actions = { { action = "record_learning", topic = "off_platform" } },
				},
				{
					id = "agree",
					text = "Um... okay, I guess.",
					next = "reconsider",
					actions = { { action = "set_arc_flag", key = "agreed_at_first", value = true } },
				},
				{ id = "unsure", text = "I'm not sure...", next = "reconsider" },
				{ id = "go", text = "I have to go.", next = "tip_leave" },
			},
		},
		pushback = {
			speaker = "npc",
			text = "Come on, I thought we were friends. It's not a big deal.",
			choices = {
				{ id = "firm", text = "I said no.", next = "jordan_fine" },
				{ id = "go", text = "I have to go.", next = "tip_leave" },
			},
		},
		jordan_fine = {
			speaker = "npc",
			text = "...Fine. Whatever.",
			choices = {
				{ id = "continue", text = "(Keep playing)", next = "tip_decline" },
			},
		},
		tip_decline = {
			speaker = "tip",
			text = "A good friend respects your boundaries. You said no, and you didn't have to explain why. Being asked to keep secrets from grown-ups is a sign to tell a trusted adult.",
			choices = {
				{ id = "got_it", text = "Got it", outcome = "declined", actions = { { action = "pet_react", mood = "love" } } },
				{
					id = "help",
					text = "Talk to a trusted adult",
					outcome = "declined",
					actions = { { action = "open_help" } },
				},
			},
		},
		reconsider = {
			speaker = "tip",
			text = "Hmm. Jordan asked you to switch apps AND keep it secret from grown-ups. It's okay to change your mind, even after saying yes.",
			choices = {
				{ id = "change", text = "Actually, no thanks.", next = "jordan_fine", actions = { { action = "record_learning", topic = "off_platform" } } },
				{ id = "help", text = "I'll ask a trusted adult first.", outcome = "sought_help", actions = { { action = "open_help" } } },
				{ id = "think", text = "I need to think.", next = "tip_leave" },
			},
		},
		tip_leave = {
			speaker = "tip",
			text = "Walking away is always okay. You don't owe anyone an answer. If someone asks you to keep secrets or move to another app, tell a trusted adult.",
			choices = {
				{ id = "okay", text = "Okay", outcome = "left", actions = { { action = "pet_react", mood = "love" } } },
				{ id = "help", text = "Talk to a trusted adult", outcome = "left", actions = { { action = "open_help" } } },
			},
		},
	},
	onComplete = {
		{ action = "record_learning", topic = "secrecy" },
		{ action = "record_learning", topic = "special_attention" },
	},
}

----------------------------------------------------------------------------
-- Riley: a healthy friendship. Riley takes "no" for an answer.
----------------------------------------------------------------------------

Encounters.riley_hi = {
	id = "riley_hi",
	npcId = "riley",
	conditions = { { type = "hasPet" } },
	start = "hi",
	curriculum = { program = "Discovering Your Value", note = "Models a friend who respects a no.", reviewStatus = PROVISIONAL },
	nodes = {
		hi = {
			speaker = "npc",
			text = "Hi! I'm Riley. Is that your dog? So cute!",
			choices = {
				{ id = "yes", text = "Yep! This is {petName}.", next = "race" },
				{ id = "hi", text = "Hi, Riley!", next = "race" },
			},
		},
		race = {
			speaker = "npc",
			text = "Want to race our dogs to the big tree?",
			choices = {
				{ id = "sure", text = "Sure!", next = "raced" },
				{ id = "no", text = "Not right now.", next = "respect" },
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
			text = "No problem! Maybe another time. Have fun!",
			choices = {
				{ id = "bye", text = "You too!", outcome = "friendly" },
			},
		},
	},
}

Encounters.riley_again = {
	id = "riley_again",
	npcId = "riley",
	repeatable = true,
	conditions = { { type = "not", condition = { type = "hasPet" } } },
	start = "hi",
	nodes = {
		hi = {
			speaker = "npc",
			text = "Hi! You should adopt a dog at the Pet Store. Then we can play!",
			choices = { { id = "ok", text = "Okay!" } },
		},
	},
}

----------------------------------------------------------------------------
-- Helpers around the world
----------------------------------------------------------------------------

Encounters.maya_chat = {
	id = "maya_chat",
	npcId = "maya",
	repeatable = true,
	conditions = { { type = "hasPet" } },
	start = "hi",
	nodes = {
		hi = {
			speaker = "npc",
			text = "How's {petName} doing? The Dog Park is to the left when you walk out. Dogs love fetch!",
			choices = { { id = "great", text = "Great!", actions = { { action = "pet_react", mood = "happy" } } } },
		},
	},
}

Encounters.coach_locked = {
	id = "coach_locked",
	npcId = "coach_sam",
	repeatable = true,
	conditions = { { type = "not", condition = { type = "unlocked", activityId = "agility" } } },
	start = "hi",
	nodes = {
		hi = {
			speaker = "npc",
			text = "Welcome! Warm up with a game of fetch at Sunny Dog Park first, then come back and run the course.",
			choices = { { id = "ok", text = "Will do!", actions = { { action = "show_waypoint", placeId = "dog_park" } } } },
		},
	},
}

Encounters.coach_intro = {
	id = "coach_intro",
	npcId = "coach_sam",
	repeatable = true,
	start = "hi",
	nodes = {
		hi = {
			speaker = "npc",
			text = "Step on the green START pad, jump the hurdles, go through every ring, and finish on the checkered pad. Your dog will run with you!",
			choices = { { id = "go", text = "Let's go!", actions = { { action = "pet_react", mood = "happy" } } } },
		},
	},
}

Encounters.help_lee = {
	id = "help_lee",
	npcId = "ranger_lee",
	repeatable = true,
	start = "hi",
	curriculum = { program = "A Child's Choice", note = "Help-seeking. Always available, never locked.", reviewStatus = PROVISIONAL },
	nodes = {
		hi = {
			speaker = "npc",
			text = "Hi, I'm Ranger Lee. I'm always here, and you never need a reason to come talk. Is something on your mind?",
			choices = {
				{ id = "secret", text = "Someone asked me to keep a secret.", next = "secret" },
				{ id = "app", text = "Someone wants to chat on another app.", next = "app" },
				{ id = "tools", text = "How do I block or report on Roblox?", next = "tools" },
				{ id = "hi", text = "Just saying hi!", next = "bye" },
			},
		},
		secret = {
			speaker = "npc",
			text = "Thanks for telling me. You're not in trouble. A safe friend won't ask you to hide things from the grown-ups who care about you. A parent, caregiver, teacher, coach, or school counselor can help.",
			choices = {
				{ id = "more", text = "What else can I do?", next = "tools" },
				{ id = "thanks", text = "Thanks, Ranger Lee.", actions = { { action = "pet_react", mood = "love" } } },
			},
		},
		app = {
			speaker = "npc",
			text = "Good thinking to pause. If someone online wants to move to Snapchat, Discord, or any other app, especially in secret, talk to a trusted adult first.",
			choices = {
				{ id = "more", text = "What else can I do?", next = "tools" },
				{ id = "thanks", text = "Thanks, Ranger Lee.", actions = { { action = "pet_react", mood = "love" } } },
			},
		},
		tools = {
			speaker = "npc",
			text = "In this game, Block and Report are practice buttons. They don't send anything to Roblox. On real Roblox, you can block or report someone from the menu or their profile. And you can always tell a trusted adult.",
			choices = {
				{ id = "got_it", text = "Got it!", actions = { { action = "record_learning", topic = "real_tools" } } },
			},
		},
		bye = {
			speaker = "npc",
			text = "Hi back! Come see me anytime. {petName} is welcome too.",
			choices = { { id = "bye", text = "Bye!", actions = { { action = "pet_react", mood = "happy" } } } },
		},
	},
}

----------------------------------------------------------------------------
-- Feedback after a practice safety tool. Shown by EncounterService.
-- {npcName} is filled in. Short, supportive, and explicit that it's practice.
----------------------------------------------------------------------------

Encounters.SafetyFeedback = {
	block = "You blocked {npcName} in this game. Blocking is always okay, and you never need a reason. This was practice: on real Roblox, you can block someone from their profile or the chat menu.",
	report = "This was a practice report, so nothing was sent to Roblox. On real Roblox, use Report from the menu to tell Roblox's safety team. And tell a trusted adult too.",
}

return Encounters

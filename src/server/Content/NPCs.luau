--[[
	NPCDefinitions. NPC models are built from `appearance` by NPCService and
	tagged "Interactable_NPC" with attributes NpcId and LocationId. An NPC may
	stand in several places (Jordan does); progress is still per player.

	role:
	  peer          another kid in the game. Dialogue shows the practice
	                Block / Report tools, the same as real player-to-player chat.
	  trusted_adult a safe grown-up character (help is always available here)
	  shopkeeper    runs a store

	interaction: "dialogue" (default) | "shop" | "adopt"
]]

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

return {
	maya = {
		id = "maya",
		displayName = "Maya",
		subtitle = "Pet Store Owner",
		role = "shopkeeper",
		interaction = "adopt",
		promptText = "Talk",
		appearance = { skin = rgb(141, 85, 36), shirt = rgb(255, 159, 67), pants = rgb(60, 70, 110), hair = rgb(30, 20, 15) },
		placements = {
			{ locationId = "pet_store", position = Vector3.new(0, 0, 63), faces = Vector3.new(0, 0, 40) },
		},
		encounters = { "maya_chat" },
		idleLine = "Take good care of your pup!",
	},
	priya = {
		id = "priya",
		displayName = "Priya",
		subtitle = "Groomer",
		role = "shopkeeper",
		interaction = "shop",
		promptText = "Shop",
		appearance = { skin = rgb(198, 134, 90), shirt = rgb(255, 120, 190), pants = rgb(80, 60, 110), hair = rgb(40, 25, 20) },
		placements = {
			{ locationId = "salon", position = Vector3.new(98, 0, -30), faces = Vector3.new(60, 0, -30) },
		},
		idleLine = "Welcome to Fluff & Puff!",
	},
	bo = {
		id = "bo",
		displayName = "Bo",
		subtitle = "Treat Baker",
		role = "shopkeeper",
		interaction = "shop",
		shop = "treat_shop",
		promptText = "Shop",
		appearance = { skin = rgb(160, 110, 75), shirt = rgb(255, 255, 255), pants = rgb(90, 70, 60), hair = rgb(30, 25, 20), hat = rgb(255, 255, 255) },
		placements = {
			{ locationId = "treat_shop", position = Vector3.new(-42, 0, 14), faces = Vector3.new(0, 0, 14) },
		},
		idleLine = "Fresh treats! Your pup will do a happy dance.",
	},
	coach_sam = {
		id = "coach_sam",
		displayName = "Coach Sam",
		subtitle = "Trainer",
		role = "trusted_adult",
		appearance = { skin = rgb(234, 192, 160), shirt = rgb(80, 160, 255), pants = rgb(40, 40, 50), hair = rgb(120, 80, 40), hat = rgb(255, 255, 255) },
		placements = {
			{ locationId = "agility", position = Vector3.new(-46, 0, -96), faces = Vector3.new(0, 0, -120) },
		},
		encounters = { "coach_locked", "coach_intro" },
		idleLine = "Go get 'em!",
	},
	ranger_lee = {
		id = "ranger_lee",
		displayName = "Ranger Lee",
		subtitle = "Trusted Adult",
		label = "Trusted adult",
		role = "trusted_adult",
		promptText = "Ask for help",
		appearance = { skin = rgb(110, 70, 45), shirt = rgb(46, 160, 120), pants = rgb(120, 95, 60), hair = rgb(20, 15, 10), hat = rgb(150, 110, 60) },
		placements = {
			{ locationId = "ranger_station", position = Vector3.new(16, 0, 5), faces = Vector3.new(0, 0, 5) },
		},
		encounters = { "help_lee" },
		idleLine = "I'm here if you need me.",
	},
	riley = {
		id = "riley",
		displayName = "Riley",
		subtitle = nil,
		role = "peer",
		appearance = { skin = rgb(255, 214, 180), shirt = rgb(255, 209, 102), pants = rgb(70, 130, 200), hair = rgb(200, 90, 40) },
		placements = {
			{ locationId = "dog_park", position = Vector3.new(-108, 0, -12), faces = Vector3.new(-90, 0, -40) },
		},
		-- green_riley (the campaign step before E2) wins while it's open.
		encounters = { "green_riley", "riley_hi", "riley_again" },
		idleLine = "Hi again! Have you tried the ball bucket? I bet {petName} can catch three in a row!",
	},
	jordan = {
		id = "jordan",
		displayName = "Jordan",
		subtitle = nil,
		role = "peer",
		appearance = { skin = rgb(224, 172, 130), shirt = rgb(239, 71, 111), pants = rgb(45, 50, 70), hair = rgb(60, 40, 25) },
		placements = {
			{ locationId = "dog_park", position = Vector3.new(-72, 0, -24), faces = Vector3.new(-90, 0, -40) },
			{ locationId = "agility", position = Vector3.new(-42, 0, -142), faces = Vector3.new(0, 0, -120) },
		},
		arcs = { "jordan_arc" }, -- unscheduled while the campaign runs (StoryArcs)
		idleLine = "Hey! Fun day, huh?",
	},

	-- Practice-story characters (docs/campaign-script.md 1.2). Ordinary
	-- looks, fictional identities, labeled "Story character" in dialogue.
	cara = {
		id = "cara",
		displayName = "Cadet Cara",
		subtitle = "Story character",
		label = "Story character",
		role = "peer",
		appearance = { skin = rgb(176, 122, 84), shirt = rgb(64, 170, 220), pants = rgb(60, 70, 90), hair = rgb(35, 22, 15) },
		placements = {
			{ locationId = "pet_store", position = Vector3.new(12, 0, 24), faces = Vector3.new(0, 0, 24) },
		},
		encounters = { "cara_practice_menu" },
		idleLine = "Hi! Pickles says hi too.", -- PROVISIONAL: needs script line
	},
	sparkz_pup = {
		id = "sparkz_pup",
		displayName = "Sparkz_Pup",
		subtitle = "Story character",
		label = "Story character",
		role = "peer",
		-- Shown to a player only while one of their Sparkz beats is open
		-- (StoryRules.presence) and never once blocked. Its dog is a
		-- client-only copy of that player's own breed.
		storyOnly = true,
		companionDog = true,
		appearance = { skin = rgb(240, 200, 160), shirt = rgb(120, 200, 120), pants = rgb(70, 80, 120), hair = rgb(150, 100, 50) },
		placements = {
			{ locationId = "dog_park", position = Vector3.new(-100, 0, -62), faces = Vector3.new(-90, 0, -40) },
		},
		encounters = { "park_e1_hello", "park_e2_deal" },
		idleLine = "Hey!", -- PROVISIONAL: needs script line
	},
}

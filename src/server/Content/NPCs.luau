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
	coach_sam = {
		id = "coach_sam",
		displayName = "Coach Sam",
		subtitle = "Agility Coach",
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
		encounters = { "riley_hi", "riley_again" },
		idleLine = "Hi again!",
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
		arcs = { "jordan_arc" },
		idleLine = "Hey! Fun day, huh?",
	},
}

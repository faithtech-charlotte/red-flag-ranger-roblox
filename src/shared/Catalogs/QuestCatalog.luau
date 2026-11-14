--[[
	QuestCatalog: the "Ranger Journal". Quests complete when a matching game
	event happens (see Server.Services.QuestService). They can be finished in
	any order; the HUD shows the first unfinished one as the next objective.

	completeOn.match values may be a single value or a list of allowed values.
	rewards are ActionService action lists.
]]

export type Quest = {
	id: string,
	title: string,
	hint: string,
	waypoint: string?,
	completeOn: { event: string, match: { [string]: any }? },
	rewards: { { [string]: any } },
}

local Quests: { Quest } = {
	{
		id = "adopt_dog",
		title = "Adopt a dog",
		hint = "Talk to Maya at the Pet Store.",
		waypoint = "pet_store",
		completeOn = { event = "pet.adopted" },
		rewards = { { action = "grant_currency", amount = 10, reason = "quest" } },
	},
	{
		id = "pet_dog",
		title = "Pet your dog",
		hint = "Stand still near your dog and press ✋ Pet. Then stroke!",
		completeOn = { event = "pet.interacted", match = { action = "pet" } },
		rewards = { { action = "grant_currency", amount = 5, reason = "quest" } },
	},
	{
		id = "feed_dog",
		title = "Feed your dog",
		hint = "Press 🦴 Care near your dog. Kibble is free!",
		completeOn = { event = "pet.interacted", match = { action = "feed" } },
		rewards = { { action = "grant_currency", amount = 5, reason = "quest" } },
	},
	{
		id = "first_fetch",
		title = "Play fetch at Sunny Dog Park",
		hint = "Equip the 🎾 ball, hold to wind up, release to throw!",
		waypoint = "dog_park",
		completeOn = { event = "activity.completed", match = { activityId = "fetch" } },
		rewards = { { action = "unlock_activity", activityId = "agility" } },
	},
	{
		id = "teach_sit",
		title = "Tell your dog to Sit",
		hint = "Press 🐕 Sit near your dog, then 📣 Come.",
		completeOn = { event = "pet.interacted", match = { action = "sit" } },
		rewards = { { action = "grant_currency", amount = 5, reason = "quest" } },
	},
	{
		id = "first_purchase",
		title = "Buy something at the Salon",
		hint = "Talk to Priya at Fluff & Puff.",
		waypoint = "salon",
		completeOn = { event = "item.purchased", match = { kind = { "cosmetic", "bundle" } } },
		rewards = { { action = "grant_currency", amount = 5, reason = "quest" } },
	},
	{
		id = "first_equip",
		title = "Dress up your dog",
		hint = "Open Wardrobe and equip something.",
		completeOn = { event = "item.equipped" },
		rewards = { { action = "grant_currency", amount = 5, reason = "quest" } },
	},
	{
		id = "first_agility",
		title = "Run the Agility Course",
		hint = "Step on START, pass every ring, reach the FINISH.",
		waypoint = "agility",
		completeOn = { event = "activity.completed", match = { activityId = "agility" } },
		rewards = { { action = "grant_currency", amount = 10, reason = "quest" } },
	},
	{
		id = "spa_day",
		title = "Give your dog a spa day",
		hint = "Use a grooming tub at the Fluff & Puff Salon.",
		waypoint = "salon",
		completeOn = { event = "activity.completed", match = { activityId = "grooming" } },
		rewards = { { action = "grant_currency", amount = 10, reason = "quest" } },
	},
	{
		id = "treat_shop",
		title = "Visit Bo's Treat Shop",
		hint = "Buy a treat and feed it to your dog.",
		waypoint = "treat_shop",
		completeOn = { event = "pet.interacted", match = { action = "feed", food = { "treat_biscuit", "treat_carrot", "treat_pupcake" } } },
		rewards = { { action = "grant_currency", amount = 5, reason = "quest" } },
	},
	{
		id = "trick_practice",
		title = "Practice on the training mat",
		hint = "Hit the green zone 2 out of 3 times.",
		waypoint = "agility",
		completeOn = { event = "activity.completed", match = { activityId = "trick_training" } },
		rewards = { { action = "grant_currency", amount = 10, reason = "quest" } },
	},
	{
		id = "bond_3",
		title = "Reach Bond Level 3",
		hint = "Pet, feed, play, and groom to grow your bond. Unlocks Spin!",
		completeOn = { event = "pet.levelUp", match = { level = 3 } },
		rewards = { { action = "grant_currency", amount = 15, reason = "quest" } },
	},
	{
		id = "first_trick",
		title = "Show off a trick",
		hint = "Press ⭐ Tricks near your dog.",
		completeOn = { event = "pet.interacted", match = { action = "trick" } },
		rewards = { { action = "grant_currency", amount = 10, reason = "quest" } },
	},
}

local byId = {}
for _, q in Quests do
	byId[q.id] = q
end

local QuestCatalog = {}
QuestCatalog.Ordered = Quests

function QuestCatalog.get(id: string): Quest?
	return byId[id]
end

return QuestCatalog

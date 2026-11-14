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
		id = "first_fetch",
		title = "Play fetch at Sunny Dog Park",
		hint = "Stand in the park and press Throw!",
		waypoint = "dog_park",
		completeOn = { event = "activity.completed", match = { activityId = "fetch" } },
		rewards = { { action = "unlock_activity", activityId = "agility" } },
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

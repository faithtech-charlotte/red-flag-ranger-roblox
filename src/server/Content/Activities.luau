--[[
	ActivityDefinitions: rewards and rules for every activity. The mechanics
	(how fetch or grooming actually plays) live in Server/Activities/*; this
	file is only the data, so balancing never touches game code.

	  location        Places id where the activity counts (optional)
	  requires        Conditions (see Logic.Conditions) to start it
	  rewards.coins   Paw Coins per completion
	  rewards.firstBonus  extra coins the very first time (claimed once)
	  rewards.bond    BondCatalog source for Bond XP
	  rewardCooldown  seconds after a paid completion before coins pay again
	                  (stops reward loops; the activity still works)
	  medals          optional time-based bonus tiers (each claimed once)
	  parSeconds      Trail Walk: the time that earns full time credit
]]

return {
	fetch = {
		id = "fetch",
		name = "Fetch",
		location = "dog_park",
		goal = 3, -- catches in the park for one completion
		requires = { { type = "hasPet" } },
		rewards = { coins = 8, firstBonus = 17, bond = "activity" },
		rewardCooldown = 20,
	},
	agility = {
		id = "agility",
		name = "Agility Course",
		location = "agility",
		minSeconds = 6,
		requires = { { type = "hasPet" }, { type = "unlocked", activityId = "agility" } },
		rewards = { coins = 12, firstBonus = 18, bond = "activity" },
		rewardCooldown = 10,
		medals = {
			{ id = "gold", label = "Gold", under = 16, bonus = 15 },
			{ id = "silver", label = "Silver", under = 24, bonus = 8 },
		},
	},
	grooming = {
		id = "grooming",
		name = "Spa Day",
		location = "salon",
		requires = { { type = "hasPet" } },
		rewards = { coins = 6, firstBonus = 14, bond = "groom_spa" },
		rewardCooldown = 30,
	},
	trick_training = {
		id = "trick_training",
		name = "Trick Training",
		location = "agility",
		requires = { { type = "hasPet" } },
		rewards = { coins = 5, firstBonus = 10, bond = "training" },
		rewardCooldown = 10,
	},
	trail_walk = {
		id = "trail_walk",
		name = "Trail Walk",
		location = "trail",
		parSeconds = 60, -- at or under this time counts fully toward trail stars
		requires = { { type = "hasPet" } },
		rewards = { coins = 10, firstBonus = 15, bond = "activity" },
		rewardCooldown = 30,
	},
}

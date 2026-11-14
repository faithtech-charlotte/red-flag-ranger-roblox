--[[
	BondCatalog: Bond XP, Bond Levels, what each level unlocks, and how much
	XP each kind of positive interaction gives. All balancing lives here.

	Bond never goes down. There is no decay, hunger, or sickness.

	XP sources:
	  xp        XP for one interaction
	  cooldown  seconds before this source can give XP again (the interaction
	            itself still works and still gets a happy reaction)
	  dailyCap  interactions per day that give XP. The first half give full
	            XP, the second half give half, after that 0 (still happy!)
]]

export type Unlock = {
	level: number,
	kind: "command" | "trick" | "item" | "gift",
	id: string,
	label: string,
	count: number?,
}

local BondCatalog = {}

-- Total XP needed to REACH each level (index = level).
BondCatalog.LevelXp = { 0, 40, 100, 180, 280, 400, 550, 730, 940, 1200 }
BondCatalog.MaxLevel = #BondCatalog.LevelXp

BondCatalog.Unlocks = {
	{ level = 1, kind = "command", id = "sit", label = "Sit" },
	{ level = 2, kind = "command", id = "stay", label = "Stay command" },
	{ level = 3, kind = "trick", id = "spin", label = "Spin trick" },
	{ level = 4, kind = "gift", id = "treat_pupcake", count = 2, label = "2 Pupcakes" },
	{ level = 5, kind = "trick", id = "high_five", label = "High-five trick" },
	{ level = 6, kind = "trick", id = "play_bow", label = "Play Bow trick" },
	{ level = 8, kind = "trick", id = "zoomies", label = "Zoomies (special move)" },
	{ level = 10, kind = "item", id = "collar_best_friend", label = "Best Friend Collar" },
}

BondCatalog.Sources = {
	pet = { xp = 8, cooldown = 12, dailyCap = 24 }, -- per meaningful petting session
	feed_kibble = { xp = 6, cooldown = 45, dailyCap = 12 },
	feed_treat = { xp = 10, cooldown = 6, dailyCap = 16 }, -- treats may override xp
	brush = { xp = 6, cooldown = 30, dailyCap = 10 },
	toy = { xp = 5, cooldown = 15, dailyCap = 16 },
	fetch = { xp = 5, cooldown = 0, dailyCap = 60 },
	trick = { xp = 3, cooldown = 4, dailyCap = 40 },
	groom_spa = { xp = 25, cooldown = 0, dailyCap = 8 },
	training = { xp = 15, cooldown = 0, dailyCap = 12 },
	activity = { xp = 15, cooldown = 0, dailyCap = 20 },
	care = { xp = 8, cooldown = 0, dailyCap = 12 }, -- services like Bubble Bath
}

-- (level, xpIntoLevel, xpNeededForNextLevel or nil at max)
function BondCatalog.levelFor(xp: number): (number, number, number?)
	local level = 1
	for i, need in BondCatalog.LevelXp do
		if xp >= need then
			level = i
		end
	end
	local base = BondCatalog.LevelXp[level]
	local nextNeed = BondCatalog.LevelXp[level + 1]
	return level, xp - base, nextNeed and (nextNeed - base) or nil
end

function BondCatalog.isUnlocked(level: number, kind: string, id: string): boolean
	for _, u in BondCatalog.Unlocks do
		if u.kind == kind and u.id == id then
			return level >= u.level
		end
	end
	return false
end

function BondCatalog.requiredLevel(kind: string, id: string): number?
	for _, u in BondCatalog.Unlocks do
		if u.kind == kind and u.id == id then
			return u.level
		end
	end
	return nil
end

function BondCatalog.unlocksAt(level: number): { Unlock }
	local list = {}
	for _, u in BondCatalog.Unlocks do
		if u.level == level then
			table.insert(list, u)
		end
	end
	return list
end

function BondCatalog.nextUnlock(level: number): Unlock?
	local best = nil
	for _, u in BondCatalog.Unlocks do
		if u.level > level and (best == nil or u.level < best.level) then
			best = u
		end
	end
	return best
end

-- XP actually awarded given how many times this source already paid today.
function BondCatalog.xpAfterCap(baseXp: number, countToday: number, dailyCap: number): number
	if countToday >= dailyCap then
		return 0
	elseif countToday >= math.floor(dailyCap / 2) then
		return math.ceil(baseXp / 2)
	end
	return baseXp
end

return BondCatalog

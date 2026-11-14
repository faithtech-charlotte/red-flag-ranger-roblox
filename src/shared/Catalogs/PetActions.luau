--[[
	PetActions: what you can do with your dog from the interaction menu, and
	the tricks it can learn. Shared so the menu can show what's available;
	the server re-checks everything.

	  touch     the dog must be close (you can't pet a dog across the map)
	  cooldown  seconds between uses (UI shows a countdown)
	  unlock    { kind, id } from BondCatalog.Unlocks, if gated by bond level
]]

export type Action = {
	id: string,
	label: string,
	icon: string,
	touch: boolean,
	cooldown: number,
	unlock: { kind: string, id: string }?,
	submenu: string?,
	order: number,
}

export type Trick = {
	id: string,
	label: string,
	icon: string,
	duration: number,
}

local PetActions = {}

PetActions.Actions = {
	pet = { id = "pet", label = "Pet", icon = "🤚", touch = true, cooldown = 1.5, order = 1 },
	feed = { id = "feed", label = "Feed", icon = "🥣", touch = true, cooldown = 2.5, submenu = "feed", order = 2 },
	fetch = { id = "fetch", label = "Fetch", icon = "🎾", touch = false, cooldown = 0, order = 3 },
	brush = { id = "brush", label = "Brush", icon = "🪮", touch = true, cooldown = 3, order = 4 },
	sit = { id = "sit", label = "Sit", icon = "🐕", touch = false, cooldown = 0.5, order = 5 },
	stay = { id = "stay", label = "Stay", icon = "✋", touch = false, cooldown = 0.5, unlock = { kind = "command", id = "stay" }, order = 6 },
	come = { id = "come", label = "Come", icon = "📣", touch = false, cooldown = 0.5, order = 7 },
	tricks = { id = "tricks", label = "Tricks", icon = "⭐", touch = true, cooldown = 0, submenu = "tricks", order = 8 },
}

PetActions.Tricks = {
	spin = { id = "spin", label = "Spin", icon = "🌀", duration = 1.4 },
	high_five = { id = "high_five", label = "High-five", icon = "🖐️", duration = 1.8 },
	play_bow = { id = "play_bow", label = "Play Bow", icon = "🙇", duration = 1.8 },
	zoomies = { id = "zoomies", label = "Zoomies", icon = "💨", duration = 3.2 },
}
PetActions.TrickOrder = { "spin", "high_five", "play_bow", "zoomies" }

-- Free food is always available (basic care is never paid-only).
PetActions.FreeFood = { id = "kibble", label = "Kibble bowl", icon = "🥣", cooldown = 45 }

PetActions.TOUCH_DISTANCE = 18

function PetActions.ordered(): { Action }
	local list = {}
	for _, a in PetActions.Actions do
		table.insert(list, a)
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	return list
end

return PetActions

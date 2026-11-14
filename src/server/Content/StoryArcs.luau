--[[
	StoryArcDefinitions. Bump `version` whenever stages change; players with
	older progress keep their completed encounters and resume at the first
	stage they haven't finished (see EncounterEngine.ensureArc).

	`scheduled = false` keeps an arc's definitions and saves but never
	starts it (EncounterEngine.select skips it). The Jordan arc is off while
	the practice-story campaign runs (spec: no two escalating stories);
	Jordan stays in the park as an ordinary peer.
]]

return {
	jordan_arc = {
		id = "jordan_arc",
		version = 1,
		scheduled = false,
		title = "Jordan", -- internal only; never shown as "a predator story"
		npcIds = { "jordan" },
		entryConditions = { { type = "hasPet" } },
		stages = {
			{ id = "meet", encounter = "jordan_e1_park" },
			{ id = "again", encounter = "jordan_e2_agility" },
			{ id = "boundary", encounter = "jordan_e3_boundary", transitions = { default = "done" } },
		},
	},
}

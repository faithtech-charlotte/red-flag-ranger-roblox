local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local ContentCheck = require(Server.Logic.ContentCheck)
local Conditions = require(Server.Logic.Conditions)
local Content = require(Server.Content)

return function(t)
	local expect = t.expect

	-- Same action list as EncounterEngine.spec ("content validates with all
	-- known actions"); keep the two in step when ActionService grows.
	local KNOWN_ACTIONS = {
		grant_currency = true, spend_currency = true, grant_item = true, equip_item = true,
		complete_quest = true, unlock_activity = true, simulate_block = true, simulate_report = true,
		open_help = true, end_conversation = true, record_learning = true, set_arc_flag = true,
		show_waypoint = true, pet_react = true,
		-- Phase 1-2 campaign actions (ProgressionService, EncounterService, StoryService)
		learning = true, campaign = true, open_scene = true, walk_to_lee = true,
	}
	local knownConditions = Conditions.knownTypes()

	local realRegistries = {
		actionExists = function(name)
			return KNOWN_ACTIONS[name] == true
		end,
		conditionExists = function(kind)
			return knownConditions[kind] == true
		end,
	}

	local fixtureRegistries = {
		actionExists = function(name)
			return name == "pet_react" or name == "open_help"
		end,
		conditionExists = function(kind)
			return kind == "hasPet" or kind == "not" or kind == "any"
		end,
	}

	local function cards(prefix)
		local list = {}
		for slot = 1, 6 do
			table.insert(list, {
				id = `{prefix}{slot}`,
				slot = slot,
				kind = if slot <= 3 then "benign" else "concerning",
				answer = if slot <= 3 then "fine" else "concern",
			})
		end
		return list
	end

	-- A small, valid graph with a retry loop that can still exit.
	local function fixture()
		return {
			facts = { asked_school = true, offered_coins = true },
			encounters = {
				demo = {
					id = "demo",
					npcId = "sparkz",
					start = "ask",
					onWalkAway = "leave",
					conditions = { { type = "hasPet" } },
					nodes = {
						ask = {
							speaker = "npc",
							text = "What school do you go to?",
							facts = { "asked_school" },
							choices = {
								{ id = "refuse", text = "No.", next = "bribe" },
								{ id = "go", text = "Bye.", next = "leave" },
							},
						},
						bribe = {
							speaker = "npc",
							text = "Just your town, then.",
							facts = { "offered_coins" },
							choices = {
								{ id = "retry", text = "Wait, what?", next = "ask" },
								{ id = "firm", text = "I said no.", outcome = "declined", actions = { { action = "pet_react", mood = "love" } } },
							},
						},
						leave = {
							speaker = "tip",
							text = "Walking away is okay.",
							choices = {
								{ id = "ok", text = "Okay", outcome = "left" },
								{ id = "help", text = "Help", outcome = "left", actions = { { action = "open_help" } }, conditions = { { type = "not", condition = { type = "hasPet" } } } },
							},
						},
					},
				},
			},
			reviewSets = {
				A = { cards = cards("a") },
				B = { cards = cards("b") },
			},
		}
	end

	local function hasProblem(problems, needle)
		for _, p in problems do
			if string.find(p, needle, 1, true) then
				return true
			end
		end
		return false
	end

	t.test("content check: real content passes", function()
		local problems = ContentCheck.check(Content, realRegistries)
		if #problems > 0 then
			error(table.concat(problems, "; "))
		end
	end)

	t.test("content check: the fixture passes (loops with an exit are fine)", function()
		local problems = ContentCheck.check(fixture(), fixtureRegistries)
		if #problems > 0 then
			error(table.concat(problems, "; "))
		end
	end)

	t.test("content check: facts and review sets are optional", function()
		local c = fixture()
		c.reviewSets = nil
		for _, node in c.encounters.demo.nodes do
			node.facts = nil
		end
		c.facts = nil
		expect(#ContentCheck.check(c, fixtureRegistries)).toBe(0)
	end)

	local failures = {
		{
			name = "unreachable node",
			needle = "orphan: unreachable node",
			mutate = function(c)
				c.encounters.demo.nodes.orphan = { speaker = "npc", text = "?", choices = { { id = "x", text = "x" } } }
			end,
		},
		{
			name = "choice into a loop with no way out",
			needle = "never terminates",
			mutate = function(c)
				local nodes = c.encounters.demo.nodes
				nodes.ask.choices[1].next = "trap"
				nodes.trap = { speaker = "npc", text = "Come on.", choices = { { id = "again", text = "...", next = "trap" } } }
			end,
		},
		{
			name = "choice to a missing node",
			needle = "next -> missing node nowhere",
			mutate = function(c)
				c.encounters.demo.nodes.bribe.choices[2].next = "nowhere"
			end,
		},
		{
			name = "node with no choices",
			needle = "dead end",
			mutate = function(c)
				c.encounters.demo.nodes.leave.choices = {}
			end,
		},
		{
			name = "missing start",
			needle = "missing start node",
			mutate = function(c)
				c.encounters.demo.start = "nope"
			end,
		},
		{
			name = "missing walk-away node",
			needle = "missing walk-away node",
			mutate = function(c)
				c.encounters.demo.onWalkAway = "gone"
			end,
		},
		{
			name = "duplicate choice id",
			needle = "duplicate choice id go",
			mutate = function(c)
				c.encounters.demo.nodes.ask.choices[1].id = "go"
			end,
		},
		{
			name = "unknown action",
			needle = "unknown action grant_robux",
			mutate = function(c)
				c.encounters.demo.nodes.bribe.choices[2].actions = { { action = "grant_robux" } }
			end,
		},
		{
			name = "unknown onComplete action",
			needle = "unknown action teleport",
			mutate = function(c)
				c.encounters.demo.onComplete = { { action = "teleport" } }
			end,
		},
		{
			name = "unknown condition",
			needle = "unknown condition isAdmin",
			mutate = function(c)
				c.encounters.demo.conditions = { { type = "isAdmin" } }
			end,
		},
		{
			name = "unknown nested condition",
			needle = "unknown condition hasRobux",
			mutate = function(c)
				c.encounters.demo.nodes.leave.choices[2].conditions = {
					{ type = "any", conditions = { { type = "not", condition = { type = "hasRobux" } } } },
				}
			end,
		},
		{
			name = "unknown fact",
			needle = "unknown fact home_address",
			mutate = function(c)
				c.encounters.demo.nodes.ask.facts = { "home_address" }
			end,
		},
		{
			name = "fact with no fact registry",
			needle = "unknown fact asked_school",
			mutate = function(c)
				c.facts = nil
			end,
		},
		{
			name = "review set with 5 cards",
			needle = "has 5 cards",
			mutate = function(c)
				table.remove(c.reviewSets.B.cards)
			end,
		},
		{
			name = "review set with the wrong benign/concerning split",
			needle = "slot 1 must be benign",
			mutate = function(c)
				local list = c.reviewSets.A.cards
				list[1].kind, list[4].kind = "concerning", "benign"
			end,
		},
		{
			name = "review set with a repeated slot",
			needle = "slot 2 used twice",
			mutate = function(c)
				c.reviewSets.A.cards[3].slot = 2
			end,
		},
		{
			name = "review card ids reused across sets",
			needle = "duplicate card id a1",
			mutate = function(c)
				c.reviewSets.B.cards[1].id = "a1"
			end,
		},
		{
			name = "review card without an answer",
			needle = "missing answer",
			mutate = function(c)
				c.reviewSets.A.cards[5].answer = nil
			end,
		},
	}

	for _, case in failures do
		t.test(`content check fails: {case.name}`, function()
			local c = fixture()
			case.mutate(c)
			local problems = ContentCheck.check(c, fixtureRegistries)
			if not hasProblem(problems, case.needle) then
				error(`expected a problem containing "{case.needle}", got: {table.concat(problems, "; ")}`)
			end
		end)
	end

	-- A minimal valid campaign scene (full metadata, reflection, recovery).
	local function campaignScene()
		return {
			id = "story",
			campaign = true,
			repeatable = true,
			contentVersion = 1,
			reviewStatus = "provisional",
			npcId = "sparkz",
			sceneKind = "beat",
			beat = "e2",
			invitation = { text = "Sparkz is waving at you." },
			prerequisites = {},
			facts = { "asked_school" },
			outcomes = { "refused_held", "agreed_kept_playing" },
			safeExits = { "bar_leave" },
			recovery = { "recover" },
			skills = { "S2" },
			targetSeconds = { 30, 60 },
			bar = "A",
			reflect = "reflect",
			start = "ask",
			nodes = {
				ask = {
					speaker = "npc",
					text = "What school do you go to?",
					facts = { "asked_school" },
					choices = {
						{ id = "no", text = "No.", outcome = "refused_held" },
						{ id = "agree", text = "[Share]", next = "recover", agree = true },
					},
				},
				recover = {
					speaker = "npc",
					recovery = true,
					text = "Hold on. The story paused.",
					choices = {
						{ id = "retry", text = "Let me try again.", next = "ask" },
						{ id = "play", text = "Keep playing.", outcome = "agreed_kept_playing" },
					},
				},
				reflect = {
					speaker = "tip",
					text = "What feels off?",
					choices = { { id = "back", text = "Back", back = true } },
				},
			},
		}
	end

	local function withScene(mutate)
		local c = fixture()
		local scene = campaignScene()
		c.encounters.story = scene
		if mutate then
			mutate(scene, c)
		end
		return c
	end

	t.test("content check: a campaign scene with full metadata passes", function()
		local problems = ContentCheck.check(withScene(nil), fixtureRegistries)
		if #problems > 0 then
			error(table.concat(problems, "; "))
		end
	end)

	local campaignFailures = {
		{ "missing content version", "missing contentVersion", function(e)
			e.contentVersion = nil
		end },
		{ "missing review status", "missing reviewStatus", function(e)
			e.reviewStatus = nil
		end },
		{ "missing skills", "missing skills", function(e)
			e.skills = {}
		end },
		{ "not repeatable", "must be repeatable", function(e)
			e.repeatable = nil
		end },
		{ "unknown scene kind", "unknown sceneKind", function(e)
			e.sceneKind = "boss_fight"
		end },
		{ "declared fact never presented", "declares fact offered_coins that no node presents", function(e)
			table.insert(e.facts, "offered_coins")
		end },
		{ "presented fact not declared", "presents undeclared fact offered_coins", function(e)
			e.nodes.recover.facts = { "offered_coins" }
		end },
		{ "conditional fact not declared", "presents undeclared fact offered_coins", function(e)
			e.nodes.ask.addText = { { text = "Deal?", facts = { "offered_coins" } } }
		end },
		{ "undeclared outcome", "ends with undeclared outcome made_up", function(e)
			e.nodes.ask.choices[1].outcome = "made_up"
		end },
		{ "recovery node not listed", "recovery node missing from recovery list", function(e)
			e.recovery = {}
		end },
		{ "listed recovery is not a recovery node", "is not a recovery node", function(e)
			table.insert(e.recovery, "ask")
		end },
		{ "back choice without a reflection", "back choice in a scene without reflect", function(e)
			e.reflect = nil
		end },
		{ "missing reflect node", "missing reflect node", function(e)
			e.reflect = "gone"
		end },
		{ "unknown generated list", "unknown generated list everything", function(e)
			table.insert(e.nodes.ask.choices, { id = "g", text = "x", generated = "everything", next = "ask" })
		end },
		{ "beat without an invitation", "unsolicited scenes need invitation text", function(e)
			e.invitation = nil
		end },
		{ "bad target length", "targetSeconds", function(e)
			e.targetSeconds = { 60, 30 }
		end },
		{ "fact from another beat", "belongs to e3, not e2", function(_e, c)
			c.facts = { asked_school = { beat = "e3" }, offered_coins = true }
		end },
		{ "unknown addText condition", "unknown condition isAdmin", function(e)
			e.nodes.ask.addText = { { text = "Hm.", conditions = { { type = "isAdmin" } } } }
		end },
		{ "unknown entry node", "missing entry node", function(e)
			e.entryNodes = { "nowhere" }
		end },
	}
	for _, case in campaignFailures do
		local name, needle, mutate = case[1], case[2], case[3]
		t.test(`content check fails (campaign): {name}`, function()
			local problems = ContentCheck.check(withScene(mutate), fixtureRegistries)
			if not hasProblem(problems, needle) then
				error(`expected a problem containing "{needle}", got: {table.concat(problems, "; ")}`)
			end
		end)
	end

	t.test("content check: malformed input is reported, not thrown", function()
		expect(#ContentCheck.check(nil, fixtureRegistries)).toBe(1)
		expect(#ContentCheck.check({ encounters = {} }, {})).toBe(1)
		local problems = ContentCheck.check({ encounters = { bad = "text" } }, fixtureRegistries)
		expect(hasProblem(problems, "not an encounter definition")).toBe(true)
	end)
end

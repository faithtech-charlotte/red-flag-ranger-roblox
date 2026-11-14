local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local EncounterEngine = require(Server.Logic.EncounterEngine)
local ProfileSchema = require(Server.Data.ProfileSchema)
local Content = require(Server.Content)

-- The Jordan arc is unscheduled while the campaign runs (plan change 7).
-- These tests keep checking the arc engine itself on a scheduled copy.
local scheduledArc = table.clone(Content.arcs.jordan_arc)
scheduledArc.scheduled = nil
local JordanContent = { npcs = Content.npcs, encounters = Content.encounters, arcs = { jordan_arc = scheduledArc } }

return function(t)
	local expect = t.expect

	local function freshProfile()
		local p = ProfileSchema.default(0)
		p.activePetId = "pet1"
		p.pets.pet1 = { id = "pet1", breedId = "golden", name = "Sunny", displayName = "Sunny", equipped = {}, bond = 0, adoptedAt = 0 }
		return p
	end

	t.test("content validates with all known actions", function()
		local known = {
			grant_currency = true, spend_currency = true, grant_item = true, equip_item = true,
			complete_quest = true, unlock_activity = true, simulate_block = true, simulate_report = true,
			open_help = true, end_conversation = true, record_learning = true, set_arc_flag = true,
			show_waypoint = true, pet_react = true,
			learning = true, campaign = true, open_scene = true, walk_to_lee = true,
		}
		local problems = EncounterEngine.validate(Content, function(name)
			return known[name] == true
		end)
		if #problems > 0 then
			error(table.concat(problems, "; "))
		end
	end)

	t.test("Jordan does not appear before fetch", function()
		local p = freshProfile()
		local enc = EncounterEngine.select(JordanContent, p, "jordan", "dog_park")
		expect(enc).toBe(nil)
	end)

	t.test("Jordan arc progresses per player through three stages", function()
		local p = freshProfile()
		p.activities.fetch = { count = 1 }
		local enc, arcId = EncounterEngine.select(JordanContent, p, "jordan", "dog_park")
		expect(enc.id).toBe("jordan_e1_park")
		expect(EncounterEngine.complete(JordanContent, p, enc, arcId, "friendly")).toBe(true)

		-- Encounter 2 needs the agility course and Jordan's agility spot.
		expect(EncounterEngine.select(JordanContent, p, "jordan", "agility")).toBe(nil)
		p.activities.agility = { count = 1 }
		expect(EncounterEngine.select(JordanContent, p, "jordan", "dog_park")).toBe(nil)
		enc, arcId = EncounterEngine.select(JordanContent, p, "jordan", "agility")
		expect(enc.id).toBe("jordan_e2_agility")
		EncounterEngine.complete(JordanContent, p, enc, arcId, "friendly")

		-- Encounter 3 needs one more activity after encounter 2.
		expect(EncounterEngine.select(JordanContent, p, "jordan", "agility")).toBe(nil)
		EncounterEngine.noteActivity(p)
		enc, arcId = EncounterEngine.select(JordanContent, p, "jordan", "agility")
		expect(enc.id).toBe("jordan_e3_boundary")
		EncounterEngine.complete(JordanContent, p, enc, arcId, "declined")
		expect(p.arcs.jordan_arc.done).toBe(true)
		expect(p.arcs.jordan_arc.decisions.jordan_e3_boundary).toBe("declined")
		expect(EncounterEngine.select(JordanContent, p, "jordan", "agility")).toBe(nil)
	end)

	t.test("two players get different Jordan encounters", function()
		local a, b = freshProfile(), freshProfile()
		a.activities.fetch = { count = 1 }
		b.activities.fetch = { count = 1 }
		local enc, arcId = EncounterEngine.select(JordanContent, a, "jordan", "dog_park")
		EncounterEngine.complete(JordanContent, a, enc, arcId, "friendly")
		a.activities.agility = { count = 1 }
		b.activities.agility = { count = 1 }
		expect(EncounterEngine.select(JordanContent, a, "jordan", "agility").id).toBe("jordan_e2_agility")
		expect(EncounterEngine.select(JordanContent, b, "jordan", "agility")).toBe(nil)
		expect(EncounterEngine.select(JordanContent, b, "jordan", "dog_park").id).toBe("jordan_e1_park")
	end)

	t.test("completing twice is idempotent", function()
		local p = freshProfile()
		p.activities.fetch = { count = 1 }
		local enc, arcId = EncounterEngine.select(JordanContent, p, "jordan", "dog_park")
		expect(EncounterEngine.complete(JordanContent, p, enc, arcId, "friendly")).toBe(true)
		expect(EncounterEngine.complete(JordanContent, p, enc, arcId, "friendly")).toBe(false)
		expect(p.arcs.jordan_arc.stage).toBe("again")
	end)

	t.test("blocked NPC offers nothing", function()
		local p = freshProfile()
		p.activities.fetch = { count = 1 }
		p.npcs.jordan = { blocked = true }
		local enc, _, reason = EncounterEngine.select(JordanContent, p, "jordan", "dog_park")
		expect(enc).toBe(nil)
		expect(reason).toBe("blocked")
	end)

	t.test("choices are validated against the current node", function()
		local enc = Content.encounters.jordan_e3_boundary
		local ctx = { profile = freshProfile() }
		local ok = EncounterEngine.choose(enc, "ask", "decline", ctx)
		expect(ok.nextNodeId).toBe("pushback")
		local bad = EncounterEngine.choose(enc, "ask", "got_it", ctx)
		expect(bad).toBe(nil)
		local ending = EncounterEngine.choose(enc, "tip_decline", "got_it", ctx)
		expect(ending.ended).toBe(true)
		expect(ending.outcome).toBe("declined")
	end)

	t.test("agreeing first always leads to a chance to reconsider", function()
		local enc = Content.encounters.jordan_e3_boundary
		local ctx = { profile = freshProfile() }
		expect(EncounterEngine.choose(enc, "ask", "agree", ctx).nextNodeId).toBe("reconsider")
		expect(EncounterEngine.choose(enc, "ask", "unsure", ctx).nextNodeId).toBe("reconsider")
	end)

	t.test("every Jordan e3 path ends on a supportive tip, never on Jordan", function()
		local enc = Content.encounters.jordan_e3_boundary
		for nodeId, node in enc.nodes do
			for _, choice in node.choices do
				if choice.next == nil then
					expect(node.speaker).toBe("tip")
				end
			end
		end
	end)

	t.test("arc content version change keeps completed encounters", function()
		local p = freshProfile()
		p.arcs.jordan_arc = {
			contentVersion = 0,
			stage = "removed_stage",
			completed = { jordan_e1_park = true },
			decisions = {},
			flags = {},
			activitiesSinceStage = 0,
			done = false,
		}
		EncounterEngine.ensureArc(p, JordanContent.arcs.jordan_arc)
		expect(p.arcs.jordan_arc.stage).toBe("again")
		expect(p.arcs.jordan_arc.contentVersion).toBe(JordanContent.arcs.jordan_arc.version)
	end)

	t.test("an unscheduled arc never starts, but keeps its saved progress", function()
		local p = freshProfile()
		p.activities.fetch = { count = 1 }
		p.arcs.jordan_arc = {
			contentVersion = 1,
			stage = "again",
			completed = { jordan_e1_park = true },
			decisions = {},
			flags = {},
			activitiesSinceStage = 3,
			done = false,
		}
		expect(EncounterEngine.select(Content, p, "jordan", "dog_park")).toBe(nil)
		expect(EncounterEngine.select(Content, p, "jordan", "agility")).toBe(nil)
		expect(p.arcs.jordan_arc.completed.jordan_e1_park).toBe(true)
		expect(p.arcs.jordan_arc.stage).toBe("again")
	end)

	t.test("help is available with a brand new profile", function()
		local p = ProfileSchema.default(0)
		local enc = EncounterEngine.select(Content, p, "ranger_lee", "ranger_station")
		expect(enc.id).toBe("help_lee")
	end)

	t.test("format fills pet name", function()
		expect(EncounterEngine.format("Hi, {petName}!", { petName = "Sunny" })).toBe("Hi, Sunny!")
	end)
end

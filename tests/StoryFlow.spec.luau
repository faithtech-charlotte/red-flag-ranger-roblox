--[[
	Phase 2 story flow over the real content, the real scheduler and the
	real ledger (plan Phase 2 "Verify (automated)"):

	  203  same activity and choice sequence -> same encounter sequence;
	       fetch counts completed rounds, not throws
	  208  a benign or premature leave records no threat evidence
	  215  every exit route (distance, close, Help, respawn, disconnect,
	       block, report) at every node of E1, green_riley and E2: no
	       duplicate credit, campaign never stranded
	  plus recovery = refusal credit, roleplay credit after a block, and
	  Reach Out caps through Lee and Cara.

	walk() mirrors what EncounterService does for a choice: facts are
	presented when a node is entered, `learning` actions become ledger
	events, refusals/agreements are tracked for the outcome code.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Content = require(Server.Content)
local Activities = require(Server.Content.Activities)
local Rules = require(Server.Logic.ProgressionRules)
local Sched = require(Server.Logic.EncounterScheduler)
local L = require(Server.Logic.LearningProgress)
local StoryRules = require(Server.Logic.StoryRules)
local ScoreRules = require(Server.Content.ScoreRules)

local AVAILABLE = { e1 = true, green_riley = true, e2 = true }
local EXIT_KINDS = { "walk_away", "help", "blocked", "reported", "respawn", "disconnect", "replaced" }

local function isConcerning(f: string): boolean
	local def = Content.facts[f]
	return def ~= nil and def.concerning == true
end

local function deepEqual(a, b): boolean
	if typeof(a) ~= typeof(b) then
		return false
	end
	if typeof(a) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- Plays choice ids through a scene. Returns where it stopped.
local function walk(sceneId: string, picks: { string }, palChoice: string?)
	local enc = Content.encounters[sceneId]
	local beat = enc.roleplayFor or enc.beat
	local viaRoleplay = enc.roleplayFor ~= nil
	local seen, factList, events = {}, {}, {}
	local story = { concern = false, refused = false, agreed = false }
	local function present(nodeId: string)
		local node = enc.nodes[nodeId]
		local list = table.clone(node.facts or {})
		for _, extra in node.addText or {} do
			-- The only conditional facts in Phase 2 depend on the E1 Pal choice.
			if extra.facts and palChoice == "declined" then
				for _, f in extra.facts do
					table.insert(list, f)
				end
			end
		end
		local fresh = {}
		for _, f in list do
			if not seen[f] then
				seen[f] = true
				table.insert(fresh, f)
				table.insert(factList, f)
			end
			if isConcerning(f) then
				story.concern = true
			end
		end
		if #fresh > 0 then
			for _, e in Rules.factEvents(beat, viaRoleplay, fresh) do
				table.insert(events, e)
			end
		end
	end
	local nodeId = enc.start
	present(nodeId)
	for _, pick in picks do
		local node = enc.nodes[nodeId]
		local choice = nil
		for _, c in node.choices do
			if c.id == pick then
				choice = c
			end
		end
		if not choice then
			error(`{sceneId}.{nodeId}: no choice {pick}`)
		end
		for _, a in choice.actions or {} do
			if a.action == "learning" then
				table.insert(events, { kind = a.kind, beat = a.beat or beat })
			end
		end
		if choice.refused then
			story.refused = true
		end
		if choice.agree then
			story.agreed = true
		end
		if choice.next == nil then
			return {
				ended = true,
				outcome = StoryRules.exitOutcome(story, "completed", choice.outcome or "done"),
				facts = factList,
				events = events,
				story = story,
				beat = beat,
				viaRoleplay = viaRoleplay,
				nodeId = nodeId,
			}
		end
		nodeId = choice.next
		present(nodeId)
	end
	return { ended = false, facts = factList, events = events, story = story, beat = beat, viaRoleplay = viaRoleplay, nodeId = nodeId }
end

-- Every node reachable by choices from start, with one pick path to it.
local function positions(sceneId: string)
	local enc = Content.encounters[sceneId]
	local out = { { nodeId = enc.start, picks = {} } }
	local seenNodes = { [enc.start] = true }
	local i = 1
	while i <= #out do
		local pos = out[i]
		for _, c in enc.nodes[pos.nodeId].choices do
			if c.next and not seenNodes[c.next] then
				seenNodes[c.next] = true
				local picks = table.clone(pos.picks)
				table.insert(picks, c.id)
				table.insert(out, { nodeId = c.next, picks = picks })
			end
		end
		i += 1
	end
	return out
end

local ACT = { kind = "activity_completed" }

local function run(s, events)
	for _, e in events do
		s = Sched.apply(s, e)
	end
	return s
end

local function play(s, beat)
	return run(s, { { kind = "invited", beat = beat }, { kind = "accepted", beat = beat }, { kind = "resolved", beat = beat } })
end

-- Scheduler state with `beat` invited and accepted (the scene is open).
local function activeAt(beat: string)
	local s = run(Sched.defaultState(), { { kind = "onboarding_done" }, ACT })
	if beat ~= "e1" then
		s = run(play(s, "e1"), { ACT })
	end
	if beat == "e2" then
		s = run(play(s, "green_riley"), { ACT })
	end
	return run(s, { { kind = "invited", beat = beat }, { kind = "accepted", beat = beat } })
end

local function ledgerAfter(events)
	local ledger = L.default()
	for _, e in events do
		L.record(ledger, ScoreRules, e)
	end
	return ledger
end

local SCENES = { park_e1_hello = "e1", green_riley = "green_riley", park_e2_deal = "e2" }
local NEXT_BEAT = { e1 = "green_riley", green_riley = "e2", e2 = "e3" }

return function(t)
	local expect = t.expect

	t.test("exit matrix: every exit at every node of E1, green_riley and E2", function()
		local checked = 0
		for sceneId, beat in SCENES do
			local npcId = Content.encounters[sceneId].npcId
			for _, pos in positions(sceneId) do
				local w = walk(sceneId, pos.picks, "declined")
				for _, kind in EXIT_KINDS do
					local where = `{sceneId}@{pos.nodeId} by {kind}`
					local atRecovery = Content.encounters[sceneId].nodes[pos.nodeId].recovery == true
					local led, sch = Rules.exitEvents({ kind = kind, facts = w.facts, atRecovery = atRecovery }, beat, false, isConcerning)
					local all = table.clone(w.events)
					for _, e in led do
						table.insert(all, e)
					end

					-- Ledger: duplicate delivery changes nothing.
					local once = ledgerAfter(all)
					local doubled = table.clone(all)
					for _, e in all do
						table.insert(doubled, e)
					end
					local twice = ledgerAfter(doubled)
					if not deepEqual(once.evidence, twice.evidence) then
						error(`{where}: replayed events changed credit`)
					end
					local cats = L.categories(once, ScoreRules)
					if beat ~= "e2" then
						if L.total(once, ScoreRules) ~= 0 then
							error(`{where}: a benign scene earned evidence`)
						end
					elseif atRecovery then
						-- Leaving the recovery card = "Keep playing": no Respond.
						if cats.respond ~= 0 then
							error(`{where}: leaving from recovery earned Respond`)
						end
					elseif w.story.concern then
						if cats.respond ~= 2 then
							error(`{where}: leaving after the request must earn both Respond slots, got {cats.respond}`)
						end
					else
						if cats.respond ~= 0 then
							error(`{where}: leaving before the request earned Respond`)
						end
					end
					if cats.recognize ~= 0 or cats.reach ~= 0 then
						error(`{where}: an exit alone earned Recognize or Reach Out`)
					end

					-- Scheduler: the scene is closed and the campaign can go on.
					local s = activeAt(beat)
					local events = {}
					if kind == "blocked" then
						table.insert(events, Rules.blocked(npcId))
					end
					for _, e in sch do
						table.insert(events, e)
						table.insert(events, e) -- duplicate delivery
					end
					s = run(s, events)
					if s.current ~= nil then
						error(`{where}: campaign left a scene open`)
					end
					local status = Sched.status(s, beat)
					if Rules.INTERRUPTIONS[kind] then
						if status ~= "eligible" then
							error(`{where}: an interruption should return the beat, got {status}`)
						end
						s = run(s, { { kind = "active_seconds", seconds = 90 } })
						local d = Sched.decide(s, { busy = false, available = AVAILABLE })
						if not d or d.beat ~= beat then
							error(`{where}: the interrupted beat was not offered again`)
						end
					else
						if not Sched.isDone(s, beat) then
							error(`{where}: a safe exit should resolve the beat, got {status}`)
						end
						s = run(s, { ACT })
						local nextStatus = Sched.status(s, NEXT_BEAT[beat])
						if nextStatus ~= "eligible" and nextStatus ~= "skipped_by_block" then
							error(`{where}: next beat stranded at {nextStatus}`)
						end
					end
					-- Cara's follow-up never follows an interruption or Help.
					local outcome = StoryRules.exitOutcome(w.story, kind, nil, atRecovery)
					if atRecovery and kind ~= "help" and outcome ~= "agreed_kept_playing" then
						error(`{where}: leaving recovery should be agreed_kept_playing, got {outcome}`)
					end
					if (Rules.INTERRUPTIONS[kind] or kind == "help")
						and StoryRules.followUpAllowed("beat", kind, outcome, false)
					then
						error(`{where}: follow-up after {kind}`)
					end
					checked += 1
				end
			end
		end
		expect(checked > 40).toBe(true)
	end)

	t.test("E2: leaving right at the request gives full Respond credit (208, 215)", function()
		local w = walk("park_e2_deal", {})
		expect(w.story.concern).toBe(true)
		local led = Rules.exitEvents({ kind = "walk_away", facts = w.facts }, "e2", false, isConcerning)
		local all = table.clone(w.events)
		for _, e in led do
			table.insert(all, e)
		end
		expect(L.categories(ledgerAfter(all), ScoreRules).respond).toBe(2)
		expect(StoryRules.exitOutcome(w.story, "walk_away")).toBe("left_after_request")
	end)

	t.test("E1: friendliness, the Pal card and leaving earn nothing and cost nothing", function()
		for _, picks in { {}, { "thanks" }, { "hi", "go" }, { "thanks", "cute", "bye" } } do
			local w = walk("park_e1_hello", picks)
			expect(w.story.concern).toBe(false)
			local ledger = ledgerAfter(w.events)
			expect(L.total(ledger, ScoreRules)).toBe(0)
			-- Facts are still on file for Lee's menu.
			if #picks > 0 then
				expect(ledger.seenFacts.e1.e1_same_breed).toBe(true)
			end
		end
	end)

	t.test("E2 paths: refusal, recovery and asking Lee", function()
		local held = walk("park_e2_deal", { "refuse", "no_deal", "continue" })
		expect(held.ended).toBe(true)
		expect(held.outcome).toBe("refused_held")
		expect(L.categories(ledgerAfter(held.events), ScoreRules).respond).toBe(2)

		-- Agreement then "try again" earns the same credit (spec 11).
		local retry = walk("park_e2_deal", { "agree", "retry", "no", "agree", "retry", "still_no", "continue" })
		expect(retry.outcome).toBe("agreed_retry_ok")
		local ledger = ledgerAfter(retry.events)
		expect(L.categories(ledger, ScoreRules).respond).toBe(2)
		expect(ledger.needsCoaching.e2).toBe(nil) -- a safe pick cleared it

		local kept = walk("park_e2_deal", { "agree", "play" })
		expect(kept.outcome).toBe("agreed_kept_playing")
		ledger = ledgerAfter(kept.events)
		expect(L.categories(ledger, ScoreRules).respond).toBe(0)
		expect(ledger.needsCoaching.e2).toBe(true) -- stays set; never gates

		local lee = walk("park_e2_deal", { "ask_lee" })
		expect(lee.outcome).toBe("help_after_request")
		expect(L.categories(ledgerAfter(lee.events), ScoreRules).respond).toBe(2)

		local pushLee = walk("park_e2_deal", { "no", "ask_lee" })
		expect(pushLee.outcome).toBe("help_after_request")
		expect(L.categories(ledgerAfter(pushLee.events), ScoreRules).respond).toBe(2)
	end)

	t.test("E2: the repeat Pal Request is presented only after a declined Pal card", function()
		local declined = walk("park_e2_deal", { "no" }, "declined")
		local accepted = walk("park_e2_deal", { "no" }, "accepted")
		expect(table.find(declined.facts, "e2_pal_repeat") ~= nil).toBe(true)
		expect(table.find(accepted.facts, "e2_pal_repeat")).toBe(nil)
	end)

	t.test("E2 reflection: only the right pattern earns Recognize", function()
		local enc = Content.encounters.park_e2_deal
		local credits = {}
		for _, c in enc.nodes.reflect.choices do
			local gives = false
			for _, a in c.actions or {} do
				if a.kind == "recognized" then
					gives = true
				end
			end
			credits[c.id] = gives
		end
		expect(credits.right).toBe(true)
		expect(credits.twin).toBe(false)
		expect(credits.fine).toBe(false)
	end)

	t.test("Reach Out: Lee direct and Cara-then-Lee both cap at 2 for E2", function()
		local base = walk("park_e2_deal", { "refuse", "no_deal", "continue" }).events
		local lee = table.clone(base)
		table.insert(lee, { kind = "told_lee", beat = "e2" })
		table.insert(lee, { kind = "told_lee", beat = "e2" })
		expect(L.categories(ledgerAfter(lee), ScoreRules).reach).toBe(2)
		local cara = table.clone(base)
		table.insert(cara, { kind = "told_cara", beat = "e2" })
		expect(L.categories(ledgerAfter(cara), ScoreRules).reach).toBe(1)
		table.insert(cara, { kind = "told_lee", beat = "e2" })
		table.insert(cara, { kind = "told_cara", beat = "e2" })
		expect(L.categories(ledgerAfter(cara), ScoreRules).reach).toBe(2)
		-- E1 told to Lee earns nothing.
		local e1 = walk("park_e1_hello", { "thanks" }).events
		table.insert(e1, { kind = "told_lee", beat = "e1" })
		expect(L.total(ledgerAfter(e1), ScoreRules)).toBe(0)
	end)

	t.test("roleplay: after blocking Sparkz, rp_e2_deal earns every E2 point without moving the campaign", function()
		local s = activeAt("e1")
		s = run(s, { Rules.blocked("sparkz_pup"), { kind = "resolved", beat = "e1" } })
		expect(Sched.status(s, "e2")).toBe("skipped_by_block")
		local w = walk("rp_e2_deal", { "ready", "refuse", "no_deal", "continue" })
		expect(w.viaRoleplay).toBe(true)
		expect(w.nodeId).toBe("debrief")
		local _, sch = Rules.exitEvents({ kind = "completed", facts = w.facts }, "e2", true, isConcerning)
		expect(#sch).toBe(0)
		local events = table.clone(w.events)
		table.insert(events, { kind = "recognized", beat = "e2" })
		table.insert(events, { kind = "told_lee", beat = "e2" })
		local ledger = ledgerAfter(events)
		local cats = L.categories(ledger, ScoreRules)
		expect(cats.respond).toBe(2)
		expect(cats.reach).toBe(2)
		expect(ledger.evidence["recognize.e2"]).toBe(1)
		expect(ledger.encountered.e2).toBe("roleplay")
	end)

	t.test("determinism: the same activities and choices give the same story (203)", function()
		local function session()
			local s = run(Sched.defaultState(), { { kind = "onboarding_done" } })
			local ledger = L.default()
			local log = {}
			local script = {
				{ sceneId = "park_e1_hello", picks = { "thanks", "cute", "bye" } },
				{ sceneId = "green_riley", picks = { "not_now", "bye" } },
				{ sceneId = "park_e2_deal", picks = { "agree", "retry", "refuse", "no_deal", "continue" } },
			}
			local step = 1
			for _ = 1, 12 do
				s = run(s, { ACT, { kind = "active_seconds", seconds = 120 } })
				local d = Sched.decide(s, { busy = false, available = AVAILABLE, ambient = StoryRules.ambientFor(s, StoryRules.defaultStory(), {}) })
				table.insert(log, d and (d.beat or d.id) or "-")
				if d and d.kind == "campaign" then
					local scene = script[step]
					step += 1
					s = run(s, { { kind = "invited", beat = d.beat }, { kind = "accepted", beat = d.beat } })
					local w = walk(scene.sceneId, scene.picks)
					for _, e in w.events do
						L.record(ledger, ScoreRules, e)
					end
					local _, sch = Rules.exitEvents({ kind = "completed", facts = w.facts }, d.beat, false, isConcerning)
					s = run(s, sch)
				end
			end
			return s, ledger, table.concat(log, ",")
		end
		local s1, l1, log1 = session()
		local s2, l2, log2 = session()
		expect(log1).toBe(log2)
		expect(deepEqual(s1, s2)).toBe(true)
		expect(deepEqual(l1, l2)).toBe(true)
		-- E1, green_riley, E2 in order, one at a time; then Cara's ambient
		-- talk (E3 has no scene in this build, so it is passed over).
		expect(string.sub(log1, 1, #"e1,green_riley,e2")).toBe("e1,green_riley,e2")
		expect(string.find(log1, "cara_talk_1", 1, true) ~= nil).toBe(true)
		expect(string.find(log1, "e3", 1, true)).toBe(nil)
	end)

	t.test("fetch counts completed rounds, not throws (203)", function()
		-- A fetch completion needs several catches in the park (one round).
		expect(Activities.fetch.goal >= 2).toBe(true)
		-- Only a completed round moves the story; throws are not events.
		local s = run(Sched.defaultState(), { { kind = "onboarding_done" } })
		for _ = 1, 10 do
			s = Sched.apply(s, { kind = "fetch_throw" })
		end
		expect(s.completedActivities).toBe(0)
		expect(Sched.status(s, "e1")).toBe("not_started")
		s = Sched.apply(s, Rules.ACTIVITY_COMPLETED)
		expect(s.completedActivities).toBe(1)
		expect(Sched.status(s, "e1")).toBe("eligible")
	end)

	t.test("invitations: one at a time, never while busy, only beats with a scene", function()
		local s = run(Sched.defaultState(), { { kind = "onboarding_done" }, ACT })
		expect(Sched.decide(s, { busy = true, available = AVAILABLE })).toBe(nil)
		local d = Sched.decide(s, { busy = false, available = AVAILABLE })
		expect(d.beat).toBe("e1")
		s = Sched.apply(s, { kind = "invited", beat = "e1" })
		expect(Sched.decide(s, { busy = false, available = AVAILABLE })).toBe(nil)
		-- A beat without a scene is never invited.
		local only = Sched.decide(run(Sched.defaultState(), { { kind = "onboarding_done" }, ACT }), { busy = false, available = { e2 = true } })
		expect(only).toBe(nil)
	end)
end

--[[
	Lee's tell menu (spec 211): it lists only facts actually presented,
	drops a fact once told, and "That's all I want to say." exits from every
	node. Runs over the real lee_tell content and fact registry.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local LeeTell = require(Server.Logic.LeeTell)
local Content = require(Server.Content)

local DEF = Content.encounters.lee_tell
local REG = {
	facts = Content.facts,
	order = Content.factOrder,
	moments = Content.moments,
	beatOrder = Content.factBeats,
}

local function ids(view): { [string]: boolean }
	local set = {}
	for _, c in view.choices do
		set[c.id] = true
	end
	return set
end

local function count(view): number
	return #view.choices
end

return function(t)
	local expect = t.expect

	t.test("lee tell: contextual menu lists only facts on file for that beat", function()
		local onFile = { e2 = { e2_ask_school = true } }
		local s = LeeTell.open(REG, onFile, "ctx", "e2", false)
		local v = LeeTell.view(s, DEF, REG, onFile)
		local set = ids(v)
		expect(v.nodeId).toBe("open_ctx")
		expect(set.e2_ask_school).toBe(true)
		expect(set.e2_ask_town).toBe(nil)
		expect(set.e2_coin_deal).toBe(nil)
		expect(set.other).toBe(nil) -- no other beat has facts
		expect(set.not_sure).toBe(true)
		expect(set.agreed_first).toBe(true)
		expect(set.done).toBe(true)
	end)

	t.test("lee tell: a told fact leaves the list; 'more' falls back to the moments", function()
		local onFile = { e2 = { e2_ask_school = true, e2_ask_town = true } }
		local s = LeeTell.open(REG, onFile, "ctx", "e2", false)
		local ok, r = LeeTell.choose(s, DEF, REG, onFile, "e2_ask_school")
		expect(ok).toBe(true)
		expect(r.told).toBe("e2_ask_school")
		expect(r.beat).toBe("e2")
		expect(LeeTell.view(s, DEF, REG, onFile).nodeId).toBe("ack")
		LeeTell.choose(s, DEF, REG, onFile, "more")
		local v = LeeTell.view(s, DEF, REG, onFile)
		expect(v.nodeId).toBe("facts")
		expect(ids(v).e2_ask_school).toBe(nil)
		expect(ids(v).e2_ask_town).toBe(true)
		LeeTell.choose(s, DEF, REG, onFile, "e2_ask_town")
		LeeTell.choose(s, DEF, REG, onFile, "more")
		expect(LeeTell.view(s, DEF, REG, onFile).nodeId).toBe("open_general")
		-- Telling the same fact again is not offered.
		local again = LeeTell.choose(s, DEF, REG, onFile, "e2_ask_town")
		expect(again).toBe(false)
	end)

	t.test("lee tell: an unseen fact id is never accepted", function()
		local onFile = { e2 = { e2_ask_school = true } }
		local s = LeeTell.open(REG, onFile, "ctx", "e2", false)
		expect((LeeTell.choose(s, DEF, REG, onFile, "e2_coin_deal"))).toBe(false)
		expect((LeeTell.choose(s, DEF, REG, onFile, "e3_go_alone"))).toBe(false)
		expect((LeeTell.choose(s, DEF, REG, onFile, 42))).toBe(false)
	end)

	t.test("lee tell: general mode skips the moments when one beat has facts", function()
		local onFile = { e1 = { e1_compliment = true } }
		local s = LeeTell.open(REG, onFile, "general", nil, false)
		local v = LeeTell.view(s, DEF, REG, onFile)
		expect(v.nodeId).toBe("facts")
		expect(ids(v).e1_compliment).toBe(true)
		expect(ids(v).done).toBe(true)
	end)

	t.test("lee tell: general mode shows a moment per beat with facts", function()
		local onFile = { e1 = { e1_compliment = true }, e2 = { e2_ask_school = true } }
		local s = LeeTell.open(REG, onFile, "general", nil, false)
		local v = LeeTell.view(s, DEF, REG, onFile)
		expect(v.nodeId).toBe("open_general")
		local set = ids(v)
		expect(set.moment_e1).toBe(true)
		expect(set.moment_e2).toBe(true)
		expect(set.moment_e3).toBe(nil)
		expect(set.agreed_first).toBe(true)
		LeeTell.choose(s, DEF, REG, onFile, "moment_e2")
		v = LeeTell.view(s, DEF, REG, onFile)
		expect(v.nodeId).toBe("facts")
		expect(ids(v).e2_ask_school).toBe(true)
		expect(ids(v).e1_compliment).toBe(nil)
	end)

	t.test("lee tell: 'I agreed at first' needs an e2-e5 fact in general mode", function()
		local onFile = { e1 = { e1_compliment = true }, e2 = {} }
		local s = LeeTell.open(REG, onFile, "general", nil, false)
		LeeTell.choose(s, DEF, REG, onFile, "back") -- skipped to facts; back to the hub
		local v = LeeTell.view(s, DEF, REG, onFile)
		expect(v.nodeId).toBe("open_general")
		expect(ids(v).agreed_first).toBe(nil)
	end)

	t.test("lee tell: 'That's all I want to say' is on every node, and close ends", function()
		local onFile = {
			e1 = { e1_compliment = true, e1_pal_request = true },
			e2 = { e2_ask_school = true, e2_coin_deal = true },
		}
		-- Breadth-first over every reachable menu state, from both modes.
		local starts = {
			LeeTell.open(REG, onFile, "general", nil, false),
			LeeTell.open(REG, onFile, "ctx", "e2", true),
		}
		local function copy(s)
			local c = table.clone(s)
			c.told = table.clone(s.told)
			return c
		end
		local queue = starts
		local seen = {}
		local reachedClose = false
		local steps = 0
		while #queue > 0 and steps < 400 do
			steps += 1
			local s = table.remove(queue, 1)
			local v = LeeTell.view(s, DEF, REG, onFile)
			local key = `{v.nodeId}|{s.focus}|{s.listFrom}|{s.toldCount}`
			if not seen[key] then
				seen[key] = true
				if v.nodeId == "close" then
					reachedClose = true
					expect(count(v)).toBe(1)
					local ok, r = LeeTell.choose(copy(s), DEF, REG, onFile, "bye")
					expect(ok).toBe(true)
					expect(r.ended).toBe(true)
				else
					if not ids(v).done then
						error(`node {v.nodeId} has no "done"`)
					end
					local ok, r = LeeTell.choose(copy(s), DEF, REG, onFile, "done")
					expect(ok).toBe(true)
					expect(r.ended).toBe(false)
					for _, c in v.choices do
						local nextState = copy(s)
						LeeTell.choose(nextState, DEF, REG, onFile, c.id)
						table.insert(queue, nextState)
					end
				end
			end
		end
		expect(reachedClose).toBe(true)
	end)

	t.test("lee tell: the core response comes with the first fact only", function()
		local onFile = { e2 = { e2_ask_school = true, e2_ask_town = true } }
		local s = LeeTell.open(REG, onFile, "ctx", "e2", false)
		LeeTell.choose(s, DEF, REG, onFile, "e2_ask_school")
		local first = LeeTell.view(s, DEF, REG, onFile).text
		expect(string.find(first, Content.facts.e2_ask_school.leeReply, 1, true) ~= nil).toBe(true)
		expect(string.find(first, "You're not in trouble", 1, true) ~= nil).toBe(true)
		LeeTell.choose(s, DEF, REG, onFile, "more")
		LeeTell.choose(s, DEF, REG, onFile, "e2_ask_town")
		local second = LeeTell.view(s, DEF, REG, onFile).text
		expect(string.find(second, Content.facts.e2_ask_town.leeReply, 1, true) ~= nil).toBe(true)
		expect(string.find(second, "You're not in trouble", 1, true)).toBe(nil)
	end)

	t.test("lee tell: closing = done; closing at the end leaves", function()
		local onFile = { e2 = { e2_ask_school = true } }
		local s = LeeTell.open(REG, onFile, "ctx", "e2", false)
		expect(LeeTell.leave(s)).toBe(false)
		local v = LeeTell.view(s, DEF, REG, onFile)
		expect(v.nodeId).toBe("close")
		expect(v.text).toBe(DEF.nodes.close.nothingText) -- nothing told: still warm
		expect(LeeTell.leave(s)).toBe(true)
	end)

	t.test("lee tell: after telling, Lee's close thanks the player", function()
		local onFile = { e2 = { e2_ask_school = true } }
		local s = LeeTell.open(REG, onFile, "ctx", "e2", false)
		LeeTell.choose(s, DEF, REG, onFile, "e2_ask_school")
		LeeTell.choose(s, DEF, REG, onFile, "done")
		expect(LeeTell.view(s, DEF, REG, onFile).text).toBe(DEF.nodes.close.text)
	end)

	t.test("lee tell: arriving with Cara uses Cara's greeting", function()
		local onFile = { e2 = { e2_ask_school = true } }
		local s = LeeTell.open(REG, onFile, "ctx", "e2", true)
		expect(LeeTell.view(s, DEF, REG, onFile).text).toBe(DEF.nodes.open_ctx.withCaraText)
	end)

	t.test("lee tell: not sure / agreed first re-offer the same list and never require a fact", function()
		local onFile = { e2 = { e2_ask_school = true } }
		local s = LeeTell.open(REG, onFile, "ctx", "e2", false)
		LeeTell.choose(s, DEF, REG, onFile, "not_sure")
		local v = LeeTell.view(s, DEF, REG, onFile)
		expect(v.nodeId).toBe("not_sure")
		expect(ids(v).e2_ask_school).toBe(true)
		expect(ids(v).just_checking).toBe(true)
		local ok, r = LeeTell.choose(s, DEF, REG, onFile, "just_checking")
		expect(ok).toBe(true)
		expect(r.told).toBe(nil)
		expect(LeeTell.view(s, DEF, REG, onFile).nodeId).toBe("close")

		s = LeeTell.open(REG, onFile, "ctx", "e2", false)
		LeeTell.choose(s, DEF, REG, onFile, "agreed_first")
		v = LeeTell.view(s, DEF, REG, onFile)
		expect(v.nodeId).toBe("agreed_first")
		expect(ids(v).e2_ask_school).toBe(true)
		ok, r = LeeTell.choose(s, DEF, REG, onFile, "done")
		expect(r.told).toBe(nil)
	end)
end

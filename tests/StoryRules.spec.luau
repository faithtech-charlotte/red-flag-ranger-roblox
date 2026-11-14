--[[
	StoryRules: the button bar (campaign-script 1.3), outcome codes (1.7),
	Cara's follow-up rule (4.4), story presence (plan change 12), the
	practice-tool tip (1.5) and the saved story flags.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local R = require(Server.Logic.StoryRules)

local function has(list, id): boolean
	return table.find(list, id) ~= nil
end

local function node(extra)
	local info = {
		campaign = true,
		role = "peer",
		isLee = false,
		rule = "B",
		concern = false,
		kind = "node",
		recovery = false,
		pretend = false,
		inReflect = false,
		hasReflect = true,
	}
	for k, v in extra or {} do
		info[k] = v
	end
	return info
end

return function(t)
	local expect = t.expect

	t.test("bar: leave and help on every conversation, help hidden only with Lee", function()
		for _, kind in { "node", "tip", "card", "feedback" } do
			local bar = R.barFor(node({ kind = kind }))
			expect(bar[1]).toBe("leave")
			expect(has(bar, "help")).toBe(true)
		end
		local lee = R.barFor(node({ role = "trusted_adult", isLee = true, campaign = false }))
		expect(#lee).toBe(1)
		expect(lee[1]).toBe("leave")
	end)

	t.test("bar: legacy peers keep block/report; adults get none", function()
		local peer = R.barFor(node({ campaign = false }))
		expect(has(peer, "block")).toBe(true)
		expect(has(peer, "report")).toBe(true)
		expect(has(peer, "off")).toBe(false)
		local adult = R.barFor(node({ campaign = false, role = "trusted_adult" }))
		expect(has(adult, "block")).toBe(false)
	end)

	t.test("bar: rule B and A show 'Something feels off'; rule C hides it", function()
		expect(has(R.barFor(node({ rule = "B" })), "off")).toBe(true)
		expect(has(R.barFor(node({ rule = "A", concern = true })), "off")).toBe(true)
		local cara = R.barFor(node({ rule = "C" }))
		expect(has(cara, "off")).toBe(false)
		expect(has(cara, "block")).toBe(true) -- Cara stays blockable
		expect(has(R.barFor(node({ hasReflect = false })), "off")).toBe(false)
	end)

	t.test("bar: a roleplay's pretend node is rule A even in a rule-C scene", function()
		local bar = R.barFor(node({ rule = "C", pretend = true }))
		expect(has(bar, "off")).toBe(true)
		expect(has(bar, "block")).toBe(true)
		expect(R.effectiveRule(node({ rule = "C", pretend = true }))).toBe("A")
		expect(R.effectiveRule(node({ rule = "B", concern = true }))).toBe("A")
		expect(R.effectiveRule(node({ rule = "B" }))).toBe("B")
	end)

	t.test("bar: recovery, reflections and cards show only leave and help", function()
		for _, extra in { { recovery = true }, { inReflect = true }, { kind = "card" }, { kind = "tip" } } do
			local bar = R.barFor(node(extra))
			expect(#bar).toBe(2)
		end
	end)

	t.test("outcome: leaving before and after the request", function()
		expect(R.exitOutcome({ concern = false }, "walk_away")).toBe("left")
		expect(R.exitOutcome({ concern = true }, "walk_away")).toBe("left_after_request")
		expect(R.exitOutcome({ concern = true, refused = true }, "walk_away")).toBe("refused_left")
		expect(R.exitOutcome({ concern = true }, "respawn")).toBe("left_after_request")
		expect(R.exitOutcome({ concern = true }, "disconnect")).toBe("left_after_request")
	end)

	t.test("outcome: help, block, report and completed endings", function()
		expect(R.exitOutcome({ concern = true }, "help")).toBe("help_after_request")
		expect(R.exitOutcome({ concern = false }, "help")).toBe("left")
		expect(R.exitOutcome({ concern = true, refused = true }, "blocked")).toBe("blocked")
		expect(R.exitOutcome({ concern = false }, "reported")).toBe("reported")
		expect(R.exitOutcome({ concern = true }, "completed", "refused_held")).toBe("refused_held")
		expect(R.exitOutcome({ concern = false }, "completed", "friendly")).toBe("friendly")
	end)

	t.test("outcome: a safe ending after a simulated agreement is agreed_retry_ok", function()
		local s = { concern = true, refused = true, agreed = true }
		expect(R.exitOutcome(s, "completed", "refused_held")).toBe("agreed_retry_ok")
		expect(R.exitOutcome(s, "walk_away")).toBe("agreed_retry_ok")
		expect(R.exitOutcome(s, "completed", "agreed_kept_playing")).toBe("agreed_kept_playing")
		expect(R.exitOutcome(s, "completed", "agreed_to_lee")).toBe("agreed_to_lee")
		expect(R.exitOutcome(s, "blocked")).toBe("blocked")
	end)

	t.test("outcome: leaving the recovery card is keep playing; Help there is Lee", function()
		local s = { concern = true, agreed = true }
		expect(R.exitOutcome(s, "walk_away", nil, true)).toBe("agreed_kept_playing")
		expect(R.exitOutcome(s, "respawn", nil, true)).toBe("agreed_kept_playing")
		expect(R.exitOutcome(s, "help", nil, true)).toBe("agreed_to_lee")
		expect(R.exitOutcome(s, "completed", "agreed_to_lee", true)).toBe("agreed_to_lee")
	end)

	t.test("follow-up: offered after real endings, never after skip, help, recovery or interruption", function()
		expect(R.followUpAllowed("beat", "completed", "refused_held", false)).toBe(true)
		expect(R.followUpAllowed("beat", "walk_away", "left_after_request", false)).toBe(true)
		expect(R.followUpAllowed("beat", "blocked", "blocked", false)).toBe(true)
		expect(R.followUpAllowed("beat", "help", "help_after_request", false)).toBe(false)
		expect(R.followUpAllowed("beat", "completed", "help_after_request", false)).toBe(false)
		expect(R.followUpAllowed("beat", "completed", "agreed_kept_playing", true)).toBe(false)
		expect(R.followUpAllowed("beat", "walk_away", "left_after_request", true)).toBe(false)
		expect(R.followUpAllowed("beat", "respawn", "left_after_request", false)).toBe(false)
		expect(R.followUpAllowed("beat", "disconnect", "left", false)).toBe(false)
		expect(R.followUpAllowed("healthy", "completed", "friendly", false)).toBe(false)
		expect(R.followUpAllowed("roleplay", "completed", "refused_held", false)).toBe(false)
	end)

	t.test("presence: Sparkz shows only while one of the player's Sparkz beats is open", function()
		local available = { e1 = true, green_riley = true, e2 = true }
		local function seen(beats, npcs)
			return R.presence({ beats = beats }, npcs or {}, available).sparkz_pup
		end
		expect(seen({})).toBe(false)
		expect(seen({ e1 = "eligible" })).toBe(true)
		expect(seen({ e1 = "deferred" })).toBe(true)
		expect(seen({ e1 = "resolved", green_riley = "eligible" })).toBe(false)
		expect(seen({ e1 = "resolved", e2 = "active" })).toBe(true)
		-- e3 has no scene in this build: Sparkz stays away.
		expect(seen({ e1 = "resolved", e2 = "resolved", e3 = "eligible" })).toBe(false)
		-- Blocking hides Sparkz whatever the story says.
		expect(seen({ e1 = "eligible" }, { sparkz_pup = { blocked = true } })).toBe(false)
	end)

	t.test("ambient: cara_talk_1 after E2 is done, once, never if Cara is blocked", function()
		local story = R.defaultStory()
		expect(R.ambientFor({ beats = { e2 = "eligible" } }, story, {})).toBe(nil)
		expect(R.ambientFor({ beats = { e2 = "resolved" } }, story, {})).toBe("cara_talk_1")
		expect(R.ambientFor({ beats = { e2 = "skipped_by_block" } }, story, {})).toBe("cara_talk_1")
		expect(R.ambientFor({ beats = { e2 = "resolved" } }, story, { cara = { blocked = true } })).toBe(nil)
		story.seen.cara_talk_1 = true
		expect(R.ambientFor({ beats = { e2 = "resolved" } }, story, {})).toBe(nil)
	end)

	t.test("practice tip: once, and only for a bar with block or report", function()
		local story = R.defaultStory()
		expect(R.needsPracticeTip(story, { "leave", "help" })).toBe(false)
		expect(R.needsPracticeTip(story, { "leave", "help", "block", "report" })).toBe(true)
		story.practiceTipShown = true
		expect(R.needsPracticeTip(story, { "leave", "help", "block", "report" })).toBe(false)
	end)

	t.test("story flags: sanitize keeps valid fields and drops junk", function()
		local s = R.sanitize({
			seen = { onb_lee_welcome = true, [5] = true, bad = "yes" },
			palChoice = "declined",
			palRepeat = "maybe",
			recoverySeen = true,
			practiceTipShown = "true",
			outcomes = { e2 = "refused_held", e9 = "friendly", e1 = "made_up" },
			followUpOffered = { e1 = true, nope = true },
			extra = { anything = true },
		})
		expect(s.seen.onb_lee_welcome).toBe(true)
		expect(s.seen.bad).toBe(nil)
		expect(s.palChoice).toBe("declined")
		expect(s.palRepeat).toBe("none")
		expect(s.recoverySeen).toBe(true)
		expect(s.practiceTipShown).toBe(false)
		expect(s.outcomes.e2).toBe("refused_held")
		expect(s.outcomes.e9).toBe(nil)
		expect(s.outcomes.e1).toBe(nil)
		expect(s.followUpOffered.e1).toBe(true)
		expect(s.followUpOffered.nope).toBe(nil)
		expect(s.extra).toBe(nil)
		expect(R.sanitize(nil).palChoice).toBe("none")
	end)

	t.test("story flags: the seen set is bounded", function()
		local raw = { seen = {} }
		for i = 1, 200 do
			raw.seen[`scene_{i}`] = true
		end
		local n = 0
		for _ in R.sanitize(raw).seen do
			n += 1
		end
		expect(n).toBe(R.MAX_SEEN)
	end)

	t.test("activity phrases fill {activity}", function()
		expect(R.activityPhrase("fetch")).toBe("fetch")
		expect(R.activityPhrase("agility")).toBe("agility run")
		expect(R.activityPhrase("grooming")).toBe("spa day")
		expect(R.activityPhrase("trail_walk")).toBe("trail walk")
		expect(R.activityPhrase(nil)).toBe("play")
	end)
end

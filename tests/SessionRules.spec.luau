local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local SessionRules = require(Server.Logic.SessionRules)

return function(t)
	local expect = t.expect

	t.test("a live lock held by another server is refused", function()
		local session = { jobId = "other", updated = 1000 }
		expect(SessionRules.lockedElsewhere(session, "me", 1100, 300)).toBe(true)
	end)

	t.test("a stale, missing or own lock is not a conflict", function()
		expect(SessionRules.lockedElsewhere({ jobId = "other", updated = 1000 }, "me", 1400, 300)).toBe(false)
		expect(SessionRules.lockedElsewhere(nil, "me", 1100, 300)).toBe(false)
		expect(SessionRules.lockedElsewhere({ jobId = "me", updated = 1000 }, "me", 1100, 300)).toBe(false)
	end)

	t.test("feedback cards accept only the choices they show", function()
		expect(SessionRules.isFeedbackChoice("ok")).toBe(true)
		expect(SessionRules.isFeedbackChoice("help")).toBe(true)
		expect(SessionRules.isFeedbackChoice("refuse")).toBe(false)
		expect(SessionRules.isFeedbackChoice(nil)).toBe(false)
		expect(SessionRules.isFeedbackChoice(42)).toBe(false)
	end)

	t.test("a close request only targets the session it names", function()
		-- Session ids are numbers (EncounterService nextSessionId).
		expect(SessionRules.closeTargets(2, { sessionId = 2 })).toBe(true)
		expect(SessionRules.closeTargets(2, { sessionId = 1 })).toBe(false)
		expect(SessionRules.closeTargets(2, { sessionId = "2" })).toBe(false)
		expect(SessionRules.closeTargets(2, {})).toBe(false)
		expect(SessionRules.closeTargets(2, nil)).toBe(false)
		expect(SessionRules.closeTargets(nil, { sessionId = 1 })).toBe(false)
	end)

	t.test("a save only proceeds while this server owns the lock", function()
		expect(SessionRules.ownsLock({ jobId = "me", updated = 1 }, "me")).toBe(true)
		expect(SessionRules.ownsLock({ jobId = "other", updated = 1 }, "me")).toBe(false)
		-- Lock released by another server after taking over: not ours.
		expect(SessionRules.ownsLock(nil, "me")).toBe(false)
	end)
end

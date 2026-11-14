local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Activity = require(Server.Services.ActivityService)

return function(t)
	t.test("stale fetch interruption leaves the replacement session running", function()
		local player = {} :: any
		local fetchInterrupted, spaInterrupted = 0, 0
		local fetch = Activity.begin(player, "fetch_play", function()
			fetchInterrupted += 1
		end)
		local spa = Activity.begin(player, "grooming", function()
			spaInterrupted += 1
		end)
		Activity.interrupt(player, "interrupted", fetch)
		local current = Activity.current(player)
		Activity.finish(player, spa)
		t.expect(fetchInterrupted).toBe(1)
		t.expect(spaInterrupted).toBe(0)
		t.expect(current).toBe(spa)
	end)

	t.test("a matching session interrupts and cleans up only once", function()
		local player = {} :: any
		local interrupted = 0
		local reason
		local session = Activity.begin(player, "fetch_play", function(why)
			interrupted += 1
			reason = why
		end)
		Activity.interrupt(player, "no pet", session)
		Activity.interrupt(player, "interrupted", session)
		t.expect(Activity.current(player)).toBe(nil)
		t.expect(interrupted).toBe(1)
		t.expect(reason).toBe("no pet")
	end)

	t.test("player cancellation still interrupts the current session", function()
		local player = {} :: any
		local interrupted = false
		Activity.begin(player, "grooming", function()
			interrupted = true
		end)
		Activity.interrupt(player, "cancelled")
		t.expect(Activity.current(player)).toBe(nil)
		t.expect(interrupted).toBe(true)
	end)
end

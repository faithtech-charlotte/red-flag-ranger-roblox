local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Ratings = require(Server.Logic.Ratings)
local ProfileSchema = require(Server.Data.ProfileSchema)

return function(t)
	local expect = t.expect

	t.test("ratings: only integers 1-3 are valid", function()
		for _, v in { 1, 2, 3 } do
			expect(Ratings.isValid(v)).toBe(true)
		end
		for _, v in { 0, 4, -1, 2.5, 0 / 0, math.huge, "3", true, {} } do
			expect(Ratings.isValid(v)).toBe(false)
		end
		expect(Ratings.isValid(nil)).toBe(false)
	end)

	t.test("ratings: best keeps the higher valid rating", function()
		expect(Ratings.best(nil, 2)).toBe(2)
		expect(Ratings.best(2, 3)).toBe(3)
		expect(Ratings.best(3, 1)).toBe(3)
		expect(Ratings.best(2, 9)).toBe(2) -- invalid new rating is ignored
		expect(Ratings.best(nil, "3")).toBe(nil)
		expect(Ratings.best(7, 1)).toBe(1) -- a corrupt stored value is replaced
	end)

	t.test("ratings: label says the count in words", function()
		expect(Ratings.label(2):find("2 of 3 stars") ~= nil).toBe(true)
	end)

	t.test("ratings: a saved bestRating survives loading", function()
		-- Optional field on the activity record: no schema bump needed.
		local p = ProfileSchema.migrate({ schemaVersion = 2, activities = { grooming = { count = 2, bestRating = 3 } } }, 0)
		expect(p.activities.grooming.bestRating).toBe(3)
	end)
end

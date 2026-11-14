--[[
	Ratings: activity star ratings (1-3), e.g. trail stars and spa shine.
	Pure logic, unit-tested in tests/Ratings.spec. ActivityService.complete
	uses it to validate data.rating and keep profile.activities[id].bestRating.
]]

local Ratings = {}

Ratings.MIN = 1
Ratings.MAX = 3

-- An integer from 1 to 3; anything else (fractions, NaN, strings) is invalid.
function Ratings.isValid(v: any): boolean
	return typeof(v) == "number" and v == v and v % 1 == 0 and v >= Ratings.MIN and v <= Ratings.MAX
end

-- The rating to keep: the better of the stored best and a new valid one.
function Ratings.best(old: any, new: any): number?
	local o = Ratings.isValid(old) and old or nil
	if not Ratings.isValid(new) then
		return o
	end
	if o == nil or new > o then
		return new
	end
	return o
end

-- "⭐⭐ 2 of 3 stars": the count is in words too, never the icons alone.
function Ratings.label(stars: number): string
	return `{string.rep("⭐", stars)}  {stars} of {Ratings.MAX} stars`
end

return Ratings

--[[
	PetStateMachine: the dog's behavior states and which changes are allowed.
	Pure logic (unit-tested). PetService applies it to the real model.

	Three kinds of state:
	  base       the dog's "home" behavior until told otherwise:
	             Following, Sitting, Staying
	  temporary  a short reaction that returns to the base state by itself:
	             Idle (paying attention to you), Eating, BeingPetted,
	             Grooming, PerformingTrick
	  activity   driven step by step by an activity (fetch, spa):
	             MovingToTarget, Fetching, Returning

	Movement: exactly ONE thing moves the dog (PetService's AlignPosition).
	Each state says where it points:
	  follow  behind the owner
	  hold    stay where it is
	  target  a point given by the activity
]]

export type State =
	"Following"
	| "Idle"
	| "Sitting"
	| "Staying"
	| "MovingToTarget"
	| "Fetching"
	| "Returning"
	| "Eating"
	| "BeingPetted"
	| "Grooming"
	| "PerformingTrick"

local M = {}

M.Kind = {
	Following = "base",
	Sitting = "base",
	Staying = "base",
	Idle = "temporary",
	Eating = "temporary",
	BeingPetted = "temporary",
	Grooming = "temporary",
	PerformingTrick = "temporary",
	MovingToTarget = "activity",
	Fetching = "activity",
	Returning = "activity",
}

M.Movement = {
	Following = "follow",
	Returning = "follow",
	Sitting = "hold",
	Staying = "hold",
	Idle = "hold",
	Eating = "hold",
	BeingPetted = "hold",
	Grooming = "hold",
	PerformingTrick = "hold",
	MovingToTarget = "target",
	Fetching = "target",
}

-- States in which the dog turns to look at its owner.
M.FacesOwner = {
	Idle = true,
	Eating = true,
	BeingPetted = true,
	PerformingTrick = true,
}

function M.isValid(state: any): boolean
	return typeof(state) == "string" and M.Kind[state] ~= nil
end

function M.isBase(state: string): boolean
	return M.Kind[state] == "base"
end

function M.isTemporary(state: string): boolean
	return M.Kind[state] == "temporary"
end

function M.isActivity(state: string): boolean
	return M.Kind[state] == "activity"
end

--[[
	Can the dog go from `current` to `target`?
	`byActivity` is true when an activity is driving the change (activities
	may move between their own states and into Grooming at the spa).
	Returns (ok, reason?) where reason is player-friendly.
]]
function M.canEnter(current: string, target: string, byActivity: boolean?): (boolean, string?)
	if not M.isValid(target) then
		return false, "unknown state"
	end
	if not M.isValid(current) then
		return true, nil -- recover from anything unexpected
	end
	-- Base commands (sit / stay / come) always work: they interrupt anything.
	if M.isBase(target) then
		return true, nil
	end
	if M.isActivity(current) and not byActivity then
		return false, "Busy playing!"
	end
	if M.isActivity(target) and not byActivity then
		return false, "Busy"
	end
	-- One reaction at a time, except "paying attention" which anything replaces.
	if M.isTemporary(current) and current ~= "Idle" and not byActivity then
		return false, "One thing at a time!"
	end
	return true, nil
end

-- What a temporary/activity state settles back into.
function M.settle(base: string): string
	if M.isBase(base) then
		return base
	end
	return "Following"
end

return M

--[[
	ActionService: validated commands that content (quests, encounters) can
	trigger by name. Content never calls services directly; it lists actions:

	  { action = "grant_currency", amount = 10, reason = "quest" }

	Each action is registered by the service that owns that piece of state.
	run() executes a list in order on the server and stops at the first
	failure. Unknown actions are rejected at content-validation time.
]]

export type ActionSpec = { action: string, [string]: any }
export type Context = { [string]: any }
export type ActionFn = (player: Player, spec: ActionSpec, ctx: Context) -> (boolean, string?)

local ActionService = {}
local registry: { [string]: ActionFn } = {}

function ActionService.register(name: string, fn: ActionFn)
	assert(registry[name] == nil, `Action {name} registered twice`)
	registry[name] = fn
end

function ActionService.has(name: string): boolean
	return registry[name] ~= nil
end

function ActionService.names(): { string }
	local list = {}
	for name in registry do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

function ActionService.run(player: Player, actions: { ActionSpec }?, ctx: Context?): (boolean, string?)
	if not actions then
		return true, nil
	end
	for _, spec in actions do
		local fn = registry[spec.action]
		if not fn then
			warn(`[ActionService] unknown action {spec.action}`)
			return false, "unknown action"
		end
		local ok, result, err = pcall(fn, player, spec, ctx or {})
		if not ok then
			warn(`[ActionService] {spec.action} errored: {result}`)
			return false, "action error"
		end
		if not result then
			return false, err
		end
	end
	return true, nil
end

return ActionService

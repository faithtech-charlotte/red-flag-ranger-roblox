--[[
	EventBus: tiny synchronous pub/sub for "something happened" events.

	Event names in use:
	  pet.adopted         { petId, breedId }
	  activity.completed  { activityId, count, timeSeconds? }
	  item.purchased      { itemId, kind }
	  item.equipped       { itemId, slot, target }
	  quest.completed     { questId }
	  encounter.completed { encounterId, npcId, arcId?, outcome }

	Handlers run in their own thread so one failing handler can't break others.
]]

export type Handler = (player: Player, payload: { [string]: any }) -> ()

local EventBus = {}
local handlers: { [string]: { Handler } } = {}

function EventBus.subscribe(eventName: string, handler: Handler)
	handlers[eventName] = handlers[eventName] or {}
	table.insert(handlers[eventName], handler)
end

function EventBus.publish(eventName: string, player: Player, payload: { [string]: any }?)
	local list = handlers[eventName]
	if not list then
		return
	end
	for _, handler in list do
		task.spawn(function()
			local ok, err = pcall(handler, player, payload or {})
			if not ok then
				warn(`[EventBus] handler for {eventName} failed: {err}`)
			end
		end)
	end
end

return EventBus

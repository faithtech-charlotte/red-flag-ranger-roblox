--[[
	SessionRules: small pure decisions about save locks and dialogue
	sessions, kept here so they are unit-tested (tests/SessionRules.spec).
]]

local SessionRules = {}

-- Choices a feedback (tip) card shows. The server accepts nothing else.
SessionRules.FEEDBACK_CHOICES = {
	{ id = "ok", text = "Okay" },
	{ id = "help", text = "Talk to a trusted adult" },
}

-- Saves (and releases) only go ahead while this server still owns the
-- stored lock. If the lock is gone or belongs to another server, this
-- server lost ownership and must stop writing.
function SessionRules.ownsLock(session: any, jobId: string): boolean
	return typeof(session) == "table" and session.jobId == jobId
end

-- True when another live server holds this save. A held lock is never
-- taken over, however many load attempts have failed: the player plays on
-- a temporary profile instead of overwriting the other server's data.
function SessionRules.lockedElsewhere(session: any, jobId: string, now: number, staleSeconds: number): boolean
	if typeof(session) ~= "table" or session.jobId == jobId then
		return false
	end
	return now - (tonumber(session.updated) or 0) < staleSeconds
end

function SessionRules.isFeedbackChoice(choiceId: any): boolean
	for _, c in SessionRules.FEEDBACK_CHOICES do
		if c.id == choiceId then
			return true
		end
	end
	return false
end

-- A close request only affects the session it names. A stale request (an
-- older session id, or none) must never close a newer conversation.
function SessionRules.closeTargets(currentSessionId: number?, payload: any): boolean
	return currentSessionId ~= nil and typeof(payload) == "table" and payload.sessionId == currentSessionId
end

return SessionRules

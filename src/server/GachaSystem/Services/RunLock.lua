-- One active run per player across all run modes (Dungeon, Tower).
-- Services must Acquire before creating a run and Release when it ends.

local RunLock = {}

local active = {}  -- { [userId] = "Dungeon" | "Tower" }

-- Returns true on success; false + the blocking mode name if already locked.
function RunLock.Acquire(userId, mode)
	if active[userId] then
		return false, active[userId]
	end
	active[userId] = mode
	return true
end

function RunLock.Release(userId)
	active[userId] = nil
end

function RunLock.Get(userId)
	return active[userId]
end

return RunLock

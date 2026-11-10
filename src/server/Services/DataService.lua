-- Player persistence with session locking.
--  * UpdateAsync everywhere (never SetAsync) so concurrent writes can't clobber each other.
--  * A session lock {jobId, time} prevents two servers from loading the same profile
--    (which would otherwise allow double offline payouts / item duplication).
--  * money and lastSeen live in the same record, so they always save/roll back together.
--  * Falls back to in-memory mode in Studio when API access is disabled (clearly warned).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}

local STORE_NAME = "BBL_Player_v1"
local LOCK_TTL = 15 * 60 -- a lock older than this is considered abandoned (crashed server)
local AUTOSAVE_INTERVAL = 120
local LOAD_ATTEMPTS = 5
local SAVE_ATTEMPTS = 3

DataService.Profiles = {} :: { [Player]: any }
DataService.MemoryMode = false

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable (" .. tostring(result) .. "). Running in MEMORY MODE: progress will not persist.")
		DataService.MemoryMode = true
	end
end

local changedCallbacks = {}

function DataService.Template()
	local parts = table.clone(Config.StarterParts)
	return {
		v = 1,
		money = 0,
		totalEarned = 0,
		parts = parts,
		monsters = {}, -- [guid] = { id, name, parts = {slot=partId}, level, xp, created }
		blueprints = {}, -- array of { name, parts }
		lab = { incomeTier = 1, podTier = 1 },
		arenas = { unlocked = 1, firstWins = {} }, -- firstWins keyed by tostring(arenaId)
		tutorial = Config.Tutorial.OpenBuilder,
		lastSeen = 0,
		rebirths = 0,
		stats = { battlesWon = 0, battlesLost = 0, monstersBuilt = 0, cratesOpened = 0 },
	}
end

local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			if type(v) == "table" then
				local copy = {}
				reconcile(copy, v)
				data[k] = copy
			else
				data[k] = v
			end
		elseif type(v) == "table" and type(data[k]) == "table" and k ~= "parts" and k ~= "monsters" then
			-- (parts/monsters are dynamic maps: don't inject template defaults into existing ones)
			reconcile(data[k], v)
		end
	end
	return data
end

local function keyFor(userId: number)
	return "u_" .. userId
end

-- Returns data table or nil, errMessage
function DataService.load(player: Player)
	if DataService.MemoryMode then
		local data = DataService.Template()
		DataService.Profiles[player] = { data = data, loadedAt = os.time() }
		return data
	end

	local key = keyFor(player.UserId)
	for attempt = 1, LOAD_ATTEMPTS do
		local loaded, locked = nil, false
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old)
				loaded, locked = nil, false
				local now = os.time()
				if old and old.lock and old.lock.jobId ~= game.JobId and now - (old.lock.time or 0) < LOCK_TTL then
					locked = true
					return nil -- cancel write; another live server owns this profile
				end
				local data = reconcile(old or DataService.Template(), DataService.Template())
				data.lock = { jobId = game.JobId, time = now }
				loaded = data
				return data
			end)
		end)
		if not player.Parent then
			return nil, "left"
		end
		if ok and loaded then
			DataService.Profiles[player] = { data = loaded, loadedAt = os.time() }
			return loaded
		end
		if not ok and RunService:IsStudio() and tostring(err):find("API") then
			warn(
				"[DataService] Studio API access is disabled. Running in MEMORY MODE: progress will not persist. "
					.. "Enable Game Settings > Security > 'Enable Studio Access to API Services' to test saving."
			)
			DataService.MemoryMode = true
			return DataService.load(player)
		end
		if not ok then
			warn(("[DataService] load attempt %d for %d failed: %s"):format(attempt, player.UserId, tostring(err)))
		elseif locked then
			warn(("[DataService] profile %d locked by another server (attempt %d)"):format(player.UserId, attempt))
		end
		task.wait(attempt * 2)
	end
	return nil, "Your data is still being saved by another server. Please rejoin in a minute."
end

function DataService.get(player: Player)
	local p = DataService.Profiles[player]
	return p and p.data
end

function DataService.profile(player: Player)
	return DataService.Profiles[player]
end

-- release = true on leave: clears the session lock.
function DataService.save(player: Player, release: boolean?)
	local profile = DataService.Profiles[player]
	if not profile then
		return false
	end
	local data = profile.data
	data.lastSeen = os.time()
	if DataService.MemoryMode then
		return true
	end
	local key = keyFor(player.UserId)
	for attempt = 1, SAVE_ATTEMPTS do
		local lostLock = false
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old)
				lostLock = false
				if old and old.lock and old.lock.jobId ~= game.JobId then
					lostLock = true
					return nil
				end
				data.lock = (not release) and { jobId = game.JobId, time = os.time() } or nil
				return data
			end)
		end)
		if ok then
			if lostLock then
				warn("[DataService] lost session lock for " .. player.UserId .. "; save skipped")
				return false
			end
			return true
		end
		warn(("[DataService] save attempt %d for %d failed: %s"):format(attempt, player.UserId, tostring(err)))
		task.wait(attempt)
	end
	return false
end

function DataService.release(player: Player)
	if DataService.Profiles[player] then
		DataService.save(player, true)
		DataService.Profiles[player] = nil
	end
end

-- kind: "monsters" | "parts" | "money" | "lab" | "arena" | "tutorial" | "all"
function DataService.onChanged(fn)
	table.insert(changedCallbacks, fn)
end

function DataService.changed(player: Player, kind: string?)
	for _, fn in ipairs(changedCallbacks) do
		task.spawn(fn, player, kind or "all")
	end
end

function DataService.init()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in pairs(DataService.Profiles) do
				task.spawn(DataService.save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and DataService.MemoryMode then
			return
		end
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			if DataService.Profiles[player] then
				pending += 1
				task.spawn(function()
					DataService.save(player, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService

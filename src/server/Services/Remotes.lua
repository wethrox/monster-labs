-- Creates all remotes and routes client requests through ONE whitelisted, rate-limited
-- dispatcher. Handlers receive (player, payload) and return a result table.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)

local Remotes = {}

local RATE = 8 -- tokens per second
local BURST = 15

local folder: Folder
local handlers = {}
local buckets = {} :: { [Player]: { tokens: number, last: number } }

local function allow(player: Player): boolean
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = BURST, last = now }
		buckets[player] = b
	end
	b.tokens = math.min(BURST, b.tokens + (now - b.last) * RATE)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

local function make(className: string, name: string)
	local r = Instance.new(className)
	r.Name = name
	r.Parent = folder
	return r
end

function Remotes.register(name: string, fn)
	handlers[name] = fn
end

-- Snapshot sent to the owning client. Display data only.
function Remotes.snapshot(player: Player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	return {
		money = data.money,
		parts = data.parts,
		monsters = data.monsters,
		blueprints = data.blueprints,
		lab = data.lab,
		arenas = data.arenas,
		tutorial = data.tutorial,
		rebirths = data.rebirths,
		stats = data.stats,
	}
end

function Remotes.push(player: Player)
	local snap = Remotes.snapshot(player)
	if snap and player.Parent then
		Remotes.StateChanged:FireClient(player, snap)
	end
end

function Remotes.notify(player: Player, kind: string, payload)
	Remotes.Notify:FireClient(player, kind, payload)
end

function Remotes.init()
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	Remotes.Action = make("RemoteFunction", "Action")
	Remotes.StateChanged = make("RemoteEvent", "StateChanged")
	Remotes.BattleEvent = make("RemoteEvent", "BattleEvent")
	Remotes.Notify = make("RemoteEvent", "Notify")
	Remotes.UseAbility = make("RemoteEvent", "UseAbility")
	folder.Parent = ReplicatedStorage -- parent last so clients see a complete folder

	Remotes.Action.OnServerInvoke = function(player: Player, action, payload)
		if type(action) ~= "string" or (payload ~= nil and type(payload) ~= "table") then
			return { ok = false, err = "Bad request" }
		end
		if not allow(player) then
			return { ok = false, err = "Slow down!" }
		end
		local fn = handlers[action]
		if not fn then
			return { ok = false, err = "Unknown action" }
		end
		if action ~= "GetState" and not DataService.get(player) then
			return { ok = false, err = "Your data is still loading" }
		end
		local ok, result = pcall(fn, player, payload or {})
		if not ok then
			warn(("[Remotes] %s from %s errored: %s"):format(action, player.Name, tostring(result)))
			return { ok = false, err = "Server error" }
		end
		if type(result) ~= "table" then
			result = { ok = true }
		end
		return result
	end

	Remotes.register("GetState", function(player)
		local snap = Remotes.snapshot(player)
		return { ok = snap ~= nil, state = snap }
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return Remotes

-- Client-side cache of the server snapshot + request helper. Display only: the server
-- re-validates everything, so tampering here only breaks the tamperer's own UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stats = require(ReplicatedStorage.Shared.Stats)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Action = Remotes:WaitForChild("Action") :: RemoteFunction

local State = {}
State.data = nil
State.Changed = Instance.new("BindableEvent") -- fires (data)
State.onError = nil -- set by Main to show toasts

local lastMoney, lastMoneyAt = 0, os.clock()

function State.invoke(action: string, payload)
	local ok, result = pcall(function()
		return Action:InvokeServer(action, payload)
	end)
	if not ok or type(result) ~= "table" then
		result = { ok = false, err = "Connection problem, try again" }
	end
	if not result.ok and result.err and State.onError then
		State.onError(result.err)
	end
	return result
end

function State.set(data)
	State.data = data
	State.Changed:Fire(data)
end

function State.income(): number
	return player:GetAttribute("IncomePerSec") or 0
end

-- Smoothly interpolated money for the HUD counter.
function State.displayMoney(): number
	return lastMoney + State.income() * math.min(os.clock() - lastMoneyAt, 1.5)
end

player:GetAttributeChangedSignal("Money"):Connect(function()
	lastMoney = player:GetAttribute("Money") or 0
	lastMoneyAt = os.clock()
end)
lastMoney = player:GetAttribute("Money") or 0

function State.money(): number
	return player:GetAttribute("Money") or 0
end

function State.globalMult(): number
	return State.data and Stats.globalMult(State.data) or 1
end

-- Monster income including global multiplier (what the player actually earns from it).
function State.monsterIncome(m): number
	return Stats.monsterIncome(m) * State.globalMult()
end

function State.monsterList()
	local list = {}
	if State.data then
		for _, m in pairs(State.data.monsters) do
			table.insert(list, m)
		end
	end
	table.sort(list, function(a, b)
		return (a.created or 0) < (b.created or 0)
	end)
	return list
end

function State.monsterCount(): number
	local n = 0
	if State.data then
		for _ in pairs(State.data.monsters) do
			n += 1
		end
	end
	return n
end

function State.owned(partId: string): number
	return State.data and State.data.parts[partId] or 0
end

Remotes:WaitForChild("StateChanged").OnClientEvent:Connect(State.set)

return State

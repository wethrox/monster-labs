-- Universal passive income.
-- ONE loop for the whole server. Each player's total income is cached and only recomputed
-- when their monsters/multipliers change. Nothing here looks at whether a monster is in
-- battle, in the builder or displayed: every owned monster always earns.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local DataService = require(script.Parent.DataService)

local IncomeService = {}

local TICK = 1

local function publish(player: Player, profile)
	player:SetAttribute("Money", profile.data.money)
	player:SetAttribute("IncomePerSec", profile.income or 0)
	local ls = player:FindFirstChild("leaderstats")
	local cash = ls and ls:FindFirstChild("Cash")
	if cash then
		cash.Value = math.floor(profile.data.money)
	end
end

function IncomeService.recompute(player: Player)
	local profile = DataService.profile(player)
	if not profile then
		return 0
	end
	profile.income = Stats.totalIncome(profile.data)
	publish(player, profile)
	return profile.income
end

-- Server-authoritative money change. Use for every spend/grant. Returns false if insufficient.
function IncomeService.addMoney(player: Player, amount: number): boolean
	local profile = DataService.profile(player)
	if not profile then
		return false
	end
	if amount ~= amount or amount == math.huge or amount == -math.huge then
		return false
	end
	if amount < 0 and profile.data.money + amount < 0 then
		return false
	end
	profile.data.money += amount
	if amount > 0 then
		profile.data.totalEarned += amount
	end
	publish(player, profile)
	return true
end

-- Called once right after a successful load. Computes offline earnings from SERVER time.
-- Returns summary table or nil.
function IncomeService.applyOffline(player: Player)
	local profile = DataService.profile(player)
	if not profile then
		return nil
	end
	local data = profile.data
	local now = os.time()
	local summary = nil
	if data.lastSeen and data.lastSeen > 0 then
		local away = math.max(0, now - data.lastSeen)
		local credited = math.min(away, Config.Economy.OfflineCapSeconds)
		local rate = Stats.totalIncome(data) * Config.Economy.OfflineRate
		local payout = math.floor(credited * rate)
		if away >= Config.Economy.OfflineMinSeconds and payout > 0 then
			data.money += payout
			data.totalEarned += payout
			summary = {
				away = away,
				credited = credited,
				rate = rate,
				payout = payout,
				capped = away > Config.Economy.OfflineCapSeconds,
			}
		end
	end
	-- Mark the claim consumed in memory immediately; it persists atomically with money.
	data.lastSeen = now
	profile.lastTick = os.clock()
	IncomeService.recompute(player)
	return summary
end

function IncomeService.init()
	task.spawn(function()
		while true do
			task.wait(TICK)
			local now = os.clock()
			for player, profile in pairs(DataService.Profiles) do
				local last = profile.lastTick or now
				local dt = math.min(now - last, 10) -- clamp after server hitches
				profile.lastTick = now
				local income = profile.income or 0
				if income > 0 and dt > 0 then
					local earned = income * dt
					profile.data.money += earned
					profile.data.totalEarned += earned
					publish(player, profile)
				end
			end
		end
	end)
end

return IncomeService

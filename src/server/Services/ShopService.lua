-- Currency sinks: direct part purchases, crates, lab upgrades. Prices come from shared
-- config on the server; the client only names what it wants.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.PartCatalog)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local Loot = require(script.Parent.Loot)

local ShopService = {}

function ShopService.buyPart(player: Player, payload)
	local data = DataService.get(player)
	local p = payload and type(payload.partId) == "string" and Catalog.get(payload.partId)
	if not p or not p.shop or not p.cost then
		return { ok = false, err = "That part is not for sale" }
	end
	if not IncomeService.addMoney(player, -p.cost) then
		return { ok = false, err = "Not enough money" }
	end
	data.parts[p.id] = (data.parts[p.id] or 0) + 1
	DataService.changed(player, "parts")
	return { ok = true, partId = p.id }
end

function ShopService.buyCrate(player: Player, payload)
	local data = DataService.get(player)
	local crate = payload and type(payload.crateId) == "string" and Config.Crates[payload.crateId]
	if not crate then
		return { ok = false, err = "Unknown crate" }
	end
	if not IncomeService.addMoney(player, -crate.cost) then
		return { ok = false, err = "Not enough money" }
	end
	local p = Loot.rollPart(crate.weights)
	if not p then
		IncomeService.addMoney(player, crate.cost) -- refund on config error
		return { ok = false, err = "Crate error, refunded" }
	end
	data.parts[p.id] = (data.parts[p.id] or 0) + 1
	data.stats.cratesOpened += 1
	DataService.changed(player, "parts")
	return { ok = true, partId = p.id }
end

function ShopService.upgradeLab(player: Player, payload)
	local data = DataService.get(player)
	local track = payload and payload.track
	local tiers, key
	if track == "income" then
		tiers, key = Config.LabIncomeTiers, "incomeTier"
	elseif track == "pods" then
		tiers, key = Config.PodTiers, "podTier"
	else
		return { ok = false, err = "Unknown upgrade" }
	end
	local nextTier = tiers[data.lab[key] + 1]
	if not nextTier then
		return { ok = false, err = "Already maxed" }
	end
	if not IncomeService.addMoney(player, -nextTier.cost) then
		return { ok = false, err = "Not enough money" }
	end
	data.lab[key] += 1
	IncomeService.recompute(player)
	DataService.changed(player, "lab")
	return { ok = true, tier = data.lab[key] }
end

return ShopService

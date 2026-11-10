-- Server-only random rolls for crates and battle drops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.PartCatalog)
local Config = require(ReplicatedStorage.Shared.Config)

local Loot = {}
local rng = Random.new()

function Loot.rng()
	return rng
end

function Loot.rollRarity(weights: { [string]: number }): string?
	local total = 0
	for _, r in ipairs(Config.Rarities) do
		total += weights[r] or 0
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for _, r in ipairs(Config.Rarities) do
		local w = weights[r] or 0
		if roll < w then
			return r
		end
		roll -= w
	end
	return nil
end

function Loot.randomPart(rarity: string)
	local pool = Catalog.byRarity(rarity)
	if #pool == 0 then
		return nil
	end
	return pool[rng:NextInteger(1, #pool)]
end

-- Rolls a part from a weight table; returns part def or nil.
function Loot.rollPart(weights)
	local rarity = Loot.rollRarity(weights)
	return rarity and Loot.randomPart(rarity)
end

return Loot

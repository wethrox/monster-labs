-- Pure stat / income / validation math. No Roblox instances touched,
-- so the server's numbers and the builder's live preview always agree.

local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.PartCatalog)

local Stats = {}

local STAT_KEYS = { "hp", "atk", "def", "spd", "aspd", "weight", "crit" }
local SCALED = { hp = true, atk = true, def = true, spd = true, aspd = true, crit = true } -- weight is not rarity scaled

-- Validate a {slot -> partId} map. Returns ok, errMessage.
function Stats.validateBuild(parts: { [string]: string }): (boolean, string?)
	if type(parts) ~= "table" then
		return false, "Invalid build"
	end
	local count = 0
	for slot, partId in pairs(parts) do
		count += 1
		if type(slot) ~= "string" or type(partId) ~= "string" then
			return false, "Invalid build data"
		end
		local slotDef = Config.SlotById[slot]
		if not slotDef then
			return false, "Unknown slot " .. slot
		end
		local p = Catalog.get(partId)
		if not p then
			return false, "Unknown part"
		end
		if p.slot ~= slot then
			return false, p.name .. " does not fit the " .. slot .. " slot"
		end
		if slotDef.requires and not parts[slotDef.requires] then
			return false, slot .. " needs " .. slotDef.requires
		end
	end
	if count > #Config.Slots then
		return false, "Too many parts"
	end
	for _, s in ipairs(Config.Slots) do
		if s.required and not parts[s.id] then
			return false, "Missing " .. s.id
		end
	end
	return true, nil
end

-- Base income of a part list (before level / global multipliers).
function Stats.baseIncome(parts: { [string]: string }): number
	local total = 0
	for _, partId in pairs(parts) do
		local p = Catalog.get(partId)
		if p then -- unknown parts contribute 0 rather than erroring
			total += (p.stats.income or 0) * (Config.RarityIncomeMult[p.rarity] or 1)
		end
	end
	return total
end

function Stats.levelIncomeMult(level: number): number
	return 1 + Config.Leveling.IncomePerLevel * (level - 1)
end

-- Per-monster income ($/s) including its own level, excluding global multipliers.
function Stats.monsterIncome(record): number
	return Stats.baseIncome(record.parts) * Stats.levelIncomeMult(record.level or 1)
end

function Stats.globalMult(data): number
	local tier = Config.LabIncomeTiers[data.lab.incomeTier] or Config.LabIncomeTiers[1]
	return tier.mult * (1 + Config.RebirthIncomeBonus * (data.rebirths or 0))
end

-- Total = sum(monster incomes) * global multiplier (applied exactly once).
function Stats.totalIncome(data): number
	local sum = 0
	for _, m in pairs(data.monsters) do
		sum += Stats.monsterIncome(m)
	end
	return sum * Stats.globalMult(data)
end

function Stats.findAbility(parts: { [string]: string }): string?
	local core = parts.Core and Catalog.get(parts.Core)
	if core and core.ability then
		return core.ability
	end
	for _, s in ipairs(Config.Slots) do
		local id = parts[s.id]
		local p = id and Catalog.get(id)
		if p and p.ability then
			return p.ability
		end
	end
	return nil
end

-- Full combat stat block for a part list at a level.
function Stats.compute(parts: { [string]: string }, level: number?)
	local lvl = level or 1
	local raw = {}
	for _, k in ipairs(STAT_KEYS) do
		raw[k] = Config.BaseStats[k] or 0
	end
	for _, partId in pairs(parts) do
		local p = Catalog.get(partId)
		if p then
			local mult = Config.RarityStatMult[p.rarity] or 1
			for _, k in ipairs(STAT_KEYS) do
				local v = p.stats[k]
				if v then
					raw[k] += SCALED[k] and v * mult or v
				end
			end
		end
	end
	local levelMult = 1 + Config.Leveling.StatPerLevel * (lvl - 1)
	local C = Config.Combat
	local base = Stats.baseIncome(parts)
	return {
		hp = math.floor(raw.hp * levelMult + 0.5),
		atk = math.floor(raw.atk * levelMult * 10 + 0.5) / 10,
		def = math.floor(raw.def * levelMult * 10 + 0.5) / 10,
		speed = math.max(1, math.floor((raw.spd - C.WeightSpeedPenalty * raw.weight) * 10 + 0.5) / 10),
		attackSpeed = math.clamp(1 + raw.aspd, C.MinAttackSpeed, C.MaxAttackSpeed),
		crit = math.floor(math.clamp(5 + raw.crit, 0, C.MaxCrit) + 0.5), -- integer so %d formatting is safe
		weight = raw.weight,
		ability = Stats.findAbility(parts),
		baseIncome = base,
		income = base * Stats.levelIncomeMult(lvl),
		level = lvl,
	}
end

function Stats.upgradeCost(record): number
	local L = Config.Leveling
	local base = math.max(1, Stats.baseIncome(record.parts))
	return math.floor(L.UpgradeCostBase * base * L.UpgradeCostGrowth ^ ((record.level or 1) - 1))
end

function Stats.xpToNext(level: number): number
	return Config.Leveling.XpPerLevel * level
end

function Stats.slotLimit(data): number
	local tier = Config.PodTiers[data.lab.podTier] or Config.PodTiers[1]
	return tier.slots
end

-- Blueprint share codes: "BB1:Torso=torso_blob;Head=head_goo"
function Stats.encodeBlueprint(parts: { [string]: string }): string
	local bits = {}
	for _, s in ipairs(Config.Slots) do
		if parts[s.id] then
			table.insert(bits, s.id .. "=" .. parts[s.id])
		end
	end
	return "BB1:" .. table.concat(bits, ";")
end

function Stats.decodeBlueprint(code: string): { [string]: string }?
	if type(code) ~= "string" or #code > 600 then
		return nil
	end
	code = code:gsub("%s", "")
	local body = code:match("^BB1:(.*)$")
	if not body then
		return nil
	end
	local parts = {}
	for slot, partId in body:gmatch("([%w_]+)=([%w_]+)") do
		if not Config.SlotById[slot] or not Catalog.get(partId) then
			return nil
		end
		parts[slot] = partId
	end
	return parts
end

return Stats

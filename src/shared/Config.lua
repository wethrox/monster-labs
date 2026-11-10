-- Central tuning constants for Beast Builder Lab.
-- Shared by server (authoritative) and client (display only).

local Config = {}

Config.Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

Config.RarityIndex = {} :: { [string]: number }
for i, r in ipairs(Config.Rarities) do
	Config.RarityIndex[r] = i
end

Config.RarityStatMult = {
	Common = 1.0,
	Uncommon = 1.25,
	Rare = 1.6,
	Epic = 2.1,
	Legendary = 2.8,
	Mythic = 3.8,
}

Config.RarityIncomeMult = {
	Common = 1,
	Uncommon = 1.6,
	Rare = 2.8,
	Epic = 5,
	Legendary = 9,
	Mythic = 16,
}

Config.RarityColor = {
	Common = { 190, 190, 190 },
	Uncommon = { 90, 210, 90 },
	Rare = { 70, 150, 255 },
	Epic = { 180, 90, 255 },
	Legendary = { 255, 175, 40 },
	Mythic = { 255, 70, 110 },
}

-- Slot order = builder UI order = ability lookup order (after Core).
Config.Slots = {
	{ id = "Torso", required = true },
	{ id = "Head", required = true },
	{ id = "Legs", required = true, paired = true },
	{ id = "Arms", paired = true },
	{ id = "Claws", paired = true, requires = "Arms" },
	{ id = "Horns", paired = true, requires = "Head" },
	{ id = "Wings", paired = true },
	{ id = "Tail" },
	{ id = "Armor" },
	{ id = "Core" },
}

Config.SlotById = {} :: { [string]: any }
for _, s in ipairs(Config.Slots) do
	Config.SlotById[s.id] = s
end

Config.BaseStats = { hp = 50, atk = 5, def = 0, spd = 10, aspd = 0, weight = 0, crit = 0, income = 0 }

Config.Leveling = {
	MaxLevel = 25,
	StatPerLevel = 0.08, -- hp/atk/def +8% per level
	IncomePerLevel = 0.15, -- income +15% per level
	UpgradeCostBase = 25, -- cost = base * monsterBaseIncome * growth^(level-1)
	UpgradeCostGrowth = 1.5,
	XpPerLevel = 50, -- xp needed = XpPerLevel * level
}

Config.Combat = {
	TickRate = 0.1,
	MaxDuration = 60,
	CritMult = 1.75,
	DodgePerSpeed = 0.01,
	MaxDodge = 0.3,
	AutoCastDelay = 3, -- seconds after ability is ready before it auto-fires for the player
	MinAttackSpeed = 0.3,
	MaxAttackSpeed = 3,
	MaxCrit = 60,
	WeightSpeedPenalty = 0.4,
	LossMoneyMult = 0.2,
	LossXpMult = 0.5,
	FirstWinMoneyMult = 3,
}

Config.Abilities = {
	FireBreath = {
		name = "Fire Breath",
		desc = "2.5x damage, ignores 50% defense",
		cooldown = 8,
		windup = 1,
		kind = "damage",
		mult = 2.5,
		armorPierce = 0.5,
	},
	Pounce = { name = "Pounce", desc = "1.5x damage + 1.5s stun", cooldown = 9, windup = 0.5, kind = "damage", mult = 1.5, stun = 1.5 },
	ShockBurst = {
		name = "Shock Burst",
		desc = "1.8x damage, always crits",
		cooldown = 7,
		windup = 0.5,
		kind = "damage",
		mult = 1.8,
		forceCrit = true,
	},
	Harden = {
		name = "Harden",
		desc = "+100% defense for 4s",
		cooldown = 10,
		windup = 0,
		kind = "buff",
		stat = "def",
		amount = 1.0,
		duration = 4,
	},
	Frenzy = {
		name = "Frenzy",
		desc = "+60% attack speed for 5s",
		cooldown = 12,
		windup = 0,
		kind = "buff",
		stat = "attackSpeed",
		amount = 0.6,
		duration = 5,
	},
	Regenerate = { name = "Regenerate", desc = "Heal 25% max HP", cooldown = 12, windup = 0, kind = "heal", amount = 0.25 },
}

Config.Economy = {
	OfflineRate = 0.5,
	OfflineCapSeconds = 8 * 3600,
	OfflineMinSeconds = 60, -- don't show summary for tiny gaps
	RecycleRefund = 1.0, -- fraction of parts returned (1 = all)
	MaxNameLength = 20,
}

Config.LabIncomeTiers = {
	{ mult = 1.0, cost = 0 },
	{ mult = 1.1, cost = 2500 },
	{ mult = 1.25, cost = 15000 },
	{ mult = 1.45, cost = 80000 },
	{ mult = 1.7, cost = 400000 },
	{ mult = 2.0, cost = 2000000 },
}

Config.PodTiers = {
	{ slots = 6, cost = 0 },
	{ slots = 8, cost = 5000 },
	{ slots = 10, cost = 40000 },
	{ slots = 12, cost = 250000 },
	{ slots = 15, cost = 1500000 },
}

Config.RebirthIncomeBonus = 0.25

Config.Crates = {
	Basic = {
		name = "Basic Crate",
		cost = 500,
		weights = { Common = 70, Uncommon = 25, Rare = 5 },
	},
	Advanced = {
		name = "Advanced Crate",
		cost = 10000,
		weights = { Uncommon = 50, Rare = 35, Epic = 13, Legendary = 2 },
	},
}

Config.StarterParts = {
	torso_blob = 1,
	head_goo = 1,
	legs_stubby = 1,
	arms_little = 1,
}

Config.Tutorial = {
	OpenBuilder = 1,
	BuildFirst = 2,
	FirstBattle = 3,
	FirstUpgrade = 4,
	Done = 5,
}

return Config

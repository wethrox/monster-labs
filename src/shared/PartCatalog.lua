-- Every monster component. Add a part by adding one entry; no other code changes needed.
-- stats: hp, atk, def, spd, aspd (bonus attacks/sec), weight, crit (%), income ($/s before rarity mult)
-- visual: shape = "Block" | "Ball" | "Cylinder" | "Wedge"; size = {x,y,z} studs (ONE piece for paired slots)

local PartCatalog = {}

local SHOP_COST = { Common = 150, Uncommon = 800, Rare = 4500, Epic = 25000 }

local function part(id, def)
	def.id = id
	def.stats = def.stats or {}
	def.cost = def.cost or SHOP_COST[def.rarity]
	-- Legendary / Mythic are never sold directly: crates & arenas only.
	if def.shop == nil then
		def.shop = SHOP_COST[def.rarity] ~= nil
	end
	PartCatalog[id] = def
end

-- TORSOS -------------------------------------------------------------------
part("torso_blob", {
	name = "Blob Torso",
	slot = "Torso",
	rarity = "Common",
	stats = { hp = 60, def = 2, weight = 2, income = 2 },
	visual = { shape = "Ball", size = { 4, 3.5, 3.5 }, color = { 120, 220, 120 }, material = "SmoothPlastic" },
})
part("torso_goblin", {
	name = "Goblin Torso",
	slot = "Torso",
	rarity = "Uncommon",
	stats = { hp = 70, atk = 3, def = 3, spd = 2, weight = 2, income = 3 },
	visual = { shape = "Block", size = { 3, 3.5, 2.2 }, color = { 110, 140, 60 }, material = "SmoothPlastic" },
})
part("torso_iron", {
	name = "Ironclad Torso",
	slot = "Torso",
	rarity = "Rare",
	stats = { hp = 140, def = 14, weight = 8, income = 4 },
	ability = "Harden",
	visual = { shape = "Block", size = { 4.5, 4, 3 }, color = { 140, 145, 155 }, material = "DiamondPlate" },
})
part("torso_cyber", {
	name = "Cyber Chassis",
	slot = "Torso",
	rarity = "Epic",
	stats = { hp = 150, atk = 8, def = 10, spd = 3, weight = 4, income = 6 },
	ability = "ShockBurst",
	visual = { shape = "Block", size = { 4, 3.6, 2.8 }, color = { 40, 200, 230 }, material = "Metal" },
})
part("torso_chimera", {
	name = "Chimera Core Body",
	slot = "Torso",
	rarity = "Legendary",
	stats = { hp = 200, atk = 12, def = 12, spd = 4, weight = 5, income = 8 },
	visual = { shape = "Ball", size = { 5, 4, 4.5 }, color = { 130, 60, 170 }, material = "SmoothPlastic" },
})

-- HEADS --------------------------------------------------------------------
part("head_goo", {
	name = "Goo Head",
	slot = "Head",
	rarity = "Common",
	stats = { hp = 10, atk = 2, income = 1 },
	visual = { shape = "Ball", size = { 2.4, 2.2, 2.2 }, color = { 150, 240, 150 }, material = "SmoothPlastic" },
})
part("head_goblin", {
	name = "Goblin Head",
	slot = "Head",
	rarity = "Uncommon",
	stats = { atk = 5, crit = 4, income = 2 },
	visual = { shape = "Block", size = { 2, 2, 1.8 }, color = { 120, 160, 70 }, material = "SmoothPlastic" },
})
part("head_skull", {
	name = "Bone Skull",
	slot = "Head",
	rarity = "Rare",
	stats = { atk = 8, def = 4, crit = 6, income = 2 },
	visual = { shape = "Block", size = { 2.2, 2.2, 2.2 }, color = { 235, 230, 210 }, material = "Marble" },
})
part("head_dragon", {
	name = "Dragon Snout",
	slot = "Head",
	rarity = "Epic",
	stats = { atk = 14, crit = 6, income = 3 },
	ability = "FireBreath",
	visual = { shape = "Wedge", size = { 2.4, 2, 3 }, color = { 210, 50, 40 }, material = "Slate" },
})
part("head_lion", {
	name = "Lion Mane",
	slot = "Head",
	rarity = "Legendary",
	stats = { hp = 40, atk = 18, crit = 10, income = 5 },
	ability = "Pounce",
	visual = { shape = "Ball", size = { 3, 2.8, 2.8 }, color = { 240, 180, 50 }, material = "Fabric" },
})

-- LEGS ---------------------------------------------------------------------
part("legs_stubby", {
	name = "Stubby Legs",
	slot = "Legs",
	rarity = "Common",
	stats = { spd = 2, weight = 1, income = 1 },
	visual = { shape = "Block", size = { 1, 1.2, 1 }, color = { 100, 190, 100 }, material = "SmoothPlastic" },
})
part("legs_runner", {
	name = "Runner Legs",
	slot = "Legs",
	rarity = "Uncommon",
	stats = { spd = 10, aspd = 0.1, income = 1 },
	visual = { shape = "Block", size = { 0.7, 2.4, 0.7 }, color = { 200, 160, 110 }, material = "SmoothPlastic" },
})
part("legs_pillar", {
	name = "Pillar Legs",
	slot = "Legs",
	rarity = "Rare",
	stats = { hp = 40, def = 6, spd = -2, weight = 4, income = 2 },
	visual = { shape = "Block", size = { 1.5, 2, 1.5 }, color = { 120, 120, 130 }, material = "Concrete" },
})
part("legs_spring", {
	name = "Spring Legs",
	slot = "Legs",
	rarity = "Epic",
	stats = { spd = 16, aspd = 0.2, income = 3 },
	ability = "Pounce",
	visual = { shape = "Block", size = { 0.8, 2.8, 0.8 }, color = { 60, 255, 200 }, material = "Neon" },
})
part("legs_titan", {
	name = "Titan Legs",
	slot = "Legs",
	rarity = "Legendary",
	stats = { hp = 80, def = 12, spd = 4, weight = 5, income = 4 },
	visual = { shape = "Block", size = { 1.8, 2.6, 1.8 }, color = { 90, 70, 60 }, material = "Basalt" },
})

-- ARMS ---------------------------------------------------------------------
part("arms_little", {
	name = "Little Arms",
	slot = "Arms",
	rarity = "Common",
	stats = { atk = 2, income = 1 },
	visual = { shape = "Block", size = { 0.8, 1.6, 0.8 }, color = { 110, 200, 110 }, material = "SmoothPlastic" },
})
part("arms_brawler", {
	name = "Brawler Arms",
	slot = "Arms",
	rarity = "Uncommon",
	stats = { atk = 6, aspd = 0.1, weight = 1, income = 1 },
	visual = { shape = "Block", size = { 1.2, 2.4, 1.2 }, color = { 170, 110, 80 }, material = "SmoothPlastic" },
})
part("arms_piston", {
	name = "Piston Arms",
	slot = "Arms",
	rarity = "Rare",
	stats = { atk = 10, aspd = 0.15, weight = 3, income = 2 },
	visual = { shape = "Block", size = { 1.1, 2.6, 1.1 }, color = { 160, 165, 175 }, material = "Metal" },
})
part("arms_tentacle", {
	name = "Tentacle Arms",
	slot = "Arms",
	rarity = "Epic",
	stats = { atk = 8, aspd = 0.35, income = 3 },
	visual = { shape = "Block", size = { 0.7, 3.2, 0.7 }, color = { 200, 80, 180 }, material = "SmoothPlastic" },
})

-- CLAWS --------------------------------------------------------------------
part("claws_bone", {
	name = "Bone Claws",
	slot = "Claws",
	rarity = "Common",
	stats = { atk = 3, crit = 3, income = 0.5 },
	visual = { shape = "Wedge", size = { 0.6, 0.6, 0.9 }, color = { 240, 235, 220 }, material = "SmoothPlastic" },
})
part("claws_steel", {
	name = "Steel Talons",
	slot = "Claws",
	rarity = "Rare",
	stats = { atk = 8, crit = 6, income = 1 },
	visual = { shape = "Wedge", size = { 0.7, 0.7, 1.1 }, color = { 200, 205, 215 }, material = "Metal" },
})
part("claws_plasma", {
	name = "Plasma Claws",
	slot = "Claws",
	rarity = "Epic",
	stats = { atk = 12, crit = 10, income = 2 },
	ability = "ShockBurst",
	visual = { shape = "Wedge", size = { 0.7, 0.7, 1.2 }, color = { 80, 200, 255 }, material = "Neon" },
})

-- HORNS --------------------------------------------------------------------
part("horns_spiky", {
	name = "Spiky Horns",
	slot = "Horns",
	rarity = "Common",
	stats = { atk = 2, crit = 2, income = 0.5 },
	visual = { shape = "Wedge", size = { 0.4, 1, 0.5 }, color = { 250, 240, 200 }, material = "SmoothPlastic" },
})
part("horns_ram", {
	name = "Ram Horns",
	slot = "Horns",
	rarity = "Uncommon",
	stats = { atk = 3, def = 3, income = 1 },
	visual = { shape = "Ball", size = { 0.9, 0.9, 0.9 }, color = { 160, 130, 100 }, material = "Slate" },
})
part("horns_crystal", {
	name = "Crystal Horns",
	slot = "Horns",
	rarity = "Legendary",
	stats = { atk = 6, crit = 12, income = 4 },
	visual = { shape = "Wedge", size = { 0.5, 1.6, 0.6 }, color = { 150, 230, 255 }, material = "Glass" },
})

-- WINGS --------------------------------------------------------------------
part("wings_bat", {
	name = "Bat Wings",
	slot = "Wings",
	rarity = "Uncommon",
	stats = { spd = 6, weight = -1, income = 1.5 },
	visual = { shape = "Block", size = { 2.6, 2, 0.2 }, color = { 70, 50, 70 }, material = "Fabric" },
})
part("wings_feather", {
	name = "Feather Wings",
	slot = "Wings",
	rarity = "Rare",
	stats = { spd = 8, aspd = 0.1, income = 2.5 },
	visual = { shape = "Block", size = { 3, 2.2, 0.25 }, color = { 245, 245, 255 }, material = "SmoothPlastic" },
})
part("wings_cyber", {
	name = "Jet Wings",
	slot = "Wings",
	rarity = "Epic",
	stats = { spd = 10, aspd = 0.15, income = 4 },
	visual = { shape = "Block", size = { 3, 1.4, 0.3 }, color = { 40, 220, 255 }, material = "Neon" },
})
part("wings_mythic", {
	name = "Phoenix Wings",
	slot = "Wings",
	rarity = "Mythic",
	stats = { spd = 14, aspd = 0.2, crit = 8, income = 8 },
	ability = "Frenzy",
	visual = { shape = "Block", size = { 3.6, 2.6, 0.25 }, color = { 255, 120, 30 }, material = "Neon" },
})

-- TAILS --------------------------------------------------------------------
part("tail_nub", {
	name = "Nub Tail",
	slot = "Tail",
	rarity = "Common",
	stats = { hp = 10, income = 0.5 },
	visual = { shape = "Ball", size = { 0.8, 0.8, 0.8 }, color = { 120, 210, 120 }, material = "SmoothPlastic" },
})
part("tail_lizard", {
	name = "Lizard Tail",
	slot = "Tail",
	rarity = "Uncommon",
	stats = { hp = 20, income = 1 },
	ability = "Regenerate",
	visual = { shape = "Wedge", size = { 0.8, 0.8, 2.6 }, color = { 90, 170, 80 }, material = "SmoothPlastic" },
})
part("tail_spike", {
	name = "Spiked Tail",
	slot = "Tail",
	rarity = "Rare",
	stats = { atk = 6, def = 3, income = 2 },
	visual = { shape = "Block", size = { 0.9, 0.9, 2.8 }, color = { 110, 100, 100 }, material = "Slate" },
})
part("tail_scorpion", {
	name = "Scorpion Stinger",
	slot = "Tail",
	rarity = "Epic",
	stats = { atk = 10, crit = 8, income = 3 },
	ability = "ShockBurst",
	visual = { shape = "Wedge", size = { 0.8, 2.6, 1.6 }, color = { 180, 40, 40 }, material = "SmoothPlastic" },
})

-- ARMOR --------------------------------------------------------------------
part("armor_plank", {
	name = "Plank Shield",
	slot = "Armor",
	rarity = "Common",
	stats = { def = 5, weight = 2, income = 0.5 },
	visual = { shape = "Block", size = { 2.6, 2.4, 0.3 }, color = { 150, 110, 70 }, material = "Wood" },
})
part("armor_plate", {
	name = "Steel Plating",
	slot = "Armor",
	rarity = "Rare",
	stats = { def = 14, weight = 5, income = 1 },
	visual = { shape = "Block", size = { 3, 2.8, 0.4 }, color = { 170, 175, 185 }, material = "DiamondPlate" },
})
part("armor_aegis", {
	name = "Aegis Plate",
	slot = "Armor",
	rarity = "Legendary",
	stats = { hp = 60, def = 25, weight = 4, income = 4 },
	ability = "Harden",
	visual = { shape = "Block", size = { 3.2, 3, 0.4 }, color = { 255, 210, 90 }, material = "Foil" },
})

-- CORES (special ability components) --------------------------------------
part("core_spark", {
	name = "Spark Core",
	slot = "Core",
	rarity = "Uncommon",
	stats = { aspd = 0.1, income = 2 },
	ability = "Frenzy",
	visual = { shape = "Ball", size = { 0.9, 0.9, 0.9 }, color = { 255, 240, 80 }, material = "Neon" },
})
part("core_heart", {
	name = "Beating Heart",
	slot = "Core",
	rarity = "Rare",
	stats = { hp = 30, income = 3 },
	ability = "Regenerate",
	visual = { shape = "Ball", size = { 1, 1, 1 }, color = { 230, 60, 80 }, material = "Neon" },
})
part("core_inferno", {
	name = "Inferno Core",
	slot = "Core",
	rarity = "Epic",
	stats = { atk = 6, income = 5 },
	ability = "FireBreath",
	visual = { shape = "Ball", size = { 1.1, 1.1, 1.1 }, color = { 255, 110, 20 }, material = "Neon" },
})
part("core_gold", {
	name = "Golden Reactor",
	slot = "Core",
	rarity = "Legendary",
	stats = { income = 15 }, -- pure income: a "money monster" build option
	visual = { shape = "Ball", size = { 1.2, 1.2, 1.2 }, color = { 255, 200, 40 }, material = "Neon" },
})
part("core_singularity", {
	name = "Singularity Core",
	slot = "Core",
	rarity = "Mythic",
	stats = { hp = 50, atk = 10, income = 25 },
	ability = "ShockBurst",
	visual = { shape = "Ball", size = { 1.3, 1.3, 1.3 }, color = { 120, 40, 255 }, material = "Neon" },
})

-- Helper lookups (not parts) -------------------------------------------------
local Lookup = {}
Lookup.Parts = PartCatalog

function Lookup.get(id: string)
	return PartCatalog[id]
end

function Lookup.byRarity(rarity: string)
	local out = {}
	for _, p in pairs(PartCatalog) do
		if p.rarity == rarity then
			table.insert(out, p)
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

function Lookup.bySlot(slot: string)
	local out = {}
	for _, p in pairs(PartCatalog) do
		if p.slot == slot then
			table.insert(out, p)
		end
	end
	return out
end

return Lookup

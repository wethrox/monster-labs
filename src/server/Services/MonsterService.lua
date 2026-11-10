-- Monster creation, editing, renaming, recycling, upgrading and blueprints.
-- All checks happen here on the server; the client only sends part IDs and names.

local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Catalog = require(ReplicatedStorage.Shared.PartCatalog)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local MonsterService = {}

local MAX_BLUEPRINTS = 10

local function countMonsters(data)
	local n = 0
	for _ in pairs(data.monsters) do
		n += 1
	end
	return n
end
MonsterService.countMonsters = countMonsters

-- Copy only valid string->string pairs (defends against weird client tables).
local function sanitizeParts(raw)
	if type(raw) ~= "table" then
		return nil
	end
	local parts, n = {}, 0
	for slot, id in pairs(raw) do
		if type(slot) ~= "string" or type(id) ~= "string" then
			return nil
		end
		n += 1
		if n > #Config.Slots then
			return nil
		end
		parts[slot] = id
	end
	return parts
end

local function filterName(player: Player, raw): string
	if type(raw) ~= "string" then
		return "Monster"
	end
	local name = raw:gsub("[%c]", ""):sub(1, Config.Economy.MaxNameLength)
	name = name:match("^%s*(.-)%s*$") or ""
	if name == "" then
		return "Monster"
	end
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(name, player.UserId)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(result) == "string" and result ~= "" then
		return result
	end
	return "Monster"
end

-- Inventory check: does `inventory` (+ optional refund map) contain every part in `parts`?
local function canAfford(inventory, parts, refund)
	local need = {}
	for _, id in pairs(parts) do
		need[id] = (need[id] or 0) + 1
	end
	for id, n in pairs(need) do
		local have = (inventory[id] or 0) + (refund and refund[id] or 0)
		if have < n then
			local p = Catalog.get(id)
			return false, "You don't own " .. (p and p.name or id)
		end
	end
	return true
end

local function addParts(inventory, parts, sign)
	for _, id in pairs(parts) do
		local v = (inventory[id] or 0) + sign
		inventory[id] = v > 0 and v or nil
	end
end

local function partCounts(parts)
	local c = {}
	for _, id in pairs(parts) do
		c[id] = (c[id] or 0) + 1
	end
	return c
end

function MonsterService.build(player: Player, payload)
	local data = DataService.get(player)
	local parts = sanitizeParts(payload and payload.parts)
	if not parts then
		return { ok = false, err = "Invalid build" }
	end
	local valid, err = Stats.validateBuild(parts)
	if not valid then
		return { ok = false, err = err }
	end
	if countMonsters(data) >= Stats.slotLimit(data) then
		return { ok = false, err = "All containment pods are full. Upgrade pods in the Shop or recycle a monster." }
	end
	local okParts, perr = canAfford(data.parts, parts)
	if not okParts then
		return { ok = false, err = perr }
	end
	local name = filterName(player, payload.name)
	-- Re-fetch after the yielding filter call; state may have changed meanwhile.
	data = DataService.get(player)
	if not data then
		return { ok = false, err = "Not loaded" }
	end
	okParts, perr = canAfford(data.parts, parts)
	if not okParts or countMonsters(data) >= Stats.slotLimit(data) then
		return { ok = false, err = perr or "No free pods" }
	end

	addParts(data.parts, parts, -1)
	local id = HttpService:GenerateGUID(false)
	data.monsters[id] = { id = id, name = name, parts = parts, level = 1, xp = 0, created = os.time() }
	data.stats.monstersBuilt += 1
	if data.tutorial <= Config.Tutorial.BuildFirst then
		data.tutorial = Config.Tutorial.FirstBattle
	end
	local before = player:GetAttribute("IncomePerSec") or 0
	local after = IncomeService.recompute(player)
	DataService.changed(player, "monsters")
	return { ok = true, id = id, incomeGain = after - before }
end

function MonsterService.edit(player: Player, payload)
	local data = DataService.get(player)
	local profile = DataService.profile(player)
	local m = payload and type(payload.id) == "string" and data.monsters[payload.id]
	if not m then
		return { ok = false, err = "Monster not found" }
	end
	if profile.battleMonsterId == m.id then
		return { ok = false, err = "That monster is fighting right now" }
	end
	local parts = sanitizeParts(payload.parts)
	if not parts then
		return { ok = false, err = "Invalid build" }
	end
	local valid, err = Stats.validateBuild(parts)
	if not valid then
		return { ok = false, err = err }
	end
	local okParts, perr = canAfford(data.parts, parts, partCounts(m.parts))
	if not okParts then
		return { ok = false, err = perr }
	end
	local newName = payload.name and filterName(player, payload.name) or m.name
	-- Re-validate after the yield.
	data = DataService.get(player)
	m = data and data.monsters[payload.id]
	if not m or profile.battleMonsterId == m.id then
		return { ok = false, err = "Monster unavailable" }
	end
	okParts, perr = canAfford(data.parts, parts, partCounts(m.parts))
	if not okParts then
		return { ok = false, err = perr }
	end
	local before = player:GetAttribute("IncomePerSec") or 0
	addParts(data.parts, m.parts, 1) -- refund old
	addParts(data.parts, parts, -1) -- consume new
	m.parts = parts
	m.name = newName
	local after = IncomeService.recompute(player)
	DataService.changed(player, "monsters")
	return { ok = true, id = m.id, incomeGain = after - before }
end

function MonsterService.rename(player: Player, payload)
	local data = DataService.get(player)
	local m = payload and type(payload.id) == "string" and data.monsters[payload.id]
	if not m then
		return { ok = false, err = "Monster not found" }
	end
	local name = filterName(player, payload.name)
	m = DataService.get(player) and DataService.get(player).monsters[payload.id]
	if not m then
		return { ok = false, err = "Monster not found" }
	end
	m.name = name
	DataService.changed(player, "monsters")
	return { ok = true }
end

function MonsterService.recycle(player: Player, payload)
	local data = DataService.get(player)
	local profile = DataService.profile(player)
	local m = payload and type(payload.id) == "string" and data.monsters[payload.id]
	if not m then
		return { ok = false, err = "Monster not found" }
	end
	if profile.battleMonsterId == m.id then
		return { ok = false, err = "That monster is fighting right now" }
	end
	data.monsters[m.id] = nil
	if Config.Economy.RecycleRefund >= 1 then
		addParts(data.parts, m.parts, 1)
	end
	IncomeService.recompute(player)
	DataService.changed(player, "monsters")
	return { ok = true }
end

function MonsterService.upgrade(player: Player, payload)
	local data = DataService.get(player)
	local m = payload and type(payload.id) == "string" and data.monsters[payload.id]
	if not m then
		return { ok = false, err = "Monster not found" }
	end
	if m.level >= Config.Leveling.MaxLevel then
		return { ok = false, err = "Max level reached" }
	end
	local cost = Stats.upgradeCost(m)
	if not IncomeService.addMoney(player, -cost) then
		return { ok = false, err = "Not enough money" }
	end
	local before = player:GetAttribute("IncomePerSec") or 0
	m.level += 1
	m.xp = 0
	if data.tutorial == Config.Tutorial.FirstUpgrade then
		data.tutorial = Config.Tutorial.Done
	end
	local after = IncomeService.recompute(player)
	DataService.changed(player, "monsters")
	return { ok = true, level = m.level, incomeGain = after - before }
end

-- XP from battles. Returns number of levels gained.
function MonsterService.grantXp(player: Player, monsterId: string, xp: number): number
	local data = DataService.get(player)
	local m = data and data.monsters[monsterId]
	if not m then
		return 0
	end
	local gained = 0
	m.xp = (m.xp or 0) + xp
	while m.level < Config.Leveling.MaxLevel and m.xp >= Stats.xpToNext(m.level) do
		m.xp -= Stats.xpToNext(m.level)
		m.level += 1
		gained += 1
	end
	if m.level >= Config.Leveling.MaxLevel then
		m.xp = 0
	end
	if gained > 0 then
		IncomeService.recompute(player)
	end
	return gained
end

function MonsterService.saveBlueprint(player: Player, payload)
	local data = DataService.get(player)
	local parts = sanitizeParts(payload and payload.parts)
	if not parts then
		return { ok = false, err = "Invalid blueprint" }
	end
	-- Blueprints may be incomplete designs, but every entry must be a real part in the right slot.
	for slot, id in pairs(parts) do
		local p = Catalog.get(id)
		if not Config.SlotById[slot] or not p or p.slot ~= slot then
			return { ok = false, err = "Invalid blueprint" }
		end
	end
	if #data.blueprints >= MAX_BLUEPRINTS then
		table.remove(data.blueprints, 1)
	end
	local name = filterName(player, payload.name)
	data = DataService.get(player)
	if not data then
		return { ok = false, err = "Not loaded" }
	end
	table.insert(data.blueprints, { name = name, parts = parts })
	DataService.changed(player, "blueprints")
	return { ok = true, code = Stats.encodeBlueprint(parts) }
end

function MonsterService.deleteBlueprint(player: Player, payload)
	local data = DataService.get(player)
	local i = payload and tonumber(payload.index)
	if not i or not data.blueprints[i] then
		return { ok = false, err = "Blueprint not found" }
	end
	table.remove(data.blueprints, i)
	DataService.changed(player, "blueprints")
	return { ok = true }
end

-- Tutorial step bump for "opened builder" (purely cosmetic progression).
function MonsterService.tutorialSeen(player: Player, payload)
	local data = DataService.get(player)
	local step = payload and tonumber(payload.step)
	if step == Config.Tutorial.OpenBuilder and data.tutorial == Config.Tutorial.OpenBuilder then
		data.tutorial = Config.Tutorial.BuildFirst
		DataService.changed(player, "tutorial")
	end
	return { ok = true }
end

return MonsterService

-- Runs arena battles on the server in real time (BattleSim at Config.Combat.TickRate),
-- streams events to the owning client for presentation, and grants rewards.
-- Passive income is NOT touched here: IncomeService keeps paying during the fight.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Arenas = require(ReplicatedStorage.Shared.Arenas)
local BattleSim = require(ReplicatedStorage.Shared.BattleSim)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MonsterService = require(script.Parent.MonsterService)
local Loot = require(script.Parent.Loot)

local BattleService = {}

local INTRO_DELAY = 2 -- seconds of "3-2-1" on the client before ticks start
local active = {} :: { [Player]: any }
local battleEvent: RemoteEvent

local function enemyStats(arena)
	local s = Stats.compute(arena.enemy, arena.level)
	s.hp = math.max(1, math.floor(s.hp * arena.scale + 0.5))
	s.atk = s.atk * arena.scale
	return s
end

local function grantRewards(player: Player, battle, won: boolean)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local arena = battle.arena
	local key = tostring(arena.id)
	local firstWin = won and not data.arenas.firstWins[key]
	local rewards = { won = won, firstWin = firstWin, parts = {} }

	local money = arena.money
	local xp = arena.xp
	if not won then
		money = math.floor(money * Config.Combat.LossMoneyMult)
		xp = math.floor(xp * Config.Combat.LossXpMult)
	elseif firstWin then
		money *= Config.Combat.FirstWinMoneyMult
	end
	IncomeService.addMoney(player, money)
	rewards.money = money
	rewards.xp = xp
	rewards.levelsGained = MonsterService.grantXp(player, battle.monsterId, xp)

	if won then
		data.stats.battlesWon += 1
		if firstWin then
			data.arenas.firstWins[key] = true
			if arena.firstWinPart then
				data.parts[arena.firstWinPart] = (data.parts[arena.firstWinPart] or 0) + 1
				table.insert(rewards.parts, arena.firstWinPart)
			end
			if Arenas[arena.id + 1] and data.arenas.unlocked < arena.id + 1 then
				data.arenas.unlocked = arena.id + 1
				rewards.unlockedArena = arena.id + 1
			end
		end
		if Loot.rng():NextNumber() < arena.drop.chance then
			local p = Loot.rollPart(arena.drop.weights)
			if p then
				data.parts[p.id] = (data.parts[p.id] or 0) + 1
				table.insert(rewards.parts, p.id)
			end
		end
	else
		data.stats.battlesLost += 1
	end
	if data.tutorial == Config.Tutorial.FirstBattle then
		data.tutorial = Config.Tutorial.FirstUpgrade
	end
	DataService.changed(player, "monsters")
	return rewards
end

local function runBattle(player: Player, battle)
	task.wait(INTRO_DELAY)
	local dt = Config.Combat.TickRate
	local sim = battle.sim
	while not sim.finished do
		if not player.Parent or active[player] ~= battle then
			return -- player left / battle aborted: no rewards
		end
		local events = sim:step(dt)
		if #events > 0 then
			battleEvent:FireClient(player, "events", { t = sim.t, events = events })
		end
		task.wait(dt)
	end
	local won = sim.winnerTeam == 1
	local profile = DataService.profile(player)
	if profile then
		profile.battleMonsterId = nil
	end
	active[player] = nil
	local rewards = grantRewards(player, battle, won)
	if player.Parent then
		battleEvent:FireClient(player, "end", rewards)
	end
end

function BattleService.start(player: Player, payload)
	local data = DataService.get(player)
	local profile = DataService.profile(player)
	if active[player] then
		return { ok = false, err = "Already in a battle" }
	end
	local arenaId = payload and tonumber(payload.arenaId)
	local arena = arenaId and Arenas[arenaId]
	if not arena then
		return { ok = false, err = "Unknown arena" }
	end
	if arena.id > data.arenas.unlocked then
		return { ok = false, err = "Arena locked: win the previous arena first" }
	end
	local m = type(payload.monsterId) == "string" and data.monsters[payload.monsterId]
	if not m then
		return { ok = false, err = "Choose a monster" }
	end

	local myStats = Stats.compute(m.parts, m.level)
	local foeStats = enemyStats(arena)
	local rng = Loot.rng()
	local sim = BattleSim.new({
		{ team = 1, name = m.name, stats = myStats, controlled = true },
		{ team = 2, name = arena.enemyName, stats = foeStats, controlled = false },
	}, function()
		return rng:NextNumber()
	end)
	local battle = { sim = sim, arena = arena, monsterId = m.id }
	active[player] = battle
	profile.battleMonsterId = m.id

	battleEvent:FireClient(player, "start", {
		arenaId = arena.id,
		arenaName = arena.name,
		introDelay = INTRO_DELAY,
		you = 1,
		units = {
			{ name = m.name, parts = m.parts, level = m.level, stats = myStats },
			{ name = arena.enemyName, parts = arena.enemy, level = arena.level, stats = foeStats },
		},
	})
	task.spawn(runBattle, player, battle)
	return { ok = true }
end

function BattleService.useAbility(player: Player)
	local battle = active[player]
	if battle then
		battle.sim:requestAbility(1)
	end
end

function BattleService.forfeit(player: Player)
	local battle = active[player]
	if battle then
		-- Forfeit = immediate loss (still pays loss rewards, consistent with timeouts).
		for _, u in ipairs(battle.sim.units) do
			if u.team == 1 then
				u.hp = 0
			end
		end
	end
	return { ok = true }
end

function BattleService.cleanup(player: Player)
	active[player] = nil
end

function BattleService.init(remotes)
	battleEvent = remotes.BattleEvent
	remotes.UseAbility.OnServerEvent:Connect(function(player)
		BattleService.useAbility(player)
	end)
end

return BattleService

-- Deterministic, tick-based combat simulation (pure Luau; no instances).
-- Supports N-vs-N teams so 2v2 (Phase 5) reuses this unchanged.
--
-- Hybrid combat: units auto-attack. Each unit has at most one active ability.
--   * AI units cast as soon as the ability is ready.
--   * Player units cast when the player requests it, or automatically
--     Config.Combat.AutoCastDelay seconds after it became ready.
--   * Damage abilities with a windup are telegraphed (a "windup" event) before resolving.

local Config = require(script.Parent.Config)

local BattleSim = {}
BattleSim.__index = BattleSim

local C = Config.Combat

-- unitDefs: { { team = 1, name = "...", stats = Stats.compute(...), controlled = true|false }, ... }
-- rand: function() -> number in [0,1)
function BattleSim.new(unitDefs, rand)
	local self = setmetatable({}, BattleSim)
	self.t = 0
	self.rand = rand or math.random
	self.units = {}
	self.finished = false
	self.winnerTeam = nil
	for i, def in ipairs(unitDefs) do
		local s = def.stats
		local ability = s.ability and Config.Abilities[s.ability] or nil
		self.units[i] = {
			index = i,
			team = def.team,
			name = def.name,
			stats = s,
			controlled = def.controlled == true,
			hp = s.hp,
			maxHp = s.hp,
			abilityId = s.ability,
			ability = ability,
			cd = ability and ability.cooldown * 0.5 or math.huge, -- first cast arrives half a cooldown in
			readySince = nil,
			requested = false,
			casting = nil, -- { at = time, target = unit }
			stunUntil = 0,
			buffs = {}, -- stat -> { amount, untilT }
			attackTimer = 0,
		}
	end
	-- Faster unit swings first: initial timer = half (fast) or full (slow) interval.
	for _, u in ipairs(self.units) do
		local fastest = true
		for _, o in ipairs(self.units) do
			if o.team ~= u.team and o.stats.speed > u.stats.speed then
				fastest = false
			end
		end
		u.attackTimer = (1 / u.stats.attackSpeed) * (fastest and 0.5 or 1)
	end
	return self
end

local function buffAmount(u, stat, t)
	local b = u.buffs[stat]
	if b and t < b.untilT then
		return b.amount
	end
	return 0
end

function BattleSim:effDef(u)
	return u.stats.def * (1 + buffAmount(u, "def", self.t))
end

function BattleSim:effAttackSpeed(u)
	return u.stats.attackSpeed * (1 + buffAmount(u, "attackSpeed", self.t))
end

function BattleSim:target(u)
	for _, o in ipairs(self.units) do
		if o.team ~= u.team and o.hp > 0 then
			return o
		end
	end
	return nil
end

function BattleSim:damage(src, dst, mult, armorPierce, forceCrit)
	local def = self:effDef(dst) * (1 - (armorPierce or 0))
	local crit = forceCrit or (self.rand() * 100 < src.stats.crit)
	local variance = 0.9 + self.rand() * 0.2
	local dmg = src.stats.atk * mult * (100 / (100 + def)) * variance
	if crit then
		dmg *= C.CritMult
	end
	dmg = math.max(1, math.floor(dmg + 0.5))
	dst.hp = math.max(0, dst.hp - dmg)
	return dmg, crit
end

function BattleSim:requestAbility(unitIndex)
	local u = self.units[unitIndex]
	if not u or not u.ability or u.hp <= 0 or self.finished then
		return false
	end
	if u.cd > 0 or u.casting then
		return false
	end
	u.requested = true
	return true
end

function BattleSim:startCast(u, events)
	local a = u.ability
	u.cd = a.cooldown
	u.readySince = nil
	u.requested = false
	if a.kind == "damage" and a.windup > 0 then
		u.casting = { at = self.t + a.windup }
		table.insert(events, { type = "windup", src = u.index, ability = u.abilityId, duration = a.windup })
	else
		self:resolveAbility(u, events)
	end
end

function BattleSim:resolveAbility(u, events)
	local a = u.ability
	u.casting = nil
	if a.kind == "damage" then
		local dst = self:target(u)
		if not dst then
			return
		end
		local dmg, crit = self:damage(u, dst, a.mult, a.armorPierce, a.forceCrit)
		if a.stun then
			dst.stunUntil = self.t + a.stun
			dst.casting = nil -- stun interrupts enemy wind-ups
		end
		table.insert(events, {
			type = "ability",
			src = u.index,
			dst = dst.index,
			ability = u.abilityId,
			dmg = dmg,
			crit = crit,
			hp = dst.hp,
			stun = a.stun,
		})
	elseif a.kind == "buff" then
		u.buffs[a.stat] = { amount = a.amount, untilT = self.t + a.duration }
		table.insert(events, { type = "ability", src = u.index, ability = u.abilityId, duration = a.duration })
	elseif a.kind == "heal" then
		local heal = math.floor(u.maxHp * a.amount + 0.5)
		u.hp = math.min(u.maxHp, u.hp + heal)
		table.insert(events, { type = "ability", src = u.index, ability = u.abilityId, heal = heal, hp = u.hp })
	end
end

-- Advance the simulation by dt seconds. Returns a list of events that happened.
function BattleSim:step(dt)
	local events = {}
	if self.finished then
		return events
	end
	self.t += dt
	local t = self.t

	for _, u in ipairs(self.units) do
		if u.hp > 0 then
			if u.ability then
				u.cd -= dt
				if u.cd <= 0 and not u.readySince and not u.casting then
					u.readySince = t
					if u.controlled then
						table.insert(events, { type = "ready", src = u.index })
					end
				end
			end

			if t >= u.stunUntil then
				if u.casting then
					if t >= u.casting.at then
						self:resolveAbility(u, events)
					end
				else
					local castNow = false
					if u.ability and u.cd <= 0 then
						-- AI casts immediately; players cast on request or after the auto-cast delay.
						castNow = not u.controlled or u.requested or (u.readySince ~= nil and t - u.readySince >= C.AutoCastDelay)
					end
					if castNow then
						self:startCast(u, events)
					else
						u.attackTimer -= dt
						if u.attackTimer <= 0 then
							u.attackTimer += 1 / self:effAttackSpeed(u)
							local dst = self:target(u)
							if dst then
								local dodge = math.clamp((dst.stats.speed - u.stats.speed) * C.DodgePerSpeed, 0, C.MaxDodge)
								if self.rand() < dodge then
									table.insert(events, { type = "dodge", src = u.index, dst = dst.index })
								else
									local dmg, crit = self:damage(u, dst, 1, 0, false)
									table.insert(
										events,
										{ type = "attack", src = u.index, dst = dst.index, dmg = dmg, crit = crit, hp = dst.hp }
									)
								end
							end
						end
					end
				end
			end
		end
	end

	-- Win check
	local aliveTeams = {}
	for _, u in ipairs(self.units) do
		if u.hp > 0 then
			aliveTeams[u.team] = true
		end
	end
	local teamCount, lastTeam = 0, nil
	for team in pairs(aliveTeams) do
		teamCount += 1
		lastTeam = team
	end
	if teamCount <= 1 then
		self.finished = true
		self.winnerTeam = lastTeam
	elseif t >= C.MaxDuration then
		-- Timeout: team with highest average HP% wins.
		local best, bestPct = nil, -1
		local pct = {}
		for _, u in ipairs(self.units) do
			pct[u.team] = pct[u.team] or { sum = 0, n = 0 }
			pct[u.team].sum += u.hp / u.maxHp
			pct[u.team].n += 1
		end
		for team, p in pairs(pct) do
			local avg = p.sum / p.n
			if avg > bestPct then
				best, bestPct = team, avg
			end
		end
		self.finished = true
		self.winnerTeam = best
	end
	if self.finished then
		table.insert(events, { type = "end", winner = self.winnerTeam })
	end
	return events
end

-- Run instantly to completion (used for balance testing).
function BattleSim:runToEnd()
	local guard = 0
	while not self.finished and guard < 100000 do
		self:step(C.TickRate)
		guard += 1
	end
	return self.winnerTeam, self.t
end

return BattleSim

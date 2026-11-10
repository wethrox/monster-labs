# Beast Builder Lab — Game Design & Technical Architecture

Version 0.1 (MVP design). All numbers here match `src/shared/Config.lua` and
`src/shared/PartCatalog.lua`. If they disagree, the code wins and this doc should be updated.

---

## 1. Game Design Document

### 1.1 Pitch
You run a monster laboratory. You bolt together heads, torsos, legs, wings, tails and
other parts into custom beasts. **Every beast you own earns money every second, always.**
You send beasts into arenas for extra cash, XP and rare parts, then spend it all on better
parts, upgrades and a bigger lab.

### 1.2 Pillars
1. **Creative building.** Parts change both the look and the stats. There are no fixed recipes.
2. **The collection is income.** Each owned monster is a permanent income stream. There are no stations and no assigning.
3. **Combat is a bonus, not a tax.** Fighting never pauses income, and it gives rewards you can't get passively (rare parts, XP, arena unlocks).

### 1.3 Core loop
Collect parts → Build → Earn (always on) → Battle → Rewards → Upgrade / Expand → New parts → repeat.

| Loop | Length | What the player does |
|---|---|---|
| Micro | 20–40 s | One arena battle, one upgrade purchase |
| Session | 10–30 min | Build 1–3 monsters, unlock an arena, buy a lab tier |
| Meta | days/weeks | Collection index, rebirth, events (Phase 6) |

### 1.4 Player experience (first 3 minutes) — implemented as `TutorialController`
| Time | Step | Trigger to advance |
|---|---|---|
| 0:00–0:30 | Spawn at your lab plot. Banner: "Open the Builder". Starter parts are already in your inventory (Blob Torso, Goo Head, Stubby Legs, Little Arms). | Builder opened |
| 0:30–1:00 | Build the first monster. A toast shows "+$5.0/s", and the HUD income counter pulses. | `BuildMonster` succeeds |
| 1:00–2:00 | Banner: "Fight in the Practice Pit". The battle runs while the HUD money keeps ticking. | First battle finished |
| 2:00–3:00 | The first win guarantees a Spiky Horns drop. Banner: "Upgrade your monster" in Collection. The upgrade shows its income and stat change. The Shop shows rare/epic parts with a "Coming soon in crates" teaser. | Upgrade bought → tutorial done |

### 1.5 Retention (roadmap, not in MVP)
- **Days 2–7:** daily free Basic Crate, daily arena modifier (e.g. "Low Gravity: +20% speed"), 3 daily build quests ("Build a monster with wings"), 7-day login calendar.
- **Weeks 2–4:** weekly limited part sets, new body types (serpent, quadruped torsos), rebirth tiers, a collection index with completion rewards per category and rarity, and a season track.
- **Collection Index:** tracks *parts discovered* and *archetypes built* (tank/striker/etc., worked out from stats). It never asks for one specific predetermined monster.

---

## 2. Creature Builder Architecture

### 2.1 Data-driven slots
Slots are defined in `Config.Slots`. Each slot declares:

| Field | Meaning |
|---|---|
| `id` | `Head`, `Torso`, `Arms`, `Legs`, `Tail`, `Wings`, `Horns`, `Claws`, `Armor`, `Core` |
| `required` | Torso, Head and Legs are required |
| `requires` | Dependency slot (Horns→Head, Claws→Arms) |
| `paired` | Mirrored left/right (Arms, Legs, Wings, Horns, Claws) |
| `socket` | Name of the socket function in `Assembler` |

To add a slot (e.g. `Back`), add one entry to `Config.Slots`, one socket function to
`Assembler.Sockets` and some parts to the catalog. Nothing else changes.

### 2.2 Part definition
```lua
torso_blob = {
  name = "Blob Torso", slot = "Torso", rarity = "Common", cost = 0,
  stats = { hp = 60, atk = 0, def = 2, spd = 0, aspd = 0, weight = 2, crit = 0, income = 2 },
  ability = nil,
  visual = { shape = "Ball", size = {4, 3.5, 3.5}, color = {120, 220, 120}, material = "SmoothPlastic" },
}
```

### 2.3 Standardised socket rig
The torso is the root. Every socket is a function of the **torso size** and the
**attached part's size**, so any torso works with any limb with no per-combination code:

- Head: on top of the torso, slightly forward
- Legs: under the torso at ±30% width. The whole model is then shifted so the lowest point sits at Y = 0.
- Arms: on the sides at shoulder height
- Wings: on the upper back, mirrored and angled out
- Tail: on the back
- Horns: on top of the head (needs Head)
- Claws: at the end of each arm (needs Arms)
- Armor: on the front of the torso
- Core: a small glowing sphere at the chest

The result is a `Model` whose PrimaryPart is the torso. Every other part is welded with a
`WeldConstraint`. **Combat never uses the mesh for hits.** It uses a consistent entity
(stats + one hitbox = the model's bounding box), so odd shapes can't break hit detection.

### 2.4 Animation (MVP → Phase 2)
- MVP: procedural tweens on the model pivot (idle bob, lunge on attack, shake on hit, pop on build).
- Phase 2: a `Motor6D` per socket, plus keyframe animations per *slot*, not per part.
  "Leg swing" drives whichever leg is attached.

### 2.5 Stats
For each part, stat × `RarityStatMult[rarity]`. Sum all parts, then add the base stats (`Config.BaseStats`).
Then:
- `hp, atk, def` × `(1 + 0.08 × (level − 1))`
- `speed = max(1, spd − 0.4 × weight)`. Heavy builds are slow.
- `attackSpeed = clamp(1 + aspd, 0.3, 3)` attacks per second
- `crit = clamp(5 + crit, 0, 60)` %
- `ability` = the Core slot's ability if it has one, otherwise the first ability found in slot order

### 2.6 Blueprints
A blueprint is `{ name, parts = { [slot] = partId } }`. The share code is plain text,
`BB1:Torso=torso_blob;Head=head_goo;...`. Loading a code only fills the builder. **Building still
spends parts from the player's own inventory**, so codes can't duplicate anything.

---

## 3. Combat System Recommendation

| Approach | Engagement | Feasibility on Roblox | Strategy | Verdict |
|---|---|---|---|---|
| Fully automated | Low–medium (watching) | Easy: server sim, no physics | All in the build | Too passive |
| Direct control | High | Hard: odd rigs + physics + latency, and mobile controls for a 4-legged dragon | Skill beats build | Undermines the builder |
| **Hybrid (chosen)** | Medium–high | Easy–medium: server tick sim + one input | Build + timing | **Recommended** |

**Hybrid design:** the server simulates the fight at 10 ticks/sec. Monsters auto-attack. Each
monster has **one active ability** (from its parts). The player presses the ability button. If they
don't press it within 3 s of it being ready, it auto-casts, so it stays fair on mobile and for
idle play. Enemy damage abilities have a **1 s telegraphed wind-up**. Using Harden or Pounce (stun)
during the wind-up is the skill expression.

### 3.1 Formulas
- Damage: `atk × 100/(100 + def) × U(0.9, 1.1)`, × 1.75 on a crit
- Dodge: `clamp((mySpeed − enemySpeed) × 1%, 0, 30%)`
- Attack interval: `1 / attackSpeed`. The faster monster's first swing comes after half an interval.
- Battle timeout: 60 s. Then the winner is whoever has the higher HP %.

### 3.2 Abilities (`Config.Abilities`)
| Ability | Effect | Cooldown | Wind-up |
|---|---|---|---|
| Fire Breath | 2.5× atk, ignores 50% def | 8 s | 1 s |
| Pounce | 1.5× atk + 1.5 s stun | 9 s | 0.5 s |
| Harden | +100% def for 4 s | 10 s | — |
| Regenerate | heal 25% max HP | 12 s | — |
| Frenzy | +60% attack speed for 5 s | 12 s | — |
| Shock Burst | 1.8× atk, always crits | 7 s | 0.5 s |

### 3.3 Archetypes it supports
Tank (Iron Torso + Plating + Harden), Striker (light legs + claws + Frenzy), Nuker (Dragon Head +
Fire Breath), Bruiser (balanced), Sustain (Regenerate tail), and later Support in 2v2
(Phase 5: aura abilities that buff the ally).

### 3.4 Arenas (`src/shared/Arenas.lua`)
| # | Arena | Enemy | Lv | Win $ | XP | Drops |
|---|---|---|---|---|---|---|
| 1 | Practice Pit | Training Slime | 1 | 60 | 25 | Common 60% |
| 2 | Goblin Gutter | Mutant Goblin | 3 | 400 | 50 | Common/Uncommon |
| 3 | Iron Colosseum | Armoured Beast | 6 | 2,500 | 90 | Uncommon/Rare |
| 4 | Neon Grid | Cyber Dragon | 11 | 15,000 | 160 | Rare/Epic |
| 5 | Chimera Throne | Legendary Chimera | 18 | 90,000 | 300 | Epic/Legendary, Mythic 3% |

First win: ×3 money and unlocks the next arena. A loss pays 20% money, 50% XP and no drop.

---

## 4. Passive Income Design

### 4.1 Formulas
```
partIncome(p)    = p.stats.income × RarityIncomeMult[p.rarity]
monsterIncome(m) = Σ partIncome(parts of m) × (1 + 0.15 × (m.level − 1))
globalMult       = LabIncomeTier.mult × (1 + 0.25 × rebirths)
totalIncome      = Σ monsterIncome(m) × globalMult      -- global applied ONCE
```
`RarityIncomeMult`: Common 1, Uncommon 1.6, Rare 2.8, Epic 5, Legendary 9, Mythic 16.

Example: the starter monster = 2 + 1 + 1 + 1 = **$5/s** (it matches "Basic Slime").

### 4.2 Server tick
There is one loop for the whole server (`IncomeService`). It runs once per second. For each
loaded player: `money += cachedIncome × dt`. `cachedIncome` is only recalculated when monsters or
multipliers change. Cost is O(players) per second, not O(monsters). The values replicate through
player attributes (`Money`, `IncomePerSec`). The client interpolates between them so the counter rolls smoothly.

### 4.3 Offline earnings
- On load: `elapsed = clamp(os.time() − data.lastSeen, 0, 8 h)`, then `payout = elapsed × totalIncome × 0.5`.
- `lastSeen` is **server time** and is written in the same DataStore record as `money`. If a save
  fails, the payout and the timestamp roll back together, so nothing can be claimed twice.
- A session lock stops two servers loading the same profile and both paying out.
- The client gets a "Welcome back" summary showing time away, rate and total.

### 4.4 Ownership rules
| Event | Income behaviour |
|---|---|
| Created | Counts from the next tick |
| Renamed | No change |
| Edited | Old parts go back to inventory, new parts are spent, income is recalculated. Same monster ID. |
| Upgraded | Recalculated immediately. The UI shows "+$X/s". |
| In battle / builder / not displayed | **Still earns.** Nothing reads "active" state. |
| Recycled | Parts are refunded and income stops. Not allowed during battle. |
| Unknown part ID (catalog error) | That part counts as 0 income/stats. The record is kept, never deleted. |
| Traded (future) | Moved atomically between two profiles inside one server. |

Duplication defences: monsters are keyed by a server-made GUID. Building and editing check and
spend inventory counts on the server. Blueprints carry no items.

### 4.5 Economy balance (MVP targets)
| Milestone | Target time | Income at that point |
|---|---|---|
| First monster | 0:45 | $5/s |
| Second monster (Basic Crate parts) | ~5 min | ~$15/s |
| Arena 3 unlocked | ~25 min | ~$60/s |
| First Epic part | ~1.5 h | ~$400/s |
| First Legendary | ~6–10 h | ~$3k/s |

**Currency sinks:** level upgrades (cost `25 × baseIncome × 1.5^(level−1)` gives a ~170 s payback
that gets longer each level), crates, lab income tiers, containment pod (slot) tiers, and rebirth.
**Why arenas stay relevant:** the best parts (Epic and up) mostly drop from arenas. The Advanced Crate
gives Legendary at only 2%, and Mythic only drops from arena 5. Arena cash is about 3–6 minutes of
the passive income you'd expect at that point.
**Slot cap:** 6 monster slots, raised to 15 by pod upgrades. That cap is what stops passive income
from growing out of control.

### 4.6 Rebirth (Phase 6 design)
- Requires a lifetime total of $10M × 4^rebirths.
- **Resets:** money, lab tiers, monster levels (back to 1).
- **Keeps:** every monster, every part, blueprints, arena unlocks, index.
- **Gives:** +25% global income per rebirth (additive), one rebirth-exclusive part per tier, +1 pod slot.

---

## 5. Technical Architecture

### 5.1 Explorer hierarchy (as built by Rojo, `default.project.json`)
```
ReplicatedStorage
  Shared (Folder)
    Config            ModuleScript  – rarities, slots, abilities, economy constants
    PartCatalog       ModuleScript  – every part definition
    Arenas            ModuleScript  – arena + enemy definitions
    Stats             ModuleScript  – stat & income math (pure)
    BattleSim         ModuleScript  – deterministic combat simulation (pure)
    Assembler         ModuleScript  – part list → Model (used by client & server)
    Format            ModuleScript  – number/time formatting
  Remotes (Folder, created at runtime by server)
    Action            RemoteFunction – all client requests
    StateChanged      RemoteEvent    – full inventory snapshot pushes
    BattleEvent       RemoteEvent    – battle stream
    Notify            RemoteEvent    – toasts & offline summary
    UseAbility        RemoteEvent    – battle input
ServerScriptService
  Server (Folder)
    Main              Script         – boots services, player lifecycle
    Services
      DataService     – DataStore load/save, session lock, autosave, BindToClose
      IncomeService   – global income tick + offline earnings
      MonsterService  – build / edit / rename / recycle / upgrade validation
      ShopService     – part purchases, crates, lab upgrades
      BattleService   – runs BattleSim in real time, rewards
      LabService      – builds the world, plots, monster displays
      Remotes         – remote creation, rate limiting, dispatch
StarterPlayer.StarterPlayerScripts
  Client (Folder)
    Main              LocalScript    – boots UI controllers
    UI/ Theme, Ui (helpers), State, Hud, Builder, Collection, Shop, Arena, Battle, Tutorial
```

### 5.2 Networking
- **One** `Action` RemoteFunction: `(actionName, payload) → { ok, err?, ... }`. The server keeps a
  whitelist dispatch table, checks types, and rate-limits each player (`Remotes.lua`: token bucket, 8 per s, burst 15).
- The server pushes full state with `StateChanged` after each successful change. It's small (parts
  plus monster records) and makes desync impossible.
- Money and income are sent as player attributes, updated every second.
- The client never sends numbers that matter (costs, stats, damage, rewards). It only sends IDs and names.

### 5.3 Persistence
DataStore `BBL_Player_v1`, key `u_<UserId>`. The schema is in `DataService.Template`:
`money, totalEarned, parts{id→count}, monsters{guid→record}, blueprints[], lab{incomeTier,podTier},
arenas{unlocked, firstWins{}}, tutorial, lastSeen, rebirths, stats{}, lock{jobId,time}`.
- Load: `UpdateAsync` takes the session lock. If another live server holds it (lock less than 15 min old), retry 5 times with backoff, then kick with a message.
- Save: autosave every 120 s, on leave (releasing the lock) and in `BindToClose`. Saves retry 3 times with backoff.
- Numbers are kept as plain doubles. Records are about 5 KB for 15 monsters, far below the 4 MB limit.

### 5.4 Security mitigations
| Threat | Mitigation |
|---|---|
| Currency manipulation | Money only changes on the server. The client value is display-only. |
| Fake part ownership | Build/edit check `parts[id] ≥ needed` on the server and spend it in the same frame |
| Monster duplication | Server GUIDs. No client-supplied IDs are trusted for creation. Blueprints carry no items. |
| Invalid builds | Slot/part-slot match, required slots, dependencies (Horns need Head), name filter and length check |
| Blueprint tampering | Blueprints are parsed and checked on the server. Unknown IDs are rejected. |
| Combat reward exploits | The server simulates the fight. One battle per player at a time. Rewards come from server tables. |
| Remote spam | Per-player token bucket, typed payload checks, pcall around handlers |
| Offline income abuse | Server `os.time()`, capped at 8 h, saved atomically with money, session lock |

---

## 6. UI/UX Specification
- **HUD (top centre):** money (rolling counter) and `+$X/s` in green, which pulses when income rises.
  Left rail: Build, Monsters, Shop, Arena. Toasts go bottom-right and fade in 3 s. The tutorial banner sits at the top under the HUD.
- **Builder:** left = 10 slot buttons (each with a rarity-coloured stroke and a red mark if a required slot is empty).
  Centre = ViewportFrame preview (drag to rotate, scroll or buttons to zoom).
  Right = parts for the selected slot with owned count, rarity and stat change.
  Bottom = live stats (HP, ATK, DEF, SPD, AS, CRIT, $/s, ability), name box, Build / Save, Blueprint code box.
  If a dependency is missing, the slot is greyed with the tooltip "Needs Arms".
- **Collection:** a card grid. Each card has a preview, name, level, $/s, combat summary, Upgrade ($cost, +$/s),
  Edit, Recycle (asks twice) and a slot counter "4/6".
- **Shop:** tabs for Parts (fixed list), Crates (Basic/Advanced with odds shown) and Lab (income tiers, pod tiers).
- **Arena:** arena cards (locked or unlocked, rewards, recommended level), a monster picker and Fight.
- **Battle screen:** a full-screen viewport with both monsters facing each other, HP bars, floating damage numbers,
  a big ability button with a cooldown sweep, a telegraph warning and a result panel with rewards. The HUD stays visible, so you can watch income keep ticking.
- Controller/console: every button is a `GuiButton` with `Selectable = true`. Mobile: everything uses
  scale sizes, and the minimum touch target is about 44 px.

---

## 7. Development Roadmap
| Phase | Deliverables | Depends on | Acceptance |
|---|---|---|---|
| 1 MVP (**this repo**) | Lab, 10 slots, 41 parts, build/edit/recycle, passive + offline income, 5 arenas, hybrid combat, shop, crates, lab tiers, tutorial, blueprint codes | — | Build → earn → fight (income keeps ticking) → spend, across rejoin |
| 2 Builder+ | Motor6D rig, slot animations, colour customisation, multiple blueprint slots UI | 1 | 100% of slot combos assemble without overlap (automated sweep) |
| 3 Economy | Rebirth, balance sheet tool, more lab tiers | 1 | Simulated 10 h session hits §4.5 targets ±25% |
| 4 Combat+ | Arena modifiers, multi-enemy waves, more abilities | 1 | Each archetype wins ≥ 40% vs a balanced reference |
| 5 Multiplayer | 2v2 (BattleSim already supports N vs N teams internally), party, matchmaking, spectate | 4 | 2v2 completes with 4 clients, no desync |
| 6 Live | Daily quests, login rewards, index, events | 3 | D1/D7 metrics instrumented |
| 7 Polish/Monetisation | VFX/SFX, game passes, cosmetics via `MarketplaceService.ProcessReceipt` with an idempotent receipt log | 1 | Receipts never double-grant |
| 8 Launch | Stress, exploit, device testing | all | Checklist in README |

**Monetisation guardrails:** passes = 2× part drops, +2 cosmetic display pedestals, VIP lobby.
Dev products = cosmetic only (paint, auras, lab themes). **No paid monster slots** (slots = income),
and no paid stat boosts in PvP.

---

## 8. Risk Assessment
| System | Complexity | Risk | Mitigation |
|---|---|---|---|
| Modular assembly | Med | Overlaps or floating parts on extreme sizes | Socket offsets derived from sizes, ground snap, catalog size limits, Phase 2 sweep test |
| Dynamic combat | Med | Odd shapes break hitboxes | Combat is abstract (stats); visuals are presentation only |
| Passive economy | High (design) | Exponential growth makes arenas pointless | Slot cap, rising upgrade cost curve, best parts drop in arenas, rebirth resets money |
| Offline earnings | Med | Double claim, time manipulation | Server time, atomic save, session lock, 8 h cap |
| DataStore | Med | Data loss or throttling | UpdateAsync, retries, session lock, BindToClose, 120 s autosave |
| Multiplayer sync | Med | 2v2 desync | Server-authoritative sim streaming events; clients only animate |
| Mobile UI density | Med | Builder too cramped on phones | Scale layout; Phase 7 dedicated phone layout |

---

## 9. MVP Implementation Plan (what was built)
1. Shared data: Config, PartCatalog, Arenas, Stats, BattleSim, Assembler, Format.
2. Server: DataService → IncomeService → MonsterService → ShopService → BattleService → LabService → Remotes → Main.
3. Client: State cache, HUD, Builder, Collection, Shop, Arena/Battle, Tutorial.
4. Verification: Rojo build, StyLua parse, Selene lint (static only). In-Studio test procedure: README §Testing.

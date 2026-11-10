-- Arena selection + battle presentation. The server simulates; this only animates
-- the event stream and sends "use ability" input.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.PartCatalog)
local Arenas = require(ReplicatedStorage.Shared.Arenas)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Assembler = require(ReplicatedStorage.Shared.Assembler)
local Format = require(ReplicatedStorage.Shared.Format)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BattleEvent = Remotes:WaitForChild("BattleEvent") :: RemoteEvent
local UseAbility = Remotes:WaitForChild("UseAbility")

local T = Ui.Theme
local create = Ui.create

local Arena = {}
local win, list, pickerLabel
local pickIndex = 1
local lastArenaId = 1
local screenGui

-- Battle screen state
local battle -- { frame, view, units = {...}, abilityBtn, cdOverlay, ... }

local function selectedMonster()
	local monsters = State.monsterList()
	if #monsters == 0 then
		return nil
	end
	pickIndex = ((pickIndex - 1) % #monsters) + 1
	return monsters[pickIndex]
end

local function refreshPicker()
	local m = selectedMonster()
	if m then
		local s = Stats.compute(m.parts, m.level)
		pickerLabel.Text = ("%s  Lv%d   HP %d  ATK %.0f  DEF %.0f  ⚡ %s"):format(
			m.name,
			m.level,
			s.hp,
			s.atk,
			s.def,
			s.ability and Config.Abilities[s.ability].name or "none"
		)
	else
		pickerLabel.Text = "Build a monster first!"
	end
end

local function startBattle(arenaId: number)
	local m = selectedMonster()
	if not m then
		Ui.toast("Build a monster first!", T.Warn)
		return
	end
	lastArenaId = arenaId
	local r = State.invoke("StartBattle", { arenaId = arenaId, monsterId = m.id })
	if r.ok then
		win.frame.Visible = false
	end
end

local function renderList()
	if not win.frame.Visible then
		return
	end
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local unlocked = State.data and State.data.arenas.unlocked or 1
	for i, a in ipairs(Arenas) do
		local locked = a.id > unlocked
		local firstWin = State.data and not State.data.arenas.firstWins[tostring(a.id)]
		local f = create("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, -10, 0, 70),
			BackgroundColor3 = T.Panel,
			Parent = list,
		}, { Ui.corner(8), Ui.stroke(locked and T.Stroke or T.Danger, 1.5), Ui.pad(8) })
		Ui.label({
			Text = (locked and "🔒 " or "⚔ ") .. a.name .. "  —  vs " .. a.enemyName .. " (Lv" .. a.level .. ")",
			Font = T.FontBold,
			TextColor3 = locked and T.Muted or T.Text,
			Size = UDim2.new(1, -140, 0, 20),
			Parent = f,
		})
		Ui.label({
			Text = a.desc .. ("\nWin: %s%s • %d XP • %d%% part drop"):format(
				Format.money(a.money),
				firstWin and (" (first win x" .. Config.Combat.FirstWinMoneyMult .. "!)") or "",
				a.xp,
				math.floor(a.drop.chance * 100)
			),
			TextSize = 13,
			TextColor3 = T.Muted,
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(1, -140, 0, 34),
			Parent = f,
		})
		Ui.button({
			Text = locked and "Locked" or "FIGHT",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(120, 40),
			BackgroundColor3 = locked and T.Panel2 or T.Danger,
			TextColor3 = T.Text,
			Parent = f,
		}, function()
			if locked then
				Ui.toast("Win " .. Arenas[a.id - 1].name .. " to unlock", T.Warn)
			else
				startBattle(a.id)
			end
		end)
	end
	refreshPicker()
end

------------------------------------------------------------------------------
-- Battle screen
------------------------------------------------------------------------------
local function tweenPivot(model: Model, target: CFrame, info: TweenInfo)
	local v = Instance.new("CFrameValue")
	v.Value = model:GetPivot()
	v.Changed:Connect(function(cf)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	local tw = TweenService:Create(v, info, { Value = target })
	tw.Completed:Connect(function()
		v:Destroy()
	end)
	tw:Play()
	return tw
end

local function floatText(side: number, text: string, color: Color3, big: boolean?)
	if not battle then
		return
	end
	local x = side == 1 and 0.25 or 0.75
	local l = Ui.label({
		Text = text,
		Font = T.FontBlack,
		TextSize = big and 34 or 24,
		TextColor3 = color,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.06, 0.35),
		Size = UDim2.fromOffset(240, 40),
		ZIndex = 30,
		Parent = battle.frame,
	})
	TweenService:Create(l, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = l.Position - UDim2.fromScale(0, 0.1),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.05, function()
		l:Destroy()
	end)
end

local function setHp(i: number, hp: number)
	local u = battle.units[i]
	u.hp = hp
	local pct = math.clamp(hp / u.maxHp, 0, 1)
	TweenService:Create(u.bar, TweenInfo.new(0.2), { Size = UDim2.fromScale(pct, 1) }):Play()
	u.hpText.Text = ("%d / %d"):format(hp, u.maxHp)
end

local function lunge(src: number)
	local u = battle.units[src]
	if not u.model.Parent then
		return
	end
	-- home faces the opponent, so local -Z is "forward"
	tweenPivot(u.model, u.home * CFrame.new(0, 0, -1.8), TweenInfo.new(0.08)).Completed:Connect(function()
		tweenPivot(u.model, u.home, TweenInfo.new(0.15))
	end)
end

local function shake(dst: number)
	local u = battle.units[dst]
	tweenPivot(u.model, u.home * CFrame.new(0.4, 0, 0.4), TweenInfo.new(0.05)).Completed:Connect(function()
		tweenPivot(u.model, u.home, TweenInfo.new(0.1))
	end)
end

local function sideOf(i: number)
	return i == battle.you and 1 or 2
end

local function handleEvent(e)
	if e.type == "attack" then
		lunge(e.src)
		task.delay(0.08, function()
			shake(e.dst)
		end)
		setHp(e.dst, e.hp)
		floatText(sideOf(e.dst), (e.crit and "CRIT " or "") .. "-" .. e.dmg, e.crit and T.Warn or T.Text, e.crit)
	elseif e.type == "dodge" then
		floatText(sideOf(e.dst), "DODGE", T.Accent)
	elseif e.type == "windup" then
		local a = Config.Abilities[e.ability]
		local u = battle.units[e.src]
		if e.src == battle.you then
			battle.cdStart, battle.cdLen = os.clock(), a.cooldown
			battle.ready = false
		else
			battle.warning.Text = ("⚠ %s is charging %s! (%s now!)"):format(u.name, a.name:upper(), "Defend or stun")
			battle.warning.Visible = true
			task.delay(e.duration + 0.2, function()
				if battle then
					battle.warning.Visible = false
				end
			end)
		end
	elseif e.type == "ability" then
		local a = Config.Abilities[e.ability]
		local side = sideOf(e.src)
		if e.src == battle.you then
			battle.cdStart, battle.cdLen = os.clock(), a.cooldown
			battle.ready = false
		end
		floatText(side, "⚡ " .. a.name, Color3.fromRGB(255, 160, 60), true)
		if e.dst then
			lunge(e.src)
			shake(e.dst)
			setHp(e.dst, e.hp)
			task.delay(0.25, function()
				floatText(
					sideOf(e.dst),
					(e.crit and "CRIT " or "") .. "-" .. e.dmg .. (e.stun and " STUN" or ""),
					Color3.fromRGB(255, 120, 60),
					true
				)
			end)
		elseif e.heal then
			setHp(e.src, e.hp)
			floatText(side, "+" .. e.heal, T.Money, true)
		end
	elseif e.type == "ready" then
		battle.ready = true
	end
end

local function closeBattle()
	if battle then
		battle.conn:Disconnect()
		battle.frame:Destroy()
		battle = nil
	end
end

local function showResult(rewards)
	if not battle then
		return
	end
	battle.abilityBtn.Visible = false
	local panel = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 300),
		BackgroundColor3 = T.Bg,
		ZIndex = 40,
		Parent = battle.frame,
	}, { Ui.corner(14), Ui.stroke(rewards and rewards.won and T.Money or T.Danger, 3), Ui.pad(14) })
	if not rewards then
		Ui.label({ Text = "Battle ended", ZIndex = 41, Parent = panel })
	else
		local lines = {
			("Money: +%s%s"):format(Format.money(rewards.money), rewards.firstWin and "  (first win bonus!)" or ""),
			("XP: +%d%s"):format(rewards.xp, rewards.levelsGained > 0 and ("  • LEVEL UP x" .. rewards.levelsGained .. "!") or ""),
		}
		for _, id in ipairs(rewards.parts) do
			local p = Catalog.get(id)
			table.insert(lines, ("New part: %s [%s]"):format(p.name, p.rarity))
		end
		if rewards.unlockedArena then
			table.insert(lines, "Unlocked: " .. Arenas[rewards.unlockedArena].name .. "!")
		end
		table.insert(lines, "Your monsters kept earning " .. Format.rate(State.income()) .. " the whole fight.")
		Ui.label({
			Text = rewards.won and "VICTORY!" or "DEFEAT",
			Font = T.FontBlack,
			TextSize = 34,
			TextColor3 = rewards.won and T.Money or T.Danger,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 40),
			ZIndex = 41,
			Parent = panel,
		})
		Ui.label({
			Text = table.concat(lines, "\n"),
			TextSize = 16,
			Position = UDim2.fromOffset(0, 48),
			Size = UDim2.new(1, 0, 0, 170),
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 41,
			Parent = panel,
		})
	end
	Ui.button({
		Text = "Fight Again",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0.48, 0, 0, 40),
		BackgroundColor3 = T.Danger,
		TextColor3 = T.Text,
		ZIndex = 41,
		Parent = panel,
	}, function()
		closeBattle()
		startBattle(lastArenaId)
	end)
	Ui.button({
		Text = "Back to Lab",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(0.48, 0, 0, 40),
		ZIndex = 41,
		Parent = panel,
	}, closeBattle)
	Ui.pop(panel)
end

local function openBattle(info)
	closeBattle()
	local frame = create("Frame", {
		Name = "Battle",
		BackgroundColor3 = Color3.fromRGB(10, 10, 16),
		Size = UDim2.new(1, 0, 1, -80),
		Position = UDim2.fromOffset(0, 80), -- leave the money HUD visible above
		ZIndex = 5,
		Parent = screenGui,
	})
	local view = Ui.viewport(frame, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(25, 20, 35),
		ZIndex = 5,
	})
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(40, 1, 20)
	floor.Position = Vector3.new(0, -0.5, 0)
	floor.Color = Color3.fromRGB(110, 40, 50)
	floor.Material = Enum.Material.DiamondPlate
	floor.Parent = view.world

	battle = { frame = frame, view = view, units = {}, you = info.you, ready = false }
	local abilityId = info.units[info.you].stats.ability
	local ability = abilityId and Config.Abilities[abilityId]
	battle.cdStart, battle.cdLen = os.clock() + info.introDelay, ability and ability.cooldown * 0.5 or 0

	for i, u in ipairs(info.units) do
		local model = Assembler.build(u.parts, { name = u.name })
		local x = i == 1 and -7 or 7
		local home = CFrame.new(x, 0, 0) * CFrame.Angles(0, i == 1 and -math.pi / 2 or math.pi / 2, 0)
		model:PivotTo(home)
		model.Parent = view.world

		local side = i == info.you and 1 or 2
		local hpFrame = create("Frame", {
			AnchorPoint = Vector2.new(side == 1 and 0 or 1, 0),
			Position = side == 1 and UDim2.new(0, 20, 0, 16) or UDim2.new(1, -20, 0, 16),
			Size = UDim2.new(0.4, 0, 0, 56),
			BackgroundTransparency = 1,
			ZIndex = 10,
			Parent = frame,
		})
		Ui.label({
			Text = ("%s  Lv%d"):format(u.name, u.level),
			Font = T.FontBlack,
			TextSize = 18,
			TextXAlignment = side == 1 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
			ZIndex = 10,
			Parent = hpFrame,
		})
		local back = create("Frame", {
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundColor3 = Color3.fromRGB(50, 20, 25),
			ZIndex = 10,
			Parent = hpFrame,
		}, { Ui.corner(6) })
		local bar = create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = side == 1 and T.Money or T.Danger,
			ZIndex = 11,
			Parent = back,
		}, { Ui.corner(6) })
		local hpText = Ui.label({
			Text = "",
			Font = T.FontBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 12,
			Parent = back,
		})
		battle.units[i] = { model = model, home = home, hp = u.stats.hp, maxHp = u.stats.hp, bar = bar, hpText = hpText, name = u.name }
		setHp(i, u.stats.hp)
	end

	-- Fixed side camera
	view.camera.CFrame = CFrame.lookAt(Vector3.new(0, 7, 24), Vector3.new(0, 2.5, 0))
	view.update = function() end -- disable orbit for battle

	battle.warning = Ui.label({
		Text = "",
		Visible = false,
		Font = T.FontBlack,
		TextSize = 24,
		TextColor3 = T.Warn,
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 0, 90),
		Size = UDim2.new(1, 0, 0, 30),
		ZIndex = 20,
		Parent = frame,
	})

	local countdown = Ui.label({
		Text = info.arenaName .. "\nGET READY!",
		Font = T.FontBlack,
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(500, 100),
		ZIndex = 30,
		Parent = frame,
	})
	task.delay(info.introDelay, function()
		countdown:Destroy()
	end)

	local abilityBtn = Ui.button({
		Text = ability and ("⚡ " .. ability.name .. "\n[Space / tap]") or "No ability",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(220, 64),
		BackgroundColor3 = Color3.fromRGB(255, 160, 60),
		ZIndex = 20,
		Parent = frame,
	}, function()
		if ability then
			UseAbility:FireServer()
		end
	end)
	local cdOverlay = create("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 21,
		Parent = abilityBtn,
	}, { Ui.corner(8) })
	battle.abilityBtn = abilityBtn

	Ui.button({
		Text = "Forfeit",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(100, 36),
		BackgroundColor3 = T.Panel2,
		TextColor3 = T.Text,
		ZIndex = 20,
		Parent = frame,
	}, function()
		State.invoke("Forfeit")
	end)

	battle.conn = RunService.RenderStepped:Connect(function()
		if not ability then
			cdOverlay.Size = UDim2.fromScale(1, 1)
			return
		end
		local elapsed = os.clock() - battle.cdStart
		local frac = battle.ready and 0 or math.clamp(1 - elapsed / battle.cdLen, 0, 1)
		cdOverlay.Size = UDim2.fromScale(1, frac)
		cdOverlay.Position = UDim2.fromScale(0, 1 - frac)
	end)
end

function Arena.init(gui: ScreenGui)
	screenGui = gui
	win = Ui.window(gui, "Arena", UDim2.new(0.7, 0, 0.8, 0))
	local pickRow = create("Frame", {
		BackgroundColor3 = T.Panel,
		Size = UDim2.new(1, 0, 0, 46),
		Parent = win.content,
	}, { Ui.corner(8), Ui.pad(4) })
	Ui.button({ Text = "◀", Size = UDim2.fromOffset(40, 38), Parent = pickRow }, function()
		pickIndex -= 1
		refreshPicker()
	end)
	pickerLabel = Ui.label({
		Text = "",
		Font = T.FontBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(46, 0),
		Size = UDim2.new(1, -92, 1, 0),
		Parent = pickRow,
	})
	Ui.button({
		Text = "▶",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(40, 38),
		Parent = pickRow,
	}, function()
		pickIndex += 1
		refreshPicker()
	end)
	list = Ui.scroll({ Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54), Parent = win.content })
	Ui.list(Enum.FillDirection.Vertical, 6).Parent = list
	State.Changed.Event:Connect(renderList)

	BattleEvent.OnClientEvent:Connect(function(kind, payload)
		if kind == "start" then
			openBattle(payload)
		elseif kind == "events" and battle then
			for _, e in ipairs(payload.events) do
				if e.type == "end" then
					continue
				end
				handleEvent(e)
			end
		elseif kind == "end" then
			showResult(payload)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not battle then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonX then
			UseAbility:FireServer()
		end
	end)
end

function Arena.open()
	win.frame.Visible = true
	Ui.pop(win.frame)
	renderList()
end

function Arena.window()
	return win
end

function Arena.inBattle()
	return battle ~= nil
end

return Arena

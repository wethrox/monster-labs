-- Collection: every owned monster with its income, stats, upgrade / edit / recycle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Assembler = require(ReplicatedStorage.Shared.Assembler)
local Format = require(ReplicatedStorage.Shared.Format)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local T = Ui.Theme
local create = Ui.create

local Collection = {}
local win, grid, header
local router
local confirmRecycle = {} -- [monsterId] = clock time of first press

local function card(m, order)
	local s = Stats.compute(m.parts, m.level)
	local income = State.monsterIncome(m)
	local maxed = m.level >= Config.Leveling.MaxLevel
	local cost = Stats.upgradeCost(m)
	local nextIncome = Stats.baseIncome(m.parts) * Stats.levelIncomeMult(m.level + 1) * State.globalMult()

	local f = create("Frame", {
		LayoutOrder = order,
		BackgroundColor3 = T.Panel,
		Parent = grid,
	}, { Ui.corner(10), Ui.stroke(), Ui.pad(8) })

	local view = Ui.viewport(f, { Size = UDim2.new(0, 120, 0, 120), BackgroundColor3 = T.Panel2 })
	view.setModel(Assembler.build(m.parts, { name = m.name }))

	local info = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(128, 0),
		Size = UDim2.new(1, -128, 0, 120),
		Parent = f,
	})
	Ui.label({ Text = m.name, Font = T.FontBlack, TextSize = 18, Size = UDim2.new(1, 0, 0, 22), Parent = info })
	Ui.label({
		Text = ("Lv %d   XP %d/%d"):format(m.level, m.xp or 0, Stats.xpToNext(m.level)),
		TextColor3 = T.Muted,
		TextSize = 13,
		Position = UDim2.fromOffset(0, 22),
		Parent = info,
	})
	Ui.label({
		Text = Format.rate(income) .. "  💰 earning now",
		Font = T.FontBold,
		TextColor3 = T.Money,
		Position = UDim2.fromOffset(0, 42),
		Parent = info,
	})
	Ui.label({
		Text = ("HP %d  ATK %.0f  DEF %.0f\nSPD %.1f  AS %.2f  CRIT %d%%\n⚡ %s"):format(
			s.hp,
			s.atk,
			s.def,
			s.speed,
			s.attackSpeed,
			s.crit,
			s.ability and Config.Abilities[s.ability].name or "no ability"
		),
		TextSize = 13,
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.new(1, 0, 0, 56),
		Parent = info,
	})

	local row = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 1, -40),
		Size = UDim2.new(1, 0, 0, 40),
		Parent = f,
	}, { Ui.list(Enum.FillDirection.Horizontal, 6) })

	local up = Ui.button({
		Text = maxed and "MAX" or ("⬆ %s\n%s"):format(Format.money(cost), Format.rate(nextIncome - income)),
		TextSize = 13,
		Size = UDim2.new(0.46, 0, 1, 0),
		BackgroundColor3 = (not maxed and State.money() >= cost) and T.Money or T.Panel2,
		TextColor3 = (not maxed and State.money() >= cost) and Color3.fromRGB(15, 18, 25) or T.Text,
		LayoutOrder = 1,
		Parent = row,
	}, function()
		if maxed then
			return
		end
		local r = State.invoke("UpgradeMonster", { id = m.id })
		if r.ok then
			Ui.toast(("%s reached Lv %d! %s"):format(m.name, r.level, Format.rate(r.incomeGain or 0)), T.Money)
		end
	end)
	up:SetAttribute("UpgradeFor", m.id)

	Ui.button({
		Text = "Edit",
		Size = UDim2.new(0.24, 0, 1, 0),
		LayoutOrder = 2,
		Parent = row,
	}, function()
		router.openBuilder(m)
	end)
	local rec
	rec = Ui.button({
		Text = "Recycle",
		TextSize = 13,
		Size = UDim2.new(0.26, 0, 1, 0),
		BackgroundColor3 = T.Danger,
		TextColor3 = T.Text,
		LayoutOrder = 3,
		Parent = row,
	}, function()
		local first = confirmRecycle[m.id]
		if first and os.clock() - first < 3 then
			confirmRecycle[m.id] = nil
			local r = State.invoke("RecycleMonster", { id = m.id })
			if r.ok then
				Ui.toast(m.name .. " recycled: parts returned to inventory", T.Warn)
			end
		else
			confirmRecycle[m.id] = os.clock()
			rec.Text = "Sure?"
			task.delay(3, function()
				if rec.Parent then
					rec.Text = "Recycle"
				end
			end)
		end
	end)
end

local function refresh()
	if not win.frame.Visible then
		return
	end
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local list = State.monsterList()
	local limit = State.data and Stats.slotLimit(State.data) or 6
	header.Text = ("Pods %d/%d   •   Total income %s   •   Every monster earns, fighting or not."):format(
		#list,
		limit,
		Format.rate(State.income())
	)
	for i, m in ipairs(list) do
		card(m, i)
	end
	if #list == 0 then
		Ui.label({ Text = "No monsters yet. Open the Builder to create one!", TextColor3 = T.Muted, Parent = grid })
	end
end

-- Lightweight refresh of upgrade affordability without rebuilding viewports every second.
local function refreshAffordability()
	if not win.frame.Visible or not State.data then
		return
	end
	for _, d in ipairs(grid:GetDescendants()) do
		local id = d:IsA("TextButton") and d:GetAttribute("UpgradeFor")
		local m = id and State.data.monsters[id]
		if m and m.level < Config.Leveling.MaxLevel then
			local can = State.money() >= Stats.upgradeCost(m)
			d.BackgroundColor3 = can and T.Money or T.Panel2
			d.TextColor3 = can and Color3.fromRGB(15, 18, 25) or T.Text
		end
	end
end

function Collection.init(gui: ScreenGui, r)
	router = r
	win = Ui.window(gui, "My Monsters", UDim2.new(0.86, 0, 0.8, 0))
	header = Ui.label({ Text = "", TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 22), Parent = win.content })
	grid = Ui.scroll({ Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -28), Parent = win.content })
	create("UIGridLayout", {
		CellSize = UDim2.new(0.5, -8, 0, 186),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	State.Changed.Event:Connect(refresh)
	task.spawn(function()
		while true do
			task.wait(1)
			refreshAffordability()
		end
	end)
end

function Collection.open()
	win.frame.Visible = true
	Ui.pop(win.frame)
	refresh()
end

function Collection.window()
	return win
end

return Collection

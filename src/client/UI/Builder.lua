-- Creature Builder: slot list, live 3D preview, part picker, live stats + income, blueprints.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.PartCatalog)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Assembler = require(ReplicatedStorage.Shared.Assembler)
local Format = require(ReplicatedStorage.Shared.Format)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local T = Ui.Theme
local create = Ui.create

local Builder = {}

local win, view
local slotButtons = {}
local partList, statsLabel, statusLabel, nameBox, buildBtn, codeBox, titleLabel
local draft = { parts = {}, editing = nil } -- editing = monster record being edited
local selectedSlot = "Torso"

local STAT_NAMES = {
	{ "hp", "HP" },
	{ "atk", "ATK" },
	{ "def", "DEF" },
	{ "spd", "SPD" },
	{ "aspd", "AS" },
	{ "crit", "CRIT%" },
	{ "weight", "WT" },
}

local function partSummary(p)
	local bits = {}
	local mult = Config.RarityStatMult[p.rarity] or 1
	for _, s in ipairs(STAT_NAMES) do
		local v = p.stats[s[1]]
		if v and v ~= 0 then
			local shown = s[1] == "weight" and v or v * mult
			local str = (shown == math.floor(shown)) and tostring(shown) or string.format("%.2f", shown)
			table.insert(bits, (shown > 0 and "+" or "") .. str .. " " .. s[2])
		end
	end
	return table.concat(bits, "  ")
end

-- How many of a part the player can use for this draft (inventory + parts locked in the monster being edited).
local function available(partId: string): number
	local n = State.owned(partId)
	if draft.editing then
		for _, id in pairs(draft.editing.parts) do
			if id == partId then
				n += 1
			end
		end
	end
	return n
end

local function missingParts()
	local need, missing = {}, {}
	for _, id in pairs(draft.parts) do
		need[id] = (need[id] or 0) + 1
	end
	for id, n in pairs(need) do
		if available(id) < n then
			table.insert(missing, Catalog.get(id).name)
		end
	end
	return missing
end

local refreshAll

local function setPart(slot: string, partId: string?)
	draft.parts[slot] = partId
	if not partId then
		-- Removing a slot also removes anything that depends on it (e.g. Arms -> Claws).
		for _, s in ipairs(Config.Slots) do
			if s.requires == slot then
				draft.parts[s.id] = nil
			end
		end
	end
	refreshAll(true)
end

local function refreshSlots()
	for _, s in ipairs(Config.Slots) do
		local btn = slotButtons[s.id]
		local id = draft.parts[s.id]
		local p = id and Catalog.get(id)
		local blocked = s.requires and not draft.parts[s.requires]
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		btn.BackgroundColor3 = (s.id == selectedSlot) and T.Panel2 or T.Panel
		local sub
		if blocked then
			sub = "Needs " .. s.requires
			btn.TextTransparency = 0.5
		elseif p then
			sub = p.name
			btn.TextTransparency = 0
		else
			sub = s.required and "REQUIRED" or "empty"
			btn.TextTransparency = 0
		end
		btn.Text = s.id .. "\n" .. sub
		stroke.Color = p and Ui.rarityColor(p.rarity) or (s.required and T.Danger or T.Stroke)
		stroke.Thickness = (s.id == selectedSlot) and 3 or 1.5
	end
end

local function refreshParts()
	for _, c in ipairs(partList:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local slotDef = Config.SlotById[selectedSlot]
	if slotDef.requires and not draft.parts[slotDef.requires] then
		Ui.label({
			Text = "Attach " .. slotDef.requires .. " first: " .. selectedSlot .. " connect to it.",
			TextColor3 = T.Warn,
			Size = UDim2.new(1, 0, 0, 44),
			Parent = partList,
		})
		return
	end
	if not slotDef.required and draft.parts[selectedSlot] then
		Ui.button({
			Text = "Remove " .. selectedSlot,
			Size = UDim2.new(1, -8, 0, 32),
			BackgroundColor3 = T.Danger,
			TextColor3 = T.Text,
			LayoutOrder = -1,
			Parent = partList,
		}, function()
			setPart(selectedSlot, nil)
		end)
	end

	local parts = Catalog.bySlot(selectedSlot)
	table.sort(parts, function(a, b)
		local ra, rb = Config.RarityIndex[a.rarity], Config.RarityIndex[b.rarity]
		if ra ~= rb then
			return ra < rb
		end
		return a.name < b.name
	end)
	local mult = State.globalMult()
	for i, p in ipairs(parts) do
		local have = available(p.id)
		local equipped = draft.parts[selectedSlot] == p.id
		local card = create("TextButton", {
			Text = "",
			AutoButtonColor = true,
			LayoutOrder = i,
			Size = UDim2.new(1, -8, 0, 74),
			BackgroundColor3 = equipped and T.Panel2 or T.Panel,
			Selectable = true,
			Parent = partList,
		}, { Ui.corner(8), Ui.stroke(Ui.rarityColor(p.rarity), equipped and 3 or 1.5), Ui.pad(6) })
		Ui.label({
			Text = p.name .. (equipped and "  ✓" or ""),
			Font = T.FontBold,
			TextColor3 = Ui.rarityColor(p.rarity),
			Size = UDim2.new(1, -70, 0, 18),
			Parent = card,
		})
		Ui.label({
			Text = have > 0 and ("x" .. have) or "not owned",
			TextColor3 = have > 0 and T.Text or T.Danger,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 70, 0, 18),
			TextSize = 14,
			Parent = card,
		})
		local incomeText = Format.rate((p.stats.income or 0) * (Config.RarityIncomeMult[p.rarity] or 1) * mult)
		local abilityText = p.ability and ("  ⚡ " .. Config.Abilities[p.ability].name) or ""
		Ui.label({
			Text = p.rarity .. "  •  " .. incomeText .. abilityText,
			TextColor3 = T.Muted,
			TextSize = 13,
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(1, 0, 0, 16),
			Parent = card,
		})
		Ui.label({
			Text = partSummary(p),
			TextSize = 13,
			Position = UDim2.fromOffset(0, 38),
			Size = UDim2.new(1, 0, 0, 24),
			Parent = card,
		})
		card.Activated:Connect(function()
			setPart(selectedSlot, p.id)
		end)
	end
end

local function refreshStats()
	local level = draft.editing and draft.editing.level or 1
	local s = Stats.compute(draft.parts, level)
	local mult = State.globalMult()
	local income = s.income * mult
	local abilityName = s.ability and Config.Abilities[s.ability].name or "none"
	local lines = {
		("HP %d   ATK %.1f   DEF %.1f   SPD %.1f   AS %.2f/s   CRIT %d%%"):format(s.hp, s.atk, s.def, s.speed, s.attackSpeed, s.crit),
		("Ability: %s     Weight %d"):format(abilityName, s.weight),
	}
	local incomeLine = "Income: " .. Format.rate(income)
	if draft.editing then
		local old = State.monsterIncome(draft.editing)
		local diff = income - old
		incomeLine ..= ("   (%s%s vs current)"):format(diff >= 0 and "+" or "", Format.money(diff))
	end
	table.insert(lines, incomeLine)
	statsLabel.Text = table.concat(lines, "\n")

	local valid, err = Stats.validateBuild(draft.parts)
	local missing = missingParts()
	local full = not draft.editing and State.data and State.monsterCount() >= Stats.slotLimit(State.data)
	if not valid then
		statusLabel.Text = "⚠ " .. err
		statusLabel.TextColor3 = T.Warn
	elseif #missing > 0 then
		statusLabel.Text = "⚠ You don't own: " .. table.concat(missing, ", ")
		statusLabel.TextColor3 = T.Danger
	elseif full then
		statusLabel.Text = "⚠ All pods full ("
			.. State.monsterCount()
			.. "/"
			.. Stats.slotLimit(State.data)
			.. "). Upgrade pods in the Shop."
		statusLabel.TextColor3 = T.Danger
	else
		statusLabel.Text = "✓ Ready! This monster will earn " .. Format.rate(income) .. " forever."
		statusLabel.TextColor3 = T.Money
	end
	local canBuild = valid and #missing == 0 and not full
	buildBtn.AutoButtonColor = canBuild
	buildBtn.BackgroundColor3 = canBuild and T.Money or T.Panel2
	buildBtn.Text = draft.editing and "Save Changes" or "BUILD"
end

local function refreshPreview()
	view.setModel(Assembler.build(draft.parts, { name = "Preview" }))
end

function refreshAll(rebuildModel: boolean?)
	if not win or not win.frame.Visible then
		return
	end
	refreshSlots()
	refreshParts()
	refreshStats()
	if rebuildModel then
		refreshPreview()
	end
	titleLabel.Text = draft.editing and ("Editing: " .. draft.editing.name) or "New Monster"
end

local function autoFill()
	-- Equip the highest-rarity available part in every empty slot (in dependency order).
	local used = {}
	for _, id in pairs(draft.parts) do
		used[id] = (used[id] or 0) + 1
	end
	for _, s in ipairs(Config.Slots) do
		if not draft.parts[s.id] and (not s.requires or draft.parts[s.requires]) then
			local best
			for _, p in ipairs(Catalog.bySlot(s.id)) do
				if available(p.id) - (used[p.id] or 0) > 0 then
					if not best or Config.RarityIndex[p.rarity] > Config.RarityIndex[best.rarity] then
						best = p
					end
				end
			end
			if best then
				draft.parts[s.id] = best.id
				used[best.id] = (used[best.id] or 0) + 1
			end
		end
	end
	refreshAll(true)
end

local function submit()
	local valid = Stats.validateBuild(draft.parts)
	if not valid or #missingParts() > 0 then
		Ui.toast(statusLabel.Text, T.Warn)
		return
	end
	buildBtn.Text = "..."
	local result
	if draft.editing then
		result = State.invoke("EditMonster", { id = draft.editing.id, parts = draft.parts, name = nameBox.Text })
	else
		result = State.invoke("BuildMonster", { parts = draft.parts, name = nameBox.Text })
	end
	if result.ok then
		local gain = result.incomeGain or 0
		Ui.toast(
			(draft.editing and "Monster updated! " or "Monster created! ") .. (gain >= 0 and "+" or "") .. Format.rate(gain):sub(2),
			T.Money
		)
		Ui.pop(view.frame)
		if draft.editing then
			-- Mirror the accepted edit locally until the server snapshot arrives.
			local updated = table.clone(draft.editing)
			updated.parts = table.clone(draft.parts)
			draft.editing = updated
		else
			draft.parts = {}
			nameBox.Text = ""
		end
		refreshAll(true)
	else
		refreshAll(false)
	end
end

function Builder.init(gui: ScreenGui)
	win = Ui.window(gui, "Creature Builder", UDim2.new(0.9, 0, 0.84, 0))
	local c = win.content

	titleLabel = Ui.label({
		Text = "New Monster",
		TextColor3 = T.Muted,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -56, 0, -38),
		Size = UDim2.fromOffset(300, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = c,
	})

	-- Left: slots
	local slotCol = Ui.scroll({ Size = UDim2.new(0, 140, 1, -96), Parent = c })
	Ui.list(Enum.FillDirection.Vertical, 6).Parent = slotCol
	for i, s in ipairs(Config.Slots) do
		local b = create("TextButton", {
			Name = s.id,
			LayoutOrder = i,
			Size = UDim2.new(1, -8, 0, 46),
			BackgroundColor3 = T.Panel,
			TextColor3 = T.Text,
			Font = T.FontBold,
			TextSize = 14,
			TextWrapped = true,
			Selectable = true,
			Text = s.id,
			Parent = slotCol,
		}, { Ui.corner(8), Ui.stroke() })
		b.Activated:Connect(function()
			selectedSlot = s.id
			refreshAll(false)
		end)
		slotButtons[s.id] = b
	end

	-- Centre: preview + stats
	local centre = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(150, 0),
		Size = UDim2.new(1, -470, 1, -96),
		Parent = c,
	})
	view = Ui.viewport(centre, { Size = UDim2.new(1, 0, 1, -96) })
	Ui.label({
		Text = "drag to rotate • scroll to zoom",
		TextColor3 = T.Muted,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 1, -20),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = view.frame,
	})
	local statsBox = create("Frame", {
		BackgroundColor3 = T.Panel,
		Position = UDim2.new(0, 0, 1, -90),
		Size = UDim2.new(1, 0, 0, 90),
		Parent = centre,
	}, { Ui.corner(10), Ui.pad(8) })
	statsLabel = Ui.label({ Text = "", TextSize = 15, Size = UDim2.new(1, 0, 0, 56), Parent = statsBox })
	statusLabel = Ui.label({
		Text = "",
		TextSize = 14,
		Font = T.FontBold,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = statsBox,
	})

	-- Right: part picker
	partList = Ui.scroll({ Position = UDim2.new(1, -310, 0, 0), Size = UDim2.new(0, 310, 1, -96), Parent = c })
	Ui.list(Enum.FillDirection.Vertical, 6).Parent = partList

	-- Bottom bar
	local bottom = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 1, -88),
		Size = UDim2.new(1, 0, 0, 88),
		Parent = c,
	})
	nameBox = create("TextBox", {
		PlaceholderText = "Monster name",
		Text = "",
		ClearTextOnFocus = false,
		Font = T.Font,
		TextSize = 16,
		TextColor3 = T.Text,
		PlaceholderColor3 = T.Muted,
		BackgroundColor3 = T.Panel,
		Size = UDim2.new(0.3, 0, 0, 38),
		Parent = bottom,
	}, { Ui.corner(8), Ui.stroke() })
	nameBox:GetPropertyChangedSignal("Text"):Connect(function()
		if #nameBox.Text > Config.Economy.MaxNameLength then
			nameBox.Text = nameBox.Text:sub(1, Config.Economy.MaxNameLength)
		end
	end)
	buildBtn = Ui.button({
		Text = "BUILD",
		Position = UDim2.new(0.3, 8, 0, 0),
		Size = UDim2.new(0.2, 0, 0, 38),
		BackgroundColor3 = T.Money,
		Parent = bottom,
	}, submit)
	Ui.button({
		Text = "Auto-Fill",
		Position = UDim2.new(0.5, 16, 0, 0),
		Size = UDim2.new(0.14, 0, 0, 38),
		Parent = bottom,
	}, autoFill)
	Ui.button({
		Text = "Clear",
		Position = UDim2.new(0.64, 24, 0, 0),
		Size = UDim2.new(0.1, 0, 0, 38),
		BackgroundColor3 = T.Panel2,
		TextColor3 = T.Text,
		Parent = bottom,
	}, function()
		draft.parts = {}
		refreshAll(true)
	end)
	Ui.button({
		Text = "New",
		Position = UDim2.new(0.74, 32, 0, 0),
		Size = UDim2.new(0.1, 0, 0, 38),
		BackgroundColor3 = T.Panel2,
		TextColor3 = T.Text,
		Parent = bottom,
	}, function()
		Builder.open(nil)
	end)

	codeBox = create("TextBox", {
		PlaceholderText = "Blueprint code (BB1:...) — paste a friend's code and press Load",
		Text = "",
		ClearTextOnFocus = false,
		Font = T.Font,
		TextSize = 14,
		TextColor3 = T.Text,
		PlaceholderColor3 = T.Muted,
		BackgroundColor3 = T.Panel,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(0.6, 0, 0, 36),
		Parent = bottom,
	}, { Ui.corner(8), Ui.stroke(), Ui.pad(6) })
	Ui.button({
		Text = "Load Code",
		Position = UDim2.new(0.6, 8, 0, 46),
		Size = UDim2.new(0.15, 0, 0, 36),
		Parent = bottom,
	}, function()
		local parts = Stats.decodeBlueprint(codeBox.Text)
		if not parts then
			Ui.toast("Invalid blueprint code", T.Danger)
			return
		end
		draft.parts = parts
		refreshAll(true)
		Ui.toast("Blueprint loaded: you still need to own each part to build it", T.Accent)
	end)
	Ui.button({
		Text = "Save Blueprint",
		Position = UDim2.new(0.75, 16, 0, 46),
		Size = UDim2.new(0.25, -16, 0, 36),
		BackgroundColor3 = T.Warn,
		Parent = bottom,
	}, function()
		local result = State.invoke("SaveBlueprint", { parts = draft.parts, name = nameBox.Text })
		if result.ok then
			codeBox.Text = result.code
			Ui.toast("Blueprint saved. Share the code in the box!", T.Money)
		end
	end)

	State.Changed.Event:Connect(function(data)
		if draft.editing then
			-- Keep the edited record in sync (level ups from battles, or it was recycled).
			local fresh = data.monsters[draft.editing.id]
			if fresh then
				draft.editing = fresh
			else
				draft.editing = nil
			end
		end
		refreshAll(false)
	end)
end

-- monster: record to edit, or nil for a new monster
function Builder.open(monster)
	draft.editing = monster
	draft.parts = {}
	if monster then
		for k, v in pairs(monster.parts) do
			draft.parts[k] = v
		end
		nameBox.Text = monster.name
	else
		nameBox.Text = ""
	end
	selectedSlot = "Torso"
	win.frame.Visible = true
	Ui.pop(win.frame)
	refreshAll(true)
	if State.data and State.data.tutorial == Config.Tutorial.OpenBuilder then
		State.invoke("TutorialSeen", { step = Config.Tutorial.OpenBuilder })
	end
end

function Builder.window()
	return win
end

return Builder

-- Shop: parts, crates (odds shown), lab upgrades (income multiplier + containment pods).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.PartCatalog)
local Assembler = require(ReplicatedStorage.Shared.Assembler)
local Format = require(ReplicatedStorage.Shared.Format)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local T = Ui.Theme
local create = Ui.create

local Shop = {}
local win, body
local tab = "Parts"
local tabButtons = {}

local function clear()
	for _, c in ipairs(body:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function revealPart(partId: string)
	local p = Catalog.get(partId)
	if not p then
		return
	end
	local overlay = create("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Parent = win.frame,
	}, { Ui.corner(14) })
	local panel = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 320),
		BackgroundColor3 = T.Panel,
		ZIndex = 21,
		Parent = overlay,
	}, { Ui.corner(12), Ui.stroke(Ui.rarityColor(p.rarity), 4), Ui.pad(10) })
	local view = Ui.viewport(panel, { Size = UDim2.new(1, 0, 0, 180), ZIndex = 22 })
	-- Show the part on a tiny dummy torso so it reads in context.
	local parts = { Torso = p.slot == "Torso" and p.id or "torso_blob" }
	if p.slot ~= "Torso" then
		parts[p.slot] = p.id
		local slotDef = Config.SlotById[p.slot]
		if slotDef.requires == "Head" then
			parts.Head = "head_goo"
		elseif slotDef.requires == "Arms" then
			parts.Arms = "arms_little"
		end
	end
	view.setModel(Assembler.build(parts))
	Ui.label({
		Text = p.rarity:upper() .. "!",
		Font = T.FontBlack,
		TextSize = 24,
		TextColor3 = Ui.rarityColor(p.rarity),
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 186),
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 22,
		Parent = panel,
	})
	Ui.label({
		Text = p.name .. " (" .. p.slot .. ")",
		Font = T.FontBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 214),
		ZIndex = 22,
		Parent = panel,
	})
	Ui.button({
		Text = "Nice!",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		ZIndex = 22,
		Parent = panel,
	}, function()
		overlay:Destroy()
	end)
	Ui.pop(panel)
end

local function row(order, title, sub, color, priceText, canBuy, onBuy)
	local f = create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -10, 0, 58),
		BackgroundColor3 = T.Panel,
		Parent = body,
	}, { Ui.corner(8), Ui.stroke(color, 1.5), Ui.pad(8) })
	Ui.label({ Text = title, Font = T.FontBold, TextColor3 = color, Size = UDim2.new(1, -150, 0, 20), Parent = f })
	Ui.label({
		Text = sub,
		TextSize = 13,
		TextColor3 = T.Muted,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, -150, 0, 22),
		Parent = f,
	})
	Ui.button({
		Text = priceText,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(140, 38),
		BackgroundColor3 = canBuy and T.Money or T.Panel2,
		TextColor3 = canBuy and Color3.fromRGB(15, 18, 25) or T.Text,
		Parent = f,
	}, onBuy)
end

local function render()
	if not win.frame.Visible or not State.data then
		return
	end
	clear()
	for name, b in pairs(tabButtons) do
		b.BackgroundColor3 = name == tab and T.Accent or T.Panel2
	end
	local money = State.money()
	if tab == "Parts" then
		local list = {}
		for _, p in pairs(Catalog.Parts) do
			table.insert(list, p)
		end
		table.sort(list, function(a, b)
			local ra, rb = Config.RarityIndex[a.rarity], Config.RarityIndex[b.rarity]
			if ra ~= rb then
				return ra < rb
			end
			if a.slot ~= b.slot then
				return a.slot < b.slot
			end
			return a.name < b.name
		end)
		for i, p in ipairs(list) do
			local inc = (p.stats.income or 0) * (Config.RarityIncomeMult[p.rarity] or 1)
			local sub = ("%s • %s • owned %d%s"):format(
				p.slot,
				Format.rate(inc),
				State.owned(p.id),
				p.ability and (" • ⚡ " .. Config.Abilities[p.ability].name) or ""
			)
			if p.shop then
				row(i, p.name .. " [" .. p.rarity .. "]", sub, Ui.rarityColor(p.rarity), Format.money(p.cost), money >= p.cost, function()
					local r = State.invoke("BuyPart", { partId = p.id })
					if r.ok then
						Ui.toast("Bought " .. p.name, T.Money)
					end
				end)
			else
				row(
					i,
					p.name .. " [" .. p.rarity .. "]",
					sub .. " • crates & arenas only",
					Ui.rarityColor(p.rarity),
					"🔒 Rare drop",
					false,
					function()
						Ui.toast(p.name .. " drops from crates and high arenas", T.Accent)
					end
				)
			end
		end
	elseif tab == "Crates" then
		local i = 0
		for id, crate in pairs(Config.Crates) do
			i += 1
			local total, bits = 0, {}
			for _, r in ipairs(Config.Rarities) do
				total += crate.weights[r] or 0
			end
			for _, r in ipairs(Config.Rarities) do
				local w = crate.weights[r]
				if w then
					table.insert(bits, ("%s %.0f%%"):format(r, w / total * 100))
				end
			end
			row(i, crate.name, table.concat(bits, " • "), T.Warn, Format.money(crate.cost), money >= crate.cost, function()
				local r = State.invoke("BuyCrate", { crateId = id })
				if r.ok then
					revealPart(r.partId)
				end
			end)
		end
	elseif tab == "Lab" then
		local lab = State.data.lab
		local inc, nextInc = Config.LabIncomeTiers[lab.incomeTier], Config.LabIncomeTiers[lab.incomeTier + 1]
		row(
			1,
			("Income Amplifier  (tier %d/%d)"):format(lab.incomeTier, #Config.LabIncomeTiers),
			nextInc and ("x%.2f → x%.2f on ALL monster income"):format(inc.mult, nextInc.mult) or ("x%.2f (max)"):format(inc.mult),
			T.Money,
			nextInc and Format.money(nextInc.cost) or "MAX",
			nextInc ~= nil and money >= nextInc.cost,
			function()
				if nextInc and State.invoke("UpgradeLab", { track = "income" }).ok then
					Ui.toast("Income Amplifier upgraded!", T.Money)
				end
			end
		)
		local pod, nextPod = Config.PodTiers[lab.podTier], Config.PodTiers[lab.podTier + 1]
		row(
			2,
			("Containment Pods  (tier %d/%d)"):format(lab.podTier, #Config.PodTiers),
			nextPod and ("%d → %d monster slots"):format(pod.slots, nextPod.slots) or ("%d slots (max)"):format(pod.slots),
			T.Accent,
			nextPod and Format.money(nextPod.cost) or "MAX",
			nextPod ~= nil and money >= nextPod.cost,
			function()
				if nextPod and State.invoke("UpgradeLab", { track = "pods" }).ok then
					Ui.toast("More containment pods!", T.Money)
				end
			end
		)
	end
end

function Shop.init(gui: ScreenGui)
	win = Ui.window(gui, "Lab Shop", UDim2.new(0.7, 0, 0.78, 0))
	local tabs = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = win.content,
	}, { Ui.list(Enum.FillDirection.Horizontal, 8) })
	for i, name in ipairs({ "Parts", "Crates", "Lab" }) do
		tabButtons[name] = Ui.button({ Text = name, LayoutOrder = i, Size = UDim2.fromOffset(110, 34), Parent = tabs }, function()
			tab = name
			render()
		end)
	end
	body = Ui.scroll({ Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), Parent = win.content })
	Ui.list(Enum.FillDirection.Vertical, 6).Parent = body
	State.Changed.Event:Connect(render)
end

function Shop.open(which: string?)
	if which then
		tab = which
	end
	win.frame.Visible = true
	Ui.pop(win.frame)
	render()
end

function Shop.window()
	return win
end

return Shop

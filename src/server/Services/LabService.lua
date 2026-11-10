-- Generates the world (hub + lab plots) in code so the place needs no hand-built assets,
-- assigns each player a plot, and shows their top monsters on pedestals.
-- Pedestals are cosmetic only: undisplayed monsters keep earning (see IncomeService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Stats = require(ReplicatedStorage.Shared.Stats)
local Assembler = require(ReplicatedStorage.Shared.Assembler)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)

local LabService = {}

local PLOT_COUNT = 8
local PLOT_RADIUS = 120
local PEDESTALS = 6

local world: Folder
local plots = {} -- [i] = { model, owner, spawn, pedestals = {}, displays = Folder, sign = TextLabel }
local playerPlot = {} :: { [Player]: number }

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function prompt(parent: BasePart, action: string, object: string, ui: string)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 14
	pp.RequiresLineOfSight = false
	pp:SetAttribute("OpenUI", ui)
	pp.Parent = parent
	return pp
end

local function label(parent: Instance, text: string, size: UDim2, offset: Vector3)
	local bb = Instance.new("BillboardGui")
	bb.Size = size
	bb.StudsOffset = offset
	bb.AlwaysOnTop = false
	bb.MaxDistance = 120
	bb.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.4
	t.Text = text
	t.Parent = bb
	return t
end

local function buildHub()
	local floor = part({
		Name = "Floor",
		Size = Vector3.new(420, 2, 420),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(32, 36, 48),
		Material = Enum.Material.SmoothPlastic,
	})
	floor.Parent = world

	-- Glowing grid strips for a sci-fi lab look
	for i = -4, 4 do
		local strip = part({
			Name = "Grid",
			Size = Vector3.new(420, 0.05, 0.4),
			Position = Vector3.new(0, 0.03, i * 45),
			Color = Color3.fromRGB(40, 180, 220),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Transparency = 0.6,
		})
		strip.Parent = world
		local strip2 = strip:Clone()
		strip2.Size = Vector3.new(0.4, 0.05, 420)
		strip2.Position = Vector3.new(i * 45, 0.03, 0)
		strip2.Parent = world
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.5, 30)
	spawn.Color = Color3.fromRGB(60, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = world

	-- Arena dome in the centre
	local arenaBase = part({
		Name = "ArenaPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 36, 36),
		CFrame = CFrame.new(0, 0.5, -10) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(150, 50, 60),
		Material = Enum.Material.DiamondPlate,
	})
	arenaBase.Parent = world
	local arenaTerminal = part({
		Name = "ArenaTerminal",
		Size = Vector3.new(4, 6, 2),
		Position = Vector3.new(0, 4, 8),
		Color = Color3.fromRGB(230, 70, 80),
		Material = Enum.Material.Neon,
	})
	arenaTerminal.Parent = world
	prompt(arenaTerminal, "Enter Arena", "Battle Terminal", "Arena")
	label(arenaTerminal, "⚔ ARENA", UDim2.fromOffset(200, 50), Vector3.new(0, 5, 0))

	local shop = part({
		Name = "PartShop",
		Size = Vector3.new(8, 5, 4),
		Position = Vector3.new(26, 2.5, 30),
		Color = Color3.fromRGB(255, 190, 60),
		Material = Enum.Material.SmoothPlastic,
	})
	shop.Parent = world
	prompt(shop, "Open Shop", "Part Shop", "Shop")
	label(shop, "🛒 PARTS & CRATES", UDim2.fromOffset(240, 50), Vector3.new(0, 5, 0))

	Lighting.ClockTime = 20
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(90, 95, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(90, 95, 120)
end

local function buildPlot(i: number)
	local angle = (i - 1) / PLOT_COUNT * math.pi * 2
	local pos = Vector3.new(math.sin(angle) * PLOT_RADIUS, 0, math.cos(angle) * PLOT_RADIUS)
	-- Face the hub: plot "front" (-Z) points toward the origin.
	local origin = CFrame.lookAt(pos, Vector3.new(0, 0, 0))

	local model = Instance.new("Model")
	model.Name = "Plot" .. i

	local base = part({
		Name = "Base",
		Size = Vector3.new(64, 1, 46),
		CFrame = origin * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(48, 54, 70),
		Material = Enum.Material.Metal,
	})
	base.Parent = model
	model.PrimaryPart = base

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.CFrame = origin * CFrame.new(0, 1.2, -16)
	spawn.Color = Color3.fromRGB(80, 220, 160)
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = false -- only used through Player.RespawnLocation
	spawn.Enabled = true
	spawn.Duration = 0
	spawn.Parent = model

	local station = part({
		Name = "BuildStation",
		Size = Vector3.new(8, 4, 3),
		CFrame = origin * CFrame.new(-18, 3, -12),
		Color = Color3.fromRGB(60, 200, 255),
		Material = Enum.Material.Neon,
	})
	station.Parent = model
	prompt(station, "Open Builder", "Creature Builder", "Builder")
	label(station, "🧬 BUILDER", UDim2.fromOffset(200, 50), Vector3.new(0, 4, 0))

	local pc = part({
		Name = "CollectionTerminal",
		Size = Vector3.new(6, 4, 3),
		CFrame = origin * CFrame.new(18, 3, -12),
		Color = Color3.fromRGB(170, 100, 255),
		Material = Enum.Material.Neon,
	})
	pc.Parent = model
	prompt(pc, "My Monsters", "Containment Pods", "Collection")
	label(pc, "📦 MONSTERS", UDim2.fromOffset(200, 50), Vector3.new(0, 4, 0))

	local signPart = part({
		Name = "Sign",
		Size = Vector3.new(30, 8, 1),
		CFrame = origin * CFrame.new(0, 9, 21),
		Color = Color3.fromRGB(25, 28, 38),
		Material = Enum.Material.SmoothPlastic,
	})
	signPart.Parent = model
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 30
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.Parent = signPart
	local sign = Instance.new("TextLabel")
	sign.Size = UDim2.fromScale(1, 1)
	sign.BackgroundTransparency = 1
	sign.TextScaled = true
	sign.Font = Enum.Font.GothamBlack
	sign.TextColor3 = Color3.fromRGB(120, 255, 180)
	sign.Text = "Vacant Lab"
	sign.Parent = sg

	local pedestals = {}
	for p = 1, PEDESTALS do
		local col = (p - 1) % 3
		local row = math.floor((p - 1) / 3)
		local ped = part({
			Name = "Pedestal" .. p,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.5, 9, 9),
			CFrame = origin * CFrame.new((col - 1) * 16, 1.75, row * 12 + 2) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(70, 80, 100),
			Material = Enum.Material.Metal,
		})
		ped.Parent = model
		-- Monsters face -Z, i.e. toward the plot's spawn and the hub.
		pedestals[p] = origin * CFrame.new((col - 1) * 16, 2.5, row * 12 + 2)
	end

	local displays = Instance.new("Folder")
	displays.Name = "Displays"
	displays.Parent = model

	model.Parent = world
	plots[i] = { model = model, owner = nil, spawn = spawn, pedestals = pedestals, displays = displays, sign = sign }
end

function LabService.assign(player: Player)
	for i, plot in ipairs(plots) do
		if not plot.owner then
			plot.owner = player
			playerPlot[player] = i
			player.RespawnLocation = plot.spawn
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			return i
		end
	end
	return nil -- server full of plots: player spawns at hub (server MaxPlayers should be <= PLOT_COUNT)
end

function LabService.release(player: Player)
	local i = playerPlot[player]
	if not i then
		return
	end
	local plot = plots[i]
	plot.owner = nil
	plot.displays:ClearAllChildren()
	plot.sign.Text = "Vacant Lab"
	plot.model:SetAttribute("OwnerUserId", nil)
	playerPlot[player] = nil
end

function LabService.refreshDisplays(player: Player)
	local i = playerPlot[player]
	local data = DataService.get(player)
	if not i or not data then
		return
	end
	local plot = plots[i]
	plot.displays:ClearAllChildren()

	local list = {}
	for _, m in pairs(data.monsters) do
		table.insert(list, m)
	end
	table.sort(list, function(a, b)
		local ia, ib = Stats.monsterIncome(a), Stats.monsterIncome(b)
		if ia == ib then
			return a.created < b.created
		end
		return ia > ib
	end)

	local mult = Stats.globalMult(data)
	for p = 1, math.min(#list, PEDESTALS) do
		local m = list[p]
		local model = Assembler.build(m.parts, { name = m.name })
		model:PivotTo(plot.pedestals[p])
		local _, size = model:GetBoundingBox()
		label(
			model.PrimaryPart,
			("%s  Lv%d\n%s"):format(m.name, m.level, Format.rate(Stats.monsterIncome(m) * mult)),
			UDim2.fromOffset(180, 50),
			Vector3.new(0, size.Y / 2 + 2, 0)
		)
		model.Parent = plot.displays
	end
	if #list > PEDESTALS then
		local extra = label(
			plot.model.PrimaryPart,
			("+%d more monsters earning in storage"):format(#list - PEDESTALS),
			UDim2.fromOffset(300, 30),
			Vector3.new(0, 3, 22)
		)
		extra.Parent.Parent = plot.displays -- so it is cleared with the displays
		extra.Parent.Adornee = plot.model.PrimaryPart
	end
end

function LabService.init()
	world = Instance.new("Folder")
	world.Name = "LabWorld"
	world.Parent = workspace
	buildHub()
	for i = 1, PLOT_COUNT do
		buildPlot(i)
	end

	-- Plot signs show live income.
	task.spawn(function()
		while true do
			for _, plot in ipairs(plots) do
				local owner = plot.owner
				if owner and owner.Parent then
					plot.sign.Text = ("%s's Lab\n%s"):format(owner.DisplayName, Format.rate(owner:GetAttribute("IncomePerSec") or 0))
				end
			end
			task.wait(2)
		end
	end)

	Players.PlayerRemoving:Connect(LabService.release)
end

return LabService

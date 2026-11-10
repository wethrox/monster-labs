-- Builds a monster Model from a {slot -> partId} map using a standardised socket rig.
-- Every socket position is derived from the torso size and the attached part's size,
-- so any combination of parts assembles without per-combination code.
--
-- Convention: model faces -Z (Roblox LookVector). Torso is the PrimaryPart.
-- After assembly the model is shifted so its lowest point sits at local Y = 0.

local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.PartCatalog)

local Assembler = {}

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

local function makePart(def, name: string)
	local vis = def.visual
	local p
	if vis.shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
		if vis.shape == "Ball" then
			p.Shape = Enum.PartType.Ball
		elseif vis.shape == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder
		end
	end
	p.Name = name
	p.Size = v3(vis.size)
	p.Color = Color3.fromRGB(vis.color[1], vis.color[2], vis.color[3])
	local okMat, mat = pcall(function()
		return Enum.Material[vis.material]
	end)
	p.Material = okMat and mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Anchored = true
	p.CastShadow = true
	p:SetAttribute("PartId", def.id)
	return p
end

-- Socket functions: (torsoSize, partSize, ctx) -> list of CFrames (one per piece; two for paired slots)
-- ctx holds already-placed reference CFrames/sizes (head, arms) for dependent slots.
Assembler.Sockets = {
	Torso = function()
		return { CFrame.new() }
	end,
	Head = function(T, S, ctx)
		-- (A WedgePart's thin edge is already at its front/-Z, so wedge heads read as snouts.)
		local cf = CFrame.new(0, T.Y / 2 + S.Y / 2 * 0.8, -T.Z * 0.15)
		ctx.head = { cf = cf, size = S }
		return { cf }
	end,
	Legs = function(T, S)
		local y = -T.Y / 2 - S.Y / 2 + 0.15
		local x = math.max(T.X * 0.3, S.X / 2 + 0.1)
		return { CFrame.new(-x, y, 0), CFrame.new(x, y, 0) }
	end,
	Arms = function(T, S, ctx)
		local x = T.X / 2 + S.X / 2 - 0.1
		local y = T.Y * 0.1 - S.Y * 0.2
		local tilt = math.rad(12)
		local l = CFrame.new(-x, y, -0.2) * CFrame.Angles(0, 0, -tilt)
		local r = CFrame.new(x, y, -0.2) * CFrame.Angles(0, 0, tilt)
		ctx.arms = { l = l, r = r, size = S }
		return { l, r }
	end,
	Claws = function(_, S, ctx)
		local a = ctx.arms
		if not a then
			return {}
		end
		local off = CFrame.new(0, -a.size.Y / 2 - S.Y / 2 + 0.1, -0.15)
		return { a.l * off, a.r * off }
	end,
	Horns = function(_, S, ctx)
		local h = ctx.head
		if not h then
			return {}
		end
		local x = h.size.X * 0.3
		local y = h.size.Y / 2 + S.Y / 2 - 0.15
		local tilt = math.rad(15)
		return {
			h.cf * CFrame.new(-x, y, 0) * CFrame.Angles(0, 0, tilt),
			h.cf * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, -tilt),
		}
	end,
	Wings = function(T, S)
		local x = T.X / 2 + S.X / 2 - 0.3
		local y = T.Y * 0.25
		local z = T.Z * 0.3
		local tilt = math.rad(20)
		return {
			CFrame.new(-x, y, z) * CFrame.Angles(0, math.rad(-25), tilt),
			CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(25), -tilt),
		}
	end,
	Tail = function(T, S)
		return { CFrame.new(0, -T.Y * 0.15, T.Z / 2 + S.Z / 2 - 0.2) * CFrame.Angles(math.rad(-10), 0, 0) }
	end,
	Armor = function(T, S)
		return { CFrame.new(0, 0, -T.Z / 2 - S.Z / 2 + 0.05) }
	end,
	Core = function(T, S)
		return { CFrame.new(0, T.Y * 0.1, -T.Z / 2 - S.Z * 0.15) }
	end,
}

-- Build a model. options.anchored (default true); options.name.
function Assembler.build(parts: { [string]: string }, options)
	options = options or {}
	local model = Instance.new("Model")
	model.Name = options.name or "Monster"

	local torsoDef = parts.Torso and Catalog.get(parts.Torso)
	if not torsoDef then
		-- Fallback so a broken record still renders something instead of erroring.
		torsoDef = Catalog.get("torso_blob")
	end
	local T = v3(torsoDef.visual.size)
	local torso = makePart(torsoDef, "Torso")
	torso.Parent = model
	model.PrimaryPart = torso

	local ctx = {}
	local placed = { torso }
	for _, slot in ipairs(Config.Slots) do
		local id = parts[slot.id]
		local def = id and Catalog.get(id)
		if slot.id ~= "Torso" and def then
			local S = v3(def.visual.size)
			local fn = Assembler.Sockets[slot.id]
			local cfs = fn and fn(T, S, ctx) or {}
			for i, cf in ipairs(cfs) do
				local p = makePart(def, slot.id .. (#cfs > 1 and tostring(i) or ""))
				p.CFrame = cf
				p.Parent = model
				table.insert(placed, p)
			end
		end
	end

	-- Ground snap: lowest point -> y = 0
	local minY = math.huge
	for _, p in ipairs(placed) do
		local cf, size = p.CFrame, p.Size
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local corner = cf:PointToWorldSpace(Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2))
					minY = math.min(minY, corner.Y)
				end
			end
		end
	end
	local shift = CFrame.new(0, -minY, 0)
	for _, p in ipairs(placed) do
		p.CFrame = shift * p.CFrame
	end

	if options.anchored == false then
		for _, p in ipairs(placed) do
			if p ~= torso then
				local w = Instance.new("WeldConstraint")
				w.Part0 = torso
				w.Part1 = p
				w.Parent = p
			end
			p.Anchored = false
		end
	end

	-- A pivot at the feet makes placing on pedestals trivial.
	model.WorldPivot = CFrame.new(0, 0, 0)
	return model
end

return Assembler

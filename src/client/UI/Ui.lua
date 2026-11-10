-- UI construction helpers + theme. Everything is built in code (no Studio GUI assets needed).

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Ui = {}

Ui.Theme = {
	Bg = Color3.fromRGB(18, 20, 28),
	Panel = Color3.fromRGB(28, 32, 44),
	Panel2 = Color3.fromRGB(38, 43, 58),
	Stroke = Color3.fromRGB(70, 80, 105),
	Text = Color3.fromRGB(235, 240, 255),
	Muted = Color3.fromRGB(150, 160, 185),
	Accent = Color3.fromRGB(60, 200, 255),
	Money = Color3.fromRGB(110, 255, 140),
	Danger = Color3.fromRGB(255, 85, 95),
	Warn = Color3.fromRGB(255, 200, 70),
	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
	FontBlack = Enum.Font.GothamBlack,
}
local T = Ui.Theme

function Ui.rarityColor(rarity: string): Color3
	local c = Config.RarityColor[rarity] or { 255, 255, 255 }
	return Color3.fromRGB(c[1], c[2], c[3])
end

function Ui.create(className: string, props, children)
	local inst = Instance.new(className)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local create = Ui.create

function Ui.corner(r: number?)
	return create("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

function Ui.stroke(color: Color3?, thickness: number?)
	return create("UIStroke", {
		Color = color or T.Stroke,
		Thickness = thickness or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.pad(px: number)
	local u = UDim.new(0, px)
	return create("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Ui.list(dir, gap: number?, align)
	return create("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

function Ui.label(props)
	local p = {
		BackgroundTransparency = 1,
		Font = T.Font,
		TextColor3 = T.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 20),
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	return create("TextLabel", p)
end

-- Pop animation on press for satisfying feedback.
local function pressFx(btn: GuiButton)
	local scale = create("UIScale", { Parent = btn })
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
end

function Ui.button(props, onClick)
	local p = {
		AutoButtonColor = true,
		BackgroundColor3 = T.Accent,
		Font = T.FontBold,
		TextColor3 = Color3.fromRGB(15, 18, 25),
		TextSize = 16,
		Size = UDim2.new(0, 120, 0, 38),
		Selectable = true,
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	local btn = create("TextButton", p, { Ui.corner(8) })
	pressFx(btn)
	if onClick then
		btn.Activated:Connect(onClick)
	end
	return btn
end

-- Modal window: returns { frame, content, close() }
function Ui.window(parent: Instance, title: string, size: UDim2, onClose)
	local frame = create("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = size,
		BackgroundColor3 = T.Bg,
		Visible = false,
		Parent = parent,
	}, {
		Ui.corner(14),
		Ui.stroke(T.Stroke, 2),
		create("UISizeConstraint", { MaxSize = Vector2.new(1100, 720), MinSize = Vector2.new(300, 260) }),
	})
	Ui.label({
		Text = title,
		Font = T.FontBlack,
		TextSize = 22,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -80, 0, 30),
		Parent = frame,
	})
	local closeBtn = Ui.button({
		Text = "✕",
		Size = UDim2.fromOffset(36, 36),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		BackgroundColor3 = T.Danger,
		TextColor3 = T.Text,
		Parent = frame,
	})
	local content = create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 50),
		Size = UDim2.new(1, -24, 1, -62),
		Parent = frame,
	})
	local win = { frame = frame, content = content }
	function win.close()
		frame.Visible = false
		if onClose then
			onClose()
		end
	end
	closeBtn.Activated:Connect(win.close)
	return win
end

function Ui.scroll(props)
	local p = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.Stroke,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	return create("ScrollingFrame", p)
end

-- 3D preview in a ViewportFrame with drag-to-rotate and zoom.
function Ui.viewport(parent: Instance, props)
	local p = {
		BackgroundColor3 = T.Panel,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(170, 170, 190),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -2, -1),
		Parent = parent,
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	local vpf = create("ViewportFrame", p, { Ui.corner(10) })
	local world = create("WorldModel", { Parent = vpf })
	local cam = create("Camera", { FieldOfView = 40, Parent = vpf })
	vpf.CurrentCamera = cam

	local view = { frame = vpf, world = world, camera = cam, yaw = math.rad(200), pitch = math.rad(-12), zoom = 1, model = nil }

	function view.update()
		local m = view.model
		if not m then
			return
		end
		local cf, size = m:GetBoundingBox()
		local radius = size.Magnitude / 2
		local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) * 1.05 * view.zoom
		local focus = cf.Position
		local rot = CFrame.Angles(0, view.yaw, 0) * CFrame.Angles(view.pitch, 0, 0)
		cam.CFrame = CFrame.new(focus) * rot * CFrame.new(0, 0, dist)
	end

	function view.setModel(model: Model?)
		if view.model then
			view.model:Destroy()
		end
		view.model = model
		if model then
			model.Parent = world
			view.update()
		end
	end

	-- Drag to rotate (mouse or touch); wheel to zoom.
	local dragging, last = false, nil
	vpf.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, last = true, input.Position
		end
	end)
	vpf.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - last
			last = input.Position
			view.yaw -= delta.X * 0.01
			view.pitch = math.clamp(view.pitch - delta.Y * 0.01, math.rad(-60), math.rad(30))
			view.update()
		end
	end)
	vpf.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			view.zoom = math.clamp(view.zoom - input.Position.Z * 0.1, 0.5, 2)
			view.update()
		end
	end)
	return view
end

-- Toasts (bottom-right). Set by Main: Ui.toastRoot
function Ui.toast(text: string, color: Color3?)
	local root = Ui.toastRoot
	if not root then
		return
	end
	local t = create("Frame", {
		BackgroundColor3 = T.Panel,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 0.05,
		Parent = root,
	}, { Ui.corner(8), Ui.stroke(color or T.Accent, 2) })
	local l = Ui.label({
		Text = text,
		TextColor3 = color or T.Text,
		Font = T.FontBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		TextScaled = true,
		Parent = t,
	})
	create("UITextSizeConstraint", { MaxTextSize = 18, Parent = l })
	task.delay(3, function()
		local tw = TweenService:Create(t, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		tw:Play()
		tw.Completed:Wait()
		t:Destroy()
	end)
end

function Ui.pop(inst: GuiObject)
	local s = inst:FindFirstChildOfClass("UIScale") or create("UIScale", { Parent = inst })
	s.Scale = 0.85
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

return Ui

-- First-three-minutes onboarding banner. Steps are advanced by the server
-- (data.tutorial), so progress survives rejoining.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local T = Ui.Theme
local Steps = Config.Tutorial

local TEXT = {
	[Steps.OpenBuilder] = { "Welcome to your lab! Open the 🧬 Build menu (or the blue station) to create your first monster.", "Builder" },
	[Steps.BuildFirst] = { "Fill every REQUIRED slot (or press Auto-Fill), name it, then press BUILD.", "Builder" },
	[Steps.FirstBattle] = {
		"Your monster earns money every second, forever! Now fight in the ⚔ Arena. It keeps earning while it fights.",
		"Arena",
	},
	[Steps.FirstUpgrade] = { "Spend your rewards: upgrade your monster in 📦 Monsters for more income AND power.", "Collection" },
}

local Tutorial = {}

function Tutorial.init(gui: ScreenGui, hudButtons)
	local banner = Ui.create("Frame", {
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.new(0.6, 0, 0, 48),
		BackgroundColor3 = T.Panel,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(10), Ui.stroke(T.Warn, 2), Ui.pad(8) })
	local label = Ui.label({
		Text = "",
		Font = T.FontBold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = banner,
	})
	Ui.create("UITextSizeConstraint", { MaxTextSize = 18, Parent = label })

	local pulseTween
	local lastStep
	local function update(data)
		local step = data.tutorial
		if step == lastStep then
			return
		end
		local wasActive = lastStep ~= nil and lastStep < Steps.Done
		lastStep = step
		if pulseTween then
			pulseTween:Cancel()
			pulseTween = nil
		end
		for _, b in pairs(hudButtons) do
			local s = b:FindFirstChild("TutorialGlow")
			if s then
				s:Destroy()
			end
		end
		local info = TEXT[step]
		if not info then
			banner.Visible = false
			if wasActive and step >= Steps.Done then
				Ui.toast("Tutorial complete! Crates in the 🛒 Shop hold Epic & Legendary parts.", T.Warn)
			end
			return
		end
		banner.Visible = true
		label.Text = info[1]
		Ui.pop(banner)
		local target = hudButtons[info[2]]
		if target then
			local glow = Ui.stroke(T.Warn, 3)
			glow.Name = "TutorialGlow"
			glow.Parent = target
			pulseTween = TweenService:Create(
				glow,
				TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Thickness = 6, Transparency = 0.5 }
			)
			pulseTween:Play()
		end
	end
	State.Changed.Event:Connect(update)
	if State.data then
		update(State.data)
	end
end

return Tutorial

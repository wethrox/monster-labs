-- Main HUD: rolling money counter, income/sec, navigation rail.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local T = Ui.Theme
local create = Ui.create
local player = Players.LocalPlayer

local Hud = {}

function Hud.init(gui: ScreenGui, router)
	local bar = create("Frame", {
		Name = "MoneyBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(380, 64),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, { Ui.corner(14), Ui.stroke(T.Money, 2) })

	local moneyLabel = Ui.label({
		Name = "Money",
		Text = "$0",
		Font = T.FontBlack,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 4),
		Parent = bar,
	})
	local incomeLabel = Ui.label({
		Name = "Income",
		Text = "+$0/s",
		Font = T.FontBold,
		TextSize = 18,
		TextColor3 = T.Money,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 38),
		Parent = bar,
	})

	RunService.RenderStepped:Connect(function()
		moneyLabel.Text = Format.money(State.displayMoney())
	end)

	local lastIncome = State.income()
	local function onIncome()
		local inc = State.income()
		incomeLabel.Text = Format.rate(inc) .. "  (all monsters, always)"
		if inc > lastIncome + 1e-6 then
			-- floating "+$X/s" gain
			local gain = Ui.label({
				Text = Format.rate(inc - lastIncome) .. "!",
				Font = T.FontBlack,
				TextSize = 22,
				TextColor3 = T.Money,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 1, 2),
				Size = UDim2.fromOffset(200, 26),
				Parent = bar,
			})
			TweenService:Create(gain, TweenInfo.new(1.4), { Position = UDim2.new(0.5, 0, 1, 40), TextTransparency = 1 }):Play()
			task.delay(1.5, function()
				gain:Destroy()
			end)
			Ui.pop(bar)
		end
		lastIncome = inc
	end
	player:GetAttributeChangedSignal("IncomePerSec"):Connect(onIncome)
	onIncome()

	-- Navigation rail
	local rail = create("Frame", {
		Name = "Rail",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(120, 4 * 52),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Ui.list(Enum.FillDirection.Vertical, 8) })

	local buttons = {}
	local defs = {
		{ "Builder", "🧬 Build", T.Accent },
		{ "Collection", "📦 Monsters", Color3.fromRGB(170, 120, 255) },
		{ "Shop", "🛒 Shop", T.Warn },
		{ "Arena", "⚔ Arena", T.Danger },
	}
	for i, d in ipairs(defs) do
		buttons[d[1]] = Ui.button({
			Name = d[1],
			Text = d[2],
			LayoutOrder = i,
			Size = UDim2.fromOffset(120, 44),
			BackgroundColor3 = d[3],
			Parent = rail,
		}, function()
			router.toggle(d[1])
		end)
	end
	Hud.buttons = buttons
	Hud.bar = bar
end

return Hud

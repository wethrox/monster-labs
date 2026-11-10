-- Beast Builder Lab client bootstrap: builds the UI, routes windows and world prompts,
-- shows notifications (incl. the offline "welcome back" summary).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Config = require(ReplicatedStorage.Shared.Config)
local UI = script.Parent:WaitForChild("UI")
local Ui = require(UI.Ui)
local State = require(UI.State)
local Hud = require(UI.Hud)
local Builder = require(UI.Builder)
local Collection = require(UI.Collection)
local Shop = require(UI.Shop)
local Arena = require(UI.Arena)
local Tutorial = require(UI.Tutorial)

local T = Ui.Theme
local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local gui = Ui.create("ScreenGui", {
	Name = "BeastBuilderLab",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

Ui.toastRoot = Ui.create("Frame", {
	Name = "Toasts",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -12),
	Size = UDim2.fromOffset(360, 300),
	BackgroundTransparency = 1,
	ZIndex = 50,
	Parent = gui,
}, {
	Ui.create("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
State.onError = function(msg)
	Ui.toast(msg, T.Danger)
end

-- Router: one window open at a time.
local windows = {
	Builder = {
		mod = Builder,
		open = function()
			Builder.open(nil)
		end,
	},
	Collection = { mod = Collection, open = Collection.open },
	Shop = {
		mod = Shop,
		open = function()
			Shop.open()
		end,
	},
	Arena = { mod = Arena, open = Arena.open },
}
local router = {}
function router.closeAll()
	for _, w in pairs(windows) do
		local win = w.mod.window()
		if win and win.frame.Visible then
			win.frame.Visible = false
		end
	end
end
function router.toggle(name: string)
	if Arena.inBattle() then
		return
	end
	local w = windows[name]
	local isOpen = w.mod.window().frame.Visible
	router.closeAll()
	if not isOpen then
		w.open()
	end
end
function router.openBuilder(monster)
	router.closeAll()
	Builder.open(monster)
end

Hud.init(gui, router)
Builder.init(gui)
Collection.init(gui, router)
Shop.init(gui)
Arena.init(gui)
Tutorial.init(gui, Hud.buttons)

-- World prompts (build station, collection terminal, arena terminal, shop)
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who ~= player then
		return
	end
	local ui = prompt:GetAttribute("OpenUI")
	if ui and windows[ui] then
		router.toggle(ui)
	end
end)

-- Notifications
local function showOffline(summary)
	local overlay = Ui.create("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
		Parent = gui,
	})
	local panel = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 250),
		BackgroundColor3 = T.Bg,
		ZIndex = 61,
		Parent = overlay,
	}, { Ui.corner(14), Ui.stroke(T.Money, 3), Ui.pad(14) })
	Ui.label({
		Text = "Welcome back, scientist!",
		Font = T.FontBlack,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		ZIndex = 62,
		Parent = panel,
	})
	Ui.label({
		Text = ("You were away %s.%s\nYour monsters earned at %s (%d%% offline rate).\n"):format(
			Format.duration(summary.away),
			summary.capped and ("\n(Offline earnings cap at " .. Format.duration(summary.credited) .. ".)") or "",
			Format.rate(summary.rate),
			math.floor(Config.Economy.OfflineRate * 100)
		),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 80),
		ZIndex = 62,
		Parent = panel,
	})
	Ui.label({
		Text = "+" .. Format.money(summary.payout),
		Font = T.FontBlack,
		TextSize = 40,
		TextColor3 = T.Money,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 0, 48),
		ZIndex = 62,
		Parent = panel,
	})
	Ui.button({
		Text = "Collect!",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(160, 42),
		BackgroundColor3 = T.Money,
		ZIndex = 62,
		Parent = panel,
	}, function()
		-- Money was already credited on the server at load; this just dismisses.
		overlay:Destroy()
	end)
	Ui.pop(panel)
end

Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(kind, payload)
	if kind == "offline" and type(payload) == "table" then
		showOffline(payload)
	elseif kind == "toast" and type(payload) == "string" then
		Ui.toast(payload)
	end
end)

-- Initial state (retry while the server is still loading our profile)
task.spawn(function()
	for _ = 1, 30 do
		if State.data then
			return
		end
		local r = Remotes.Action:InvokeServer("GetState")
		if type(r) == "table" and r.ok and r.state then
			if not State.data then
				State.set(r.state)
			end
			return
		end
		task.wait(1)
	end
end)

-- Beast Builder Lab server bootstrap.

local Players = game:GetService("Players")

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local IncomeService = require(Services.IncomeService)
local MonsterService = require(Services.MonsterService)
local ShopService = require(Services.ShopService)
local BattleService = require(Services.BattleService)
local LabService = require(Services.LabService)
local Remotes = require(Services.Remotes)

Players.CharacterAutoLoads = false

Remotes.init()
DataService.init()
IncomeService.init()
LabService.init()
BattleService.init(Remotes)

-- Whitelisted client actions -------------------------------------------------
Remotes.register("BuildMonster", MonsterService.build)
Remotes.register("EditMonster", MonsterService.edit)
Remotes.register("RenameMonster", MonsterService.rename)
Remotes.register("RecycleMonster", MonsterService.recycle)
Remotes.register("UpgradeMonster", MonsterService.upgrade)
Remotes.register("SaveBlueprint", MonsterService.saveBlueprint)
Remotes.register("DeleteBlueprint", MonsterService.deleteBlueprint)
Remotes.register("TutorialSeen", MonsterService.tutorialSeen)
Remotes.register("BuyPart", ShopService.buyPart)
Remotes.register("BuyCrate", ShopService.buyCrate)
Remotes.register("UpgradeLab", ShopService.upgradeLab)
Remotes.register("StartBattle", BattleService.start)
Remotes.register("Forfeit", BattleService.forfeit)

-- Any successful state change: push a fresh snapshot; refresh pedestals if monsters changed.
DataService.onChanged(function(player, kind)
	Remotes.push(player)
	if kind == "monsters" or kind == "lab" or kind == "all" then
		LabService.refreshDisplays(player)
	end
end)

-- Player lifecycle -------------------------------------------------------------
local function respawnLoop(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				task.wait(3)
				if player.Parent then
					player:LoadCharacter()
				end
			end)
		end
	end)
end

local function onPlayerAdded(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Parent = ls
	ls.Parent = player

	local data, err = DataService.load(player)
	if not player.Parent then
		DataService.release(player)
		return
	end
	if not data then
		player:Kick(err or "Could not load your data. Please rejoin.")
		return
	end

	LabService.assign(player)
	respawnLoop(player)
	player:LoadCharacter()

	local summary = IncomeService.applyOffline(player)
	player:SetAttribute("Loaded", true)
	DataService.changed(player, "all")
	if summary then
		-- Small delay so the client UI exists before the welcome-back popup arrives.
		task.delay(2, function()
			if player.Parent then
				Remotes.notify(player, "offline", summary)
			end
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	BattleService.cleanup(player)
	DataService.release(player)
end)

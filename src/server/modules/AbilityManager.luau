local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local DataManager = require(script.Parent.DataManager)
local AntiCheat = require(script.Parent.AntiCheat)
local ProgressionManager = require(script.Parent.ProgressionManager)

local AbilityManager = {}

-- Ability Definitions
local Abilities = {
    Dash = {
        Name = "Dash",
        Description = "A QUICK DASH TO DODGE SOMETHING OR TO MOVE QUICKLY",
        Price = 500,
        Cooldown = 15
    },
    Shield = {
        Name = "Shield",
        Description = "A SHIELD THAT PROTECTS YOU FROM A STRONG ATTACK FOR 3 SECONDS",
        Price = 500,
        Cooldown = 20
    }
}

-- Cooldown tracking
local cooldowns = {}

-- Setup Remote Events
local abilityRequestEvent = ReplicatedStorage:FindFirstChild("AbilityRequestEvent")
if not abilityRequestEvent then
    abilityRequestEvent = Instance.new("RemoteEvent")
    abilityRequestEvent.Name = "AbilityRequestEvent"
    abilityRequestEvent.Parent = ReplicatedStorage
end

local abilityUseEvent = ReplicatedStorage:FindFirstChild("AbilityUseEvent")
if not abilityUseEvent then
    abilityUseEvent = Instance.new("RemoteEvent")
    abilityUseEvent.Name = "AbilityUseEvent"
    abilityUseEvent.Parent = ReplicatedStorage
end

local abilityStateEvent = ReplicatedStorage:FindFirstChild("AbilityStateEvent")
if not abilityStateEvent then
    abilityStateEvent = Instance.new("RemoteEvent")
    abilityStateEvent.Name = "AbilityStateEvent"
    abilityStateEvent.Parent = ReplicatedStorage
end

local dashVelocityEvent = ReplicatedStorage:FindFirstChild("DashVelocityEvent")
if not dashVelocityEvent then
    dashVelocityEvent = Instance.new("RemoteEvent")
    dashVelocityEvent.Name = "DashVelocityEvent"
    dashVelocityEvent.Parent = ReplicatedStorage
end

local function syncAbilities(player)
    local data = DataManager.GetData(player)
    if data then
        abilityStateEvent:FireClient(player, data.OwnedAbilities, data.EquippedAbility, Abilities)
    end
end

-- Handling UI Requests
abilityRequestEvent.OnServerEvent:Connect(function(player, action, abilityName)
    local data = DataManager.GetData(player)

    if action == "RequestSync" then
        if data then
            syncAbilities(player)
        else
            -- Data might still be loading from DataStore, wait for it
            task.spawn(function()
                local retries = 0
                while not DataManager.GetData(player) and retries < 10 do
                    task.wait(1)
                    retries += 1
                end
                if DataManager.GetData(player) then
                    syncAbilities(player)
                end
            end)
        end
        return
    end

    if not data then return end

    if action == "Buy" then
        local abilityDef = Abilities[abilityName]
        if abilityDef and not data.OwnedAbilities[abilityName] then
            if data.Coins >= abilityDef.Price then
                ProgressionManager.AddCoins(player, -abilityDef.Price)
                data.OwnedAbilities[abilityName] = true
                syncAbilities(player)
            end
        end
    elseif action == "Equip" then
        if data.OwnedAbilities[abilityName] then
            data.EquippedAbility = abilityName
            syncAbilities(player)
        end
    elseif action == "Unequip" then
        if data.EquippedAbility == abilityName then
            data.EquippedAbility = nil
            syncAbilities(player)
        end
    end
end)

local function applyDash(player)
    local character = player.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    -- AntiCheat Bypass
    AntiCheat.SetBypass(player, "Speed", 1)

    -- Apply velocity locally via RemoteEvent to bypass network ownership issues
    local dashVelocity = rootPart.CFrame.LookVector * 100
    dashVelocityEvent:FireClient(player, dashVelocity)

    -- Trail Effect
    local attachment0 = Instance.new("Attachment", rootPart)
    attachment0.Position = Vector3.new(0, 1, 0)
    local attachment1 = Instance.new("Attachment", rootPart)
    attachment1.Position = Vector3.new(0, -1, 0)

    local trail = Instance.new("Trail")
    trail.Attachment0 = attachment0
    trail.Attachment1 = attachment1
    trail.Color = ColorSequence.new(Color3.new(1, 1, 1))
    trail.Lifetime = 0.5
    trail.Parent = rootPart

    Debris:AddItem(trail, 1)
    Debris:AddItem(attachment0, 1)
    Debris:AddItem(attachment1, 1)
end

local function applyShield(player)
    local character = player.Character
    if not character then return end

    character:SetAttribute("ShieldActive", true)

    local forceField = Instance.new("ForceField")
    forceField.Parent = character

    task.delay(3, function()
        if character then
            character:SetAttribute("ShieldActive", false)
        end
        if forceField then
            forceField:Destroy()
        end
    end)
end

-- Handling Ability Use
abilityUseEvent.OnServerEvent:Connect(function(player)
    -- Abilitatile functioneaza doar in meci
    if not player:GetAttribute("InMatch") then return end

    local data = DataManager.GetData(player)
    if not data or not data.EquippedAbility then return end

    local abilityName = data.EquippedAbility
    local abilityDef = Abilities[abilityName]
    if not abilityDef then return end

    local userId = player.UserId
    if not cooldowns[userId] then cooldowns[userId] = {} end

    local lastUsed = cooldowns[userId][abilityName] or 0
    if tick() - lastUsed >= abilityDef.Cooldown then
        cooldowns[userId][abilityName] = tick()

        if abilityName == "Dash" then
            applyDash(player)
        elseif abilityName == "Shield" then
            applyShield(player)
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    cooldowns[player.UserId] = nil
end)

-- Require Abilities table for other modules
function AbilityManager.GetAbilities()
    return Abilities
end

return AbilityManager

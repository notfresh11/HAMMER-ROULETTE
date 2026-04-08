local ModifierManager = {}
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local activeModifiers = {}
local modifierConnections = {}
local originalMapProperties = {}
local originalLighting = {}

local updateModifiersUIEvent = ReplicatedStorage:FindFirstChild("UpdateModifiersUIEvent")
if not updateModifiersUIEvent then
    updateModifiersUIEvent = Instance.new("RemoteEvent")
    updateModifiersUIEvent.Name = "UpdateModifiersUIEvent"
    updateModifiersUIEvent.Parent = ReplicatedStorage
end

local clientModifierEvent = ReplicatedStorage:FindFirstChild("ClientModifierEvent")
if not clientModifierEvent then
    clientModifierEvent = Instance.new("RemoteEvent")
    clientModifierEvent.Name = "ClientModifierEvent"
    clientModifierEvent.Parent = ReplicatedStorage
end

-- Define all modifiers
ModifierManager.Modifiers = {
    ["Invisible platform"] = {
        Name = "Invisible platform",
        Apply = function()
            local map = Workspace:FindFirstChild("WholeMap") or Workspace:FindFirstChildWhichIsA("Model")
            if not map then return end
            for _, part in ipairs(map:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "SpawnMap" and part.Name ~= "Zone" and part.Transparency < 1 then
                    originalMapProperties[part] = originalMapProperties[part] or {}
                    originalMapProperties[part].Transparency = part.Transparency
                    part.Transparency = 1
                end
            end
        end,
        Remove = function()
            for part, props in pairs(originalMapProperties) do
                if part and part.Parent and props.Transparency then
                    part.Transparency = props.Transparency
                end
            end
        end
    },
    ["Shadow Assasin"] = {
        Name = "Shadow Assasin",
        Apply = function()
            -- Logic handled in MaceMechanic / MainGameLoop for the specific player
        end,
        Remove = function()
        end
    },
    ["Ghost Party"] = {
        Name = "Ghost Party",
        Apply = function()
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then
                    ModifierManager.ApplyGhostToCharacter(player.Character, true)
                end
            end
        end,
        Remove = function()
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then
                    ModifierManager.ApplyGhostToCharacter(player.Character, false)
                end
            end
        end
    },
    ["Icyy"] = {
        Name = "Icyy",
        Apply = function()
            local map = Workspace:FindFirstChild("WholeMap") or Workspace:FindFirstChildWhichIsA("Model")
            if not map then return end
            for _, part in ipairs(map:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    originalMapProperties[part] = originalMapProperties[part] or {}
                    -- Save original only if we haven't already saved it
                    if originalMapProperties[part].CustomPhysicalProperties == nil then
                        originalMapProperties[part].CustomPhysicalProperties = part.CustomPhysicalProperties or "DEFAULT"
                    end
                    -- Friction 0, Restitution 0
                    part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 1, 1)
                end
            end
        end,
        Remove = function()
            for part, props in pairs(originalMapProperties) do
                if part and part.Parent and props.CustomPhysicalProperties then
                    if props.CustomPhysicalProperties == "DEFAULT" then
                        part.CustomPhysicalProperties = nil
                    else
                        part.CustomPhysicalProperties = props.CustomPhysicalProperties
                    end
                end
            end
        end
    },
    ["Grow a Player!"] = {
        Name = "Grow a Player!",
        Apply = function()
            -- Handled via Heartbeat loop in MainGameLoop / ModifierManager
        end,
        Remove = function()
            -- Reset scales
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then
                    local hum = player.Character:FindFirstChild("Humanoid")
                    if hum then
                        local scales = {"BodyDepthScale", "BodyHeightScale", "BodyWidthScale", "HeadScale"}
                        for _, scaleName in ipairs(scales) do
                            local val = hum:FindFirstChild(scaleName)
                            if val and val:IsA("NumberValue") then
                                val.Value = 1
                            end
                        end
                    end
                end
            end
        end
    },
    ["The Player isnt Growing..."] = {
        Name = "The Player isnt Growing...",
        Apply = function()
            -- Handled via Heartbeat
        end,
        Remove = function()
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then
                    local hum = player.Character:FindFirstChild("Humanoid")
                    if hum then
                        local scales = {"BodyDepthScale", "BodyHeightScale", "BodyWidthScale", "HeadScale"}
                        for _, scaleName in ipairs(scales) do
                            local val = hum:FindFirstChild(scaleName)
                            if val and val:IsA("NumberValue") then
                                val.Value = 1
                            end
                        end
                    end
                end
            end
        end
    },
    ["I cant see !"] = {
        Name = "I cant see !",
        Apply = function()
            originalLighting.FogColor = Lighting.FogColor
            originalLighting.FogEnd = Lighting.FogEnd
            originalLighting.FogStart = Lighting.FogStart
            Lighting.FogColor = Color3.new(0, 0, 0)
            Lighting.FogEnd = 30
            Lighting.FogStart = 0
            clientModifierEvent:FireAllClients("Fog", {Color = Color3.new(0,0,0), End = 30, Start = 0})

            -- Apply outline to everyone
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then
                    ModifierManager.ApplyOutlineToCharacter(player.Character, true)
                end
            end
        end,
        Remove = function()
            Lighting.FogColor = originalLighting.FogColor or Color3.new(0.5, 0.5, 0.5)
            Lighting.FogEnd = originalLighting.FogEnd or 100000
            Lighting.FogStart = originalLighting.FogStart or 0
            clientModifierEvent:FireAllClients("Fog", {Color = Lighting.FogColor, End = Lighting.FogEnd, Start = Lighting.FogStart})

            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then
                    ModifierManager.ApplyOutlineToCharacter(player.Character, false)
                end
            end
        end
    },
    ["Low Gravity"] = {
        Name = "Low Gravity",
        Apply = function()
            Workspace.Gravity = 50
        end,
        Remove = function()
            Workspace.Gravity = 196.2
        end
    },
    ["Super Speed"] = {
        Name = "Super Speed",
        Apply = function()
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then
                    local hum = player.Character:FindFirstChild("Humanoid")
                    if hum then
                        hum.WalkSpeed = 32
                        player.Character:SetAttribute("MaxSpeedAllowed", 32)
                    end
                end
            end
        end,
        Remove = function()
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then
                    local hum = player.Character:FindFirstChild("Humanoid")
                    if hum then
                        hum.WalkSpeed = 16
                        player.Character:SetAttribute("MaxSpeedAllowed", 16)
                    end
                end
            end
        end
    },
    ["Double Trouble !"] = {
        Name = "Double Trouble !",
        Apply = function() end, Remove = function() end -- Logic in Roulette / MainGameLoop
    },
    ["Triple Trouble !"] = {
        Name = "Triple Trouble !",
        Apply = function() end, Remove = function() end -- Logic in Roulette / MainGameLoop
    },
    ["Panic at the Disco!"] = {
        Name = "Panic at the Disco!",
        Apply = function()
            local discoConn
            discoConn = RunService.Heartbeat:Connect(function()
                if math.random() < 0.1 then -- limit frequency
                    local map = Workspace:FindFirstChild("WholeMap") or Workspace:FindFirstChildWhichIsA("Model")
                    if map then
                        local parts = {}
                        for _, p in ipairs(map:GetDescendants()) do
                            if p:IsA("BasePart") and p.Name ~= "SpawnMap" and p.Name ~= "Zone" and p.Transparency < 1 then
                                table.insert(parts, p)
                            end
                        end
                        if #parts > 0 then
                            local part = parts[math.random(1, #parts)]
                            originalMapProperties[part] = originalMapProperties[part] or {}
                            originalMapProperties[part].Color = originalMapProperties[part].Color or part.Color
                            part.Color = Color3.new(math.random(), math.random(), math.random())
                        end
                    end
                end
            end)
            table.insert(modifierConnections, discoConn)
        end,
        Remove = function()
            for part, props in pairs(originalMapProperties) do
                if part and part.Parent and props.Color then
                    part.Color = props.Color
                end
            end
        end
    },
    ["Shockwave"] = {
        Name = "Shockwave",
        Apply = function() end, Remove = function() end -- Logic in MaceMechanic
    }
}

local Exclusions = {
    {"Grow a Player!", "The Player isnt Growing..."},
    {"Double Trouble !", "Triple Trouble !"},
    {"Invisible platform", "Panic at the Disco!"},
    {"Ghost Party", "Shadow Assasin", "I cant see !"}
}

function ModifierManager.GetActiveModifiers()
    return activeModifiers
end

function ModifierManager.IsModifierActive(name)
    return table.find(activeModifiers, name) ~= nil
end

function ModifierManager.ApplyOutlineToCharacter(character, enable, isMaceUser)
    local highlight = character:FindFirstChild("GhostHighlight")
    if enable then
        if not highlight then
            highlight = Instance.new("Highlight")
            highlight.Name = "GhostHighlight"
            highlight.FillTransparency = 1
            highlight.OutlineTransparency = 0
            highlight.Parent = character
        end
        if isMaceUser then
            highlight.OutlineColor = Color3.new(1, 0, 0)
        else
            highlight.OutlineColor = Color3.new(1, 1, 1)
        end
    else
        if highlight then
            highlight:Destroy()
        end
    end
end

function ModifierManager.ApplyGhostToCharacter(character, isGhost, isMaceUser)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            if isGhost then
                if not part:GetAttribute("OrigTransparency") then
                    part:SetAttribute("OrigTransparency", part.Transparency)
                end
                part.Transparency = 1
            else
                local orig = part:GetAttribute("OrigTransparency")
                if orig then
                    part.Transparency = orig
                    part:SetAttribute("OrigTransparency", nil)
                end
            end
        elseif part:IsA("Decal") then
            if isGhost then
                if not part:GetAttribute("OrigTransparency") then
                    part:SetAttribute("OrigTransparency", part.Transparency)
                end
                part.Transparency = 1
            else
                local orig = part:GetAttribute("OrigTransparency")
                if orig then
                    part.Transparency = orig
                    part:SetAttribute("OrigTransparency", nil)
                end
            end
        end
    end

    ModifierManager.ApplyOutlineToCharacter(character, isGhost, isMaceUser)
end

function ModifierManager.ReapplyPlayerStates(player)
    if not player or not player.Character then return end
    local char = player.Character

    -- Check Ghost Party
    if ModifierManager.IsModifierActive("Ghost Party") then
        ModifierManager.ApplyGhostToCharacter(char, true, false)
    else
        ModifierManager.ApplyGhostToCharacter(char, false, false)
    end

    -- Check I cant see !
    if ModifierManager.IsModifierActive("I cant see !") then
        ModifierManager.ApplyOutlineToCharacter(char, true, false)
    end

    -- Check Super Speed
    local hum = char:FindFirstChild("Humanoid")
    if hum then
        if ModifierManager.IsModifierActive("Super Speed") then
            hum.WalkSpeed = 32
            char:SetAttribute("MaxSpeedAllowed", 32)
        else
            hum.WalkSpeed = 16
            char:SetAttribute("MaxSpeedAllowed", 16)
        end
    end
end

function ModifierManager.ClearAllModifiers()
    for _, modName in ipairs(activeModifiers) do
        local mod = ModifierManager.Modifiers[modName]
        if mod and mod.Remove then
            mod.Remove()
        end
    end

    for _, conn in ipairs(modifierConnections) do
        conn:Disconnect()
    end
    table.clear(modifierConnections)

    activeModifiers = {}
    table.clear(originalMapProperties)
    updateModifiersUIEvent:FireAllClients({})
end

function ModifierManager.PickAndAddModifier(activePlayerCount)
    local available = {}

    for modName, _ in pairs(ModifierManager.Modifiers) do
        local canAdd = true
        if table.find(activeModifiers, modName) then
            canAdd = false
        end

        -- Check exclusions
        if canAdd then
            for _, group in ipairs(Exclusions) do
                if table.find(group, modName) then
                    for _, activeMod in ipairs(activeModifiers) do
                        if table.find(group, activeMod) then
                            canAdd = false
                            break
                        end
                    end
                end
                if not canAdd then break end
            end
        end

        -- Check player count constraints
        if canAdd and modName == "Double Trouble !" and activePlayerCount < 3 then canAdd = false end
        if canAdd and modName == "Triple Trouble !" and activePlayerCount < 4 then canAdd = false end

        if canAdd then
            table.insert(available, modName)
        end
    end

    if #available > 0 then
        local chosen = available[math.random(1, #available)]
        table.insert(activeModifiers, chosen)

        local mod = ModifierManager.Modifiers[chosen]
        if mod and mod.Apply then
            mod.Apply()
        end

        updateModifiersUIEvent:FireAllClients(activeModifiers)
        return chosen
    end
    return nil
end

function ModifierManager.UpdateDynamicModifiers(activePlayers, maceUsers)
    local growActive = ModifierManager.IsModifierActive("Grow a Player!")
    local shrinkActive = ModifierManager.IsModifierActive("The Player isnt Growing...")

    if growActive or shrinkActive then
        for _, player in ipairs(activePlayers) do
            local isMace = table.find(maceUsers, player) ~= nil
            if not isMace and player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                local hum = player.Character:FindFirstChild("Humanoid")
                if root and hum and hum.Health > 0 then
                    -- Check if moving
                    if root.AssemblyLinearVelocity.Magnitude > 1 then
                        local scaleFactor = growActive and 1.002 or 0.998
                        local scales = {"BodyDepthScale", "BodyHeightScale", "BodyWidthScale", "HeadScale"}
                        for _, scaleName in ipairs(scales) do
                            local val = hum:FindFirstChild(scaleName)
                            if val and val:IsA("NumberValue") then
                                local newVal = val.Value * scaleFactor
                                if growActive then
                                    newVal = math.min(newVal, 3)
                                else
                                    newVal = math.max(newVal, 0.3)
                                end
                                val.Value = newVal
                            end
                        end
                    end
                end
            end
        end
    end
end

return ModifierManager

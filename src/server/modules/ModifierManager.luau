local ModifierManager = {}
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local MapManager = require(script.Parent.MapManager)

local activeModifiers = {}
local savedModifiers = nil
local adminAbuseApplied = {}
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

local knockbackEvent = ReplicatedStorage:FindFirstChild("KnockbackClickEvent")
if not knockbackEvent then
    knockbackEvent = Instance.new("RemoteEvent")
    knockbackEvent.Name = "KnockbackClickEvent"
    knockbackEvent.Parent = ReplicatedStorage
end

local beachBallThrowEvent = ReplicatedStorage:FindFirstChild("BeachBallThrowEvent")
if not beachBallThrowEvent then
    beachBallThrowEvent = Instance.new("RemoteEvent")
    beachBallThrowEvent.Name = "BeachBallThrowEvent"
    beachBallThrowEvent.Parent = ReplicatedStorage
end

local hotPotatoTimerEvent = ReplicatedStorage:FindFirstChild("HotPotatoTimerEvent")
if not hotPotatoTimerEvent then
    hotPotatoTimerEvent = Instance.new("RemoteEvent")
    hotPotatoTimerEvent.Name = "HotPotatoTimerEvent"
    hotPotatoTimerEvent.Parent = ReplicatedStorage
end

local passEvent = ReplicatedStorage:FindFirstChild("HotPotatoPassEvent")
if not passEvent then
    passEvent = Instance.new("RemoteEvent")
    passEvent.Name = "HotPotatoPassEvent"
    passEvent.Parent = ReplicatedStorage
end

beachBallThrowEvent.OnServerEvent:Connect(function(player, cursorHitPosition)
    if not ModifierManager.IsModifierActive("Beach Episode") then return end
    if typeof(cursorHitPosition) ~= "Vector3" then return end

    local char = player.Character
    if not char then return end

    local tool = char:FindFirstChild("BeachBall")
    if not tool then return end

    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Destroy tool right away
    tool:Destroy()

    local dirToHit = (cursorHitPosition - root.Position).Unit
    local forwardDir = root.CFrame.LookVector
    -- Jucătorul trebuie să stea cu fața la punctul unde vrea să arunce
    if forwardDir:Dot(dirToHit) < 0.5 then
        return -- nu e orientat cu fața spre cursor
    end

    -- Spawn projectile visually (optional, we'll just check hits on a ray or distance)
    local hitDist = 50 -- range of ball throw
    local pushForce = 120

    local closestTarget = nil
    local closestDist = hitDist

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            local otherRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
            if otherRoot then
                local dist = (otherRoot.Position - root.Position).Magnitude
                if dist <= hitDist then
                    local dirToTarget = (otherRoot.Position - root.Position).Unit
                    local dotToTarget = dirToHit:Dot(dirToTarget)
                    -- Trebuie să fie pe traiectoria mingii (aproximativ)
                    if dotToTarget > 0.9 then
                        if dist < closestDist then
                            closestDist = dist
                            closestTarget = otherRoot
                        end
                    end
                end
            end
        end
    end

    if closestTarget then
        local flatDir = Vector3.new(dirToHit.X, 0, dirToHit.Z).Unit
        if flatDir.Magnitude ~= flatDir.Magnitude then flatDir = Vector3.new(1,0,0) end

        closestTarget.AssemblyLinearVelocity = flatDir * pushForce + Vector3.new(0, 50, 0)
    end
end)

local lastKnockbacks = {}
knockbackEvent.OnServerEvent:Connect(function(player)
    if not ModifierManager.IsModifierActive("KnockBack") then return end

    local now = tick()
    local lastTime = lastKnockbacks[player.UserId] or 0
    if now - lastTime < 1 then return end
    lastKnockbacks[player.UserId] = now

    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Găsim ținta în fața jucătorului (maxim 12 stud-uri)
    local hitDist = 12
    local pushForce = 90 -- destul de mult încât să fie frustrant

    local closestTarget = nil
    local closestDist = hitDist

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            local otherRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
            if otherRoot then
                local dist = (otherRoot.Position - root.Position).Magnitude
                if dist <= hitDist then
                    -- Verificăm dacă se află în unghiul vizual frontal
                    local dirToTarget = (otherRoot.Position - root.Position).Unit
                    local forwardDir = root.CFrame.LookVector
                    local dotProduct = forwardDir:Dot(dirToTarget)
                    if dotProduct > 0.3 or dist <= 4 then -- Mai permisiv cu unghiul, iar dacă sunt super aproape nu mai contează unghiul așa mult
                        if dist < closestDist then
                            closestDist = dist
                            closestTarget = otherRoot
                        end
                    end
                end
            end
        end
    end

    if closestTarget then
        -- Play an animation if we want (optional, we can just apply push)
        -- Animatia standard de punch:
        local pushAnimId = "rbxassetid://104708388"
        local anim = Instance.new("Animation")
        anim.AnimationId = pushAnimId
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            local animator = hum:FindFirstChildOfClass("Animator")
            if animator then
                animator:LoadAnimation(anim):Play()
            end
        end

        local pushDir = root.CFrame.LookVector
        -- Aplicăm assembly linear velocity pe X și Z, și puțin pe Y
        local flatDir = Vector3.new(pushDir.X, 0, pushDir.Z).Unit
        if flatDir.Magnitude ~= flatDir.Magnitude then flatDir = Vector3.new(1,0,0) end

        -- Override current velocity completely for a hard push
        closestTarget.AssemblyLinearVelocity = flatDir * pushForce + Vector3.new(0, 30, 0)
    end
end)

-- Define all modifiers
ModifierManager.Modifiers = {
    ["Invisible platform"] = {
        Name = "Invisible platform",
        Apply = function()
            local map = MapManager.getCurrentMap()
            if not map then return end
            for _, part in ipairs(map:GetDescendants()) do
                -- Verificăm special dacă este BasePart sau o Uniune care funcționează ca teren
                if (part:IsA("BasePart") or part.Name == "BasePart") and part.Name ~= "SpawnMap" and part.Name ~= "Zone" and part.Transparency < 1 then
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
            -- Shadow Assassin is handled in MaceMechanic, it makes the Mace User transparent to others but they see an outline of themselves
        end,
        Remove = function()
        end
    },
    ["Ghost Party"] = {
        Name = "Ghost Party",
        Apply = function()
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then
                    ModifierManager.ApplyGhostToCharacter(player.Character, true, false)
                    ModifierManager.ApplyOutlineToCharacter(player.Character, true, false)
                end
            end
        end,
        Remove = function()
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then
                    ModifierManager.ApplyGhostToCharacter(player.Character, false, false)
                    ModifierManager.ApplyOutlineToCharacter(player.Character, false, false)
                end
            end
        end
    },
    ["Icyy"] = {
        Name = "Icyy",
        Apply = function()
            local map = MapManager.getCurrentMap()
            if not map then return end
            for _, part in ipairs(map:GetDescendants()) do
                -- Verificăm explicit și după nume pentru siguranță, chiar dacă IsA("BasePart") acoperă și Uniunile.
                if (part:IsA("BasePart") or part.Name == "BasePart") and part.CanCollide then
                    originalMapProperties[part] = originalMapProperties[part] or {}
                    -- Save original only if we haven't already saved it
                    if originalMapProperties[part].CustomPhysicalProperties == nil then
                        originalMapProperties[part].CustomPhysicalProperties = part.CustomPhysicalProperties or "DEFAULT"
                    end
                    -- Pentru a asigura alunecarea pe orice material (inclusiv Studs/Neon care au friction custom),
                    -- forțăm friction 0 absolut și weight MARE (100) pentru a suprascrie fricțiunea picioarelor jucătorului.
                    part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 100)
                end
            end
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then
                    for _, part in ipairs(player.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 100)
                        end
                    end
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
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then
                    for _, part in ipairs(player.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CustomPhysicalProperties = nil
                        end
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
            local lastChange = 0
            discoConn = RunService.Heartbeat:Connect(function()
                local now = tick()
                if now - lastChange > 1 then -- change color only once per second
                    lastChange = now
                    local map = MapManager.getCurrentMap()
                    if map then
                        local parts = {}
                        for _, p in ipairs(map:GetDescendants()) do
                            if (p:IsA("BasePart") or p.Name == "BasePart") and p.Name ~= "SpawnMap" and p.Name ~= "Zone" and p.Transparency < 1 then
                                table.insert(parts, p)
                            end
                        end
                        if #parts > 0 then
                            -- Change up to 3 random parts per second
                            for _ = 1, math.min(3, #parts) do
                                local part = parts[math.random(1, #parts)]
                                originalMapProperties[part] = originalMapProperties[part] or {}
                                originalMapProperties[part].Color = originalMapProperties[part].Color or part.Color
                                part.Color = Color3.new(math.random(), math.random(), math.random())
                            end
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
    },
    ["Streamsnipe"] = {
        Name = "Streamsnipe",
        IsRoundModifier = true,
        Apply = function() end, Remove = function() end
    },
    ["SuddenDeath"] = {
        Name = "SuddenDeath",
        IsRoundModifier = true,
        Apply = function() end, Remove = function() end
    },
    ["KnockBack"] = {
        Name = "KnockBack",
        Apply = function() end, Remove = function() end
    },
    ["The Floor is Lava"] = {
        Name = "The Floor is Lava",
        Apply = function() end, Remove = function() end
    },
    ["Beach Episode"] = {
        Name = "Beach Episode",
        Apply = function() end, Remove = function() end
    },
    ["Nothing Special"] = {
        Name = "Nothing Special",
        IsRoundModifier = true,
        Apply = function() end, Remove = function() end
    },
    ["Random Strategy"] = {
        Name = "Random Strategy",
        Apply = function() end, Remove = function() end
    },
    ["AdminAbuse"] = {
        Name = "AdminAbuse",
        IsRoundModifier = true,
        Apply = function() end, Remove = function() end
    },
    ["Impostor"] = {
        Name = "Impostor",
        Apply = function() end, Remove = function() end
    },
    ["Hot Potato"] = {
        Name = "Hot Potato",
        IsRoundModifier = true,
        Apply = function() end, Remove = function() end
    }
}

local Exclusions = {
    {"Grow a Player!", "The Player isnt Growing..."},
    {"Streamsnipe", "SuddenDeath", "Hot Potato"},
    {"Double Trouble !", "Triple Trouble !", "Streamsnipe", "SuddenDeath"}, -- Hot Potato POATE pica cu Double/Triple Trouble, dar nu Streamsnipe sau SuddenDeath
    {"Ghost Party", "Shadow Assasin"}, -- I cant see! poate pica cu ele, deci nu e in acest grup!
    {"Invisible platform", "Panic at the Disco!"},
    {"AdminAbuse", "Nothing Special"}
}

function ModifierManager.GetActiveModifiers()
    return activeModifiers
end

function ModifierManager.IsModifierActive(name)
    if table.find(activeModifiers, name) then return true end
    if table.find(activeModifiers, "AdminAbuse") then
        if table.find(adminAbuseApplied, name) then
            return true
        end
    end
    return false
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
                -- To make the highlight visible, the part transparency must NOT be exactly 1
                -- 0.99 transparency makes it effectively invisible but still allows Highlight rendering
                part.Transparency = 0.99
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
                part.Transparency = 0.99
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

    -- Outline Logic
    local needsOutline = false
    local isRedOutline = false
    local isImpostor = ModifierManager.IsModifierActive("Impostor")

    if ModifierManager.IsModifierActive("I cant see !") then
        needsOutline = true
    end

    if isImpostor then
        needsOutline = true
        isRedOutline = true
    end

    ModifierManager.ApplyOutlineToCharacter(char, needsOutline, isRedOutline)

    -- Check Super Speed & Jump Power
    local hum = char:FindFirstChild("Humanoid")
    if hum then
        if ModifierManager.IsModifierActive("Super Speed") then
            hum.WalkSpeed = 32
            char:SetAttribute("MaxSpeedAllowed", 32)
        else
            hum.WalkSpeed = 16
            char:SetAttribute("MaxSpeedAllowed", 16)
        end

        if isImpostor then
            hum.UseJumpPower = false
            hum.JumpHeight = 40
        else
            hum.UseJumpPower = false
            hum.JumpHeight = 7.2
        end
    end
end

function ModifierManager.ClearAllModifiers()
    if #adminAbuseApplied > 0 then
        for _, modName in ipairs(adminAbuseApplied) do
            local mod = ModifierManager.Modifiers[modName]
            if mod and mod.Remove then mod.Remove() end
        end
        adminAbuseApplied = {}
    end

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
    savedModifiers = nil
    adminAbuseApplied = {}
    table.clear(originalMapProperties)
    updateModifiersUIEvent:FireAllClients({})
end

function ModifierManager.ClearRoundModifiers()
    -- Restore original modifiers if a special override was active
    if savedModifiers then
        if #adminAbuseApplied > 0 then
            -- Remove all forced AdminAbuse modifiers
            for _, modName in ipairs(adminAbuseApplied) do
                local mod = ModifierManager.Modifiers[modName]
                if mod and mod.Remove then mod.Remove() end
            end
            adminAbuseApplied = {}
        end

        -- Remove the override modifier (Nothing Special / AdminAbuse)
        for _, modName in ipairs(activeModifiers) do
            local mod = ModifierManager.Modifiers[modName]
            if mod and mod.IsRoundModifier and mod.Remove then
                mod.Remove()
            end
        end

        -- Re-apply saved modifiers
        activeModifiers = {}
        for _, modName in ipairs(savedModifiers) do
            table.insert(activeModifiers, modName)
            local mod = ModifierManager.Modifiers[modName]
            if mod and mod.Apply then
                mod.Apply()
            end
        end
        savedModifiers = nil
    else
        local newActiveModifiers = {}
        for _, modName in ipairs(activeModifiers) do
            local mod = ModifierManager.Modifiers[modName]
            if mod and mod.IsRoundModifier then
                if mod.Remove then
                    mod.Remove()
                end
            else
                table.insert(newActiveModifiers, modName)
            end
        end
        activeModifiers = newActiveModifiers
    end

    updateModifiersUIEvent:FireAllClients(activeModifiers)
end

function ModifierManager.PickAndAddModifier(activePlayerCount)
    local available = {}

    for modName, _ in pairs(ModifierManager.Modifiers) do
        local canAdd = true
        if table.find(activeModifiers, modName) then
            canAdd = false
        end

        if canAdd then
            for _, group in ipairs(Exclusions) do
                if table.find(group, modName) then
                    for _, activeMod in ipairs(activeModifiers) do
                        if table.find(group, activeMod) then
                            -- Excepția: Double Trouble și Triple Trouble au voie să fie adăugate în lista de "available"
                            -- pentru a-l înlocui pe celălalt, dar alte conflicte sunt respinse!
                            local isTroubleReplacement = (modName == "Double Trouble !" and activeMod == "Triple Trouble !") or
                                                         (modName == "Triple Trouble !" and activeMod == "Double Trouble !")
                            if not isTroubleReplacement then
                                canAdd = false
                                break
                            end
                        end
                    end
                end
                if not canAdd then break end
            end
        end

        -- Check player count constraints
        if canAdd and modName == "Double Trouble !" and activePlayerCount < 3 then canAdd = false end
        if canAdd and modName == "Triple Trouble !" and activePlayerCount < 4 then canAdd = false end
        if canAdd and modName == "SuddenDeath" and activePlayerCount < 3 then canAdd = false end

        if canAdd then
            table.insert(available, modName)
        end
    end

    if #available > 0 then
        local chosen = available[math.random(1, #available)]

        if chosen == "Nothing Special" then
            savedModifiers = {}
            for _, m in ipairs(activeModifiers) do table.insert(savedModifiers, m) end

            -- Remove current ones
            for _, m in ipairs(activeModifiers) do
                local oldMod = ModifierManager.Modifiers[m]
                if oldMod and oldMod.Remove then oldMod.Remove() end
            end
            activeModifiers = {chosen}
            updateModifiersUIEvent:FireAllClients(activeModifiers)
            return chosen
        elseif chosen == "AdminAbuse" then
            savedModifiers = {}
            for _, m in ipairs(activeModifiers) do table.insert(savedModifiers, m) end

            activeModifiers = {chosen}
            adminAbuseApplied = {}

            -- Shuffle modifier list to give fair random chances
            local keys = {}
            for mName in pairs(ModifierManager.Modifiers) do
                if mName ~= "AdminAbuse" and mName ~= "Nothing Special" then
                    table.insert(keys, mName)
                end
            end

            for i = #keys, 2, -1 do
                local j = math.random(i)
                keys[i], keys[j] = keys[j], keys[i]
            end

            for _, mName in ipairs(keys) do
                local mDef = ModifierManager.Modifiers[mName]

                -- Check if it can be added without violating exclusions
                local canAdd = true
                for _, group in ipairs(Exclusions) do
                    if table.find(group, mName) then
                        for _, appliedMod in ipairs(adminAbuseApplied) do
                            if table.find(group, appliedMod) then
                                canAdd = false
                                break
                            end
                        end
                    end
                    if not canAdd then break end
                end

                -- Check player count constraints
                if canAdd and mName == "Double Trouble !" and activePlayerCount < 3 then canAdd = false end
                if canAdd and mName == "Triple Trouble !" and activePlayerCount < 4 then canAdd = false end
                if canAdd and mName == "SuddenDeath" and activePlayerCount < 3 then canAdd = false end

                if canAdd then
                    table.insert(adminAbuseApplied, mName)
                    if mDef.Apply then mDef.Apply() end
                end
            end

            updateModifiersUIEvent:FireAllClients(activeModifiers)
            return chosen
        end

        -- Handle Exclusions for `chosen` (replace any conflicting active modifiers)
        local newActiveModifiers = {}
        local conflictingModsToRemove = {}

        for _, activeMod in ipairs(activeModifiers) do
            local conflict = false
            for _, group in ipairs(Exclusions) do
                if table.find(group, chosen) and table.find(group, activeMod) then
                    conflict = true
                    break
                end
            end
            if conflict then
                table.insert(conflictingModsToRemove, activeMod)
            else
                table.insert(newActiveModifiers, activeMod)
            end
        end

        for _, modName in ipairs(conflictingModsToRemove) do
            local oldMod = ModifierManager.Modifiers[modName]
            if oldMod and oldMod.Remove then oldMod.Remove() end
        end

        activeModifiers = newActiveModifiers
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

local lavaDamageTicks = {}

function ModifierManager.UpdateDynamicModifiers(activePlayers, maceUsers)
    local growActive = ModifierManager.IsModifierActive("Grow a Player!")
    local shrinkActive = ModifierManager.IsModifierActive("The Player isnt Growing...")
    local floorIsLava = ModifierManager.IsModifierActive("The Floor is Lava")

    local now = tick()

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

    if floorIsLava then
        for _, player in ipairs(activePlayers) do
            if player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                local hum = player.Character:FindFirstChild("Humanoid")
                if root and hum and hum.Health > 0 then
                    -- Oprește scriptul nativ de Health ca să nu se regenereze automat în The Floor is Lava (ori permanent pe parcursul meciului dacă The Floor is Lava a fost vreodată activ)
                    local healthScript = player.Character:FindFirstChild("Health")
                    if healthScript and healthScript:IsA("Script") then
                        healthScript.Disabled = true
                    end

                    -- Check if on floor and moving
                    local isMoving = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude > 1
                    local isOnFloor = hum.FloorMaterial ~= Enum.Material.Air
                    if isMoving and isOnFloor then
                        local lastTick = lavaDamageTicks[player.UserId] or 0
                        if now - lastTick >= 1 then
                            lavaDamageTicks[player.UserId] = now
                            hum:TakeDamage(5)
                        end
                    end
                end
            end
        end
    end
end

return ModifierManager

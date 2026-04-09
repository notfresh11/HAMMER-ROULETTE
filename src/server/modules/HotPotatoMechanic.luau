local HotPotatoMechanic = {}
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

HotPotatoMechanic.cleanups = {}

HotPotatoMechanic.forceStopMechanic = function()
    for _, cleanup in pairs(HotPotatoMechanic.cleanups) do
        cleanup()
    end
    table.clear(HotPotatoMechanic.cleanups)
end

function HotPotatoMechanic.startMechanic(player, onRoundEndCallback, activePlayers)
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end

    local potatoFolder = ServerStorage:FindFirstChild("HotPotato")
    if not potatoFolder then return end

    local toolTemplate = potatoFolder:FindFirstChild("HotPotato") or potatoFolder:FindFirstChild("Tool")
    if not toolTemplate then return end

    local currentTool = toolTemplate:Clone()
    currentTool.Name = "HotPotatoTool"
    currentTool.Parent = player.Backpack
    humanoid:EquipTool(currentTool)

    -- Timer UI
    local updateTimerEvent = ReplicatedStorage:FindFirstChild("HotPotatoTimerEvent")
    if not updateTimerEvent then
        updateTimerEvent = Instance.new("RemoteEvent")
        updateTimerEvent.Name = "HotPotatoTimerEvent"
        updateTimerEvent.Parent = ReplicatedStorage
    end

    local timer = 15
    local potatoHolder = player
    local mechanicActive = true

    local function cleanupFunc()
        mechanicActive = false
        updateTimerEvent:FireAllClients(-1, potatoHolder and potatoHolder.Name or "") -- Hide UI specific to this
        if potatoHolder and potatoHolder.Character then
            local tool = potatoHolder.Character:FindFirstChild("HotPotatoTool") or potatoHolder.Backpack:FindFirstChild("HotPotatoTool")
            if tool then tool:Destroy() end
        end
        if passConn then passConn:Disconnect() end
        HotPotatoMechanic.cleanups[player] = nil
    end

    HotPotatoMechanic.cleanups[player] = cleanupFunc

    -- Server connection for passing potato
    local passEvent = ReplicatedStorage:FindFirstChild("HotPotatoPassEvent")
    if not passEvent then
        passEvent = Instance.new("RemoteEvent")
        passEvent.Name = "HotPotatoPassEvent"
        passEvent.Parent = ReplicatedStorage
    end

    local passConn
    passConn = passEvent.OnServerEvent:Connect(function(passingPlayer, targetPos)
        if not mechanicActive then return end
        if passingPlayer ~= potatoHolder then return end

        local char = passingPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local closestTarget = nil
        local minData = 10 -- 10 studs range to pass

        for _, other in ipairs(activePlayers) do
            if other ~= passingPlayer and other.Character then
                local otherRoot = other.Character:FindFirstChild("HumanoidRootPart")
                if otherRoot then
                    local dist = (otherRoot.Position - root.Position).Magnitude
                    if dist < minData then
                        minData = dist
                        closestTarget = other
                    end
                end
            end
        end

        if closestTarget then
            -- Pass the potato
            local oldTool = char:FindFirstChild("HotPotatoTool") or passingPlayer.Backpack:FindFirstChild("HotPotatoTool")
            if oldTool then oldTool:Destroy() end

            potatoHolder = closestTarget
            local newChar = potatoHolder.Character
            if newChar and newChar:FindFirstChild("Humanoid") then
                local newTool = toolTemplate:Clone()
                newTool.Name = "HotPotatoTool"
                newTool.Parent = potatoHolder.Backpack
                newChar.Humanoid:EquipTool(newTool)
            end

            print("HotPotato passed from " .. passingPlayer.Name .. " to " .. potatoHolder.Name)
        end
    end)

    -- Timer loop
    task.spawn(function()
        while mechanicActive and timer > 0 do
            updateTimerEvent:FireAllClients(timer, potatoHolder.Name)
            task.wait(1)
            timer = timer - 1

            if potatoHolder.Character == nil or not potatoHolder.Character:FindFirstChild("Humanoid") or potatoHolder.Character.Humanoid.Health <= 0 then
                -- Holder died some other way
                break
            end
        end

        if mechanicActive then
            updateTimerEvent:FireAllClients(-1, potatoHolder and potatoHolder.Name or "") -- Hide UI
            passConn:Disconnect()
            mechanicActive = false
            HotPotatoMechanic.cleanups[player] = nil

            -- Explode
            if potatoHolder and potatoHolder.Character then
                local root = potatoHolder.Character:FindFirstChild("HumanoidRootPart")
                local hum = potatoHolder.Character:FindFirstChild("Humanoid")

                if root then
                    local explosion = Instance.new("Explosion")
                    explosion.Position = root.Position
                    explosion.BlastRadius = 15
                    explosion.BlastPressure = 500000
                    explosion.Parent = Workspace

                    local vfxEvent = ReplicatedStorage:FindFirstChild("ShockwaveVfxEvent")
                    if vfxEvent then vfxEvent:FireAllClients(root.Position) end
                end

                if hum then
                    hum.Health = 0
                end

                local tool = potatoHolder.Character:FindFirstChild("HotPotatoTool") or potatoHolder.Backpack:FindFirstChild("HotPotatoTool")
                if tool then tool:Destroy() end
            end

            if onRoundEndCallback then onRoundEndCallback() end
        end
    end)
end

return HotPotatoMechanic

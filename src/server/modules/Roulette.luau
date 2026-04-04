local Roulette = {}
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local playerWeights = {}

-- Initialize weights for new players
Players.PlayerAdded:Connect(function(player)
    playerWeights[player.UserId] = 1
end)

Players.PlayerRemoving:Connect(function(player)
    playerWeights[player.UserId] = nil
end)

function Roulette.selectMaceBearer(activePlayers)
    if #activePlayers == 0 then return nil end

    local totalWeight = 0
    for _, player in ipairs(activePlayers) do
        local weight = playerWeights[player.UserId] or 1
        totalWeight = totalWeight + weight
    end

    local randomValue = math.random() * totalWeight
    local chosenPlayer = nil
    local currentSum = 0

    for _, player in ipairs(activePlayers) do
        local weight = playerWeights[player.UserId] or 1
        currentSum = currentSum + weight
        if randomValue <= currentSum then
            chosenPlayer = player
            break
        end
    end

    -- Fallback
    if not chosenPlayer then
        chosenPlayer = activePlayers[math.random(1, #activePlayers)]
    end

    -- Update weights
    for _, player in ipairs(activePlayers) do
        if player == chosenPlayer then
            playerWeights[player.UserId] = 1
        else
            playerWeights[player.UserId] = (playerWeights[player.UserId] or 1) + 1
        end
    end

    return chosenPlayer
end

function Roulette.playRouletteAnimation(targetPlayer)
    print("Roulette: Începem animația ruletă către", targetPlayer.Name)
    local hammerSpawn = Workspace:WaitForChild("HammerSpawn", 10)
    if not hammerSpawn then
        warn("Eroare: Nu am găsit folderul HammerSpawn în Workspace!")
        task.wait(3) -- Wait out the time anyway
        return
    end

    -- Look for the HammerModel inside the folder
    local hammerModel = hammerSpawn:WaitForChild("HammerModel", 10)
    local isModel = hammerModel:IsA("Model")
    local isBasePart = hammerModel:IsA("BasePart")

    if not isModel and not isBasePart then
        warn("Eroare: HammerModel nu este nici Model, nici BasePart/Union!")
        task.wait(3)
        return
    end

    if isModel then
        if not hammerModel.PrimaryPart then
            local anyPart = hammerModel:FindFirstChildWhichIsA("BasePart", true)
            if anyPart then
                hammerModel.PrimaryPart = anyPart
            else
                warn("Eroare: HammerModel nu are niciun BasePart pentru a fi folosit ca PrimaryPart!")
                task.wait(3)
                return
            end
        end

        -- Fix physics interference: ensure all parts are firmly anchored
        for _, part in ipairs(hammerModel:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = true
                part.CanCollide = false
            end
        end
    elseif isBasePart then
        hammerModel.Anchored = true
        hammerModel.CanCollide = false
    end

    -- Tell the idle spinner to stop fighting us
    hammerModel:SetAttribute("IsRoulette", true)

    local initialPivot = isModel and hammerModel:GetPivot() or hammerModel.CFrame
    local targetPos = Vector3.new(0,0,0)

    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        targetPos = targetPlayer.Character.HumanoidRootPart.Position
    end

    -- For a flat-laying object, the "LookAt" logic changes.
    -- We create a CFrame that faces the target, and THEN tilt it 90 degrees on X to lie flat.
    local baseLookAtCFrame = CFrame.new(initialPivot.Position, Vector3.new(targetPos.X, initialPivot.Position.Y, targetPos.Z))
    local targetPivot = baseLookAtCFrame * CFrame.Angles(math.rad(90), 0, 0)

    local SPIN_DURATION = 3
    local startTime = tick()

    -- Extract the Z-axis rotation (spin on the ground) from the initial and target CFrames
    -- Because it's tilted 90deg on X, "yaw" is now effectively the Z axis relative to local space
    local _, startYaw, _ = (initialPivot * CFrame.Angles(math.rad(-90), 0, 0)):ToEulerAnglesYXZ()
    local _, targetYaw, _ = baseLookAtCFrame:ToEulerAnglesYXZ()

    -- Adjust target yaw so the tip of the hammer points to the player.
    -- Depending on the model's import orientation, we offset by 90 degrees.
    targetYaw = targetYaw + math.rad(-90)

    local yawDiff = (targetYaw - startYaw + math.pi) % (2 * math.pi) - math.pi
    local totalSpins = 5
    local totalYawToTravel = yawDiff + (math.pi * 2 * totalSpins)

    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        local elapsed = tick() - startTime
        local alpha = math.clamp(elapsed / SPIN_DURATION, 0, 1)

        -- Ease out cubic
        local easeOutAlpha = 1 - math.pow(1 - alpha, 3)

        if elapsed >= SPIN_DURATION then
            connection:Disconnect()
            if isModel then
                hammerModel:PivotTo(targetPivot)
            else
                hammerModel.CFrame = targetPivot
            end
            -- Allow idle spinner to resume
            hammerModel:SetAttribute("IsRoulette", false)
            return
        end

        local currentYaw = startYaw + (totalYawToTravel * easeOutAlpha)

        -- Build the CFrame: Start at position, apply yaw rotation, then tilt 90deg to lie flat
        local finalPivot = CFrame.new(initialPivot.Position) * CFrame.Angles(0, currentYaw, 0) * CFrame.Angles(math.rad(90), 0, 0)

        -- To prevent fighting with the idle animation, we override its CFrame entirely here
        if isModel then
            hammerModel:PivotTo(finalPivot)
        else
            hammerModel.CFrame = finalPivot
        end
    end)

    task.wait(SPIN_DURATION)
end

return Roulette

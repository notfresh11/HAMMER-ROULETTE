local Roulette = {}
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

function Roulette.playRouletteAnimation(targetPlayer, currentHammerInstance)
    print("Roulette: Începem animația ruletă către", targetPlayer.Name)

    if not currentHammerInstance then
        warn("Roulette Eroare: Nu a fost pasat niciun ciocan vizual pentru animație!")
        task.wait(3)
        return
    end

    local hammerModel = currentHammerInstance
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

    local SPIN_DURATION = 3
    local startTime = tick()

    -- UI Setup
    local showCountdownEvent = ReplicatedStorage:WaitForChild("ShowCountdownEvent")
    local showTextEvent = ReplicatedStorage:WaitForChild("ShowTextEvent")
    local hideTextEvent = ReplicatedStorage:WaitForChild("HideTextEvent")
    local COUNTDOWN_SOUND = "rbxassetid://110001162763213"
    local START_SOUND = "rbxassetid://77736543307386"

    -- Countdown loop for the Roulette
    task.spawn(function()
        local startTick = os.clock()
        local i = SPIN_DURATION
        while i >= 1 do
            if os.clock() - startTick >= (SPIN_DURATION - i) then
                local color = Color3.new(1, 0, 0)
                if i == 2 then color = Color3.new(1, 1, 0)
                elseif i == 1 then color = Color3.new(0, 1, 0) end

                showCountdownEvent:FireAllClients(i, color, COUNTDOWN_SOUND)
                i = i - 1
            end
            task.wait()
        end
    end)

    -- We create a flat direction vector pointing towards the target player
    local dirToTarget = (Vector3.new(targetPos.X, initialPivot.Position.Y, targetPos.Z) - initialPivot.Position).Unit
    if dirToTarget.Magnitude == 0 then dirToTarget = Vector3.new(0, 0, -1) end

    -- We calculate the exact angle to the target player in global space
    local targetAngleGlobal = math.atan2(-dirToTarget.Z, dirToTarget.X)

    -- Find the 'Tip' part if it exists to calculate its current direction
    local tipPart = hammerModel:FindFirstChild("Tip", true)

    local tipDirectionAngle = 0
    if tipPart then
        -- Find the current global direction of the tip relative to the pivot center on the XZ plane
        -- The hammer is already lying flat, so the Tip is displaced horizontally from the center.
        local tipDir = (Vector3.new(tipPart.Position.X, initialPivot.Position.Y, tipPart.Position.Z) - initialPivot.Position).Unit
        -- Check if it's not a zero vector (which happens if Tip is perfectly above/below center)
        if tipDir.Magnitude > 0.001 then
            tipDirectionAngle = math.atan2(-tipDir.Z, tipDir.X)
        end
    else
        -- Fallback: If no Tip, we just assume its local Top/Up vector is "forward" when lying flat.
        -- But because it's rotated 90 on X, its local Y axis points along global Z.
        tipDirectionAngle = math.atan2(-initialPivot.UpVector.Z, initialPivot.UpVector.X)
    end

    -- Calculate how much we need to rotate globally on the Y axis to align the tip to the target
    -- Start by finding the shortest angular distance
    local angleDiff = (targetAngleGlobal - tipDirectionAngle)

    -- Normalize angle difference to be between -pi and pi
    angleDiff = (angleDiff + math.pi) % (2 * math.pi) - math.pi

    local totalSpins = 5
    -- The total rotation we want to apply around the global Y axis
    local totalYawToTravel = angleDiff + (math.pi * 2 * totalSpins)

    -- Because the hammer is already flat on the ground (from MapManager and Idle animation),
    -- initialPivot represents a flat hammer. We simply want to rotate this entire flat structure
    -- around the global Y-axis passing through its center.

    -- Target Pivot is the initial pivot rotated globally around its position
    local targetFlatPivot = CFrame.new(initialPivot.Position) * CFrame.Angles(0, totalYawToTravel, 0) * (initialPivot - initialPivot.Position)

    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        local elapsed = tick() - startTime
        local alpha = math.clamp(elapsed / SPIN_DURATION, 0, 1)

        -- Ease out cubic
        local easeOutAlpha = 1 - math.pow(1 - alpha, 3)

        if elapsed >= SPIN_DURATION then
            connection:Disconnect()
            if isModel then
                hammerModel:PivotTo(targetFlatPivot)
            else
                hammerModel.CFrame = targetFlatPivot
            end
            -- Allow idle spinner to resume
            hammerModel:SetAttribute("IsRoulette", false)
            return
        end

        local currentYaw = totalYawToTravel * easeOutAlpha

        -- Create a pure global Y-axis rotation and apply it to the initial orientation.
        local rotationStep = CFrame.Angles(0, currentYaw, 0)
        local finalPivot = CFrame.new(initialPivot.Position) * rotationStep * (initialPivot - initialPivot.Position)

        -- To prevent fighting with the idle animation, we override its CFrame entirely here
        if isModel then
            hammerModel:PivotTo(finalPivot)
        else
            hammerModel.CFrame = finalPivot
        end
    end)

    task.wait(SPIN_DURATION)

    -- Finalize UI with the chosen player's name
    showTextEvent:FireAllClients(targetPlayer.Name .. " has the Mace !", Color3.new(0, 1, 0), START_SOUND)
    task.delay(2, function()
        hideTextEvent:FireAllClients()
    end)
end

return Roulette

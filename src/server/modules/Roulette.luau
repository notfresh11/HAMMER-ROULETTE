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

function Roulette.selectMaceBearers(activePlayers, count)
    count = count or 1
    if #activePlayers == 0 then return {} end

    local numToPick = math.min(count, #activePlayers)
    local chosenPlayers = {}
    local availablePlayers = {}
    for _, p in ipairs(activePlayers) do
        table.insert(availablePlayers, p)
    end

    for i = 1, numToPick do
        local totalWeight = 0
        for _, player in ipairs(availablePlayers) do
            local weight = playerWeights[player.UserId] or 1
            totalWeight = totalWeight + weight
        end

        local randomValue = math.random() * totalWeight
        local chosenPlayer = nil
        local currentSum = 0
        local chosenIndex = 1

        for idx, player in ipairs(availablePlayers) do
            local weight = playerWeights[player.UserId] or 1
            currentSum = currentSum + weight
            if randomValue <= currentSum then
                chosenPlayer = player
                chosenIndex = idx
                break
            end
        end

        if not chosenPlayer then
            chosenIndex = math.random(1, #availablePlayers)
            chosenPlayer = availablePlayers[chosenIndex]
        end

        table.insert(chosenPlayers, chosenPlayer)
        table.remove(availablePlayers, chosenIndex)

        -- Update weights
        for _, player in ipairs(activePlayers) do
            if player == chosenPlayer then
                playerWeights[player.UserId] = 1
            else
                playerWeights[player.UserId] = (playerWeights[player.UserId] or 1) + 1
            end
        end
    end

    return chosenPlayers
end

function Roulette.playRouletteAnimation(targetPlayers, currentHammerInstances)
    if type(targetPlayers) ~= "table" then targetPlayers = {targetPlayers} end
    if type(currentHammerInstances) ~= "table" then currentHammerInstances = {currentHammerInstances} end

    local names = {}
    for _, tp in ipairs(targetPlayers) do table.insert(names, tp.Name) end
    print("Roulette: Începem animația ruletă către", table.concat(names, ", "))

    local animations = {}

    for i, targetPlayer in ipairs(targetPlayers) do
        local hammerModel = currentHammerInstances[i]
        if not hammerModel then break end

        local isModel = hammerModel:IsA("Model")
        local isBasePart = hammerModel:IsA("BasePart")

        if isModel then
            if not hammerModel.PrimaryPart then
                hammerModel.PrimaryPart = hammerModel:FindFirstChildWhichIsA("BasePart", true)
            end
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

        hammerModel:SetAttribute("IsRoulette", true)

        local initialPivot = isModel and hammerModel:GetPivot() or hammerModel.CFrame
        local targetPos = Vector3.new(0,0,0)
        if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            targetPos = targetPlayer.Character.HumanoidRootPart.Position
        end

        local dirToTarget = (Vector3.new(targetPos.X, initialPivot.Position.Y, targetPos.Z) - initialPivot.Position).Unit
        if dirToTarget.Magnitude == 0 then dirToTarget = Vector3.new(0, 0, -1) end
        local targetAngleGlobal = math.atan2(-dirToTarget.Z, dirToTarget.X)

        local tipPart = hammerModel:FindFirstChild("Tip", true)
        local tipDirectionAngle = 0
        if tipPart then
            local tipDir = (Vector3.new(tipPart.Position.X, initialPivot.Position.Y, tipPart.Position.Z) - initialPivot.Position).Unit
            if tipDir.Magnitude > 0.001 then
                tipDirectionAngle = math.atan2(-tipDir.Z, tipDir.X)
            end
        else
            tipDirectionAngle = math.atan2(-initialPivot.UpVector.Z, initialPivot.UpVector.X)
        end

        local angleDiff = (targetAngleGlobal - tipDirectionAngle)
        angleDiff = (angleDiff + math.pi) % (2 * math.pi) - math.pi
        local totalYawToTravel = angleDiff + (math.pi * 2 * 5)

        local targetFlatPivot = CFrame.new(initialPivot.Position) * CFrame.Angles(0, angleDiff, 0) * (initialPivot - initialPivot.Position)

        table.insert(animations, {
            hammer = hammerModel,
            isModel = isModel,
            initialPivot = initialPivot,
            totalYawToTravel = totalYawToTravel,
            targetFlatPivot = targetFlatPivot
        })
    end

    local SPIN_DURATION = 3
    local startTime = tick()

    local showCountdownEvent = ReplicatedStorage:WaitForChild("ShowCountdownEvent")
    local showTextEvent = ReplicatedStorage:WaitForChild("ShowTextEvent")
    local hideTextEvent = ReplicatedStorage:WaitForChild("HideTextEvent")
    local COUNTDOWN_SOUND = "rbxassetid://110001162763213"
    local START_SOUND = "rbxassetid://77736543307386"

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

    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        local elapsed = tick() - startTime
        local alpha = math.clamp(elapsed / SPIN_DURATION, 0, 1)
        local easeOutAlpha = 1 - math.pow(1 - alpha, 3)

        if elapsed >= SPIN_DURATION then
            connection:Disconnect()
            for _, anim in ipairs(animations) do
                if anim.isModel then
                    anim.hammer:PivotTo(anim.targetFlatPivot)
                else
                    anim.hammer.CFrame = anim.targetFlatPivot
                end
                anim.hammer:SetAttribute("IsRoulette", false)
            end
            return
        end

        for _, anim in ipairs(animations) do
            local currentYaw = anim.totalYawToTravel * easeOutAlpha
            local rotationStep = CFrame.Angles(0, currentYaw, 0)
            local finalPivot = CFrame.new(anim.initialPivot.Position) * rotationStep * (anim.initialPivot - anim.initialPivot.Position)

            if anim.isModel then
                anim.hammer:PivotTo(finalPivot)
            else
                anim.hammer.CFrame = finalPivot
            end
        end
    end)

    task.wait(SPIN_DURATION)

    local ModifierManager = require(script.Parent.ModifierManager)
    local msg = table.concat(names, " & ") .. " got the Mace!"

    if ModifierManager.IsModifierActive("Hot Potato") then
        msg = table.concat(names, " & ") .. " got the Hot Potato!"
    elseif ModifierManager.IsModifierActive("Streamsnipe") then
        msg = table.concat(names, " & ") .. " did NOT get the Mace!"
    end

    showTextEvent:FireAllClients(msg, Color3.new(0, 1, 0), START_SOUND)
    task.delay(2, function()
        hideTextEvent:FireAllClients()
    end)
end

return Roulette

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

    -- Find the 'Tip' part if it exists to precisely calculate the forward vector
    local tipPart = hammerModel:FindFirstChild("Tip", true)

    -- Noi vrem ca Y-ul (înălțimea) să rămână neschimbat la hammer
    local flatTargetPos = Vector3.new(targetPos.X, initialPivot.Position.Y, targetPos.Z)

    -- Creăm un CFrame care "se uită" direct la jucător (asta aliniază fața Z negativă)
    local targetLookCFrame = CFrame.lookAt(initialPivot.Position, flatTargetPos)

    -- Acum ajustăm tilt-ul pentru că ciocanul zace pe jos.
    -- Dacă e modelat ca un baros în picioare (pe Y), îl lăsăm jos cu 90 de grade:
    local targetPivot = targetLookCFrame * CFrame.Angles(math.rad(90), 0, 0)

    -- Dacă are un element numit 'Tip', îl folosim ca să corectăm orice rotație ciudată a modelatorului
    if tipPart then
        -- Ne dăm seama unde este 'Tip' în interiorul CFrame-ului proaspăt calculat
        local localTipPos = targetPivot:ToObjectSpace(tipPart.CFrame).Position

        -- Dacă Tip-ul nu este pe axa Z (în față), ci e, de exemplu, pe X... rotim compensatoriu
        -- Unghiul 2D între (Z=în față, X=dreapta) pe planul podelei modelului
        local offsetAngle = math.atan2(localTipPos.X, -localTipPos.Z)

        -- Compensăm axa verticală locală care îl rotește fix pe pământ (care după tilt e axa Z, dar aplicăm Y înainte de tilt pt simplitate)
        targetPivot = targetLookCFrame * CFrame.Angles(0, -offsetAngle, 0) * CFrame.Angles(math.rad(90), 0, 0)
    end

    -- Extragem unghiul de start pentru a face tranziția
    -- Din cauza rotației pe X, rotația de spinning în plan se face acum pe axa Z global
    -- Vom obține Y (yaw) înainte să fie lăsat pe jos
    local startLookCFrame = initialPivot * CFrame.Angles(math.rad(-90), 0, 0)
    local _, startYaw, _ = startLookCFrame:ToEulerAnglesYXZ()
    local _, targetYaw, _ = (targetPivot * CFrame.Angles(math.rad(-90), 0, 0)):ToEulerAnglesYXZ()

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

        -- Pivotul final per cadru
        local finalLookCFrame = CFrame.new(initialPivot.Position) * CFrame.Angles(0, currentYaw, 0)

        -- Adăugăm compensația Tip dacă există, altfel doar tilt-ul de 90 grade
        local currentPivot = finalLookCFrame * CFrame.Angles(math.rad(90), 0, 0)
        if tipPart then
            local localTipPos = currentPivot:ToObjectSpace(tipPart.CFrame).Position
            local offsetAngle = math.atan2(localTipPos.X, -localTipPos.Z)
            currentPivot = finalLookCFrame * CFrame.Angles(0, -offsetAngle, 0) * CFrame.Angles(math.rad(90), 0, 0)
        end

        if isModel then
            hammerModel:PivotTo(currentPivot)
        else
            hammerModel.CFrame = currentPivot
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

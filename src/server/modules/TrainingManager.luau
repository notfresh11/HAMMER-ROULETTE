local TrainingManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local MaceMechanic = require(script.Parent.MaceMechanic)

-- Setări
local MAX_DUMMIES = 10
local DUMMY_RESPAWN_TIME = 2

local platformPart = nil
local zonePart = nil
local activeDummies = {}

local playersInTraining = {} -- [Player] = true

local function getTrainingParts()
    if platformPart and zonePart then return platformPart, zonePart end
    local wholeMap = Workspace:FindFirstChild("WholeMap")
    if wholeMap then
        local trainingFolder = wholeMap:FindFirstChild("Training")
        if trainingFolder then
            platformPart = trainingFolder:FindFirstChild("Platform")
            zonePart = trainingFolder:FindFirstChild("Zone")
        end
    end
    return platformPart, zonePart
end

local function getValidRandomPosition(pForm)
    local size = pForm.Size
    local maxAttempts = 15
    local MIN_DISTANCE = 5 -- Dummies should be at least 5 studs apart

    for attempt = 1, maxAttempts do
        -- Alegem un punct aleatoriu in spatiul LOCAL al platformei (ignoram rotatiile momentan)
        -- Daca platforma e pusa pe jos, X si Z sunt de obicei lungimea/latimea, iar Y este inaltimea (grosimea).
        -- Vom selecta un punct fix in centrul "grosimii" platformei ca sa fim siguri ca e in ea.
        local localX = (math.random() - 0.5) * (size.X - 4)
        local localZ = (math.random() - 0.5) * (size.Z - 4)

        -- Calculam pozitia globala (World Space) a acestui punct aflat fix in centrul prmei
        local pointInWorld = (pForm.CFrame * CFrame.new(localX, 0, localZ)).Position

        -- Acum ne mutam la o inaltime globala ABSOLUTA deasupra acelui punct
        local rayOrigin = pointInWorld + Vector3.new(0, 50, 0)

        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {pForm}
        raycastParams.FilterType = Enum.RaycastFilterType.Include

        -- Tragem o raza ABSOLUTA in jos
        local raycastResult = Workspace:Raycast(rayOrigin, Vector3.new(0, -100, 0), raycastParams)

        if raycastResult then
            -- Pozitia pe Y exact pe platforma + jumatate din inaltimea tipica a unui Dummy (aprox 3 studs ptr HumanoidRootPart)
            local finalPos = raycastResult.Position + Vector3.new(0, 3, 0)

            -- Calculam un CFrame care doar se uita in fata, pentru a evita spawnarea in diagonala din cauza rotatiei platformei
            -- Pastram rotatia Y a platformei doar vizual daca dorim, dar orientarea simpla este mai sigura.
            local _, yAngle, _ = pForm.CFrame:ToEulerAnglesYXZ()
            local pivotCFrame = CFrame.new(finalPos) * CFrame.Angles(0, yAngle, 0)

            local tooClose = false
            for _, otherDummy in ipairs(activeDummies) do
                if otherDummy and otherDummy.PrimaryPart then
                    local otherPos = otherDummy:GetPivot().Position
                    if (finalPos - otherPos).Magnitude < MIN_DISTANCE then
                        tooClose = true
                        break
                    end
                end
            end

            if not tooClose then
                return pivotCFrame
            end
        end
    end
    warn("TrainingManager: Failed to find valid position for Dummy!")
    return nil
end

local function spawnDummy()
    local pForm, _ = getTrainingParts()
    if not pForm then return end

    local pivotCFrame = getValidRandomPosition(pForm)
    if not pivotCFrame then
        -- Daca nu gasim loc, mai incercam putin mai incolo
        task.delay(1, spawnDummy)
        return
    end

    local dummyTemplate = ServerStorage:FindFirstChild("Dummy")
    if not dummyTemplate then
        warn("TrainingManager: Missing 'Dummy' model in ServerStorage!")
        return
    end

    local dummy = dummyTemplate:Clone()
    dummy.Parent = Workspace
    dummy:PivotTo(pivotCFrame)

    table.insert(activeDummies, dummy)

    local humanoid = dummy:FindFirstChild("Humanoid")
    if humanoid then
        local connection
        connection = humanoid.Died:Connect(function()
            if connection then connection:Disconnect() end

            -- Elimina imediat din tabel in mod sigur
            local idx = table.find(activeDummies, dummy)
            if idx then
                table.remove(activeDummies, idx)
            end

            -- Distruge dummy-ul complet si sigur din memorie
            task.delay(0.5, function()
                if dummy then
                    dummy:Destroy()
                end
            end)

            -- Forteaza respawn-ul dupa DUMMY_RESPAWN_TIME
            task.delay(DUMMY_RESPAWN_TIME, function()
                -- Daca meciul nu s-a oprit si mai e loc, spawnam altul.
                if #activeDummies < MAX_DUMMIES then
                    spawnDummy()
                end
            end)
        end)
    end
end

local function setupDummies()
    local currentCount = #activeDummies
    for i = currentCount + 1, MAX_DUMMIES do
        spawnDummy()
    end
end

-- Cleanup Training if Match starts / Player leaves
function TrainingManager.removePlayerFromTraining(player)
    if playersInTraining[player] then
        playersInTraining[player] = nil
        player:SetAttribute("InTraining", false)

        if MaceMechanic.playerCleanups[player] then
            MaceMechanic.playerCleanups[player]()
        end
        print("TrainingManager: " .. player.Name .. " a fost scos din training.")
    end
end

function TrainingManager.Start()
    print("TrainingManager: Initializing...")

    -- Așteptăm ca platforma să existe (dacă e cazul, deși ai menționat că deja există)
    task.spawn(function()
        local attempts = 0
        local pForm, zPart = getTrainingParts()
        while not (pForm and zPart) and attempts < 10 do
            task.wait(1)
            pForm, zPart = getTrainingParts()
            attempts += 1
        end

        if not pForm or not zPart then
            warn("TrainingManager: Nu s-au putut gasi Workspace.WholeMap.Training.Platform sau Zone")
            return
        end

        setupDummies()

        -- Loop de verificare
        RunService.Heartbeat:Connect(function()
            local currentPlatform, currentZone = getTrainingParts()
            if not currentZone then return end

            -- Set up params to search only for player characters
            local chars = {}
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then table.insert(chars, player.Character) end
            end

            local params = OverlapParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            params.FilterDescendantsInstances = chars

            local partsInZone = Workspace:GetPartsInPart(currentZone, params)
            local currentPlayersInZone = {}

            for _, part in ipairs(partsInZone) do
                local char = part:FindFirstAncestorOfClass("Model")
                if char then
                    local player = Players:GetPlayerFromCharacter(char)
                    if player then
                        -- Dacă jucătorul este în meci, îl ignorăm complet. Niciodată nu intră în training.
                        if not player:GetAttribute("InMatch") then
                            currentPlayersInZone[player] = true
                        end
                    end
                end
            end

            -- Verificăm cine a intrat
            for player, _ in pairs(currentPlayersInZone) do
                if not playersInTraining[player] then
                    playersInTraining[player] = true
                    player:SetAttribute("InTraining", true)
                    print("TrainingManager: " .. player.Name .. " a intrat in zona de training.")

                    -- Start mechanic (Training mode)
                    MaceMechanic.startMechanic(player, function()
                        -- Callback for unexpected end if needed
                    end, true)
                end
            end

            -- Verificăm cine a iesit
            for player, _ in pairs(playersInTraining) do
                if not currentPlayersInZone[player] then
                    TrainingManager.removePlayerFromTraining(player)
                end
            end
        end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        TrainingManager.removePlayerFromTraining(player)
    end)
end

return TrainingManager

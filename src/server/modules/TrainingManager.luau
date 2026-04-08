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
    local maxAttempts = 10
    local MIN_DISTANCE = 5 -- Dummies should be at least 5 studs apart

    for attempt = 1, maxAttempts do
        local rx = (math.random() - 0.5) * (size.X - 4)
        local rz = (math.random() - 0.5) * (size.Z - 4)

        -- Raycast de sus in jos pentru a gasi inaltimea corecta a platformei
        -- Folosim Y de sus + 50 pentru a fi siguri ca tragem de deasupra
        local rayOriginCFrame = pForm.CFrame * CFrame.new(rx, (size.Y / 2) + 50, rz)
        local rayOrigin = rayOriginCFrame.Position

        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {pForm}
        raycastParams.FilterType = Enum.RaycastFilterType.Include

        local raycastResult = Workspace:Raycast(rayOrigin, Vector3.new(0, -100, 0), raycastParams)

        if raycastResult then
            -- Pozitia pe Y exact pe platforma + jumate din inaltimea tipica a unui Dummy (aprox 3 studs ptr HumanoidRootPart)
            local finalPos = raycastResult.Position + Vector3.new(0, 3, 0)
            -- Mentinem orientarea pe Y a platformei ca sa nu stea intr-o parte
            local pivotCFrame = CFrame.new(finalPos) * CFrame.Angles(0, pForm.CFrame.Rotation.Y, 0)

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
        humanoid.Died:Connect(function()
            local idx = table.find(activeDummies, dummy)
            if idx then table.remove(activeDummies, idx) end

            Debris:AddItem(dummy, 1) -- Curățare după mort

            task.delay(DUMMY_RESPAWN_TIME, function()
                -- Verificam cate dummy uri mai sunt active sau sunt in curs de respawn
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

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
local trainingZoneParams = nil
local activeDummies = {}

local playersInTraining = {} -- [Player] = true

local function getPlatform()
    if platformPart then return platformPart end
    local wholeMap = Workspace:FindFirstChild("WholeMap")
    if wholeMap then
        local trainingFolder = wholeMap:FindFirstChild("Training")
        if trainingFolder then
            platformPart = trainingFolder:FindFirstChild("Platform")
            if platformPart then
                trainingZoneParams = OverlapParams.new()
                trainingZoneParams.FilterType = Enum.RaycastFilterType.Include
                -- Filterul va include jucătorii, aşa că nu setăm FilterDescendantsInstances încă (e creat dinamic per verificare)
            end
        end
    end
    return platformPart
end

local function spawnDummy()
    local pForm = getPlatform()
    if not pForm then return end

    local dummyTemplate = ServerStorage:FindFirstChild("Dummy")
    if not dummyTemplate then
        warn("TrainingManager: Missing 'Dummy' model in ServerStorage!")
        return
    end

    local dummy = dummyTemplate:Clone()
    dummy.Parent = Workspace

    -- Găsim poziție random
    local size = pForm.Size
    local rx = (math.random() - 0.5) * (size.X - 4) -- Margin safety
    local rz = (math.random() - 0.5) * (size.Z - 4)
    local ry = (size.Y / 2) + 3

    local pivotCFrame = pForm.CFrame * CFrame.new(rx, ry, rz)
    dummy:PivotTo(pivotCFrame)

    table.insert(activeDummies, dummy)

    local humanoid = dummy:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.Died:Connect(function()
            local idx = table.find(activeDummies, dummy)
            if idx then table.remove(activeDummies, idx) end

            Debris:AddItem(dummy, 1) -- Curățare după mort

            task.delay(DUMMY_RESPAWN_TIME, function()
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
        while not getPlatform() and attempts < 10 do
            task.wait(1)
            attempts += 1
        end

        if not getPlatform() then
            warn("TrainingManager: Nu s-a putut gasi Workspace.WholeMap.Training.Platform")
            return
        end

        setupDummies()

        -- Loop de verificare
        RunService.Heartbeat:Connect(function()
            local pForm = getPlatform()
            if not pForm then return end

            -- Set up params to search only for player characters
            local chars = {}
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then table.insert(chars, player.Character) end
            end

            local params = OverlapParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            params.FilterDescendantsInstances = chars

            local partsInZone = Workspace:GetPartBoundsInBox(pForm.CFrame, pForm.Size, params)
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

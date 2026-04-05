local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create the RemoteEvent FIRST, before any scripts try to wait for it or require modules
local maceEventName = "MaceAttackEvent"
if not ReplicatedStorage:FindFirstChild(maceEventName) then
    local event = Instance.new("RemoteEvent")
    event.Name = maceEventName
    event.Parent = ReplicatedStorage
end

local maceBounceEventName = "MaceBounceEvent"
if not ReplicatedStorage:FindFirstChild(maceBounceEventName) then
    local event = Instance.new("RemoteEvent")
    event.Name = maceBounceEventName
    event.Parent = ReplicatedStorage
end

-- UI Events
-- UI Events and VFX
local uiEvents = {"ShowCountdownEvent", "ShowTextEvent", "HideTextEvent", "VfxEvent", "ToggleAFKEvent", "ToggleMainUIEvent", "UpdateMatchmakingUIEvent"}
for _, evName in ipairs(uiEvents) do
    if not ReplicatedStorage:FindFirstChild(evName) then
        local ev = Instance.new("RemoteEvent")
        ev.Name = evName
        ev.Parent = ReplicatedStorage
    end
end

local toggleAfkEvent = ReplicatedStorage:WaitForChild("ToggleAFKEvent")
toggleAfkEvent.OnServerEvent:Connect(function(player, isAFK)
    if typeof(isAFK) == "boolean" then
        player:SetAttribute("IsAFK", isAFK)
    end
end)

local Matchmaking = require(script.Parent.modules.Matchmaking)
local Roulette = require(script.Parent.modules.Roulette)
local MaceMechanic = require(script.Parent.modules.MaceMechanic)
local MapManager = require(script.Parent.modules.MapManager)
local DataManager = require(script.Parent.modules.DataManager)
local ProgressionManager = require(script.Parent.modules.ProgressionManager)
local AntiCheat = require(script.Parent.modules.AntiCheat)

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Hook up DataManager to handle player connections
Players.PlayerAdded:Connect(function(player)
    DataManager.loadPlayerData(player)
    -- Sync initial values to UI
    task.spawn(function()
        -- Wait slightly to allow client UI to initialize
        task.wait(2)
        ProgressionManager.SyncDataToClient(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    DataManager.savePlayerData(player)
end)

game:BindToClose(function()
    print("Server shutting down. Saving all data...")
    for _, player in ipairs(Players:GetPlayers()) do
        DataManager.savePlayerData(player)
    end
end)

-- Helper function to lock/unlock player movement during roulette
local function setPlayersAnchored(playersList, isAnchored)
    for _, player in ipairs(playersList) do
        if player and player.Character then
            local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                rootPart.Anchored = isAnchored
            end
        end
    end
end

-- Helper function to toggle the visual hammer
local function setHammerVisibility(hammerModel, visible)
    if hammerModel then
        local transparency = visible and 0 or 1
        if hammerModel:IsA("Model") then
            for _, part in ipairs(hammerModel:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Transparency = transparency
                end
            end
        elseif hammerModel:IsA("BasePart") then
            hammerModel.Transparency = transparency
        end
    end
end

-- Function to initialize map elements (make spawns invisible)
local function setupMap()
    MapManager.hideAllMaps()
end

-- Spinner Connection for active hammer
local currentSpinnerConnection = nil

-- Main Game Loop
local function gameLoop()
    local Players = game:GetService("Players")

    while true do
        -- 1. ALEGEREA ȘI SPAWNAREA HĂRȚII
        print("MainLoop: Pregătim o nouă hartă...")
        local currentMap, currentHammer = MapManager.chooseAndSpawnMap()

        -- Dacă nu e nicio hartă validă, așteptăm un pic și reîncercăm
        if not currentMap then
            warn("Nu s-a putut alege harta. Se va reîncerca în scurt timp...")
            task.wait(3)
        else
            -- Repornește animația de idle a ciocanului pe noul ciocan
            if currentSpinnerConnection then currentSpinnerConnection:Disconnect() end
            if currentHammer then
                currentSpinnerConnection = RunService.Heartbeat:Connect(function(dt)
                    if currentHammer and currentHammer.Parent then
                        if not currentHammer:GetAttribute("IsRoulette") then
                            if currentHammer:IsA("Model") and currentHammer.PrimaryPart then
                                local currentPivot = currentHammer:GetPivot()
                                currentHammer:PivotTo(currentPivot * CFrame.Angles(0, 0, math.rad(90 * dt)))
                            elseif currentHammer:IsA("BasePart") then
                                local currentCFrame = currentHammer.CFrame
                                currentHammer.CFrame = currentCFrame * CFrame.Angles(0, 0, math.rad(90 * dt))
                            end
                        end
                    end
                end)
            end

            print("MainLoop: Harta a fost spawnată. Așteptăm jucători pentru un NOU MECI...")
            local success = Matchmaking.waitForPlayers()

            if success then
            -- Așteptăm cele 2 secunde cât timp este afișat mesajul "The Game Has Started"
            task.wait(2)

            -- Meciul începe, înregistrăm toți jucătorii care participă la acest meci
            local activePlayers = Matchmaking.getActivePlayers()
            print("MainLoop: Meciul a început cu " .. #activePlayers .. " jucători!")

            -- Rewards for participation & Hide UI
            local toggleMainUiEvent = ReplicatedStorage:FindFirstChild("ToggleMainUIEvent")
            for _, player in ipairs(activePlayers) do
                ProgressionManager.ProcessMatchParticipation(player)
                if toggleMainUiEvent then
                    toggleMainUiEvent:FireClient(player, false)
                end
            end

            -- Handle disconnects during the match to prevent softlocking
            local disconnectConnection = Players.PlayerRemoving:Connect(function(leavingPlayer)
                local idx = table.find(activePlayers, leavingPlayer)
                if idx then
                    table.remove(activePlayers, idx)
                    print("MainLoop: " .. leavingPlayer.Name .. " a părăsit serverul și a fost eliminat din meci.")
                end
            end)

            -- Bucla de Runde (cât timp sunt cel puțin 2 supraviețuitori în meci)
            while #activePlayers > 1 do
                print("MainLoop: Începem o NOUĂ RUNDĂ cu " .. #activePlayers .. " supraviețuitori.")

                -- Ensure hammer is visible at round start
                setHammerVisibility(currentHammer, true)

                Matchmaking.teleportPlayersToSpawns(activePlayers, currentMap)

                -- Block player movement while roulette spins
                setPlayersAnchored(activePlayers, true)

                task.wait(1) -- small delay for physics/camera to settle

                local chosenPlayer = Roulette.selectMaceBearer(activePlayers)
                if chosenPlayer then
                    Roulette.playRouletteAnimation(chosenPlayer, currentHammer)

                    -- Unblock movement now that roulette has finished
                    setPlayersAnchored(activePlayers, false)

                    -- Hide visual hammer because the player picked it up
                    setHammerVisibility(currentHammer, false)

                    local roundEnded = false
                    local victimDied = false

                    local function onRoundEnd()
                        roundEnded = true
                    end

                    -- Conectăm un event rapid ca să știm dacă cineva din activePlayers a murit în această rundă
                    local deathConnections = {}
                    for _, player in ipairs(activePlayers) do
                        if player.Character and player.Character:FindFirstChild("Humanoid") then
                            table.insert(deathConnections, player.Character.Humanoid.Died:Connect(function()
                                -- Reset streaks on death
                                ProgressionManager.ResetStreaks(player)

                                -- Scoatem jucătorul mort din lista de supraviețuitori ai meciului
                                local idx = table.find(activePlayers, player)
                                if idx then
                                    table.remove(activePlayers, idx)
                                    print("MainLoop: " .. player.Name .. " a fost ELIMINAT din meci!")
                                    -- Afișăm MAINUI din nou pentru cel eliminat
                                    if toggleMainUiEvent then
                                        toggleMainUiEvent:FireClient(player, true)
                                    end
                                end
                            end))
                        end
                    end

                    MaceMechanic.startMechanic(chosenPlayer, onRoundEnd)

                    -- Wait until the round is marked as ended (by missing or the attacker dying)
                    -- (If the attacker gets a kill, the mechanic keeps going and doesn't call onRoundEnd)
                    while not roundEnded do
                        -- If only 1 player is left active during the mechanic, force end
                        if #activePlayers <= 1 then
                            roundEnded = true
                        end
                        task.wait(0.5)
                    end

                    -- Reward survivals at round end
                    for _, activeP in ipairs(activePlayers) do
                        ProgressionManager.ProcessRoundSurvive(activeP)
                    end

                    -- Clean up death connections
                    for _, conn in ipairs(deathConnections) do
                        conn:Disconnect()
                    end
                    table.clear(deathConnections)

                    print("MainLoop: Runda s-a încheiat. Așteptăm cooldown 5 secunde...")
                    task.wait(5)
                else
                    warn("MainLoop: Nu s-a putut alege un jucător!")
                    task.wait(5)
                    break
                end
            end -- End of Round Loop

                if disconnectConnection then
                    disconnectConnection:Disconnect()
                end

                -- Force cleanup of the mechanic in case a round ended abruptly (e.g. opponent died, leaving only the attacker)
                if MaceMechanic.forceStopMechanic then
                    MaceMechanic.forceStopMechanic()
                end

                -- Dacă bucla de runde s-a terminat, înseamnă că meciul s-a încheiat (avem <= 1 supraviețuitori)
                if #activePlayers == 1 then
                    local winner = activePlayers[1]
                    print("MainLoop: MECIUL S-A TERMINAT! Câștigătorul este: " .. winner.Name)

                    -- Match Win Rewards
                    ProgressionManager.ProcessMatchWin(winner)

                    -- Reafișăm MAINUI pentru câștigător
                    if toggleMainUiEvent then
                        toggleMainUiEvent:FireClient(winner, true)
                    end

                    -- Teleport winner to a default roblox spawn location
                    if winner.Character and winner.Character:FindFirstChild("HumanoidRootPart") then
                        local rootPart = winner.Character.HumanoidRootPart
                        local spawns = {}

                        -- Search for any SpawnLocation in Workspace
                        for _, obj in ipairs(Workspace:GetDescendants()) do
                            if obj:IsA("SpawnLocation") then
                                table.insert(spawns, obj)
                            end
                        end

                        if #spawns > 0 then
                            -- Pick a random spawn point to teleport the winner
                            local chosenSpawn = spawns[math.random(1, #spawns)]
                            -- Y offset is half the spawn height + half character height roughly, 5 is a safe amount
                            rootPart.CFrame = chosenSpawn.CFrame * CFrame.new(0, chosenSpawn.Size.Y/2 + 3, 0)
                            print("MainLoop: Câștigătorul a fost teleportat la spawn.")
                        else
                            -- Fallback just in case no default spawn exists
                            rootPart.CFrame = CFrame.new(0, 50, 0)
                            warn("MainLoop: Nu s-a găsit niciun SpawnLocation în Workspace. S-a folosit coordonata de fallback.")
                        end
                    end
                else
                    print("MainLoop: MECIUL S-A TERMINAT! Nu există niciun câștigător valid.")
                end
                task.wait(5) -- Timp înainte de a porni un nou meci global
            else
                -- Not enough players during countdown, loop will restart
                task.wait(2)
            end
        end
    end
end

-- Start
AntiCheat.Start()
setupMap()
gameLoop()

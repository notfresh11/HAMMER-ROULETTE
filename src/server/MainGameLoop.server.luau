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
local HotPotatoMechanic = require(script.Parent.modules.HotPotatoMechanic)
local MapManager = require(script.Parent.modules.MapManager)
local DataManager = require(script.Parent.modules.DataManager)
local ProgressionManager = require(script.Parent.modules.ProgressionManager)
local AntiCheat = require(script.Parent.modules.AntiCheat)
local AbilityManager = require(script.Parent.modules.AbilityManager)
local TrainingManager = require(script.Parent.modules.TrainingManager)
local ModifierManager = require(script.Parent.modules.ModifierManager)

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

                -- Zero out physics momentum so they don't slide or float when unanchored
                if isAnchored then
                    rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
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

            ModifierManager.ClearAllModifiers()
            ModifierManager.PickAndAddModifier(#activePlayers)

            -- Apply baseline states (like Super Speed) to everyone entering the match
            for _, player in ipairs(activePlayers) do
                ModifierManager.ReapplyPlayerStates(player)
            end

            -- Rewards for participation & Hide UI
            local toggleMainUiEvent = ReplicatedStorage:FindFirstChild("ToggleMainUIEvent")
            for _, player in ipairs(activePlayers) do
                -- Asigură-te că scoatem jucătorul din starea de training dacă era acolo
                TrainingManager.removePlayerFromTraining(player)

                -- Reset ability cooldowns on match start
                AbilityManager.ResetCooldowns(player)

                player:SetAttribute("InMatch", true)
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
            local isFirstRound = true
            while #activePlayers > 1 do
                print("MainLoop: Începem o NOUĂ RUNDĂ cu " .. #activePlayers .. " supraviețuitori.")

                if not isFirstRound then
                    ModifierManager.ClearRoundModifiers()
                    ModifierManager.PickAndAddModifier(#activePlayers)
                end
                isFirstRound = false

                -- Ensure all players have correct baseline stats updated for the new modifier
                local isRandomStrategy = ModifierManager.IsModifierActive("Random Strategy")

                for _, player in ipairs(activePlayers) do
                    ModifierManager.ReapplyPlayerStates(player)

                    if isRandomStrategy then
                        AbilityManager.EquipRandomAbility(player)
                    end

                    -- Force Reset Scales for Grow/Shrink Modifier
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

                local isStreamsnipe = ModifierManager.IsModifierActive("Streamsnipe")

                local numMaces = 1
                if isStreamsnipe then
                    numMaces = math.max(1, #activePlayers - 1)
                elseif ModifierManager.IsModifierActive("Triple Trouble !") then
                    numMaces = 3
                elseif ModifierManager.IsModifierActive("Double Trouble !") then
                    numMaces = 2
                end

                -- Cap the number of maces to activePlayers - 1 to prevent a draw where everyone is a mace user
                if numMaces >= #activePlayers then
                    numMaces = math.max(1, #activePlayers - 1)
                end

                -- The map is already spawned at the start of the match.
                -- However, we still need to spawn/update the visual Hammers for roulette
                -- based on the current numMaces (which can change between rounds due to modifiers).
                -- Since we do NOT want to change the arena entirely, we will just manage the hammers.
                -- MapManager.chooseAndSpawnMap takes down the entire map, which we want to avoid.

                if currentMap then
                    -- Just re-spawn hammers on the existing map
                    if currentHammer then
                        if type(currentHammer) == "table" then
                            for _, h in ipairs(currentHammer) do h:Destroy() end
                        else
                            currentHammer:Destroy()
                        end
                        currentHammer = nil
                    end

                    local hammerSpawnFolder = currentMap:FindFirstChild("HammerSpawn")
                    local hammerSpawnPart = nil
                    if hammerSpawnFolder then
                        hammerSpawnPart = hammerSpawnFolder:FindFirstChildWhichIsA("BasePart")
                    end

                    local hammerModelTemplate = game:GetService("ServerStorage"):FindFirstChild("MapStorage"):FindFirstChild("HammerModel")
                    if hammerModelTemplate and hammerSpawnPart then
                        currentHammer = {}
                        local isModel = hammerModelTemplate:IsA("Model")
                        local hammerHeight = 1

                        if isModel then
                            local primary = hammerModelTemplate.PrimaryPart or hammerModelTemplate:FindFirstChildWhichIsA("BasePart", true)
                            if primary then hammerHeight = primary.Size.Z / 2 end
                        elseif hammerModelTemplate:IsA("BasePart") then
                            hammerHeight = hammerModelTemplate.Size.Z / 2
                        end

                        local radius = numMaces > 1 and 3 or 0

                        for i = 1, numMaces do
                            local hammerInst = hammerModelTemplate:Clone()
                            hammerInst.Parent = Workspace

                            if isModel then
                                if not hammerInst.PrimaryPart then
                                    hammerInst.PrimaryPart = hammerInst:FindFirstChildWhichIsA("BasePart", true)
                                end
                                for _, part in ipairs(hammerInst:GetDescendants()) do
                                    if part:IsA("BasePart") then
                                        part.Anchored = true
                                        part.CanCollide = false
                                    end
                                end
                            else
                                hammerInst.Anchored = true
                                hammerInst.CanCollide = false
                            end

                            local angle = (math.pi * 2 / numMaces) * i
                            local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                            local targetHammerCFrame = hammerSpawnPart.CFrame * CFrame.new(offset) * CFrame.new(0, (hammerSpawnPart.Size.Y/2) + hammerHeight, 0) * CFrame.Angles(math.rad(90), 0, 0)

                            if isModel and hammerInst.PrimaryPart then
                                hammerInst:PivotTo(targetHammerCFrame)
                            elseif hammerInst:IsA("BasePart") then
                                hammerInst.CFrame = targetHammerCFrame
                            end

                            table.insert(currentHammer, hammerInst)
                        end
                    end

                    if currentHammer and #currentHammer == 1 then
                        currentHammer = currentHammer[1]
                    end
                end

                -- Ensure hammer is visible at round start
                if type(currentHammer) == "table" then
                    for _, h in ipairs(currentHammer) do setHammerVisibility(h, true) end
                elseif currentHammer then
                    setHammerVisibility(currentHammer, true)
                end

                -- Teleport players to their spawn points on every round
                Matchmaking.teleportPlayersToSpawns(activePlayers, currentMap)

                -- Block player movement while roulette spins
                setPlayersAnchored(activePlayers, true)

                task.wait(1) -- small delay for physics/camera to settle

                local chosenPlayers = Roulette.selectMaceBearers(activePlayers, numMaces)

                if #chosenPlayers > 0 then
                    local targetAnimPlayers = chosenPlayers
                    if isStreamsnipe then
                        local nonMaceUser = nil
                        for _, p in ipairs(activePlayers) do
                            if not table.find(chosenPlayers, p) then
                                nonMaceUser = p
                                break
                            end
                        end
                        if nonMaceUser then
                            targetAnimPlayers = {nonMaceUser}
                        end
                    end
                    Roulette.playRouletteAnimation(targetAnimPlayers, currentHammer)

                    -- Unblock movement now that roulette has finished
                    setPlayersAnchored(activePlayers, false)

                    -- Hide visual hammer because the player picked it up
                    if type(currentHammer) == "table" then
                        for _, h in ipairs(currentHammer) do setHammerVisibility(h, false) end
                    else
                        setHammerVisibility(currentHammer, false)
                    end

                    local roundEnded = false
                    local activeAttackers = #chosenPlayers

                    local function onAttackerFinished()
                        activeAttackers = activeAttackers - 1
                        if activeAttackers <= 0 then
                            roundEnded = true
                        end
                    end

                    local function onRoundEnd()
                        roundEnded = true
                    end

                    -- Conectăm un event rapid ca să știm dacă cineva din activePlayers a murit în această rundă
                    local deathConnections = {}
                    local nonMaceUser = nil
                    if isStreamsnipe then
                        for _, p in ipairs(activePlayers) do
                            if not table.find(chosenPlayers, p) then
                                nonMaceUser = p
                                break
                            end
                        end
                    end

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
                                    player:SetAttribute("InMatch", false)
                                    -- Afișăm MAINUI din nou pentru cel eliminat
                                    if toggleMainUiEvent then
                                        toggleMainUiEvent:FireClient(player, true)
                                    end

                                    if isStreamsnipe and nonMaceUser and player == nonMaceUser then
                                        print("MainLoop: Non-mace user died in Streamsnipe. Round ends.")
                                        roundEnded = true
                                    end

                                    if ModifierManager.IsModifierActive("SuddenDeath") then
                                        print("MainLoop: A player died during SuddenDeath. Round ends.")
                                        roundEnded = true
                                    end
                                end
                            end))
                        end
                    end

                    for _, chosenPlayer in ipairs(chosenPlayers) do
                        if ModifierManager.IsModifierActive("Hot Potato") then
                            HotPotatoMechanic.startMechanic(chosenPlayer, onAttackerFinished, activePlayers)
                        else
                            MaceMechanic.startMechanic(chosenPlayer, onAttackerFinished, false, chosenPlayers)
                        end
                    end

                    if ModifierManager.IsModifierActive("Beach Episode") then
                        local ServerStorage = game:GetService("ServerStorage")
                        local beachBallFolder = ServerStorage:FindFirstChild("BeachBall")
                        if beachBallFolder then
                            local ballTool = beachBallFolder:FindFirstChild("BeachBall") or beachBallFolder:FindFirstChild("Tool")
                            if ballTool then
                                for _, player in ipairs(activePlayers) do
                                    if not table.find(chosenPlayers, player) then
                                        local clone = ballTool:Clone()
                                        clone.Name = "BeachBall"
                                        clone.Parent = player.Backpack
                                    end
                                end
                            end
                        end
                    end

                    local heartbeatConn
                    heartbeatConn = RunService.Heartbeat:Connect(function()
                        ModifierManager.UpdateDynamicModifiers(activePlayers, chosenPlayers)
                    end)

                    -- Wait until the round is marked as ended (by missing or the attacker dying)
                    -- (If the attacker gets a kill, the mechanic keeps going and doesn't call onRoundEnd)
                    while not roundEnded do
                        -- If only 1 player is left active during the mechanic, force end
                        if #activePlayers <= 1 then
                            roundEnded = true
                        end
                        task.wait(0.5)
                    end

                    if heartbeatConn then heartbeatConn:Disconnect() end

                    -- Reward survivals at round end
                    for _, activeP in ipairs(activePlayers) do
                        ProgressionManager.ProcessRoundSurvive(activeP)
                    end

                    -- Clean up death connections
                    for _, conn in ipairs(deathConnections) do
                        conn:Disconnect()
                    end
                    table.clear(deathConnections)

                    for _, p in ipairs(activePlayers) do
                        local tool = p.Backpack:FindFirstChild("BeachBall")
                        if tool then tool:Destroy() end
                        if p.Character then
                            local charTool = p.Character:FindFirstChild("BeachBall")
                            if charTool then charTool:Destroy() end
                        end
                    end

                    print("MainLoop: Runda s-a încheiat. Așteptăm cooldown 5 secunde...")
                    task.wait(5)
                else
                    warn("MainLoop: Nu s-a putut alege un jucător!")
                    setPlayersAnchored(activePlayers, false)
                    task.wait(5)
                    break
                end
            end -- End of Round Loop

                -- Failsafe: Ensure everyone is unanchored when the match ends
                setPlayersAnchored(activePlayers, false)

                if disconnectConnection then
                    disconnectConnection:Disconnect()
                end

                -- Force cleanup of the mechanic in case a round ended abruptly (e.g. opponent died, leaving only the attacker)
                if MaceMechanic.forceStopMechanic then
                    MaceMechanic.forceStopMechanic()
                end
                if HotPotatoMechanic.forceStopMechanic then
                    HotPotatoMechanic.forceStopMechanic()
                end

                for _, p in ipairs(Players:GetPlayers()) do
                    AbilityManager.RestoreOriginalAbility(p)
                end

                ModifierManager.ClearAllModifiers()

                -- Dacă bucla de runde s-a terminat, înseamnă că meciul s-a încheiat (avem <= 1 supraviețuitori)
                if #activePlayers == 1 then
                    local winner = activePlayers[1]
                    winner:SetAttribute("InMatch", false)
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
                            -- Add AntiCheat bypass for winner teleport
                            AntiCheat.SetBypass(winner, "Speed", 5)

                            -- Y offset is half the spawn height + half character height roughly, 5 is a safe amount
                            rootPart.CFrame = chosenSpawn.CFrame * CFrame.new(0, chosenSpawn.Size.Y/2 + 3, 0)
                            print("MainLoop: Câștigătorul a fost teleportat la spawn.")
                        else
                            -- Add AntiCheat bypass for fallback winner teleport
                            AntiCheat.SetBypass(winner, "Speed", 5)

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
TrainingManager.Start()
setupMap()
gameLoop()

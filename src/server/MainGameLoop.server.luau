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
local uiEvents = {"ShowCountdownEvent", "ShowTextEvent", "HideTextEvent"}
for _, evName in ipairs(uiEvents) do
    if not ReplicatedStorage:FindFirstChild(evName) then
        local ev = Instance.new("RemoteEvent")
        ev.Name = evName
        ev.Parent = ReplicatedStorage
    end
end

local Matchmaking = require(script.Parent.modules.Matchmaking)
local Roulette = require(script.Parent.modules.Roulette)
local MaceMechanic = require(script.Parent.modules.MaceMechanic)

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

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
local function setHammerVisibility(visible)
    local hammerSpawn = Workspace:FindFirstChild("HammerSpawn")
    if hammerSpawn then
        local hammerModel = hammerSpawn:FindFirstChild("HammerModel")
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
end

-- Function to initialize map elements (make spawns invisible)
local function setupMap()
    local spawns = Workspace:WaitForChild("PlayerSpawn", 10)
    if spawns then
        for _, part in ipairs(spawns:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = 1
                part.Anchored = true
                part.CanCollide = false
            end
        end
    end

    local hammerSpawn = Workspace:WaitForChild("HammerSpawn", 10)
    if hammerSpawn then
        -- PREVENT VOID FALL: Anchor HammerModel exactly when the server starts
        local hammerModel = hammerSpawn:WaitForChild("HammerModel", 10)
        if hammerModel then
            local isModel = hammerModel:IsA("Model")

            -- If it's a Model, anchor descendants. If it's just a Union/Part, anchor it directly.
            if isModel then
                for _, part in ipairs(hammerModel:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Anchored = true
                        part.CanCollide = false
                    end
                end
                if not hammerModel.PrimaryPart then
                    hammerModel.PrimaryPart = hammerModel:FindFirstChildWhichIsA("BasePart", true)
                end
            elseif hammerModel:IsA("BasePart") then
                hammerModel.Anchored = true
                hammerModel.CanCollide = false
            end

            -- Teleport the visual hammer precisely above the blue block
            local spawnBlock = hammerSpawn:WaitForChild("HammerSpawn", 5)
            if spawnBlock and spawnBlock:IsA("BasePart") then
                -- Lay it flat on the ground (rotate 90 degrees on X)
                local targetCFrame = spawnBlock.CFrame * CFrame.new(0, 2, 0) * CFrame.Angles(math.rad(90), 0, 0)
                if isModel and hammerModel.PrimaryPart then
                    hammerModel:PivotTo(targetCFrame)
                elseif hammerModel:IsA("BasePart") then
                    hammerModel.CFrame = targetCFrame
                end
            end

            -- Continuous Idle Spin
            RunService.Heartbeat:Connect(function(dt)
                if hammerModel and hammerModel.Parent then
                    if not hammerModel:GetAttribute("IsRoulette") then
                        -- To spin a flat object like a compass needle, we rotate around its local Z axis (which is now pointing "up" globally due to the 90deg X rotation)
                        if isModel and hammerModel.PrimaryPart then
                            local currentPivot = hammerModel:GetPivot()
                            hammerModel:PivotTo(currentPivot * CFrame.Angles(0, 0, math.rad(90 * dt)))
                        elseif hammerModel:IsA("BasePart") then
                            local currentCFrame = hammerModel.CFrame
                            hammerModel.CFrame = currentCFrame * CFrame.Angles(0, 0, math.rad(90 * dt))
                        end
                    end
                end
            end)
        end
    end
end

-- Main Game Loop
local function gameLoop()
    local Players = game:GetService("Players")

    while true do
        print("MainLoop: Așteptăm jucători pentru un NOU MECI...")
        local success = Matchmaking.waitForPlayers()

        if success then
            -- Meciul începe, înregistrăm toți jucătorii care participă la acest meci
            local activePlayers = Players:GetPlayers()
            print("MainLoop: Meciul a început cu " .. #activePlayers .. " jucători!")

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
                setHammerVisibility(true)

                Matchmaking.teleportPlayersToSpawns(activePlayers)

                -- Block player movement while roulette spins
                setPlayersAnchored(activePlayers, true)

                task.wait(1) -- small delay for physics/camera to settle

                local chosenPlayer = Roulette.selectMaceBearer(activePlayers)
                if chosenPlayer then
                    Roulette.playRouletteAnimation(chosenPlayer)

                    -- Unblock movement now that roulette has finished
                    setPlayersAnchored(activePlayers, false)

                    -- Hide visual hammer because the player picked it up
                    setHammerVisibility(false)

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
                                -- Scoatem jucătorul mort din lista de supraviețuitori ai meciului
                                local idx = table.find(activePlayers, player)
                                if idx then
                                    table.remove(activePlayers, idx)
                                    print("MainLoop: " .. player.Name .. " a fost ELIMINAT din meci!")
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

-- Start
task.spawn(setupMap)
task.spawn(gameLoop)

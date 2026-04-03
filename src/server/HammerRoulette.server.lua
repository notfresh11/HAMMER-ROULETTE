-- Hammer Roulette Server Script

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Configuration
local MIN_PLAYERS = 2
local MAX_PLAYERS = 9
local JUMP_POWER = 100
local BOUNCE_POWER = 100
local SPIN_DURATION = 3

local activePlayers = {}
local alivePlayersInRound = {}
local playerWeights = {}
local roundInProgress = false
local currentBearer = nil
local hammerTool = nil

local function getHammerSpawn()
    -- Assuming a Workspace.HammerSpawn model exists
    local spawn = Workspace:FindFirstChild("HammerSpawn")
    if not spawn then
        -- Create a dummy one for testing if it doesn't exist
        spawn = Instance.new("Model")
        spawn.Name = "HammerSpawn"
        local part = Instance.new("Part")
        part.Name = "PrimaryPart"
        part.Anchored = true
        part.Parent = spawn
        spawn.PrimaryPart = part
        spawn.Parent = Workspace
    end
    return spawn
end

local function getHammerToolTemplate()
    -- Assuming ServerStorage.Hammer exists
    local hammer = ServerStorage:FindFirstChild("Hammer")
    if not hammer then
        hammer = Instance.new("Tool")
        hammer.Name = "Hammer"
        local handle = Instance.new("Part")
        handle.Name = "Handle"
        handle.Size = Vector3.new(1, 4, 1)
        handle.Parent = hammer
        hammer.Parent = ServerStorage
    end
    return hammer
end

-- Matchmaking and State Management
local function teleportPlayers()
    local spawnsFolder = Workspace:FindFirstChild("PlayerSpawns")
    local spawns = {}
    if spawnsFolder then
        spawns = spawnsFolder:GetChildren()
    end

    for i, player in ipairs(activePlayers) do
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            -- Find a spawn point, or use a default if missing
            local spawnPos = Vector3.new(0, 10, 0)
            if #spawns > 0 then
                local spawnPart = spawns[(i % #spawns) + 1]
                if spawnPart and spawnPart:IsA("BasePart") then
                    spawnPos = spawnPart.Position + Vector3.new(0, 3, 0)
                end
            end

            character.HumanoidRootPart.CFrame = CFrame.new(spawnPos)
        end
    end
end

local function checkWinCondition()
    -- Filter out players who left or were eliminated
    local currentAlive = {}
    for _, player in ipairs(alivePlayersInRound) do
        if player and player.Parent == Players then
            table.insert(currentAlive, player)
        end
    end

    alivePlayersInRound = currentAlive

    if #alivePlayersInRound <= 1 then
        return true, alivePlayersInRound[1]
    end
    return false, nil
end

local function cleanupRound()
    roundInProgress = false
    currentBearer = nil

    if hammerTool then
        hammerTool:Destroy()
        hammerTool = nil
    end

    -- Reset all players jump power just in case
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.JumpPower = 50 -- default
        end
    end

    local hammerSpawn = Workspace:FindFirstChild("HammerSpawn")
    if hammerSpawn then
        hammerSpawn.Parent = ServerStorage -- Hide it
    end
end

local function endRound(winner)
    if winner then
        print("Winner is: " .. winner.Name)
    else
        print("Round ended in a draw or was cancelled.")
    end

    cleanupRound()

    -- Small delay before next round
    task.wait(3)
    startMatchmaking()
end

-- Pre-declare the roulette phase (to be implemented next)
local function giveHammer(player)
    local template = getHammerToolTemplate()
    hammerTool = template:Clone()
    hammerTool.Parent = player.Backpack

    -- Wait for character to equip it or just equip it directly
    local char = player.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid:EquipTool(hammerTool)
    end
end

-- Pre-declare the roulette phase
-- Forward declarations
local startMatchmaking
local startRoulettePhase
local startMaceMechanic

startRoulettePhase = function()
    print("Roulette Phase Starting...")
    if not roundInProgress then return end

    local hasWinner, winner = checkWinCondition()
    if hasWinner then
        endRound(winner)
        return
    end

    -- Make HammerSpawn visible
    local hammerSpawn = getHammerSpawn()
    if hammerSpawn.Parent ~= Workspace then
        hammerSpawn.Parent = Workspace
    end

    -- Weighted random selection
    local totalWeight = 0
    for _, player in ipairs(activePlayers) do
        local w = playerWeights[player.UserId] or 1
        totalWeight = totalWeight + w
    end

    local randomValue = math.random() * totalWeight
    local chosenPlayer = nil

    local currentSum = 0
    for _, player in ipairs(activePlayers) do
        local w = playerWeights[player.UserId] or 1
        currentSum = currentSum + w
        if randomValue <= currentSum then
            chosenPlayer = player
            break
        end
    end

    -- Fallback in case of weird float issues
    if not chosenPlayer then
        chosenPlayer = activePlayers[math.random(1, #activePlayers)]
    end

    print("Chosen player for this round: " .. chosenPlayer.Name)
    currentBearer = chosenPlayer

    -- Increase weight for everyone else, reset for chosen
    for _, player in ipairs(activePlayers) do
        if player == chosenPlayer then
            playerWeights[player.UserId] = 1
        else
            playerWeights[player.UserId] = (playerWeights[player.UserId] or 1) + 1
        end
    end

    -- Spin the Hammer Spawn for 3 seconds
    if hammerSpawn.PrimaryPart then
        local startTime = tick()
        local connection
        connection = RunService.Heartbeat:Connect(function(dt)
            if tick() - startTime >= SPIN_DURATION then
                connection:Disconnect()
                return
            end
            hammerSpawn:SetPrimaryPartCFrame(hammerSpawn:GetPrimaryPartCFrame() * CFrame.Angles(0, math.rad(360 * dt), 0))
        end)
        task.wait(SPIN_DURATION)
    else
        -- If no PrimaryPart, just wait
        task.wait(SPIN_DURATION)
    end

    -- Hide HammerSpawn
    hammerSpawn.Parent = ServerStorage

    -- Give tool to chosen player
    giveHammer(chosenPlayer)

    -- Start the mechanic for the mace
    startMaceMechanic(chosenPlayer)
end

startMaceMechanic = function(player)
    local character = player.Character
    if not character then
        -- Failsafe: start next phase if player character is gone
        task.wait(1)
        startRoulettePhase()
        return
    end

    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not rootPart then
        task.wait(1)
        startRoulettePhase()
        return
    end

    -- Boost jump power
    humanoid.JumpPower = JUMP_POWER

    local isFalling = false
    local mechanicConnections = {}

    local function cleanupMechanic()
        for _, conn in ipairs(mechanicConnections) do
            conn:Disconnect()
        end
        mechanicConnections = {}
        if humanoid then
            humanoid.JumpPower = 50 -- Reset to default
        end
        if hammerTool then
            hammerTool:Destroy()
            hammerTool = nil
        end
    end

    -- Listen for Humanoid state changes to track falling and landing
    table.insert(mechanicConnections, humanoid.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.Freefall then
            isFalling = true
        elseif newState == Enum.HumanoidStateType.Landed then
            if isFalling then
                -- Player landed without hitting anyone, they fail.
                print(player.Name .. " missed and landed on the ground. Next round starting.")
                cleanupMechanic()
                task.wait(1)
                startRoulettePhase()
            end
        end
    end))

    -- Failsafe: if the bearer dies, eliminate them and go to next phase
    table.insert(mechanicConnections, humanoid.Died:Connect(function()
        local idx = table.find(alivePlayersInRound, player)
        if idx then
            table.remove(alivePlayersInRound, idx)
        end
        print(player.Name .. " died while holding the hammer. Next round starting.")
        cleanupMechanic()
        task.wait(1)
        startRoulettePhase()
    end))

    -- Failsafe: if the bearer leaves the game
    table.insert(mechanicConnections, Players.PlayerRemoving:Connect(function(plr)
        if plr == player then
            local idx = table.find(alivePlayersInRound, player)
            if idx then
                table.remove(alivePlayersInRound, idx)
            end
            print(player.Name .. " left the game while holding the hammer. Next round starting.")
            cleanupMechanic()
            task.wait(1)
            startRoulettePhase()
        end
    end))

    -- Listen for Tool hits
    local handle = hammerTool:FindFirstChild("Handle")
    if handle then
        table.insert(mechanicConnections, handle.Touched:Connect(function(hit)
            if not isFalling then return end -- Only hits during a fall count

            -- Make sure the hit object belongs to a character
            local hitCharacter = hit.Parent
            if not hitCharacter then return end

            -- Ensure we don't hit ourselves
            if hitCharacter == character then return end

            local hitHumanoid = hitCharacter:FindFirstChild("Humanoid")
            local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)

            -- Make sure the hit opponent is part of the game and alive
            local isOpponentAlive = false
            if hitPlayer then
                local index = table.find(alivePlayersInRound, hitPlayer)
                if index then
                    isOpponentAlive = true
                    table.remove(alivePlayersInRound, index)
                end
            end

            if hitHumanoid and hitHumanoid.Health > 0 and isOpponentAlive then
                -- Insta-kill the opponent
                hitHumanoid.Health = 0

                print(player.Name .. " smashed " .. hitCharacter.Name .. "!")

                -- Apply bounce to the attacker
                rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, BOUNCE_POWER, rootPart.AssemblyLinearVelocity.Z)

                -- Note: They remain the bearer and can hit someone else while in the air again!
            end
        end))
    end

end

startMatchmaking = function()
    if roundInProgress then return end

    print("Waiting for players to start match...")
    while true do
        local currentPlayers = Players:GetPlayers()
        if #currentPlayers >= MIN_PLAYERS then
            break
        end
        task.wait(1)
    end

    print("Starting Match...")
    roundInProgress = true
    activePlayers = {}
    alivePlayersInRound = {}

    local currentPlayers = Players:GetPlayers()
    for i = 1, math.min(#currentPlayers, MAX_PLAYERS) do
        table.insert(activePlayers, currentPlayers[i])
        table.insert(alivePlayersInRound, currentPlayers[i])

        -- Initialize weight if they are new
        if not playerWeights[currentPlayers[i].UserId] then
            playerWeights[currentPlayers[i].UserId] = 1
        end
    end

    -- Make HammerSpawn visible
    local hammerSpawn = getHammerSpawn()
    if hammerSpawn.Parent ~= Workspace then
        hammerSpawn.Parent = Workspace
    end

    teleportPlayers()
    task.wait(1)

    startRoulettePhase()
end

Players.PlayerAdded:Connect(function(player)
    playerWeights[player.UserId] = 1
end)

Players.PlayerRemoving:Connect(function(player)
    playerWeights[player.UserId] = nil

    -- If a player leaves during a round, we check if we still have enough players
    if roundInProgress then
        local index = table.find(activePlayers, player)
        if index then
            table.remove(activePlayers, index)

            -- Also remove from alive players if they were still alive
            local aliveIndex = table.find(alivePlayersInRound, player)
            if aliveIndex then
                table.remove(alivePlayersInRound, aliveIndex)
            end

            if #activePlayers < MIN_PLAYERS then
                print("Not enough players to continue the round. Cancelling...")
                endRound(nil)
            end
        end
    end
end)

-- Start the matchmaking loop when the server starts
task.spawn(startMatchmaking)

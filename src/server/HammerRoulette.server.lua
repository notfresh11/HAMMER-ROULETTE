-- Hammer Roulette Server Script

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Configuration
local MIN_PLAYERS = 2
local MAX_PLAYERS = 9
local JUMP_HEIGHT = 50
local BOUNCE_POWER = 100
local SPIN_DURATION = 3

local activePlayers = {}
local alivePlayersInRound = {}
local playerWeights = {}
local roundInProgress = false
local currentBearer = nil
local hammerTool = nil

-- Forward declarations to fix scope issues
local startMatchmaking
local startRoulettePhase
local startMaceMechanic

local function getWholeMap()
    return Workspace:FindFirstChild("WholeMap")
end

local function getHammerSpawnModel()
    local wholeMap = getWholeMap()
    if wholeMap then
        local hammerSpawnFolder = wholeMap:FindFirstChild("HammerSpawn")
        if hammerSpawnFolder then
            return hammerSpawnFolder:FindFirstChild("HammerModel")
        end
    end
    return nil
end

local function getHammerToolTemplate()
    -- It was moved to ServerStorage during initialization
    return ServerStorage:FindFirstChild("Tool")
end

-- Matchmaking and State Management
local function teleportPlayers()
    local wholeMap = getWholeMap()
    local spawns = {}
    if wholeMap then
        local playerSpawnFolder = wholeMap:FindFirstChild("PlayersSpawn")
        if playerSpawnFolder then
            spawns = playerSpawnFolder:GetChildren()
        end
    end

    for i, player in ipairs(activePlayers) do
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            -- Find a spawn point, or use a default if missing
            local spawnPos = Vector3.new(0, 10, 0)
            if #spawns > 0 then
                -- Use math.floor to properly map 'i' directly to index (1 to #spawns)
                -- We use ((i - 1) % #spawns) + 1 so player 1 gets spawn 1, player 2 gets spawn 2, etc.
                local spawnIndex = ((i - 1) % #spawns) + 1
                local spawnPart = spawns[spawnIndex]

                if spawnPart and spawnPart:IsA("BasePart") then
                    spawnPos = spawnPart.Position + Vector3.new(0, 5, 0)
                end
            else
                -- Fallback spread if no spawns exist
                spawnPos = Vector3.new((i - 1) * 5, 10, 0)
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

    -- Reset all players jump height just in case
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.UseJumpPower = false
            char.Humanoid.JumpHeight = 7.2 -- default Roblox JumpHeight
            char.Humanoid.JumpPower = 50 -- default Roblox JumpPower
        end
    end

    local hammerModel = getHammerSpawnModel()
    -- We removed the transparency hiding so the hammer remains visible on the ground.
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
startRoulettePhase = function()
    print("Roulette Phase Starting...")
    if not roundInProgress then return end

    local hasWinner, winner = checkWinCondition()
    if hasWinner then
        endRound(winner)
        return
    end

    local hammerModel = getHammerSpawnModel()

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

    -- Spin the Hammer Model for 3 seconds using PivotTo
    if hammerModel then
        local startTime = tick()
        local initialPivot = hammerModel:GetPivot()
        local connection
        connection = RunService.Heartbeat:Connect(function(dt)
            local elapsed = tick() - startTime
            if elapsed >= SPIN_DURATION then
                connection:Disconnect()
                return
            end
            -- Spin around the Y axis over time based on total elapsed time, not dt
            -- For example, spinning at 360 degrees per second:
            hammerModel:PivotTo(initialPivot * CFrame.Angles(0, math.rad(360 * elapsed), 0))
        end)
        task.wait(SPIN_DURATION)

    else
        -- If no HammerModel, just wait
        task.wait(SPIN_DURATION)
    end

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

    -- Boost jump height
    humanoid.UseJumpPower = true
    humanoid.JumpPower = 140

    local isFalling = false
    local mechanicConnections = {}

    -- To prevent double jumping (especially on mobile)
    local hasJumped = false

    local function cleanupMechanic()
        for _, conn in ipairs(mechanicConnections) do
            conn:Disconnect()
        end
        mechanicConnections = {}
        if humanoid then
            humanoid.UseJumpPower = false
            humanoid.JumpHeight = 7.2 -- Reset to default
        end
        if hammerTool then
            hammerTool:Destroy()
            hammerTool = nil
        end
    end

    -- Listen for Humanoid state changes to track falling and landing
    table.insert(mechanicConnections, humanoid.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.Jumping then
            -- The moment they jump, disable jump power so they can't jump again mid-air
            hasJumped = true
            humanoid.UseJumpPower = false
            humanoid.JumpPower = 0
        elseif newState == Enum.HumanoidStateType.Freefall then
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
            -- Only hits count if the player is mid-air (either falling or jumping up)
            -- Relying strictly on 'isFalling' can sometimes miss if state doesn't update fast enough
            local humanoidState = humanoid:GetState()
            local inAir = humanoidState == Enum.HumanoidStateType.Freefall or humanoidState == Enum.HumanoidStateType.Jumping or isFalling

            if not inAir then return end

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

                -- Reset jump state if they want to jump after landing on someone (though the bounce keeps them in air anyway)
                hasJumped = false
                humanoid.UseJumpPower = true
                humanoid.JumpPower = 140
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

    print("Match starting in 10 seconds...")
    for i = 10, 1, -1 do
        print(i .. "...")
        task.wait(1)
        -- Check if players dropped below minimum during countdown
        if #Players:GetPlayers() < MIN_PLAYERS then
            print("Not enough players anymore. Matchmaking cancelled.")
            task.spawn(startMatchmaking)
            return
        end
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
local function initializeMapObjects()
    local wholeMap = getWholeMap()
    if wholeMap then
        local playerSpawnFolder = wholeMap:FindFirstChild("PlayersSpawn")
        if playerSpawnFolder then
            for _, spawnPart in ipairs(playerSpawnFolder:GetChildren()) do
                if spawnPart:IsA("BasePart") then
                    spawnPart.Transparency = 1
                    spawnPart.Anchored = true
                    spawnPart.CanCollide = false
                end
            end
        end

        local hammerSpawnFolder = wholeMap:FindFirstChild("HammerSpawn")
        if hammerSpawnFolder then
            -- Loop over all children just to be safe, making all baseparts inside the folder invisible (except the model which is handled below)
            for _, child in ipairs(hammerSpawnFolder:GetChildren()) do
                if child:IsA("BasePart") then
                    child.Transparency = 1
                    child.Anchored = true
                    child.CanCollide = false
                end
            end

            local hammerSpawnPart = hammerSpawnFolder:FindFirstChild("HammerSpawn")
            if hammerSpawnPart and hammerSpawnPart:IsA("BasePart") then
                hammerSpawnPart.Transparency = 1
                hammerSpawnPart.Anchored = true
                hammerSpawnPart.CanCollide = false
            end

            local hammerModel = hammerSpawnFolder:FindFirstChild("HammerModel")
            if hammerModel then
                for _, part in ipairs(hammerModel:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Anchored = true
                        part.CanCollide = false
                    end
                end
            end
        end

        local hammerFolder = wholeMap:FindFirstChild("Hammer")
        if hammerFolder then
            local tool = hammerFolder:FindFirstChild("Tool")
            if tool then
                -- Move it to ServerStorage so players can't just pick it up from Workspace
                tool.Parent = ServerStorage
            end
        end
    end
end

-- Initialize map and start the matchmaking loop when the server starts
initializeMapObjects()
task.spawn(startMatchmaking)

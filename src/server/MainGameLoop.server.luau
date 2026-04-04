local Matchmaking = require(script.Parent.modules.Matchmaking)
local Roulette = require(script.Parent.modules.Roulette)
local MaceMechanic = require(script.Parent.modules.MaceMechanic)

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

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
        for _, child in ipairs(hammerSpawn:GetChildren()) do
            if child:IsA("BasePart") and child.Name ~= "HammerModel" then
                child.Transparency = 1
                child.Anchored = true
                child.CanCollide = false
            end
        end

        -- PREVENT VOID FALL: Anchor HammerModel exactly when the server starts
        local hammerModel = hammerSpawn:WaitForChild("HammerModel", 10)
        if hammerModel then
            for _, part in ipairs(hammerModel:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = true
                    part.CanCollide = false
                end
            end

            -- Ensure PrimaryPart exists for rotation
            if not hammerModel.PrimaryPart then
                hammerModel.PrimaryPart = hammerModel:FindFirstChildWhichIsA("BasePart", true)
            end

            -- Continuous Idle Spin
            RunService.Heartbeat:Connect(function(dt)
                if hammerModel and hammerModel.Parent and hammerModel.PrimaryPart then
                    -- Stop idle spin when the active roulette animation takes over
                    if not hammerModel:GetAttribute("IsRoulette") then
                        local currentPivot = hammerModel:GetPivot()
                        hammerModel:PivotTo(currentPivot * CFrame.Angles(0, math.rad(90 * dt), 0))
                    end
                end
            end)
        end
    end
end

-- Main Game Loop
local function gameLoop()
    while true do
        print("MainLoop: Așteptăm jucători pentru o nouă rundă...")
        local success = Matchmaking.waitForPlayers()

        if success then
            Matchmaking.teleportPlayersToSpawns()
            task.wait(1) -- small delay for physics/camera to settle

            local chosenPlayer = Roulette.selectMaceBearer()
            if chosenPlayer then
                Roulette.playRouletteAnimation(chosenPlayer)

                local roundEnded = false
                local function onRoundEnd()
                    roundEnded = true
                end

                MaceMechanic.startMechanic(chosenPlayer, onRoundEnd)

                -- Wait until the round is marked as ended (by missing or dying)
                while not roundEnded do
                    task.wait(0.5)
                end

                print("MainLoop: Runda s-a încheiat. Așteptăm cooldown 5 secunde...")
                task.wait(5)
            else
                warn("MainLoop: Nu s-a putut alege un jucător!")
                task.wait(5)
            end
        else
            -- Not enough players during countdown, loop will restart
            task.wait(2)
        end
    end
end

-- Start
task.spawn(setupMap)
task.spawn(gameLoop)

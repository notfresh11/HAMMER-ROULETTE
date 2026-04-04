local Matchmaking = require(script.Parent.modules.Matchmaking)
local Roulette = require(script.Parent.modules.Roulette)
local MaceMechanic = require(script.Parent.modules.MaceMechanic)

local Workspace = game:GetService("Workspace")

-- Function to initialize map elements (make spawns invisible)
local function setupMap()
    local spawns = Workspace:FindFirstChild("PlayerSpawns") or Workspace:FindFirstChild("PlayersSpawn")
    if spawns then
        for _, part in ipairs(spawns:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = 1
                part.Anchored = true
                part.CanCollide = false
            end
        end
    end

    local hammerSpawn = Workspace:FindFirstChild("HammerSpawn")
    if hammerSpawn then
        for _, child in ipairs(hammerSpawn:GetChildren()) do
            if child:IsA("BasePart") and child.Name ~= "HammerModel" then
                child.Transparency = 1
                child.Anchored = true
                child.CanCollide = false
            end
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
setupMap()
task.spawn(gameLoop)

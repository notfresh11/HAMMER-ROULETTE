local Matchmaking = {}
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MIN_PLAYERS = 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AntiCheat = require(script.Parent.AntiCheat)

local function getActivePlayers()
    local activePlayers = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if not plr:GetAttribute("IsAFK") then
            table.insert(activePlayers, plr)
        end
    end
    return activePlayers
end
Matchmaking.getActivePlayers = getActivePlayers

function Matchmaking.waitForPlayers()
    print("Matchmaking: Așteptăm minim " .. MIN_PLAYERS .. " jucători activi...")

    local updateMatchmakingUIEvent = ReplicatedStorage:WaitForChild("UpdateMatchmakingUIEvent")

    while true do
        local currentActive = #getActivePlayers()
        updateMatchmakingUIEvent:FireAllClients("Searching for Players " .. currentActive .. "/" .. MIN_PLAYERS)

        if currentActive >= MIN_PLAYERS then
            break
        end
        task.wait(1)
    end

    print("Matchmaking: Avem suficienți jucători. Începem în 10 secunde.")
    local COUNTDOWN_SOUND = "rbxassetid://110001162763213"
    local START_SOUND = "rbxassetid://77736543307386"

    local startTick = os.clock()
    local i = 10

    while i >= 1 do
        -- Așteptăm precis folosind os.clock() ca să fim la fix o secundă diferență
        if os.clock() - startTick >= (10 - i) then
            print(i .. "...")

            updateMatchmakingUIEvent:FireAllClients("Game starting in " .. i, COUNTDOWN_SOUND)
            i = i - 1

            if #getActivePlayers() < MIN_PLAYERS then
                print("Matchmaking anulat: Număr insuficient de jucători activi.")
                updateMatchmakingUIEvent:FireAllClients("Matchmaking Cancelled")
                task.wait(2)
                return false
            end
        end
        task.wait() -- Așteptăm doar un singur cadru pentru precizie
    end

    -- Delay scurt ca să ne asigurăm că termină beep-ul pentru 1 înainte să bată Start
    task.wait(1)
    updateMatchmakingUIEvent:FireAllClients("The Game Has Started", START_SOUND)
    task.delay(2, function()
        -- Resetăm textul după ce începe meciul
        updateMatchmakingUIEvent:FireAllClients("")
    end)

    return true
end

function Matchmaking.teleportPlayersToSpawns(activePlayers, currentMapInstance)
    print("Matchmaking: Teleportăm jucătorii supraviețuitori...")
    local spawns = {}

    if currentMapInstance then
        local spawnFolder = currentMapInstance:FindFirstChild("PlayerSpawn")
        if spawnFolder then
            for _, part in ipairs(spawnFolder:GetDescendants()) do
                if part:IsA("BasePart") then
                    table.insert(spawns, part)
                end
            end
        else
            warn("Eroare: Nu am găsit folderul PlayerSpawn în harta " .. currentMapInstance.Name)
        end
    else
        warn("Eroare: Nu a fost pasată nicio hartă curentă pentru teleportare!")
    end

    for index, player in ipairs(activePlayers) do
        -- Only teleport if they are actually in game and alive
        if player and player.Parent == Players then
            task.spawn(function()
                local character = player.Character or player.CharacterAdded:Wait()
                if character then
                    local rootPart = character:WaitForChild("HumanoidRootPart", 5)
                    if rootPart then
                        local targetCFrame = CFrame.new(0, 50, 0) -- fallback

                        if #spawns > 0 then
                            -- Round robin assign spawns
                            local spawnIndex = ((index - 1) % #spawns) + 1
                            local chosenSpawn = spawns[spawnIndex]

                            -- Calculate exact floor placement
                            -- Y offset = (Spawn Height / 2) + (RootPart Height / 2) + Humanoid HipHeight (which is usually around 2 studs for R15)
                            local humanoid = character:WaitForChild("Humanoid", 5)
                            local hipHeight = humanoid and humanoid.HipHeight or 2
                            local yOffset = (chosenSpawn.Size.Y / 2) + (rootPart.Size.Y / 2) + hipHeight

                            targetCFrame = CFrame.new(chosenSpawn.Position + Vector3.new(0, yOffset, 0))
                        else
                            targetCFrame = CFrame.new((index - 1) * 5, 50, 0)
                        end

                        -- Add temporary AntiCheat bypass for intentional teleport
                        AntiCheat.SetBypass(player, "Speed", 5)

                        -- Așteaptă foarte puțin ca fizica să se asigure pe noul spawn
                        task.wait(0.1)
                        rootPart.CFrame = targetCFrame
                    end
                end
            end)
        end
    end
end

return Matchmaking

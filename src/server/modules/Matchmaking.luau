local Matchmaking = {}
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MIN_PLAYERS = 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")

function Matchmaking.waitForPlayers()
    print("Matchmaking: Așteptăm minim " .. MIN_PLAYERS .. " jucători...")
    while true do
        if #Players:GetPlayers() >= MIN_PLAYERS then
            break
        end
        task.wait(1)
    end

    print("Matchmaking: Avem suficienți jucători. Începem în 10 secunde.")
    local showCountdownEvent = ReplicatedStorage:WaitForChild("ShowCountdownEvent")
    local showTextEvent = ReplicatedStorage:WaitForChild("ShowTextEvent")
    local hideTextEvent = ReplicatedStorage:WaitForChild("HideTextEvent")

    local COUNTDOWN_SOUND = "rbxassetid://110001162763213"
    local START_SOUND = "rbxassetid://77736543307386"

    for i = 10, 1, -1 do
        print(i .. "...")

        -- Logică culori
        local color = Color3.new(1, 0, 0) -- Roșu default (10 - 3)
        if i == 2 then
            color = Color3.new(1, 1, 0) -- Galben
        elseif i == 1 then
            color = Color3.new(0, 1, 0) -- Verde
        end

        showCountdownEvent:FireAllClients(i, color, COUNTDOWN_SOUND)

        task.wait(1)
        if #Players:GetPlayers() < MIN_PLAYERS then
            print("Matchmaking anulat: Număr insuficient de jucători.")
            showTextEvent:FireAllClients("Matchmaking cancelled", Color3.new(1, 0, 0), "")
            task.wait(2)
            hideTextEvent:FireAllClients()
            return false
        end
    end

    showTextEvent:FireAllClients("The Game Has Started", Color3.new(0, 1, 0), START_SOUND)
    task.delay(2, function()
        hideTextEvent:FireAllClients()
    end)

    return true
end

function Matchmaking.teleportPlayersToSpawns(activePlayers)
    print("Matchmaking: Teleportăm jucătorii supraviețuitori...")
    -- Use the exact folder name from the screenshot: "PlayerSpawn"
    local spawnFolder = Workspace:WaitForChild("PlayerSpawn", 10)
    local spawns = {}

    if spawnFolder then
        for _, part in ipairs(spawnFolder:GetChildren()) do
            if part:IsA("BasePart") then
                table.insert(spawns, part)
            end
        end
    else
        warn("Eroare: Nu am găsit folderul PlayerSpawn în Workspace!")
    end

    for index, player in ipairs(activePlayers) do
        -- Only teleport if they are actually in game and alive
        if player and player.Parent == Players then
            local character = player.Character
            if character and character:FindFirstChild("HumanoidRootPart") then
                local spawnPos = Vector3.new(0, 50, 0) -- fallback
                if #spawns > 0 then
                    -- Round robin assign spawns
                    local spawnIndex = ((index - 1) % #spawns) + 1
                    spawnPos = spawns[spawnIndex].Position + Vector3.new(0, 5, 0)
                else
                    spawnPos = Vector3.new((index - 1) * 5, 50, 0)
                end

                character.HumanoidRootPart.CFrame = CFrame.new(spawnPos)
            end
        end
    end
end

return Matchmaking

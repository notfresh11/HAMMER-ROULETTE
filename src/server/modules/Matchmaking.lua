local Matchmaking = {}
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MIN_PLAYERS = 2

function Matchmaking.waitForPlayers()
    print("Matchmaking: Așteptăm minim " .. MIN_PLAYERS .. " jucători...")
    while true do
        if #Players:GetPlayers() >= MIN_PLAYERS then
            break
        end
        task.wait(1)
    end

    print("Matchmaking: Avem suficienți jucători. Începem în 10 secunde.")
    for i = 10, 1, -1 do
        print(i .. "...")
        task.wait(1)
        if #Players:GetPlayers() < MIN_PLAYERS then
            print("Matchmaking anulat: Număr insuficient de jucători.")
            return false
        end
    end
    return true
end

function Matchmaking.teleportPlayersToSpawns()
    print("Matchmaking: Teleportăm jucătorii...")
    -- Support both naming conventions just in case
    local spawnFolder = Workspace:FindFirstChild("PlayerSpawns") or Workspace:FindFirstChild("PlayersSpawn")
    local spawns = {}

    if spawnFolder then
        for _, part in ipairs(spawnFolder:GetChildren()) do
            if part:IsA("BasePart") then
                table.insert(spawns, part)
            end
        end
    else
        warn("Eroare: Nu am găsit folderul PlayerSpawns în Workspace!")
    end

    local currentPlayers = Players:GetPlayers()
    for index, player in ipairs(currentPlayers) do
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

return Matchmaking

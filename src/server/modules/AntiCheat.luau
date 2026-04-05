local AntiCheat = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Stocare pentru datele interne ale anti-cheat-ului
local acData = {}

-- Constante
local MAX_STRIKES = 3
local DEFAULT_WALKSPEED = 16
local CHECK_INTERVAL = 0.5 -- Verificăm la fiecare jumatate de secunda pentru a economisi resurse

local function initPlayerAC(player)
    acData[player.UserId] = {
        Strikes = 0,
        LastPosition = nil,
        LastTick = tick(),
        AirTime = 0,
        Cooldowns = {}
    }

    -- Reset LastPosition when character respawns to prevent false positive teleports
    player.CharacterAdded:Connect(function(character)
        local data = acData[player.UserId]
        if data then
            data.LastPosition = nil
        end
    end)
end

local function cleanupPlayerAC(player)
    acData[player.UserId] = nil
end

local function addStrike(player, reason, oldPosition)
    local data = acData[player.UserId]
    if not data then return end

    data.Strikes = data.Strikes + 1
    warn("AntiCheat: Jucatorul " .. player.Name .. " a primit un strike (" .. data.Strikes .. "/" .. MAX_STRIKES .. ") Motiv: " .. reason)

    if data.Strikes >= MAX_STRIKES then
        player:Kick("AntiCheat Detection: " .. reason)
    else
        -- Rubberband
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and oldPosition then
            player.Character.HumanoidRootPart.CFrame = CFrame.new(oldPosition)
        end
    end
end

-- Funcție generică pentru a verifica cooldown-urile la remote event-uri (abilități, interacțiuni)
function AntiCheat.CheckCooldown(player, actionName, cooldownTime)
    local data = acData[player.UserId]
    if not data then return false end

    local now = tick()
    local lastUsed = data.Cooldowns[actionName]

    if lastUsed and now - lastUsed < cooldownTime then
        -- Încearcă să spameze acțiunea
        warn("AntiCheat: Cooldown bypass detectat pentru " .. player.Name .. " actiunea: " .. actionName)
        -- Nu dăm direct strike pentru cooldown (poate fi lag), dar îi refuzăm acțiunea
        return false
    end

    data.Cooldowns[actionName] = now
    return true
end

-- Funcție pentru a oferi un bypass temporar jucătorului (ex: din scriptul abilității)
function AntiCheat.SetBypass(player, bypassType, duration)
    local char = player.Character
    if char then
        -- duration + 1 secunda extra (cum a cerut utilizatorul pentru siguranță)
        char:SetAttribute(bypassType .. "BypassUntil", tick() + duration + 1)
    end
end

-- Funcție de start loop
function AntiCheat.Start()
    Players.PlayerAdded:Connect(function(player)
        initPlayerAC(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        cleanupPlayerAC(player)
    end)

    -- Inițializare pentru jucătorii deja conectați (în caz că scriptul pornește mai târziu)
    for _, p in ipairs(Players:GetPlayers()) do
        initPlayerAC(p)
    end

    -- Loop principal de detectare (se rulează pe server)
    task.spawn(function()
        while true do
            task.wait(CHECK_INTERVAL)
            local currentTick = tick()

            for _, player in ipairs(Players:GetPlayers()) do
                local data = acData[player.UserId]
                local char = player.Character

                if data and char then
                    local rootPart = char:FindFirstChild("HumanoidRootPart")
                    local humanoid = char:FindFirstChild("Humanoid")

                    if rootPart and humanoid and humanoid.Health > 0 then

                        -- Verificăm dacă are Bypass activ
                        local speedBypass = char:GetAttribute("SpeedBypassUntil") or 0
                        local flyBypass = char:GetAttribute("FlyBypassUntil") or 0

                        -- 1. Anti-Speed / Teleport
                        if currentTick > speedBypass then
                            if data.LastPosition then
                                local distance = (Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z) - Vector3.new(data.LastPosition.X, 0, data.LastPosition.Z)).Magnitude
                                local timeDiff = currentTick - data.LastTick

                                -- Citim viteza maximă permisă în acest moment (dacă nu are abilitate care ignoră total, ci doar crește viteza)
                                local maxAllowedSpeed = char:GetAttribute("MaxSpeedAllowed") or DEFAULT_WALKSPEED

                                -- Threshold: Adăugăm o marjă de eroare pentru ping și fizica roblox (ex: gravity drops)
                                -- Distanta maximă teoretică = Viteza * timpul + marjă de 10 stud-uri
                                local maxExpectedDistance = (maxAllowedSpeed * timeDiff) + 15

                                if distance > maxExpectedDistance then
                                    addStrike(player, "Speed/Teleport Hack", data.LastPosition)
                                    -- Setează poziția last pe actualul DOAR dacă n-a luat rubberband, altfel îl încurcă
                                else
                                    data.LastPosition = rootPart.Position
                                end
                            else
                                data.LastPosition = rootPart.Position
                            end
                        else
                            -- E în bypass de viteză, actualizăm doar poziția ca să nu aibă "salt" uriaș când expiră bypass-ul
                            data.LastPosition = rootPart.Position
                        end
                        data.LastTick = currentTick

                        -- 2. Anti-Fly / Hover
                        if currentTick > flyBypass then
                            local state = humanoid:GetState()
                            if state == Enum.HumanoidStateType.Freefall then
                                -- Dacă stă în aer, verificăm dacă are viteză pe Y mică (plutire/hover)
                                -- În roblox o cădere naturală crește viteza Y foarte repede în minus.
                                -- Dacă velocity Y e aproape 0 dar el e în freefall, zboară.
                                if math.abs(rootPart.AssemblyLinearVelocity.Y) < 5 then
                                    data.AirTime = data.AirTime + CHECK_INTERVAL
                                else
                                    -- Cădere normală sau salt
                                    -- Nu resetăm chiar la 0 imediat, scădem ușor sau resetăm
                                    data.AirTime = 0
                                end

                                -- Dacă plutește de mai mult de 2.5 secunde, dăm strike (rubberband la sol e greu fără raycast, îi dăm la last valid pos)
                                if data.AirTime > 2.5 then
                                    addStrike(player, "Fly/Hover Hack", data.LastPosition)
                                    data.AirTime = 0
                                end
                            else
                                data.AirTime = 0
                            end
                        else
                            data.AirTime = 0
                        end

                    end
                end
            end
        end
    end)
end

return AntiCheat

local MapManager = {}
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local mapWeights = {
    MapSquare = 1,
    MapDonut = 1
}

local currentMapInstance = nil
local currentHammerInstance = nil

-- Create storage folder
local mapStorage = ServerStorage:FindFirstChild("MapStorage")
if not mapStorage then
    mapStorage = Instance.new("Folder")
    mapStorage.Name = "MapStorage"
    mapStorage.Parent = ServerStorage
end

function MapManager.hideAllMaps()
    -- După structura din imagine, ai mutat hărțile direct în ServerStorage!
    -- Muta HammerModel în MapStorage
    local hammerModelFolder = ServerStorage:FindFirstChild("HammerModel")
    if hammerModelFolder then
        -- Dacă este folder (cum ai în poză), vrem să scoatem fix Modelul de ciocan din el
        if hammerModelFolder:IsA("Folder") then
            local actualModel = hammerModelFolder:FindFirstChild("HammerModel") or hammerModelFolder:FindFirstChildWhichIsA("Model")
            if actualModel then
                actualModel.Parent = mapStorage
                actualModel.Name = "HammerModel" -- Standardizăm numele
                hammerModelFolder:Destroy()
            else
                -- Dacă nu găsim un Model, mutăm folderul cumva convertit
                local hm = Instance.new("Model")
                hm.Name = "HammerModel"
                for _, d in ipairs(hammerModelFolder:GetChildren()) do d.Parent = hm end
                hm.Parent = mapStorage
                hammerModelFolder:Destroy()
            end
        else
            hammerModelFolder.Parent = mapStorage
        end
    end

    -- Găsim hărțile din ServerStorage și le convertim în Modele (pentru PivotTo)
    for _, child in ipairs(ServerStorage:GetChildren()) do
        if child.Name:match("^Map") and child.Name ~= "MapStorage" then
            -- Avem nevoie ca ele sa fie Model pentru a folosi PivotTo() mai târziu
            local mapModel
            if child:IsA("Folder") then
                mapModel = Instance.new("Model")
                mapModel.Name = child.Name
                -- Trebuie să folosim un while pt că GetChildren() dintr-un array se scurtează la reparentare
                while #child:GetChildren() > 0 do
                    local elem = child:GetChildren()[1]
                    elem.Parent = mapModel
                end
                child:Destroy()
            else
                mapModel = child
            end
            mapModel.Parent = mapStorage
        end
    end
end

function MapManager.cleanupCurrentMap()
    if currentMapInstance then
        currentMapInstance:Destroy()
        currentMapInstance = nil
    end
    if currentHammerInstance then
        currentHammerInstance:Destroy()
        currentHammerInstance = nil
    end
end

function MapManager.chooseAndSpawnMap()
    MapManager.cleanupCurrentMap()

    local availableMaps = {}
    for _, map in ipairs(mapStorage:GetChildren()) do
        if map:IsA("Model") and mapWeights[map.Name] then
            table.insert(availableMaps, map)
        end
    end

    if #availableMaps == 0 then
        warn("MapManager: Nu a fost găsită nicio hartă validă în MapStorage!")
        return nil, nil
    end

    -- RNG Logic
    local totalWeight = 0
    for _, map in ipairs(availableMaps) do
        totalWeight = totalWeight + (mapWeights[map.Name] or 1)
    end

    -- Folosim Random.new() care este mult mai calitativ și produce entropie reală în Roblox
    local rng = Random.new()
    local randomValue = rng:NextNumber(0, totalWeight)
    local chosenMapTemplate = availableMaps[1]
    local currentSum = 0

    for _, map in ipairs(availableMaps) do
        currentSum = currentSum + (mapWeights[map.Name] or 1)
        if randomValue <= currentSum then
            chosenMapTemplate = map
            break
        end
    end

    print("MapManager: Harta aleasă este " .. chosenMapTemplate.Name)

    -- Clonare harta
    currentMapInstance = chosenMapTemplate:Clone()
    currentMapInstance.Parent = Workspace

    -- Setăm PrimaryPart-ul hărții pe HammerSpawn, pt că userul a zis că el e centrul
    local hammerSpawnFolder = currentMapInstance:FindFirstChild("HammerSpawn")
    local hammerSpawnPart = nil
    if hammerSpawnFolder then
        hammerSpawnPart = hammerSpawnFolder:FindFirstChildWhichIsA("BasePart")
    end

    if not hammerSpawnPart then
        warn("MapManager: Harta " .. currentMapInstance.Name .. " nu are un HammerSpawn valid!")
    else
        currentMapInstance.PrimaryPart = hammerSpawnPart
    end

    -- Teleportam la SpawnMap (Ancora) - care este în interiorul folderului WholeMap acum!
    local wholeMap = Workspace:FindFirstChild("WholeMap")
    local spawnMapTarget = wholeMap and wholeMap:FindFirstChild("SpawnMap")

    if spawnMapTarget and currentMapInstance.PrimaryPart then
        -- Ne asiguram ca e plat pe pamant, luam doar pozitiile si le potrivim
        -- Y-ul trebuie sa tina cont de inaltimea block-urilor
        local yOffset = (spawnMapTarget.Size.Y / 2) + (hammerSpawnPart.Size.Y / 2)
        local targetCFrame = CFrame.new(spawnMapTarget.Position + Vector3.new(0, yOffset, 0))
        currentMapInstance:PivotTo(targetCFrame)
    else
        warn("MapManager: SpawnMap lipseste din WholeMap sau harta nu are PrimaryPart! A rămas pe poziția originală.")
    end

    -- Ascundem block-ul de la HammerSpawn să nu se mai vadă ochiului
    if hammerSpawnPart then
        hammerSpawnPart.Transparency = 1
        hammerSpawnPart.Anchored = true
        hammerSpawnPart.CanCollide = false
    end

    -- Face si PlayerSpawns invizibile
    local playerSpawnsFolder = currentMapInstance:FindFirstChild("PlayerSpawn")
    if playerSpawnsFolder then
        for _, p in ipairs(playerSpawnsFolder:GetDescendants()) do
            if p:IsA("BasePart") then
                p.Transparency = 1
                p.Anchored = true
                p.CanCollide = false
            end
        end
    end

    -- Spawnează Ciocanul Vizual (idle) în centrul hărții
    local hammerModelTemplate = mapStorage:FindFirstChild("HammerModel")
    if hammerModelTemplate and hammerSpawnPart then
        currentHammerInstance = hammerModelTemplate:Clone()
        currentHammerInstance.Parent = Workspace

        local isModel = currentHammerInstance:IsA("Model")
        local hammerHeight = 1

        if isModel then
            if not currentHammerInstance.PrimaryPart then
                currentHammerInstance.PrimaryPart = currentHammerInstance:FindFirstChildWhichIsA("BasePart", true)
            end
            -- Ancora pieselor
            for _, part in ipairs(currentHammerInstance:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = true
                    part.CanCollide = false
                end
            end
            if currentHammerInstance.PrimaryPart then
                hammerHeight = currentHammerInstance.PrimaryPart.Size.Z / 2
            end
        else
            currentHammerInstance.Anchored = true
            currentHammerInstance.CanCollide = false
            if currentHammerInstance:IsA("BasePart") then
                hammerHeight = currentHammerInstance.Size.Z / 2
            end
        end

        -- Plasam fix deasupra centrului (HammerSpawn-ului proaspat mutat)
        local targetHammerCFrame = hammerSpawnPart.CFrame * CFrame.new(0, (hammerSpawnPart.Size.Y/2) + hammerHeight, 0) * CFrame.Angles(math.rad(90), 0, 0)

        if isModel and currentHammerInstance.PrimaryPart then
            currentHammerInstance:PivotTo(targetHammerCFrame)
        elseif currentHammerInstance:IsA("BasePart") then
            currentHammerInstance.CFrame = targetHammerCFrame
        end
    else
        warn("MapManager: HammerModel template lipseste sau nu exista HammerSpawnPart!")
    end

    return currentMapInstance, currentHammerInstance
end

return MapManager
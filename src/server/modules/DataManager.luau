local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local PlayerDataStore = DataStoreService:GetDataStore("PlayerDatabase_V1")

local DataManager = {}
-- Local table to hold data of active players in memory
local playerData = {}

-- Initial structure for a new player
local INITIAL_DATA = {
    Level = 1,
    Xp = 0,
    Coins = 0,
    Items = {},
    KillStreak = 0,
    WinStreak = 0,
    SurviveStreak = 0
}

-- Deep copy function to avoid modifying the template
local function deepCopy(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            v = deepCopy(v)
        end
        copy[k] = v
    end
    return copy
end

-- Reconcile function to ensure missing keys are added from the template
local function reconcileData(data, template)
    for key, val in pairs(template) do
        if data[key] == nil then
            if type(val) == "table" then
                data[key] = deepCopy(val)
            else
                data[key] = val
            end
        elseif type(val) == "table" and type(data[key]) == "table" then
            reconcileData(data[key], val)
        end
    end
    return data
end

-- Called when a player joins to load their data
function DataManager.loadPlayerData(player)
    local playerUserId = "Player_" .. player.UserId
    local data = nil

    local success, errorMessage = pcall(function()
        data = PlayerDataStore:GetAsync(playerUserId)
    end)

    if not success then
        -- Important: If Roblox DataStores are down, we kick the player to prevent data loss.
        warn("Failed to load data for " .. player.Name .. ". Error: " .. tostring(errorMessage))
        player:Kick("Eroare la încărcarea datelor (Roblox DataStores ar putea fi căzute). Te rugăm să reintri pe joc pentru a nu-ți pierde progresul!")
        return
    end

    if not player.Parent then
        -- The player left the game while we were fetching their data from Roblox servers
        -- Don't keep their data floating in server memory
        return
    end

    if data then
        -- Player played before, ensure data structure is up-to-date
        playerData[player.UserId] = reconcileData(data, INITIAL_DATA)
        print("Data loaded for " .. player.Name)
    else
        -- First time playing
        playerData[player.UserId] = deepCopy(INITIAL_DATA)
        print("New data profile created for " .. player.Name)
    end
end

-- Called when a player leaves to save their data safely
function DataManager.savePlayerData(player)
    local userId = player.UserId
    local dataToSave = playerData[userId]

    if not dataToSave then
        -- If data was never loaded (e.g. they got kicked or a script error), don't overwrite with nil.
        return
    end

    local playerUserIdKey = "Player_" .. userId

    local success, errorMessage = pcall(function()
        PlayerDataStore:UpdateAsync(playerUserIdKey, function(oldData)
            -- UpdateAsync is safer. We just overwrite with our current session data.
            -- You could put version checking here in the future if needed.
            return dataToSave
        end)
    end)

    if success then
        print("Data successfully saved for " .. player.Name)
    else
        warn("Failed to save data for " .. player.Name .. ". Error: " .. tostring(errorMessage))
    end

    -- Cleanup memory
    playerData[userId] = nil
end

-- API Functions for other scripts

-- Gets the full data table for a player
function DataManager.GetData(player)
    return playerData[player.UserId]
end

-- Gets a specific value (e.g., Level, Coins)
function DataManager.GetValue(player, key)
    local data = playerData[player.UserId]
    if data then
        return data[key]
    end
    return nil
end

-- Sets a specific value
function DataManager.SetValue(player, key, value)
    local data = playerData[player.UserId]
    if data then
        data[key] = value
    end
end

-- Increments or decrements a number value (e.g., AddCoins(50) -> IncrementValue(player, "Coins", 50))
function DataManager.IncrementValue(player, key, amount)
    local data = playerData[player.UserId]
    if data and type(data[key]) == "number" and type(amount) == "number" then
        data[key] = data[key] + amount
    end
end

return DataManager

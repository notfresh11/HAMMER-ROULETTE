local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Parent.DataManager)

-- Setup RemoteEvent for sending data to client UI
local eventName = "UpdateStatsEvent"
local updateStatsEvent = ReplicatedStorage:FindFirstChild(eventName)
if not updateStatsEvent then
    updateStatsEvent = Instance.new("RemoteEvent")
    updateStatsEvent.Name = eventName
    updateStatsEvent.Parent = ReplicatedStorage
end

local ProgressionManager = {}

-- Formula pentru XP-ul necesar pentru următorul nivel
function ProgressionManager.GetRequiredXP(level)
    return 250 * (level + 1)
end

-- Trimite datele actualizate către client pentru UI
function ProgressionManager.SyncDataToClient(player)
    local data = DataManager.GetData(player)
    if data then
        local reqXp = ProgressionManager.GetRequiredXP(data.Level)
        updateStatsEvent:FireClient(player, data.Level, data.Xp, reqXp, data.Coins)
    end
end

-- Adaugă Coins simplu
function ProgressionManager.AddCoins(player, amount)
    DataManager.IncrementValue(player, "Coins", amount)
    ProgressionManager.SyncDataToClient(player)
end

-- Adaugă XP și verifică Level Up
function ProgressionManager.AddXP(player, amount)
    local data = DataManager.GetData(player)
    if not data then return end

    data.Xp = data.Xp + amount
    local reqXp = ProgressionManager.GetRequiredXP(data.Level)

    local levelUpCount = 0
    -- Tratăm cazul în care primește suficient XP pentru mai multe nivele deodată
    while data.Xp >= reqXp do
        data.Xp = data.Xp - reqXp
        data.Level = data.Level + 1
        levelUpCount = levelUpCount + 1
        reqXp = ProgressionManager.GetRequiredXP(data.Level)
    end

    if levelUpCount > 0 then
        -- Oferă 50 Coins pentru fiecare nivel crescut
        data.Coins = data.Coins + (50 * levelUpCount)
        print(player.Name .. " a crescut in nivel! Acum este nivelul " .. data.Level)
    end

    ProgressionManager.SyncDataToClient(player)
end

-- Participare la meci
function ProgressionManager.ProcessMatchParticipation(player)
    ProgressionManager.AddCoins(player, 50)
    ProgressionManager.AddXP(player, 50)
end

-- Castigare Meci
function ProgressionManager.ProcessMatchWin(player)
    local data = DataManager.GetData(player)
    if not data then return end

    data.WinStreak = data.WinStreak + 1
    -- 200 base + winstreak multiplier
    local streakMultiplier = math.max(1, data.WinStreak * 1.5)

    local xpReward = math.floor(200 * streakMultiplier)

    -- Castigul de baza pe coins e 500, nu ai cerut multiplier la coins pt win, dar dam baza
    ProgressionManager.AddCoins(player, 500)
    ProgressionManager.AddXP(player, xpReward)
end

-- Supravietuire Runda
function ProgressionManager.ProcessRoundSurvive(player)
    local data = DataManager.GetData(player)
    if not data then return end

    data.SurviveStreak = data.SurviveStreak + 1
    local streakMultiplier = math.max(1, data.SurviveStreak * 1.5)

    local xpReward = math.floor(25 * streakMultiplier)
    ProgressionManager.AddXP(player, xpReward)
end

-- Kill
function ProgressionManager.ProcessKill(player)
    local data = DataManager.GetData(player)
    if not data then return end

    data.KillStreak = data.KillStreak + 1
    local streakMultiplier = math.max(1, data.KillStreak * 1.5)

    local coinsReward = math.floor(50 * streakMultiplier)
    local xpReward = math.floor(50 * streakMultiplier)

    ProgressionManager.AddCoins(player, coinsReward)
    ProgressionManager.AddXP(player, xpReward)
end

-- Resetam streak-urile cand jucatorul moare
function ProgressionManager.ResetStreaks(player)
    local data = DataManager.GetData(player)
    if not data then return end

    data.KillStreak = 0
    data.WinStreak = 0
    data.SurviveStreak = 0
end

return ProgressionManager

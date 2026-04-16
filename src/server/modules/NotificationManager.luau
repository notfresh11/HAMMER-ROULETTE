local MessagingService = game:GetService("MessagingService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Parent.DataManager)
local PartyManager = require(script.Parent.PartyManager)

local TOPIC = "GlobalNotifications"

local NotificationManager = {}

local function sendNotificationReceivedEvent(player, notifType, senderUserId, senderName, additionalData)
    local ev = ReplicatedStorage:FindFirstChild("NotificationReceivedEvent")
    if ev then
        ev:FireClient(player, {
            type = notifType,
            senderUserId = senderUserId,
            senderName = senderName,
            data = additionalData
        })
    end
end

function NotificationManager.Init()
    local SendNotificationEvent = ReplicatedStorage:WaitForChild("SendNotificationEvent")
    local NotificationAnswerEvent = ReplicatedStorage:WaitForChild("NotificationAnswerEvent")
    local FetchFriendsFunction = ReplicatedStorage:WaitForChild("FetchFriendsFunction")

    -- Handle Cross-Server Messages
    pcall(function()
        MessagingService:SubscribeAsync(TOPIC, function(message)
            local data = message.Data
            if type(data) ~= "table" then return end

            local targetUserId = data.targetUserId
            local senderUserId = data.senderUserId
            local senderName = data.senderName
            local notifType = data.type
            local additionalData = data.additionalData

            local targetPlayer = Players:GetPlayerByUserId(targetUserId)
            if targetPlayer then
                sendNotificationReceivedEvent(targetPlayer, notifType, senderUserId, senderName, additionalData)
            end
        end)
    end)

    -- Client wants to send a notification (Friend, Game, Party)
    SendNotificationEvent.OnServerEvent:Connect(function(player, targetUserId, notifType)
        if type(targetUserId) ~= "number" then return end

        -- Prevent sending to self
        if player.UserId == targetUserId then return end

        local additionalData = {}
        if notifType == "GameInvite" or notifType == "PartyInvite" then
            additionalData.jobId = game.JobId
            additionalData.placeId = game.PlaceId
        end

        local targetPlayer = Players:GetPlayerByUserId(targetUserId)
        if targetPlayer then
            -- Target is on the same server
            sendNotificationReceivedEvent(targetPlayer, notifType, player.UserId, player.Name, additionalData)
        else
            -- Send globally
            pcall(function()
                MessagingService:PublishAsync(TOPIC, {
                    targetUserId = targetUserId,
                    senderUserId = player.UserId,
                    senderName = player.Name,
                    type = notifType,
                    additionalData = additionalData
                })
            end)
        end
    end)

    -- Client responds to a notification
    NotificationAnswerEvent.OnServerEvent:Connect(function(player, response, notifType, senderUserId, additionalData)
        if response ~= "Accept" then return end

        if notifType == "FriendRequest" then
            -- Both become friends
            DataManager.AddFriend(player.UserId, senderUserId)
            print("[NotificationManager] Friend request accepted between " .. player.Name .. " and UserId " .. tostring(senderUserId))

        elseif notifType == "PartyInvite" then
            if additionalData and additionalData.jobId and additionalData.jobId ~= game.JobId then
                -- Teleport to the server where the party is
                local teleportOptions = Instance.new("TeleportOptions")
                teleportOptions.ServerInstanceId = additionalData.jobId
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(additionalData.placeId, additionalData.jobId, player, nil, nil, nil)
                end)
                -- Note: They won't automatically join the party upon teleport due to cross-server limitations unless passed via join data,
                -- which is complex, but teleporting is the first step as requested.
            else
                -- Try to join party natively on this server
                local targetPlayer = Players:GetPlayerByUserId(senderUserId)
                if targetPlayer then
                    PartyManager.HandleAction(player, "join", {targetUsername = targetPlayer.Name})
                end
            end

        elseif notifType == "GameInvite" then
            if additionalData and additionalData.jobId and additionalData.jobId ~= game.JobId then
                local teleportOptions = Instance.new("TeleportOptions")
                teleportOptions.ServerInstanceId = additionalData.jobId
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(additionalData.placeId, additionalData.jobId, player, nil, nil, nil)
                end)
            end
        end
    end)

    -- Client fetches friends
    FetchFriendsFunction.OnServerInvoke = function(player)
        local friendsIds = DataManager.GetFriends(player)
        local friendsData = {}
        for _, fId in ipairs(friendsIds) do
            -- Look up names. Note: this can yield. We use GetNameFromUserIdAsync
            local s, name = pcall(function()
                return Players:GetNameFromUserIdAsync(fId)
            end)
            if s and name then
                table.insert(friendsData, {Id = fId, Username = name})
            end
        end
        return friendsData
    end
end

return NotificationManager

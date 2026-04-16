local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)
local PartyManager = require(script.Parent.PartyManager)

local NotificationManager = {}

local TOPIC = "GlobalNotifications"

local notificationEvent
local notificationResponseEvent
local sendNotificationEvent

-- Cooldowns to prevent spam [senderId_targetId_type] = tick()
local cooldowns = {}
local COOLDOWN_TIME = 10 -- seconds

function NotificationManager.Start()
    print("[DEBUG] NotificationManager.Start() apelat.")
    notificationEvent = ReplicatedStorage:WaitForChild("NotificationEvent")
    notificationResponseEvent = ReplicatedStorage:WaitForChild("NotificationResponseEvent")
    sendNotificationEvent = ReplicatedStorage:WaitForChild("SendNotificationEvent")

    local fetchFriendsFunction = ReplicatedStorage:WaitForChild("FetchFriendsFunction")
    fetchFriendsFunction.OnServerInvoke = function(player)
        local friendsData = DataManager.GetFriends(player)
        local friendList = {}
        for friendIdStr, _ in pairs(friendsData) do
            local idNum = tonumber(friendIdStr)
            if idNum then
                local isOnline = false
                local name = "Unknown"

                local friendPlayer = Players:GetPlayerByUserId(idNum)
                if friendPlayer then
                    isOnline = true
                    name = friendPlayer.Name
                else
                    pcall(function() name = Players:GetNameFromUserIdAsync(idNum) end)
                end

                table.insert(friendList, {Id = idNum, Username = name, IsOnline = isOnline})
            end
        end
        return friendList
    end

    -- Subscribe to cross-server notifications
    local success, err = pcall(function()
        MessagingService:SubscribeAsync(TOPIC, function(message)
            local data = message.Data
            if type(data) == "table" then
                local targetId = data.TargetId
                local targetPlayer = Players:GetPlayerByUserId(targetId)
                if targetPlayer then
                    -- The target is in this server!
                    notificationEvent:FireClient(targetPlayer, data)
                end
            end
        end)
    end)
    if not success then
        warn("NotificationManager: Failed to subscribe to MessagingService: " .. tostring(err))
    end

    -- Handle client requesting to send a notification (e.g. from UI)
    sendNotificationEvent.OnServerEvent:Connect(function(player, targetUsername, notifType)
        if type(targetUsername) ~= "string" or type(notifType) ~= "string" then return end

        -- Validate NotifType
        if notifType == "Unfriend" then
            local targetId
            local s, e = pcall(function() targetId = Players:GetUserIdFromNameAsync(targetUsername) end)
            if s and targetId then
                DataManager.RemoveFriend(player, targetId)
                -- Also remove offline from target
                DataManager.ModifyOfflineFriend(targetId, player.UserId, false)
            end
            return
        end

        if notifType ~= "FriendRequest" and notifType ~= "PartyInvite" and notifType ~= "GameInvite" then return end

        local targetId
        local s, e = pcall(function()
            targetId = Players:GetUserIdFromNameAsync(targetUsername)
        end)

        if not s or not targetId then
            warn("NotificationManager: Could not find UserId for " .. tostring(targetUsername))
            return
        end

        if targetId == player.UserId then
            -- Can't invite/friend self
            return
        end

        local cooldownKey = player.UserId .. "_" .. targetId .. "_" .. notifType
        if cooldowns[cooldownKey] and tick() - cooldowns[cooldownKey] < COOLDOWN_TIME then
            -- Cooldown active
            return
        end
        cooldowns[cooldownKey] = tick()

        local payload = {
            SenderId = player.UserId,
            SenderName = player.Name,
            TargetId = targetId,
            Type = notifType,
            JobId = game.JobId -- Used for cross-server teleporting
        }

        -- Check if target is in the same server to skip MessagingService latency
        local targetPlayer = Players:GetPlayerByUserId(targetId)
        if targetPlayer then
            notificationEvent:FireClient(targetPlayer, payload)
        else
            -- Publish globally
            pcall(function()
                MessagingService:PublishAsync(TOPIC, payload)
            end)
        end
    end)

    -- Handle client responding to a notification
    notificationResponseEvent.OnServerEvent:Connect(function(player, responseData)
        if type(responseData) ~= "table" then return end

        local action = responseData.Action -- "Accept" or "Decline"
        local payload = responseData.Payload

        if not payload or type(payload) ~= "table" then return end

        -- Payload should contain what we sent them originally
        local senderId = payload.SenderId
        local notifType = payload.Type
        local jobId = payload.JobId

        if action == "Accept" then
            if notifType == "FriendRequest" then
                -- Add to each other's datastore
                -- Add target to sender's friend list (offline safe)
                local senderPlayer = Players:GetPlayerByUserId(senderId)
                if senderPlayer then
                    DataManager.AddFriend(senderPlayer, player.UserId)
                else
                    DataManager.ModifyOfflineFriend(senderId, player.UserId, true)
                end

                -- Add sender to target's friend list
                DataManager.AddFriend(player, senderId)

                print("NotificationManager: Friend Request accepted between " .. player.Name .. " and UserId " .. senderId)

            elseif notifType == "GameInvite" or notifType == "PartyInvite" then
                if jobId == game.JobId then
                    -- Same server
                    if notifType == "PartyInvite" then
                        local senderPlayer = Players:GetPlayerByUserId(senderId)
                        if senderPlayer then
                            PartyManager.invitePlayer(senderPlayer, player.Name)
                        end
                    end
                else
                    -- Different server, need to teleport
                    -- For PartyInvite, we can pass teleportData
                    local teleportData = nil
                    if notifType == "PartyInvite" then
                        teleportData = { JoinPartyOwnerId = senderId }
                    end

                    local s, e = pcall(function()
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, player, nil, teleportData)
                    end)
                    if not s then
                        warn("NotificationManager: Teleport failed: " .. tostring(e))
                    end
                end
            end
        elseif action == "Decline" then
            -- We just ignore, the UI already closed it.
            print("NotificationManager: " .. player.Name .. " declined " .. notifType .. " from " .. tostring(payload.SenderName))
        end
    end)

    -- Handle players joining with teleport data (Accepting cross server party invites)
    Players.PlayerAdded:Connect(function(player)
        local joinData = player:GetJoinData()
        if joinData and joinData.TeleportData then
            local tpData = joinData.TeleportData
            if type(tpData) == "table" and tpData.JoinPartyOwnerId then
                -- They accepted a party invite and teleported here. Let's add them to the party.
                task.spawn(function()
                    -- Wait for data to load and party to be created
                    task.wait(3)
                    local ownerPlayer = Players:GetPlayerByUserId(tpData.JoinPartyOwnerId)
                    if ownerPlayer then
                        PartyManager.invitePlayer(ownerPlayer, player.Name)
                        print("NotificationManager: Automatically added " .. player.Name .. " to " .. ownerPlayer.Name .. "'s party after teleport.")
                    end
                end)
            end
        end
    end)
end

return NotificationManager

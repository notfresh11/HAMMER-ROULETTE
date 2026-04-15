local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartyManager = {}

-- parties = {
--   [partyId] = { owner = userId, members = { userId1, userId2, ... } }
-- }
local parties = {}
-- playerPartyMap = { [userId] = partyId }
local playerPartyMap = {}

local partyUpdateEvent = ReplicatedStorage:FindFirstChild("PartyUpdateEvent")
local partyActionEvent = ReplicatedStorage:FindFirstChild("PartyActionEvent")

local nextPartyId = 1

local function getPlayer(userId)
    return Players:GetPlayerByUserId(userId)
end

local function sendUpdateToParty(partyId)
    if not partyUpdateEvent then return end
    local party = parties[partyId]
    if not party then return end

    local ownerName = "UNKNOWN"
    local ownerPlayer = getPlayer(party.owner)
    if ownerPlayer then
        ownerName = ownerPlayer.Name
    end

    local payload = {
        owner = party.owner,
        ownerName = ownerName,
        members = {}
    }

    for _, memberId in ipairs(party.members) do
        local member = getPlayer(memberId)
        if member then
            table.insert(payload.members, {
                userId = memberId,
                name = member.Name
            })
        end
    end

    -- Trimitem update la toti membrii din party
    for _, memberId in ipairs(party.members) do
        local member = getPlayer(memberId)
        if member then
            partyUpdateEvent:FireClient(member, payload)
        end
    end
end

function PartyManager.createParty(ownerPlayer)
    if not ownerPlayer then return end

    local pId = "Party_" .. nextPartyId
    nextPartyId = nextPartyId + 1

    parties[pId] = {
        owner = ownerPlayer.UserId,
        members = { ownerPlayer.UserId }
    }
    playerPartyMap[ownerPlayer.UserId] = pId

    sendUpdateToParty(pId)
end

function PartyManager.leaveParty(userId)
    local pId = playerPartyMap[userId]
    if not pId then return end

    local party = parties[pId]
    if not party then return end

    -- Remove from members
    for i, memberId in ipairs(party.members) do
        if memberId == userId then
            table.remove(party.members, i)
            break
        end
    end
    playerPartyMap[userId] = nil

    if #party.members == 0 then
        -- Destroy party
        parties[pId] = nil
    else
        -- If owner left, reassign owner
        if party.owner == userId then
            local newOwnerId = party.members[math.random(1, #party.members)]
            party.owner = newOwnerId
        end
        sendUpdateToParty(pId)
    end

    -- Recreate 1/4 party if the user is still in game
    local player = getPlayer(userId)
    if player then
        PartyManager.createParty(player)
    end
end

function PartyManager.invitePlayer(inviterPlayer, targetUsername)
    local pId = playerPartyMap[inviterPlayer.UserId]
    if not pId then return end

    local party = parties[pId]
    if not party then return end

    if #party.members >= 4 then
        -- Party full
        return
    end

    local targetPlayer = Players:FindFirstChild(targetUsername)
    if not targetPlayer then return end

    if playerPartyMap[targetPlayer.UserId] == pId then
        -- Deja in party
        return
    end

    -- Fortam jucatorul sa iasa din party-ul actual si sa intre in cel nou (pentru testing)
    PartyManager.leaveParty(targetPlayer.UserId)

    -- Anulam crearea de party 1/4 din leaveParty stergandu-l din vechiul party (LeaveParty creeaza unul automat, deci il scoatem iar)
    local oldNewPId = playerPartyMap[targetPlayer.UserId]
    if oldNewPId then
        local oldNewParty = parties[oldNewPId]
        if oldNewParty and oldNewParty.owner == targetPlayer.UserId and #oldNewParty.members == 1 then
            parties[oldNewPId] = nil
            playerPartyMap[targetPlayer.UserId] = nil
        end
    end

    table.insert(party.members, targetPlayer.UserId)
    playerPartyMap[targetPlayer.UserId] = pId

    sendUpdateToParty(pId)
end

function PartyManager.kickPlayer(ownerPlayer, targetUserId)
    local pId = playerPartyMap[ownerPlayer.UserId]
    if not pId then return end

    local party = parties[pId]
    if not party then return end

    if party.owner ~= ownerPlayer.UserId then
        return -- Doar owner poate da kick
    end

    if ownerPlayer.UserId == targetUserId then
        return -- Nu isi poate da kick singur
    end

    -- Verify target is in party
    local inParty = false
    for _, id in ipairs(party.members) do
        if id == targetUserId then
            inParty = true
            break
        end
    end

    if inParty then
        PartyManager.leaveParty(targetUserId)
    end
end

function PartyManager.promotePlayer(ownerPlayer, targetUserId)
    local pId = playerPartyMap[ownerPlayer.UserId]
    if not pId then return end

    local party = parties[pId]
    if not party then return end

    if party.owner ~= ownerPlayer.UserId then
        return -- Doar owner poate promova
    end

    -- Verify target is in party
    local inParty = false
    for _, id in ipairs(party.members) do
        if id == targetUserId then
            inParty = true
            break
        end
    end

    if inParty then
        party.owner = targetUserId
        sendUpdateToParty(pId)
    end
end

-- Events and initialization
local function onPlayerAdded(player)
    -- La conectare, jucatorul isi creeaza propriul party 1/4
    PartyManager.createParty(player)
end

local function onPlayerRemoving(player)
    PartyManager.leaveParty(player.UserId)
    -- Nu trebuie curatat 1/4 care s-a creat in leaveParty, pt ca playerul oricum a iesit,
    -- dar sa fim siguri il curatam direct:
    local pId = playerPartyMap[player.UserId]
    if pId then
        parties[pId] = nil
        playerPartyMap[player.UserId] = nil
    end
end

function PartyManager.Init()
    partyUpdateEvent = ReplicatedStorage:FindFirstChild("PartyUpdateEvent")
    partyActionEvent = ReplicatedStorage:FindFirstChild("PartyActionEvent")

    if not partyUpdateEvent or not partyActionEvent then
        warn("PartyManager: Missing RemoteEvents")
        return
    end

    Players.PlayerAdded:Connect(onPlayerAdded)
    for _, player in ipairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end
    Players.PlayerRemoving:Connect(onPlayerRemoving)

    partyActionEvent.OnServerEvent:Connect(function(player, action, payload)
        if action == "invite" then
            local targetUsername = payload.targetUsername
            if targetUsername then
                PartyManager.invitePlayer(player, targetUsername)
            end
        elseif action == "kick" then
            local targetUserId = payload.targetUserId
            if targetUserId then
                PartyManager.kickPlayer(player, targetUserId)
            end
        elseif action == "promote" then
            local targetUserId = payload.targetUserId
            if targetUserId then
                PartyManager.promotePlayer(player, targetUserId)
            end
        elseif action == "leave" then
            PartyManager.leaveParty(player.UserId)
        elseif action == "fetch" then
            local pId = playerPartyMap[player.UserId]
            if pId then
                sendUpdateToParty(pId)
            end
        end
    end)
end

return PartyManager

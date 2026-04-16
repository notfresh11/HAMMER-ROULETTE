local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local socialGui = playerGui:WaitForChild("Social", 10)

if not socialGui then
    warn("NotificationUI: Could not find Social GUI.")
    return
end

local notifFrame = socialGui:WaitForChild("Notif", 10)
if not notifFrame then
    warn("NotificationUI: Could not find Notif Frame.")
    return
end

local friendRequestTemplate = notifFrame:FindFirstChild("FriendRequest")
local partyInviteTemplate = notifFrame:FindFirstChild("PartyInvite")
local gameInviteTemplate = notifFrame:FindFirstChild("GameInvite")

-- Hide them initially
if friendRequestTemplate then friendRequestTemplate.Visible = false end
if partyInviteTemplate then partyInviteTemplate.Visible = false end
if gameInviteTemplate then gameInviteTemplate.Visible = false end

local notificationEvent = ReplicatedStorage:WaitForChild("NotificationEvent")
local notificationResponseEvent = ReplicatedStorage:WaitForChild("NotificationResponseEvent")

local notificationQueue = {}
local isDisplaying = false
local currentActiveNotifUI = nil
local currentActiveConnectionAccept = nil
local currentActiveConnectionDecline = nil

local DISPLAY_TIME = 15 -- seconds

local function showNextNotification()
    if isDisplaying or #notificationQueue == 0 then return end

    -- Check if player is in match. If so, don't show, just leave in queue.
    if player:GetAttribute("InMatch") then return end

    isDisplaying = true
    local payload = table.remove(notificationQueue, 1)

    local templateToUse
    local messageText = ""

    if payload.Type == "FriendRequest" then
        templateToUse = friendRequestTemplate
        messageText = payload.SenderName .. " SENT YOU A FRIEND REQUEST"
    elseif payload.Type == "PartyInvite" then
        templateToUse = partyInviteTemplate
        messageText = payload.SenderName .. " SENT YOU A PARTY INVITE"
    elseif payload.Type == "GameInvite" then
        templateToUse = gameInviteTemplate
        messageText = payload.SenderName .. " WANTS YOU TO JOIN THEIR GAME"
    end

    if not templateToUse then
        isDisplaying = false
        showNextNotification()
        return
    end

    -- Setup UI
    templateToUse.Visible = true
    -- Ensure scale is 0 for pop-in effect
    templateToUse.Size = UDim2.new(0, 0, 0, 0)

    local msgLabel = templateToUse:FindFirstChild("Message")
    if msgLabel then
        msgLabel.Text = messageText
    end

    local acceptBtn = templateToUse:FindFirstChild("AcceptButton")
    local declineBtn = templateToUse:FindFirstChild("DeclineButton")

    currentActiveNotifUI = templateToUse

    -- Tween In
    local origSize = templateToUse:GetAttribute("OriginalSize")
    if not origSize then
        origSize = templateToUse.Size
        if origSize.X.Scale == 0 and origSize.X.Offset == 0 then
            origSize = UDim2.new(1, 0, 0.2, 0) -- Ultimate Fallback
        end
        templateToUse:SetAttribute("OriginalSize", origSize)
    end
    templateToUse.Size = UDim2.new(0, 0, 0, 0)
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local tweenIn = TweenService:Create(templateToUse, tweenInfo, {Size = origSize})
    tweenIn:Play()

    local isResolved = false

    local function resolve(action)
        if isResolved then return end
        isResolved = true

        if currentActiveConnectionAccept then currentActiveConnectionAccept:Disconnect() end
        if currentActiveConnectionDecline then currentActiveConnectionDecline:Disconnect() end

        -- Send response
        notificationResponseEvent:FireServer({
            Action = action,
            Payload = payload
        })

        -- Tween Out
        local tweenOutInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
        local tweenOut = TweenService:Create(templateToUse, tweenOutInfo, {Size = UDim2.new(0,0,0,0)})
        tweenOut:Play()

        tweenOut.Completed:Connect(function()
            templateToUse.Visible = false
            currentActiveNotifUI = nil
            isDisplaying = false
            -- Small delay before next notif
            task.wait(0.5)
            showNextNotification()
        end)
    end

    if acceptBtn then
        currentActiveConnectionAccept = acceptBtn.MouseButton1Click:Connect(function()
            resolve("Accept")
        end)
    end

    if declineBtn then
        currentActiveConnectionDecline = declineBtn.MouseButton1Click:Connect(function()
            resolve("Decline")
        end)
    end

    -- Auto decline after DISPLAY_TIME
    task.delay(DISPLAY_TIME, function()
        if not isResolved then
            resolve("Decline")
        end
    end)
end

-- Listen for incoming notifications
notificationEvent.OnClientEvent:Connect(function(payload)
    -- Check if it's already in queue (shouldn't happen with server cooldowns, but good practice)
    for _, item in ipairs(notificationQueue) do
        if item.SenderId == payload.SenderId and item.Type == payload.Type then
            return
        end
    end

    table.insert(notificationQueue, payload)
    showNextNotification()
end)

-- If player returns to lobby from a match, check queue
player:GetAttributeChangedSignal("InMatch"):Connect(function()
    local inMatch = player:GetAttribute("InMatch")
    if not inMatch then
        -- Returned to lobby
        task.wait(1) -- small delay to let UI settle
        showNextNotification()
    else
        -- Entered match. If currently displaying, hide it (and act like decline to clear state)
        if isDisplaying and currentActiveNotifUI then
            -- Optional: we can just leave it, or auto-hide. User wanted "Doar in lobby si training"
            -- We'll just let it expire in the background or hide it.
            -- To be safe, we just let it expire via the 15s timer. But if they entered match, the next one won't pop up.
        end
    end
end)

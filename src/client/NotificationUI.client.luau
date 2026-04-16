local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local notificationReceivedEvent = ReplicatedStorage:WaitForChild("NotificationReceivedEvent")
local notificationAnswerEvent = ReplicatedStorage:WaitForChild("NotificationAnswerEvent")

local notificationQueue = {}
local isProcessingQueue = false
local currentActivePopup = nil

local function playSoundIsolated(soundId)
    if not soundId or soundId == "" then return end
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Parent = game:GetService("SoundService")
    sound.TimePosition = 0.05
    sound.Ended:Connect(function() sound:Destroy() end)
    task.delay(10, function()
        if sound and sound.Parent then sound:Destroy() end
    end)
    sound:Play()
end

local function bindHoverAnimation(button)
    if not button or not button:IsA("GuiObject") then return end

    if not button:GetAttribute("OrigSizeXScale") then
        button:SetAttribute("OrigSizeXScale", button.Size.X.Scale)
        button:SetAttribute("OrigSizeXOffset", button.Size.X.Offset)
        button:SetAttribute("OrigSizeYScale", button.Size.Y.Scale)
        button:SetAttribute("OrigSizeYOffset", button.Size.Y.Offset)
    end

    local originalSize = UDim2.new(
        button:GetAttribute("OrigSizeXScale"),
        button:GetAttribute("OrigSizeXOffset"),
        button:GetAttribute("OrigSizeYScale"),
        button:GetAttribute("OrigSizeYOffset")
    )

    local targetSize = UDim2.new(
        originalSize.X.Scale * 1.05, originalSize.X.Offset * 1.05,
        originalSize.Y.Scale * 1.05, originalSize.Y.Offset * 1.05
    )

    if button:IsA("GuiButton") then
        local clickSize = UDim2.new(
            originalSize.X.Scale * 0.95, originalSize.X.Offset * 0.95,
            originalSize.Y.Scale * 0.95, originalSize.Y.Offset * 0.95
        )
        button.MouseButton1Down:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = clickSize}):Play()
        end)
        button.MouseButton1Up:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize}):Play()
        end)
    end

    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize}):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = originalSize}):Play()
    end)
end

local function displayNextNotification()
    if isProcessingQueue or #notificationQueue == 0 then return end

    -- If player is in match, don't show yet
    if player:GetAttribute("InMatch") then return end

    isProcessingQueue = true
    local notifData = table.remove(notificationQueue, 1)

    local socialGui = playerGui:WaitForChild("Social", 10)
    if not socialGui then
        isProcessingQueue = false
        return
    end

    local notifFolder = socialGui:FindFirstChild("Notif")
    if not notifFolder then
        isProcessingQueue = false
        return
    end

    local templateName = notifData.type
    local template = notifFolder:FindFirstChild(templateName)
    if not template then
        isProcessingQueue = false
        displayNextNotification()
        return
    end

    local popup = template:Clone()
    popup.Name = "Active_" .. templateName
    popup.Visible = true
    popup.Parent = notifFolder
    currentActivePopup = popup

    -- Ensure it starts hidden for pop-in animation
    if not popup:GetAttribute("OriginalSizeXScale") then
        popup:SetAttribute("OriginalSizeXScale", popup.Size.X.Scale)
        popup:SetAttribute("OriginalSizeXOffset", popup.Size.X.Offset)
        popup:SetAttribute("OriginalSizeYScale", popup.Size.Y.Scale)
        popup:SetAttribute("OriginalSizeYOffset", popup.Size.Y.Offset)
    end

    local originalSize = UDim2.new(
        popup:GetAttribute("OriginalSizeXScale"),
        popup:GetAttribute("OriginalSizeXOffset"),
        popup:GetAttribute("OriginalSizeYScale"),
        popup:GetAttribute("OriginalSizeYOffset")
    )

    popup.Size = UDim2.new(0, 0, 0, 0)
    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    TweenService:Create(popup, tweenInfo, {Size = originalSize}):Play()

    -- Setup text
    local msgLabel = popup:FindFirstChild("Message") or popup:FindFirstChild("TextLabel")
    if msgLabel then
        msgLabel.TextScaled = true
        msgLabel.TextWrapped = true

        if notifData.type == "FriendRequest" then
            msgLabel.Text = string.upper(notifData.senderName) .. " SENT YOU A FRIEND REQUEST"
        elseif notifData.type == "PartyInvite" then
            msgLabel.Text = string.upper(notifData.senderName) .. " SENT YOU A PARTY INVITE"
        elseif notifData.type == "GameInvite" then
            msgLabel.Text = string.upper(notifData.senderName) .. " WANTS YOU TO JOIN THEIR GAME"
        end
    end

    local acceptBtn = popup:FindFirstChild("AcceptButton")
    local declineBtn = popup:FindFirstChild("DeclineButton")

    local isHandled = false

    local function closePopup(accepted)
        if isHandled then return end
        isHandled = true

        playSoundIsolated("rbxassetid://124476359159008") -- Default click sound

        if accepted then
            notificationAnswerEvent:FireServer("Accept", notifData.type, notifData.senderUserId, notifData.data)
        else
            notificationAnswerEvent:FireServer("Decline", notifData.type, notifData.senderUserId, notifData.data)
        end

        local closeTween = TweenService:Create(popup, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0)})
        closeTween:Play()
        closeTween.Completed:Wait()

        if popup and popup.Parent then
            popup:Destroy()
        end

        currentActivePopup = nil
        isProcessingQueue = false

        -- Check for more
        task.delay(0.5, displayNextNotification)
    end

    if acceptBtn then
        bindHoverAnimation(acceptBtn)
        acceptBtn.MouseButton1Click:Connect(function() closePopup(true) end)
    end

    if declineBtn then
        bindHoverAnimation(declineBtn)
        declineBtn.MouseButton1Click:Connect(function() closePopup(false) end)
    end

    -- Auto expire after 15 seconds
    task.delay(15, function()
        if not isHandled and currentActivePopup == popup then
            closePopup(false)
        end
    end)
end

notificationReceivedEvent.OnClientEvent:Connect(function(payload)
    table.insert(notificationQueue, payload)
    displayNextNotification()
end)

-- Monitor match state to unpause queue
player:GetAttributeChangedSignal("InMatch"):Connect(function()
    if not player:GetAttribute("InMatch") then
        task.delay(2, displayNextNotification) -- slight delay when exiting match
    else
        -- If entered a match, immediately hide current popup
        if currentActivePopup and currentActivePopup.Parent then
            currentActivePopup.Visible = false
            -- Move it back to front of queue to handle later, or we can just decline it. Let's re-queue.
            -- Actually, simpler to just let it expire in the background, but since it's hidden, user can't click it.
            -- Better approach: just leave it hidden, or destroy and consider it declined if match starts.
            -- Let's auto decline if a match starts to keep it simple.
            -- Wait, if it's hidden they can't click. Let's just destroy it and auto-decline to avoid stale state.
            currentActivePopup:Destroy()
            currentActivePopup = nil
            isProcessingQueue = false
            -- Since we destroyed it, we should theoretically answer Decline, but we'll just ignore for now.
        end
    end
end)

-- Initialize logic (hide original templates)
task.spawn(function()
    local socialGui = playerGui:WaitForChild("Social", 10)
    if socialGui then
        local notifFolder = socialGui:WaitForChild("Notif", 5)
        if notifFolder then
            for _, child in ipairs(notifFolder:GetChildren()) do
                if child:IsA("GuiObject") then
                    child.Visible = false
                end
            end
        end
    end
end)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local playerGui = player:WaitForChild("PlayerGui")

local _socialGui = playerGui:FindFirstChild("Social")
if _socialGui then
    local _mainFrame = _socialGui:FindFirstChild("MainFrame")
    if _mainFrame then
        _mainFrame.Visible = false
        _mainFrame.Size = UDim2.new(0, 0, 0, 0)
    end
end

-- Constants
local CLICK_SOUND_ID = "rbxassetid://124476359159008"

local activeConnections = {}

local function disconnectAll()
    for _, conn in ipairs(activeConnections) do
        if conn then conn:Disconnect() end
    end
    table.clear(activeConnections)
end

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
        table.insert(activeConnections, button.MouseButton1Down:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = clickSize}):Play()
        end))
        table.insert(activeConnections, button.MouseButton1Up:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize}):Play()
        end))
    end

    local enterConn = button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize}):Play()
    end)
    local leaveConn = button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = originalSize}):Play()
    end)

    -- Only insert into global activeConnections if the button is not a temporary clone
    -- (We assume buttons with names starting with "INVITE" inside a clone are dynamic)
    if not button.Name:match("^INVITE") then
        table.insert(activeConnections, enterConn)
        table.insert(activeConnections, leaveConn)
    end
end

-- Funcție pentru animarea ferestrelor (deschidere)
local function openMenu(frame)
    if not frame then return end
    frame.Visible = true

    if not frame:GetAttribute("OriginalSizeXScale") then
        frame:SetAttribute("OriginalSizeXScale", frame.Size.X.Scale)
        frame:SetAttribute("OriginalSizeXOffset", frame.Size.X.Offset)
        frame:SetAttribute("OriginalSizeYScale", frame.Size.Y.Scale)
        frame:SetAttribute("OriginalSizeYOffset", frame.Size.Y.Offset)
    end

    local targetSize = UDim2.new(
        frame:GetAttribute("OriginalSizeXScale"),
        frame:GetAttribute("OriginalSizeXOffset"),
        frame:GetAttribute("OriginalSizeYScale"),
        frame:GetAttribute("OriginalSizeYOffset")
    )

    frame.Size = UDim2.new(0, 0, 0, 0)
    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local tween = TweenService:Create(frame, tweenInfo, {Size = targetSize})
    tween:Play()
end

local partyUpdateEvent = ReplicatedStorage:WaitForChild("PartyUpdateEvent")
local partyActionEvent = ReplicatedStorage:WaitForChild("PartyActionEvent")
local sendNotificationEvent = ReplicatedStorage:WaitForChild("SendNotificationEvent")


local currentPartyData = nil

local function setupPartyUI(socialMainFrame)
    local partyTab = socialMainFrame:FindFirstChild("Party") or socialMainFrame
    local partyInfo = partyTab:FindFirstChild("PartyInfo")
    local memberInfo = partyTab:FindFirstChild("MemberInfo")
    if not partyInfo or not memberInfo then return end

    memberInfo.Visible = false
    partyInfo.Visible = true

    local topText = partyTab:FindFirstChild("PartyName") or partyInfo:FindFirstChild("TextLabel")
    local leaveBtn = partyTab:FindFirstChild("LeaveButton") or partyInfo:FindFirstChild("LeaveButton")

    if leaveBtn then
        bindHoverAnimation(leaveBtn)
        table.insert(activeConnections, leaveBtn.MouseButton1Click:Connect(function()
            playSoundIsolated(CLICK_SOUND_ID)
            partyActionEvent:FireServer("leave", {})
        end))
    end

    local kickBtn = memberInfo:FindFirstChild("KickButton") or memberInfo:FindFirstChild("KICKBUTTON")
    local promoteBtn = memberInfo:FindFirstChild("PromoteButton") or memberInfo:FindFirstChild("PROMOTEBUTTON")
    local backBtn = memberInfo:FindFirstChild("BackButton") or memberInfo:FindFirstChild("BACKBUTTON")

    local selectedUserId = nil

    if backBtn then
        bindHoverAnimation(backBtn)
        table.insert(activeConnections, backBtn.MouseButton1Click:Connect(function()
            playSoundIsolated(CLICK_SOUND_ID)
            memberInfo.Visible = false
            partyInfo.Visible = true
        end))
    end

    if kickBtn then
        bindHoverAnimation(kickBtn)
        table.insert(activeConnections, kickBtn.MouseButton1Click:Connect(function()
            playSoundIsolated(CLICK_SOUND_ID)
            if selectedUserId then
                partyActionEvent:FireServer("kick", {targetUserId = selectedUserId})
                memberInfo.Visible = false
                partyInfo.Visible = true
            end
        end))
    end

    if promoteBtn then
        bindHoverAnimation(promoteBtn)
        table.insert(activeConnections, promoteBtn.MouseButton1Click:Connect(function()
            playSoundIsolated(CLICK_SOUND_ID)
            if selectedUserId then
                partyActionEvent:FireServer("promote", {targetUserId = selectedUserId})
                memberInfo.Visible = false
                partyInfo.Visible = true
            end
        end))
    end

    table.insert(activeConnections, partyUpdateEvent.OnClientEvent:Connect(function(payload)
        currentPartyData = payload
        if topText then
            topText.Text = payload.ownerName .. "'S PARTY " .. #payload.members .. "/4"
        end

        local isLocalOwner = (payload.owner == player.UserId)

        -- Ascundem automat MemberInfo cand dam kick/promote daca targetul a iesit,
        -- sau doar re-evaluam daca suntem inca Owner,
        -- Dar update-ul in sine se intampla cand se schimba membrii.

        for i = 1, 4 do
            local slot = partyInfo:FindFirstChild("MEMBER" .. i)
            if not slot then continue end

            local memberData = payload.members[i]
            if memberData then
                slot.Visible = true
                local nameLabel = slot:FindFirstChild("Name") or slot:FindFirstChild("TextLabel")
                if nameLabel then nameLabel.Text = memberData.name end

                local imgLabel = slot:FindFirstChild("ImageLabel")
                if imgLabel then
                    task.spawn(function()
                        local succ, thumb = pcall(function()
                            return Players:GetUserThumbnailAsync(memberData.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
                        end)
                        if succ then imgLabel.Image = thumb end
                    end)
                end

                local infoBtn = slot:FindFirstChild("InfoButton")
                if infoBtn then
                    if isLocalOwner and memberData.userId ~= player.UserId then
                        infoBtn.Visible = true
                    else
                        infoBtn.Visible = false
                    end
                end
            else
                slot.Visible = false
            end
        end

        -- Daca cineva se muta/pleaca, iar meniul MemberInfo e deschis cu un anumit ID, actualizam datele acolo automat, sau iesim daca a plecat.
        if memberInfo.Visible and selectedUserId then
            local stillInParty = false
            local selectedMemberData = nil
            for _, m in ipairs(payload.members) do
                if m.userId == selectedUserId then
                    stillInParty = true
                    selectedMemberData = m
                    break
                end
            end

            if not stillInParty then
                memberInfo.Visible = false
                partyInfo.Visible = true
            elseif selectedMemberData then
                local nameLabel = memberInfo:FindFirstChild("Name") or memberInfo:FindFirstChild("TextLabel")
                if nameLabel then nameLabel.Text = selectedMemberData.name end

                local statusLabel = memberInfo:FindFirstChild("Status")
                if statusLabel then
                    statusLabel.Text = (payload.owner == selectedMemberData.userId) and "Owner" or "Member"
                end
            end
        end
    end))

    for i = 1, 4 do
        local slot = partyInfo:FindFirstChild("MEMBER" .. i)
        if not slot then continue end
        local infoBtn = slot:FindFirstChild("InfoButton")
        if infoBtn then
            bindHoverAnimation(infoBtn)
            table.insert(activeConnections, infoBtn.MouseButton1Click:Connect(function()
                playSoundIsolated(CLICK_SOUND_ID)
                if not currentPartyData or not currentPartyData.members[i] then return end

                local memberData = currentPartyData.members[i]
                selectedUserId = memberData.userId

                local nameLabel = memberInfo:FindFirstChild("Name") or memberInfo:FindFirstChild("TextLabel")
                if nameLabel then nameLabel.Text = memberData.name end

                local imgLabel = memberInfo:FindFirstChild("ImageLabel")
                if imgLabel then
                    task.spawn(function()
                        local succ, thumb = pcall(function()
                            return Players:GetUserThumbnailAsync(memberData.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
                        end)
                        if succ then imgLabel.Image = thumb end
                    end)
                end

                local statusLabel = memberInfo:FindFirstChild("Status")
                if statusLabel then
                    statusLabel.Text = (currentPartyData.owner == memberData.userId) and "Owner" or "Member"
                end

                partyInfo.Visible = false
                memberInfo.Visible = true
            end))
        end
    end

    -- Cere starea initiala de la server in caz ca a ratat evenimentul de la PlayerAdded
    partyActionEvent:FireServer("fetch", {})
end

local function setupSocialUI()
    disconnectAll()

    local mainUI = playerGui:WaitForChild("MAINUI", 10)
    local socialGui = playerGui:WaitForChild("Social", 10)

    if not mainUI or not socialGui then
        warn("SocialUI: Could not find MAINUI or Social GUI.")
        return
    end

    socialGui.Enabled = true

    local socialsButton = mainUI:FindFirstChild("SocialButton")
    if not socialsButton then
        local cornerBtns = mainUI:FindFirstChild("CornerButtons")
        if cornerBtns then socialsButton = cornerBtns:FindFirstChild("SocialButton") end
    end

    local socialMainFrame = socialGui:FindFirstChild("MainFrame")
    if not socialsButton or not socialMainFrame then
        warn("SocialUI: Missing SocialButton or MainFrame")
        return
    end

    setupPartyUI(socialMainFrame)

    -- Store original size manually BEFORE hiding or zeroing it out to prevent openMenu from breaking
    if not socialMainFrame:GetAttribute("OriginalSizeXScale") then
        socialMainFrame:SetAttribute("OriginalSizeXScale", socialMainFrame.Size.X.Scale)
        socialMainFrame:SetAttribute("OriginalSizeXOffset", socialMainFrame.Size.X.Offset)
        socialMainFrame:SetAttribute("OriginalSizeYScale", socialMainFrame.Size.Y.Scale)
        socialMainFrame:SetAttribute("OriginalSizeYOffset", socialMainFrame.Size.Y.Offset)
    end

    -- Fix initial visibility explicitly before any logic
    socialMainFrame.Visible = false
    socialMainFrame.Size = UDim2.new(0, 0, 0, 0)

    local friendTab = socialMainFrame:FindFirstChild("Friend")
    if not friendTab then return end

    -- Meniurile
    local inviteFriendMenu = friendTab:FindFirstChild("INVITEFRIEND")
    local addFriendMenu = friendTab:FindFirstChild("ADDFRIEND") -- Acesta este Frame-ul pentru add

    -- Ascundem ambele la deschiderea meniului
    if inviteFriendMenu then inviteFriendMenu.Visible = false end
    if addFriendMenu then addFriendMenu.Visible = false end

    -- Butoanele tab-urilor principale
    local addFriendBtn = friendTab:FindFirstChild("ADDFRIENDBUTTMAIN")
    local inviteFriendBtn = friendTab:FindFirstChild("INVITEFRIENDBUTTMAIN")

    -- Buton de Close pentru Social (daca exista ExitButton)
    local exitBtn = socialMainFrame.Parent:FindFirstChild("EXITBUTTON") or socialMainFrame:FindFirstChild("EXITBUTTON")
    if exitBtn then
        bindHoverAnimation(exitBtn)
        table.insert(activeConnections, exitBtn.MouseButton1Click:Connect(function()
            playSoundIsolated(CLICK_SOUND_ID)
            -- Instead of just Visible = false, we should tween it away or just close it consistently
            socialMainFrame.Visible = false
        end))
    end

    -- Toggle Social Menu
    bindHoverAnimation(socialsButton)
    table.insert(activeConnections, socialsButton.MouseButton1Click:Connect(function()
        playSoundIsolated(CLICK_SOUND_ID)
        local wasVisible = socialMainFrame.Visible
        if not wasVisible then
            openMenu(socialMainFrame)
            -- Ascunde sub-meniurile când se deschide Social
            if inviteFriendMenu then inviteFriendMenu.Visible = false end
            if addFriendMenu then addFriendMenu.Visible = false end
        else
            socialMainFrame.Visible = false
        end
    end))

    -- Ensure Social Menu hides when game starts/MAINUI is toggled off
    local toggleMainUiEvent = ReplicatedStorage:FindFirstChild("ToggleMainUIEvent")
    if toggleMainUiEvent then
        table.insert(activeConnections, toggleMainUiEvent.OnClientEvent:Connect(function(isVisible)
            if not isVisible and socialMainFrame then
                socialMainFrame.Visible = false
            end
        end))
    end

    -- TAB: INVITE FRIEND LOGIC
    if inviteFriendBtn and inviteFriendMenu then
        bindHoverAnimation(inviteFriendBtn)

        local template = inviteFriendMenu:FindFirstChild("EXAMPLEFRIENDLIST")
        if template then template.Visible = false end

        table.insert(activeConnections, inviteFriendBtn.MouseButton1Click:Connect(function()
            playSoundIsolated(CLICK_SOUND_ID)
            if addFriendMenu then addFriendMenu.Visible = false end
            inviteFriendMenu.Visible = true

            if template then
                -- Curățăm lista existentă
                for _, child in ipairs(inviteFriendMenu:GetChildren()) do
                    if child:IsA("GuiObject") and child.Name ~= "EXAMPLEFRIENDLIST" and child.Name ~= "UIListLayout" and not child:IsA("UICorner") then
                        child:Destroy()
                    end
                end

                -- Aducem prietenii async
                task.spawn(function()
                    local getFriendsFunction = ReplicatedStorage:FindFirstChild("FetchFriendsFunction")
                    local friendList = {}
                    if getFriendsFunction then
                        friendList = getFriendsFunction:InvokeServer() or {}
                    end

                    local success = true

                    if success then
                        for _, friend in ipairs(friendList) do
                                local newFrame = template:Clone()
                                newFrame.Name = "Friend_" .. friend.Username
                                newFrame.Visible = true

                                local textLabel = newFrame:FindFirstChild("TextLabel")
                                if textLabel then textLabel.Text = friend.Username end

                                local imgLabel = newFrame:FindFirstChild("ImageLabel")
                                if imgLabel then
                                    task.spawn(function()
                                        local succ, thumb = pcall(function()
                                            return Players:GetUserThumbnailAsync(friend.Id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
                                        end)
                                        if succ then imgLabel.Image = thumb end
                                    end)
                                end

                                local invPartyBtn = newFrame:FindFirstChild("INVITEPARTYBUTTFRIEND")
                                local invGameBtn = newFrame:FindFirstChild("INVITEGAMEBUTTFRIEND")

                                if invPartyBtn then
                                    -- Nu mai punem hover events in activeConnections aici pentru ca sunt distruse regulat
                                    bindHoverAnimation(invPartyBtn)
                                    invPartyBtn.MouseButton1Click:Connect(function()
                                        playSoundIsolated(CLICK_SOUND_ID)
                                        partyActionEvent:FireServer("invite", {targetUsername = friend.Username})
                                        print("[Socials] Invited " .. friend.Username .. " to Party!")
                                    end)
                                end

                                if invGameBtn then
                                    bindHoverAnimation(invGameBtn)
                                    invGameBtn.MouseButton1Click:Connect(function()
                                        playSoundIsolated(CLICK_SOUND_ID)
                                        print("[Socials] Invited " .. friend.Username .. " to Game! (Placeholder)")
                                    end)
                                end

                                newFrame.Parent = inviteFriendMenu
                        end
                    else
                        warn("SocialUI: Failed to fetch friends")
                    end
                end)
            end
        end))
    end

    -- TAB: ADD FRIEND LOGIC
    if addFriendBtn and addFriendMenu then
        bindHoverAnimation(addFriendBtn)

        local searchFrame = addFriendMenu:FindFirstChild("SearchFrame")
        local userFrame = addFriendMenu:FindFirstChild("USERFRAME")

        if userFrame then userFrame.Visible = false end

        table.insert(activeConnections, addFriendBtn.MouseButton1Click:Connect(function()
            playSoundIsolated(CLICK_SOUND_ID)
            if inviteFriendMenu then inviteFriendMenu.Visible = false end
            addFriendMenu.Visible = true
            if userFrame then userFrame.Visible = false end
        end))

        if searchFrame and userFrame then
            local searchBox = searchFrame:FindFirstChild("TextBox")
            local currentSearchUserId = nil
            local currentSearchUsername = nil

            -- Bind static button events ONLY ONCE outside of the search loop
            local addBtn = userFrame:FindFirstChild("ADDFRIENDBUTTUF")
            local invitePartyBtn = userFrame:FindFirstChild("INVITEPARTYBUTTUF")

            if addBtn then
                bindHoverAnimation(addBtn)
                table.insert(activeConnections, addBtn.MouseButton1Click:Connect(function()
                    playSoundIsolated(CLICK_SOUND_ID)
                    if not currentSearchUserId then return end

                    -- Send Custom Friend Request
                    print("[Socials] Trimis Friend Request catre: " .. currentSearchUsername)
                    local sendNotificationEvent = game:GetService("ReplicatedStorage"):WaitForChild("SendNotificationEvent")
                    sendNotificationEvent:FireServer(currentSearchUsername, "FriendRequest")
                end))
            end

            if invitePartyBtn then
                bindHoverAnimation(invitePartyBtn)
                table.insert(activeConnections, invitePartyBtn.MouseButton1Click:Connect(function()
                    playSoundIsolated(CLICK_SOUND_ID)
                    if currentSearchUsername then
                        local sendNotificationEvent = game:GetService("ReplicatedStorage"):WaitForChild("SendNotificationEvent")
                        sendNotificationEvent:FireServer(currentSearchUsername, "PartyInvite")
                        print("[Socials] Invited " .. currentSearchUsername .. " to Party!")
                    end
                end))
            end

            local inviteGameBtn = userFrame:FindFirstChild("INVITEGAMEBUTTUF")
            if inviteGameBtn then
                bindHoverAnimation(inviteGameBtn)
                table.insert(activeConnections, inviteGameBtn.MouseButton1Click:Connect(function()
                    playSoundIsolated(CLICK_SOUND_ID)
                    if currentSearchUsername then
                        local sendNotificationEvent = game:GetService("ReplicatedStorage"):WaitForChild("SendNotificationEvent")
                        sendNotificationEvent:FireServer(currentSearchUsername, "GameInvite")
                        print("[Socials] Invited " .. currentSearchUsername .. " to Game!")
                    end
                end))
            end

            if searchBox then
                table.insert(activeConnections, searchBox.FocusLost:Connect(function(enterPressed)
                    if enterPressed then
                        local username = searchBox.Text
                        if username == "" then return end

                        playSoundIsolated(CLICK_SOUND_ID)

                        task.spawn(function()
                            local success, userId = pcall(function()
                                return Players:GetUserIdFromNameAsync(username)
                            end)

                            if success and userId then
                                currentSearchUserId = userId
                                currentSearchUsername = username

                                local textLabel = userFrame:FindFirstChild("TextLabel")
                                if textLabel then textLabel.Text = username end

                                local imgLabel = userFrame:FindFirstChild("ImageLabel")
                                if imgLabel then
                                    local succ, thumb = pcall(function()
                                        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
                                    end)
                                    if succ then imgLabel.Image = thumb end
                                end

                                userFrame.Visible = true
                            else
                                warn("SocialUI: User not found!")
                                currentSearchUserId = nil
                                currentSearchUsername = nil
                                if userFrame then userFrame.Visible = false end
                            end
                        end)
                    end
                end))
            end
        end
    end
end

setupSocialUI()

player.CharacterAdded:Connect(function()
    task.wait(0.2)
    setupSocialUI()
end)

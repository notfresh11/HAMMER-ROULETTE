local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Creează UI-ul
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GameUIScreen"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local textLabel = Instance.new("TextLabel")
textLabel.Name = "CenterText"
textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
textLabel.Size = UDim2.new(1, 0, 0.1, 0) -- Făcut textul și mai mic (de la 0.15 la 0.1) pentru countdown
textLabel.Position = UDim2.new(0.5, 0, 0.5, 0) -- Exact pe centrul ecranului
textLabel.BackgroundTransparency = 1
-- Schimbat pe fontul FredokaOne dorit de utilizator
textLabel.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
textLabel.TextScaled = true
textLabel.TextColor3 = Color3.new(1, 1, 1) -- Alb default
textLabel.TextStrokeTransparency = 0 -- Contur negru
textLabel.Text = ""
textLabel.Visible = false
textLabel.Parent = screenGui

-- Funcție dedicată pentru a reda sunete izolate care nu se anulează între ele
local function playSoundIsolated(soundId)
    if not soundId or soundId == "" then return end

    local newSound = Instance.new("Sound")
    newSound.SoundId = soundId
    newSound.Parent = screenGui

    -- Un trim foarte mic pentru a elimina delay-ul scurt fără să taie sunetul
    newSound.TimePosition = 0.05

    -- Distrugem sunetul după ce se termină de redat
    newSound.Ended:Connect(function()
        newSound:Destroy()
    end)

    -- Măsură de siguranță în caz că sunetul are eroare la încărcare
    task.delay(10, function()
        if newSound and newSound.Parent then
            newSound:Destroy()
        end
    end)

    newSound:Play()
end

local TweenService = game:GetService("TweenService")

-- === GUI INTERACTION LOGIC ===
local isAFK = false -- State-ul AFK trebuie să fie persistent

-- Stocăm toate conexiunile pentru a le putea curăța la respawn, evitând memory leaks și triggere duplicate
local activeConnections = {}

local function disconnectAll()
    for _, connection in ipairs(activeConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    table.clear(activeConnections)
end

-- Funcție utilitară pentru a face orice element UI scalabil automat
-- Funcție utilitară pentru a face ScreenGui-urile scalabile automat fără a strica structurile imbricate (nested UI)
local function applyDynamicUIScale(screenGui)
    if not screenGui or not screenGui:IsA("ScreenGui") then return end

    local uiScale = screenGui:FindFirstChildOfClass("UIScale")
    if not uiScale then
        uiScale = Instance.new("UIScale")
        uiScale.Parent = screenGui
    end

    local function updateScale()
        local viewportSize = workspace.CurrentCamera.ViewportSize
        -- Rezoluție de referință (ex: desktop 1920x1080)
        local baseWidth = 1920
        local baseHeight = 1080

        -- Dacă viewport-ul e invalid, nu facem nimic
        if viewportSize.X <= 0 or viewportSize.Y <= 0 then return end

        -- Calculăm factorii de scalare
        local scaleX = viewportSize.X / baseWidth
        local scaleY = viewportSize.Y / baseHeight

        -- Alegem scara cea mai mică pentru a ne asigura că tot conținutul intră pe ecran fără a fi trunchiat
        local minScale = math.min(scaleX, scaleY)

        -- Evităm scalarea în sus (peste 1) pentru ecrane foarte mari, doar micșorăm pe mobile
        -- De asemenea, punem o limită inferioară ca să nu devină microscopic
        uiScale.Scale = math.clamp(minScale, 0.3, 1)
    end

    -- Actualizăm scala inițial
    updateScale()

    -- Ascultăm schimbările de rezoluție (ex: rotirea telefonului, resize pe PC)
    local conn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    table.insert(activeConnections, conn)
end

local function setupUI()
    -- Curățăm conexiunile vechi înainte de a adăuga altele noi
    disconnectAll()

    local mainUI = playerGui:WaitForChild("MAINUI")
    if mainUI then
        applyDynamicUIScale(mainUI)
    end
    if not mainUI then return end

    -- Fix UI being pushed down by the topbar
    if mainUI:IsA("ScreenGui") then
        mainUI.IgnoreGuiInset = true
    end

    local clickSoundId = "rbxassetid://124476359159008"

    -- Fetching the components based on the user's hierarchy
    local questsGui = playerGui:WaitForChild("Quests", 5)
    local discordGui = playerGui:WaitForChild("Discord", 5)
    local statsGui = playerGui:WaitForChild("Stats")
    local shopGui = playerGui:WaitForChild("Shop")
    local settingsGui = playerGui:WaitForChild("Settings")

    -- Force Enable all root ScreenGuis in case user disabled them in Studio to save space
    if questsGui then
        questsGui.Enabled = true
        applyDynamicUIScale(questsGui)
    end
    if discordGui then
        discordGui.Enabled = true
        applyDynamicUIScale(discordGui)
    end
    if statsGui then
        statsGui.Enabled = true
        applyDynamicUIScale(statsGui)
    end
    if shopGui then
        shopGui.Enabled = true
        applyDynamicUIScale(shopGui)
    end
    if settingsGui then
        settingsGui.Enabled = true
        applyDynamicUIScale(settingsGui)
    end

    -- PROGRESSION UI SETUP
    local levelFrame = mainUI:FindFirstChild("Level")
    if levelFrame then
        local innerFrame = levelFrame:FindFirstChild("Frame")
        if innerFrame then
            local avatarHolder = innerFrame:FindFirstChild("Avatar")
            local levelTotal = innerFrame:FindFirstChild("LevelTotal")
            local levelDone = innerFrame:FindFirstChild("LevelDone")
            local xpProgress = innerFrame:FindFirstChild("XPProgress")
            local lvlProgress = innerFrame:FindFirstChild("LVLProgress")

            -- Setup Avatar Image
            if avatarHolder and avatarHolder:IsA("Frame") then
                local imgAvatar = Instance.new("ImageLabel")
                imgAvatar.Name = "Avatar"
                imgAvatar.Size = avatarHolder.Size
                imgAvatar.Position = avatarHolder.Position
                imgAvatar.AnchorPoint = avatarHolder.AnchorPoint
                imgAvatar.BackgroundTransparency = 1

                -- Attempt to get thumbnail
                task.spawn(function()
                    local success, thumb, ready = pcall(function()
                        return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
                    end)
                    if success and ready then
                        imgAvatar.Image = thumb
                    end
                end)

                imgAvatar.Parent = innerFrame
                avatarHolder:Destroy()
            elseif avatarHolder and avatarHolder:IsA("ImageLabel") then
                -- Already converted, just update image
                task.spawn(function()
                    local success, thumb, ready = pcall(function()
                        return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
                    end)
                    if success and ready then
                        avatarHolder.Image = thumb
                    end
                end)
            end

            -- Setup initial bar colors
            if levelTotal then levelTotal.BackgroundColor3 = Color3.new(1, 1, 1) end -- Alb
            if levelDone then levelDone.BackgroundColor3 = Color3.new(1, 0, 0) end -- Rosu

            -- Ascultăm UpdateStatsEvent
            local updateStatsEvent = ReplicatedStorage:WaitForChild("UpdateStatsEvent", 5)
            local abilityRequestEvent = ReplicatedStorage:WaitForChild("AbilityRequestEvent", 5)
            local abilityStateEvent = ReplicatedStorage:WaitForChild("AbilityStateEvent", 5)

            if updateStatsEvent then
                table.insert(activeConnections, updateStatsEvent.OnClientEvent:Connect(function(level, currentXp, requiredXp, coins)
                    -- Update XP Texts
                    if lvlProgress then lvlProgress.Text = "LVL " .. tostring(level) end
                    if xpProgress then xpProgress.Text = tostring(math.floor(currentXp)) .. "/" .. tostring(math.floor(requiredXp)) end

                    -- Update Bar Size (assuming left anchored, so we tween X Scale)
                    if levelDone and levelTotal then
                        local ratio = math.clamp(currentXp / requiredXp, 0, 1)
                        -- Putem folosi tween pt un efect smooth
                        local targetSize = UDim2.new(ratio, 0, levelDone.Size.Y.Scale, levelDone.Size.Y.Offset)
                        TweenService:Create(levelDone, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize}):Play()
                    end

                    -- Update Shop Coins Button
                    local shopGuiRef = playerGui:FindFirstChild("Shop")
                    if shopGuiRef then
                        local shopMainFrame = shopGuiRef:FindFirstChild("MainFrame")
                        if shopMainFrame then
                            local coinsBtn = shopMainFrame:FindFirstChild("CoinsButton")
                            if coinsBtn then
                                local coinsText = coinsBtn:FindFirstChild("TextLabel")
                                if coinsText then
                                    coinsText.Text = tostring(math.floor(coins))
                                end
                            end
                        end
                    end
                end))
            end
        end
    end
    if shopGui then shopGui.Enabled = true end
    if settingsGui then settingsGui.Enabled = true end

    -- AFK Component Setup
    local afkButton = mainUI:FindFirstChild("AFKButton")
    local afkTextFadeTween = nil
    local afkDelayThread = nil

    -- Use WaitForChild instead of creating a fake local instance
    local toggleAfkEvent = ReplicatedStorage:WaitForChild("ToggleAFKEvent")

    if afkButton then
        -- Find existing notification or create new one
        local afkTextLabel = screenGui:FindFirstChild("AFKNotificationText")

        local originalFont = Font.new("rbxassetid://12187371840")
        local oldStudioText = afkButton:FindFirstChild("TextLabel")
        if oldStudioText then
            originalFont = oldStudioText.FontFace
            oldStudioText:Destroy()
        end

        if not afkTextLabel then
            -- Create a brand new TextLabel explicitly to guarantee it ignores all MAINUI constraints
            afkTextLabel = Instance.new("TextLabel")
            afkTextLabel.Name = "AFKNotificationText"
            afkTextLabel.Parent = screenGui
            afkTextLabel.AnchorPoint = Vector2.new(0.5, 0.5)
            afkTextLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
            afkTextLabel.Size = UDim2.new(0.5, 0, 0.2, 0)
            afkTextLabel.BackgroundTransparency = 1
            afkTextLabel.TextScaled = true
            afkTextLabel.FontFace = originalFont
            afkTextLabel.TextTransparency = 1
            afkTextLabel.TextStrokeTransparency = 1
        end

        -- Make sure default color matches current persistent state
        if isAFK then
            afkButton.BackgroundColor3 = Color3.new(0, 1, 0) -- Green
        else
            afkButton.BackgroundColor3 = Color3.new(1, 0, 0) -- Red
        end

        table.insert(activeConnections, afkButton.MouseButton1Click:Connect(function()
            playSoundIsolated(clickSoundId)
            isAFK = not isAFK

            -- Update Background Color of the button itself
            if isAFK then
                afkButton.BackgroundColor3 = Color3.new(0, 1, 0) -- Green
            else
                afkButton.BackgroundColor3 = Color3.new(1, 0, 0) -- Red
            end

            -- Inform Server
            toggleAfkEvent:FireServer(isAFK)

            -- Update Text
            if afkTextLabel then
                -- Reset existing tween and thread if any
                if afkTextFadeTween then
                    afkTextFadeTween:Cancel()
                end
                if afkDelayThread then
                    task.cancel(afkDelayThread)
                    afkDelayThread = nil
                end

                afkTextLabel.TextTransparency = 0
                afkTextLabel.TextStrokeTransparency = 0

                if isAFK then
                    afkTextLabel.Text = "You are AFK"
                    afkTextLabel.TextColor3 = Color3.new(0, 1, 0) -- Green
                else
                    afkTextLabel.Text = "You are not AFK"
                    afkTextLabel.TextColor3 = Color3.new(1, 0, 0) -- Red
                end

                -- Create fade out tween after a short delay
                afkDelayThread = task.delay(1.5, function()
                    local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
                    afkTextFadeTween = TweenService:Create(afkTextLabel, tweenInfo, {
                        TextTransparency = 1,
                        TextStrokeTransparency = 1
                    })
                    afkTextFadeTween:Play()
                end)
            end
        end))
    end

    local updateMatchmakingEvent = ReplicatedStorage:WaitForChild("UpdateMatchmakingUIEvent", 10)
    if updateMatchmakingEvent then
        table.insert(activeConnections, updateMatchmakingEvent.OnClientEvent:Connect(function(textMsg, soundId)
            local matchmakingUI = mainUI:FindFirstChild("MatchmakingUI")
            if matchmakingUI and matchmakingUI:IsA("TextLabel") then
                matchmakingUI.Text = textMsg or ""
                matchmakingUI.Visible = (textMsg and textMsg ~= "")
            end
            if soundId and soundId ~= "" then
                playSoundIsolated(soundId)
            end
        end))
    end

    -- Menu Toggling Logic
    local menus = {
        ShopButton = shopGui and shopGui:FindFirstChild("MainFrame"),
        QuestsButton = questsGui and questsGui:FindFirstChild("MainFrame"),
        StatsButton = statsGui and statsGui:FindFirstChild("MainFrame"),
        SettingsButton = settingsGui and settingsGui:FindFirstChild("MainFrame"),
        DiscordButton = discordGui and discordGui:FindFirstChild("MainFrame")
    }

    local function hideAllMenus()
        for _, frame in pairs(menus) do
            if frame then
                frame.Visible = false
            end
        end
    end

    -- Ascunde toate meniurile automat cand interfața se inițializează pentru a nu te bombarda pe ecran
    hideAllMenus()

    -- Helper function to open a menu with a pop-up animation
    local function openMenu(frame)
        if not frame then return end
        frame.Visible = true

        -- Store the original size if not already saved
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

        -- Set to 0 instantly, then tween up
        frame.Size = UDim2.new(0, 0, 0, 0)
        local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        local tween = TweenService:Create(frame, tweenInfo, {Size = targetSize})
        tween:Play()
    end

    local toggleMainUiEvent = ReplicatedStorage:WaitForChild("ToggleMainUIEvent", 10)
    if toggleMainUiEvent then
        table.insert(activeConnections, toggleMainUiEvent.OnClientEvent:Connect(function(isVisible)
            if mainUI and mainUI.Parent then
                mainUI.Enabled = isVisible
            end

            -- Când intrăm în meci, ascundem conținutul (Visible = false) din ecranele secundare
            if not isVisible then
                hideAllMenus()
            end
        end))
    end

    -- Assign logic to buttons
    local cornerButtonsFolder = mainUI:FindFirstChild("CornerButtons")

    for buttonName, targetFrame in pairs(menus) do
        -- Check both MAINUI and CornerButtons folder
        local button = mainUI:FindFirstChild(buttonName) or (cornerButtonsFolder and cornerButtonsFolder:FindFirstChild(buttonName))
        if button then
            table.insert(activeConnections, button.MouseButton1Click:Connect(function()
                playSoundIsolated(clickSoundId)

                -- Toggle logic: if already open, just close it
                local wasVisible = targetFrame and targetFrame.Visible
                hideAllMenus()

                if targetFrame and not wasVisible then
                    openMenu(targetFrame)
                end
            end))
        end
    end

    -- ===========================
    -- SHOP INTERNAL LOGIC
    -- ===========================
    if menus.ShopButton then
        local shopFrame = menus.ShopButton

        -- References to the internal content frames
        local frameAbilities = shopFrame:FindFirstChild("FrameAb")
        local frameCurrency = shopFrame:FindFirstChild("FrameCurrency")
        local frameSkins = shopFrame:FindFirstChild("FrameSkins")
        local frameVFX = shopFrame:FindFirstChild("FrameVFX")

        -- References to the tab buttons (as seen in hierarchy, they are direct children of MainFrame)
        local abilitiesBtn = shopFrame:FindFirstChild("AbButton")
        local currencyBtn = shopFrame:FindFirstChild("CurrencyButton")
        local skinsBtn = shopFrame:FindFirstChild("SkinsButton")
        local vfxBtn = shopFrame:FindFirstChild("VFXButton")

        -- Ref to the Exit Button (Expecting it directly under shopFrame now to prevent hover scaling inheritance)
        local exitBtn = shopFrame:FindFirstChild("ExitButton")

        -- Asigurăm că eventurile există, având timeout mic de la început, pot da silent fail
        if not abilityRequestEvent then
            abilityRequestEvent = ReplicatedStorage:WaitForChild("AbilityRequestEvent")
        end
        if not abilityStateEvent then
            abilityStateEvent = ReplicatedStorage:WaitForChild("AbilityStateEvent")
        end

        -- Abilities layout setup
        -- Ascunde layout-ul original imediat ca să nu se vadă niciodată
        if frameAbilities then
            local templateLayout = frameAbilities:FindFirstChild("AbLayout")
            if templateLayout then
                templateLayout.Visible = false
            end
        end

        local function setupAbilities(ownedAbilities, equippedAbility, abilitiesDef)
            if not frameAbilities then return end

            ownedAbilities = ownedAbilities or {}
            abilitiesDef = abilitiesDef or {}

            -- Căutăm șablonul (template-ul) făcut de utilizator
            local templateLayout = frameAbilities:FindFirstChild("AbLayout")
            if not templateLayout then
                warn("GameUI: Nu am găsit 'AbLayout' în 'FrameAb'!")
                return
            end

            -- Ascundem template-ul original în caz că era vizibil
            templateLayout.Visible = false

            -- Ștergem clonele vechi (cele care au numele abilității, nu template-ul)
            for _, child in ipairs(frameAbilities:GetChildren()) do
                if child ~= templateLayout and not child:IsA("UIListLayout") and not child:IsA("UICorner") then
                    child:Destroy()
                end
            end

            for abilityName, def in pairs(abilitiesDef) do
                -- Clonăm șablonul
                local itemClone = templateLayout:Clone()
                itemClone.Name = abilityName
                itemClone.Visible = true

                -- Găsim componentele din interiorul clonei.
                -- Folosim a doua variabila "true" la FindFirstChild pentru o cautare recursiva,
                -- astfel incat sa gaseasca elementele indiferent daca sunt in clona radacina sau in TextButton
                local actionBtn = itemClone:FindFirstChild("TextButton", true)
                local nameLbl = itemClone:FindFirstChild("ItemName", true)
                local descLbl = itemClone:FindFirstChild("ItemDescription", true)
                local priceLbl = itemClone:FindFirstChild("ItemPrice", true)
                local iconLbl = itemClone:FindFirstChild("ItemImage", true)

                if nameLbl then
                    nameLbl.Text = def.Name
                    nameLbl.Visible = true
                end

                if descLbl then
                    descLbl.Text = def.Description
                    descLbl.Visible = true
                end

                if iconLbl then
                    iconLbl.Visible = true
                end

                if actionBtn then
                    -- Configurăm starea butonului și prețul
                    if ownedAbilities[abilityName] then
                        if priceLbl then priceLbl.Visible = false end -- Ascundem prețul dacă o deține

                        if equippedAbility == abilityName then
                            actionBtn.Text = "UNEQUIP"
                            actionBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
                        else
                            actionBtn.Text = "EQUIP"
                            actionBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
                        end
                    else
                        if priceLbl then
                            priceLbl.Visible = true
                            priceLbl.Text = "PRICE " .. tostring(def.Price)
                        end

                        actionBtn.Text = "BUY"
                        actionBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
                    end

                    -- Conectăm funcționalitatea de Buy/Equip/Unequip
                    table.insert(activeConnections, actionBtn.MouseButton1Click:Connect(function()
                        playSoundIsolated("rbxassetid://124476359159008")
                        if ownedAbilities[abilityName] then
                            if equippedAbility == abilityName then
                                abilityRequestEvent:FireServer("Unequip", abilityName)
                            else
                                abilityRequestEvent:FireServer("Equip", abilityName)
                            end
                        else
                            abilityRequestEvent:FireServer("Buy", abilityName)
                        end
                    end))
                else
                    warn("GameUI: 'TextButton' nu a fost găsit în clona pentru abilitatea " .. abilityName)
                end

                itemClone.Parent = frameAbilities
            end
        end

        table.insert(activeConnections, abilityStateEvent.OnClientEvent:Connect(function(ownedAbilities, equippedAbility, abilitiesDef)
            if ownedAbilities == "ResetCooldowns" then
                -- Local cooldown reset logic could be added here if UI tracking is added later
                -- Currently relying on tick() server-side.
                return
            end
            setupAbilities(ownedAbilities, equippedAbility, abilitiesDef)
        end))

        -- Default State: Only Currency visible
        local function resetShopTabs()
            if frameAbilities then frameAbilities.Visible = false end
            if frameCurrency then frameCurrency.Visible = true end
            if frameSkins then frameSkins.Visible = false end
            if frameVFX then frameVFX.Visible = false end
        end

        -- Call reset to set default state immediately
        resetShopTabs()

        -- Logic for Exit Button
        if exitBtn then
            table.insert(activeConnections, exitBtn.MouseButton1Click:Connect(function()
                playSoundIsolated(clickSoundId)
                shopFrame.Visible = false
            end))
        end

        -- Helper to switch tabs
        local function showShopTab(tabName)
            if frameAbilities then frameAbilities.Visible = (tabName == "Abilities") end
            if frameCurrency then frameCurrency.Visible = (tabName == "Currency") end
            if frameSkins then frameSkins.Visible = (tabName == "Skins") end
            if frameVFX then frameVFX.Visible = (tabName == "VFX") end

            -- Automatically request sync whenever we open the Abilities tab
            if tabName == "Abilities" then
                abilityRequestEvent:FireServer("RequestSync")
            end
        end

        -- Bind tab buttons
        if abilitiesBtn then
            table.insert(activeConnections, abilitiesBtn.MouseButton1Click:Connect(function()
                playSoundIsolated(clickSoundId)
                showShopTab("Abilities")
            end))
        end

        -- Initial Sync Request just in case the tab is default
        abilityRequestEvent:FireServer("RequestSync")

        if skinsBtn then
            table.insert(activeConnections, skinsBtn.MouseButton1Click:Connect(function()
                playSoundIsolated(clickSoundId)
                showShopTab("Skins")
            end))
        end

        if vfxBtn then
            table.insert(activeConnections, vfxBtn.MouseButton1Click:Connect(function()
                playSoundIsolated(clickSoundId)
                showShopTab("VFX")
            end))
        end

        if currencyBtn then
            table.insert(activeConnections, currencyBtn.MouseButton1Click:Connect(function()
                playSoundIsolated(clickSoundId)
                showShopTab("Currency")
            end))
        end

        local coinsBtn = shopFrame:FindFirstChild("CoinsButton")
        if coinsBtn then
            table.insert(activeConnections, coinsBtn.MouseButton1Click:Connect(function()
                playSoundIsolated(clickSoundId)
                showShopTab("Currency")
            end))
        end
    end

    -- Hover Animations for standard buttons (Scale Up)
    -- We define a helper function to bind scale animations to any button
    local function bindHoverAnimation(button)
        if not button or not button:IsA("GuiObject") then return end

        -- Store initial size as attributes to prevent size degradation if hovered during tween interruptions
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

        -- If it's a click button, also add a click "squish" effect
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

        table.insert(activeConnections, button.MouseEnter:Connect(function()
            local tween = TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize})
            tween:Play()
        end))

        table.insert(activeConnections, button.MouseLeave:Connect(function()
            local tween = TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = originalSize})
            tween:Play()
        end))
    end

    -- Apply to standard main buttons
    for _, child in ipairs(mainUI:GetChildren()) do
        if child:IsA("GuiButton") then
            bindHoverAnimation(child)
        end
    end

    -- Apply to shop internal buttons
    if menus.ShopButton then
        local shopFrame = menus.ShopButton
        bindHoverAnimation(shopFrame:FindFirstChild("AbButton"))
        bindHoverAnimation(shopFrame:FindFirstChild("SkinsButton"))
        bindHoverAnimation(shopFrame:FindFirstChild("VFXButton"))
        bindHoverAnimation(shopFrame:FindFirstChild("CurrencyButton"))
        bindHoverAnimation(shopFrame:FindFirstChild("CoinsButton"))

        -- Extracted ExitButton out of CurrencyButton directly to MainFrame
        bindHoverAnimation(shopFrame:FindFirstChild("ExitButton"))
    end

    -- Hover Animations for CornerButtons (Darken Background/Image)
    if cornerButtonsFolder then
        for _, button in ipairs(cornerButtonsFolder:GetChildren()) do
            if button:IsA("GuiButton") then
                -- Assuming user used UI elements with colors, we target Text/Image buttons specifically.
                -- Darken the general Background if they use that, or TextColor
                local originalColor = button.BackgroundColor3
                local hoverColor = Color3.new(originalColor.R * 0.7, originalColor.G * 0.7, originalColor.B * 0.7)

                table.insert(activeConnections, button.MouseEnter:Connect(function()
                    local tween = TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Linear), {BackgroundColor3 = hoverColor})
                    tween:Play()
                end))

                table.insert(activeConnections, button.MouseLeave:Connect(function()
                    local tween = TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Linear), {BackgroundColor3 = originalColor})
                    tween:Play()
                end))

                -- Also tween any ImageLabels inside it if they have images that act as icons
                for _, icon in ipairs(button:GetChildren()) do
                    if icon:IsA("ImageLabel") or icon:IsA("ImageButton") then
                        local origImgColor = icon.ImageColor3
                        local hoverImgColor = Color3.new(origImgColor.R * 0.7, origImgColor.G * 0.7, origImgColor.B * 0.7)

                        table.insert(activeConnections, button.MouseEnter:Connect(function()
                            TweenService:Create(icon, TweenInfo.new(0.15, Enum.EasingStyle.Linear), {ImageColor3 = hoverImgColor}):Play()
                        end))
                        table.insert(activeConnections, button.MouseLeave:Connect(function()
                            TweenService:Create(icon, TweenInfo.new(0.15, Enum.EasingStyle.Linear), {ImageColor3 = origImgColor}):Play()
                        end))
                    end
                end
            end
        end
    end
end

-- Rulăm funcția inițial la pornire
setupUI()

-- Re-rulăm funcția ori de câte ori caracterul moare și se respawnează
-- (deoarece interfața din PlayerGui se distruge și se creează din nou din StarterGui)
player.CharacterAdded:Connect(function()
    -- Adăugăm un mic delay pentru a lăsa timp Roblox-ului să cloneze noile ScreenGui-uri din StarterGui în PlayerGui
    task.wait(0.2)
    setupUI()
end)

-- Remote Events
local showCountdown = ReplicatedStorage:WaitForChild("ShowCountdownEvent", 10)
local showText = ReplicatedStorage:WaitForChild("ShowTextEvent", 10)
local hideText = ReplicatedStorage:WaitForChild("HideTextEvent", 10)
local vfxEvent = ReplicatedStorage:WaitForChild("VfxEvent", 10)

-- Funcție Helper VFX Client
local function runClientVfx(victimPos, victimColors, groundColor, groundMaterial)
    local Workspace = game:GetService("Workspace")
    local TweenService = game:GetService("TweenService")
    local Debris = game:GetService("Debris")

    -- Fallbacks
    groundColor = groundColor or Color3.fromRGB(100, 100, 100)
    groundMaterial = groundMaterial or Enum.Material.Slate

    -- 1. Explozia de cuburi a victimei
    for _, partColor in ipairs(victimColors) do
        local shard = Instance.new("Part")
        shard.Size = Vector3.new(1, 1, 1)
        shard.Color = partColor
        shard.Material = Enum.Material.SmoothPlastic
        shard.Position = victimPos + Vector3.new(math.random(-1,1), math.random(1,4), math.random(-1,1))
        shard.CanCollide = false
        shard.Parent = Workspace

        -- Dăm o forță explozivă (Client side physics)
        local spread = Vector3.new(math.random(-50,50), math.random(50, 100), math.random(-50,50))
        shard.AssemblyLinearVelocity = spread

        -- Le micșorăm și le distrugem
        local tween = TweenService:Create(shard, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(0,0,0)})
        tween:Play()
        Debris:AddItem(shard, 2)
    end

    -- 2. Ground Smash (Crater Ring)
    for i = 1, 8 do
        local angle = (math.pi * 2 / 8) * i
        local offset = Vector3.new(math.cos(angle) * 4, -2, math.sin(angle) * 4)

        local rock = Instance.new("Part")
        rock.Size = Vector3.new(2, 2, 2)
        rock.Color = groundColor
        rock.Material = groundMaterial
        rock.Position = victimPos + offset
        rock.Anchored = true
        rock.CanCollide = false
        rock.Parent = Workspace

        -- Ridicăm pietrele din pământ și le rotim random
        local upCFrame = CFrame.new(victimPos + offset + Vector3.new(0, 3, 0)) * CFrame.Angles(math.random(), math.random(), math.random())
        local rockTween = TweenService:Create(rock, TweenInfo.new(0.3, Enum.EasingStyle.Bounce), {CFrame = upCFrame})
        rockTween:Play()

        -- Se scufundă la loc și dispar
        task.delay(1.5, function()
            local downTween = TweenService:Create(rock, TweenInfo.new(0.5), {Position = rock.Position - Vector3.new(0,5,0), Transparency = 1})
            downTween:Play()
        end)
        Debris:AddItem(rock, 2.5)
    end

    -- 3. Shockwave (Inel invizibil care se lărgește)
    local shock = Instance.new("Part")
    shock.Shape = Enum.PartType.Cylinder
    shock.Size = Vector3.new(0.5, 2, 2) -- Orientare X, Y, Z (pentru disc plat punem Y mare pe lateral, apoi îl rotim)
    shock.CFrame = CFrame.new(victimPos) * CFrame.Angles(0, 0, math.rad(90))
    shock.Color = Color3.new(1,1,1)
    shock.Material = Enum.Material.Neon
    shock.Transparency = 0.5
    shock.Anchored = true
    shock.CanCollide = false
    shock.Parent = Workspace

    local shockTween = TweenService:Create(shock, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.1, 30, 30),
        Transparency = 1
    })
    shockTween:Play()
    Debris:AddItem(shock, 0.5)

    -- 4. Screen Shake
    local camera = Workspace.CurrentCamera
    local distToImpact = (camera.CFrame.Position - victimPos).Magnitude
    if distToImpact < 100 then
        -- Intensitatea scade cu distanța (max 1 la 0 distanță, 0 la 100 distanță)
        local intensity = 1 - (distToImpact / 100)
        task.spawn(function()
            local startTime = tick()
            local duration = 0.3
            while tick() - startTime < duration do
                local elapsed = tick() - startTime
                local falloff = 1 - (elapsed / duration)
                local offset = Vector3.new(
                    math.random(-100, 100)/100,
                    math.random(-100, 100)/100,
                    math.random(-100, 100)/100
                ) * intensity * falloff * 2 -- Multiplicator general

                camera.CFrame = camera.CFrame * CFrame.new(offset)
                task.wait()
            end
        end)
    end
end

if vfxEvent then
    vfxEvent.OnClientEvent:Connect(function(victimPos, victimColors, groundColor, groundMaterial)
        runClientVfx(victimPos, victimColors, groundColor, groundMaterial)
    end)
end

if showCountdown then
    showCountdown.OnClientEvent:Connect(function(numberText, colorCode, soundId)
        textLabel.Text = tostring(numberText)
        textLabel.TextColor3 = colorCode
        textLabel.Visible = true

        playSoundIsolated(soundId)
    end)
end

if showText then
    showText.OnClientEvent:Connect(function(msg, colorCode, soundId)
        textLabel.Text = msg
        textLabel.TextColor3 = colorCode or Color3.new(1, 1, 1)
        textLabel.Visible = true

        playSoundIsolated(soundId)
    end)
end

if hideText then
    hideText.OnClientEvent:Connect(function()
        textLabel.Visible = false
        textLabel.Text = ""
    end)
end

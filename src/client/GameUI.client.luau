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
local mainUI = playerGui:WaitForChild("MAINUI")
if mainUI then
    -- Fix UI being pushed down by the topbar
    if mainUI:IsA("ScreenGui") then
        mainUI.IgnoreGuiInset = true
    end

    local clickSoundId = "rbxassetid://124476359159008"

    -- Fetching the components based on the user's hierarchy
    -- Am scos limitele de timp (5 secunde) pentru a aștepta interfața oricât e nevoie.
    local questsGui = playerGui:WaitForChild("Quests")
    local discordGui = playerGui:WaitForChild("Discord")
    local statsGui = playerGui:WaitForChild("Stats")
    local shopGui = playerGui:WaitForChild("Shop")
    local settingsGui = playerGui:WaitForChild("Settings")

    -- Force Enable all root ScreenGuis in case user disabled them in Studio to save space
    -- AND ensure they do not reset on spawn, so our script references don't break when players die
    if mainUI and mainUI:IsA("ScreenGui") then mainUI.ResetOnSpawn = false end
    if questsGui then questsGui.Enabled = true; questsGui.ResetOnSpawn = false end
    if discordGui then discordGui.Enabled = true; discordGui.ResetOnSpawn = false end
    if statsGui then statsGui.Enabled = true; statsGui.ResetOnSpawn = false end
    if shopGui then shopGui.Enabled = true; shopGui.ResetOnSpawn = false end
    if settingsGui then settingsGui.Enabled = true; settingsGui.ResetOnSpawn = false end

    -- AFK Component Setup
    local afkButton = mainUI:FindFirstChild("AFKButton")
    local isAFK = false
    local afkTextFadeTween = nil
    local afkDelayThread = nil

    -- Use WaitForChild instead of creating a fake local instance
    local toggleAfkEvent = ReplicatedStorage:WaitForChild("ToggleAFKEvent")

    if afkButton then
        local afkTextLabel = afkButton:FindFirstChild("TextLabel")

        local originalFont = Font.new("rbxassetid://12187371840")

        if afkTextLabel then
            -- Salvează fontul original setat de tine din Studio
            originalFont = afkTextLabel.FontFace
            -- Destroy the Studio-bound text label that might have constraints attached to it
            afkTextLabel:Destroy()
        end

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

        -- Make sure default color matches default state (NOAFK = Red)
        afkButton.BackgroundColor3 = Color3.new(1, 0, 0)

        afkButton.MouseButton1Click:Connect(function()
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
        end)
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

    -- Ascunde toate meniurile automat cand intri pe joc pentru a nu te bombarda pe ecran
    hideAllMenus()

    local toggleMainUiEvent = ReplicatedStorage:WaitForChild("ToggleMainUIEvent", 10)
    -- Când intrăm în meci, pe lângă ascunderea MAINUI, închidem forțat și orice meniu rămas deschis (cum ar fi Quests)
    if toggleMainUiEvent then
        toggleMainUiEvent.OnClientEvent:Connect(function(isVisible)
            mainUI.Enabled = isVisible

            -- Când intrăm în meci, ascundem conținutul (Visible = false) din ecranele secundare
            if not isVisible then
                hideAllMenus()
            end
        end)
    end

    -- Assign logic to buttons
    local cornerButtonsFolder = mainUI:FindFirstChild("CornerButtons")

    for buttonName, targetFrame in pairs(menus) do
        -- Check both MAINUI and CornerButtons folder
        local button = mainUI:FindFirstChild(buttonName) or (cornerButtonsFolder and cornerButtonsFolder:FindFirstChild(buttonName))
        if button then
            button.MouseButton1Click:Connect(function()
                playSoundIsolated(clickSoundId)

                -- Toggle logic: if already open, just close it
                local wasVisible = targetFrame and targetFrame.Visible
                hideAllMenus()

                if targetFrame and not wasVisible then
                    targetFrame.Visible = true
                end
            end)
        end
    end

    -- Hover Animations for standard buttons (Scale Up)
    for _, child in ipairs(mainUI:GetChildren()) do
        if child:IsA("GuiButton") then
            local originalSize = child.Size
            local targetSize = UDim2.new(
                originalSize.X.Scale * 1.1, originalSize.X.Offset * 1.1,
                originalSize.Y.Scale * 1.1, originalSize.Y.Offset * 1.1
            )

            child.MouseEnter:Connect(function()
                local tween = TweenService:Create(child, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize})
                tween:Play()
            end)

            child.MouseLeave:Connect(function()
                local tween = TweenService:Create(child, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = originalSize})
                tween:Play()
            end)
        end
    end

    -- Hover Animations for CornerButtons (Darken Background/Image)
    if cornerButtonsFolder then
        for _, button in ipairs(cornerButtonsFolder:GetChildren()) do
            if button:IsA("GuiButton") then
                -- Assuming user used UI elements with colors, we target Text/Image buttons specifically.
                -- Darken the general Background if they use that, or TextColor
                local originalColor = button.BackgroundColor3
                local hoverColor = Color3.new(originalColor.R * 0.7, originalColor.G * 0.7, originalColor.B * 0.7)

                button.MouseEnter:Connect(function()
                    local tween = TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Linear), {BackgroundColor3 = hoverColor})
                    tween:Play()
                end)

                button.MouseLeave:Connect(function()
                    local tween = TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Linear), {BackgroundColor3 = originalColor})
                    tween:Play()
                end)

                -- Also tween any ImageLabels inside it if they have images that act as icons
                for _, icon in ipairs(button:GetChildren()) do
                    if icon:IsA("ImageLabel") or icon:IsA("ImageButton") then
                        local origImgColor = icon.ImageColor3
                        local hoverImgColor = Color3.new(origImgColor.R * 0.7, origImgColor.G * 0.7, origImgColor.B * 0.7)

                        button.MouseEnter:Connect(function()
                            TweenService:Create(icon, TweenInfo.new(0.15, Enum.EasingStyle.Linear), {ImageColor3 = hoverImgColor}):Play()
                        end)
                        button.MouseLeave:Connect(function()
                            TweenService:Create(icon, TweenInfo.new(0.15, Enum.EasingStyle.Linear), {ImageColor3 = origImgColor}):Play()
                        end)
                    end
                end
            end
        end
    end
end

-- Remote Events
local showCountdown = ReplicatedStorage:WaitForChild("ShowCountdownEvent", 10)
local showText = ReplicatedStorage:WaitForChild("ShowTextEvent", 10)
local hideText = ReplicatedStorage:WaitForChild("HideTextEvent", 10)
local vfxEvent = ReplicatedStorage:WaitForChild("VfxEvent", 10)

-- Funcție Helper VFX Client
local function runClientVfx(victimPos, victimColors)
    local Workspace = game:GetService("Workspace")
    local TweenService = game:GetService("TweenService")
    local Debris = game:GetService("Debris")

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
        rock.Color = Color3.fromRGB(100, 100, 100)
        rock.Material = Enum.Material.Slate
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
    vfxEvent.OnClientEvent:Connect(function(victimPos, victimColors)
        runClientVfx(victimPos, victimColors)
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

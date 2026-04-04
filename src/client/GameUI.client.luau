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
textLabel.Size = UDim2.new(1, 0, 0.35, 0) -- Mărit pe Y pentru text mai mare
textLabel.Position = UDim2.new(0.5, 0, 0.5, 0) -- Exact pe centrul ecranului
textLabel.BackgroundTransparency = 1
textLabel.FontFace = Font.new("rbxassetid://12187371840")
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

-- Remote Events
local showCountdown = ReplicatedStorage:WaitForChild("ShowCountdownEvent", 10)
local showText = ReplicatedStorage:WaitForChild("ShowTextEvent", 10)
local hideText = ReplicatedStorage:WaitForChild("HideTextEvent", 10)

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

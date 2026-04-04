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
textLabel.Size = UDim2.new(1, 0, 0.2, 0)
textLabel.Position = UDim2.new(0, 0, 0.4, 0) -- Centrat
textLabel.BackgroundTransparency = 1
textLabel.Font = Enum.Font.Silkscreen
textLabel.TextScaled = true
textLabel.TextColor3 = Color3.new(1, 1, 1) -- Alb default
textLabel.TextStrokeTransparency = 0 -- Contur negru
textLabel.Text = ""
textLabel.Visible = false
textLabel.Parent = screenGui

-- Sound Setup
local soundPlayer = Instance.new("Sound")
soundPlayer.Parent = screenGui

-- Remote Events
local showCountdown = ReplicatedStorage:WaitForChild("ShowCountdownEvent", 10)
local showText = ReplicatedStorage:WaitForChild("ShowTextEvent", 10)
local hideText = ReplicatedStorage:WaitForChild("HideTextEvent", 10)

if showCountdown then
    showCountdown.OnClientEvent:Connect(function(numberText, colorCode, soundId)
        textLabel.Text = tostring(numberText)
        textLabel.TextColor3 = colorCode
        textLabel.Visible = true

        if soundId and soundId ~= "" then
            soundPlayer.SoundId = soundId
            soundPlayer:Play()
        end
    end)
end

if showText then
    showText.OnClientEvent:Connect(function(msg, colorCode, soundId)
        textLabel.Text = msg
        textLabel.TextColor3 = colorCode or Color3.new(1, 1, 1)
        textLabel.Visible = true

        if soundId and soundId ~= "" then
            soundPlayer.SoundId = soundId
            soundPlayer:Play()
        end
    end)
end

if hideText then
    hideText.OnClientEvent:Connect(function()
        textLabel.Visible = false
        textLabel.Text = ""
    end)
end

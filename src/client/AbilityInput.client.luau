local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local abilityUseEvent = ReplicatedStorage:WaitForChild("AbilityUseEvent", 10)

if abilityUseEvent then
    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        -- Do not trigger if typing in chat
        if gameProcessedEvent then return end

        -- 'Q' key for activating abilities
        if input.KeyCode == Enum.KeyCode.Q then
            local character = player.Character
            if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
                abilityUseEvent:FireServer()
            end
        end
    end)
else
    warn("AbilityInput: Nu am putut găsi AbilityUseEvent în ReplicatedStorage.")
end

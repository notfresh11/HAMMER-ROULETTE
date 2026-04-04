local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Remote Event Setup
local eventName = "MaceAttackEvent"
local attackEvent = ReplicatedStorage:FindFirstChild(eventName)

-- If the server hasn't created it yet, wait for it
if not attackEvent then
    attackEvent = ReplicatedStorage:WaitForChild(eventName, 10)
    if not attackEvent then
        warn("MaceAttackEvent nu a fost găsit în ReplicatedStorage!")
        return
    end
end

local debugHitboxVisible = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    -- Don't process if typing in chat, etc.
    if gameProcessed then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local character = player.Character
        if not character then return end

        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then return end

        -- Only trigger if the player is in the air (Freefall)
        if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
            -- Optional: Verify if the tool is equipped
            local tool = character:FindFirstChildWhichIsA("Tool")
            if tool then
                -- Inform the server that an attack click happened, and pass the debug state
                attackEvent:FireServer(debugHitboxVisible)
            end
        end
    elseif input.KeyCode == Enum.KeyCode.L then
        -- Toggle Debug Hitbox visibility
        debugHitboxVisible = not debugHitboxVisible
        print("Mace Debug Hitbox Visible:", debugHitboxVisible)
    end
end)

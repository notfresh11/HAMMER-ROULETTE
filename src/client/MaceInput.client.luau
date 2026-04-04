local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Remote Event Setup
local eventName = "MaceAttackEvent"
local attackEvent = ReplicatedStorage:WaitForChild(eventName)

if not attackEvent then
    warn("MaceAttackEvent nu a fost găsit în ReplicatedStorage!")
    return
end

local bounceEventName = "MaceBounceEvent"
local bounceEvent = ReplicatedStorage:WaitForChild(bounceEventName)

if bounceEvent then
    bounceEvent.OnClientEvent:Connect(function()
        local character = player.Character
        if character then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                -- Set the velocity directly to ensure bounce on client-owned physics
                local currentVel = rootPart.AssemblyLinearVelocity
                rootPart.AssemblyLinearVelocity = Vector3.new(currentVel.X, 100, currentVel.Z)
            end
        end
    end)
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
                -- Inform the server that an attack click happened
                attackEvent:FireServer()
            end
        end
    elseif input.KeyCode == Enum.KeyCode.L then
        -- Toggle Debug Hitbox visibility
        debugHitboxVisible = not debugHitboxVisible
        print("Mace Debug Hitbox Visible:", debugHitboxVisible)

        local character = player.Character
        if character then
            local hitbox = character:FindFirstChild("MaceHitbox")
            if hitbox then
                hitbox.Transparency = debugHitboxVisible and 0.8 or 1
            else
                warn("Debug: Hitbox-ul 'MaceHitbox' nu a fost găsit. Poate nu este runda ta?")
            end
        end
    end
end)

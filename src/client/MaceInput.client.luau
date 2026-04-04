local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Remote Event Setup
local eventName = "MaceAttackEvent"
local attackEvent = ReplicatedStorage:WaitForChild(eventName, 10)

if not attackEvent then
    warn("MaceInput (Client): MaceAttackEvent nu a fost găsit în ReplicatedStorage!")
    return
end

local bounceEventName = "MaceBounceEvent"
local bounceEvent = ReplicatedStorage:WaitForChild(bounceEventName, 10)

if bounceEvent then
    bounceEvent.OnClientEvent:Connect(function()
        print("MaceInput: S-a primit MaceBounceEvent de la server!")
        local character = player.Character
        if character then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChild("Humanoid")
            if rootPart and humanoid then
                -- Setăm o viteză mare și resetăm starea humanoid-ului ca să nu o blocheze
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                rootPart.AssemblyLinearVelocity = Vector3.new(0, 100, 0)
                print("MaceInput: Viteza Y a fost setată la 100!")
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
        local state = humanoid:GetState()
        print("MaceInput: S-a apăsat Click. Stare humanoid:", state.Name)
        if state == Enum.HumanoidStateType.Freefall then
            -- Optional: Verify if the tool is equipped
            local tool = character:FindFirstChildWhichIsA("Tool")
            if tool then
                print("MaceInput: Echipat! Trimitem FireServer().")
                -- Inform the server that an attack click happened
                attackEvent:FireServer()
            else
                print("MaceInput: Tool-ul nu e echipat.")
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

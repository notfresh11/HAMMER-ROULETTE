local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Remote Event Setup
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
                -- Oprim orice viteză descendentă (pentru a asigura că bounce-ul nu e anulat de gravitație/viteza de cădere)
                rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

                -- Setăm starea humanoid-ului pentru siguranță
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

                -- Aplicăm impuls fizic masiv bazat pe greutatea personajului
                -- 200 de unități de forță per unitate de masă aruncă un caracter masiv în aer instant
                rootPart:ApplyImpulse(Vector3.new(0, rootPart.AssemblyMass * 200, 0))
                print("MaceInput: S-a aplicat un impuls masiv de bounce!")
            end
        end
    end)
end

local debugHitboxVisible = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    -- Don't process if typing in chat, etc.
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.L then
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

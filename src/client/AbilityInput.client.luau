local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local abilityUseEvent = ReplicatedStorage:WaitForChild("AbilityUseEvent", 10)

local dashVelocityEvent = ReplicatedStorage:WaitForChild("DashVelocityEvent", 10)

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

if dashVelocityEvent then
    dashVelocityEvent.OnClientEvent:Connect(function(dashVelocity)
        local character = player.Character
        if character then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                -- Apply a LinearVelocity for a short duration to make it feel like a real dash
                local attachment = Instance.new("Attachment", rootPart)

                local linearVelocity = Instance.new("LinearVelocity")
                linearVelocity.Attachment0 = attachment
                linearVelocity.MaxForce = 100000 -- Putere mare ca să învingă fricțiunea și greutatea
                linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
                linearVelocity.VectorVelocity = Vector3.new(dashVelocity.X, 0, dashVelocity.Z)
                linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
                linearVelocity.Parent = rootPart

                -- Distruge după 0.18 secunde (durata dash-ului scurtată)
                task.delay(0.18, function()
                    if linearVelocity then linearVelocity:Destroy() end
                    if attachment then attachment:Destroy() end

                    -- Oprește inerția ca să nu alunece mai departe
                    if rootPart and rootPart.Parent then
                        -- Nu tăia complet Y-ul, altfel îl oprești din cădere/bounce
                        rootPart.AssemblyLinearVelocity = Vector3.new(0, rootPart.AssemblyLinearVelocity.Y, 0)
                    end
                end)
            end
        end
    end)
end

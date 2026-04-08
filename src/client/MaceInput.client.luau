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
                -- Serverul ancorează personajul timp de 0.08 secunde la hit-pause, iar apoi trimite bounceEvent-ul.
                -- Deseori semnalul ajunge la client cu o microsecundă înainte să se replice Anchored = false,
                -- anulând complet aplicarea AssemblyLinearVelocity. Așteptăm ca part-ul să se deancoreze!
                if rootPart.Anchored then
                    print("MaceInput: RootPart este ancorat, aștept deancorarea înainte de Bounce...")
                    local startWait = tick()
                    -- Așteptăm maxim 0.2 secunde (ca fail-safe)
                    while rootPart.Anchored and tick() - startWait < 0.2 do
                        task.wait()
                    end
                end

                -- Oprim inerția curentă de mișcare complet (pentru a evita ca forțele existente să se adauge la bounce și să creeze inconsecvențe)
                rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z)

                -- Setăm o viteză constantă mare și resetăm starea humanoid-ului ca să nu o blocheze
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

                -- Fixăm Y-ul la o valoare fixă, păstrând inerția orizontală, ca săritura să fie mereu la fel de înaltă
                rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, 90, rootPart.AssemblyLinearVelocity.Z)
                print("MaceInput: Viteza Y a fost setată exact la 90, curățând inerția veche!")
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

local MaceMechanic = {}
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local currentTool = nil
local connections = {}
local roundActive = false
local currentPlayer = nil

-- Visual Debug Hitbox Helper
local function createDebugHitbox(cframe, size)
    local part = Instance.new("Part")
    part.Size = size
    part.CFrame = cframe
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 0.5
    part.Color = Color3.new(1, 0, 0)
    part.Material = Enum.Material.Neon
    part.Parent = Workspace

    -- Cleanup after short time
    task.delay(0.5, function()
        part:Destroy()
    end)
end

-- Create or get the RemoteEvent for the MaceAttack
-- Get the RemoteEvent created by MainGameLoop
local maceEventName = "MaceAttackEvent"
local attackEvent = ReplicatedStorage:WaitForChild(maceEventName)

function MaceMechanic.startMechanic(player, onRoundEndCallback)
    roundActive = true
    local character = player.Character
    if not character then
        onRoundEndCallback()
        return
    end

    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then
        onRoundEndCallback()
        return
    end

    -- Create tool safely from ServerStorage
    local hammerFolder = ServerStorage:WaitForChild("Hammer", 5)
    if hammerFolder then
        local toolTemplate = hammerFolder:WaitForChild("Tool", 5)
        if toolTemplate and toolTemplate:IsA("Tool") then
            currentTool = toolTemplate:Clone()
            currentTool.Parent = player.Backpack
            humanoid:EquipTool(currentTool)
        else
            warn("MaceMechanic: Nu am putut găsi tool-ul 'Tool' în ServerStorage.Hammer!")
        end
    else
        warn("MaceMechanic: Nu am putut găsi folderul 'Hammer' în ServerStorage!")
    end

    -- Boost Jump
    humanoid.UseJumpPower = false
    humanoid.JumpHeight = 60

    -- Add a temporary force/state to disable fall damage if needed.
    -- In standard Roblox, fall damage isn't applied unless specifically scripted.
    -- We will assume standard Roblox physics.

    local isFalling = false

    -- Create Permanent Hitbox Part
    local hitboxPart = Instance.new("Part")
    hitboxPart.Name = "MaceHitbox"
    -- Make it longer downwards
    hitboxPart.Size = Vector3.new(14, 24, 14)
    -- Position slightly in front and further down
    hitboxPart.CFrame = rootPart.CFrame * CFrame.new(0, -6, -2)
    hitboxPart.Anchored = false
    hitboxPart.CanCollide = false
    hitboxPart.CanTouch = false
    hitboxPart.CanQuery = false
    hitboxPart.Massless = true
    hitboxPart.Transparency = 1
    hitboxPart.Color = Color3.new(1, 0, 0)
    hitboxPart.Material = Enum.Material.ForceField
    hitboxPart.Parent = character

    local hitboxWeld = Instance.new("WeldConstraint")
    hitboxWeld.Part0 = rootPart
    hitboxWeld.Part1 = hitboxPart
    hitboxWeld.Parent = hitboxPart

    currentPlayer = player
    -- Cleanup function
    local function cleanup()
        roundActive = false
        currentPlayer = nil
        for _, conn in ipairs(connections) do
            conn:Disconnect()
        end
        table.clear(connections)

        if currentTool then
            currentTool:Destroy()
            currentTool = nil
        end

        if hitboxPart then
            hitboxPart:Destroy()
        end

        if humanoid then
            humanoid.UseJumpPower = false
            humanoid.JumpHeight = 7.2
        end
    end

    -- Expose cleanup globally for abrupt match ends
    MaceMechanic.forceStopMechanic = cleanup

    -- Track jumping/falling
    local pendingLandingEnd = nil

    table.insert(connections, humanoid.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.Freefall then
            isFalling = true
            if pendingLandingEnd then
                task.cancel(pendingLandingEnd)
                pendingLandingEnd = nil
            end
        elseif newState == Enum.HumanoidStateType.Landed then
            if isFalling and roundActive then
                -- Adăugăm un mic delay înainte de a opri runda
                -- Acest lucru permite procesarea unui atac declanșat fix înainte de a atinge solul
                pendingLandingEnd = task.delay(0.2, function()
                    if roundActive then
                        print(player.Name .. " a aterizat. Rateu! Runda se încheie.")
                        cleanup()
                        onRoundEndCallback()
                    end
                end)
            end
            isFalling = false
        end
    end))

    -- Spatial query attack logic replaces the `.Touched` event
    local lastAttackTime = 0
    local ATTACK_COOLDOWN = 0.5

    if attackEvent then
        table.insert(connections, attackEvent.OnServerEvent:Connect(function(plr)
            if not roundActive or plr ~= player then
                print("Server Attack Rejected: Round not active or wrong player.")
                return
            end

            local now = tick()
            if now - lastAttackTime < ATTACK_COOLDOWN then
                print("Server Attack Rejected: Cooldown.")
                return
            end

            -- Validare relaxată: Clientul e de încredere pentru aer (din scriptul local)
            -- Dar pe server, permitem lovitura dacă starea curentă e Freefall SAU suntem în "grace period" (abia a aterizat)
            local currentState = humanoid:GetState()
            local inAirState = (currentState == Enum.HumanoidStateType.Freefall)

            if not inAirState and not pendingLandingEnd then
                print("Server Attack Rejected: Not in air and no grace period. State:", currentState.Name)
                return
            end

            lastAttackTime = now
            print("Server Attack Validated! Checking for targets...")

            local boxSize = hitboxPart.Size
            local boxCFrame = hitboxPart.CFrame

            local overlapParams = OverlapParams.new()
            overlapParams.FilterType = Enum.RaycastFilterType.Exclude
            overlapParams.FilterDescendantsInstances = {character}

            local partsInBox = Workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlapParams)
            print("Părți găsite în hitbox:", #partsInBox)

            local closestPlayer = nil
            local closestDist = math.huge

            for _, part in ipairs(partsInBox) do
                -- Part could be inside an Accessory, so we find the actual character model
                local hitChar = part:FindFirstAncestorWhichIsA("Model")
                if hitChar then
                    local hitHumanoid = hitChar:FindFirstChild("Humanoid")
                    if hitHumanoid and hitHumanoid.Health > 0 then
                        local targetRoot = hitChar:FindFirstChild("HumanoidRootPart")
                        if targetRoot then
                            local dist = (rootPart.Position - targetRoot.Position).Magnitude
                            if dist < closestDist then
                                closestDist = dist
                                closestPlayer = hitChar
                            end
                        end
                    end
                end
            end

            if closestPlayer then
                local hitHumanoid = closestPlayer:FindFirstChild("Humanoid")
                local hitPlayer = Players:GetPlayerFromCharacter(closestPlayer)

                if hitHumanoid and hitPlayer then
                    hitHumanoid.Health = 0
                    print(player.Name .. " l-a ucis pe " .. hitPlayer.Name .. " cu un atac mid-air!")

                    -- Anulăm oprirea rundei dacă atacul a fost un succes exact în momentul aterizării
                    if pendingLandingEnd then
                        task.cancel(pendingLandingEnd)
                        pendingLandingEnd = nil
                    end

                    -- The Bounce (Apply Impulse upwards)
                    -- Am înlocuit cu un Event către client, deoarece NetworkOwnership-ul previne ApplyImpulse de pe server
                    local bounceEvent = ReplicatedStorage:FindFirstChild("MaceBounceEvent")
                    if bounceEvent then
                        bounceEvent:FireClient(player)
                    end

                    -- Round continues, they can fall and hit again!
                    isFalling = true
                end
            end
        end))
    end

    -- Fail safes
    table.insert(connections, humanoid.Died:Connect(function()
        cleanup()
        onRoundEndCallback()
    end))

    table.insert(connections, Players.PlayerRemoving:Connect(function(plr)
        if plr == player then
            cleanup()
            onRoundEndCallback()
        end
    end))
end

return MaceMechanic

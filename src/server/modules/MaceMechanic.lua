local MaceMechanic = {}
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local currentTool = nil
local connections = {}
local roundActive = false

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

    -- Create tool
    local template = ServerStorage:FindFirstChild("Hammer")
    if template then
        local toolTemplate = template:FindFirstChild("Tool") or template
        if toolTemplate:IsA("Tool") then
            currentTool = toolTemplate:Clone()
            currentTool.Parent = player.Backpack
            humanoid:EquipTool(currentTool)
        end
    end

    -- Boost Jump
    humanoid.UseJumpPower = true
    humanoid.JumpPower = 70

    -- Add a temporary force/state to disable fall damage if needed.
    -- In standard Roblox, fall damage isn't applied unless specifically scripted.
    -- We will assume standard Roblox physics.

    local isFalling = false

    -- Cleanup function
    local function cleanup()
        roundActive = false
        for _, conn in ipairs(connections) do
            conn:Disconnect()
        end
        table.clear(connections)

        if currentTool then
            currentTool:Destroy()
            currentTool = nil
        end

        if humanoid then
            humanoid.UseJumpPower = false
            humanoid.JumpHeight = 7.2
            humanoid.JumpPower = 50
        end
    end

    -- Track jumping/falling
    table.insert(connections, humanoid.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.Freefall then
            isFalling = true
        elseif newState == Enum.HumanoidStateType.Landed then
            if isFalling and roundActive then
                -- Player landed (Miss). End round.
                print(player.Name .. " a aterizat. Rateu! Runda se încheie.")
                cleanup()
                onRoundEndCallback()
            end
            isFalling = false
        end
    end))

    -- Listen for hits on the tool
    if currentTool then
        for _, part in ipairs(currentTool:GetDescendants()) do
            if part:IsA("BasePart") then
                table.insert(connections, part.Touched:Connect(function(hit)
                    if not roundActive then return end

                    -- Must be falling
                    local inAir = (humanoid:GetState() == Enum.HumanoidStateType.Freefall)
                    if not inAir then return end

                    local hitChar = hit.Parent
                    if not hitChar or hitChar == character then return end

                    local hitHumanoid = hitChar:FindFirstChild("Humanoid")
                    if hitHumanoid and hitHumanoid.Health > 0 then
                        local hitPlayer = Players:GetPlayerFromCharacter(hitChar)
                        if hitPlayer then
                            -- Kill victim
                            hitHumanoid.Health = 0
                            print(player.Name .. " l-a ucis pe " .. hitPlayer.Name .. " cu ciocanul!")

                            -- The Bounce (Apply Impulse upwards)
                            rootPart:ApplyImpulse(Vector3.new(0, rootPart.AssemblyMass * 100, 0))

                            -- Round continues, they can fall and hit again!
                            isFalling = true
                        end
                    end
                end))
            end
        end
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

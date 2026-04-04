local MaceMechanic = {}
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local currentTool = nil
local connections = {}
local roundActive = false
local currentPlayer = nil

-- Hit Sounds Setup
local hitSoundIds = {
    "rbxassetid://77574533044558",
    "rbxassetid://114348072835488",
    "rbxassetid://89154534119930",
    "rbxassetid://108830942760951"
}
local lastHitSoundIndex = 0

-- Helper function to play a 3D random hit sound without repeating the same one twice
local function playRandomHitSound(parentPart)
    if #hitSoundIds == 0 then return end

    local randomIndex = math.random(1, #hitSoundIds)
    -- Asigură-te că nu e la fel cu ultimul redat
    if #hitSoundIds > 1 and randomIndex == lastHitSoundIndex then
        randomIndex = (randomIndex % #hitSoundIds) + 1
    end
    lastHitSoundIndex = randomIndex

    local hitSound = Instance.new("Sound")
    hitSound.SoundId = hitSoundIds[randomIndex]
    hitSound.RollOffMaxDistance = 150 -- Distanța la care se aude
    hitSound.Volume = 1
    hitSound.Parent = parentPart

    -- Eliminăm primele secunde "mute" din asset pentru a rezolva problema delay-ului
    hitSound.TimePosition = 0.2

    hitSound:Play()

    -- Cleanup automatically
    game:GetService("Debris"):AddItem(hitSound, 5)
end

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

    -- VFX: Highlight & Trail Setup
    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = 1
    highlight.OutlineColor = Color3.new(1, 0, 0) -- Roșu
    highlight.OutlineTransparency = 0
    highlight.Parent = character

    local attachTop = Instance.new("Attachment")
    attachTop.Position = Vector3.new(0, 1, 0)
    attachTop.Parent = rootPart

    local attachBottom = Instance.new("Attachment")
    attachBottom.Position = Vector3.new(0, -1, 0)
    attachBottom.Parent = rootPart

    local trail = Instance.new("Trail")
    trail.Color = ColorSequence.new(Color3.new(1, 1, 1)) -- Alb
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1)
    })
    trail.Lifetime = 0.4
    trail.Attachment0 = attachTop
    trail.Attachment1 = attachBottom
    trail.Enabled = false
    trail.Parent = rootPart

    -- Add a temporary force/state to disable fall damage if needed.
    -- In standard Roblox, fall damage isn't applied unless specifically scripted.
    -- We will assume standard Roblox physics.

    local isFalling = false

    -- Create Permanent Hitbox Part
    local hitboxPart = Instance.new("Part")
    hitboxPart.Name = "MaceHitbox"
    -- Mărime redusă conform cerinței (9x9x9)
    hitboxPart.Size = Vector3.new(9, 9, 9)
    -- Centrat puțin mai jos de RootPart ca să acopere zona de impact
    hitboxPart.CFrame = rootPart.CFrame * CFrame.new(0, -4, 0)
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

        if highlight then highlight:Destroy() end
        if trail then trail:Destroy() end
        if attachTop then attachTop:Destroy() end
        if attachBottom then attachBottom:Destroy() end

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
            trail.Enabled = true
            -- Imediat ce e în aer, îi tăiem JumpHeight ca să nu poată ține Space apăsat la nesfârșit (Bunny Hop)
            humanoid.JumpHeight = 0

            -- NU mai anulăm pendingLandingEnd aici! Se anulează doar dacă dă hit.
            -- Dacă a aterizat, runda se va închide chiar dacă sistemul crede că a reușit să sară iar.
        elseif newState == Enum.HumanoidStateType.Landed then
            trail.Enabled = false
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

    -- Spatial query attack logic - AUTO HIT
    local lastHitTick = 0
    local AUTO_HIT_COOLDOWN = 0.5 -- prevent double hits on same frame

    table.insert(connections, RunService.Heartbeat:Connect(function()
        if not roundActive or not player then return end

        -- Verificăm dacă e în aer. isFalling este setat de StateChanged Freefall
        local currentState = humanoid:GetState()
        local inAirState = (currentState == Enum.HumanoidStateType.Freefall)

        if not inAirState and not pendingLandingEnd then
            return
        end

        local now = tick()
        if now - lastHitTick < AUTO_HIT_COOLDOWN then return end

        local boxSize = hitboxPart.Size
        local boxCFrame = hitboxPart.CFrame

        local overlapParams = OverlapParams.new()
        overlapParams.FilterType = Enum.RaycastFilterType.Exclude
        overlapParams.FilterDescendantsInstances = {character}

        local partsInBox = Workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlapParams)

        local hitRegistered = false

        for _, part in ipairs(partsInBox) do
            local hitChar = part:FindFirstAncestorWhichIsA("Model")
            if hitChar then
                local hitHumanoid = hitChar:FindFirstChild("Humanoid")
                if hitHumanoid and hitHumanoid.Health > 0 then
                    local hitPlayer = Players:GetPlayerFromCharacter(hitChar)
                    if hitPlayer then
                        -- KILL!

                        -- Prevent the default Roblox "Oof" / death sound from playing
                        -- Roblox client audio replication sometimes caches the sound before Destroy propagates.
                        -- Setting Volume = 0 and overriding the ID prevents it entirely.
                        local victimRoot = hitChar:FindFirstChild("HumanoidRootPart")
                        if victimRoot then
                            local defaultDeathSound = victimRoot:FindFirstChild("Died")
                            if defaultDeathSound and defaultDeathSound:IsA("Sound") then
                                defaultDeathSound.Volume = 0
                                defaultDeathSound.SoundId = ""
                                defaultDeathSound:Stop()
                                defaultDeathSound:Destroy()
                            end
                        end

                        hitHumanoid.Health = 0
                        print(player.Name .. " l-a ucis automat pe " .. hitPlayer.Name .. " (Auto-Hit)!")

                        hitRegistered = true
                        lastHitTick = tick()

                        -- Ascunde victima și colectează culorile ei
                        local victimColors = {}
                        for _, p in ipairs(hitChar:GetDescendants()) do
                            if p:IsA("BasePart") then
                                table.insert(victimColors, p.Color)
                                p.Transparency = 1
                                p.CanCollide = false
                                -- Oprim și eventualele decals/fețe ca să fie invizibil complet
                                for _, d in ipairs(p:GetChildren()) do
                                    if d:IsA("Decal") then d.Transparency = 1 end
                                end
                            end
                        end

                        -- Trigger VFX pe toți clienții
                        local vfxEvent = ReplicatedStorage:FindFirstChild("VfxEvent")
                        local targetRoot = hitChar:FindFirstChild("HumanoidRootPart")
                        if targetRoot and vfxEvent then
                            vfxEvent:FireAllClients(targetRoot.Position, victimColors)
                            playRandomHitSound(targetRoot)
                        end

                        -- Hit Pause! Înghețăm temporar atacatorul în aer pt 0.08 secunde
                        rootPart.Anchored = true
                        task.delay(0.08, function()
                            rootPart.Anchored = false
                            -- Bounce the attacker after the pause
                            local bounceEvent = ReplicatedStorage:FindFirstChild("MaceBounceEvent")
                            if bounceEvent then
                                bounceEvent:FireClient(player)
                            end
                        end)

                        -- Odată ce a omorât un om în acest cadru, e de ajuns
                        break
                    end
                end
            end
        end

        if hitRegistered then
            -- Anulăm oprirea rundei dacă a lovit fix la aterizare
            if pendingLandingEnd then
                task.cancel(pendingLandingEnd)
                pendingLandingEnd = nil
            end

            isFalling = true
            -- Îi redăm posibilitatea de jump pentru viitoarea cădere, deși bounce-ul deja îl forțează în sus
            humanoid.JumpHeight = 60
        end
    end))

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

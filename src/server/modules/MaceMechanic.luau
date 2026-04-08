local MaceMechanic = {}
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ProgressionManager = require(script.Parent.ProgressionManager)
local AntiCheat = require(script.Parent.AntiCheat)

-- Tracking per-player cleanup functions to allow multiple concurrent maces
MaceMechanic.playerCleanups = {}


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

function MaceMechanic.startMechanic(player, onRoundEndCallback, isTraining)
    local roundActive = true
    local currentPlayer = player
    local connections = {}
    local character = player.Character
    if not character then
        if onRoundEndCallback then onRoundEndCallback() end
        return
    end

    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then
        if onRoundEndCallback then onRoundEndCallback() end
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

    -- Play Equip Animation if it exists inside the Tool
    local equipAnim = currentTool:FindFirstChild("Equip") or currentTool:FindFirstChild("equip")
    if equipAnim and equipAnim:IsA("Animation") then
        local animator = humanoid:FindFirstChildWhichIsA("Animator")
        if animator then
            local track = animator:LoadAnimation(equipAnim)
            track:Play()
        end
    end

    -- Give the attacker an AntiCheat bypass because they jump high and move fast during mechanic
    AntiCheat.SetBypass(player, "Fly", 20)
    AntiCheat.SetBypass(player, "Speed", 20)

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
    local fallStartTick = 0
    local AUTO_HIT_COOLDOWN = 0.5
    local lastHitTick = 0

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
    local pendingLandingEnd = nil
    local function cleanup()
        roundActive = false
        currentPlayer = nil
        if pendingLandingEnd then
            task.cancel(pendingLandingEnd)
            pendingLandingEnd = nil
        end
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

        MaceMechanic.playerCleanups[player] = nil
    end

    -- Tracking per-player for abrupt stops
    MaceMechanic.playerCleanups[player] = cleanup

    -- Expose cleanup globally for abrupt match ends
    MaceMechanic.forceStopMechanic = function()
        for _, plrcleanup in pairs(MaceMechanic.playerCleanups) do
            plrcleanup()
        end
    end

    -- Track jumping/falling

    table.insert(connections, humanoid.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.Freefall then
            isFalling = true
            fallStartTick = tick()
            trail.Enabled = true
            -- Imediat ce e în aer, îi tăiem JumpHeight ca să nu poată ține Space apăsat la nesfârșit (Bunny Hop)
            humanoid.JumpHeight = 0
        end
    end))

    -- Spatial query attack logic - AUTO HIT
    local lastHitTick = 0
    local AUTO_HIT_COOLDOWN = 0.5 -- prevent double hits on same frame

    table.insert(connections, RunService.Heartbeat:Connect(function()
        if not roundActive or not player then return end

        local now = tick()

        -- Floor detection via raycast to be perfectly certain they touched the ground
        if isFalling and humanoid.Health > 0 and rootPart then
            -- Only check for landing if we are actually falling downwards (or at the peak of jump)
            -- And ensure a grace period has passed since we started falling/jumping (0.15 seconds)
            if rootPart.AssemblyLinearVelocity.Y <= 0 and (tick() - fallStartTick > 0.15) then
                -- Set up raycast params to ignore the character itself
                local rayParams = RaycastParams.new()
                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                rayParams.FilterDescendantsInstances = {character, hitboxPart}

                -- Raycast from slightly above the bottom of the root part, pointing down past the legs
                -- Distance adjusted to exactly 3.1 to avoid false triggers
                local rayOrigin = rootPart.Position
                local rayDirection = Vector3.new(0, -3.1, 0)

                local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, rayParams)

                if raycastResult and not pendingLandingEnd then
                    -- They touched the ground. Give a tiny margin to register any last-millisecond hit.
                    trail.Enabled = false
                    isFalling = false
                    pendingLandingEnd = task.delay(0.2, function()
                        if roundActive then
                            print(player.Name .. " a aterizat. Rateu! Runda se încheie.")
                            cleanup()
                            onRoundEndCallback()
                        end
                    end)
                end
            end
        end

        if not isFalling and not pendingLandingEnd then
            return
        end

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
                        local victimHasShield = hitChar:GetAttribute("ShieldActive")

                        -- KILL OR SHIELD BREAK!
                        if victimHasShield then
                            print(player.Name .. " a lovit scutul lui " .. hitPlayer.Name .. " (Auto-Hit)!")
                            hitChar:SetAttribute("ShieldActive", false)
                            local forceField = hitChar:FindFirstChildOfClass("ForceField")
                            if forceField then forceField:Destroy() end
                        else
                            -- Prevent the default Roblox "Oof" / death sound from playing
                            -- Roblox client audio replication sometimes caches the sound before Destroy propagates.
                            -- Setting Volume = 0 and overriding the ID prevents it entirely.
                            local isDummy = hitPlayer == nil and hitChar.Name == "Dummy"
                            local shouldKill = true
                            local shouldReward = true

                            if isTraining then
                                shouldReward = false
                                if not isDummy then
                                    shouldKill = false
                                end
                            end

                            local victimColors = {}

                            if shouldKill then
                                -- Prevent the default Roblox "Oof" / death sound from playing
                                -- Roblox client audio replication sometimes caches the sound before Destroy propagates.
                                -- Setting Volume = 0 and overriding the ID prevents it entirely.
                                local function disableDeathSound(part)
                                    if part then
                                        for _, child in ipairs(part:GetChildren()) do
                                            if child:IsA("Sound") and (child.Name == "Died" or child.Name == "Oof") then
                                                child.Volume = 0
                                                child.SoundId = ""
                                                child:Stop()
                                                child:Destroy()
                                            end
                                        end
                                    end
                                end

                                -- Căutăm sunetul de death și în RootPart și în Head (de obicei apare acolo)
                                local victimRoot = hitChar:FindFirstChild("HumanoidRootPart")
                                local victimHead = hitChar:FindFirstChild("Head")

                                disableDeathSound(victimRoot)
                                disableDeathSound(victimHead)

                                hitHumanoid.Health = 0
                                if hitPlayer then
                                    print(player.Name .. " l-a ucis automat pe " .. hitPlayer.Name .. " (Auto-Hit)!")
                                else
                                    print(player.Name .. " a distrus un Dummy (Auto-Hit)!")
                                end

                                -- Ascunde victima și colectează culorile ei
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
                            else
                                print(player.Name .. " a lovit pe " .. hitPlayer.Name .. " pe platforma de training!")
                                -- Nu îl omoară, dar putem colecta culorile pentru VFX
                                for _, p in ipairs(hitChar:GetDescendants()) do
                                    if p:IsA("BasePart") then
                                        table.insert(victimColors, p.Color)
                                    end
                                end
                            end

                            -- Add Kill Reward
                            if shouldReward and hitPlayer then
                                ProgressionManager.ProcessKill(player)
                            end

                            -- Detect ground material and color for dynamic VFX
                            local groundColor = Color3.fromRGB(100, 100, 100) -- Default Grey Slate
                            local groundMaterial = Enum.Material.Slate
                            local targetRoot = hitChar:FindFirstChild("HumanoidRootPart")

                            if targetRoot then
                                local rayOrigin = targetRoot.Position
                                local rayDirection = Vector3.new(0, -10, 0)
                                local rayParams = RaycastParams.new()
                                rayParams.FilterType = Enum.RaycastFilterType.Exclude

                                local ignoreList = {hitChar, character, hitboxPart}
                                rayParams.FilterDescendantsInstances = ignoreList

                                local maxCasts = 5
                                local casts = 0
                                local foundGround = false

                                while casts < maxCasts and not foundGround do
                                    casts += 1
                                    local groundHit = Workspace:Raycast(rayOrigin, rayDirection, rayParams)

                                    if groundHit and groundHit.Instance then
                                        if groundHit.Instance.Name == "PlayerSpawn" or groundHit.Instance.Name == "HammerSpawn" then
                                            table.insert(ignoreList, groundHit.Instance)
                                            rayParams.FilterDescendantsInstances = ignoreList
                                            -- Adjust origin to continue casting from slightly below the hit point
                                            rayOrigin = groundHit.Position - Vector3.new(0, 0.01, 0)
                                        else
                                            groundColor = groundHit.Instance.Color
                                            groundMaterial = groundHit.Instance.Material
                                            foundGround = true
                                        end
                                    else
                                        break -- Nothing hit
                                    end
                                end
                            end

                            -- Trigger VFX pe toți clienții
                            local vfxEvent = ReplicatedStorage:FindFirstChild("VfxEvent")
                            if targetRoot and vfxEvent then
                                vfxEvent:FireAllClients(targetRoot.Position, victimColors, groundColor, groundMaterial)
                            end
                        end

                        hitRegistered = true
                        lastHitTick = tick()

                        local targetRoot = hitChar:FindFirstChild("HumanoidRootPart")
                        if targetRoot then
                            playRandomHitSound(targetRoot)
                        end

                        -- Play swing animation if we hit someone
                        if currentTool then
                            local attackAnim = currentTool:FindFirstChild("Attack") or currentTool:FindFirstChild("attack")
                            if attackAnim and attackAnim:IsA("Animation") then
                                local animator = humanoid:FindFirstChildWhichIsA("Animator")
                                if animator then
                                    local track = animator:LoadAnimation(attackAnim)
                                    track:Play()
                                end
                            end
                        end

                        -- Hit Pause! Înghețăm temporar atacatorul în aer pt 0.08 secunde
                        rootPart.Anchored = true
                        task.delay(0.08, function()
                            if rootPart and rootPart.Parent then
                                rootPart.Anchored = false
                            end

                            -- Renew bypass before bounce to ensure it covers the bounce distance/time
                            AntiCheat.SetBypass(player, "Fly", 5)
                            AntiCheat.SetBypass(player, "Speed", 5)

                            -- Bounce the attacker after the pause
                            local bounceEvent = ReplicatedStorage:FindFirstChild("MaceBounceEvent")
                            if bounceEvent then
                                bounceEvent:FireClient(player)
                            end
                        end)

                        -- Odată ce a lovit în acest cadru, e de ajuns
                        break
                    elseif hitChar.Name == "Dummy" and hitHumanoid and hitHumanoid.Health > 0 then
                        -- Handle Dummy Hit
                        local victimColors = {}
                        if isTraining then
                            hitHumanoid.Health = 0
                            print(player.Name .. " a distrus un Dummy (Auto-Hit) pe platforma de antrenament!")

                            for _, p in ipairs(hitChar:GetDescendants()) do
                                if p:IsA("BasePart") then
                                    table.insert(victimColors, p.Color)
                                    p.Transparency = 1
                                    p.CanCollide = false
                                    for _, d in ipairs(p:GetChildren()) do
                                        if d:IsA("Decal") then d.Transparency = 1 end
                                    end
                                end
                            end
                        end

                        local groundColor = Color3.fromRGB(100, 100, 100)
                        local groundMaterial = Enum.Material.Slate
                        local targetRoot = hitChar:FindFirstChild("HumanoidRootPart")

                        if targetRoot then
                            local rayOrigin = targetRoot.Position
                            local rayDirection = Vector3.new(0, -10, 0)
                            local rayParams = RaycastParams.new()
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude

                            local ignoreList = {hitChar, character, hitboxPart}
                            rayParams.FilterDescendantsInstances = ignoreList

                            local maxCasts = 5
                            local casts = 0
                            local foundGround = false

                            while casts < maxCasts and not foundGround do
                                casts += 1
                                local groundHit = Workspace:Raycast(rayOrigin, rayDirection, rayParams)

                                if groundHit and groundHit.Instance then
                                    if groundHit.Instance.Name == "PlayerSpawn" or groundHit.Instance.Name == "HammerSpawn" or groundHit.Instance.Name == "Platform" then
                                        table.insert(ignoreList, groundHit.Instance)
                                        rayParams.FilterDescendantsInstances = ignoreList
                                        rayOrigin = groundHit.Position - Vector3.new(0, 0.01, 0)
                                    else
                                        groundColor = groundHit.Instance.Color
                                        groundMaterial = groundHit.Instance.Material
                                        foundGround = true
                                    end
                                else
                                    break
                                end
                            end
                        end

                        local vfxEvent = ReplicatedStorage:FindFirstChild("VfxEvent")
                        if targetRoot and vfxEvent then
                            vfxEvent:FireAllClients(targetRoot.Position, victimColors, groundColor, groundMaterial)
                        end

                        hitRegistered = true
                        lastHitTick = tick()

                        if targetRoot then
                            playRandomHitSound(targetRoot)
                        end

                        if currentTool then
                            local attackAnim = currentTool:FindFirstChild("Attack") or currentTool:FindFirstChild("attack")
                            if attackAnim and attackAnim:IsA("Animation") then
                                local animator = humanoid:FindFirstChildWhichIsA("Animator")
                                if animator then
                                    local track = animator:LoadAnimation(attackAnim)
                                    track:Play()
                                end
                            end
                        end

                        rootPart.Anchored = true
                        task.delay(0.08, function()
                            if rootPart and rootPart.Parent then
                                rootPart.Anchored = false
                            end

                            AntiCheat.SetBypass(player, "Fly", 5)
                            AntiCheat.SetBypass(player, "Speed", 5)

                            local bounceEvent = ReplicatedStorage:FindFirstChild("MaceBounceEvent")
                            if bounceEvent then
                                bounceEvent:FireClient(player)
                            end
                        end)
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
        if onRoundEndCallback then onRoundEndCallback() end
    end))

    table.insert(connections, Players.PlayerRemoving:Connect(function(plr)
        if plr == player then
            cleanup()
            if onRoundEndCallback then onRoundEndCallback() end
        end
    end))
end

return MaceMechanic

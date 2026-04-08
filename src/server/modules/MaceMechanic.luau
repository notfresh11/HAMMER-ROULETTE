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
    if #hitSoundIds == 0 or not parentPart then return end

    -- Use a fresh random seed based on tick to guarantee entropy
    local rng = Random.new(math.floor(tick() * 1000) % 100000)
    local randomIndex = rng:NextInteger(1, #hitSoundIds)

    -- Asigură-te că nu e la fel cu ultimul redat (și forțează selecția unui altul dacă este la fel)
    if #hitSoundIds > 1 and randomIndex == lastHitSoundIndex then
        randomIndex = randomIndex + 1
        if randomIndex > #hitSoundIds then
            randomIndex = 1
        end
    end
    lastHitSoundIndex = randomIndex

    -- Creăm un part temporar pentru a găzdui sunetul decuplat de victimă, ca să nu se oprească la moarte
    local soundAnchor = Instance.new("Part")
    soundAnchor.Name = "HitSoundAnchor"
    soundAnchor.Anchored = true
    soundAnchor.CanCollide = false
    soundAnchor.Transparency = 1
    soundAnchor.Size = Vector3.new(0.1, 0.1, 0.1)
    soundAnchor.Position = parentPart.Position
    soundAnchor.Parent = Workspace

    local hitSound = Instance.new("Sound")
    hitSound.SoundId = hitSoundIds[randomIndex]
    hitSound.RollOffMaxDistance = 150 -- Distanța la care se aude
    hitSound.Volume = 1

    -- Slight pitch variation for extra diversity
    hitSound.PlaybackSpeed = rng:NextNumber(0.9, 1.1)

    hitSound.Parent = soundAnchor

    hitSound:Play()

    -- Cleanup automatically
    game:GetService("Debris"):AddItem(soundAnchor, 2)
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
local ModifierManager = require(script.Parent.ModifierManager)

function MaceMechanic.startMechanic(player, onRoundEndCallback, isTraining, allMaceUsers)
    allMaceUsers = allMaceUsers or {player}
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

    local currentTool = nil
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

    if not MaceMechanic.jumpCooldowns then MaceMechanic.jumpCooldowns = {} end

    -- Cooldown jump în training: 10 secunde
    local applyJumpBoost = true
    if isTraining then
        local userId = player.UserId
        local lastJump = MaceMechanic.jumpCooldowns[userId] or 0
        if tick() - lastJump < 10 then
            applyJumpBoost = false
        end
    end

    humanoid.UseJumpPower = false
    if applyJumpBoost then
        humanoid.JumpHeight = 40
    else
        humanoid.JumpHeight = 7.2
    end

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

    -- Check Shadow Assassin modifier
    local isShadowAssassin = ModifierManager.IsModifierActive("Shadow Assasin")
    local isGhostParty = ModifierManager.IsModifierActive("Ghost Party")

    if isShadowAssassin and not isGhostParty then
        ModifierManager.ApplyGhostToCharacter(character, true, true)
    elseif isGhostParty then
        ModifierManager.ApplyGhostToCharacter(character, true, true)
    else
        -- VFX: Highlight & Trail Setup
        local highlight = Instance.new("Highlight")
        highlight.FillTransparency = 1
        highlight.OutlineColor = Color3.new(1, 0, 0) -- Roșu
        highlight.OutlineTransparency = 0
        highlight.Parent = character
    end

    if currentTool and (isShadowAssassin or isGhostParty) then
        for _, p in ipairs(currentTool:GetDescendants()) do
            if p:IsA("BasePart") or p:IsA("Decal") then
                p.Transparency = 1
            end
        end
    end

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

    local hasStartedFalling = false
    local fallStartTick = 0
    local maxJumpY = 0 -- Reține înălțimea maximă atinsă în săritură pentru a preveni kill-urile false
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

        local highlight = character and character:FindFirstChildWhichIsA("Highlight")
        if highlight then highlight:Destroy() end
        if isShadowAssassin or isGhostParty then
             if character then ModifierManager.ApplyGhostToCharacter(character, false) end
        end
        if trail then trail:Destroy() end
        if attachTop then attachTop:Destroy() end
        if attachBottom then attachBottom:Destroy() end

        -- Reapply baseline states based on active modifiers (Ghost Party, I cant see, Super Speed)
        ModifierManager.ReapplyPlayerStates(player)

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

    -- Spatial query attack logic - AUTO HIT

    table.insert(connections, RunService.Heartbeat:Connect(function()
        if not roundActive or not player then return end

        local now = tick()

        -- Training jump cooldown recharger
        if isTraining and humanoid and humanoid.Health > 0 then
            local userId = player.UserId
            local lastJump = MaceMechanic.jumpCooldowns[userId] or 0
            if tick() - lastJump >= 10 then
                -- Doar dacă nu e deja în aer redăm jump-ul mare
                if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall and humanoid.JumpHeight < 30 then
                    humanoid.JumpHeight = 40
                end
            end
        end

        local currentState = humanoid:GetState()
        local isCurrentlyInAir = (humanoid.FloorMaterial == Enum.Material.Air) or (currentState == Enum.HumanoidStateType.Freefall)

        -- 1. Detect if the player has started jumping/falling
        if not hasStartedFalling then
            if isCurrentlyInAir then
                hasStartedFalling = true
                fallStartTick = tick()
                maxJumpY = rootPart and rootPart.Position.Y or 0
                trail.Enabled = true

                -- Tăiem JumpHeight ca să nu poată ține Space apăsat la nesfârșit (Bunny Hop)
                if not isTraining then
                    humanoid.JumpHeight = 0
                else
                    local userId = player.UserId
                    if humanoid.JumpHeight > 30 then
                        MaceMechanic.jumpCooldowns[userId] = tick()
                        humanoid.JumpHeight = 7.2
                    end
                end
            end

            -- If they haven't jumped yet, we still check for hits in case they walk into someone
            -- But we don't end the round.
        end

        -- 2. Once they are in the air, update max height
        if hasStartedFalling and isCurrentlyInAir and rootPart and rootPart.Position.Y > maxJumpY then
            maxJumpY = rootPart.Position.Y
        end

        -- 3. Detect Landing
        if hasStartedFalling and humanoid.Health > 0 and rootPart then
            -- Oferim un grace period de 0.3 secunde de la momentul desprinderii de la sol pentru a nu se opri runda instant in momentul sariturii
            if (tick() - fallStartTick > 0.3) then
                local isOnGround = false

                -- Verificările cerute: dacă merge (Running), dacă pur și simplu nu cade (FloorMaterial valid)
                if currentState == Enum.HumanoidStateType.Running or currentState == Enum.HumanoidStateType.Landed then
                    isOnGround = true
                elseif humanoid.FloorMaterial ~= Enum.Material.Air then
                    isOnGround = true
                elseif rootPart.AssemblyLinearVelocity.Y >= -0.5 and rootPart.AssemblyLinearVelocity.Y <= 0.5 then
                    -- Dacă viteza Y e 0 și stă pe loc, sigur e pe un obiect
                    isOnGround = true
                end

                if isOnGround and not pendingLandingEnd then
                    trail.Enabled = false
                    hasStartedFalling = false
                    maxJumpY = rootPart.Position.Y

                    if isTraining then
                        if humanoid then
                            humanoid.JumpHeight = 7.2
                        end
                    else
                        pendingLandingEnd = task.delay(0.1, function()
                            if roundActive then
                                print(player.Name .. " a aterizat pe podea conform logicii simplificate.")
                                cleanup()
                                onRoundEndCallback()
                            end
                        end)
                    end
                end
            end
        end

        if not hasStartedFalling and not pendingLandingEnd then
            -- They haven't jumped yet, but we allow auto-hits if they walk into someone
        end

        if now - lastHitTick < AUTO_HIT_COOLDOWN then return end

        -- Verificăm de cât timp este în aer (trebuie să fi trecut o fracțiune de secundă pentru a nu omorî fix la săritură)
        -- și forțăm jucătorul să fie măcar în partea superioară a săriturii sau în coborâre
        local timeSinceJump = now - fallStartTick
        if timeSinceJump < 0.25 and rootPart.AssemblyLinearVelocity.Y > 10 then
            -- Prea devreme după săritură și încă se ridică cu viteză mare
            return
        end

        -- PREVINE INSTA-KILL LA ATERIZARE SAU MERS:
        -- Trebuie să fi căzut măcar 10 studs de la punctul maxim atins pentru ca hitbox-ul să fie "letal"
        local fallDistance = maxJumpY - (rootPart and rootPart.Position.Y or maxJumpY)
        if fallDistance < 10 and not pendingLandingEnd then
            -- Daca nu a căzut destul și nici nu a lovit în milisecunda imediată după aterizare, nu face nimic
            return
        end

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
                if hitHumanoid and hitHumanoid.Health > 0 and hitChar ~= character then
                    local hitPlayer = Players:GetPlayerFromCharacter(hitChar)

                    -- Check Double/Triple Trouble friendly fire
                    local isFriendlyFire = false
                    if hitPlayer and table.find(allMaceUsers, hitPlayer) then
                        isFriendlyFire = true
                    end

                    if isFriendlyFire then
                        -- Just skip hit logic for friendly mace users
                        continue
                    end

                    if hitPlayer then
                        local victimHasShield = hitChar:GetAttribute("ShieldActive")

                        -- KILL OR SHIELD BREAK!
                        if victimHasShield then
                            print(player.Name .. " a lovit scutul lui " .. hitPlayer.Name .. " (Auto-Hit)!")
                            hitChar:SetAttribute("ShieldActive", false)
                            local forceField = hitChar:FindFirstChildOfClass("ForceField")
                            if forceField then forceField:Destroy() end
                        else
                            local shouldKill = not isTraining
                            local shouldReward = not isTraining

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
                                    if groundHit.Instance.Transparency == 1 or groundHit.Instance.Name == "Zone" or groundHit.Instance.Name == "PlayerSpawn" or groundHit.Instance.Name == "HammerSpawn" then
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

                        -- SHOCKWAVE MODIFIER LOGIC
                        if ModifierManager.IsModifierActive("Shockwave") then
                            local targetRoot = hitChar:FindFirstChild("HumanoidRootPart")
                            if targetRoot then
                                local blastPos = targetRoot.Position
                                for _, otherPlayer in ipairs(Players:GetPlayers()) do
                                    if otherPlayer ~= player and otherPlayer.Character then
                                        local otherRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
                                        if otherRoot then
                                            local dist = (otherRoot.Position - blastPos).Magnitude
                                            if dist < 30 then
                                                local dir = (otherRoot.Position - blastPos).Unit
                                                if dir.Magnitude == 0 then dir = Vector3.new(0,1,0) end
                                                otherRoot.AssemblyLinearVelocity = dir * 50 + Vector3.new(0, 30, 0)
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        hitRegistered = true
                        lastHitTick = tick()

                        -- Pentru a ne asigura că hit-soundul se va auzi perfect pe poziția decesului,
                        -- pasăm un CFrame / Poziție din personaj înainte de a fi ascuns.
                        -- Funcția folosește doar coordonatele pentru crearea Part-ului invizibil.
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
                            print(player.Name .. " a distrus un Dummy (Auto-Hit) pe platforma de antrenament!")

                            -- Just collect colors for VFX
                            for _, p in ipairs(hitChar:GetDescendants()) do
                                if p:IsA("BasePart") then
                                    table.insert(victimColors, p.Color)
                                    -- Hide Dummy parts locally here as well to be completely sure it visually disappears
                                    p.Transparency = 1
                                    p.CanCollide = false
                                    for _, d in ipairs(p:GetChildren()) do
                                        if d:IsA("Decal") then d.Transparency = 1 end
                                    end
                                end
                            end

                            -- Set health to 0 to trigger the GetPropertyChangedSignal("Health") in TrainingManager
                            hitHumanoid.Health = 0
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
                                    if groundHit.Instance.Transparency == 1 or groundHit.Instance.Name == "Zone" or groundHit.Instance.Name == "PlayerSpawn" or groundHit.Instance.Name == "HammerSpawn" then
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
            if pendingLandingEnd then
                task.cancel(pendingLandingEnd)
                pendingLandingEnd = nil
            end

            hasStartedFalling = true
            fallStartTick = tick()
            maxJumpY = rootPart and rootPart.Position.Y or 0

            if humanoid.JumpHeight == 0 then
                humanoid.JumpHeight = 40
            end
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

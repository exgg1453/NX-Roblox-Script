--[[
    NX Roblox Script - Open-Source Multi-Game Utility Hub
    Maintained by NX-developer (Novatex)

    Universal: God Mode, God Position, Anti-Void, Fly (camera-direction, PC + mobile),
    NoClip, Wave Remover, Anti-AFK, movement tools (speed/jump locks, auto walk/jump/spin,
    bhop), visuals (ESP, Fullbright, FOV, upside-down cam, draggable FPS/Ping/KeyStrokes HUD),
    combat (aimbot, hitbox, camera lock), Teleport V2 (saved slots + player list), misc utilities.

    Game-specific tabs appear only when you are inside the matching game.

    License: Apache License 2.0 (see LICENSE).
    Author: NX-developer (Novatex) - https://github.com/exgg1453
    Discord: https://discord.gg/CydYr9UTX  |  YouTube: https://youtube.com/@novatexpanel
    Repository: https://github.com/exgg1453/NX-Roblox-Script
    Credits: UI built with the Rayfield library by Sirius Software, used under its own license.
]]

local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()

local Window = Rayfield:CreateWindow({
    Name = "NX Roblox Script",
    Icon = "terminal",
    LoadingTitle = "NX Roblox Script",
    LoadingSubtitle = "by NX-developer (Novatex)",
    Theme = "DarkBlue",
    ConfigurationSaving = {
       Enabled = true,
       FolderName = "NXRobloxScript",
       FileName = "config"
    },
    KeySystem = false
})

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

local function copyToClipboard(text)
    if type(setclipboard) == "function" then
        local ok = pcall(setclipboard, text)
        if ok then return true end
    end
    if type(toclipboard) == "function" then
        local ok = pcall(toclipboard, text)
        if ok then return true end
    end
    if type(set_clipboard) == "function" then
        local ok = pcall(set_clipboard, text)
        if ok then return true end
    end
    if syn and type(syn.write_clipboard) == "function" then
        local ok = pcall(syn.write_clipboard, text)
        if ok then return true end
    end
    return false
end

local function guiButton(...)
    local node = LocalPlayer:FindFirstChild("PlayerGui")
    for _, part in ipairs({...}) do
        if not node then return nil end
        node = node:FindFirstChild(part)
    end
    return node
end

local function clickGuiButton(btn)
    if type(btn) == "function" then btn = btn() end
    if not btn then return false end
    local fired = false
    if getconnections then
        for _, sigName in ipairs({"MouseButton1Click", "Activated", "MouseButton1Down", "MouseButton1Up"}) do
            local ok, conns = pcall(function() return getconnections(btn[sigName]) end)
            if ok and conns then
                for _, c in ipairs(conns) do
                    pcall(function()
                        if c.Function then c.Function()
                        elseif c.Fire then c:Fire() end
                    end)
                    fired = true
                end
            end
        end
    end
    if not fired and firesignal then
        pcall(function() firesignal(btn.MouseButton1Click) end)
        pcall(function() firesignal(btn.Activated) end)
        fired = true
    end
    return fired
end

local flyConnection, noclipConnection, espActive, espPlayerData = nil, nil, false, {}
local aimbotConnection, cameraLockConnection, hitboxConnection, hitboxHighlights = nil, nil, nil, {}
local infiniteJumpConnection = nil
local autoWalkEnabled, autoJumpEnabled = false, false
local autoWalkConnection = nil
local autoJumpStateConnection, autoJumpHeartbeatConnection, autoJumpCharConnection = nil, nil, nil
local autoSpinEnabled = false
local autoSpinBAV = nil
local autoSpinSpeed = 5
local godPositionEnabled = false
local godPositionConnection = nil
local godPositionHeight = 1000000
local godPositionSafePos = nil
local walkSpeedLockEnabled, jumpPowerLockEnabled = false, false
local walkSpeedLockConn, jumpPowerLockConn = nil, nil
local walkSpeedCharConn, jumpPowerCharConn = nil, nil
local waveRemoverConnections = {}
local waveCustomKeywords = {}
local waveAggressiveMode = false
local waveTotalRemoved = 0
local antiAfkConnection = nil
local clickTpConnections = {}
local upsideDownActive = false
local fullbrightActive, originalLighting = false, {}

local hudGui = nil
local hudConnection = nil
local fpsEnabled, pingEnabled, keysEnabled = false, false, false
local hudRepositionMode = false
local fpsLabel, pingLabel, keysFrame = nil, nil, nil
local keyVisuals = {}
local frameTimes = {}
local pingUpdateTimer = 0

local godModeEnabled = false
local godModeConnections = {}
local godModeOriginalMax = nil

local antiVoidEnabled = false
local antiVoidConnection = nil
local antiVoidThreshold = -300
local antiVoidLastSafePos = nil

local savedSettings = {
    WalkSpeed = 16,
    JumpPower = 50,
    FOV = 70
}

local savedPositions = {}
local currentTeleportSlot = 1

local function parseSlotOption(opt)
    if opt == nil then return nil end
    if type(opt) == "table" then
        opt = opt[1]
    end
    if type(opt) ~= "string" then return nil end
    local num = tonumber(string.match(opt, "%d+"))
    return num
end

local function getCurrentSlot()
    local ok, flag = pcall(function()
        return Rayfield.Flags and Rayfield.Flags["TeleportSlot"]
    end)
    if ok and flag then
        local opt = flag.CurrentOption
        local num = parseSlotOption(opt)
        if num and num >= 1 and num <= 5 then
            return num
        end
    end
    if currentTeleportSlot and currentTeleportSlot >= 1 and currentTeleportSlot <= 5 then
        return currentTeleportSlot
    end
    return 1
end

local function GetClosestVisiblePlayer(MaxDistance)
    local closestPlayer = nil
    local shortestDistance = MaxDistance or math.huge
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health <= 0 then continue end

            local targetRoot = player.Character.HumanoidRootPart
            local distance = (myRoot.Position - targetRoot.Position).Magnitude
            if distance < shortestDistance then
                local rayOrigin = myRoot.Position
                local rayDirection = (targetRoot.Position - rayOrigin).Unit * distance
                local rayParams = RaycastParams.new()
                rayParams.FilterDescendantsInstances = {LocalPlayer.Character, player.Character}
                rayParams.FilterType = Enum.RaycastFilterType.Exclude

                local rayResult = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
                if not rayResult then
                    shortestDistance = distance
                    closestPlayer = player
                end
            end
        end
    end
    return closestPlayer
end

local function applyGodModeToCharacter(char)
    if not godModeEnabled or not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then
        local h = char:WaitForChild("Humanoid", 5)
        hum = h
    end
    if not hum then return end

    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    end)
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    end)
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    end)
    pcall(function()
        hum.BreakJointsOnDeath = false
    end)

    if godModeOriginalMax == nil then
        godModeOriginalMax = hum.MaxHealth
    end

    hum.MaxHealth = 1e9
    hum.Health = 1e9

    local hpConn = hum.HealthChanged:Connect(function(health)
        if godModeEnabled and health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
    end)
    table.insert(godModeConnections, hpConn)

    local stateConn = hum.StateChanged:Connect(function(_, newState)
        if godModeEnabled and newState == Enum.HumanoidStateType.Dead then
            pcall(function()
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                hum.Health = hum.MaxHealth
            end)
        end
    end)
    table.insert(godModeConnections, stateConn)

    local diedConn = hum.Died:Connect(function()
        if godModeEnabled then
            local lp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local pos = lp and lp.Position or nil
            LocalPlayer.CharacterAdded:Wait()
            task.wait(0.2)
            applyGodModeToCharacter(LocalPlayer.Character)
            if pos and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
            end
        end
    end)
    table.insert(godModeConnections, diedConn)
end

local function disableGodMode()
    godModeEnabled = false
    for _, c in ipairs(godModeConnections) do
        if c then pcall(function() c:Disconnect() end) end
    end
    table.clear(godModeConnections)

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                hum.BreakJointsOnDeath = true
            end)
            local restore = godModeOriginalMax or 100
            hum.MaxHealth = restore
            hum.Health = restore
        end
    end
    godModeOriginalMax = nil
end

LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    hum.WalkSpeed = savedSettings.WalkSpeed
    hum.JumpPower = savedSettings.JumpPower
    hum.UseJumpPower = true
    if godModeEnabled then
        task.wait(0.1)
        applyGodModeToCharacter(char)
    end
end)

local function getKeyboardKeyStates()
    local W, A, S, D, Space, Shift = false, false, false, false, false, false
    if UserInputService.KeyboardEnabled then
        W = UserInputService:IsKeyDown(Enum.KeyCode.W)
        A = UserInputService:IsKeyDown(Enum.KeyCode.A)
        S = UserInputService:IsKeyDown(Enum.KeyCode.S)
        D = UserInputService:IsKeyDown(Enum.KeyCode.D)
        Space = UserInputService:IsKeyDown(Enum.KeyCode.Space)
        Shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
    end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.MoveDirection.Magnitude > 0.1 then
        local localDir = Camera.CFrame:VectorToObjectSpace(hum.MoveDirection)
        if localDir.Z < -0.3 then W = true end
        if localDir.Z > 0.3 then S = true end
        if localDir.X < -0.3 then A = true end
        if localDir.X > 0.3 then D = true end
    end

    if hum and hum:GetState() == Enum.HumanoidStateType.Jumping then
        Space = true
    end

    return {W = W, A = A, S = S, D = D, Space = Space, Shift = Shift}
end

local function getPingValue()
    local ok, ping = pcall(function()
        return LocalPlayer:GetNetworkPing() * 1000
    end)
    if ok and ping then
        return math.floor(ping)
    end
    local ok2, statsPing = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok2 and statsPing then
        return math.floor(statsPing)
    end
    return -1
end

local function fpsColor(fps)
    if fps >= 50 then return Color3.fromRGB(80, 240, 120)
    elseif fps >= 30 then return Color3.fromRGB(255, 220, 80)
    else return Color3.fromRGB(255, 90, 90) end
end

local function pingColor(ping)
    if ping < 0 then return Color3.fromRGB(180, 180, 180)
    elseif ping <= 100 then return Color3.fromRGB(80, 240, 120)
    elseif ping <= 250 then return Color3.fromRGB(255, 220, 80)
    else return Color3.fromRGB(255, 90, 90) end
end

local function makeDraggable(frame)
    frame.Active = true
    local dragging = false
    local dragInput, dragStart, startPos

    frame.InputBegan:Connect(function(input)
        if not hudRepositionMode then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging and hudRepositionMode then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local function applyRepositionVisual(frame, isOutlineTarget)
    if not frame then return end
    local existing = frame:FindFirstChild("RepositionStroke")
    if hudRepositionMode then
        if not existing then
            local stroke = Instance.new("UIStroke")
            stroke.Name = "RepositionStroke"
            stroke.Color = Color3.fromRGB(80, 200, 255)
            stroke.Thickness = 2
            stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            stroke.Parent = frame
        end
        if isOutlineTarget and frame:IsA("Frame") and frame.BackgroundTransparency == 1 then
            frame.BackgroundColor3 = Color3.fromRGB(80, 200, 255)
            frame.BackgroundTransparency = 0.85
        end
    else
        if existing then existing:Destroy() end
        if isOutlineTarget and frame:IsA("Frame") then
            frame.BackgroundTransparency = 1
        end
    end
end

local function refreshRepositionVisuals()
    if fpsLabel then applyRepositionVisual(fpsLabel, false) end
    if pingLabel then applyRepositionVisual(pingLabel, false) end
    if keysFrame then applyRepositionVisual(keysFrame, true) end
end

local function ensureHud()
    if hudGui and hudGui.Parent then return end

    hudGui = Instance.new("ScreenGui")
    hudGui.Name = "DeltaProHub_HUD"
    hudGui.ResetOnSpawn = false
    hudGui.IgnoreGuiInset = true
    hudGui.DisplayOrder = 999

    local parented = false
    pcall(function()
        if gethui then
            hudGui.Parent = gethui()
            parented = true
        end
    end)
    if not parented then
        pcall(function()
            hudGui.Parent = game:GetService("CoreGui")
            parented = true
        end)
    end
    if not parented then
        hudGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    fpsLabel = Instance.new("TextLabel")
    fpsLabel.Name = "FpsLabel"
    fpsLabel.AnchorPoint = Vector2.new(1, 0)
    fpsLabel.Position = UDim2.new(1, -12, 0, 12)
    fpsLabel.Size = UDim2.new(0, 110, 0, 26)
    fpsLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    fpsLabel.BackgroundTransparency = 0.35
    fpsLabel.BorderSizePixel = 0
    fpsLabel.Font = Enum.Font.GothamBold
    fpsLabel.TextSize = 14
    fpsLabel.TextColor3 = Color3.fromRGB(80, 240, 120)
    fpsLabel.Text = "FPS: --"
    fpsLabel.TextXAlignment = Enum.TextXAlignment.Center
    fpsLabel.Visible = false
    fpsLabel.Parent = hudGui
    local fpsCorner = Instance.new("UICorner")
    fpsCorner.CornerRadius = UDim.new(0, 6)
    fpsCorner.Parent = fpsLabel
    makeDraggable(fpsLabel)

    pingLabel = Instance.new("TextLabel")
    pingLabel.Name = "PingLabel"
    pingLabel.AnchorPoint = Vector2.new(1, 0)
    pingLabel.Position = UDim2.new(1, -12, 0, 44)
    pingLabel.Size = UDim2.new(0, 110, 0, 26)
    pingLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    pingLabel.BackgroundTransparency = 0.35
    pingLabel.BorderSizePixel = 0
    pingLabel.Font = Enum.Font.GothamBold
    pingLabel.TextSize = 14
    pingLabel.TextColor3 = Color3.fromRGB(80, 240, 120)
    pingLabel.Text = "Ping: --"
    pingLabel.TextXAlignment = Enum.TextXAlignment.Center
    pingLabel.Visible = false
    pingLabel.Parent = hudGui
    local pingCorner = Instance.new("UICorner")
    pingCorner.CornerRadius = UDim.new(0, 6)
    pingCorner.Parent = pingLabel
    makeDraggable(pingLabel)

    keysFrame = Instance.new("Frame")
    keysFrame.Name = "KeysFrame"
    keysFrame.AnchorPoint = Vector2.new(0, 1)
    keysFrame.Position = UDim2.new(0, 20, 1, -20)
    keysFrame.Size = UDim2.new(0, 132, 0, 90)
    keysFrame.BackgroundTransparency = 1
    keysFrame.Visible = false
    keysFrame.Parent = hudGui

    local function makeKey(letter, x, y, w, h)
        local f = Instance.new("Frame")
        f.Name = letter
        f.Size = UDim2.new(0, w, 0, h)
        f.Position = UDim2.new(0, x, 0, y)
        f.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        f.BackgroundTransparency = 0.35
        f.BorderSizePixel = 0
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = f

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = letter
        lbl.TextColor3 = Color3.fromRGB(200, 200, 210)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 16
        lbl.Parent = f

        f.Parent = keysFrame
        return {frame = f, label = lbl}
    end

    keyVisuals.W = makeKey("W", 46, 0, 40, 40)
    keyVisuals.A = makeKey("A", 0, 44, 40, 40)
    keyVisuals.S = makeKey("S", 46, 44, 40, 40)
    keyVisuals.D = makeKey("D", 92, 44, 40, 40)
    keyVisuals.Space = makeKey("SPACE", 0, 0, 40, 40)
    keyVisuals.Space.label.TextSize = 10
    keyVisuals.Space.frame.Position = UDim2.new(0, 0, 0, 0)
    keyVisuals.Space.frame.Size = UDim2.new(0, 40, 0, 40)

    makeDraggable(keysFrame)
end

local function setKeyVisual(entry, pressed)
    if not entry then return end
    if pressed then
        entry.frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        entry.frame.BackgroundTransparency = 0.05
        entry.label.TextColor3 = Color3.fromRGB(15, 15, 15)
    else
        entry.frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        entry.frame.BackgroundTransparency = 0.35
        entry.label.TextColor3 = Color3.fromRGB(200, 200, 210)
    end
end

local function startHud()
    if hudConnection then return end
    ensureHud()
    hudConnection = RunService.RenderStepped:Connect(function(dt)
        if fpsEnabled and fpsLabel then
            table.insert(frameTimes, dt)
            if #frameTimes > 30 then table.remove(frameTimes, 1) end
            local sum = 0
            for _, t in ipairs(frameTimes) do sum = sum + t end
            if sum > 0 then
                local fps = math.floor(#frameTimes / sum)
                fpsLabel.Text = "FPS: " .. fps
                fpsLabel.TextColor3 = fpsColor(fps)
            end
        end

        if pingEnabled and pingLabel then
            pingUpdateTimer = pingUpdateTimer + dt
            if pingUpdateTimer >= 0.5 then
                pingUpdateTimer = 0
                local p = getPingValue()
                if p < 0 then
                    pingLabel.Text = "Ping: --"
                else
                    pingLabel.Text = "Ping: " .. p .. "ms"
                end
                pingLabel.TextColor3 = pingColor(p)
            end
        end

        if keysEnabled and keysFrame then
            local s = getKeyboardKeyStates()
            setKeyVisual(keyVisuals.W, s.W)
            setKeyVisual(keyVisuals.A, s.A)
            setKeyVisual(keyVisuals.S, s.S)
            setKeyVisual(keyVisuals.D, s.D)
            setKeyVisual(keyVisuals.Space, s.Space)
        end
    end)
end

local function stopHudIfIdle()
    if not fpsEnabled and not pingEnabled and not keysEnabled then
        if hudConnection then
            hudConnection:Disconnect()
            hudConnection = nil
        end
    end
end

local waveBaseKeywords = {
    "wave", "waves", "tsunami", "tsunamis", "flood", "floods",
    "disaster", "disasters", "wins", "wackywaves", "wacky",
    "killbrick", "killpart", "deathwave", "bigwave", "hugewave",
    "tidalwave", "tidal", "earthquake", "lava", "meteor",
    "fireball", "asteroid", "blackhole", "acidrain", "acid",
    "hurricane", "tornado", "blizzard", "storm"
}

local function nameMatchesWave(name)
    if not name or name == "" then return false end
    local lname = string.lower(name)
    for _, kw in ipairs(waveBaseKeywords) do
        if string.find(lname, kw, 1, true) then return true end
    end
    for _, kw in ipairs(waveCustomKeywords) do
        if kw and kw ~= "" then
            if string.find(lname, string.lower(kw), 1, true) then
                return true
            end
        end
    end
    return false
end

local function isProtectedInstance(obj)
    if obj == Workspace.Terrain then return true end
    if obj == Camera then return true end
    if LocalPlayer.Character and (obj == LocalPlayer.Character or obj:IsDescendantOf(LocalPlayer.Character)) then
        return true
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and (obj == p.Character or obj:IsDescendantOf(p.Character)) then
            return true
        end
    end
    return false
end

local function destroyWaveTarget(obj)
    if not obj or not obj.Parent then return 0 end
    if isProtectedInstance(obj) then return 0 end
    local count = 0
    if obj:IsA("Folder") or obj:IsA("Model") then
        for _, c in ipairs(obj:GetChildren()) do
            if not isProtectedInstance(c) then
                local ok = pcall(function() c:Destroy() end)
                if ok then count = count + 1 end
            end
        end
    elseif obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
        local ok = pcall(function() obj:Destroy() end)
        if ok then count = count + 1 end
    end
    return count
end

local function performWaveCleanup()
    local removed = 0
    for _, child in ipairs(Workspace:GetChildren()) do
        if nameMatchesWave(child.Name) then
            removed = removed + destroyWaveTarget(child)
        end
    end
    if waveAggressiveMode then
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc.Parent and nameMatchesWave(desc.Name) then
                if desc:IsA("BasePart") or desc:IsA("MeshPart") or desc:IsA("UnionOperation") then
                    if not isProtectedInstance(desc) then
                        local ok = pcall(function() desc:Destroy() end)
                        if ok then removed = removed + 1 end
                    end
                end
            end
        end
    end
    waveTotalRemoved = waveTotalRemoved + removed
    return removed
end

local function startWaveCleanup()
    performWaveCleanup()

    local addedConn = Workspace.ChildAdded:Connect(function(child)
        task.wait(0.05)
        if child and child.Parent and nameMatchesWave(child.Name) then
            destroyWaveTarget(child)
        end
    end)
    table.insert(waveRemoverConnections, addedConn)

    if waveAggressiveMode then
        local descConn = Workspace.DescendantAdded:Connect(function(desc)
            if desc and desc.Parent and nameMatchesWave(desc.Name) then
                if desc:IsA("BasePart") or desc:IsA("MeshPart") or desc:IsA("UnionOperation") then
                    if not isProtectedInstance(desc) then
                        pcall(function() desc:Destroy() end)
                        waveTotalRemoved = waveTotalRemoved + 1
                    end
                end
            end
        end)
        table.insert(waveRemoverConnections, descConn)
    end

    local periodicTimer = 0
    local heartbeatConn = RunService.Heartbeat:Connect(function(dt)
        periodicTimer = periodicTimer + dt
        if periodicTimer >= 0.5 then
            periodicTimer = 0
            performWaveCleanup()
        end
    end)
    table.insert(waveRemoverConnections, heartbeatConn)
end

local function stopWaveCleanup()
    for _, conn in ipairs(waveRemoverConnections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    table.clear(waveRemoverConnections)
end

local MainTab = Window:CreateTab("Main", "home")
local MovementTab = Window:CreateTab("Movement", "user")
local VisualTab = Window:CreateTab("Visuals", "eye")
local CombatTab = Window:CreateTab("Combat", "crosshair")
local WavesTab = Window:CreateTab("Waves", "waves")
local TeleportTab = Window:CreateTab("Teleport V2", "map-pin")
local MiscTab = Window:CreateTab("Misc", "settings")
local BlocksTab = Window:CreateTab("Blocks", "box")
local BotTab = Window:CreateTab("Bot", "user-plus")

local MM2_PLACE_IDS = {
    [142823291] = true,
}
local Mm2Tab = nil
if MM2_PLACE_IDS[game.PlaceId] then
    Mm2Tab = Window:CreateTab("MM2", "skull")
end

local SKE_PLACE_IDS = {
    [95082159892680] = true,
}
local SkeTab = nil
if SKE_PLACE_IDS[game.PlaceId] then
    SkeTab = Window:CreateTab("Speed Escape", "zap")
end

local KLB_PLACE_IDS = {
    [89469502395769] = true,
}
local KlbTab = nil
if KLB_PLACE_IDS[game.PlaceId] then
    KlbTab = Window:CreateTab("Lucky Block", "gift")
end

local function placeMatches(idTable, nameKeywords)
    if idTable[game.PlaceId] then return true end
    local n = string.lower(tostring(game.Name))
    for _, kw in ipairs(nameKeywords) do
        if string.find(n, kw, 1, true) then return true end
    end
    return false
end

local GAG_PLACE_IDS = {
    [77085202503540] = true,
    [124977557560410] = true,
    [97598239454123] = true,
    [126884695634066] = true,
}
local GagTab = nil
if placeMatches(GAG_PLACE_IDS, {"garden"}) then
    GagTab = Window:CreateTab("Grow a Garden", "sprout")
end

MainTab:CreateToggle({
    Name = "God Mode (v2 - Kill Brick Resistant)",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            godModeEnabled = true
            applyGodModeToCharacter(LocalPlayer.Character)
            Rayfield:Notify({
                Title = "God Mode ON",
                Content = "Health protection active. Auto-revive on death.",
                Duration = 3,
                Image = "shield",
            })
        else
            disableGodMode()
            Rayfield:Notify({
                Title = "God Mode OFF",
                Content = "Health protection disabled.",
                Duration = 3,
                Image = "shield-off",
            })
        end
    end,
})

local function startGodPosition()
    if godPositionConnection then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        godPositionSafePos = hrp.Position
    end

    godPositionConnection = RunService.Heartbeat:Connect(function()
        if not godPositionEnabled then return end
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if not h or not hum or hum.Health <= 0 then return end
        local pos = h.Position
        if pos.Y < godPositionHeight - 1000 then
            local rot = h.CFrame - h.CFrame.Position
            h.CFrame = CFrame.new(pos.X, godPositionHeight, pos.Z) * rot
            h.AssemblyLinearVelocity = Vector3.zero
        end
    end)
end

local function stopGodPosition()
    if godPositionConnection then
        godPositionConnection:Disconnect()
        godPositionConnection = nil
    end
    if godPositionSafePos then
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        if h then
            pcall(function()
                local rot = h.CFrame - h.CFrame.Position
                h.CFrame = CFrame.new(godPositionSafePos) * rot
                h.AssemblyLinearVelocity = Vector3.zero
            end)
        end
        godPositionSafePos = nil
    end
end

do
    local safeRollbackEnabled = false
    local safeHistory = {}
    local maxHistory = 14
    local lastHealth = nil
    local killKeywords = { "kill", "lava", "damage", "trap", "spike", "death", "hazard", "acid", "poison", "fire", "laser", "danger", "void" }

    local function isHazardName(name)
        local l = string.lower(name)
        for _, kw in ipairs(killKeywords) do
            if string.find(l, kw, 1, true) then return true end
        end
        return false
    end

    local function rollbackToSafe(hrp)
        local target = safeHistory[1]
        if target then
            local rot = hrp.CFrame - hrp.CFrame.Position
            hrp.CFrame = CFrame.new(target) * rot
            hrp.AssemblyLinearVelocity = Vector3.zero
            safeHistory = { target }
        end
    end

    MainTab:CreateToggle({
        Name = "Safe Rollback (Anti-Death)",
        CurrentValue = false,
        Callback = function(Value)
            safeRollbackEnabled = Value
            if Value then
                safeHistory = {}
                lastHealth = nil
                task.spawn(function()
                    while safeRollbackEnabled do
                        local char = LocalPlayer.Character
                        local hum = char and char:FindFirstChildOfClass("Humanoid")
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hum and hrp and hum.Health > 0 then
                            local grounded = hum.FloorMaterial ~= Enum.Material.Air
                            local hazardBelow = false
                            local params = RaycastParams.new()
                            params.FilterType = Enum.RaycastFilterType.Exclude
                            params.FilterDescendantsInstances = { char }
                            local hit = Workspace:Raycast(hrp.Position, Vector3.new(0, -10, 0), params)
                            if hit and hit.Instance and isHazardName(hit.Instance.Name) then
                                hazardBelow = true
                            end
                            local tookDamage = (lastHealth ~= nil and hum.Health < lastHealth - 0.5)
                            if tookDamage or hazardBelow then
                                rollbackToSafe(hrp)
                            elseif grounded then
                                table.insert(safeHistory, hrp.Position)
                                if #safeHistory > maxHistory then
                                    table.remove(safeHistory, 1)
                                end
                            end
                            lastHealth = hum.Health
                        end
                        task.wait(0.2)
                    end
                end)
                Rayfield:Notify({
                    Title = "Safe Rollback ON",
                    Content = "If something hurts you or you land on a hazard, you snap back to an earlier safe spot.",
                    Duration = 6,
                    Image = "shield",
                })
            end
        end,
    })
end

MainTab:CreateToggle({
    Name = "Anti-Void (Auto-Save Position)",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            antiVoidEnabled = true
            antiVoidConnection = RunService.Heartbeat:Connect(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                if hrp.Position.Y > antiVoidThreshold then
                    if hrp.Velocity.Y >= -10 then
                        antiVoidLastSafePos = hrp.Position
                    end
                else
                    if antiVoidLastSafePos then
                        hrp.CFrame = CFrame.new(antiVoidLastSafePos + Vector3.new(0, 8, 0))
                        hrp.Velocity = Vector3.zero
                    end
                end
            end)
        else
            antiVoidEnabled = false
            if antiVoidConnection then
                antiVoidConnection:Disconnect()
                antiVoidConnection = nil
            end
        end
    end,
})

MainTab:CreateSlider({
    Name = "Anti-Void Y Threshold",
    Range = {-1000, 0},
    Increment = 10,
    Suffix = "Y",
    CurrentValue = -300,
    Callback = function(Value)
        antiVoidThreshold = Value
    end,
})

MainTab:CreateToggle({
    Name = "Fly (Camera-Direction, PC + Mobile)",
    CurrentValue = false,
    Callback = function(Value)
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hum = char:WaitForChild("Humanoid")
        local hrp = char:WaitForChild("HumanoidRootPart")

        if Value then
            local bodyGyro = Instance.new("BodyGyro")
            bodyGyro.P = 9e4
            bodyGyro.D = 1000
            bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            bodyGyro.CFrame = hrp.CFrame
            bodyGyro.Parent = hrp

            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            bodyVelocity.Velocity = Vector3.zero
            bodyVelocity.Parent = hrp

            flyConnection = RunService.RenderStepped:Connect(function()
                if not bodyGyro.Parent or not bodyVelocity.Parent then return end

                local camCFrame = Camera.CFrame
                local lookVec = camCFrame.LookVector
                local rightVec = camCFrame.RightVector

                if autoSpinEnabled then
                    bodyGyro.MaxTorque = Vector3.new(9e9, 0, 9e9)
                else
                    bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                    bodyGyro.CFrame = camCFrame
                end

                local moveDir = Vector3.zero

                if UserInputService.KeyboardEnabled then
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += lookVec end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= lookVec end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= rightVec end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += rightVec end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0, 1, 0) end
                end

                if hum and hum.MoveDirection.Magnitude > 0.1 then
                    local md = hum.MoveDirection
                    local lookFlat = Vector3.new(lookVec.X, 0, lookVec.Z)
                    local rightFlat = Vector3.new(rightVec.X, 0, rightVec.Z)
                    if lookFlat.Magnitude > 0.001 then lookFlat = lookFlat.Unit end
                    if rightFlat.Magnitude > 0.001 then rightFlat = rightFlat.Unit end
                    local fwdAmount = lookFlat:Dot(md)
                    local rightAmount = rightFlat:Dot(md)
                    moveDir += lookVec * fwdAmount
                    moveDir += rightVec * rightAmount
                end

                local speed = (hum.WalkSpeed > 16) and hum.WalkSpeed or 50
                if moveDir.Magnitude < 0.1 then
                    bodyVelocity.Velocity = Vector3.zero
                else
                    bodyVelocity.Velocity = moveDir.Unit * speed
                end
                hum.PlatformStand = true
            end)
        else
            if flyConnection then flyConnection:Disconnect() end
            for _, name in ipairs({"BodyGyro", "BodyVelocity"}) do
                local obj = hrp:FindFirstChild(name)
                if obj then obj:Destroy() end
            end
            hum.PlatformStand = false
        end
    end,
})

MainTab:CreateToggle({
    Name = "NoClip",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            local cachedParts = {}
            local cachedChar = nil

            local function refreshParts()
                table.clear(cachedParts)
                local char = LocalPlayer.Character
                cachedChar = char
                if not char then return end
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then
                        table.insert(cachedParts, v)
                    end
                end
            end

            refreshParts()
            noclipConnection = RunService.Stepped:Connect(function()
                local char = LocalPlayer.Character
                if char ~= cachedChar then
                    refreshParts()
                end
                for i = #cachedParts, 1, -1 do
                    local v = cachedParts[i]
                    if v and v.Parent then
                        if v.CanCollide then v.CanCollide = false end
                    else
                        table.remove(cachedParts, i)
                    end
                end
            end)
        else
            if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
            local char = LocalPlayer.Character
            if char then
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = true end
                end
            end
        end
    end,
})

WavesTab:CreateSection("Main Controls")

WavesTab:CreateToggle({
    Name = "Remove Waves (Smart Detection)",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            stopWaveCleanup()
            startWaveCleanup()
            Rayfield:Notify({
                Title = "Wave Remover Active",
                Content = "Smart keyword scan running. Aggressive mode optional below.",
                Duration = 3,
                Image = "shield",
            })
        else
            stopWaveCleanup()
        end
    end,
})

WavesTab:CreateToggle({
    Name = "Aggressive Deep Scan",
    CurrentValue = false,
    Callback = function(Value)
        waveAggressiveMode = Value
        if #waveRemoverConnections > 0 then
            stopWaveCleanup()
            startWaveCleanup()
        end
    end,
})

WavesTab:CreateButton({
    Name = "Force Cleanup Now",
    Callback = function()
        local n = performWaveCleanup()
        Rayfield:Notify({
            Title = "Manual Cleanup",
            Content = "Removed " .. n .. " object(s) this pass.",
            Duration = 3,
            Image = "trash-2",
        })
    end,
})

WavesTab:CreateSection("Custom Keywords")

WavesTab:CreateInput({
    Name = "Add Custom Wave Keyword",
    PlaceholderText = "e.g. lavablock, rainpart, boom",
    RemoveTextAfterFocusLost = true,
    Callback = function(Text)
        if Text and Text ~= "" then
            local trimmed = Text:gsub("^%s+", ""):gsub("%s+$", "")
            if trimmed ~= "" then
                table.insert(waveCustomKeywords, trimmed)
                Rayfield:Notify({
                    Title = "Keyword Added",
                    Content = "Now matching: " .. trimmed,
                    Duration = 3,
                    Image = "plus-circle",
                })
            end
        end
    end,
})

WavesTab:CreateButton({
    Name = "Show Custom Keywords",
    Callback = function()
        if #waveCustomKeywords == 0 then
            Rayfield:Notify({
                Title = "Custom Keywords",
                Content = "No custom keywords. Built-in list still active.",
                Duration = 4,
                Image = "list",
            })
        else
            Rayfield:Notify({
                Title = "Custom Keywords (" .. #waveCustomKeywords .. ")",
                Content = table.concat(waveCustomKeywords, ", "),
                Duration = 6,
                Image = "list",
            })
        end
    end,
})

WavesTab:CreateButton({
    Name = "Clear Custom Keywords",
    Callback = function()
        local n = #waveCustomKeywords
        table.clear(waveCustomKeywords)
        Rayfield:Notify({
            Title = "Cleared",
            Content = "Removed " .. n .. " custom keyword(s).",
            Duration = 3,
            Image = "check-circle",
        })
    end,
})

WavesTab:CreateSection("Diagnostics")

WavesTab:CreateButton({
    Name = "Wave Stats / List Targets",
    Callback = function()
        local found = {}
        for _, child in ipairs(Workspace:GetChildren()) do
            if nameMatchesWave(child.Name) then
                table.insert(found, child.Name)
            end
        end
        local content
        if #found == 0 then
            content = "No matching top-level workspace targets. Total removed so far: " .. waveTotalRemoved
        else
            content = "Top-level matches: " .. table.concat(found, ", ") .. " | Total removed: " .. waveTotalRemoved
        end
        Rayfield:Notify({
            Title = "Wave Stats",
            Content = content,
            Duration = 7,
            Image = "bar-chart",
        })
    end,
})

MainTab:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            antiAfkConnection = LocalPlayer.Idled:Connect(function()
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end)
        else
            if antiAfkConnection then
                antiAfkConnection:Disconnect()
                antiAfkConnection = nil
            end
        end
    end,
})

local function bindWalkSpeedLock()
    if walkSpeedLockConn then
        pcall(function() walkSpeedLockConn:Disconnect() end)
        walkSpeedLockConn = nil
    end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if hum.WalkSpeed ~= savedSettings.WalkSpeed then
        hum.WalkSpeed = savedSettings.WalkSpeed
    end

    walkSpeedLockConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if not walkSpeedLockEnabled then return end
        if hum.WalkSpeed ~= savedSettings.WalkSpeed then
            hum.WalkSpeed = savedSettings.WalkSpeed
        end
    end)
end

local function startWalkSpeedLock()
    bindWalkSpeedLock()
    if walkSpeedCharConn then pcall(function() walkSpeedCharConn:Disconnect() end) end
    walkSpeedCharConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
        if not walkSpeedLockEnabled then return end
        newChar:WaitForChild("Humanoid", 5)
        task.wait(0.2)
        if walkSpeedLockEnabled then bindWalkSpeedLock() end
    end)
end

local function stopWalkSpeedLock()
    if walkSpeedLockConn then
        pcall(function() walkSpeedLockConn:Disconnect() end)
        walkSpeedLockConn = nil
    end
    if walkSpeedCharConn then
        pcall(function() walkSpeedCharConn:Disconnect() end)
        walkSpeedCharConn = nil
    end
end

local function bindJumpPowerLock()
    if jumpPowerLockConn then
        pcall(function() jumpPowerLockConn:Disconnect() end)
        jumpPowerLockConn = nil
    end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    pcall(function() hum.UseJumpPower = true end)
    if hum.JumpPower ~= savedSettings.JumpPower then
        hum.JumpPower = savedSettings.JumpPower
    end

    jumpPowerLockConn = hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
        if not jumpPowerLockEnabled then return end
        if hum.JumpPower ~= savedSettings.JumpPower then
            hum.JumpPower = savedSettings.JumpPower
        end
    end)
end

local function startJumpPowerLock()
    bindJumpPowerLock()
    if jumpPowerCharConn then pcall(function() jumpPowerCharConn:Disconnect() end) end
    jumpPowerCharConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
        if not jumpPowerLockEnabled then return end
        newChar:WaitForChild("Humanoid", 5)
        task.wait(0.2)
        if jumpPowerLockEnabled then bindJumpPowerLock() end
    end)
end

local function stopJumpPowerLock()
    if jumpPowerLockConn then
        pcall(function() jumpPowerLockConn:Disconnect() end)
        jumpPowerLockConn = nil
    end
    if jumpPowerCharConn then
        pcall(function() jumpPowerCharConn:Disconnect() end)
        jumpPowerCharConn = nil
    end
end

MovementTab:CreateSlider({
    Name = "WalkSpeed",
    Range = {16, 500},
    Increment = 1,
    Suffix = "Studs/s",
    CurrentValue = 16,
    Callback = function(Value)
        savedSettings.WalkSpeed = Value
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then hum.WalkSpeed = Value end
    end,
})

MovementTab:CreateToggle({
    Name = "Lock WalkSpeed (Anti-Reset)",
    CurrentValue = false,
    Callback = function(Value)
        walkSpeedLockEnabled = Value
        if Value then
            startWalkSpeedLock()
            Rayfield:Notify({
                Title = "WalkSpeed Locked",
                Content = "Game cannot reset your WalkSpeed anymore.",
                Duration = 3,
                Image = "lock",
            })
        else
            stopWalkSpeedLock()
        end
    end,
})

MovementTab:CreateSlider({
    Name = "JumpPower",
    Range = {50, 500},
    Increment = 1,
    Suffix = "Power",
    CurrentValue = 50,
    Callback = function(Value)
        savedSettings.JumpPower = Value
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then
            hum.JumpPower = Value
            hum.UseJumpPower = true
        end
    end,
})

MovementTab:CreateToggle({
    Name = "Lock JumpPower (Anti-Reset)",
    CurrentValue = false,
    Callback = function(Value)
        jumpPowerLockEnabled = Value
        if Value then
            startJumpPowerLock()
            Rayfield:Notify({
                Title = "JumpPower Locked",
                Content = "Game cannot reset your JumpPower anymore.",
                Duration = 3,
                Image = "lock",
            })
        else
            stopJumpPowerLock()
        end
    end,
})

MovementTab:CreateToggle({
    Name = "Infinite Air Jump",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            infiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
        else
            if infiniteJumpConnection then infiniteJumpConnection:Disconnect() end
        end
    end,
})

local function startAutoWalk()
    pcall(function()
        RunService:UnbindFromRenderStep("DeltaAutoWalk")
    end)
    pcall(function()
        RunService:BindToRenderStep("DeltaAutoWalk", Enum.RenderPriority.Character.Value + 1, function()
            if not autoWalkEnabled then return end
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return end

            local lookVec = Camera.CFrame.LookVector
            local horizontal = Vector3.new(lookVec.X, 0, lookVec.Z)
            if horizontal.Magnitude < 0.001 then return end
            horizontal = horizontal.Unit
            pcall(function()
                hum:Move(horizontal, false)
            end)
        end)
    end)
end

local function stopAutoWalk()
    pcall(function()
        RunService:UnbindFromRenderStep("DeltaAutoWalk")
    end)
    if autoWalkConnection then
        autoWalkConnection:Disconnect()
        autoWalkConnection = nil
    end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum:Move(Vector3.zero, false) end)
    end
end

local function attachAutoJumpToHumanoid(hum)
    if autoJumpStateConnection then
        autoJumpStateConnection:Disconnect()
        autoJumpStateConnection = nil
    end
    if not hum then return end

    autoJumpStateConnection = hum.StateChanged:Connect(function(_, newState)
        if not autoJumpEnabled then return end
        if newState == Enum.HumanoidStateType.Landed then
            task.wait(0.03)
            if autoJumpEnabled and hum.Parent then
                pcall(function()
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end)
            end
        end
    end)

    if hum.FloorMaterial ~= Enum.Material.Air then
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end

local function startAutoJump()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    attachAutoJumpToHumanoid(hum)

    if autoJumpCharConnection then
        autoJumpCharConnection:Disconnect()
    end
    autoJumpCharConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
        local newHum = newChar:WaitForChild("Humanoid", 5)
        if autoJumpEnabled and newHum then
            attachAutoJumpToHumanoid(newHum)
        end
    end)

    if not autoJumpHeartbeatConnection then
        autoJumpHeartbeatConnection = RunService.Heartbeat:Connect(function()
            if not autoJumpEnabled then return end
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if not h or h.Health <= 0 then return end
            local state = h:GetState()
            if h.FloorMaterial ~= Enum.Material.Air
                and state ~= Enum.HumanoidStateType.Jumping
                and state ~= Enum.HumanoidStateType.Freefall then
                pcall(function()
                    h:ChangeState(Enum.HumanoidStateType.Jumping)
                end)
            end
        end)
    end
end

local function stopAutoJump()
    if autoJumpStateConnection then
        autoJumpStateConnection:Disconnect()
        autoJumpStateConnection = nil
    end
    if autoJumpCharConnection then
        autoJumpCharConnection:Disconnect()
        autoJumpCharConnection = nil
    end
    if autoJumpHeartbeatConnection then
        autoJumpHeartbeatConnection:Disconnect()
        autoJumpHeartbeatConnection = nil
    end
end

MovementTab:CreateToggle({
    Name = "Auto Walk (Camera Direction)",
    CurrentValue = false,
    Callback = function(Value)
        autoWalkEnabled = Value
        if Value then
            startAutoWalk()
            Rayfield:Notify({
                Title = "Auto Walk ON",
                Content = "Walking toward camera direction. Aim camera to steer.",
                Duration = 3,
                Image = "navigation",
            })
        else
            stopAutoWalk()
        end
    end,
})

MovementTab:CreateToggle({
    Name = "Auto Jump",
    CurrentValue = false,
    Callback = function(Value)
        autoJumpEnabled = Value
        if Value then
            startAutoJump()
        else
            stopAutoJump()
        end
    end,
})

MovementTab:CreateToggle({
    Name = "Bhop Combo (Auto Walk + Auto Jump)",
    CurrentValue = false,
    Callback = function(Value)
        autoWalkEnabled = Value
        autoJumpEnabled = Value
        if Value then
            startAutoWalk()
            startAutoJump()
            Rayfield:Notify({
                Title = "Bhop ON",
                Content = "Auto walking and jumping. Aim camera to steer.",
                Duration = 3,
                Image = "rabbit",
            })
        else
            stopAutoWalk()
            stopAutoJump()
        end
    end,
})

do
local autoSpinRespawnConn = nil

local function applyAutoSpinToCharacter()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    pcall(function() hum.AutoRotate = false end)

    if autoSpinBAV then
        pcall(function() autoSpinBAV:Destroy() end)
        autoSpinBAV = nil
    end

    autoSpinBAV = Instance.new("BodyAngularVelocity")
    autoSpinBAV.Name = "DeltaAutoSpin"
    autoSpinBAV.MaxTorque = Vector3.new(0, 9e9, 0)
    autoSpinBAV.AngularVelocity = Vector3.new(0, math.rad(360) * autoSpinSpeed, 0)
    autoSpinBAV.P = 1250
    autoSpinBAV.Parent = hrp
end

local function startAutoSpin()
    applyAutoSpinToCharacter()
    if autoSpinRespawnConn then
        pcall(function() autoSpinRespawnConn:Disconnect() end)
    end
    autoSpinRespawnConn = LocalPlayer.CharacterAdded:Connect(function(char)
        if not autoSpinEnabled then return end
        char:WaitForChild("HumanoidRootPart", 10)
        char:WaitForChild("Humanoid", 10)
        task.wait(0.2)
        if autoSpinEnabled then
            applyAutoSpinToCharacter()
        end
    end)
end

local function stopAutoSpin()
    if autoSpinRespawnConn then
        pcall(function() autoSpinRespawnConn:Disconnect() end)
        autoSpinRespawnConn = nil
    end
    if autoSpinBAV then
        pcall(function() autoSpinBAV:Destroy() end)
        autoSpinBAV = nil
    end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum.AutoRotate = true end)
    end
end

MovementTab:CreateToggle({
    Name = "Auto Spin (Rotate Character)",
    CurrentValue = false,
    Callback = function(Value)
        autoSpinEnabled = Value
        if Value then
            startAutoSpin()
        else
            stopAutoSpin()
        end
    end,
})

MovementTab:CreateSlider({
    Name = "Auto Spin Speed",
    Range = {1, 30},
    Increment = 1,
    Suffix = "rev/s",
    CurrentValue = 5,
    Callback = function(Value)
        autoSpinSpeed = Value
        if autoSpinBAV then
            autoSpinBAV.AngularVelocity = Vector3.new(0, math.rad(360) * Value, 0)
        end
    end,
})
end

do
    local antiBounceEnabled = false
    local antiBounceRespawnConn = nil
    local noBounceProps = PhysicalProperties.new(0.7, 0.3, 0, 1, 1)

    local function applyAntiBounce()
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.CustomPhysicalProperties = noBounceProps
                end)
            end
        end
    end

    MovementTab:CreateToggle({
        Name = "Anti-Bounce (No Wall Bounce)",
        CurrentValue = false,
        Callback = function(Value)
            antiBounceEnabled = Value
            if Value then
                applyAntiBounce()
                if antiBounceRespawnConn then
                    pcall(function() antiBounceRespawnConn:Disconnect() end)
                end
                antiBounceRespawnConn = LocalPlayer.CharacterAdded:Connect(function(char)
                    if not antiBounceEnabled then return end
                    char:WaitForChild("HumanoidRootPart", 10)
                    task.wait(0.3)
                    if antiBounceEnabled then
                        applyAntiBounce()
                    end
                end)
                Rayfield:Notify({
                    Title = "Anti-Bounce ON",
                    Content = "Removed elasticity - you won't bounce off walls at high speed.",
                    Duration = 4,
                    Image = "shield",
                })
            else
                if antiBounceRespawnConn then
                    pcall(function() antiBounceRespawnConn:Disconnect() end)
                    antiBounceRespawnConn = nil
                end
                local char = LocalPlayer.Character
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            pcall(function() part.CustomPhysicalProperties = nil end)
                        end
                    end
                end
            end
        end,
    })
end

local function createESP(player)
    if player == LocalPlayer then return end
    if espPlayerData[player] then return end
    local function onCharacter(character)
        local head = character:WaitForChild("Head", 5)
        if not head then return end
        if head:FindFirstChild("EspTag") then return end
        local bill = Instance.new("BillboardGui")
        bill.Name = "EspTag"
        bill.Size = UDim2.new(0, 100, 0, 40)
        bill.StudsOffset = Vector3.new(0, 2, 0)
        bill.AlwaysOnTop = true
        local tl = Instance.new("TextLabel")
        tl.Text = player.Name
        tl.Size = UDim2.new(1, 0, 1, 0)
        tl.BackgroundTransparency = 1
        tl.TextColor3 = Color3.fromRGB(255, 50, 50)
        tl.TextStrokeTransparency = 0
        tl.Parent = bill
        bill.Parent = head
        espPlayerData[player] = bill
    end
    if player.Character then onCharacter(player.Character) end
    player.CharacterAdded:Connect(onCharacter)
end

local function clearESP()
    for player, bill in pairs(espPlayerData) do
        if bill then bill:Destroy() end
    end
    table.clear(espPlayerData)
end

VisualTab:CreateToggle({
    Name = "Player ESP",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            for _, player in ipairs(Players:GetPlayers()) do createESP(player) end
            Players.PlayerAdded:Connect(createESP)
            local function onRemove(player)
                if espPlayerData[player] then
                    espPlayerData[player]:Destroy()
                    espPlayerData[player] = nil
                end
            end
            Players.PlayerRemoving:Connect(onRemove)
            espActive = true
        else
            clearESP()
            espActive = false
        end
    end,
})

VisualTab:CreateToggle({
    Name = "Fullbright",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            originalLighting.Brightness = Lighting.Brightness
            originalLighting.ClockTime = Lighting.ClockTime
            originalLighting.FogEnd = Lighting.FogEnd
            originalLighting.GlobalShadows = Lighting.GlobalShadows
            originalLighting.Ambient = Lighting.Ambient
            originalLighting.OutdoorAmbient = Lighting.OutdoorAmbient

            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 1e6
            Lighting.GlobalShadows = false
            Lighting.Ambient = Color3.fromRGB(178, 178, 178)
            Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
            fullbrightActive = true
        else
            if fullbrightActive then
                Lighting.Brightness = originalLighting.Brightness or 2
                Lighting.ClockTime = originalLighting.ClockTime or 14
                Lighting.FogEnd = originalLighting.FogEnd or 1e6
                Lighting.GlobalShadows = originalLighting.GlobalShadows or true
                Lighting.Ambient = originalLighting.Ambient or Color3.fromRGB(0, 0, 0)
                Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient or Color3.fromRGB(127, 127, 127)
                fullbrightActive = false
            end
        end
    end,
})

VisualTab:CreateSlider({
    Name = "Camera FOV",
    Range = {30, 120},
    Increment = 1,
    Suffix = "deg",
    CurrentValue = 70,
    Callback = function(Value)
        savedSettings.FOV = Value
        Camera.FieldOfView = Value
    end,
})

VisualTab:CreateToggle({
    Name = "Upside-Down Camera",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            upsideDownActive = true
            local ok = pcall(function()
                RunService:BindToRenderStep("UpsideDownCam", Enum.RenderPriority.Camera.Value + 1, function()
                    if upsideDownActive then
                        Camera.CFrame = Camera.CFrame * CFrame.Angles(0, 0, math.pi)
                    end
                end)
            end)
            if not ok then
                upsideDownActive = false
                Rayfield:Notify({
                    Title = "Error",
                    Content = "Could not bind to render step.",
                    Duration = 3,
                    Image = "x-circle",
                })
            end
        else
            upsideDownActive = false
            pcall(function()
                RunService:UnbindFromRenderStep("UpsideDownCam")
            end)
        end
    end,
})

VisualTab:CreateToggle({
    Name = "FPS Counter",
    CurrentValue = false,
    Callback = function(Value)
        fpsEnabled = Value
        ensureHud()
        if fpsLabel then fpsLabel.Visible = Value end
        if Value then
            startHud()
        else
            stopHudIfIdle()
        end
    end,
})

VisualTab:CreateToggle({
    Name = "Ping / Lag Indicator",
    CurrentValue = false,
    Callback = function(Value)
        pingEnabled = Value
        ensureHud()
        if pingLabel then pingLabel.Visible = Value end
        if Value then
            startHud()
        else
            stopHudIfIdle()
        end
    end,
})

VisualTab:CreateToggle({
    Name = "KeyStrokes Overlay (PC + Mobile)",
    CurrentValue = false,
    Callback = function(Value)
        keysEnabled = Value
        ensureHud()
        if keysFrame then keysFrame.Visible = Value end
        if Value then
            startHud()
        else
            stopHudIfIdle()
            if not Value then
                for _, entry in pairs(keyVisuals) do
                    setKeyVisual(entry, false)
                end
            end
        end
    end,
})

VisualTab:CreateToggle({
    Name = "Reposition HUD (Drag FPS / Ping / Keys)",
    CurrentValue = false,
    Callback = function(Value)
        hudRepositionMode = Value
        ensureHud()
        refreshRepositionVisuals()
        if Value then
            if fpsLabel and not fpsEnabled then fpsLabel.Visible = true end
            if pingLabel and not pingEnabled then pingLabel.Visible = true end
            if keysFrame and not keysEnabled then keysFrame.Visible = true end
            Rayfield:Notify({
                Title = "Reposition Mode ON",
                Content = "Drag any HUD element to move it. Toggle off to lock.",
                Duration = 4,
                Image = "move",
            })
        else
            if fpsLabel and not fpsEnabled then fpsLabel.Visible = false end
            if pingLabel and not pingEnabled then pingLabel.Visible = false end
            if keysFrame and not keysEnabled then keysFrame.Visible = false end
        end
    end,
})

VisualTab:CreateButton({
    Name = "Reset HUD Positions",
    Callback = function()
        ensureHud()
        if fpsLabel then fpsLabel.Position = UDim2.new(1, -12, 0, 12) end
        if pingLabel then pingLabel.Position = UDim2.new(1, -12, 0, 44) end
        if keysFrame then keysFrame.Position = UDim2.new(0, 20, 1, -20) end
        Rayfield:Notify({
            Title = "HUD Reset",
            Content = "All HUD elements moved back to defaults.",
            Duration = 3,
            Image = "rotate-ccw",
        })
    end,
})

CombatTab:CreateToggle({
    Name = "Aimbot (Wall-Check)",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            aimbotConnection = RunService.RenderStepped:Connect(function()
                local target = GetClosestVisiblePlayer(1000)
                if target and target.Character and target.Character:FindFirstChild("Head") then
                    local hum = target.Character:FindFirstChild("Humanoid")
                    if hum and hum.Health > 0 then
                        local headPos = target.Character.Head.Position
                        Camera.CFrame = CFrame.new(Camera.CFrame.Position, headPos)
                    end
                end
            end)
        else
            if aimbotConnection then aimbotConnection:Disconnect() end
        end
    end,
})

CombatTab:CreateToggle({
    Name = "Hitbox (Red Glow)",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            local function addHighlight(player)
                if player == LocalPlayer or hitboxHighlights[player] then return end
                local char = player.Character
                if not char then return end
                local highlight = Instance.new("Highlight")
                highlight.FillColor = Color3.fromRGB(255, 0, 0)
                highlight.OutlineColor = Color3.fromRGB(255, 100, 100)
                highlight.FillTransparency = 0.6
                highlight.OutlineTransparency = 0
                highlight.Parent = char
                hitboxHighlights[player] = highlight
            end

            for _, player in ipairs(Players:GetPlayers()) do addHighlight(player) end
            local function charAdded(char)
                local player = Players:GetPlayerFromCharacter(char)
                if player then addHighlight(player) end
            end
            local addedCon = Players.PlayerAdded:Connect(function(player)
                if player.Character then addHighlight(player) end
                player.CharacterAdded:Connect(charAdded)
            end)
            local removingCon = Players.PlayerRemoving:Connect(function(player)
                if hitboxHighlights[player] then
                    hitboxHighlights[player]:Destroy()
                    hitboxHighlights[player] = nil
                end
            end)
            hitboxConnection = {addedCon, removingCon}
        else
            for player, highlight in pairs(hitboxHighlights) do
                if highlight then highlight:Destroy() end
            end
            table.clear(hitboxHighlights)
            if hitboxConnection then
                for _, con in ipairs(hitboxConnection) do con:Disconnect() end
                hitboxConnection = nil
            end
        end
    end,
})

CombatTab:CreateToggle({
    Name = "Camera Lock",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            local lockedCFrame = Camera.CFrame
            cameraLockConnection = RunService.RenderStepped:Connect(function()
                Camera.CFrame = lockedCFrame
            end)
        else
            if cameraLockConnection then cameraLockConnection:Disconnect() end
        end
    end,
})

TeleportTab:CreateDropdown({
    Name = "Select Slot",
    Options = {"Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5"},
    CurrentOption = {"Slot 1"},
    MultipleOptions = false,
    Flag = "TeleportSlot",
    Callback = function(Option)
        local num = parseSlotOption(Option)
        if num and num >= 1 and num <= 5 then
            currentTeleportSlot = num
        end
    end,
})

TeleportTab:CreateButton({
    Name = "Save Position to Slot",
    Callback = function()
        local slot = getCurrentSlot()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            savedPositions[slot] = char.HumanoidRootPart.Position
            Rayfield:Notify({
                Title = "Saved",
                Content = "Position saved to Slot " .. tostring(slot),
                Duration = 3,
                Image = "check-circle",
            })
        else
            Rayfield:Notify({
                Title = "Error",
                Content = "Character not found!",
                Duration = 3,
                Image = "x-circle",
            })
        end
    end,
})

TeleportTab:CreateButton({
    Name = "Teleport to Slot",
    Callback = function()
        local slot = getCurrentSlot()
        local pos = savedPositions[slot]
        if pos then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local rot = hrp.CFrame - hrp.CFrame.Position
                hrp.CFrame = CFrame.new(pos) * rot
                hrp.AssemblyLinearVelocity = Vector3.zero
                Rayfield:Notify({
                    Title = "Teleported",
                    Content = "Teleported to Slot " .. tostring(slot),
                    Duration = 3,
                    Image = "check-circle",
                })
            else
                Rayfield:Notify({
                    Title = "Error",
                    Content = "Character not found!",
                    Duration = 3,
                    Image = "x-circle",
                })
            end
        else
            Rayfield:Notify({
                Title = "Empty Slot",
                Content = "Slot " .. tostring(slot) .. " is empty. Save a position first.",
                Duration = 3,
                Image = "alert-triangle",
            })
        end
    end,
})

TeleportTab:CreateButton({
    Name = "Clear Slot",
    Callback = function()
        local slot = getCurrentSlot()
        savedPositions[slot] = nil
        Rayfield:Notify({
            Title = "Cleared",
            Content = "Slot " .. tostring(slot) .. " has been cleared.",
            Duration = 3,
            Image = "check-circle",
        })
    end,
})

TeleportTab:CreateButton({
    Name = "Show Saved Slots",
    Callback = function()
        local lines = {}
        for i = 1, 5 do
            if savedPositions[i] then
                local p = savedPositions[i]
                table.insert(lines, "Slot " .. i .. ": " .. math.floor(p.X) .. ", " .. math.floor(p.Y) .. ", " .. math.floor(p.Z))
            else
                table.insert(lines, "Slot " .. i .. ": empty")
            end
        end
        Rayfield:Notify({
            Title = "Saved Slots",
            Content = table.concat(lines, "\n"),
            Duration = 6,
            Image = "list",
        })
    end,
})

TeleportTab:CreateSection("Player Teleport")

local function getPlayerNameList()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(names, p.Name)
        end
    end
    if #names == 0 then
        table.insert(names, "No other players")
    end
    return names
end

TeleportTab:CreateDropdown({
    Name = "Select Player",
    Options = getPlayerNameList(),
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "PlayerTpTarget",
    Callback = function(Option) end,
})

local function getSelectedPlayerName()
    local ok, flag = pcall(function()
        return Rayfield.Flags and Rayfield.Flags["PlayerTpTarget"]
    end)
    if ok and flag then
        local opt = flag.CurrentOption
        if type(opt) == "table" then opt = opt[1] end
        if type(opt) == "string" then return opt end
    end
    return nil
end

TeleportTab:CreateButton({
    Name = "Refresh Player List",
    Callback = function()
        local names = getPlayerNameList()
        pcall(function()
            PlayerTpDropdown:Refresh(names, false)
        end)
        Rayfield:Notify({
            Title = "Player List Updated",
            Content = #Players:GetPlayers() - 1 .. " other player(s) in server.",
            Duration = 3,
            Image = "users",
        })
    end,
})

TeleportTab:CreateButton({
    Name = "Teleport to Player",
    Callback = function()
        local name = getSelectedPlayerName()
        if not name or name == "No other players" then
            Rayfield:Notify({
                Title = "No Selection",
                Content = "Pick a player from the dropdown first.",
                Duration = 3,
                Image = "alert-triangle",
            })
            return
        end
        local target = Players:FindFirstChild(name)
        local targetHrp = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if targetHrp and hrp then
            local rot = hrp.CFrame - hrp.CFrame.Position
            hrp.CFrame = CFrame.new(targetHrp.Position + Vector3.new(0, 3, 0)) * rot
            hrp.AssemblyLinearVelocity = Vector3.zero
            Rayfield:Notify({
                Title = "Teleported",
                Content = "Teleported to " .. name,
                Duration = 3,
                Image = "check-circle",
            })
        else
            Rayfield:Notify({
                Title = "Error",
                Content = name .. " has no character right now.",
                Duration = 3,
                Image = "x-circle",
            })
        end
    end,
})

local playerTpRefreshConns = {}
table.insert(playerTpRefreshConns, Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    pcall(function() PlayerTpDropdown:Refresh(getPlayerNameList(), false) end)
end))
table.insert(playerTpRefreshConns, Players.PlayerRemoving:Connect(function()
    task.wait(0.5)
    pcall(function() PlayerTpDropdown:Refresh(getPlayerNameList(), false) end)
end))

local function teleportToScreenPos(screenX, screenY)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local ray = Camera:ScreenPointToRay(screenX, screenY)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {char}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local result = Workspace:Raycast(ray.Origin, ray.Direction * 5000, rayParams)
    if result then
        hrp.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
        return true
    end
    return false
end

TeleportTab:CreateToggle({
    Name = "Click Teleport (PC: T or RClick / Mobile: Tap)",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            local kbConn = UserInputService.InputBegan:Connect(function(input, processed)
                if processed then return end
                if input.KeyCode == Enum.KeyCode.T or input.UserInputType == Enum.UserInputType.MouseButton2 then
                    if Mouse.Hit then
                        local char = LocalPlayer.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            hrp.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0))
                        end
                    end
                end
            end)
            table.insert(clickTpConnections, kbConn)

            local touchConn = UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
                if processedByUI then return end
                teleportToScreenPos(position.X, position.Y)
            end)
            table.insert(clickTpConnections, touchConn)

            Rayfield:Notify({
                Title = "Click TP Active",
                Content = "PC: aim and press T or right-click. Mobile: tap any spot.",
                Duration = 4,
                Image = "mouse-pointer",
            })
        else
            for _, conn in ipairs(clickTpConnections) do
                if conn then pcall(function() conn:Disconnect() end) end
            end
            table.clear(clickTpConnections)
        end
    end,
})

MiscTab:CreateButton({
    Name = "Reset Character",
    Callback = function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            if godModeEnabled then
                disableGodMode()
                task.wait(0.1)
            end
            hum.Health = 0
        end
    end,
})

MiscTab:CreateButton({
    Name = "Save Configuration",
    Callback = function()
        local ok = pcall(function()
            if Rayfield.SaveConfiguration then Rayfield:SaveConfiguration() end
        end)
        Rayfield:Notify({
            Title = ok and "Saved" or "Save Unavailable",
            Content = ok and "Your toggles and settings are saved for next time." or "Configuration saving isn't supported here.",
            Duration = 4,
            Image = ok and "save" or "alert-triangle",
        })
    end,
})

MiscTab:CreateButton({
    Name = "Show Current Place ID (Copy)",
    Callback = function()
        local id = tostring(game.PlaceId)
        local copied = copyToClipboard(id)
        Rayfield:Notify({
            Title = "Place ID: " .. id,
            Content = copied and "Copied. Paste it to your developer to enable the game tab." or "Place ID shown above.",
            Duration = 10,
            Image = "hash",
        })
        print("[NX] Current PlaceId:", id)
    end,
})

MiscTab:CreateSection("Local Asset Spawner (Client-Side Only)")

local localAssetId = ""
MiscTab:CreateInput({
    Name = "Asset / Model ID",
    PlaceholderText = "e.g. 1028593",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        localAssetId = text
    end,
})

MiscTab:CreateButton({
    Name = "Spawn Asset Locally (Only You See It)",
    Callback = function()
        local cleanedAsset = (localAssetId or ""):gsub("%s+", "")
        local id = tonumber(cleanedAsset)
        if not id then
            Rayfield:Notify({ Title = "Invalid ID", Content = "Enter a numeric asset/model ID first.", Duration = 4, Image = "alert-triangle" })
            return
        end
        local InsertService = game:GetService("InsertService")
        local ok, result = pcall(function()
            return InsertService:LoadAsset(id)
        end)
        if not ok or not result then
            Rayfield:Notify({ Title = "Load Failed", Content = "Couldn't load that ID locally. It may be private or not loadable client-side.", Duration = 6, Image = "x-circle" })
            return
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        local function attachAccessoryLocal(accessory)
            if not char then return false end
            local handle = accessory:FindFirstChild("Handle")
            if not handle then return false end
            local accAtt
            for _, a in ipairs(handle:GetChildren()) do
                if a:IsA("Attachment") then accAtt = a break end
            end
            if accAtt then
                local charAtt
                for _, d in ipairs(char:GetDescendants()) do
                    if d:IsA("Attachment") and d.Name == accAtt.Name then charAtt = d break end
                end
                if charAtt and charAtt.Parent then
                    for _, w in ipairs(handle:GetChildren()) do
                        if w:IsA("Weld") or w:IsA("Motor6D") or w:IsA("ManualWeld") then w:Destroy() end
                    end
                    handle.Massless = true
                    handle.CanCollide = false
                    local weld = Instance.new("Weld")
                    weld.Name = "NXLocalAccessoryWeld"
                    weld.Part0 = handle
                    weld.Part1 = charAtt.Parent
                    weld.C0 = accAtt.CFrame
                    weld.C1 = charAtt.CFrame
                    weld.Parent = handle
                    accessory:SetAttribute("NXLocalAccessory", true)
                    accessory.Parent = char
                    return true
                end
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                local okAdd = pcall(function() hum:AddAccessory(accessory) end)
                if okAdd then accessory:SetAttribute("NXLocalAccessory", true) end
                return okAdd
            end
            return false
        end

        local accessories = {}
        for _, d in ipairs(result:GetDescendants()) do
            if d:IsA("Accessory") then table.insert(accessories, d) end
        end

        if #accessories > 0 and char then
            local attached = 0
            for _, acc in ipairs(accessories) do
                acc.Parent = Workspace
                if attachAccessoryLocal(acc) then attached = attached + 1 end
            end
            result:Destroy()
            Rayfield:Notify({
                Title = attached > 0 and "Accessory Equipped" or "Couldn't Attach",
                Content = attached > 0 and "Equipped locally - only you see it. Take your screenshot!" or "This accessory had no matching attachment point.",
                Duration = 6,
                Image = attached > 0 and "smile" or "alert-triangle",
            })
            return
        end

        local spawnCFrame = hrp and (hrp.CFrame * CFrame.new(0, 0, -6)) or CFrame.new(0, 10, 0)
        local count = 0
        for _, obj in ipairs(result:GetChildren()) do
            obj.Parent = Workspace
            pcall(function() obj:SetAttribute("NXLocalSpawn", true) end)
            pcall(function()
                if obj:IsA("BasePart") then
                    obj.CFrame = spawnCFrame
                elseif obj:IsA("Model") then
                    if not obj.PrimaryPart then
                        obj.PrimaryPart = obj:FindFirstChildWhichIsA("BasePart")
                    end
                    obj:PivotTo(spawnCFrame)
                end
            end)
            count = count + 1
        end
        result:Destroy()
        Rayfield:Notify({
            Title = count > 0 and "Spawned Locally" or "Nothing Spawned",
            Content = count > 0 and "Loaded client-side. Only you can see this; it is not sent to the server." or "The asset loaded but had no spawnable parts.",
            Duration = 6,
            Image = count > 0 and "package" or "alert-triangle",
        })
    end,
})

MiscTab:CreateButton({
    Name = "Remove My Local Accessories",
    Callback = function()
        local removed = 0
        local char = LocalPlayer.Character
        if char then
            for _, d in ipairs(char:GetChildren()) do
                if d:IsA("Accessory") and d:GetAttribute("NXLocalAccessory") then
                    d:Destroy()
                    removed = removed + 1
                end
            end
        end
        Rayfield:Notify({ Title = "Removed", Content = removed .. " local accessory/accessories removed.", Duration = 4, Image = "trash-2" })
    end,
})

MiscTab:CreateButton({
    Name = "Clear My Spawned Assets",
    Callback = function()
        local removed = 0
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:GetAttribute("NXLocalSpawn") then
                obj:Destroy()
                removed = removed + 1
            end
        end
        Rayfield:Notify({ Title = "Cleared", Content = removed .. " locally spawned item(s) removed.", Duration = 4, Image = "trash-2" })
    end,
})

local cosmeticType = "Shirt"
MiscTab:CreateDropdown({
    Name = "Apply ID As",
    Options = {"Shirt", "Pants", "Face", "Animation (others can see)"},
    CurrentOption = {"Shirt"},
    Callback = function(opt)
        if type(opt) == "table" then cosmeticType = opt[1] else cosmeticType = opt end
    end,
})

MiscTab:CreateButton({
    Name = "Apply Cosmetic (uses Asset ID field)",
    Callback = function()
        local cleaned = (localAssetId or ""):gsub("%s+", "")
        local id = tonumber(cleaned)
        if not id then
            Rayfield:Notify({ Title = "Invalid ID", Content = "Type the ID in the 'Asset / Model ID' field above first.", Duration = 5, Image = "alert-triangle" })
            return
        end
        local char = LocalPlayer.Character
        if not char then return end
        local assetUrl = "rbxassetid://" .. id

        if cosmeticType == "Shirt" then
            local shirt = char:FindFirstChildOfClass("Shirt") or Instance.new("Shirt")
            shirt.ShirtTemplate = assetUrl
            shirt.Parent = char
            Rayfield:Notify({ Title = "Shirt Applied", Content = "Local only. Use the clothing TEMPLATE id if it doesn't show.", Duration = 6, Image = "shirt" })
        elseif cosmeticType == "Pants" then
            local pants = char:FindFirstChildOfClass("Pants") or Instance.new("Pants")
            pants.PantsTemplate = assetUrl
            pants.Parent = char
            Rayfield:Notify({ Title = "Pants Applied", Content = "Local only. Use the clothing TEMPLATE id if it doesn't show.", Duration = 6, Image = "shirt" })
        elseif cosmeticType == "Face" then
            local head = char:FindFirstChild("Head")
            if head then
                local face = head:FindFirstChild("face") or head:FindFirstChildOfClass("Decal")
                if not face then
                    face = Instance.new("Decal")
                    face.Name = "face"
                    face.Face = Enum.NormalId.Front
                    face.Parent = head
                end
                face.Texture = assetUrl
                Rayfield:Notify({ Title = "Face Applied", Content = "Local only.", Duration = 5, Image = "smile" })
            end
        else
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                local anim = Instance.new("Animation")
                anim.AnimationId = assetUrl
                local okPlay = pcall(function()
                    local animator = hum:FindFirstChildOfClass("Animator") or hum
                    local track = animator:LoadAnimation(anim)
                    track:Play()
                end)
                Rayfield:Notify({ Title = okPlay and "Animation Playing" or "Animation Failed", Content = okPlay and "Note: animations replicate - other players CAN see this one." or "Couldn't load that animation ID.", Duration = 7, Image = okPlay and "play" or "x-circle" })
            end
        end
    end,
})

local headlessOn = false
MiscTab:CreateToggle({
    Name = "Headless (Local Only)",
    CurrentValue = false,
    Callback = function(Value)
        headlessOn = Value
        local char = LocalPlayer.Character
        local head = char and char:FindFirstChild("Head")
        if head then
            head.Transparency = Value and 1 or 0
            local face = head:FindFirstChild("face") or head:FindFirstChildOfClass("Decal")
            if face then face.Transparency = Value and 1 or 0 end
            for _, acc in ipairs(char:GetChildren()) do
                if acc:IsA("Accessory") then
                    local h = acc:FindFirstChild("Handle")
                    local att = h and (h:FindFirstChild("HatAttachment") or h:FindFirstChild("FaceFrontAttachment") or h:FindFirstChild("HairAttachment"))
                    if att then h.Transparency = Value and 1 or 0 end
                end
            end
        end
        Rayfield:Notify({ Title = Value and "Headless ON" or "Headless OFF", Content = "Local only - others see your normal head.", Duration = 4, Image = "user-x" })
    end,
})

local leglessOn = false
MiscTab:CreateToggle({
    Name = "Legless (Local Only)",
    CurrentValue = false,
    Callback = function(Value)
        leglessOn = Value
        local char = LocalPlayer.Character
        if char then
            local legNames = { "Left Leg", "Right Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }
            for _, name in ipairs(legNames) do
                local part = char:FindFirstChild(name)
                if part and part:IsA("BasePart") then
                    part.Transparency = Value and 1 or 0
                end
            end
        end
        Rayfield:Notify({ Title = Value and "Legless ON" or "Legless OFF", Content = "Local only - others see your normal legs.", Duration = 4, Image = "user-x" })
    end,
})

MiscTab:CreateButton({
    Name = "Rejoin Server",
    Callback = function()
        local TeleportService = game:GetService("TeleportService")
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end,
})

MiscTab:CreateSection("Join Game by ID")

local joinPlaceId = ""
MiscTab:CreateInput({
    Name = "Place ID",
    PlaceholderText = "e.g. 77085202503540",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        joinPlaceId = text
    end,
})

MiscTab:CreateButton({
    Name = "Join Game",
    Callback = function()
        local cleanedPlace = (joinPlaceId or ""):gsub("%s+", "")
        local id = tonumber(cleanedPlace)
        if not id then
            Rayfield:Notify({ Title = "Invalid ID", Content = "Enter a numeric Place ID first.", Duration = 4, Image = "alert-triangle" })
            return
        end
        Rayfield:Notify({ Title = "Joining...", Content = "Teleporting to place " .. id .. ".", Duration = 4, Image = "log-in" })
        local TeleportService = game:GetService("TeleportService")
        local ok, err = pcall(function()
            TeleportService:Teleport(id, LocalPlayer)
        end)
        if not ok then
            local msg = tostring(err)
            if string.find(msg, "773") or string.lower(msg):find("restrict") then
                Rayfield:Notify({ Title = "Restricted (773)", Content = "Roblox blocks teleporting into this game from here. The destination disabled third-party joins - open it from the Roblox app instead.", Duration = 9, Image = "lock" })
            else
                Rayfield:Notify({ Title = "Teleport Failed", Content = "Couldn't teleport. Make sure it's a place ID (not a universe ID).", Duration = 6, Image = "x-circle" })
            end
        end
    end,
})

MiscTab:CreateSection("Stat Editor (Client-Side - Risky)")

do
    local STAT_VALUE = 999
    local skipWords = { "walk", "run", "jump", "speed", "stamina", "sprint", "velocity", "position", "pos", "icon", "image", "rotation", "size", "scale", "offset", "index", "slot", "page", "volume", "zoom", "fov", "time", "cooldown", "id" }
    local statWords = { "money", "cash", "coin", "gold", "gem", "credit", "token", "kill", "win", "level", "xp", "exp", "star", "trophy", "buck", "diamond", "score", "brainrot", "currency", "bank", "wallet", "balance", "point", "kills", "wins", "wins", "candy", "tix", "click", "rebirth", "power", "strength", "wealth", "cookie", "food", "wood", "stone", "iron" }

    local function nameHas(name, list)
        local l = string.lower(name)
        for _, w in ipairs(list) do
            if string.find(l, w, 1, true) then return true end
        end
        return false
    end

    local function isValueObj(v)
        return v:IsA("IntValue") or v:IsA("NumberValue") or v:IsA("DoubleConstrainedValue") or v:IsA("IntConstrainedValue")
    end

    local function insideUI(v)
        local p = v
        while p and p ~= LocalPlayer do
            if p.Name == "PlayerGui" or p.Name == "PlayerScripts" or p.Name == "StarterGear" then return true end
            p = p.Parent
        end
        return false
    end

    MiscTab:CreateSlider({
        Name = "Stat Value",
        Range = { 1, 1000000 },
        Increment = 1,
        Suffix = "",
        CurrentValue = 999,
        Callback = function(v) STAT_VALUE = v end,
    })

    MiscTab:CreateButton({
        Name = "Set My Stats To Value (Money etc.)",
        Callback = function()
            local changed = 0
            local seen = {}

            local ls = LocalPlayer:FindFirstChild("leaderstats")
            if ls then
                for _, v in ipairs(ls:GetDescendants()) do
                    if isValueObj(v) and not seen[v] and not nameHas(v.Name, skipWords) then
                        seen[v] = true
                        pcall(function() v.Value = STAT_VALUE end)
                        changed = changed + 1
                    end
                end
            end

            for _, v in ipairs(LocalPlayer:GetDescendants()) do
                if isValueObj(v) and not seen[v] and not insideUI(v) then
                    if nameHas(v.Name, statWords) and not nameHas(v.Name, skipWords) then
                        seen[v] = true
                        pcall(function() v.Value = STAT_VALUE end)
                        changed = changed + 1
                    end
                end
            end

            Rayfield:Notify({
                Title = "Stats Set: " .. changed,
                Content = "Only real stat values (leaderstats + money-like names). Client-side; server-authoritative games will snap it back.",
                Duration = 8,
                Image = "coins",
            })
        end,
    })
end

MiscTab:CreateButton({
    Name = "Server Hop (Random)",
    Callback = function()
        local TeleportService = game:GetService("TeleportService")
        local HttpService = game:GetService("HttpService")
        local servers = {}
        local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
        if not req then
            Rayfield:Notify({
                Title = "Unsupported",
                Content = "Your executor doesn't support HTTP requests.",
                Duration = 4,
                Image = "x-circle",
            })
            return
        end
        local ok, resp = pcall(function()
            return req({
                Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100",
                Method = "GET"
            })
        end)
        if ok and resp and resp.Body then
            local data = HttpService:JSONDecode(resp.Body)
            for _, s in ipairs(data.data or {}) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    table.insert(servers, s.id)
                end
            end
            if #servers > 0 then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LocalPlayer)
            else
                Rayfield:Notify({
                    Title = "No Servers",
                    Content = "Couldn't find another available server.",
                    Duration = 3,
                    Image = "alert-triangle",
                })
            end
        end
    end,
})

MiscTab:CreateButton({
    Name = "Destroy Hub",
    Callback = function()
        Rayfield:Destroy()
    end,
})

if Mm2Tab then
    local MURDERER_COLOR = Color3.fromRGB(255, 50, 50)
    local SHERIFF_COLOR = Color3.fromRGB(60, 130, 255)
    local INNOCENT_COLOR = Color3.fromRGB(180, 180, 180)

    local mm2EspEnabled = false
    local mm2EspData = {}
    local mm2EspConnections = {}

    local mm2AutoCoinEnabled = false
    local mm2OriginalPos = nil

    local mm2WeaponEspEnabled = false
    local mm2WeaponEspData = {}
    local mm2WeaponLoopActive = false

    local mm2DeathAlertEnabled = false
    local mm2TrackedRoles = {}
    local mm2DeathLoopActive = false

    local function hasMatchingTool(parent, keyword)
        if not parent then return false end
        for _, item in ipairs(parent:GetChildren()) do
            if item:IsA("Tool") and string.find(string.lower(item.Name), keyword, 1, true) then
                return true
            end
        end
        return false
    end

    local function getPlayerRole(player)
        local backpack = player:FindFirstChildOfClass("Backpack")
        local character = player.Character
        if hasMatchingTool(backpack, "knife") or hasMatchingTool(character, "knife") then
            return "Murderer"
        elseif hasMatchingTool(backpack, "gun") or hasMatchingTool(character, "gun")
            or hasMatchingTool(backpack, "revolver") or hasMatchingTool(character, "revolver") then
            return "Sheriff"
        else
            return "Innocent"
        end
    end

    local function roleColor(role)
        if role == "Murderer" then return MURDERER_COLOR
        elseif role == "Sheriff" then return SHERIFF_COLOR
        else return INNOCENT_COLOR end
    end

    local function applyEsp(player)
        if player == LocalPlayer then return end
        if not mm2EspEnabled then return end
        local character = player.Character
        if not character then return end

        local data = mm2EspData[player]
        if not data then
            data = {}
            mm2EspData[player] = data
        end

        local role = getPlayerRole(player)
        local color = roleColor(role)

        if not data.highlight or not data.highlight.Parent then
            if data.highlight then pcall(function() data.highlight:Destroy() end) end
            data.highlight = Instance.new("Highlight")
            data.highlight.FillTransparency = 0.5
            data.highlight.OutlineTransparency = 0
        end
        data.highlight.FillColor = color
        data.highlight.OutlineColor = color
        data.highlight.Parent = character

        local head = character:FindFirstChild("Head")
        if head then
            if not data.billboard or not data.billboard.Parent then
                if data.billboard then pcall(function() data.billboard:Destroy() end) end
                data.billboard = Instance.new("BillboardGui")
                data.billboard.Size = UDim2.new(0, 160, 0, 40)
                data.billboard.StudsOffset = Vector3.new(0, 3, 0)
                data.billboard.AlwaysOnTop = true
                local tl = Instance.new("TextLabel")
                tl.Size = UDim2.new(1, 0, 1, 0)
                tl.BackgroundTransparency = 1
                tl.Font = Enum.Font.GothamBold
                tl.TextSize = 14
                tl.TextStrokeTransparency = 0
                tl.Name = "Label"
                tl.Parent = data.billboard
                data.billboard.Parent = head
            end
            local label = data.billboard:FindFirstChild("Label")
            if label then
                label.Text = player.Name .. " [" .. role .. "]"
                label.TextColor3 = color
            end
        end
    end

    local function clearEspFor(player)
        local data = mm2EspData[player]
        if data then
            if data.highlight then pcall(function() data.highlight:Destroy() end) end
            if data.billboard then pcall(function() data.billboard:Destroy() end) end
        end
        mm2EspData[player] = nil
    end

    local mm2PlayerBackpackConns = {}

    local function hookBackpack(player)
        if mm2PlayerBackpackConns[player] then
            for _, c in ipairs(mm2PlayerBackpackConns[player]) do
                pcall(function() c:Disconnect() end)
            end
        end
        mm2PlayerBackpackConns[player] = {}

        local backpack = player:FindFirstChildOfClass("Backpack")
        if backpack then
            local bConn1 = backpack.ChildAdded:Connect(function()
                if mm2EspEnabled then
                    task.wait(0.1)
                    applyEsp(player)
                end
            end)
            local bConn2 = backpack.ChildRemoved:Connect(function()
                if mm2EspEnabled then
                    task.wait(0.1)
                    applyEsp(player)
                end
            end)
            table.insert(mm2PlayerBackpackConns[player], bConn1)
            table.insert(mm2PlayerBackpackConns[player], bConn2)
        end
        local char = player.Character
        if char then
            local cConn1 = char.ChildAdded:Connect(function(c)
                if mm2EspEnabled and c:IsA("Tool") then
                    task.wait(0.1)
                    applyEsp(player)
                end
            end)
            local cConn2 = char.ChildRemoved:Connect(function(c)
                if mm2EspEnabled and c:IsA("Tool") then
                    task.wait(0.1)
                    applyEsp(player)
                end
            end)
            table.insert(mm2PlayerBackpackConns[player], cConn1)
            table.insert(mm2PlayerBackpackConns[player], cConn2)
        end
    end

    local function hookPlayer(player)
        local addedConn = player.CharacterAdded:Connect(function()
            task.wait(0.5)
            if mm2EspEnabled then
                hookBackpack(player)
                applyEsp(player)
            end
        end)
        table.insert(mm2EspConnections, addedConn)
        hookBackpack(player)
    end

    local function fullRescan()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                applyEsp(p)
            end
        end
    end

    local function startMm2Esp()
        for _, p in ipairs(Players:GetPlayers()) do
            hookPlayer(p)
            applyEsp(p)
        end
        local joinConn = Players.PlayerAdded:Connect(function(p)
            hookPlayer(p)
            task.wait(1)
            if mm2EspEnabled then applyEsp(p) end
        end)
        local leaveConn = Players.PlayerRemoving:Connect(function(p)
            clearEspFor(p)
            if mm2PlayerBackpackConns[p] then
                for _, c in ipairs(mm2PlayerBackpackConns[p]) do
                    pcall(function() c:Disconnect() end)
                end
                mm2PlayerBackpackConns[p] = nil
            end
        end)
        table.insert(mm2EspConnections, joinConn)
        table.insert(mm2EspConnections, leaveConn)

        local roundConn = LocalPlayer.CharacterAdded:Connect(function()
            if mm2EspEnabled then
                task.wait(1)
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer then hookBackpack(p) end
                end
                fullRescan()
            end
        end)
        table.insert(mm2EspConnections, roundConn)

        task.spawn(function()
            while mm2EspEnabled do
                task.wait(1)
                if mm2EspEnabled then
                    fullRescan()
                end
            end
        end)
    end

    local function stopMm2Esp()
        for player, conns in pairs(mm2PlayerBackpackConns) do
            for _, c in ipairs(conns) do
                pcall(function() c:Disconnect() end)
            end
        end
        table.clear(mm2PlayerBackpackConns)
        for _, c in ipairs(mm2EspConnections) do
            pcall(function() c:Disconnect() end)
        end
        table.clear(mm2EspConnections)
        for player, _ in pairs(mm2EspData) do
            clearEspFor(player)
        end
        table.clear(mm2EspData)
    end

    local function findCoins()
        local coins = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local lname = string.lower(obj.Name)
                if string.find(lname, "coin", 1, true) and not string.find(lname, "spawn", 1, true) then
                    table.insert(coins, obj)
                end
            end
        end
        return coins
    end

    local MM2_COIN_LIMIT = 40

    local function startAutoCoin()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then mm2OriginalPos = hrp.CFrame end

        task.spawn(function()
            local collected = 0
            local coinCache = findCoins()

            while mm2AutoCoinEnabled do
                local c = LocalPlayer.Character
                local h = c and c:FindFirstChild("HumanoidRootPart")
                if not h then
                    task.wait(0.3)
                else
                    local closest, closestDist, closestIndex = nil, math.huge, nil
                    for i, coin in ipairs(coinCache) do
                        if coin and coin.Parent then
                            local d = (coin.Position - h.Position).Magnitude
                            if d < closestDist then
                                closest = coin
                                closestDist = d
                                closestIndex = i
                            end
                        end
                    end

                    if not closest then
                        coinCache = findCoins()
                        if #coinCache == 0 then
                            task.wait(0.4)
                        end
                    else
                        pcall(function()
                            h.CFrame = CFrame.new(closest.Position + Vector3.new(0, 2, 0))
                            h.AssemblyLinearVelocity = Vector3.zero
                        end)

                        local waited = 0
                        while closest.Parent and waited < 0.7 and mm2AutoCoinEnabled do
                            task.wait(0.05)
                            waited = waited + 0.05
                        end

                        if not closest.Parent then
                            collected = collected + 1
                            table.remove(coinCache, closestIndex)
                        else
                            table.remove(coinCache, closestIndex)
                        end

                        if collected >= MM2_COIN_LIMIT then
                            mm2AutoCoinEnabled = false
                            local hh = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            if hh and mm2OriginalPos then
                                pcall(function()
                                    hh.CFrame = mm2OriginalPos
                                    hh.AssemblyLinearVelocity = Vector3.zero
                                end)
                            end
                            mm2OriginalPos = nil
                            Rayfield:Notify({
                                Title = "Bag Full",
                                Content = "Collected " .. MM2_COIN_LIMIT .. " coins (bag limit reached). Returned to start.",
                                Duration = 6,
                                Image = "check-circle",
                            })
                            break
                        end
                    end
                end
            end
        end)
    end

    local function stopAutoCoin()
        if mm2OriginalPos then
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            if h then
                pcall(function()
                    h.CFrame = mm2OriginalPos
                    h.AssemblyLinearVelocity = Vector3.zero
                end)
            end
            mm2OriginalPos = nil
        end
    end

    local function findDroppedWeapons()
        local weapons = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("Model") then
                local lname = string.lower(obj.Name)
                local isGun = string.find(lname, "gun", 1, true) or string.find(lname, "revolver", 1, true)
                local isKnife = string.find(lname, "knife", 1, true)
                if isGun or isKnife then
                    local inPlayer = false
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p.Character and obj:IsDescendantOf(p.Character) then
                            inPlayer = true
                            break
                        end
                    end
                    if not inPlayer then
                        table.insert(weapons, {obj = obj, isKnife = isKnife})
                    end
                end
            end
        end
        return weapons
    end

    local function clearWeaponEsp()
        for obj, data in pairs(mm2WeaponEspData) do
            if data.hl then pcall(function() data.hl:Destroy() end) end
            if data.bb then pcall(function() data.bb:Destroy() end) end
        end
        table.clear(mm2WeaponEspData)
    end

    local function startWeaponEsp()
        if mm2WeaponLoopActive then return end
        mm2WeaponLoopActive = true
        task.spawn(function()
            while mm2WeaponEspEnabled do
                local weapons = findDroppedWeapons()
                local current = {}
                for _, entry in ipairs(weapons) do
                    local w = entry.obj
                    current[w] = true
                    if not mm2WeaponEspData[w] then
                        local adornee = w:IsA("Model") and (w.PrimaryPart or w:FindFirstChildWhichIsA("BasePart")) or w
                        if adornee then
                            local hl = Instance.new("Highlight")
                            hl.FillColor = entry.isKnife and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(60, 130, 255)
                            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                            hl.FillTransparency = 0.25
                            hl.Parent = w

                            local bb = Instance.new("BillboardGui")
                            bb.Size = UDim2.new(0, 110, 0, 28)
                            bb.StudsOffset = Vector3.new(0, 2.5, 0)
                            bb.AlwaysOnTop = true
                            bb.Adornee = adornee
                            local lbl = Instance.new("TextLabel")
                            lbl.Size = UDim2.new(1, 0, 1, 0)
                            lbl.BackgroundTransparency = 1
                            lbl.Text = entry.isKnife and "KNIFE DROP" or "GUN DROP"
                            lbl.TextColor3 = entry.isKnife and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(90, 160, 255)
                            lbl.Font = Enum.Font.GothamBold
                            lbl.TextSize = 14
                            lbl.TextStrokeTransparency = 0
                            lbl.Parent = bb
                            bb.Parent = w

                            mm2WeaponEspData[w] = {hl = hl, bb = bb}
                        end
                    end
                end
                for obj, data in pairs(mm2WeaponEspData) do
                    if not current[obj] or not obj.Parent then
                        if data.hl then pcall(function() data.hl:Destroy() end) end
                        if data.bb then pcall(function() data.bb:Destroy() end) end
                        mm2WeaponEspData[obj] = nil
                    end
                end
                task.wait(0.4)
            end
            mm2WeaponLoopActive = false
            clearWeaponEsp()
        end)
    end

    local function startDeathAlerts()
        if mm2DeathLoopActive then return end
        mm2DeathLoopActive = true
        task.spawn(function()
            while mm2DeathAlertEnabled do
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        local role = getPlayerRole(player)
                        if role ~= "Innocent" then
                            local char = player.Character
                            local hum = char and char:FindFirstChildOfClass("Humanoid")
                            if hum then
                                local tracked = mm2TrackedRoles[player]
                                if not tracked or tracked.role ~= role or tracked.hum ~= hum then
                                    if tracked and tracked.conn then
                                        pcall(function() tracked.conn:Disconnect() end)
                                    end
                                    local capturedRole = role
                                    local capturedName = player.Name
                                    local conn = hum.Died:Connect(function()
                                        if mm2DeathAlertEnabled then
                                            Rayfield:Notify({
                                                Title = capturedRole .. " DIED!",
                                                Content = capturedName .. " (" .. capturedRole .. ") was eliminated. Check the dropped weapon!",
                                                Duration = 7,
                                                Image = capturedRole == "Murderer" and "shield-check" or "alert-triangle",
                                            })
                                        end
                                    end)
                                    mm2TrackedRoles[player] = {role = role, hum = hum, conn = conn}
                                end
                            end
                        end
                    end
                end
                task.wait(1)
            end
            mm2DeathLoopActive = false
            for player, tracked in pairs(mm2TrackedRoles) do
                if tracked.conn then pcall(function() tracked.conn:Disconnect() end) end
            end
            table.clear(mm2TrackedRoles)
        end)
    end

    Mm2Tab:CreateSection("Role ESP")

    Mm2Tab:CreateToggle({
        Name = "Role ESP (Murderer / Sheriff / Innocent)",
        CurrentValue = false,
        Callback = function(Value)
            mm2EspEnabled = Value
            if Value then
                startMm2Esp()
                Rayfield:Notify({
                    Title = "MM2 ESP ON",
                    Content = "Red = Murderer | Blue = Sheriff | Gray = Innocent",
                    Duration = 5,
                    Image = "eye",
                })
            else
                stopMm2Esp()
            end
        end,
    })

    Mm2Tab:CreateButton({
        Name = "Identify Murderer Now",
        Callback = function()
            local murderer = nil
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and getPlayerRole(p) == "Murderer" then
                    murderer = p
                    break
                end
            end
            if murderer then
                Rayfield:Notify({
                    Title = "Murderer Found",
                    Content = murderer.Name .. " has the knife!",
                    Duration = 6,
                    Image = "alert-triangle",
                })
            else
                Rayfield:Notify({
                    Title = "No Murderer",
                    Content = "Knife not in any player's inventory right now.",
                    Duration = 4,
                    Image = "info",
                })
            end
        end,
    })

    Mm2Tab:CreateButton({
        Name = "Identify Sheriff Now",
        Callback = function()
            local sheriff = nil
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and getPlayerRole(p) == "Sheriff" then
                    sheriff = p
                    break
                end
            end
            if sheriff then
                Rayfield:Notify({
                    Title = "Sheriff Found",
                    Content = sheriff.Name .. " has the gun!",
                    Duration = 6,
                    Image = "shield",
                })
            else
                Rayfield:Notify({
                    Title = "No Sheriff",
                    Content = "Gun not in any player's inventory right now.",
                    Duration = 4,
                    Image = "info",
                })
            end
        end,
    })

    Mm2Tab:CreateToggle({
        Name = "Dropped Weapon ESP (Gun / Knife)",
        CurrentValue = false,
        Callback = function(Value)
            mm2WeaponEspEnabled = Value
            if Value then
                startWeaponEsp()
                Rayfield:Notify({
                    Title = "Weapon ESP ON",
                    Content = "Dropped gun (blue) and knife (red) are now highlighted.",
                    Duration = 5,
                    Image = "crosshair",
                })
            else
                clearWeaponEsp()
            end
        end,
    })

    Mm2Tab:CreateToggle({
        Name = "Role Death Alerts (Sheriff / Murderer)",
        CurrentValue = false,
        Callback = function(Value)
            mm2DeathAlertEnabled = Value
            if Value then
                startDeathAlerts()
                Rayfield:Notify({
                    Title = "Death Alerts ON",
                    Content = "You'll be notified when the Sheriff or Murderer dies.",
                    Duration = 5,
                    Image = "bell",
                })
            end
        end,
    })

    Mm2Tab:CreateSection("Auto Farm")

    Mm2Tab:CreateToggle({
        Name = "Auto Collect Coins",
        CurrentValue = false,
        Callback = function(Value)
            mm2AutoCoinEnabled = Value
            if Value then
                startAutoCoin()
                Rayfield:Notify({
                    Title = "Auto Coin ON",
                    Content = "Teleporting to closest coins. Toggle off to return.",
                    Duration = 4,
                    Image = "coins",
                })
            else
                stopAutoCoin()
            end
        end,
    })

    Mm2Tab:CreateButton({
        Name = "Show Coin Count",
        Callback = function()
            local count = #findCoins()
            Rayfield:Notify({
                Title = "Coins in Map",
                Content = count .. " coin(s) currently active.",
                Duration = 4,
                Image = "coins",
            })
        end,
    })
end

if SkeTab then
    local skeFarmEnabled = false
    local skeWalkDir = nil
    local skeFlip = false
    local skeFlipTimer = 0

    local function skeFindParts(keywords)
        local found = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local lname = string.lower(obj.Name)
                for _, kw in ipairs(keywords) do
                    if string.find(lname, kw, 1, true) then
                        table.insert(found, obj)
                        break
                    end
                end
            end
        end
        return found
    end

    local function skeTeleportTo(keywords, label)
        local targets = skeFindParts(keywords)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if #targets == 0 then
            Rayfield:Notify({
                Title = "Not Found",
                Content = "No '" .. label .. "' object found. Use 'Scan Stage Objects' to see real names.",
                Duration = 6,
                Image = "alert-triangle",
            })
            return
        end
        local farthest, farDist = nil, -1
        for _, t in ipairs(targets) do
            local d = (t.Position - hrp.Position).Magnitude
            if d > farDist then
                farthest = t
                farDist = d
            end
        end
        if farthest then
            local rot = hrp.CFrame - hrp.CFrame.Position
            hrp.CFrame = CFrame.new(farthest.Position + Vector3.new(0, 4, 0)) * rot
            hrp.AssemblyLinearVelocity = Vector3.zero
            Rayfield:Notify({
                Title = "Teleported",
                Content = "Moved to '" .. farthest.Name .. "'.",
                Duration = 4,
                Image = "check-circle",
            })
        end
    end

    SkeTab:CreateSection("Speed Farm")

    SkeTab:CreateToggle({
        Name = "Auto Step Farm (Walks Back & Forth)",
        CurrentValue = false,
        Callback = function(Value)
            skeFarmEnabled = Value
            if Value then
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local look = hrp.CFrame.LookVector
                    skeWalkDir = Vector3.new(look.X, 0, look.Z)
                    if skeWalkDir.Magnitude > 0.001 then
                        skeWalkDir = skeWalkDir.Unit
                    else
                        skeWalkDir = Vector3.new(1, 0, 0)
                    end
                end
                skeFlip = false
                skeFlipTimer = 0

                pcall(function()
                    RunService:UnbindFromRenderStep("SkeStepFarm")
                end)
                pcall(function()
                    RunService:BindToRenderStep("SkeStepFarm", Enum.RenderPriority.Character.Value + 1, function(dt)
                        if not skeFarmEnabled then return end
                        local c = LocalPlayer.Character
                        local hum = c and c:FindFirstChildOfClass("Humanoid")
                        if not hum or hum.Health <= 0 or not skeWalkDir then return end

                        skeFlipTimer = skeFlipTimer + dt
                        if skeFlipTimer >= 0.7 then
                            skeFlipTimer = 0
                            skeFlip = not skeFlip
                        end

                        local dir = skeFlip and (skeWalkDir * -1) or skeWalkDir
                        pcall(function()
                            hum:Move(dir, false)
                        end)
                    end)
                end)

                Rayfield:Notify({
                    Title = "Auto Step Farm ON",
                    Content = "Walking back and forth to rack up steps. Stand on a key row first.",
                    Duration = 5,
                    Image = "zap",
                })
            else
                pcall(function()
                    RunService:UnbindFromRenderStep("SkeStepFarm")
                end)
                local c = LocalPlayer.Character
                local hum = c and c:FindFirstChildOfClass("Humanoid")
                if hum then
                    pcall(function() hum:Move(Vector3.zero, false) end)
                end
            end
        end,
    })

    SkeTab:CreateSection("Teleports")

    SkeTab:CreateButton({
        Name = "Teleport to Finish / End",
        Callback = function()
            skeTeleportTo({"finish", "end", "goal", "win", "exit"}, "finish")
        end,
    })

    SkeTab:CreateButton({
        Name = "Teleport to Trophy",
        Callback = function()
            skeTeleportTo({"trophy", "reward", "chest", "crown"}, "trophy")
        end,
    })

    SkeTab:CreateButton({
        Name = "Teleport to Checkpoint",
        Callback = function()
            skeTeleportTo({"checkpoint", "stage", "flag", "spawn"}, "checkpoint")
        end,
    })

    SkeTab:CreateButton({
        Name = "Stand on Treadmill",
        Callback = function()
            skeTeleportTo({"treadmill", "tread", "conveyor", "belt"}, "treadmill")
        end,
    })

    SkeTab:CreateSection("Diagnostics")

    SkeTab:CreateButton({
        Name = "Scan Stage Objects (Find Real Names)",
        Callback = function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local seen = {}
            local list = {}
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if (obj:IsA("BasePart") or obj:IsA("Model")) then
                    local d = (obj:IsA("BasePart") and (obj.Position - hrp.Position).Magnitude) or 0
                    local lname = string.lower(obj.Name)
                    local interesting = string.find(lname, "win", 1, true) or string.find(lname, "trophy", 1, true)
                        or string.find(lname, "finish", 1, true) or string.find(lname, "check", 1, true)
                        or string.find(lname, "stage", 1, true) or string.find(lname, "tread", 1, true)
                        or string.find(lname, "goal", 1, true) or string.find(lname, "end", 1, true)
                    if interesting and not seen[obj.Name] then
                        seen[obj.Name] = true
                        table.insert(list, obj.Name)
                    end
                end
            end
            local content
            if #list == 0 then
                content = "No obvious named targets found. Tell me a target's exact name from the dev console and I'll map it."
            else
                content = "Found: " .. table.concat(list, ", ")
            end
            Rayfield:Notify({
                Title = "Stage Objects",
                Content = content,
                Duration = 10,
                Image = "search",
            })
        end,
    })
end

if KlbTab then
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local klbAutoKick = false
    local klbAutoIncome = false
    local klbAutoRebirth = false
    local klbAutoFree = false
    local klbAutoBonus = false

    local function fireRemote(name, ...)
        local args = {...}
        local r = ReplicatedStorage:FindFirstChild(name, true)
        if r then
            if r:IsA("RemoteEvent") then
                pcall(function() r:FireServer(table.unpack(args)) end)
                return true
            elseif r:IsA("RemoteFunction") then
                pcall(function() r:InvokeServer(table.unpack(args)) end)
                return true
            end
        end
        return false
    end

    local function klbGetBasePart()
        local plots = Workspace:FindFirstChild("Plots")
        if not plots then return nil end
        local mine = nil
        for _, plot in ipairs(plots:GetChildren()) do
            local attrOwner = plot:GetAttribute("Owner") or plot:GetAttribute("OwnerName") or plot:GetAttribute("Player")
            if attrOwner and tostring(attrOwner) == LocalPlayer.Name then mine = plot break end
            local ov = plot:FindFirstChild("Owner", true) or plot:FindFirstChild("Player", true)
            if ov and ((ov:IsA("ObjectValue") and ov.Value == LocalPlayer) or (ov:IsA("StringValue") and ov.Value == LocalPlayer.Name)) then
                mine = plot break
            end
            for _, d in ipairs(plot:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text and string.find(d.Text, LocalPlayer.Name, 1, true) then
                    mine = plot break
                end
            end
            if mine then break end
        end
        if not mine then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local best, bd = nil, math.huge
                for _, plot in ipairs(plots:GetChildren()) do
                    local ok, pivot = pcall(function() return plot:GetPivot().Position end)
                    if ok then
                        local d = (pivot - hrp.Position).Magnitude
                        if d < bd then best, bd = plot, d end
                    end
                end
                mine = best
            end
        end
        if not mine then return nil end
        local spawn = mine:FindFirstChild("Spawn", true) or mine:FindFirstChild("Pad", true)
            or mine:FindFirstChild("SpawnLocation", true) or mine:FindFirstChild("Base", true)
        if spawn and spawn:IsA("BasePart") then return spawn end
        if mine:IsA("Model") and mine.PrimaryPart then return mine.PrimaryPart end
        return mine:FindFirstChildWhichIsA("BasePart", true)
    end

    local function klbTeleportToBase()
        local base = klbGetBasePart()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        if not base then
            return false
        end
        local rot = hrp.CFrame - hrp.CFrame.Position
        hrp.CFrame = CFrame.new(base.Position + Vector3.new(0, 4, 0)) * rot
        hrp.AssemblyLinearVelocity = Vector3.zero
        return true
    end

    local function klbTeleportToBlock()
        local block = Workspace:FindFirstChild("BlockPart", true)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or not block then return false end
        local bpos = (block:IsA("BasePart") and block.Position) or (block:IsA("Model") and block:GetPivot().Position)
        if not bpos then return false end
        local rot = hrp.CFrame - hrp.CFrame.Position
        hrp.CFrame = CFrame.new(bpos + Vector3.new(0, 4, 0)) * rot
        hrp.AssemblyLinearVelocity = Vector3.zero
        return true
    end

    KlbTab:CreateSection("Movement")

    KlbTab:CreateButton({
        Name = "Teleport to My Base / Safe Zone",
        Callback = function()
            local ok = klbTeleportToBase()
            Rayfield:Notify({
                Title = ok and "Teleported" or "Base Not Found",
                Content = ok and "Moved to your safe zone." or "Couldn't find your plot. Tell me a Plots child name and I'll map it.",
                Duration = 5,
                Image = ok and "check-circle" or "alert-triangle",
            })
        end,
    })

    KlbTab:CreateButton({
        Name = "Teleport to Lucky Block (Kick Zone)",
        Callback = function()
            local ok = klbTeleportToBlock()
            Rayfield:Notify({
                Title = ok and "Teleported" or "Block Not Found",
                Content = ok and "Moved to the kick block." or "BlockPart not found right now.",
                Duration = 4,
                Image = ok and "check-circle" or "alert-triangle",
            })
        end,
    })

    KlbTab:CreateSection("Auto Farm")

    KlbTab:CreateToggle({
        Name = "Auto Kick + Collect + Return",
        CurrentValue = false,
        Callback = function(Value)
            klbAutoKick = Value
            if Value then
                task.spawn(function()
                    while klbAutoKick do
                        klbTeleportToBlock()
                        task.wait(0.15)
                        fireRemote("rev_ForceKickBar")
                        task.wait(0.05)
                        clickGuiButton(guiButton("HUD", "KickButton"))
                        task.wait(0.1)
                        fireRemote("rev_KickEvent")
                        task.wait(0.1)
                        fireRemote("rev_KickCollect")
                        fireRemote("rev_Collected")
                        task.wait(0.2)
                        klbTeleportToBase()
                        task.wait(0.15)
                        fireRemote("rev_B_Collect")
                        task.wait(0.45)
                    end
                end)
                Rayfield:Notify({
                    Title = "Auto Kick ON",
                    Content = "Perfect bar > kick button > collect > return to base loop.",
                    Duration = 5,
                    Image = "zap",
                })
            end
        end,
    })

    KlbTab:CreateToggle({
        Name = "Auto Weight Bonus (Purple 2x)",
        CurrentValue = false,
        Callback = function(Value)
            klbAutoBonus = Value
            if Value then
                task.spawn(function()
                    while klbAutoBonus do
                        fireRemote("rev_WeightBonus")
                        task.wait(0.4)
                    end
                end)
                Rayfield:Notify({
                    Title = "Weight Bonus ON",
                    Content = "Auto-firing the 2x training bonus.",
                    Duration = 4,
                    Image = "trending-up",
                })
            end
        end,
    })

    KlbTab:CreateToggle({
        Name = "Auto Collect Income (Base Money)",
        CurrentValue = false,
        Callback = function(Value)
            klbAutoIncome = Value
            if Value then
                task.spawn(function()
                    while klbAutoIncome do
                        fireRemote("rev_B_Collect")
                        fireRemote("rev_Collected")
                        task.wait(2)
                    end
                end)
                Rayfield:Notify({
                    Title = "Auto Income ON",
                    Content = "Collecting base income every 2s.",
                    Duration = 4,
                    Image = "dollar-sign",
                })
            end
        end,
    })

    KlbTab:CreateToggle({
        Name = "Auto Claim Free / Offline Rewards",
        CurrentValue = false,
        Callback = function(Value)
            klbAutoFree = Value
            if Value then
                task.spawn(function()
                    while klbAutoFree do
                        fireRemote("rev_ClaimFree")
                        fireRemote("rev_Offline_Claim")
                        task.wait(10)
                    end
                end)
                Rayfield:Notify({
                    Title = "Auto Claim ON",
                    Content = "Claiming free and offline rewards periodically.",
                    Duration = 4,
                    Image = "gift",
                })
            end
        end,
    })

    KlbTab:CreateSection("Rebirth & Upgrades")

    KlbTab:CreateButton({
        Name = "Rebirth Now",
        Callback = function()
            local clicked = clickGuiButton(guiButton("Frames", "Rebirth", "Rebirth"))
            fireRemote("rev_RebirthRequest")
            Rayfield:Notify({
                Title = "Rebirth Sent",
                Content = clicked and "Clicked rebirth button." or "Fired rebirth remote (open the Rebirth frame if it fails).",
                Duration = 4,
                Image = "rotate-ccw",
            })
        end,
    })

    KlbTab:CreateToggle({
        Name = "Auto Rebirth",
        CurrentValue = false,
        Callback = function(Value)
            klbAutoRebirth = Value
            if Value then
                task.spawn(function()
                    while klbAutoRebirth do
                        clickGuiButton(guiButton("Frames", "Rebirth", "Rebirth"))
                        fireRemote("rev_RebirthRequest")
                        task.wait(3)
                    end
                end)
                Rayfield:Notify({ Title = "Auto Rebirth ON", Content = "Triggering rebirth every 3s when you qualify.", Duration = 5, Image = "rotate-ccw" })
            end
        end,
    })

    KlbTab:CreateButton({
        Name = "Buy Speed  x1",
        Callback = function()
            local ok = clickGuiButton(guiButton("Frames", "SpeedUpgrades", "ScrollingFrame", "+1 Speed", "ButtonsFrame", "One"))
            Rayfield:Notify({ Title = ok and "Speed x1" or "Open Speed Menu", Content = ok and "Bought single speed." or "Open the Speed Upgrades menu once first.", Duration = 3, Image = ok and "check-circle" or "alert-triangle" })
        end,
    })

    KlbTab:CreateButton({
        Name = "Buy Speed  x3 (Triple)",
        Callback = function()
            local ok = clickGuiButton(guiButton("Frames", "SpeedUpgrades", "ScrollingFrame", "+1 Speed", "ButtonsFrame", "Two"))
            Rayfield:Notify({ Title = ok and "Speed x3" or "Open Speed Menu", Content = ok and "Bought triple speed." or "Open the Speed Upgrades menu once first.", Duration = 3, Image = ok and "check-circle" or "alert-triangle" })
        end,
    })

    KlbTab:CreateButton({
        Name = "Buy Speed  x10",
        Callback = function()
            local ok = clickGuiButton(guiButton("Frames", "SpeedUpgrades", "ScrollingFrame", "+1 Speed", "ButtonsFrame", "Three"))
            Rayfield:Notify({ Title = ok and "Speed x10" or "Open Speed Menu", Content = ok and "Bought x10 speed." or "Open the Speed Upgrades menu once first.", Duration = 3, Image = ok and "check-circle" or "alert-triangle" })
        end,
    })

    KlbTab:CreateButton({
        Name = "Buy Kick Power  +1",
        Callback = function()
            local ok = clickGuiButton(guiButton("Frames", "KickUpgrades", "ScrollingFrame", "+1 Kick", "Button"))
            Rayfield:Notify({ Title = ok and "Kick +1" or "Open Kick Menu", Content = ok and "Bought +1 kick power." or "Open the Kick Upgrades menu once first.", Duration = 3, Image = ok and "check-circle" or "alert-triangle" })
        end,
    })

    KlbTab:CreateButton({
        Name = "Buy Kick Power  +5",
        Callback = function()
            local ok = clickGuiButton(guiButton("Frames", "KickUpgrades", "ScrollingFrame", "+5 Kick", "Button"))
            Rayfield:Notify({ Title = ok and "Kick +5" or "Open Kick Menu", Content = ok and "Bought +5 kick power." or "Open the Kick Upgrades menu once first.", Duration = 3, Image = ok and "check-circle" or "alert-triangle" })
        end,
    })

    KlbTab:CreateButton({
        Name = "Buy Kick Power  +10",
        Callback = function()
            local ok = clickGuiButton(guiButton("Frames", "KickUpgrades", "ScrollingFrame", "+10 Kick", "Button"))
            Rayfield:Notify({ Title = ok and "Kick +10" or "Open Kick Menu", Content = ok and "Bought +10 kick power." or "Open the Kick Upgrades menu once first.", Duration = 3, Image = ok and "check-circle" or "alert-triangle" })
        end,
    })

    KlbTab:CreateButton({
        Name = "Buy All Affordable Weights",
        Callback = function()
            local sf = guiButton("Frames", "WeightUI", "ScrollingFrame")
            local count = 0
            if sf then
                for _, child in ipairs(sf:GetChildren()) do
                    local btns = child:FindFirstChild("Buttons")
                    local interact = btns and btns:FindFirstChild("InteractButton")
                    if interact then
                        if clickGuiButton(interact) then count = count + 1 end
                        task.wait(0.05)
                    end
                end
            end
            Rayfield:Notify({ Title = "Weights", Content = (count > 0) and ("Tried buying " .. count .. " weights.") or "Open the Weight menu once first.", Duration = 4, Image = count > 0 and "check-circle" or "alert-triangle" })
        end,
    })

    KlbTab:CreateButton({
        Name = "Upgrade Brainrots",
        Callback = function()
            local ok = fireRemote("rev_B_Upgrade")
            Rayfield:Notify({
                Title = ok and "Brainrot Upgrade Sent" or "Remote Missing",
                Content = ok and "Requested a brainrot upgrade." or "rev_B_Upgrade not found.",
                Duration = 4,
                Image = ok and "check-circle" or "x-circle",
            })
        end,
    })

    KlbTab:CreateSection("Diagnostics (Read First)")

    KlbTab:CreateButton({
        Name = "Scan Remotes (Copy to Clipboard)",
        Callback = function()
            local names = {}
            local seen = {}
            local function scan(container)
                for _, obj in ipairs(container:GetDescendants()) do
                    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                        if not seen[obj:GetFullName()] then
                            seen[obj:GetFullName()] = true
                            table.insert(names, obj.ClassName .. "  " .. obj:GetFullName())
                        end
                    end
                end
            end
            pcall(function() scan(ReplicatedStorage) end)
            local full = "=== REMOTES (" .. #names .. ") ===\n" .. table.concat(names, "\n")
            print(full)
            local copied = copyToClipboard(full)
            Rayfield:Notify({
                Title = "Remotes: " .. #names,
                Content = copied and "Copied to clipboard. Paste it to me." or "Clipboard unsupported - read console.",
                Duration = 8,
                Image = "radio",
            })
        end,
    })

    KlbTab:CreateButton({
        Name = "Scan My Plot (Copy to Clipboard)",
        Callback = function()
            local plots = Workspace:FindFirstChild("Plots")
            if not plots then
                Rayfield:Notify({ Title = "No Plots Folder", Content = "Workspace has no 'Plots'. Tell me what holds the bases.", Duration = 6, Image = "alert-triangle" })
                return
            end
            local lines = {"=== PLOTS (" .. #plots:GetChildren() .. ") ===", "My name: " .. LocalPlayer.Name}
            for _, plot in ipairs(plots:GetChildren()) do
                local info = "[" .. plot.Name .. "] (" .. plot.ClassName .. ")"
                for _, v in ipairs(plot:GetDescendants()) do
                    if v:IsA("StringValue") or v:IsA("ObjectValue") or v:IsA("IntValue") or v:IsA("BoolValue") then
                        local val = (v:IsA("ObjectValue") and v.Value and v.Value.Name) or tostring(v.Value)
                        info = info .. "\n    " .. v.Name .. " = " .. tostring(val)
                    end
                end
                table.insert(lines, info)
            end
            local full = table.concat(lines, "\n")
            print(full)
            local copied = copyToClipboard(full)
            Rayfield:Notify({
                Title = "Plots: " .. #plots:GetChildren(),
                Content = copied and "Copied to clipboard. Paste it to me." or "Clipboard unsupported - read console.",
                Duration = 8,
                Image = "search",
            })
        end,
    })

    KlbTab:CreateButton({
        Name = "Scan On-Screen Buttons (Copy to Clipboard)",
        Callback = function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if not pg then return end
            local found = {}
            for _, obj in ipairs(pg:GetDescendants()) do
                if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                    if obj.Visible then
                        local txt = (obj:IsA("TextButton") and obj.Text ~= "" and ("  TEXT='" .. obj.Text .. "'")) or ""
                        table.insert(found, obj:GetFullName() .. txt)
                    end
                end
            end
            local full = "=== VISIBLE BUTTONS (" .. #found .. ") ===\n" .. table.concat(found, "\n")
            print(full)
            local copied = copyToClipboard(full)
            Rayfield:Notify({
                Title = "Buttons: " .. #found,
                Content = copied and "Copied to clipboard. Paste it to me (look for the 2x button)." or "Clipboard unsupported - read console.",
                Duration = 8,
                Image = "mouse-pointer",
            })
        end,
    })

    KlbTab:CreateButton({
        Name = "Scan Shop Items (Copy to Clipboard)",
        Callback = function()
            local out = {}
            local function dump(folderName)
                local f = Workspace:FindFirstChild(folderName)
                if f then
                    for _, c in ipairs(f:GetDescendants()) do
                        if c:IsA("Model") or c:IsA("ProximityPrompt") then
                            local extra = ""
                            if c:IsA("ProximityPrompt") then
                                extra = "  ACTION='" .. tostring(c.ActionText) .. "' OBJ='" .. tostring(c.ObjectText) .. "'"
                            end
                            table.insert(out, c.ClassName .. "  " .. c:GetFullName() .. extra)
                        end
                    end
                end
            end
            dump("Shops")
            dump("VolcanicShop")
            local full = "=== SHOP ITEMS (" .. #out .. ") ===\n" .. table.concat(out, "\n")
            print(full)
            local copied = copyToClipboard(full)
            Rayfield:Notify({
                Title = "Shop: " .. #out,
                Content = copied and "Copied to clipboard. Paste it to me." or "Clipboard unsupported - read console.",
                Duration = 8,
                Image = "shopping-cart",
            })
        end,
    })
end

if GagTab then
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local gagAutoHarvest = false
    local gagAutoSell = false
    local gagAutoGrow = false
    local gagSelectedSeed = "Carrot"

    local gagV1Ids = { [124977557560410] = true, [126884695634066] = true }
    local gagV2Ids = { [77085202503540] = true, [97598239454123] = true }
    local gagVersion
    if gagV1Ids[game.PlaceId] then
        gagVersion = 1
    elseif gagV2Ids[game.PlaceId] then
        gagVersion = 2
    elseif ReplicatedStorage:FindFirstChild("GameEvents") then
        gagVersion = 1
    else
        gagVersion = 2
    end

    local function gagFire(name, ...)
        local args = {...}
        local r = ReplicatedStorage:FindFirstChild(name, true)
        if r then
            if r:IsA("RemoteEvent") then
                pcall(function() r:FireServer(table.unpack(args)) end)
                return true
            elseif r:IsA("RemoteFunction") then
                pcall(function() r:InvokeServer(table.unpack(args)) end)
                return true
            end
        end
        return false
    end

    local function gagCollectOwnCrops()
        local n = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                local action = string.lower(tostring(obj.ActionText))
                if string.find(action, "steal", 1, true) then
                    -- never auto-steal from other players
                else
                    if string.find(action, "collect", 1, true) or string.find(action, "harvest", 1, true)
                        or string.find(action, "pick", 1, true) or string.find(action, "gather", 1, true) then
                        if type(fireproximityprompt) == "function" then
                            pcall(fireproximityprompt, obj)
                            n = n + 1
                        end
                    end
                end
            end
        end
        gagFire("Collect")
        return n
    end

    local function gagGrowAll()
        local fired = gagFire("GrowAllToolActivated")
        local clicked = clickGuiButton(guiButton("GrowingList", "Frame", "Header", "GrowAll"))
        local gl = guiButton("GrowingList")
        if gl then
            pcall(function()
                if gl:IsA("ScreenGui") then gl.Enabled = false end
                local frame = gl:FindFirstChild("Frame")
                if frame then frame.Visible = false end
            end)
        end
        return fired or clicked
    end

    local function gagSellInventory()
        local a = gagFire("Sell_Inventory")
        local b = gagFire("SellFood_RE")
        local c = clickGuiButton(guiButton("TeleportButtons", "TeleportButtons", "SellButton"))
        return a or b or c
    end

    GagTab:CreateSection("Auto Farm (Your Own Garden)")

    GagTab:CreateLabel("Detected: Grow a Garden " .. tostring(gagVersion) .. (gagVersion == 1 and "  (named remotes)" or "  (Replica / GUI based)"))

    GagTab:CreateButton({
        Name = "Grow All (Instant)",
        Callback = function()
            local ok = gagGrowAll()
            Rayfield:Notify({ Title = ok and "Grow All" or "Not Found", Content = ok and "Triggered grow-all on your plants." or "Grow-all action not found here.", Duration = 4, Image = ok and "sprout" or "alert-triangle" })
        end,
    })

    GagTab:CreateToggle({
        Name = "Auto Grow All",
        CurrentValue = false,
        Callback = function(Value)
            gagAutoGrow = Value
            if Value then
                task.spawn(function()
                    while gagAutoGrow do
                        gagGrowAll()
                        task.wait(3)
                    end
                end)
                Rayfield:Notify({ Title = "Auto Grow All ON", Content = "Keeping your plants grown.", Duration = 4, Image = "sprout" })
            end
        end,
    })

    GagTab:CreateToggle({
        Name = "Auto Collect (Your Crops Only)",
        CurrentValue = false,
        Callback = function(Value)
            gagAutoHarvest = Value
            if Value then
                task.spawn(function()
                    while gagAutoHarvest do
                        gagCollectOwnCrops()
                        task.wait(0.5)
                    end
                end)
                Rayfield:Notify({ Title = "Auto Collect ON", Content = "Collecting your own ripe crops. Steal prompts are never touched.", Duration = 5, Image = "scissors" })
            end
        end,
    })

    GagTab:CreateToggle({
        Name = "Auto Sell Inventory",
        CurrentValue = false,
        Callback = function(Value)
            gagAutoSell = Value
            if Value then
                task.spawn(function()
                    while gagAutoSell do
                        gagSellInventory()
                        task.wait(5)
                    end
                end)
                Rayfield:Notify({ Title = "Auto Sell ON", Content = "Selling your harvested inventory every 5s.", Duration = 4, Image = "dollar-sign" })
            end
        end,
    })

    GagTab:CreateSection("Seed Shop")

    GagTab:CreateDropdown({
        Name = "Seed to Buy",
        Options = {"Carrot", "Strawberry", "Blueberry", "Tomato", "Corn", "Apple", "Bamboo", "Watermelon", "Pumpkin", "Pineapple", "Mushroom", "Cactus", "Banana", "Grape", "Coconut", "Mango", "Dragon Fruit", "Cherry", "Sunflower"},
        CurrentOption = {"Carrot"},
        Callback = function(opt)
            if type(opt) == "table" then gagSelectedSeed = opt[1] else gagSelectedSeed = opt end
        end,
    })

    GagTab:CreateButton({
        Name = "Buy Selected Seed",
        Callback = function()
            local ok = gagFire("BuySeedStock", gagSelectedSeed)
            Rayfield:Notify({ Title = ok and ("Bought: " .. tostring(gagSelectedSeed)) or "Not Found", Content = ok and "Sent buy request to the seed shop." or "BuySeedStock remote not found (this may be the Replica version - open the shop and use Auto Buy via prompts).", Duration = 5, Image = ok and "shopping-cart" or "alert-triangle" })
        end,
    })

    GagTab:CreateButton({
        Name = "Buy Selected Seed  x10",
        Callback = function()
            local any = false
            for i = 1, 10 do
                if gagFire("BuySeedStock", gagSelectedSeed) then any = true end
                task.wait(0.06)
            end
            Rayfield:Notify({ Title = any and ("Bought x10: " .. tostring(gagSelectedSeed)) or "Not Found", Content = any and "Sent 10 buy requests." or "BuySeedStock remote not found here.", Duration = 4, Image = any and "shopping-cart" or "alert-triangle" })
        end,
    })


    if gagVersion == 2 then
        GagTab:CreateSection("Night Watch (Notifications Only)")

        local gagNightAlerts = false
        GagTab:CreateToggle({
            Name = "Night Alerts (Protect / Steal Reminder)",
            CurrentValue = false,
            Callback = function(Value)
                gagNightAlerts = Value
                if Value then
                    task.spawn(function()
                        local Lighting = game:GetService("Lighting")
                        local lastIsNight = nil
                        while gagNightAlerts do
                            local clock = Lighting.ClockTime
                            local isNight = (clock >= 18 or clock < 6)
                            if lastIsNight == nil then
                                lastIsNight = isNight
                            elseif isNight ~= lastIsNight then
                                lastIsNight = isNight
                                if isNight then
                                    Rayfield:Notify({
                                        Title = "Night has fallen",
                                        Content = "Protect your garden - this is the time others can steal, and the steal phase is open.",
                                        Duration = 8,
                                        Image = "moon",
                                    })
                                else
                                    Rayfield:Notify({
                                        Title = "Daytime",
                                        Content = "Day is back. Your garden is safer now.",
                                        Duration = 6,
                                        Image = "sun",
                                    })
                                end
                            end
                            task.wait(2)
                        end
                    end)
                    Rayfield:Notify({
                        Title = "Night Alerts ON",
                        Content = "You'll get a heads-up when night and day begin. Notification only.",
                        Duration = 5,
                        Image = "bell",
                    })
                end
            end,
        })
    end

    GagTab:CreateSection("Diagnostics (Scan First, Paste to Me)")

    GagTab:CreateButton({
        Name = "Scan Remotes (Copy to Clipboard)",
        Callback = function()
            local names = {}
            local seen = {}
            for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    if not seen[obj:GetFullName()] then
                        seen[obj:GetFullName()] = true
                        table.insert(names, obj.ClassName .. "  " .. obj:GetFullName())
                    end
                end
            end
            local full = "=== GAG REMOTES (" .. #names .. ") ===\n" .. table.concat(names, "\n")
            print(full)
            local copied = copyToClipboard(full)
            Rayfield:Notify({ Title = "Remotes: " .. #names, Content = copied and "Copied to clipboard. Paste it to me." or "Clipboard unsupported - read console.", Duration = 8, Image = "radio" })
        end,
    })

    GagTab:CreateButton({
        Name = "Scan On-Screen Buttons (Copy to Clipboard)",
        Callback = function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if not pg then return end
            local found = {}
            for _, obj in ipairs(pg:GetDescendants()) do
                if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible then
                    local txt = (obj:IsA("TextButton") and obj.Text ~= "" and ("  TEXT='" .. obj.Text .. "'")) or ""
                    table.insert(found, obj:GetFullName() .. txt)
                end
            end
            local full = "=== GAG VISIBLE BUTTONS (" .. #found .. ") ===\n" .. table.concat(found, "\n")
            print(full)
            local copied = copyToClipboard(full)
            Rayfield:Notify({ Title = "Buttons: " .. #found, Content = copied and "Copied to clipboard. Paste it to me." or "Clipboard unsupported - read console.", Duration = 8, Image = "mouse-pointer" })
        end,
    })

    GagTab:CreateButton({
        Name = "Scan Garden + Prompts (Copy to Clipboard)",
        Callback = function()
            local lines = {"=== WORKSPACE TOP-LEVEL ==="}
            for _, c in ipairs(Workspace:GetChildren()) do
                table.insert(lines, c.ClassName .. "  " .. c.Name)
            end
            table.insert(lines, "")
            table.insert(lines, "=== PROXIMITY PROMPTS ===")
            local promptCount = 0
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    promptCount = promptCount + 1
                    table.insert(lines, obj:GetFullName() .. "  ACTION='" .. tostring(obj.ActionText) .. "' OBJ='" .. tostring(obj.ObjectText) .. "'")
                end
            end
            local full = table.concat(lines, "\n")
            print(full)
            local copied = copyToClipboard(full)
            Rayfield:Notify({ Title = "Garden Scan", Content = copied and ("Copied (" .. promptCount .. " prompts). Paste it to me.") or "Clipboard unsupported - read console.", Duration = 8, Image = "search" })
        end,
    })
end

do
    local placedBlocks = {}
    local blockShape = "Square"
    local blockSize = 14
    local blockColor = Color3.fromRGB(0, 170, 255)
    local followBlock = nil
    local followConn = nil
    local tpDistance = 50

    local function makeBlock(cf)
        local part
        if blockShape == "Round" then
            part = Instance.new("Part")
            part.Shape = Enum.PartType.Cylinder
            part.Size = Vector3.new(1, blockSize, blockSize)
            part.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
        elseif blockShape == "Triangle" then
            part = Instance.new("WedgePart")
            part.Size = Vector3.new(blockSize, blockSize * 0.6, blockSize)
            part.CFrame = cf
        else
            part = Instance.new("Part")
            part.Shape = Enum.PartType.Block
            part.Size = Vector3.new(blockSize, 1, blockSize)
            part.CFrame = cf
        end
        part.Anchored = true
        part.CanCollide = true
        part.Material = Enum.Material.Neon
        part.Color = blockColor
        part.Transparency = 0.25
        part:SetAttribute("NXBlock", true)
        part.Parent = Workspace
        return part
    end

    BlocksTab:CreateSection("Place (Client-Side Only)")

    BlocksTab:CreateDropdown({
        Name = "Block Shape",
        Options = { "Square", "Round", "Triangle" },
        CurrentOption = { "Square" },
        Callback = function(opt)
            if type(opt) == "table" then blockShape = opt[1] else blockShape = opt end
        end,
    })

    BlocksTab:CreateSlider({
        Name = "Block Size",
        Range = { 4, 60 },
        Increment = 1,
        Suffix = "studs",
        CurrentValue = 14,
        Callback = function(v) blockSize = v end,
    })

    BlocksTab:CreateColorPicker({
        Name = "Block Color",
        Color = Color3.fromRGB(0, 170, 255),
        Callback = function(c)
            blockColor = c
        end,
    })

    BlocksTab:CreateButton({
        Name = "Recolor All My Blocks",
        Callback = function()
            local n = 0
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj:GetAttribute("NXBlock") then
                    pcall(function() obj.Color = blockColor end)
                    n = n + 1
                end
            end
            Rayfield:Notify({ Title = "Recolored", Content = n .. " block(s) updated.", Duration = 3, Image = "palette" })
        end,
    })

    BlocksTab:CreateButton({
        Name = "Place Block Under Me",
        Callback = function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local b = makeBlock(CFrame.new(hrp.Position - Vector3.new(0, 3.5, 0)))
            table.insert(placedBlocks, b)
        end,
    })

    BlocksTab:CreateButton({
        Name = "Place Block In Front",
        Callback = function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local b = makeBlock(hrp.CFrame * CFrame.new(0, -1, -blockSize))
            table.insert(placedBlocks, b)
        end,
    })

    BlocksTab:CreateButton({
        Name = "Clear All My Blocks",
        Callback = function()
            local n = 0
            for _, b in ipairs(placedBlocks) do
                if b and b.Parent then b:Destroy() n = n + 1 end
            end
            placedBlocks = {}
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj:GetAttribute("NXBlock") then obj:Destroy() end
            end
            Rayfield:Notify({ Title = "Cleared", Content = n .. " block(s) removed.", Duration = 3, Image = "trash-2" })
        end,
    })

    BlocksTab:CreateSection("Remove Wall (Click to Pick - Local Only)")

    local hiddenWalls = {}
    local pickingWall = false

    BlocksTab:CreateButton({
        Name = "Pick a Wall to Hide",
        Callback = function()
            if pickingWall then return end
            pickingWall = true
            Rayfield:Notify({ Title = "Click a Wall", Content = "Tap/click the wall in front of you to hide it (only for you).", Duration = 6, Image = "mouse-pointer" })
            local UIS = game:GetService("UserInputService")
            local conn
            conn = UIS.InputBegan:Connect(function(input, processed)
                if processed then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    local cam = Workspace.CurrentCamera
                    local pos = UIS:GetMouseLocation()
                    local ray = cam:ViewportPointToRay(pos.X, pos.Y)
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    local char = LocalPlayer.Character
                    if char then params.FilterDescendantsInstances = { char } end
                    local result = Workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
                    if result and result.Instance and result.Instance:IsA("BasePart") then
                        local part = result.Instance
                        table.insert(hiddenWalls, {
                            part = part,
                            transparency = part.Transparency,
                            canCollide = part.CanCollide,
                        })
                        pcall(function()
                            part.Transparency = 1
                            part.CanCollide = false
                        end)
                        Rayfield:Notify({ Title = "Wall Hidden", Content = "'" .. part.Name .. "' is now see-through and walk-through for you only.", Duration = 5, Image = "eye-off" })
                    else
                        Rayfield:Notify({ Title = "Nothing Hit", Content = "No part under your click. Try again.", Duration = 4, Image = "alert-triangle" })
                    end
                    pickingWall = false
                    if conn then conn:Disconnect() end
                end
            end)
        end,
    })

    BlocksTab:CreateButton({
        Name = "Restore All Hidden Walls",
        Callback = function()
            local n = 0
            for _, w in ipairs(hiddenWalls) do
                if w.part and w.part.Parent then
                    pcall(function()
                        w.part.Transparency = w.transparency
                        w.part.CanCollide = w.canCollide
                    end)
                    n = n + 1
                end
            end
            hiddenWalls = {}
            Rayfield:Notify({ Title = "Restored", Content = n .. " wall(s) brought back.", Duration = 4, Image = "eye" })
        end,
    })

    BlocksTab:CreateSection("Follow Platform (Climb)")

    BlocksTab:CreateToggle({
        Name = "Follow Platform Under Me",
        CurrentValue = false,
        Callback = function(Value)
            if Value then
                followBlock = Instance.new("Part")
                followBlock.Anchored = true
                followBlock.CanCollide = true
                followBlock.Size = Vector3.new(blockSize, 1, blockSize)
                followBlock.Material = Enum.Material.Neon
                followBlock.Color = Color3.fromRGB(0, 255, 140)
                followBlock.Transparency = 0.3
                followBlock:SetAttribute("NXBlock", true)
                followBlock.Parent = Workspace
                followConn = game:GetService("RunService").Heartbeat:Connect(function()
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp and followBlock then
                        local half = followBlock.Size.Y / 2
                        local feetY = hrp.Position.Y - 3.0
                        local platTop = followBlock.Position.Y + half
                        local vy = hrp.AssemblyLinearVelocity.Y
                        local newCenterY = followBlock.Position.Y
                        if feetY > platTop + 1.2 then
                            if vy <= 0.2 then
                                newCenterY = (feetY - 0.3) - half
                            end
                        elseif feetY < platTop - 1.2 then
                            newCenterY = (feetY - 0.3) - half
                        end
                        followBlock.CFrame = CFrame.new(hrp.Position.X, newCenterY, hrp.Position.Z)
                    end
                end)
                Rayfield:Notify({ Title = "Follow Platform ON", Content = "Follows you horizontally and catches you - it won't creep you upward anymore.", Duration = 5, Image = "square" })
            else
                if followConn then followConn:Disconnect() followConn = nil end
                if followBlock then followBlock:Destroy() followBlock = nil end
            end
        end,
    })

    BlocksTab:CreateSection("Directional Teleport")

    BlocksTab:CreateInput({
        Name = "Teleport Distance",
        PlaceholderText = "50",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            local cleaned = (text or ""):gsub("%s+", "")
            local n = tonumber(cleaned)
            if n then tpDistance = n end
        end,
    })

    local function tpMove(getOffset)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        hrp.CFrame = hrp.CFrame + getOffset()
        hrp.AssemblyLinearVelocity = Vector3.zero
    end

    local function flatLook()
        local cam = Workspace.CurrentCamera
        local lv = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
        local flat = Vector3.new(lv.X, 0, lv.Z)
        if flat.Magnitude < 0.001 then return Vector3.new(0, 0, -1) end
        return flat.Unit
    end

    local function rightVec()
        local f = flatLook()
        return Vector3.new(f.Z, 0, -f.X)
    end

    BlocksTab:CreateButton({ Name = "Teleport Up", Callback = function() tpMove(function() return Vector3.new(0, tpDistance, 0) end) end })
    BlocksTab:CreateButton({ Name = "Teleport Down", Callback = function() tpMove(function() return Vector3.new(0, -tpDistance, 0) end) end })
    BlocksTab:CreateButton({ Name = "Teleport Forward", Callback = function() tpMove(function() return flatLook() * tpDistance end) end })
    BlocksTab:CreateButton({ Name = "Teleport Back", Callback = function() tpMove(function() return flatLook() * -tpDistance end) end })
    BlocksTab:CreateButton({ Name = "Teleport Right", Callback = function() tpMove(function() return rightVec() * tpDistance end) end })
    BlocksTab:CreateButton({ Name = "Teleport Left", Callback = function() tpMove(function() return rightVec() * -tpDistance end) end })
    BlocksTab:CreateButton({ Name = "Diagonal Forward-Right", Callback = function() tpMove(function() return (flatLook() + rightVec()).Unit * tpDistance end) end })
    BlocksTab:CreateButton({ Name = "Diagonal Forward-Left", Callback = function() tpMove(function() return (flatLook() - rightVec()).Unit * tpDistance end) end })
    BlocksTab:CreateButton({ Name = "Diagonal Back-Right", Callback = function() tpMove(function() return (-flatLook() + rightVec()).Unit * tpDistance end) end })
    BlocksTab:CreateButton({ Name = "Diagonal Back-Left", Callback = function() tpMove(function() return (-flatLook() - rightVec()).Unit * tpDistance end) end })
end

do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local bots = {}
    local botName = "Bot"
    local botCopyUser = ""
    local botFollow = false
    local botAttack = false
    local botFollowConn = nil
    local botAttackConn = nil

    local function clearDeadBots()
        for i = #bots, 1, -1 do
            if not bots[i] or not bots[i].Parent then
                table.remove(bots, i)
            end
        end
    end

    local function removeAllBots()
        botFollow = false
        botAttack = false
        if botFollowConn then pcall(function() botFollowConn:Disconnect() end) botFollowConn = nil end
        if botAttackConn then pcall(function() botAttackConn:Disconnect() end) botAttackConn = nil end
        for _, b in ipairs(bots) do
            if b then pcall(function() b:Destroy() end) end
        end
        bots = {}
    end

    local function giveSword(model)
        local hand = model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")
        if not hand then return end
        if model:FindFirstChild("NXSword") then return end
        local tool = Instance.new("Model")
        tool.Name = "NXSword"
        local handle = Instance.new("Part")
        handle.Name = "Blade"
        handle.Size = Vector3.new(0.4, 5, 0.4)
        handle.Color = Color3.fromRGB(200, 200, 210)
        handle.Material = Enum.Material.Metal
        handle.CanCollide = false
        handle.Massless = true
        handle.Parent = tool
        local guard = Instance.new("Part")
        guard.Name = "Guard"
        guard.Size = Vector3.new(1.6, 0.3, 0.3)
        guard.Color = Color3.fromRGB(120, 90, 40)
        guard.CanCollide = false
        guard.Massless = true
        guard.Parent = tool
        local weld = Instance.new("Weld")
        weld.Part0 = hand
        weld.Part1 = handle
        weld.C0 = CFrame.new(0, -2.5, 0) * CFrame.Angles(math.rad(90), 0, 0)
        weld.Parent = handle
        local gw = Instance.new("Weld")
        gw.Part0 = handle
        gw.Part1 = guard
        gw.C0 = CFrame.new(0, -2.2, 0)
        gw.Parent = guard
        tool.Parent = model
    end

    local swinging = false
    local function swingSword(model)
        if not model then return end
        local sword = model:FindFirstChild("NXSword")
        local blade = sword and sword:FindFirstChild("Blade")
        local weld = blade and blade:FindFirstChildOfClass("Weld")
        if not weld then return end
        if swinging then return end
        swinging = true
        local base = CFrame.new(0, -2.5, 0) * CFrame.Angles(math.rad(90), 0, 0)
        pcall(function()
            weld.C0 = CFrame.new(0, -2.5, 0) * CFrame.Angles(math.rad(-30), math.rad(-60), 0)
        end)
        task.delay(0.07, function()
            pcall(function()
                weld.C0 = CFrame.new(0, -2.5, 0) * CFrame.Angles(math.rad(120), math.rad(40), 0)
            end)
        end)
        task.delay(0.2, function()
            pcall(function() weld.C0 = base end)
            swinging = false
        end)
        local bhrp = model:FindFirstChild("HumanoidRootPart")
        local char = LocalPlayer.Character
        local myHrp = char and char:FindFirstChild("HumanoidRootPart")
        local myHum = char and char:FindFirstChildOfClass("Humanoid")
        if bhrp and myHrp and myHum then
            local dist = (bhrp.Position - myHrp.Position).Magnitude
            if dist < 8 then
                pcall(function() myHum:TakeDamage(3) end)
            end
        end
    end

    BotTab:CreateSection("Local Bots (Client-Side Only)")

    BotTab:CreateInput({
        Name = "Bot Name (overhead)",
        PlaceholderText = "Bot",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            botName = (text and text ~= "") and text or "Bot"
        end,
    })

    BotTab:CreateInput({
        Name = "Copy Username (empty = Noob)",
        PlaceholderText = "Roblox username",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            botCopyUser = text or ""
        end,
    })

    BotTab:CreateButton({
        Name = "Spawn Bot (adds another)",
        Callback = function()
            task.spawn(function()
                clearDeadBots()
                local desc = nil
                local uname = (botCopyUser or ""):gsub("%s+", "")
                if uname ~= "" then
                    local okId, uid = pcall(function() return Players:GetUserIdFromNameAsync(uname) end)
                    if okId and uid then
                        local okDesc, d = pcall(function() return Players:GetHumanoidDescriptionFromUserId(uid) end)
                        if okDesc then desc = d end
                    else
                        Rayfield:Notify({ Title = "User Not Found", Content = "Couldn't find that username. Spawning a Noob instead.", Duration = 5, Image = "alert-triangle" })
                    end
                end

                local model = nil
                if desc then
                    local okM, m = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15) end)
                    if okM then model = m end
                end
                if not model then
                    local okN, m = pcall(function() return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6) end)
                    if okN then model = m end
                end
                if not model then
                    Rayfield:Notify({ Title = "Spawn Failed", Content = "Couldn't create the bot model here.", Duration = 5, Image = "x-circle" })
                    return
                end

                local hum = model:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum.DisplayName = botName end) end
                model.Name = botName

                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local angle = math.rad(math.random(0, 360))
                    pcall(function() model:PivotTo(hrp.CFrame * CFrame.new(math.cos(angle) * 6, 0, math.sin(angle) * 6)) end)
                end
                model.Parent = Workspace
                table.insert(bots, model)
                Rayfield:Notify({ Title = "Bot Spawned (" .. #bots .. ")", Content = "Only you can see these bots.", Duration = 4, Image = "user-check" })
            end)
        end,
    })

    BotTab:CreateToggle({
        Name = "All Bots Follow Me",
        CurrentValue = false,
        Callback = function(Value)
            botFollow = Value
            if Value then
                if botFollowConn then pcall(function() botFollowConn:Disconnect() end) end
                botFollowConn = RunService.Heartbeat:Connect(function()
                    if not botFollow then return end
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    for _, b in ipairs(bots) do
                        if b and b.Parent then
                            local hum = b:FindFirstChildOfClass("Humanoid")
                            if hum then pcall(function() hum:MoveTo(hrp.Position) end) end
                        end
                    end
                end)
            else
                if botFollowConn then pcall(function() botFollowConn:Disconnect() end) botFollowConn = nil end
            end
        end,
    })

    BotTab:CreateButton({
        Name = "Give All Bots a Sword",
        Callback = function()
            clearDeadBots()
            for _, b in ipairs(bots) do
                if b and b.Parent then pcall(function() giveSword(b) end) end
            end
            Rayfield:Notify({ Title = "Swords Given", Content = "Each bot now holds a sword (local visual).", Duration = 4, Image = "sword" })
        end,
    })

    BotTab:CreateToggle({
        Name = "Bots Attack Me (Local Test)",
        CurrentValue = false,
        Callback = function(Value)
            botAttack = Value
            if Value then
                if botAttackConn then pcall(function() botAttackConn:Disconnect() end) end
                botAttackConn = RunService.Heartbeat:Connect(function()
                    if not botAttack then return end
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    local myHum = char and char:FindFirstChildOfClass("Humanoid")
                    if not hrp or not myHum then return end
                    for _, b in ipairs(bots) do
                        if b and b.Parent then
                            local hum = b:FindFirstChildOfClass("Humanoid")
                            local bhrp = b:FindFirstChild("HumanoidRootPart")
                            if hum and bhrp then
                                pcall(function() hum:MoveTo(hrp.Position) end)
                                local dist = (bhrp.Position - hrp.Position).Magnitude
                                if dist < 6 then
                                    local sword = b:FindFirstChild("NXSword")
                                    local blade = sword and sword:FindFirstChild("Blade")
                                    if blade then
                                        local w = blade:FindFirstChildOfClass("Weld")
                                        if w then
                                            pcall(function()
                                                w.C0 = CFrame.new(0, -2.5, 0) * CFrame.Angles(math.rad(20), 0, 0)
                                                task.delay(0.12, function()
                                                    if w and w.Parent then
                                                        w.C0 = CFrame.new(0, -2.5, 0) * CFrame.Angles(math.rad(90), 0, 0)
                                                    end
                                                end)
                                            end)
                                        end
                                    end
                                    pcall(function() myHum:TakeDamage(2) end)
                                end
                            end
                        end
                    end
                end)
                Rayfield:Notify({ Title = "Bots Attacking", Content = "Bots swing at YOU only. Damage is local (server restores it). Others are never affected.", Duration = 6, Image = "swords" })
            else
                if botAttackConn then pcall(function() botAttackConn:Disconnect() end) botAttackConn = nil end
            end
        end,
    })

    BotTab:CreateButton({
        Name = "All Bots Jump",
        Callback = function()
            for _, b in ipairs(bots) do
                if b and b.Parent then
                    local hum = b:FindFirstChildOfClass("Humanoid")
                    if hum then pcall(function() hum.Jump = true end) end
                end
            end
        end,
    })

    BotTab:CreateButton({
        Name = "Bring All Bots To Me",
        Callback = function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            for i, b in ipairs(bots) do
                if b and b.Parent then
                    local angle = math.rad((360 / math.max(#bots, 1)) * i)
                    pcall(function() b:PivotTo(hrp.CFrame * CFrame.new(math.cos(angle) * 6, 0, math.sin(angle) * 6)) end)
                end
            end
        end,
    })

    BotTab:CreateButton({
        Name = "Remove All Bots",
        Callback = function()
            removeAllBots()
            Rayfield:Notify({ Title = "Bots Removed", Content = "All your local bots are gone.", Duration = 3, Image = "user-x" })
        end,
    })

    BotTab:CreateSection("Control & View (First Bot)")

    local function firstBot()
        for _, b in ipairs(bots) do
            if b and b.Parent then return b end
        end
        return nil
    end

    local botPOV = false
    local botPOVConn = nil
    local botPOVYaw = 0
    local botPOVPitch = 0
    local botPOVTouchBegan = nil
    local botPOVTouchMoved = nil
    local botPOVTouchEnded = nil
    local botPOVDrag = nil
    local botPOVLast = nil
    BotTab:CreateToggle({
        Name = "Bot POV Camera",
        CurrentValue = false,
        Callback = function(Value)
            botPOV = Value
            local cam = Workspace.CurrentCamera
            local UIS = game:GetService("UserInputService")
            if Value then
                cam.CameraType = Enum.CameraType.Scriptable
                botPOVYaw = 0
                botPOVPitch = 0
                botPOVDrag = nil
                botPOVLast = nil

                botPOVTouchBegan = UIS.TouchStarted:Connect(function(touch, processed)
                    if processed then return end
                    if touch.Position.X > cam.ViewportSize.X * 0.35 then
                        botPOVDrag = touch
                        botPOVLast = touch.Position
                    end
                end)
                botPOVTouchMoved = UIS.TouchMoved:Connect(function(touch, processed)
                    if botPOVDrag == touch and botPOVLast then
                        local delta = touch.Position - botPOVLast
                        botPOVLast = touch.Position
                        botPOVYaw = botPOVYaw - delta.X * 0.4
                        botPOVPitch = math.clamp(botPOVPitch - delta.Y * 0.4, -80, 80)
                    end
                end)
                botPOVTouchEnded = UIS.TouchEnded:Connect(function(touch)
                    if botPOVDrag == touch then botPOVDrag = nil botPOVLast = nil end
                end)

                if botPOVConn then pcall(function() botPOVConn:Disconnect() end) end
                botPOVConn = RunService.RenderStepped:Connect(function()
                    if not botPOV then return end
                    if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                        local md = UIS:GetMouseDelta()
                        botPOVYaw = botPOVYaw - md.X * 0.3
                        botPOVPitch = math.clamp(botPOVPitch - md.Y * 0.3, -80, 80)
                    end
                    local bot = firstBot()
                    local head = bot and (bot:FindFirstChild("Head") or bot:FindFirstChild("HumanoidRootPart"))
                    if head then
                        local baseLook = head.CFrame.LookVector
                        local baseYaw = math.atan2(-baseLook.X, -baseLook.Z)
                        local rot = CFrame.Angles(0, baseYaw + math.rad(botPOVYaw), 0) * CFrame.Angles(math.rad(botPOVPitch), 0, 0)
                        local eye = head.Position + Vector3.new(0, 1, 0) + (rot.LookVector * 1.2)
                        cam.CFrame = CFrame.new(eye) * rot
                    end
                end)
                Rayfield:Notify({ Title = "Bot POV ON", Content = "Mobile: drag the right side of the screen to look around. PC: right-mouse to look.", Duration = 6, Image = "eye" })
            else
                if botPOVConn then pcall(function() botPOVConn:Disconnect() end) botPOVConn = nil end
                if botPOVTouchBegan then pcall(function() botPOVTouchBegan:Disconnect() end) botPOVTouchBegan = nil end
                if botPOVTouchMoved then pcall(function() botPOVTouchMoved:Disconnect() end) botPOVTouchMoved = nil end
                if botPOVTouchEnded then pcall(function() botPOVTouchEnded:Disconnect() end) botPOVTouchEnded = nil end
                cam.CameraType = Enum.CameraType.Custom
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then cam.CameraSubject = hum end
            end
        end,
    })

    local botTPS = false
    local botTPSConn = nil
    local botTPSDist = 12
    local botTPSYaw = 0
    local botTPSPitch = 20
    local botTPSTouchBegan = nil
    local botTPSTouchMoved = nil
    local botTPSTouchEnded = nil
    local botTPSDrag = nil
    local botTPSLast = nil

    BotTab:CreateSlider({
        Name = "Third-Person Distance",
        Range = { 5, 40 },
        Increment = 1,
        Suffix = "studs",
        CurrentValue = 12,
        Callback = function(v) botTPSDist = v end,
    })

    BotTab:CreateToggle({
        Name = "Bot Third-Person Camera",
        CurrentValue = false,
        Callback = function(Value)
            botTPS = Value
            local cam = Workspace.CurrentCamera
            local UIS = game:GetService("UserInputService")
            if Value then
                cam.CameraType = Enum.CameraType.Scriptable
                botTPSYaw = 0
                botTPSPitch = 20
                botTPSDrag = nil
                botTPSLast = nil

                botTPSTouchBegan = UIS.TouchStarted:Connect(function(touch, processed)
                    if processed then return end
                    if touch.Position.X > cam.ViewportSize.X * 0.35 then
                        botTPSDrag = touch
                        botTPSLast = touch.Position
                    end
                end)
                botTPSTouchMoved = UIS.TouchMoved:Connect(function(touch, processed)
                    if botTPSDrag == touch and botTPSLast then
                        local delta = touch.Position - botTPSLast
                        botTPSLast = touch.Position
                        botTPSYaw = botTPSYaw - delta.X * 0.4
                        botTPSPitch = math.clamp(botTPSPitch - delta.Y * 0.4, -75, 80)
                    end
                end)
                botTPSTouchEnded = UIS.TouchEnded:Connect(function(touch)
                    if botTPSDrag == touch then botTPSDrag = nil botTPSLast = nil end
                end)

                if botTPSConn then pcall(function() botTPSConn:Disconnect() end) end
                botTPSConn = RunService.RenderStepped:Connect(function()
                    if not botTPS then return end
                    if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                        local md = UIS:GetMouseDelta()
                        botTPSYaw = botTPSYaw - md.X * 0.3
                        botTPSPitch = math.clamp(botTPSPitch - md.Y * 0.3, -75, 80)
                    end
                    local bot = firstBot()
                    local hrp = bot and (bot:FindFirstChild("HumanoidRootPart") or bot:FindFirstChild("Head"))
                    if hrp then
                        local focus = hrp.Position + Vector3.new(0, 2, 0)
                        local rot = CFrame.Angles(0, math.rad(botTPSYaw), 0) * CFrame.Angles(math.rad(-botTPSPitch), 0, 0)
                        local offset = rot:VectorToWorldSpace(Vector3.new(0, 0, botTPSDist))
                        cam.CFrame = CFrame.new(focus + offset, focus)
                    end
                end)
                Rayfield:Notify({ Title = "Bot Third-Person ON", Content = "Watching the bot from behind. Mobile: drag the right side to orbit. PC: right-mouse to orbit.", Duration = 6, Image = "video" })
            else
                if botTPSConn then pcall(function() botTPSConn:Disconnect() end) botTPSConn = nil end
                if botTPSTouchBegan then pcall(function() botTPSTouchBegan:Disconnect() end) botTPSTouchBegan = nil end
                if botTPSTouchMoved then pcall(function() botTPSTouchMoved:Disconnect() end) botTPSTouchMoved = nil end
                if botTPSTouchEnded then pcall(function() botTPSTouchEnded:Disconnect() end) botTPSTouchEnded = nil end
                cam.CameraType = Enum.CameraType.Custom
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then cam.CameraSubject = hum end
            end
        end,
    })

    local botControl = false
    local botControlConn = nil
    local botJumpConn = nil
    local savedWalkSpeed = nil
    local savedAnchor = nil
    BotTab:CreateToggle({
        Name = "Control Bot (WASD / Joystick)",
        CurrentValue = false,
        Callback = function(Value)
            botControl = Value
            local UIS = game:GetService("UserInputService")
            if Value then
                local char = LocalPlayer.Character
                local ph = char and char:FindFirstChildOfClass("Humanoid")
                if ph then
                    savedWalkSpeed = ph.WalkSpeed
                    pcall(function() ph.WalkSpeed = 0 end)
                end
                if botJumpConn then pcall(function() botJumpConn:Disconnect() end) end
                botJumpConn = UIS.JumpRequest:Connect(function()
                    if not botControl then return end
                    local bot = firstBot()
                    local hum = bot and bot:FindFirstChildOfClass("Humanoid")
                    if hum then pcall(function() hum.Jump = true end) end
                end)
                if botControlConn then pcall(function() botControlConn:Disconnect() end) end
                botControlConn = RunService.RenderStepped:Connect(function()
                    if not botControl then return end
                    local bot = firstBot()
                    local hum = bot and bot:FindFirstChildOfClass("Humanoid")
                    if not hum then return end
                    local cam = Workspace.CurrentCamera
                    local dir = Vector3.zero
                    if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                    if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                    if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                    if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                    local pc = LocalPlayer.Character
                    local pmh = pc and pc:FindFirstChildOfClass("Humanoid")
                    if pmh and pmh.MoveDirection.Magnitude > 0 then
                        dir = dir + pmh.MoveDirection
                    end
                    dir = Vector3.new(dir.X, 0, dir.Z)
                    if dir.Magnitude > 0 then
                        hum:Move(dir.Unit, false)
                    else
                        hum:Move(Vector3.zero, false)
                    end
                end)
                Rayfield:Notify({ Title = "Control Bot ON", Content = "Steer with WASD/joystick. Press Jump (Space or the mobile jump button) and the BOT jumps.", Duration = 7, Image = "gamepad-2" })
            else
                if botControlConn then pcall(function() botControlConn:Disconnect() end) botControlConn = nil end
                if botJumpConn then pcall(function() botJumpConn:Disconnect() end) botJumpConn = nil end
                local char = LocalPlayer.Character
                local ph = char and char:FindFirstChildOfClass("Humanoid")
                if ph and savedWalkSpeed then pcall(function() ph.WalkSpeed = savedWalkSpeed end) end
            end
        end,
    })

    BotTab:CreateToggle({
        Name = "Lock My Character (While Using Bot)",
        CurrentValue = false,
        Callback = function(Value)
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if Value then
                if hrp then
                    savedAnchor = hrp.Anchored
                    pcall(function() hrp.Anchored = true end)
                end
                if hum then pcall(function() hum.WalkSpeed = 0 end) end
                Rayfield:Notify({ Title = "Character Locked", Content = "You stay frozen in place while you view or drive the bot.", Duration = 5, Image = "lock" })
            else
                if hrp and savedAnchor ~= nil then pcall(function() hrp.Anchored = savedAnchor end) end
                if hum and not botControl then pcall(function() hum.WalkSpeed = 16 end) end
                Rayfield:Notify({ Title = "Character Unlocked", Content = "You can move again.", Duration = 3, Image = "unlock" })
            end
        end,
    })

    local botSwing = false
    local botSwingConn = nil
    BotTab:CreateToggle({
        Name = "Bot Swings Sword on Click/Tap",
        CurrentValue = false,
        Callback = function(Value)
            botSwing = Value
            local UIS = game:GetService("UserInputService")
            if Value then
                if botSwingConn then pcall(function() botSwingConn:Disconnect() end) end
                botSwingConn = UIS.InputBegan:Connect(function(input, processed)
                    if processed then return end
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        if botSwing then
                            swingSword(firstBot())
                        end
                    end
                end)
                Rayfield:Notify({ Title = "Sword Swing ON", Content = "Click or tap to make the controlled bot swing - even at empty air. Only hits YOU if you're close.", Duration = 7, Image = "swords" })
            else
                if botSwingConn then pcall(function() botSwingConn:Disconnect() end) botSwingConn = nil end
            end
        end,
    })

    BotTab:CreateButton({
        Name = "Swing Sword Once",
        Callback = function()
            swingSword(firstBot())
        end,
    })

    BotTab:CreateButton({
        Name = "Bot Jump (Controlled)",
        Callback = function()
            local bot = firstBot()
            local hum = bot and bot:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.Jump = true end) end
        end,
    })

    BotTab:CreateButton({
        Name = "Teleport To Bot",
        Callback = function()
            local bot = firstBot()
            local bhrp = bot and bot:FindFirstChild("HumanoidRootPart")
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if bhrp and hrp then
                hrp.CFrame = bhrp.CFrame * CFrame.new(2, 0, 0)
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end,
    })

    BotTab:CreateButton({
        Name = "Swap Places With Bot",
        Callback = function()
            local bot = firstBot()
            local bhrp = bot and bot:FindFirstChild("HumanoidRootPart")
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if bhrp and hrp then
                local myCF = hrp.CFrame
                local botCF = bhrp.CFrame
                hrp.CFrame = botCF
                hrp.AssemblyLinearVelocity = Vector3.zero
                pcall(function() bot:PivotTo(myCF) end)
            end
        end,
    })

    BotTab:CreateSection("Free Camera (View From Outside)")

    local freeCam = false
    local freeCamConn = nil
    local freeCamTouchBegan = nil
    local freeCamTouchChanged = nil
    local freeCamTouchEnded = nil
    local freeCamPos = Vector3.zero
    local freeCamYaw = 0
    local freeCamPitch = 0
    local freeCamSpeed = 60
    local freeCamLockChar = false
    local freeCamSavedWS = nil
    local freeCamSavedAnchor = nil
    local freeCamDragId = nil
    local freeCamLastTouch = nil
    local UIS = game:GetService("UserInputService")

    BotTab:CreateSlider({
        Name = "Free Camera Speed",
        Range = { 10, 300 },
        Increment = 5,
        Suffix = "studs/s",
        CurrentValue = 60,
        Callback = function(v) freeCamSpeed = v end,
    })

    BotTab:CreateToggle({
        Name = "Lock Character In Place",
        CurrentValue = false,
        Callback = function(Value)
            freeCamLockChar = Value
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if Value then
                if hum then
                    freeCamSavedWS = hum.WalkSpeed
                    pcall(function() hum.WalkSpeed = 0 end)
                end
                if hrp then
                    freeCamSavedAnchor = hrp.Anchored
                    pcall(function() hrp.Anchored = true end)
                end
                Rayfield:Notify({ Title = "Character Locked", Content = "You stay put. Only the camera moves.", Duration = 4, Image = "lock" })
            else
                if hum and freeCamSavedWS then pcall(function() hum.WalkSpeed = freeCamSavedWS end) end
                if hrp and freeCamSavedAnchor ~= nil then pcall(function() hrp.Anchored = freeCamSavedAnchor end) end
            end
        end,
    })

    BotTab:CreateToggle({
        Name = "Free Camera (Detach & Fly)",
        CurrentValue = false,
        Callback = function(Value)
            freeCam = Value
            local cam = Workspace.CurrentCamera
            if Value then
                cam.CameraType = Enum.CameraType.Scriptable
                freeCamPos = cam.CFrame.Position
                local look = cam.CFrame.LookVector
                freeCamYaw = math.deg(math.atan2(-look.X, -look.Z))
                freeCamPitch = math.deg(math.asin(math.clamp(look.Y, -1, 1)))

                freeCamDragId = nil
                freeCamLastTouch = nil
                freeCamTouchBegan = UIS.TouchStarted:Connect(function(touch, processed)
                    if processed then return end
                    if touch.Position.X > Workspace.CurrentCamera.ViewportSize.X * 0.35 then
                        freeCamDragId = touch
                        freeCamLastTouch = touch.Position
                    end
                end)
                freeCamTouchChanged = UIS.TouchMoved:Connect(function(touch, processed)
                    if freeCamDragId == touch and freeCamLastTouch then
                        local delta = touch.Position - freeCamLastTouch
                        freeCamLastTouch = touch.Position
                        freeCamYaw = freeCamYaw - delta.X * 0.4
                        freeCamPitch = math.clamp(freeCamPitch - delta.Y * 0.4, -89, 89)
                    end
                end)
                freeCamTouchEnded = UIS.TouchEnded:Connect(function(touch)
                    if freeCamDragId == touch then
                        freeCamDragId = nil
                        freeCamLastTouch = nil
                    end
                end)

                if freeCamConn then pcall(function() freeCamConn:Disconnect() end) end
                freeCamConn = RunService.RenderStepped:Connect(function(dt)
                    if not freeCam then return end
                    if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                        local md = UIS:GetMouseDelta()
                        freeCamYaw = freeCamYaw - md.X * 0.3
                        freeCamPitch = math.clamp(freeCamPitch - md.Y * 0.3, -89, 89)
                    end
                    local rot = CFrame.Angles(0, math.rad(freeCamYaw), 0) * CFrame.Angles(math.rad(freeCamPitch), 0, 0)
                    local move = Vector3.zero
                    if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + Vector3.new(0, 0, -1) end
                    if UIS:IsKeyDown(Enum.KeyCode.S) then move = move + Vector3.new(0, 0, 1) end
                    if UIS:IsKeyDown(Enum.KeyCode.A) then move = move + Vector3.new(-1, 0, 0) end
                    if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + Vector3.new(1, 0, 0) end
                    if UIS:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
                    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then move = move + Vector3.new(0, -1, 0) end
                    if not freeCamLockChar then
                        local pc = LocalPlayer.Character
                        local ph = pc and pc:FindFirstChildOfClass("Humanoid")
                        if ph and ph.MoveDirection.Magnitude > 0 then
                            move = move + rot:VectorToObjectSpace(ph.MoveDirection)
                        end
                    else
                        local pc = LocalPlayer.Character
                        local ph = pc and pc:FindFirstChildOfClass("Humanoid")
                        if ph and ph.MoveDirection.Magnitude > 0 then
                            move = move + rot:VectorToObjectSpace(ph.MoveDirection)
                        end
                    end
                    if move.Magnitude > 0 then
                        freeCamPos = freeCamPos + rot:VectorToWorldSpace(move.Unit) * freeCamSpeed * dt
                    end
                    cam.CFrame = CFrame.new(freeCamPos) * rot
                end)
                Rayfield:Notify({ Title = "Free Camera ON", Content = "Mobile: drag the right side of the screen to look; joystick moves the camera. PC: WASD + right-mouse to look.", Duration = 8, Image = "video" })
            else
                if freeCamConn then pcall(function() freeCamConn:Disconnect() end) freeCamConn = nil end
                if freeCamTouchBegan then pcall(function() freeCamTouchBegan:Disconnect() end) freeCamTouchBegan = nil end
                if freeCamTouchChanged then pcall(function() freeCamTouchChanged:Disconnect() end) freeCamTouchChanged = nil end
                if freeCamTouchEnded then pcall(function() freeCamTouchEnded:Disconnect() end) freeCamTouchEnded = nil end
                cam.CameraType = Enum.CameraType.Custom
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then cam.CameraSubject = hum end
            end
        end,
    })
end

Rayfield:Notify({
    Title = "Hub Ready",
    Content = "NX Roblox Script loaded. Game tabs appear automatically when supported.",
    Duration = 5,
    Image = "check-circle",
})

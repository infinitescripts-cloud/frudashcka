--[[
    Reboot Movie Route Recorder - Animation Edition
    Single-file Luau recorder

    Fixes:
      - Start Recording button restored
      - Stop Recording button restored
      - Play Record button is visible on Recorder tab
      - Play Record uses the actual local route table
      - Export JSON writes a real .json file using the route name
      - No notifications/toasts are used
      - 0.10s default sampling
      - Route name is stored inside the JSON and used as the filename
      - Fixed the RecorderRecorderTab typo
      - Playback drives walking, climbing, jumping, falling, and landing animations
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Rayfield
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- =========================================================
-- STATE
-- =========================================================

local recording = false
local playing = false

local route = {}
local routeName = "My Movie Route"

local sampleInterval = 0.10
local captureState = true
local captureJumps = true

local elapsed = 0
local sampleAccumulator = 0

local heartbeatConnection
local jumpConnection

-- =========================================================
-- HELPERS
-- =========================================================

local function getCharacter()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root then
        return nil
    end

    return character, humanoid, root
end

local function safeFileName(name)
    name = tostring(name or "RebootRoute")
    name = name:gsub("[^%w_%- ]", "")
    name = name:gsub("%s+", "_")
    name = name:gsub("_+", "_")

    if name == "" then
        name = "RebootRoute"
    end

    return name
end

-- =========================================================
-- EXPORT
-- =========================================================

local function buildExport()
    return {
        format = "RebootPracticeRoute",
        version = 1,
        name = routeName,
        sampleInterval = sampleInterval,
        createdAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        samples = route
    }
end

local function exportRoute()
    if #route == 0 then
        StatusLabel:Set("Status: Nothing to export")
        return
    end

    if type(writefile) ~= "function" then
        StatusLabel:Set("Status: Export failed - writefile unavailable")
        return
    end

    local data = buildExport()
    local json

    local encodeOK, encodeResult = pcall(function()
        return HttpService:JSONEncode(data)
    end)

    if not encodeOK then
        StatusLabel:Set("Status: JSON encode failed")
        return
    end

    json = encodeResult

    local filename = safeFileName(routeName) .. ".json"

    -- Prefer a dedicated folder when the executor supports folders.
    local folder = "RebootRecordEngine"
    local folderReady = false

    if type(makefolder) == "function" then
        pcall(function()
            if type(isfolder) == "function" then
                if not isfolder(folder) then
                    makefolder(folder)
                end
            else
                makefolder(folder)
            end
            folderReady = true
        end)
    end

    local paths = {}

    if folderReady then
        table.insert(paths, folder .. "/" .. filename)
    end

    table.insert(paths, filename)

    for _, path in ipairs(paths) do
        local ok = pcall(function()
            writefile(path, json)
        end)

        if ok then
            StatusLabel:Set("Status: Exported " .. filename)
            return
        end
    end

    StatusLabel:Set("Status: Export failed")
end

-- =========================================================
-- RECORDING
-- =========================================================

local function addSample()
    local _, humanoid, root = getCharacter()
    if not humanoid or not root then
        return
    end

    local cf = root.CFrame
    local rx, ry, rz = cf:ToOrientation()

    local sample = {
        time = elapsed,

        position = {
            tonumber(string.format("%.4f", cf.Position.X)),
            tonumber(string.format("%.4f", cf.Position.Y)),
            tonumber(string.format("%.4f", cf.Position.Z))
        },

        rotation = {
            tonumber(string.format("%.5f", rx)),
            tonumber(string.format("%.5f", ry)),
            tonumber(string.format("%.5f", rz))
        }
    }

    if captureState then
        sample.state = humanoid:GetState().Name
    end

    table.insert(route, sample)

    CountLabel:Set("Samples: " .. tostring(#route))
end

local function stopRecording()
    if not recording then
        return
    end

    recording = false

    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end

    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end

    StatusLabel:Set("Status: Stopped")
    refreshPreview()
end

local function startRecording()
    if recording then
        return
    end

    local _, humanoid, root = getCharacter()

    if not humanoid or not root then
        StatusLabel:Set("Status: Character not ready")
        return
    end

    -- Reset only when a new recording actually starts.
    route = {}
    elapsed = 0
    sampleAccumulator = 0

    recording = true

    StatusLabel:Set("Status: Recording")
    CountLabel:Set("Samples: 0")

    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end

    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end

    -- Capture the exact starting position immediately.
    addSample()

    if captureJumps then
        jumpConnection = humanoid.StateChanged:Connect(function(_, newState)
            if not recording then
                return
            end

            if newState == Enum.HumanoidStateType.Jumping then
                local _, _, rootNow = getCharacter()

                if rootNow then
                    local p = rootNow.Position

                    table.insert(route, {
                        time = elapsed,
                        position = {
                            tonumber(string.format("%.4f", p.X)),
                            tonumber(string.format("%.4f", p.Y)),
                            tonumber(string.format("%.4f", p.Z))
                        },
                        action = "Jump"
                    })

                    CountLabel:Set("Samples: " .. tostring(#route))
                end
            end
        end)
    end

    heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
        if not recording then
            return
        end

        elapsed += dt
        sampleAccumulator += dt

        if sampleAccumulator >= sampleInterval then
            sampleAccumulator -= sampleInterval
            addSample()
        end
    end)
end

-- =========================================================
-- PLAYBACK ANIMATIONS
-- =========================================================

local activePlaybackTrack
local activePlaybackState

local function getAnimator()
    local character, humanoid = getCharacter()
    if not humanoid then
        return nil, nil
    end

    local animator = humanoid:FindFirstChildOfClass("Animator")

    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    return animator, humanoid
end

local function findAnimationId(name)
    local character = LocalPlayer.Character
    if not character then
        return nil
    end

    local animate = character:FindFirstChild("Animate")
    if not animate then
        return nil
    end

    local folder = animate:FindFirstChild(name)
    if not folder then
        return nil
    end

    local animation = folder:FindFirstChildWhichIsA("Animation", true)
    return animation and animation.AnimationId or nil
end

local function playAnimationState(state, speed)
    local animator, humanoid = getAnimator()
    if not animator or not humanoid then
        return
    end

    local wanted = state

    if wanted == "Running" then
        wanted = "walk"
    elseif wanted == "Walking" then
        wanted = "walk"
    elseif wanted == "Climbing" then
        wanted = "climb"
    elseif wanted == "Jumping" then
        wanted = "jump"
    elseif wanted == "Freefall" then
        wanted = "fall"
    elseif wanted == "Landed" then
        wanted = "land"
    elseif wanted == "Idle" then
        wanted = "idle"
    end

    if activePlaybackState == wanted and activePlaybackTrack and activePlaybackTrack.IsPlaying then
        activePlaybackTrack:AdjustSpeed(speed or 1)
        return
    end

    if activePlaybackTrack then
        pcall(function()
            activePlaybackTrack:Stop(0.12)
            activePlaybackTrack:Destroy()
        end)
        activePlaybackTrack = nil
    end

    activePlaybackState = wanted

    local animationId

    if wanted == "walk" then
        animationId = findAnimationId("walk")
        if not animationId then
            animationId = findAnimationId("run")
        end
    elseif wanted == "climb" then
        animationId = findAnimationId("climb")
    elseif wanted == "jump" then
        animationId = findAnimationId("jump")
    elseif wanted == "fall" then
        animationId = findAnimationId("fall")
    elseif wanted == "idle" then
        animationId = findAnimationId("idle")
    elseif wanted == "land" then
        animationId = findAnimationId("land")
    end

    if not animationId or animationId == "" then
        return
    end

    local animation = Instance.new("Animation")
    animation.AnimationId = animationId

    local ok, track = pcall(function()
        return animator:LoadAnimation(animation)
    end)

    animation:Destroy()

    if not ok or not track then
        return
    end

    activePlaybackTrack = track
    track.Priority = Enum.AnimationPriority.Movement
    track.Looped = wanted ~= "jump" and wanted ~= "land"
    track:Play(0.12, 1, speed or 1)
end

local function stopPlaybackAnimation()
    if activePlaybackTrack then
        pcall(function()
            activePlaybackTrack:Stop(0.12)
            activePlaybackTrack:Destroy()
        end)
    end

    activePlaybackTrack = nil
    activePlaybackState = nil
end

-- =========================================================
-- PREVIEW / PLAY RECORD
-- =========================================================

local function stopRecordedRoute()
    playing = false
    stopPlaybackAnimation()

    local _, humanoid = getCharacter()
    if humanoid then
        humanoid:Move(Vector3.zero, false)
    end
end

local function playRecordedRoute()
    if playing then
        return
    end

    if #route < 1 then
        StatusLabel:Set("Status: No recording to play")
        return
    end

    local character, humanoid, root = getCharacter()

    if not character or not humanoid or not root then
        StatusLabel:Set("Status: Character not ready")
        return
    end

    -- Smooth playback: samples are keyframes, not teleport points.
    -- The character is interpolated every Heartbeat between each pair.
    playing = true
    StatusLabel:Set("Status: Playing Record")

    task.spawn(function()
        local oldAutoRotate = humanoid.AutoRotate
        local oldPlatformStand = humanoid.PlatformStand
        humanoid.AutoRotate = false
        -- Disable Humanoid physics while replaying keyframes.
        -- The recorded CFrame trajectory controls the character, which
        -- prevents jump/freefall physics from fighting the interpolation.
        humanoid.PlatformStand = true

        local function sampleCFrame(sample)
            local p = sample and sample.position
            if type(p) ~= "table" or #p < 3 then
                return nil
            end

            local r = sample.rotation
            if type(r) == "table" and #r >= 3 then
                return CFrame.new(p[1], p[2], p[3]) * CFrame.Angles(
                    r[1] or 0,
                    r[2] or 0,
                    r[3] or 0
                )
            end

            return CFrame.new(p[1], p[2], p[3])
        end

        local function applyRecordedState(sample)
            if not sample then
                return
            end

            if sample.action == "Jump" then
                playAnimationState("Jumping", 1)
            elseif sample.state == "Climbing" then
                playAnimationState("Climbing", 1)
            elseif sample.state == "Freefall" then
                playAnimationState("Freefall", 1)
            elseif sample.state == "Landed" then
                playAnimationState("Landed", 1)
            elseif sample.state == "Running" or sample.state == "Walking" then
                playAnimationState("Running", 1)
            else
                playAnimationState("Idle", 1)
            end
        end

        local function validTime(sample, fallback)
            local t = tonumber(sample and sample.time)
            if not t then
                return fallback
            end
            return t
        end

        -- Establish the first frame immediately.
        local firstCF = sampleCFrame(route[1])
        if firstCF and root.Parent then
            root.CFrame = firstCF
        end
        applyRecordedState(route[1])

        local playbackTime = 0
        local startClock = os.clock()
        local segment = 1
        local lastStateSample = 1
        local finished = false

        while playing and root.Parent and segment <= #route do
            local now = os.clock()
            playbackTime = now - startClock

            -- Advance through all keyframes reached by the current time.
            while segment < #route and playbackTime >= validTime(route[segment + 1], playbackTime) do
                segment = segment + 1
                applyRecordedState(route[segment])
                lastStateSample = segment
            end

            if segment >= #route then
                local finalCF = sampleCFrame(route[#route])
                if finalCF and root.Parent then
                    root.CFrame = finalCF
                end
                finished = true
                break
            end

            local a = route[segment]
            local b = route[segment + 1]
            local aTime = validTime(a, 0)
            local bTime = validTime(b, aTime + sampleInterval)
            local duration = math.max(0.0001, bTime - aTime)
            local alpha = math.clamp((playbackTime - aTime) / duration, 0, 1)

            local aCF = sampleCFrame(a)
            local bCF = sampleCFrame(b)

            if aCF and bCF and root.Parent then
                -- CFrame:Lerp gives continuous position + rotation instead of
                -- snapping to each 0.1s recording sample.
                root.CFrame = aCF:Lerp(bCF, alpha)
            elseif bCF and root.Parent then
                root.CFrame = bCF
            end

            -- Let the animation rate roughly follow recorded movement speed.
            if bCF and aCF then
                local distance = (bCF.Position - aCF.Position).Magnitude
                local speed = distance / duration
                if speed > 0.05 then
                    local animSpeed = math.clamp(speed / 16, 0.55, 2.5)
                    if route[segment].state == "Running" or route[segment].state == "Walking" then
                        playAnimationState("Running", animSpeed)
                    elseif route[segment].state == "Climbing" then
                        playAnimationState("Climbing", animSpeed)
                    end
                end
            end

            RunService.Heartbeat:Wait()
        end

        if finished and playing and root.Parent then
            local finalCF = sampleCFrame(route[#route])
            if finalCF then
                root.CFrame = finalCF
            end
        end

        playing = false
        stopPlaybackAnimation()

        humanoid.AutoRotate = oldAutoRotate
        humanoid.PlatformStand = oldPlatformStand
        pcall(function()
            humanoid:Move(Vector3.zero, false)
        end)

        if recording then
            StatusLabel:Set("Status: Recording")
        else
            StatusLabel:Set("Status: Stopped")
        end
    end)
end

-- =========================================================
-- PREVIEW INFO
-- =========================================================

local function refreshPreview()
    if #route == 0 then
        PreviewParagraph:Set({
            Title = "Route Preview",
            Content = "No route recorded yet."
        })
        return
    end

    local first = route[1]
    local last = route[#route]

    local firstPos = first.position
    local lastPos = last.position

    local lines = {
        "Name: " .. routeName,
        "Samples: " .. tostring(#route),
        "Duration: " .. string.format("%.2f", tonumber(last.time) or 0) .. "s",
        "",
        "Start:",
        string.format(
            "X %.2f | Y %.2f | Z %.2f",
            firstPos[1],
            firstPos[2],
            firstPos[3]
        ),
        "",
        "End:",
        string.format(
            "X %.2f | Y %.2f | Z %.2f",
            lastPos[1],
            lastPos[2],
            lastPos[3]
        )
    }

    if #route > 1 then
        local distance = 0

        for i = 2, #route do
            local a = route[i - 1].position
            local b = route[i].position

            local dx = b[1] - a[1]
            local dy = b[2] - a[2]
            local dz = b[3] - a[3]

            distance += math.sqrt(dx * dx + dy * dy + dz * dz)
        end

        table.insert(lines, "")
        table.insert(
            lines,
            string.format("Approx. distance: %.2f studs", distance)
        )
    end

    PreviewParagraph:Set({
        Title = "Route Preview",
        Content = table.concat(lines, "\n")
    })
end

local function clearRoute()
    if recording then
        stopRecording()
    end

    playing = false
    route = {}
    elapsed = 0
    sampleAccumulator = 0

    CountLabel:Set("Samples: 0")
    StatusLabel:Set("Status: Idle")

    refreshPreview()
end

-- =========================================================
-- UI
-- =========================================================

local Window = Rayfield:CreateWindow({
    Name = "Reboot Movie Route Recorder",
    Icon = "video",
    LoadingTitle = "Reboot Movie Route Recorder",
    LoadingSubtitle = "Practice TAS Recorder",
    ShowText = "Reboot Recorder",
    Theme = "Default",
    ToggleUIKeybind = "K",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true
})

local RecorderTab = Window:CreateTab("Recorder", "video")
local PreviewTab = Window:CreateTab("Preview", "map")
local SettingsTab = Window:CreateTab("Settings", "settings")

StatusLabel = RecorderTab:CreateLabel("Status: Idle")
CountLabel = RecorderTab:CreateLabel("Samples: 0")

PreviewParagraph = PreviewTab:CreateParagraph({
    Title = "Route Preview",
    Content = "No route recorded yet."
})

-- Recorder controls
RecorderTab:CreateSection("Recording")

RecorderTab:CreateInput({
    Name = "Route Name",
    PlaceholderText = "Movie challenge name",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        if text and text:gsub("%s+", "") ~= "" then
            routeName = text
            RouteNameLabel:Set("Route: " .. routeName)
            refreshPreview()
        end
    end
})

RecorderTab:CreateButton({
    Name = "Start Recording",
    Callback = startRecording
})

RecorderTab:CreateButton({
    Name = "Stop Recording",
    Callback = stopRecording
})

RecorderTab:CreateButton({
    Name = "Play Record",
    Callback = playRecordedRoute
})

RecorderTab:CreateButton({
    Name = "Stop Record",
    Callback = stopRecordedRoute
})

RecorderTab:CreateButton({
    Name = "Export JSON to File",
    Callback = exportRoute
})

RecorderTab:CreateButton({
    Name = "Clear Route",
    Callback = clearRoute
})

RecorderTab:CreateSection("Current Route")

RouteNameLabel = RecorderTab:CreateLabel("Route: " .. routeName)

-- Preview controls
PreviewTab:CreateSection("Playback")

PreviewTab:CreateButton({
    Name = "Play Record",
    Callback = playRecordedRoute
})

PreviewTab:CreateButton({
    Name = "Stop Record",
    Callback = stopRecordedRoute
})

PreviewTab:CreateButton({
    Name = "Refresh Preview",
    Callback = refreshPreview
})

-- Settings
SettingsTab:CreateSection("Recorder Settings")

SettingsTab:CreateSlider({
    Name = "Sample Interval",
    Range = {0.05, 1},
    Increment = 0.05,
    Suffix = " sec",
    CurrentValue = sampleInterval,
    Flag = "SampleInterval",
    Callback = function(value)
        sampleInterval = value
    end
})

SettingsTab:CreateToggle({
    Name = "Capture Humanoid State",
    CurrentValue = captureState,
    Flag = "CaptureState",
    Callback = function(value)
        captureState = value
    end
})

SettingsTab:CreateToggle({
    Name = "Capture Jumps",
    CurrentValue = captureJumps,
    Flag = "CaptureJumps",
    Callback = function(value)
        captureJumps = value
    end
})

SettingsTab:CreateParagraph({
    Title = "JSON Export",
    Content = "Export JSON to File saves <RouteName>.json. No clipboard-only export and no notifications are used."
})

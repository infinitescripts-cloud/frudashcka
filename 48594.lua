--[[
    Reboot Practice Route Recorder
    Single-file LuaU recorder
    Features:
      - Start Recording
      - Stop Recording
      - Export JSON
      - Route Preview
      - Sample interval control
      - Route name input
      - Optional jump/state capture
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Load Rayfield Gen1
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()


-- Export a complete route as a real JSON file.
local function ExportRouteToFile(routeData)
    if type(writefile) ~= "function" then
        Rayfield:Notify({
            Title = "File Export",
            Content = "This executor does not provide writefile().",
            Duration = 4
        })
        return false
    end

    local json = HttpService:JSONEncode(routeData)
    local safeName = tostring(routeData.name or "RebootRoute")
        :gsub("[^%w_%-]", "_")

    if safeName == "" then
        safeName = "RebootRoute"
    end

    -- The exported file is named after the recording.
    local filename = safeName .. ".json"

    local ok, err = pcall(function()
        writefile(filename, json)
    end)

    if ok then
        Rayfield:Notify({
            Title = "JSON Exported",
            Content = "Saved " .. filename,
            Duration = 3
        })
        return true
    end

    Rayfield:Notify({
        Title = "File Export Failed",
        Content = tostring(err),
        Duration = 4
    })
    return false
end

-- Play Record preview.
-- This previews the current recording locally by moving the character
-- through the recorded positions/timings.
local playPreviewing = false

local function PlayRecordedRoute()
    if playPreviewing then
        return
    end

    if type(route) ~= "table" or #route == 0 then
        Rayfield:Notify({
            Title = "Play Record",
            Content = "Record a route first.",
            Duration = 2
        })
        return
    end

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not root then
        Rayfield:Notify({
            Title = "Play Record",
            Content = "HumanoidRootPart not found.",
            Duration = 2
        })
        return
    end

    playPreviewing = true

    task.spawn(function()
        local previousTime = 0

        for _, sample in ipairs(route) do
            if not playPreviewing then
                break
            end

            local t = tonumber(sample.time) or previousTime
            local delayTime = math.max(0, t - previousTime)

            if delayTime > 0 then
                task.wait(delayTime)
            end

            previousTime = t

            local p = sample.position
            local r = sample.rotation

            if type(p) == "table" and #p >= 3 and root.Parent then
                if type(r) == "table" and #r >= 3 then
                    root.CFrame =
                        CFrame.new(p[1], p[2], p[3]) *
                        CFrame.Angles(r[1] or 0, r[2] or 0, r[3] or 0)
                else
                    root.CFrame = CFrame.new(p[1], p[2], p[3])
                end
            end
        end

        playPreviewing = false

        if root.Parent then
            Rayfield:Notify({
                Title = "Play Record",
                Content = "Preview finished.",
                Duration = 2
            })
        end
    end)
end

local function StopRecordedRoutePreview()
    playPreviewing = false
end

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

local recording = false
local route = {}
local routeName = "My Movie Route"
local sampleInterval = 0.10
local captureState = true
local captureJumps = true
local elapsed = 0
local heartbeatConnection
local jumpConnection

local PreviewParagraph = PreviewTab:CreateParagraph({
    Title = "Route Preview",
    Content = "No route recorded yet."
})

local StatusLabel = RecorderTab:CreateLabel("Status: Idle")
local CountLabel = RecorderTab:CreateLabel("Samples: 0")

local function getCharacter()
    local character = LocalPlayer.Character
    if not character then return nil end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root then
        return nil
    end

    return character, humanoid, root
end

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
        "Duration: " .. string.format("%.2f", last.time) .. "s",
        "",
        "Start:",
        string.format("  X %.2f | Y %.2f | Z %.2f", firstPos[1], firstPos[2], firstPos[3]),
        "",
        "End:",
        string.format("  X %.2f | Y %.2f | Z %.2f", lastPos[1], lastPos[2], lastPos[3]),
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
        table.insert(lines, string.format("Approx. distance: %.2f studs", distance))
    end

    PreviewParagraph:Set({
        Title = "Route Preview",
        Content = table.concat(lines, "\n")
    })
end

local function addSample()
    local character, humanoid, root = getCharacter()
    if not root then return end

    local cf = root.CFrame
    local x, y, z = cf.Position.X, cf.Position.Y, cf.Position.Z
    local rx, ry, rz = cf:ToOrientation()

    local sample = {
        time = elapsed,
        position = {
            tonumber(string.format("%.4f", x)),
            tonumber(string.format("%.4f", y)),
            tonumber(string.format("%.4f", z))
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

local function startRecording()
    if recording then return end

    local _, humanoid, root = getCharacter()
    if not humanoid or not root then
        Rayfield:Notify({
            Title = "Recorder",
            Content = "Character is not ready.",
            Duration = 4,
            Image = "triangle-alert"
        })
        return
    end

    route = {}
    elapsed = 0
    recording = true

    StatusLabel:Set("Status: Recording")
    CountLabel:Set("Samples: 0")

    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end

    if captureJumps then
        jumpConnection = humanoid.StateChanged:Connect(function(_, newState)
            if not recording then return end

            if newState == Enum.HumanoidStateType.Jumping then
                local characterNow, humanoidNow, rootNow = getCharacter()
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
                end
            end
        end)
    end

    heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
        if not recording then return end

        elapsed += dt

        if elapsed >= (#route == 0 and sampleInterval or route[#route].time + sampleInterval) then
            addSample()
        end
    end)

    Rayfield:Notify({
        Title = "Recording Started",
        Content = "Move through the challenge normally.",
        Duration = 4,
        Image = "circle-dot"
    })
end

local function stopRecording()
    if not recording then return end

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

    Rayfield:Notify({
        Title = "Recording Stopped",
        Content = string.format("%d samples captured.", #route),
        Duration = 4,
        Image = "square"
    })
end

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
        Rayfield:Notify({
            Title = "Export Failed",
            Content = "Record a route first.",
            Duration = 2,
            Image = "triangle-alert"
        })
        return
    end

    ExportRouteToFile(buildExport())
end

local function clearRoute()
    if recording then
        stopRecording()
    end

    route = {}
    elapsed = 0
    CountLabel:Set("Samples: 0")
    StatusLabel:Set("Status: Idle")
    refreshPreview()

    Rayfield:Notify({
        Title = "Route Cleared",
        Content = "The current recording was cleared.",
        Duration = 3,
        Image = "trash-2"
    })
end

RecorderTab:CreateSection("Recording")

RecorderTab:CreateInput({
    Name = "Route Name",
    PlaceholderText = "Movie challenge name",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        if text and text:gsub("%s+", "") ~= "" then
            routeName = text
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
    Name = "Export JSON",
    Callback = exportRoute
})


Tab:CreateButton({
    Name = "Export JSON to File",
    Callback = function()
        if type(route) ~= "table" then
            Rayfield:Notify({
                Title = "Export",
                Content = "No route is currently recorded.",
                Duration = 4
            })


Tab:CreateButton({
    Name = "Play Record",
    Callback = function()
        PlayRecordedRoute()
    end
})

Tab:CreateButton({
    Name = "Stop Record Preview",
    Callback = function()
        StopRecordedRoutePreview()
    end
})

            return
        end
        ExportRouteToFile(route)
    end
})


RecorderTab:CreateButton({
    Name = "Clear Route",
    Callback = clearRoute
})

RecorderTab:CreateSection("Current Route")

RecorderTab:CreateLabel("Route: " .. routeName)

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
    Title = "Format Note",
    Content = "This recorder exports the RebootPracticeRoute format. It is intentionally separate from TrdTAS JSON until a compatible route schema is confirmed."
})

PreviewTab:CreateButton({
    Name = "Play Record",
    Callback = function()
        PlayRecordedRoute()
    end
})

PreviewTab:CreateButton({
    Name = "Stop Record Preview",
    Callback = function()
        StopRecordedRoutePreview()
    end
})

PreviewTab:CreateButton({
    Name = "Refresh Preview",
    Callback = refreshPreview
})

Rayfield:Notify({
    Title = "Recorder Ready",
    Content = "Choose a route name, then press Start Recording.",
    Duration = 2,
    Image = "video"
})

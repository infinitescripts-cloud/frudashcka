--[[
    NovaUI Beta v0.1
    Mobile-first Liquid Glass UI Library
    Original standalone implementation
]]

local NovaUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Themes = {
    Amber = {
        Accent = Color3.fromRGB(255, 183, 77),
        AccentDark = Color3.fromRGB(190, 120, 35),
    },
    Blue = {
        Accent = Color3.fromRGB(80, 160, 255),
        AccentDark = Color3.fromRGB(45, 100, 190),
    },
    Purple = {
        Accent = Color3.fromRGB(170, 110, 255),
        AccentDark = Color3.fromRGB(105, 60, 180),
    },
    Rose = {
        Accent = Color3.fromRGB(255, 105, 150),
        AccentDark = Color3.fromRGB(180, 55, 100),
    },
    Emerald = {
        Accent = Color3.fromRGB(70, 210, 150),
        AccentDark = Color3.fromRGB(35, 140, 95),
    }
}

local Theme = Themes.Amber

local function tween(obj, props, duration)
    return TweenService:Create(
        obj,
        TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        props
    )
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = parent
    return c
end

local function stroke(parent, transparency)
    local s = Instance.new("UIStroke")
    s.Color = Color3.new(1, 1, 1)
    s.Transparency = transparency or 0.88
    s.Thickness = 1
    s.Parent = parent
    return s
end

local function makeText(parent, text, size, bold)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Text = text or ""
    label.TextColor3 = Color3.fromRGB(245, 245, 250)
    label.TextSize = size or 14
    label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

local function bindTouchDrag(handle, target)
    local dragging = false
    local dragStart
    local startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then

            local delta = input.Position - dragStart

            target.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

function NovaUI:SetTheme(name)
    if Themes[name] then
        Theme = Themes[name]
    end
end

function NovaUI:Notify(data)
    data = data or {}

    local gui = PlayerGui:FindFirstChild("NovaUI_Notifications")
    if not gui then
        gui = Instance.new("ScreenGui")
        gui.Name = "NovaUI_Notifications"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 100
        gui.Parent = PlayerGui
    end

    local holder = gui:FindFirstChild("Holder")
    if not holder then
        holder = Instance.new("Frame")
        holder.Name = "Holder"
        holder.BackgroundTransparency = 1
        holder.AnchorPoint = Vector2.new(1, 0)
        holder.Position = UDim2.new(1, -12, 0, 12)
        holder.Size = UDim2.new(0, 300, 1, -24)
        holder.Parent = gui

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        layout.VerticalAlignment = Enum.VerticalAlignment.Top
        layout.Parent = holder
    end

    local card = Instance.new("Frame")
    card.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    card.BackgroundTransparency = 0.12
    card.Size = UDim2.new(1, 0, 0, 70)
    card.Parent = holder
    corner(card, 14)
    stroke(card, 0.82)

    local title = makeText(card, data.Title or "NovaUI", 14, true)
    title.Position = UDim2.fromOffset(14, 10)
    title.Size = UDim2.new(1, -28, 0, 20)

    local body = makeText(card, data.Content or "", 12, false)
    body.TextColor3 = Color3.fromRGB(190, 190, 200)
    body.Position = UDim2.fromOffset(14, 32)
    body.Size = UDim2.new(1, -28, 0, 28)
    body.TextWrapped = true

    card.Position = UDim2.new(1, 30, 0, 0)
    tween(card, {Position = UDim2.new(0, 0, 0, 0)}, 0.35):Play()

    task.delay(data.Duration or 3, function()
        if card.Parent then
            local t = tween(card, {BackgroundTransparency = 1}, 0.25)
            t:Play()
            t.Completed:Wait()
            card:Destroy()
        end
    end)
end

function NovaUI:CreateWindow(options)
    options = options or {}

    self:SetTheme(options.Theme or "Amber")

    local old = PlayerGui:FindFirstChild("NovaUI")
    if old then
        old:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NovaUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = PlayerGui

    local window = Instance.new("Frame")
    window.Name = "Window"
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Size = UDim2.fromScale(0.92, 0.82)
    window.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
    window.BackgroundTransparency = 0.08
    window.ClipsDescendants = true
    window.Parent = gui

    corner(window, 18)
    stroke(window, 0.78)

    local sizeConstraint = Instance.new("UISizeConstraint")
    sizeConstraint.MinSize = Vector2.new(300, 260)
    sizeConstraint.MaxSize = Vector2.new(900, 650)
    sizeConstraint.Parent = window

    local top = Instance.new("Frame")
    top.Name = "Topbar"
    top.BackgroundTransparency = 1
    top.Size = UDim2.new(1, 0, 0, 62)
    top.Parent = window

    local title = makeText(top, options.Title or "NovaUI", 18, true)
    title.Position = UDim2.fromOffset(18, 10)
    title.Size = UDim2.new(1, -110, 0, 25)

    local subtitle = makeText(top, options.Subtitle or "Beta", 11, false)
    subtitle.TextColor3 = Color3.fromRGB(160, 160, 170)
    subtitle.Position = UDim2.fromOffset(19, 34)
    subtitle.Size = UDim2.new(1, -110, 0, 18)

    local minimize = Instance.new("TextButton")
    minimize.Text = "−"
    minimize.TextSize = 22
    minimize.Font = Enum.Font.GothamBold
    minimize.TextColor3 = Color3.fromRGB(235, 235, 240)
    minimize.BackgroundColor3 = Theme.Accent
    minimize.BackgroundTransparency = 0.75
    minimize.Size = UDim2.fromOffset(38, 38)
    minimize.Position = UDim2.new(1, -50, 0, 12)
    minimize.Parent = top
    corner(minimize, 12)

    local body = Instance.new("Frame")
    body.BackgroundTransparency = 1
    body.Position = UDim2.fromOffset(10, 62)
    body.Size = UDim2.new(1, -20, 1, -72)
    body.Parent = window

    local tabBar = Instance.new("ScrollingFrame")
    tabBar.Name = "Tabs"
    tabBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    tabBar.BackgroundTransparency = 0.96
    tabBar.BorderSizePixel = 0
    tabBar.ScrollBarThickness = 0
    tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
    tabBar.CanvasSize = UDim2.new()
    tabBar.ScrollingDirection = Enum.ScrollingDirection.X
    tabBar.Size = UDim2.new(1, 0, 0, 44)
    tabBar.Parent = body
    corner(tabBar, 12)

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Parent = tabBar

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.BackgroundTransparency = 1
    content.Position = UDim2.fromOffset(0, 52)
    content.Size = UDim2.new(1, 0, 1, -52)
    content.Parent = body

    bindTouchDrag(top, window)

    local minimized = false

    minimize.MouseButton1Click:Connect(function()
        minimized = not minimized

        if minimized then
            tween(window, {
                Size = UDim2.fromScale(0.92, 0.13)
            }, 0.3):Play()
            body.Visible = false
        else
            body.Visible = true
            tween(window, {
                Size = UDim2.fromScale(0.92, 0.82)
            }, 0.3):Play()
        end
    end)

    local Window = {
        Instance = window,
        Tabs = {}
    }

    function Window:CreateTab(tabOptions)
        tabOptions = tabOptions or {}

        local button = Instance.new("TextButton")
        button.AutoButtonColor = false
        button.Text = tabOptions.Name or "Tab"
        button.TextColor3 = Color3.fromRGB(190, 190, 200)
        button.TextSize = 12
        button.Font = Enum.Font.GothamMedium
        button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        button.BackgroundTransparency = 0.96
        button.Size = UDim2.fromOffset(100, 34)
        button.Parent = tabBar
        corner(button, 10)

        local page = Instance.new("ScrollingFrame")
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 3
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.new()
        page.Size = UDim2.fromScale(1, 1)
        page.Visible = false
        page.Parent = content

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 4)
        padding.PaddingBottom = UDim.new(0, 10)
        padding.PaddingLeft = UDim.new(2, 0)
        padding.PaddingRight = UDim.new(2, 0)
        padding.Parent = page

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.Parent = page

        local Tab = {
            Button = button,
            Page = page
        }

        local function activate()
            for _, tab in pairs(Window.Tabs) do
                tab.Page.Visible = false
                tween(tab.Button, {
                    BackgroundTransparency = 0.96,
                    TextColor3 = Color3.fromRGB(190, 190, 200)
                }, 0.15):Play()
            end

            page.Visible = true
            tween(button, {
                BackgroundColor3 = Theme.Accent,
                BackgroundTransparency = 0.72,
                TextColor3 = Color3.fromRGB(255, 255, 255)
            }, 0.15):Play()
        end

        button.MouseButton1Click:Connect(activate)

        table.insert(Window.Tabs, Tab)

        if #Window.Tabs == 1 then
            activate()
        end

        function Tab:CreateSection(name)
            local section = Instance.new("Frame")
            section.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            section.BackgroundTransparency = 0.95
            section.AutomaticSize = Enum.AutomaticSize.Y
            section.Size = UDim2.new(1, -4, 0, 0)
            section.Parent = page
            corner(section, 14)
            stroke(section, 0.9)

            local sectionPadding = Instance.new("UIPadding")
            sectionPadding.PaddingTop = UDim.new(0, 10)
            sectionPadding.PaddingBottom = UDim.new(0, 10)
            sectionPadding.PaddingLeft = UDim.new(0, 10)
            sectionPadding.PaddingRight = UDim.new(0, 10)
            sectionPadding.Parent = section

            local sectionTitle = makeText(section, name or "Section", 13, true)
            sectionTitle.Size = UDim2.new(1, 0, 0, 22)

            local list = Instance.new("Frame")
            list.BackgroundTransparency = 1
            list.Position = UDim2.fromOffset(0, 28)
            list.Size = UDim2.new(1, 0, 0, 0)
            list.AutomaticSize = Enum.AutomaticSize.Y
            list.Parent = section

            local listLayout = Instance.new("UIListLayout")
            listLayout.Padding = UDim.new(0, 6)
            listLayout.Parent = list

            local Section = {}

            function Section:CreateButton(data)
                data = data or {}

                local b = Instance.new("TextButton")
                b.AutoButtonColor = false
                b.Text = data.Name or "Button"
                b.TextColor3 = Color3.fromRGB(235, 235, 240)
                b.TextSize = 13
                b.Font = Enum.Font.GothamMedium
                b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                b.BackgroundTransparency = 0.94
                b.Size = UDim2.new(1, 0, 0, 44)
                b.Parent = list
                corner(b, 11)

                b.MouseButton1Click:Connect(function()
                    tween(b, {BackgroundTransparency = 0.82}, 0.08):Play()
                    task.delay(0.08, function()
                        if b.Parent then
                            tween(b, {BackgroundTransparency = 0.94}, 0.15):Play()
                        end
                    end)

                    if typeof(data.Callback) == "function" then
                        task.spawn(data.Callback)
                    end
                end)

                return b
            end

            function Section:CreateToggle(data)
                data = data or {}

                local state = data.CurrentValue == true

                local b = Instance.new("TextButton")
                b.AutoButtonColor = false
                b.Text = ""
                b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                b.BackgroundTransparency = 0.94
                b.Size = UDim2.new(1, 0, 0, 48)
                b.Parent = list
                corner(b, 11)

                local label = makeText(b, data.Name or "Toggle", 13, true)
                label.Position = UDim2.fromOffset(12, 5)
                label.Size = UDim2.new(1, -75, 0, 20)

                local switch = Instance.new("Frame")
                switch.Size = UDim2.fromOffset(42, 22)
                switch.Position = UDim2.new(1, -54, 0.5, -11)
                switch.BackgroundColor3 = Color3.fromRGB(70, 70, 78)
                switch.Parent = b
                corner(switch, 11)

                local knob = Instance.new("Frame")
                knob.Size = UDim2.fromOffset(18, 18)
                knob.Position = UDim2.fromOffset(2, 2)
                knob.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
                knob.Parent = switch
                corner(knob, 9)

                local function update()
                    tween(switch, {
                        BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(70, 70, 78)
                    }, 0.15):Play()

                    tween(knob, {
                        Position = state
                            and UDim2.new(1, -20, 0, 2)
                            or UDim2.fromOffset(2, 2)
                    }, 0.15):Play()
                end

                b.MouseButton1Click:Connect(function()
                    state = not state
                    update()

                    if typeof(data.Callback) == "function" then
                        task.spawn(data.Callback, state)
                    end
                end)

                update()

                return {
                    Set = function(_, value)
                        state = value == true
                        update()
                    end,
                    Get = function()
                        return state
                    end
                }
            end

            function Section:CreateParagraph(data)
                data = data or {}

                local p = Instance.new("Frame")
                p.BackgroundTransparency = 1
                p.AutomaticSize = Enum.AutomaticSize.Y
                p.Size = UDim2.new(1, 0, 0, 45)
                p.Parent = list

                local t = makeText(p, data.Title or "Information", 13, true)
                t.Size = UDim2.new(1, 0, 0, 20)

                local c = makeText(p, data.Content or "", 11, false)
                c.TextColor3 = Color3.fromRGB(175, 175, 185)
                c.TextWrapped = true
                c.Position = UDim2.fromOffset(0, 22)
                c.Size = UDim2.new(1, 0, 0, 0)
                c.AutomaticSize = Enum.AutomaticSize.Y

                return p
            end

            return Section
        end

        return Tab
    end

    return Window
end

return NovaUI

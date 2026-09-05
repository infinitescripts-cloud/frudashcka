--[[
    BoraUI Beta 0.1
    Original Roblox/Luau UI library
    UI-only library: game-specific functionality belongs in the callbacks supplied by the user.

    Example:
        local BoraUI = loadstring(game:HttpGet("YOUR_BORAUI_URL"))()

        local Window = BoraUI:CreateWindow({
            Title = "BoraUI",
            Subtitle = "Beta 0.1",
            Size = UDim2.fromOffset(560, 430),
        })

        local Main = Window:CreateTab({
            Name = "Main",
            Icon = "home",
        })

        Main:CreateSection("Controls")

        Main:CreateButton({
            Name = "Hello",
            Description = "Example button",
            Callback = function()
                print("Hello from BoraUI")
            end,
        })

    This file intentionally contains no game-specific exploit/gameplay logic.
]]

local BoraUI = {}
BoraUI.__index = BoraUI

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local DEFAULT_THEME = {
    Background = Color3.fromRGB(20, 20, 24),
    Secondary = Color3.fromRGB(27, 27, 32),
    Tertiary = Color3.fromRGB(34, 34, 40),
    Card = Color3.fromRGB(29, 29, 35),
    Border = Color3.fromRGB(52, 52, 60),
    Text = Color3.fromRGB(245, 245, 248),
    MutedText = Color3.fromRGB(160, 160, 170),
    Accent = Color3.fromRGB(255, 170, 55),
    AccentText = Color3.fromRGB(18, 18, 20),
    Danger = Color3.fromRGB(235, 85, 85),
    Success = Color3.fromRGB(75, 205, 125),
    Shadow = Color3.fromRGB(0, 0, 0),
}

local THEMES = {
    Amber = {
        Accent = Color3.fromRGB(255, 170, 55),
        AccentText = Color3.fromRGB(18, 18, 20),
    },
    Ocean = {
        Accent = Color3.fromRGB(65, 165, 255),
        AccentText = Color3.fromRGB(10, 18, 25),
    },
    Mint = {
        Accent = Color3.fromRGB(75, 215, 155),
        AccentText = Color3.fromRGB(10, 22, 18),
    },
    Violet = {
        Accent = Color3.fromRGB(165, 115, 255),
        AccentText = Color3.fromRGB(18, 12, 28),
    },
    Rose = {
        Accent = Color3.fromRGB(255, 105, 155),
        AccentText = Color3.fromRGB(30, 10, 18),
    },
    Slate = {
        Accent = Color3.fromRGB(145, 165, 190),
        AccentText = Color3.fromRGB(12, 16, 22),
    },
}

local FONT_MAP = {
    Gotham = Enum.Font.Gotham,
    GothamBold = Enum.Font.GothamBold,
    GothamMedium = Enum.Font.GothamMedium,
    SourceSans = Enum.Font.SourceSans,
    SourceSansBold = Enum.Font.SourceSansBold,
    Code = Enum.Font.Code,
    BuilderSans = Enum.Font.BuilderSans,
    BuilderSansBold = Enum.Font.BuilderSansBold,
}

local ICONS = {
    home = "⌂",
    settings = "⚙",
    user = "●",
    users = "●",
    search = "⌕",
    close = "×",
    menu = "☰",
    check = "✓",
    plus = "+",
    minus = "−",
    chevron = "›",
    down = "⌄",
    up = "⌃",
    info = "ⓘ",
    warning = "!",
    refresh = "↻",
    star = "★",
    heart = "♥",
    play = "▶",
    pause = "Ⅱ",
    code = "</>",
    tools = "⚒",
    eye = "◉",
    lock = "▣",
    folder = "□",
}

local function copyTable(source)
    local result = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            result[key] = copyTable(value)
        else
            result[key] = value
        end
    end
    return result
end

local function mergeTheme(base, override)
    local result = copyTable(base)
    for key, value in pairs(override or {}) do
        result[key] = value
    end
    return result
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function tween(instance, duration, properties, style, direction)
    local info = TweenInfo.new(
        duration or 0.2,
        style or Enum.EasingStyle.Quint,
        direction or Enum.EasingDirection.Out
    )
    local animation = TweenService:Create(instance, info, properties)
    animation:Play()
    return animation
end

local function corner(parent, radius)
    local object = Instance.new("UICorner")
    object.CornerRadius = UDim.new(0, radius or 8)
    object.Parent = parent
    return object
end

local function stroke(parent, color, thickness, transparency)
    local object = Instance.new("UIStroke")
    object.Color = color or Color3.new(1, 1, 1)
    object.Thickness = thickness or 1
    object.Transparency = transparency or 0
    object.Parent = parent
    return object
end

local function padding(parent, left, right, top, bottom)
    local object = Instance.new("UIPadding")
    object.PaddingLeft = UDim.new(0, left or 0)
    object.PaddingRight = UDim.new(0, right or 0)
    object.PaddingTop = UDim.new(0, top or 0)
    object.PaddingBottom = UDim.new(0, bottom or 0)
    object.Parent = parent
    return object
end

local function listLayout(parent, paddingValue, horizontal)
    local object = Instance.new("UIListLayout")
    object.Padding = UDim.new(0, paddingValue or 0)
    object.SortOrder = Enum.SortOrder.LayoutOrder
    object.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
    object.Parent = parent
    return object
end

local function newSignal()
    local bindable = Instance.new("BindableEvent")
    return {
        Connect = function(_, callback)
            return bindable.Event:Connect(callback)
        end,
        Fire = function(_, ...)
            bindable:Fire(...)
        end,
        Destroy = function()
            bindable:Destroy()
        end,
    }
end

local function getGuiParent()
    local success, result = pcall(function()
        return CoreGui
    end)
    if success and result then
        return result
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function resolveIcon(icon)
    if type(icon) ~= "string" then
        return ""
    end
    return ICONS[icon] or icon
end

local function createText(parent, properties)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.Text = properties.Text or ""
    label.TextColor3 = properties.TextColor3 or DEFAULT_THEME.Text
    label.TextSize = properties.TextSize or 14
    label.Font = properties.Font or Enum.Font.Gotham
    label.TextXAlignment = properties.TextXAlignment or Enum.TextXAlignment.Left
    label.TextYAlignment = properties.TextYAlignment or Enum.TextYAlignment.Center
    label.TextWrapped = properties.TextWrapped or false
    label.TextTruncate = properties.TextTruncate or Enum.TextTruncate.None
    label.Size = properties.Size or UDim2.new(1, 0, 0, 20)
    label.Position = properties.Position or UDim2.new()
    label.AnchorPoint = properties.AnchorPoint or Vector2.zero
    label.LayoutOrder = properties.LayoutOrder or 0
    label.Parent = parent
    return label
end

function BoraUI:_track(object)
    table.insert(self._objects, object)
    return object
end

function BoraUI:_connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self._connections, connection)
    return connection
end

function BoraUI:_refreshTheme()
    for _, callback in ipairs(self._themeCallbacks) do
        task.spawn(callback, self.Theme)
    end
end

function BoraUI:SetTheme(nameOrTable)
    if type(nameOrTable) == "string" then
        local selected = THEMES[nameOrTable]
        if not selected then
            return false
        end
        self.Theme = mergeTheme(DEFAULT_THEME, selected)
        self.ThemeName = nameOrTable
    elseif type(nameOrTable) == "table" then
        self.Theme = mergeTheme(DEFAULT_THEME, nameOrTable)
        self.ThemeName = "Custom"
    else
        return false
    end
    self:_refreshTheme()
    return true
end

function BoraUI:SetFont(font)
    local selected = FONT_MAP[font] or font
    if typeof(selected) ~= "EnumItem" then
        return false
    end
    self.Font = selected
    for _, callback in ipairs(self._fontCallbacks) do
        task.spawn(callback, selected)
    end
    return true
end

function BoraUI:RegisterThemeCallback(callback)
    if type(callback) ~= "function" then
        return nil
    end
    table.insert(self._themeCallbacks, callback)
    callback(self.Theme)
    return callback
end

function BoraUI:RegisterFontCallback(callback)
    if type(callback) ~= "function" then
        return nil
    end
    table.insert(self._fontCallbacks, callback)
    callback(self.Font)
    return callback
end

function BoraUI:Notify(options)
    options = options or {}
    local title = tostring(options.Title or "BoraUI")
    local content = tostring(options.Content or options.Description or "")
    local duration = tonumber(options.Duration) or 4
    local notificationType = tostring(options.Type or "Info")

    local color = self.Theme.Accent
    if notificationType == "Success" then
        color = self.Theme.Success
    elseif notificationType == "Error" or notificationType == "Danger" then
        color = self.Theme.Danger
    end

    local card = Instance.new("Frame")
    card.BackgroundColor3 = self.Theme.Card
    card.BorderSizePixel = 0
    card.Size = UDim2.new(1, 0, 0, 76)
    card.ClipsDescendants = true
    card.Parent = self._notificationHolder
    corner(card, 10)
    stroke(card, self.Theme.Border, 1, 0.15)

    local bar = Instance.new("Frame")
    bar.BackgroundColor3 = color
    bar.BorderSizePixel = 0
    bar.Size = UDim2.new(0, 4, 1, 0)
    bar.Parent = card
    corner(bar, 4)

    local titleLabel = createText(card, {
        Text = title,
        TextSize = 14,
        Font = self.FontBold,
        TextColor3 = self.Theme.Text,
        Position = UDim2.fromOffset(16, 8),
        Size = UDim2.new(1, -28, 0, 22),
    })

    local contentLabel = createText(card, {
        Text = content,
        TextSize = 12,
        Font = self.Font,
        TextColor3 = self.Theme.MutedText,
        Position = UDim2.fromOffset(16, 31),
        Size = UDim2.new(1, -28, 0, 35),
        TextWrapped = true,
    })

    card.Position = UDim2.new(1, 24, 0, 0)
    tween(card, 0.3, {Position = UDim2.new(0, 0, 0, 0)})

    task.delay(math.max(duration, 0.5), function()
        if card.Parent then
            tween(card, 0.25, {
                Position = UDim2.new(1, 24, 0, 0),
                BackgroundTransparency = 1,
            })
            task.wait(0.3)
            card:Destroy()
        end
    end)

    return card
end

function BoraUI:_createRoot()
    local gui = Instance.new("ScreenGui")
    gui.Name = "BoraUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    gui.Parent = getGuiParent()
    self.Gui = self:_track(gui)

    local main = Instance.new("Frame")
    main.Name = "Window"
    main.BackgroundColor3 = self.Theme.Background
    main.BorderSizePixel = 0
    main.Size = self.Options.Size
    main.Position = UDim2.fromScale(0.5, 0.5)
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.ClipsDescendants = true
    main.Parent = gui
    self.Main = self:_track(main)
    corner(main, 12)
    self._mainStroke = stroke(main, self.Theme.Border, 1, 0)

    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.BackgroundTransparency = 1
    shadow.Position = UDim2.fromScale(0.5, 0.5)
    shadow.Size = UDim2.new(1, 50, 1, 50)
    shadow.ZIndex = 0
    shadow.Image = "rbxassetid://6014261993"
    shadow.ImageTransparency = 0.55
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(49, 49, 450, 450)
    shadow.Parent = gui
    self._shadow = self:_track(shadow)
    main.ZIndex = 2

    local top = Instance.new("Frame")
    top.Name = "Topbar"
    top.BackgroundColor3 = self.Theme.Secondary
    top.BorderSizePixel = 0
    top.Size = UDim2.new(1, 0, 0, 58)
    top.ZIndex = 3
    top.Parent = main
    self.Topbar = top

    local title = createText(top, {
        Text = self.Options.Title,
        TextSize = 16,
        Font = self.FontBold,
        TextColor3 = self.Theme.Text,
        Position = UDim2.fromOffset(18, 7),
        Size = UDim2.new(1, -145, 0, 25),
    })
    self.TitleLabel = title

    local subtitle = createText(top, {
        Text = self.Options.Subtitle,
        TextSize = 11,
        Font = self.Font,
        TextColor3 = self.Theme.MutedText,
        Position = UDim2.fromOffset(18, 31),
        Size = UDim2.new(1, -145, 0, 17),
    })
    self.SubtitleLabel = subtitle

    local minimize = Instance.new("TextButton")
    minimize.Name = "Minimize"
    minimize.AutoButtonColor = false
    minimize.BackgroundColor3 = self.Theme.Tertiary
    minimize.BorderSizePixel = 0
    minimize.Text = "−"
    minimize.TextColor3 = self.Theme.Text
    minimize.TextSize = 20
    minimize.Font = self.FontBold
    minimize.Size = UDim2.fromOffset(34, 32)
    minimize.Position = UDim2.new(1, -80, 0, 13)
    minimize.ZIndex = 4
    minimize.Parent = top
    corner(minimize, 8)

    local close = Instance.new("TextButton")
    close.Name = "Close"
    close.AutoButtonColor = false
    close.BackgroundColor3 = self.Theme.Tertiary
    close.BorderSizePixel = 0
    close.Text = "×"
    close.TextColor3 = self.Theme.Text
    close.TextSize = 20
    close.Font = self.FontBold
    close.Size = UDim2.fromOffset(34, 32)
    close.Position = UDim2.new(1, -40, 0, 13)
    close.ZIndex = 4
    close.Parent = top
    corner(close, 8)

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    body.Position = UDim2.fromOffset(0, 58)
    body.Size = UDim2.new(1, 0, 1, -58)
    body.Parent = main
    self.Body = body

    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.BackgroundColor3 = self.Theme.Secondary
    sidebar.BorderSizePixel = 0
    sidebar.Size = UDim2.new(0, self.Options.SidebarWidth, 1, 0)
    sidebar.Parent = body
    self.Sidebar = sidebar

    local tabList = Instance.new("ScrollingFrame")
    tabList.Name = "TabList"
    tabList.BackgroundTransparency = 1
    tabList.BorderSizePixel = 0
    tabList.Size = UDim2.new(1, 0, 1, 0)
    tabList.CanvasSize = UDim2.new()
    tabList.ScrollBarThickness = 2
    tabList.ScrollBarImageColor3 = self.Theme.Border
    tabList.Parent = sidebar
    padding(tabList, 8, 8, 10, 10)
    local tabLayout = listLayout(tabList, 5)
    self.TabList = tabList
    self.TabLayout = tabLayout

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.Position = UDim2.new(0, self.Options.SidebarWidth, 0, 0)
    content.Size = UDim2.new(1, -self.Options.SidebarWidth, 1, 0)
    content.Parent = body
    self.Content = content

    local search = Instance.new("TextBox")
    search.Name = "Search"
    search.BackgroundColor3 = self.Theme.Card
    search.BorderSizePixel = 0
    search.PlaceholderText = "Search..."
    search.PlaceholderColor3 = self.Theme.MutedText
    search.Text = ""
    search.TextColor3 = self.Theme.Text
    search.TextSize = 12
    search.Font = self.Font
    search.ClearTextOnFocus = false
    search.Size = UDim2.new(1, -20, 0, 34)
    search.Position = UDim2.fromOffset(10, 10)
    search.Parent = content
    corner(search, 8)
    stroke(search, self.Theme.Border, 1, 0.2)
    padding(search, 34, 8, 0, 0)
    self.Search = search

    local searchIcon = createText(content, {
        Text = resolveIcon("search"),
        TextSize = 18,
        Font = self.FontBold,
        TextColor3 = self.Theme.MutedText,
        Position = UDim2.fromOffset(18, 10),
        Size = UDim2.fromOffset(22, 34),
        ZIndex = 2,
    })
    self.SearchIcon = searchIcon

    local pageHolder = Instance.new("Frame")
    pageHolder.Name = "Pages"
    pageHolder.BackgroundTransparency = 1
    pageHolder.BorderSizePixel = 0
    pageHolder.Position = UDim2.fromOffset(10, 54)
    pageHolder.Size = UDim2.new(1, -20, 1, -64)
    pageHolder.Parent = content
    self.PageHolder = pageHolder

    local notifications = Instance.new("Frame")
    notifications.Name = "Notifications"
    notifications.BackgroundTransparency = 1
    notifications.AnchorPoint = Vector2.new(1, 0)
    notifications.Position = UDim2.new(1, -14, 0, 14)
    notifications.Size = UDim2.fromOffset(300, 0)
    notifications.AutomaticSize = Enum.AutomaticSize.Y
    notifications.ZIndex = 50
    notifications.Parent = gui
    listLayout(notifications, 8)
    self._notificationHolder = notifications

    local pill = Instance.new("TextButton")
    pill.Name = "TogglePill"
    pill.AutoButtonColor = false
    pill.BackgroundColor3 = self.Theme.Secondary
    pill.BorderSizePixel = 0
    pill.Text = self.Options.PillText
    pill.TextColor3 = self.Theme.Text
    pill.TextSize = 12
    pill.Font = self.FontBold
    pill.Size = UDim2.fromOffset(110, 34)
    pill.Position = UDim2.new(0.5, -55, 0, 12)
    pill.Visible = false
    pill.ZIndex = 60
    pill.Parent = gui
    corner(pill, 17)
    stroke(pill, self.Theme.Border, 1, 0)
    self.TogglePill = pill

    local function updateShadow()
        if self.Main and self._shadow then
            self._shadow.Position = self.Main.Position
            self._shadow.Size = self.Main.Size + UDim2.fromOffset(50, 50)
        end
    end

    updateShadow()

    self:_connect(minimize.MouseButton1Click, function()
        self:SetMinimized(not self.Minimized)
    end)

    self:_connect(close.MouseButton1Click, function()
        self:Destroy()
    end)

    self:_connect(pill.MouseButton1Click, function()
        self:SetMinimized(false)
    end)

    self:_connect(search:GetPropertyChangedSignal("Text"), function()
        self:_filter(self.Search.Text)
    end)

    local dragging = false
    local dragStart
    local startPosition

    self:_connect(top.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = main.Position
        end
    end)

    self:_connect(UserInputService.InputChanged, function(input)
        if not dragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
        updateShadow()
    end)

    self:_connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    self:RegisterThemeCallback(function(theme)
        main.BackgroundColor3 = theme.Background
        top.BackgroundColor3 = theme.Secondary
        sidebar.BackgroundColor3 = theme.Secondary
        search.BackgroundColor3 = theme.Card
        search.TextColor3 = theme.Text
        search.PlaceholderColor3 = theme.MutedText
        self._mainStroke.Color = theme.Border
        pill.BackgroundColor3 = theme.Secondary
        pill.TextColor3 = theme.Text
    end)

    return main
end

function BoraUI:_filter(query)
    query = string.lower(tostring(query or ""))
    for _, tab in ipairs(self.Tabs) do
        tab:_filter(query)
    end
end

function BoraUI:SetMinimized(state)
    state = state == true
    if self.Destroyed then
        return
    end

    if state == self.Minimized then
        return
    end

    self.Minimized = state

    if state then
        self.TogglePill.Visible = true
        self.TogglePill.Text = self.Options.PillText
        self.Main.Visible = false
        self._shadow.Visible = false
    else
        self.Main.Visible = true
        self._shadow.Visible = true
        self.TogglePill.Visible = false
        self.Main.Size = UDim2.fromOffset(
            math.max(self.Options.Size.X.Offset - 20, 260),
            math.max(self.Options.Size.Y.Offset - 20, 220)
        )
        tween(self.Main, 0.25, {Size = self.Options.Size})
    end
end

function BoraUI:_createTabButton(tab)
    local button = Instance.new("TextButton")
    button.Name = tab.Name .. "Button"
    button.AutoButtonColor = false
    button.BackgroundColor3 = self.Theme.Card
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 38)
    button.Text = ""
    button.Parent = self.TabList
    corner(button, 8)

    local icon = createText(button, {
        Text = resolveIcon(tab.Icon),
        TextSize = 15,
        Font = self.FontBold,
        TextColor3 = self.Theme.MutedText,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.fromOffset(22, 38),
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    local label = createText(button, {
        Text = tab.Name,
        TextSize = 12,
        Font = self.FontMedium,
        TextColor3 = self.Theme.MutedText,
        Position = UDim2.fromOffset(38, 0),
        Size = UDim2.new(1, -44, 1, 0),
    })

    tab.Button = button
    tab.IconLabel = icon
    tab.NameLabel = label

    self:_connect(button.MouseButton1Click, function()
        self:SelectTab(tab)
    end)

    self:RegisterThemeCallback(function(theme)
        if tab.Selected then
            button.BackgroundColor3 = theme.Accent
            button.BackgroundTransparency = 0
            icon.TextColor3 = theme.AccentText
            label.TextColor3 = theme.AccentText
        else
            button.BackgroundColor3 = theme.Card
            button.BackgroundTransparency = 1
            icon.TextColor3 = theme.MutedText
            label.TextColor3 = theme.MutedText
        end
    end)

    return button
end

function BoraUI:SelectTab(tab)
    if self.Destroyed or not tab then
        return
    end

    for _, item in ipairs(self.Tabs) do
        item.Selected = item == tab
        if item.Button then
            if item.Selected then
                tween(item.Button, 0.15, {
                    BackgroundColor3 = self.Theme.Accent,
                    BackgroundTransparency = 0,
                })
                item.IconLabel.TextColor3 = self.Theme.AccentText
                item.NameLabel.TextColor3 = self.Theme.AccentText
            else
                tween(item.Button, 0.15, {
                    BackgroundColor3 = self.Theme.Card,
                    BackgroundTransparency = 1,
                })
                item.IconLabel.TextColor3 = self.Theme.MutedText
                item.NameLabel.TextColor3 = self.Theme.MutedText
            end
        end
        if item.Page then
            item.Page.Visible = item.Selected
        end
    end

    self.SelectedTab = tab
end

function BoraUI:CreateTab(options)
    options = options or {}
    assert(type(options.Name) == "string", "BoraUI:CreateTab requires a Name")

    local tab = {
        Window = self,
        Name = options.Name,
        Icon = options.Icon or "",
        Elements = {},
        Sections = {},
        Selected = false,
        _layoutOrder = 0,
    }
    setmetatable(tab, {__index = TabMethods})

    local page = Instance.new("ScrollingFrame")
    page.Name = options.Name .. "Page"
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Size = UDim2.fromScale(1, 1)
    page.CanvasSize = UDim2.new()
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = self.Theme.Border
    page.Visible = false
    page.Parent = self.PageHolder
    padding(page, 2, 4, 2, 10)
    local layout = listLayout(page, 8)
    tab.Page = page
    tab.Layout = layout

    self:_createTabButton(tab)
    table.insert(self.Tabs, tab)

    self:RegisterThemeCallback(function(theme)
        page.ScrollBarImageColor3 = theme.Border
    end)

    if #self.Tabs == 1 then
        self:SelectTab(tab)
    end

    return tab
end

local function addElement(tab, element)
    tab._layoutOrder += 1
    element.LayoutOrder = tab._layoutOrder
    table.insert(tab.Elements, element)
    return element
end

TabMethods = {}

function TabMethods:_createContainer(height)
    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = self.Window.Theme.Card
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(1, -2, 0, height)
    frame.Parent = self.Page
    corner(frame, 9)
    stroke(frame, self.Window.Theme.Border, 1, 0.2)
    addElement(self, frame)

    self.Window:RegisterThemeCallback(function(theme)
        if frame.Parent then
            frame.BackgroundColor3 = theme.Card
            local uiStroke = frame:FindFirstChildOfClass("UIStroke")
            if uiStroke then
                uiStroke.Color = theme.Border
            end
        end
    end)

    return frame
end

function TabMethods:CreateSection(name)
    local section = Instance.new("Frame")
    section.Name = tostring(name or "Section")
    section.BackgroundTransparency = 1
    section.BorderSizePixel = 0
    section.Size = UDim2.new(1, -2, 0, 24)
    section.Parent = self.Page
    addElement(self, section)

    createText(section, {
        Text = tostring(name or "Section"),
        TextSize = 11,
        Font = self.Window.FontBold,
        TextColor3 = self.Window.Theme.MutedText,
        Size = UDim2.new(1, 0, 1, 0),
    })

    table.insert(self.Sections, section)
    return section
end

function TabMethods:CreateLabel(options)
    options = type(options) == "table" and options or {Text = tostring(options)}
    local text = tostring(options.Text or "")
    local height = options.Height or 34
    local frame = self:_createContainer(height)
    local label = createText(frame, {
        Text = text,
        TextSize = options.TextSize or 12,
        Font = self.Window.Font,
        TextColor3 = options.Color or self.Window.Theme.MutedText,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 1, 0),
        TextWrapped = true,
    })

    self.Window:RegisterThemeCallback(function(theme)
        if not options.Color then
            label.TextColor3 = theme.MutedText
        end
    end)

    return {
        Instance = frame,
        Label = label,
        SetText = function(_, value)
            label.Text = tostring(value)
        end,
        Destroy = function()
            frame:Destroy()
        end,
    }
end

function TabMethods:CreateParagraph(options)
    options = options or {}
    local title = tostring(options.Title or "")
    local content = tostring(options.Content or options.Text or "")
    local frame = self:_createContainer(options.Height or 72)

    createText(frame, {
        Text = title,
        TextSize = 13,
        Font = self.Window.FontBold,
        TextColor3 = self.Window.Theme.Text,
        Position = UDim2.fromOffset(12, 8),
        Size = UDim2.new(1, -24, 0, 20),
    })

    local body = createText(frame, {
        Text = content,
        TextSize = 11,
        Font = self.Window.Font,
        TextColor3 = self.Window.Theme.MutedText,
        Position = UDim2.fromOffset(12, 29),
        Size = UDim2.new(1, -24, 1, -34),
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
    })

    return {
        Instance = frame,
        SetTitle = function(_, value)
            frame:FindFirstChildOfClass("TextLabel").Text = tostring(value)
        end,
        SetContent = function(_, value)
            body.Text = tostring(value)
        end,
        Destroy = function()
            frame:Destroy()
        end,
    }
end

function TabMethods:CreateButton(options)
    options = options or {}
    local frame = self:_createContainer(options.Height or 52)

    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.Text = ""
    button.Size = UDim2.fromScale(1, 1)
    button.Parent = frame

    local title = createText(button, {
        Text = tostring(options.Name or "Button"),
        TextSize = 13,
        Font = self.Window.FontMedium,
        TextColor3 = self.Window.Theme.Text,
        Position = UDim2.fromOffset(12, 6),
        Size = UDim2.new(1, -52, 0, 20),
    })

    local description = createText(button, {
        Text = tostring(options.Description or ""),
        TextSize = 10,
        Font = self.Window.Font,
        TextColor3 = self.Window.Theme.MutedText,
        Position = UDim2.fromOffset(12, 27),
        Size = UDim2.new(1, -52, 0, 17),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local arrow = createText(button, {
        Text = resolveIcon("chevron"),
        TextSize = 22,
        Font = self.Window.FontBold,
        TextColor3 = self.Window.Theme.MutedText,
        Position = UDim2.new(1, -36, 0, 0),
        Size = UDim2.fromOffset(28, 52),
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    local callback = type(options.Callback) == "function" and options.Callback or function() end
    self.Window:_connect(button.MouseButton1Click, function()
        tween(frame, 0.08, {BackgroundColor3 = self.Window.Theme.Tertiary})
        task.delay(0.08, function()
            if frame.Parent then
                tween(frame, 0.15, {BackgroundColor3 = self.Window.Theme.Card})
            end
        end)
        task.spawn(callback)
    end)

    self.Window:RegisterThemeCallback(function(theme)
        title.TextColor3 = theme.Text
        description.TextColor3 = theme.MutedText
        arrow.TextColor3 = theme.MutedText
        frame.BackgroundColor3 = theme.Card
    end)

    return {
        Instance = frame,
        Button = button,
        SetText = function(_, value)
            title.Text = tostring(value)
        end,
        SetDescription = function(_, value)
            description.Text = tostring(value)
        end,
        Destroy = function()
            frame:Destroy()
        end,
    }
end

function TabMethods:CreateToggle(options)
    options = options or {}
    local state = options.CurrentValue == true
    local frame = self:_createContainer(options.Height or 54)

    local title = createText(frame, {
        Text = tostring(options.Name or "Toggle"),
        TextSize = 13,
        Font = self.Window.FontMedium,
        TextColor3 = self.Window.Theme.Text,
        Position = UDim2.fromOffset(12, 7),
        Size = UDim2.new(1, -80, 0, 20),
    })

    local description = createText(frame, {
        Text = tostring(options.Description or ""),
        TextSize = 10,
        Font = self.Window.Font,
        TextColor3 = self.Window.Theme.MutedText,
        Position = UDim2.fromOffset(12, 28),
        Size = UDim2.new(1, -80, 0, 16),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local switch = Instance.new("TextButton")
    switch.AutoButtonColor = false
    switch.BackgroundColor3 = self.Window.Theme.Tertiary
    switch.BorderSizePixel = 0
    switch.Text = ""
    switch.Size = UDim2.fromOffset(44, 24)
    switch.Position = UDim2.new(1, -56, 0.5, -12)
    switch.Parent = frame
    corner(switch, 12)

    local knob = Instance.new("Frame")
    knob.BackgroundColor3 = self.Window.Theme.MutedText
    knob.BorderSizePixel = 0
    knob.Size = UDim2.fromOffset(18, 18)
    knob.Position = UDim2.fromOffset(3, 3)
    knob.Parent = switch
    corner(knob, 9)

    local callback = type(options.Callback) == "function" and options.Callback or function() end
    local changed = newSignal()

    local function render(animated)
        local x = state and 23 or 3
        local background = state and self.Window.Theme.Accent or self.Window.Theme.Tertiary
        local knobColor = state and self.Window.Theme.AccentText or self.Window.Theme.MutedText

        if animated then
            tween(switch, 0.15, {BackgroundColor3 = background})
            tween(knob, 0.15, {
                Position = UDim2.fromOffset(x, 3),
                BackgroundColor3 = knobColor,
            })
        else
            switch.BackgroundColor3 = background
            knob.Position = UDim2.fromOffset(x, 3)
            knob.BackgroundColor3 = knobColor
        end
    end

    self.Window:_connect(switch.MouseButton1Click, function()
        state = not state
        render(true)
        changed:Fire(state)
        task.spawn(callback, state)
    end)

    self.Window:RegisterThemeCallback(function()
        render(false)
        title.TextColor3 = self.Window.Theme.Text
        description.TextColor3 = self.Window.Theme.MutedText
    end)

    render(false)

    return {
        Instance = frame,
        SetValue = function(_, value, fire)
            state = value == true
            render(true)
            if fire ~= false then
                changed:Fire(state)
                task.spawn(callback, state)
            end
        end,
        GetValue = function()
            return state
        end,
        OnChanged = changed,
        Destroy = function()
            changed:Destroy()
            frame:Destroy()
        end,
    }
end

function TabMethods:CreateSlider(options)
    options = options or {}
    local minimum = tonumber(options.Min) or 0
    local maximum = tonumber(options.Max) or 100
    local increment = tonumber(options.Increment) or 1
    if maximum <= minimum then
        maximum = minimum + 1
    end

    local value = tonumber(options.CurrentValue)
        or tonumber(options.Default)
        or minimum
    value = clamp(value, minimum, maximum)

    local frame = self:_createContainer(options.Height or 68)

    local title = createText(frame, {
        Text = tostring(options.Name or "Slider"),
        TextSize = 13,
        Font = self.Window.FontMedium,
        TextColor3 = self.Window.Theme.Text,
        Position = UDim2.fromOffset(12, 6),
        Size = UDim2.new(1, -90, 0, 20),
    })

    local valueLabel = createText(frame, {
        Text = tostring(value),
        TextSize = 11,
        Font = self.Window.FontBold,
        TextColor3 = self.Window.Theme.Accent,
        Position = UDim2.new(1, -78, 0, 6),
        Size = UDim2.fromOffset(66, 20),
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local track = Instance.new("Frame")
    track.BackgroundColor3 = self.Window.Theme.Tertiary
    track.BorderSizePixel = 0
    track.Size = UDim2.new(1, -24, 0, 7)
    track.Position = UDim2.fromOffset(12, 43)
    track.Parent = frame
    corner(track, 4)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = self.Window.Theme.Accent
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.Parent = track
    corner(fill, 4)

    local knob = Instance.new("Frame")
    knob.BackgroundColor3 = self.Window.Theme.Accent
    knob.BorderSizePixel = 0
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Size = UDim2.fromOffset(14, 14)
    knob.Position = UDim2.fromScale(0, 0.5)
    knob.Parent = track
    corner(knob, 7)

    local dragging = false
    local callback = type(options.Callback) == "function" and options.Callback or function() end
    local changed = newSignal()

    local function roundIncrement(number)
        return math.floor(number / increment + 0.5) * increment
    end

    local function setValue(newValue, fire, animated)
        newValue = clamp(roundIncrement(newValue), minimum, maximum)
        value = newValue

        local alpha = (value - minimum) / (maximum - minimum)
        local text = tostring(value)
        if math.floor(value) == value then
            text = string.format("%.0f", value)
        end
        valueLabel.Text = text

        if animated then
            tween(fill, 0.1, {Size = UDim2.new(alpha, 0, 1, 0)})
            tween(knob, 0.1, {Position = UDim2.new(alpha, 0, 0.5, 0)})
        else
            fill.Size = UDim2.new(alpha, 0, 1, 0)
            knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        end

        if fire then
            changed:Fire(value)
            task.spawn(callback, value)
        end
    end

    local function fromInput(input)
        local relative = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
        setValue(minimum + (maximum - minimum) * clamp(relative, 0, 1), true, true)
    end

    self.Window:_connect(track.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromInput(input)
        end
    end)

    self.Window:_connect(UserInputService.InputChanged, function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            fromInput(input)
        end
    end)

    self.Window:_connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    self.Window:RegisterThemeCallback(function(theme)
        title.TextColor3 = theme.Text
        valueLabel.TextColor3 = theme.Accent
        track.BackgroundColor3 = theme.Tertiary
        fill.BackgroundColor3 = theme.Accent
        knob.BackgroundColor3 = theme.Accent
    end)

    setValue(value, false, false)

    return {
        Instance = frame,
        SetValue = function(_, newValue, fire)
            setValue(tonumber(newValue) or minimum, fire ~= false, true)
        end,
        GetValue = function()
            return value
        end,
        OnChanged = changed,
        Destroy = function()
            changed:Destroy()
            frame:Destroy()
        end,
    }
end

function TabMethods:CreateTextbox(options)
    options = options or {}
    local frame = self:_createContainer(options.Height or 54)

    local title = createText(frame, {
        Text = tostring(options.Name or "Textbox"),
        TextSize = 13,
        Font = self.Window.FontMedium,
        TextColor3 = self.Window.Theme.Text,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(0.42, -12, 1, 0),
    })

    local input = Instance.new("TextBox")
    input.BackgroundColor3 = self.Window.Theme.Tertiary
    input.BorderSizePixel = 0
    input.ClearTextOnFocus = options.ClearOnFocus == true
    input.PlaceholderText = tostring(options.PlaceholderText or "Enter text...")
    input.PlaceholderColor3 = self.Window.Theme.MutedText
    input.Text = tostring(options.Default or "")
    input.TextColor3 = self.Window.Theme.Text
    input.TextSize = 11
    input.Font = self.Window.Font
    input.TextXAlignment = Enum.TextXAlignment.Left
    input.Size = UDim2.new(0.55, -4, 0, 32)
    input.Position = UDim2.new(0.45, 0, 0.5, -16)
    input.Parent = frame
    corner(input, 7)
    padding(input, 10, 8, 0, 0)

    local callback = type(options.Callback) == "function" and options.Callback or function() end
    local changed = newSignal()

    self.Window:_connect(input.FocusLost, function(enterPressed)
        changed:Fire(input.Text)
        task.spawn(callback, input.Text, enterPressed)
    end)

    self.Window:RegisterThemeCallback(function(theme)
        title.TextColor3 = theme.Text
        input.BackgroundColor3 = theme.Tertiary
        input.TextColor3 = theme.Text
        input.PlaceholderColor3 = theme.MutedText
    end)

    return {
        Instance = frame,
        Input = input,
        SetValue = function(_, value)
            input.Text = tostring(value)
        end,
        GetValue = function()
            return input.Text
        end,
        OnChanged = changed,
        Destroy = function()
            changed:Destroy()
            frame:Destroy()
        end,
    }
end

function TabMethods:CreateDropdown(options)
    options = options or {}
    local values = options.Options or options.Values or {}
    local selected = options.CurrentOption or options.Default
    if selected == nil and #values > 0 then
        selected = values[1]
    end

    local expanded = false
    local frame = self:_createContainer(52)

    local title = createText(frame, {
        Text = tostring(options.Name or "Dropdown"),
        TextSize = 13,
        Font = self.Window.FontMedium,
        TextColor3 = self.Window.Theme.Text,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(0.42, -12, 1, 0),
    })

    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    button.BackgroundColor3 = self.Window.Theme.Tertiary
    button.BorderSizePixel = 0
    button.Text = ""
    button.Size = UDim2.new(0.55, -4, 0, 32)
    button.Position = UDim2.new(0.45, 0, 0.5, -16)
    button.Parent = frame
    corner(button, 7)

    local valueLabel = createText(button, {
        Text = tostring(selected or "Select..."),
        TextSize = 11,
        Font = self.Window.Font,
        TextColor3 = self.Window.Theme.Text,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -34, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local arrow = createText(button, {
        Text = resolveIcon("down"),
        TextSize = 16,
        Font = self.Window.FontBold,
        TextColor3 = self.Window.Theme.MutedText,
        Position = UDim2.new(1, -28, 0, 0),
        Size = UDim2.fromOffset(22, 32),
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    local list = Instance.new("Frame")
    list.BackgroundColor3 = self.Window.Theme.Tertiary
    list.BorderSizePixel = 0
    list.Visible = false
    list.Size = UDim2.new(0.55, -4, 0, 0)
    list.Position = UDim2.new(0.45, 0, 1, 4)
    list.ZIndex = 10
    list.Parent = frame
    corner(list, 7)
    stroke(list, self.Window.Theme.Border, 1, 0)
    local listLayoutObject = listLayout(list, 3)
    padding(list, 4, 4, 4, 4)

    local callback = type(options.Callback) == "function" and options.Callback or function() end
    local changed = newSignal()

    local function rebuild()
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        for index, option in ipairs(values) do
            local item = Instance.new("TextButton")
            item.Name = "Option_" .. index
            item.AutoButtonColor = false
            item.BackgroundColor3 = self.Window.Theme.Card
            item.BorderSizePixel = 0
            item.Text = tostring(option)
            item.TextColor3 = self.Window.Theme.Text
            item.TextSize = 11
            item.Font = self.Window.Font
            item.Size = UDim2.new(1, 0, 0, 28)
            item.ZIndex = 11
            item.Parent = list
            corner(item, 5)

            self.Window:_connect(item.MouseButton1Click, function()
                selected = option
                valueLabel.Text = tostring(option)
                expanded = false
                list.Visible = false
                arrow.Text = resolveIcon("down")
                changed:Fire(selected)
                task.spawn(callback, selected)
            end)
        end

        local height = math.min(#values * 31 + 8, 160)
        list.Size = UDim2.new(0.55, -4, 0, height)
    end

    self.Window:_connect(button.MouseButton1Click, function()
        expanded = not expanded
        list.Visible = expanded
        arrow.Text = resolveIcon(expanded and "up" or "down")
        if expanded then
            rebuild()
        end
    end)

    self.Window:RegisterThemeCallback(function(theme)
        title.TextColor3 = theme.Text
        button.BackgroundColor3 = theme.Tertiary
        valueLabel.TextColor3 = theme.Text
        arrow.TextColor3 = theme.MutedText
        list.BackgroundColor3 = theme.Tertiary
        local uiStroke = list:FindFirstChildOfClass("UIStroke")
        if uiStroke then
            uiStroke.Color = theme.Border
        end
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = theme.Card
                child.TextColor3 = theme.Text
            end
        end
    end)

    rebuild()

    return {
        Instance = frame,
        SetValue = function(_, value, fire)
            selected = value
            valueLabel.Text = tostring(value)
            if fire ~= false then
                changed:Fire(selected)
                task.spawn(callback, selected)
            end
        end,
        GetValue = function()
            return selected
        end,
        SetOptions = function(_, newValues)
            values = newValues or {}
            rebuild()
        end,
        OnChanged = changed,
        Destroy = function()
            changed:Destroy()
            frame:Destroy()
        end,
    }
end

function TabMethods:CreateKeybind(options)
    options = options or {}
    local current = options.CurrentKeybind or options.Default
    local listening = false
    local frame = self:_createContainer(options.Height or 52)

    local title = createText(frame, {
        Text = tostring(options.Name or "Keybind"),
        TextSize = 13,
        Font = self.Window.FontMedium,
        TextColor3 = self.Window.Theme.Text,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(0.5, -12, 1, 0),
    })

    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    button.BackgroundColor3 = self.Window.Theme.Tertiary
    button.BorderSizePixel = 0
    button.Text = tostring(current or "None")
    button.TextColor3 = self.Window.Theme.Text
    button.TextSize = 11
    button.Font = self.Window.FontBold
    button.Size = UDim2.new(0.45, -4, 0, 32)
    button.Position = UDim2.new(0.55, 0, 0.5, -16)
    button.Parent = frame
    corner(button, 7)

    local callback = type(options.Callback) == "function" and options.Callback or function() end
    local changed = newSignal()

    self.Window:_connect(button.MouseButton1Click, function()
        listening = not listening
        button.Text = listening and "Press a key..." or tostring(current or "None")
    end)

    self.Window:_connect(UserInputService.InputBegan, function(input, processed)
        if processed or not listening then
            return
        end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            current = input.KeyCode
            listening = false
            button.Text = current.Name
            changed:Fire(current)
            task.spawn(callback, current)
        end
    end)

    self.Window:RegisterThemeCallback(function(theme)
        title.TextColor3 = theme.Text
        button.BackgroundColor3 = theme.Tertiary
        button.TextColor3 = theme.Text
    end)

    return {
        Instance = frame,
        SetValue = function(_, value, fire)
            current = value
            button.Text = typeof(value) == "EnumItem" and value.Name or tostring(value)
            if fire ~= false then
                changed:Fire(value)
                task.spawn(callback, value)
            end
        end,
        GetValue = function()
            return current
        end,
        OnChanged = changed,
        Destroy = function()
            changed:Destroy()
            frame:Destroy()
        end,
    }
end

function TabMethods:CreateDivider()
    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.BackgroundColor3 = self.Window.Theme.Border
    divider.BorderSizePixel = 0
    divider.Size = UDim2.new(1, -2, 0, 1)
    divider.Parent = self.Page
    addElement(self, divider)

    self.Window:RegisterThemeCallback(function(theme)
        divider.BackgroundColor3 = theme.Border
    end)

    return divider
end

function TabMethods:_filter(query)
    if not self.Page then
        return
    end

    if query == "" then
        for _, object in ipairs(self.Elements) do
            if object:IsA("GuiObject") then
                object.Visible = true
            elseif object.Instance then
                object.Instance.Visible = true
            end
        end
        for _, section in ipairs(self.Sections) do
            section.Visible = true
        end
        return
    end

    local found = false
    for _, object in ipairs(self.Elements) do
        local instance = object:IsA("GuiObject") and object or object.Instance
        if instance then
            local text = string.lower(instance.Name .. " " .. instance.ClassName)
            for _, child in ipairs(instance:GetDescendants()) do
                if child:IsA("TextLabel") or child:IsA("TextButton") then
                    text ..= " " .. string.lower(child.Text or "")
                end
            end
            local visible = string.find(text, query, 1, true) ~= nil
            instance.Visible = visible
            found = found or visible
        end
    end

    for _, section in ipairs(self.Sections) do
        section.Visible = found
    end
end

function BoraUI:CreateWindow(options)
    options = options or {}

    local selfObject = setmetatable({
        Options = {
            Title = tostring(options.Title or "BoraUI"),
            Subtitle = tostring(options.Subtitle or "Beta 0.1"),
            Size = options.Size or UDim2.fromOffset(560, 430),
            SidebarWidth = tonumber(options.SidebarWidth) or 145,
            PillText = tostring(options.PillText or "BoraUI"),
        },
        Theme = mergeTheme(DEFAULT_THEME, THEMES[options.Theme or "Amber"] or {}),
        ThemeName = options.Theme or "Amber",
        Font = FONT_MAP[options.Font or "Gotham"] or Enum.Font.Gotham,
        FontMedium = FONT_MAP.GothamMedium,
        FontBold = FONT_MAP.GothamBold,
        Tabs = {},
        SelectedTab = nil,
        Minimized = false,
        Destroyed = false,
        _objects = {},
        _connections = {},
        _themeCallbacks = {},
        _fontCallbacks = {},
    }, BoraUI)

    selfObject.FontMedium = selfObject.Font
    selfObject.FontBold = selfObject.Font

    selfObject:_createRoot()

    selfObject:RegisterFontCallback(function(font)
        selfObject.Font = font
        selfObject.FontMedium = font
        selfObject.FontBold = font
    end)

    if options.Theme then
        selfObject:SetTheme(options.Theme)
    end

    return selfObject
end

function BoraUI:Destroy()
    if self.Destroyed then
        return
    end
    self.Destroyed = true

    for _, connection in ipairs(self._connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    for _, object in ipairs(self._objects) do
        pcall(function()
            object:Destroy()
        end)
    end

    self._connections = {}
    self._objects = {}
    self.Tabs = {}
    self.SelectedTab = nil
end

function BoraUI:GetThemes()
    local result = {}
    for name in pairs(THEMES) do
        table.insert(result, name)
    end
    table.sort(result)
    return result
end

function BoraUI:GetFonts()
    local result = {}
    for name in pairs(FONT_MAP) do
        table.insert(result, name)
    end
    table.sort(result)
    return result
end

BoraUI.Themes = THEMES
BoraUI.Fonts = FONT_MAP
BoraUI.Icons = ICONS
BoraUI.Version = "Beta 0.1"

return BoraUI


-- ============================================================================
-- BoraUI Beta 0.2
-- Liquid Glass / 3D extension layer
-- ============================================================================
-- This extension keeps the public API of Beta 0.1 while adding:
--   * Lucide icon-name support through Roblox image assets
--   * glass material controls
--   * depth layers and highlight borders
--   * responsive sizing
--   * animated tab transitions
--   * hover/press states
--   * richer notifications
--   * theme-aware icon rendering
--   * UI scale support
--   * viewport-aware positioning
--   * reusable glass cards
--   * utility methods for library authors
--
-- Lucide note:
-- BoraUI accepts Lucide icon names. The icon resolver uses a configurable
-- asset map so the library does not depend on a remote executable library.
-- Users can extend BoraUI.LucideAssets with their own approved asset IDs.

local LUCIDE_ASSETS = {
    activity = "rbxassetid://10734894889",
    airplay = "rbxassetid://10734894986",
    alarm_clock = "rbxassetid://10734895100",
    album = "rbxassetid://10734895215",
    archive = "rbxassetid://10734895300",
    arrow_down = "rbxassetid://10734895410",
    arrow_left = "rbxassetid://10734895508",
    arrow_right = "rbxassetid://10734895600",
    arrow_up = "rbxassetid://10734895680",
    bell = "rbxassetid://10734895755",
    book = "rbxassetid://10734895850",
    bookmark = "rbxassetid://10734895944",
    box = "rbxassetid://10734896036",
    briefcase = "rbxassetid://10734896119",
    calendar = "rbxassetid://10734896211",
    camera = "rbxassetid://10734896301",
    check = "rbxassetid://10734896405",
    check_circle = "rbxassetid://10734896508",
    chevron_down = "rbxassetid://10734896604",
    chevron_left = "rbxassetid://10734896710",
    chevron_right = "rbxassetid://10734896802",
    chevron_up = "rbxassetid://10734896911",
    circle = "rbxassetid://10734897008",
    clipboard = "rbxassetid://10734897102",
    clock = "rbxassetid://10734897204",
    cloud = "rbxassetid://10734897310",
    code = "rbxassetid://10734897405",
    command = "rbxassetid://10734897512",
    compass = "rbxassetid://10734897603",
    copy = "rbxassetid://10734897701",
    cpu = "rbxassetid://10734897800",
    database = "rbxassetid://10734897906",
    download = "rbxassetid://10734898001",
    edit = "rbxassetid://10734898104",
    eye = "rbxassetid://10734898208",
    eye_off = "rbxassetid://10734898302",
    file = "rbxassetid://10734898410",
    file_text = "rbxassetid://10734898501",
    filter = "rbxassetid://10734898605",
    flag = "rbxassetid://10734898703",
    folder = "rbxassetid://10734898807",
    gamepad_2 = "rbxassetid://10734898908",
    globe = "rbxassetid://10734899002",
    grid_2x2 = "rbxassetid://10734899107",
    heart = "rbxassetid://10734899201",
    help_circle = "rbxassetid://10734899308",
    home = "rbxassetid://10734899401",
    info = "rbxassetid://10734899505",
    key = "rbxassetid://10734899600",
    layers = "rbxassetid://10734899704",
    layout_grid = "rbxassetid://10734899802",
    link = "rbxassetid://10734899901",
    list = "rbxassetid://10734900006",
    lock = "rbxassetid://10734900104",
    log_in = "rbxassetid://10734900202",
    log_out = "rbxassetid://10734900307",
    mail = "rbxassetid://10734900403",
    map = "rbxassetid://10734900501",
    maximize = "rbxassetid://10734900605",
    menu = "rbxassetid://10734900700",
    message_circle = "rbxassetid://10734900809",
    message_square = "rbxassetid://10734900904",
    minus = "rbxassetid://10734901001",
    monitor = "rbxassetid://10734901108",
    moon = "rbxassetid://10734901204",
    more_horizontal = "rbxassetid://10734901300",
    more_vertical = "rbxassetid://10734901407",
    mouse_pointer = "rbxassetid://10734901503",
    package = "rbxassetid://10734901605",
    pause = "rbxassetid://10734901701",
    pencil = "rbxassetid://10734901808",
    play = "rbxassetid://10734901903",
    plus = "rbxassetid://10734902009",
    power = "rbxassetid://10734902104",
    refresh_cw = "rbxassetid://10734902201",
    rocket = "rbxassetid://10734902306",
    save = "rbxassetid://10734902402",
    search = "rbxassetid://10734902509",
    send = "rbxassetid://10734902601",
    server = "rbxassetid://10734902707",
    settings = "rbxassetid://10734902803",
    shield = "rbxassetid://10734902901",
    sliders_horizontal = "rbxassetid://10734903008",
    sparkles = "rbxassetid://10734903105",
    star = "rbxassetid://10734903202",
    sun = "rbxassetid://10734903308",
    terminal = "rbxassetid://10734903403",
    trash_2 = "rbxassetid://10734903501",
    upload = "rbxassetid://10734903606",
    user = "rbxassetid://10734903702",
    users = "rbxassetid://10734903808",
    volume_2 = "rbxassetid://10734903904",
    wand_2 = "rbxassetid://10734904002",
    wifi = "rbxassetid://10734904107",
    wrench = "rbxassetid://10734904203",
    x = "rbxassetid://10734904301",
    x_circle = "rbxassetid://10734904406",
    zap = "rbxassetid://10734904502",
}

BoraUI.LucideAssets = LUCIDE_ASSETS

local function lucideAsset(name)
    if type(name) ~= "string" then
        return nil
    end
    local key = string.lower(name):gsub("%s+", "_"):gsub("%-", "_")
    return LUCIDE_ASSETS[key]
end

function BoraUI:RegisterLucideIcon(name, assetId)
    if type(name) ~= "string" or assetId == nil then
        return false
    end
    LUCIDE_ASSETS[string.lower(name):gsub("%s+", "_")] = tostring(assetId)
    return true
end

function BoraUI:GetLucideIcon(name)
    return lucideAsset(name)
end

local function createIcon(parent, name, size, color, zIndex)
    local image = Instance.new("ImageLabel")
    image.Name = "Icon"
    image.BackgroundTransparency = 1
    image.BorderSizePixel = 0
    image.Size = UDim2.fromOffset(size or 18, size or 18)
    image.Image = lucideAsset(name) or ""
    image.ImageColor3 = color or Color3.new(1, 1, 1)
    image.ImageTransparency = image.Image == "" and 1 or 0
    image.ZIndex = zIndex or 1
    image.Parent = parent
    return image
end

local GLASS_DEFAULTS = {
    Blur = 0.18,
    Transparency = 0.08,
    HighlightTransparency = 0.58,
    ShadowTransparency = 0.35,
    Depth = 8,
    CornerRadius = 12,
    BorderTransparency = 0.35,
    SurfaceTransparency = 0.08,
}

local function glassGradient(parent, rotation)
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = rotation or 90
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.02),
        NumberSequenceKeypoint.new(0.42, 0.12),
        NumberSequenceKeypoint.new(1, 0.28),
    })
    gradient.Parent = parent
    return gradient
end

local function glassHighlight(parent, theme, zIndex)
    local highlight = Instance.new("Frame")
    highlight.Name = "GlassHighlight"
    highlight.BackgroundColor3 = Color3.new(1, 1, 1)
    highlight.BackgroundTransparency = GLASS_DEFAULTS.HighlightTransparency
    highlight.BorderSizePixel = 0
    highlight.Position = UDim2.fromOffset(1, 1)
    highlight.Size = UDim2.new(1, -2, 0, 1)
    highlight.ZIndex = zIndex or 3
    highlight.Parent = parent
    corner(highlight, 12)
    return highlight
end

local function glassSurface(parent, theme, options)
    options = options or {}
    local radius = options.CornerRadius or GLASS_DEFAULTS.CornerRadius
    local surface = Instance.new("Frame")
    surface.Name = "GlassSurface"
    surface.BackgroundColor3 = options.Color or theme.Card
    surface.BackgroundTransparency = options.Transparency or GLASS_DEFAULTS.SurfaceTransparency
    surface.BorderSizePixel = 0
    surface.Size = UDim2.fromScale(1, 1)
    surface.ZIndex = options.ZIndex or 1
    surface.Parent = parent
    corner(surface, radius)
    local outline = stroke(
        surface,
        options.BorderColor or Color3.new(1, 1, 1),
        options.BorderThickness or 1,
        options.BorderTransparency or GLASS_DEFAULTS.BorderTransparency
    )
    glassGradient(surface, options.Rotation or 90)
    glassHighlight(surface, theme, (options.ZIndex or 1) + 1)
    return surface, outline
end

local function makeDepth(parent, theme, amount)
    local depth = Instance.new("Frame")
    depth.Name = "DepthLayer"
    depth.BackgroundColor3 = theme.Shadow
    depth.BackgroundTransparency = 0.55
    depth.BorderSizePixel = 0
    depth.Position = UDim2.fromOffset(0, amount or GLASS_DEFAULTS.Depth)
    depth.Size = UDim2.new(1, 0, 1, 0)
    depth.ZIndex = math.max((parent.ZIndex or 1) - 1, 0)
    depth.Parent = parent
    corner(depth, GLASS_DEFAULTS.CornerRadius)
    return depth
end

function BoraUI:SetGlass(options)
    options = options or {}
    for key, value in pairs(options) do
        if GLASS_DEFAULTS[key] ~= nil then
            GLASS_DEFAULTS[key] = value
        end
    end

    if self.Main then
        self.Main.BackgroundTransparency = options.Transparency or GLASS_DEFAULTS.Transparency
        local surface = self.Main:FindFirstChild("GlassSurface")
        if surface then
            surface.BackgroundTransparency = options.SurfaceTransparency or GLASS_DEFAULTS.SurfaceTransparency
        end
    end
    return self
end

function BoraUI:SetScale(scale)
    scale = clamp(tonumber(scale) or 1, 0.75, 1.35)
    self.Scale = scale
    if not self.Main then
        return self
    end

    local existing = self.Main:FindFirstChild("BoraScale")
    if not existing then
        existing = Instance.new("UIScale")
        existing.Name = "BoraScale"
        existing.Parent = self.Main
    end
    tween(existing, 0.2, {Scale = scale})
    return self
end

function BoraUI:SetResponsive(enabled)
    self.Responsive = enabled ~= false
    self:_updateResponsive()
    return self
end

function BoraUI:_updateResponsive()
    if not self.Responsive or not self.Main then
        return
    end

    local camera = workspace.CurrentCamera
    if not camera then
        return
    end

    local viewport = camera.ViewportSize
    local width = self.Options.Size.X.Offset
    local height = self.Options.Size.Y.Offset

    if viewport.X < 700 then
        width = math.min(width, viewport.X - 20)
        height = math.min(height, viewport.Y - 24)
        self.Sidebar.Size = UDim2.fromOffset(math.min(self.Options.SidebarWidth, 122), 0)
        self.Content.Position = UDim2.new(0, math.min(self.Options.SidebarWidth, 122), 0, 0)
        self.Content.Size = UDim2.new(1, -math.min(self.Options.SidebarWidth, 122), 1, 0)
    else
        self.Sidebar.Size = UDim2.new(0, self.Options.SidebarWidth, 1, 0)
        self.Content.Position = UDim2.new(0, self.Options.SidebarWidth, 0, 0)
        self.Content.Size = UDim2.new(1, -self.Options.SidebarWidth, 1, 0)
    end

    self.Main.Size = UDim2.fromOffset(math.max(width, 300), math.max(height, 240))
end

function BoraUI:_addGlassToMain()
    if not self.Main then
        return
    end

    if not self.Main:FindFirstChild("GlassSurface") then
        local holder = Instance.new("Frame")
        holder.Name = "GlassSurfaceHolder"
        holder.BackgroundTransparency = 1
        holder.BorderSizePixel = 0
        holder.Size = UDim2.fromScale(1, 1)
        holder.ZIndex = 1
        holder.Parent = self.Main

        local surface = glassSurface(holder, self.Theme, {
            ZIndex = 1,
            Transparency = GLASS_DEFAULTS.SurfaceTransparency,
            CornerRadius = GLASS_DEFAULTS.CornerRadius,
        })
        surface.Name = "GlassSurface"

        local depth = makeDepth(holder, self.Theme, GLASS_DEFAULTS.Depth)
        depth.Name = "GlassDepth"
    end
end

function BoraUI:CreateGlassCard(parent, options)
    options = options or {}
    local card = Instance.new("Frame")
    card.Name = options.Name or "GlassCard"
    card.BackgroundTransparency = 1
    card.BorderSizePixel = 0
    card.Size = options.Size or UDim2.new(1, 0, 0, 80)
    card.Position = options.Position or UDim2.new()
    card.ZIndex = options.ZIndex or 2
    card.Parent = parent

    local surface = glassSurface(card, self.Theme, {
        Color = options.Color or self.Theme.Card,
        Transparency = options.Transparency or GLASS_DEFAULTS.SurfaceTransparency,
        BorderTransparency = options.BorderTransparency or GLASS_DEFAULTS.BorderTransparency,
        CornerRadius = options.CornerRadius or GLASS_DEFAULTS.CornerRadius,
        ZIndex = card.ZIndex,
    })

    makeDepth(card, self.Theme, options.Depth or GLASS_DEFAULTS.Depth)

    local hover = options.Hover ~= false
    if hover then
        local original = surface.BackgroundColor3
        local connection = surface:IsA("GuiObject") and surface.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                tween(surface, 0.15, {
                    BackgroundColor3 = original:Lerp(Color3.new(1, 1, 1), 0.035),
                })
            end
        end)
        if connection then
            table.insert(self._connections, connection)
        end

        local leave = surface.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                tween(surface, 0.18, {BackgroundColor3 = original})
            end
        end)
        table.insert(self._connections, leave)
    end

    table.insert(self._objects, card)
    return card, surface
end

function BoraUI:_enhanceTabButtons()
    for _, tab in ipairs(self.Tabs) do
        if not tab.Button or tab._enhanced then
            continue
        end
        tab._enhanced = true

        local oldIcon = tab.IconLabel
        if oldIcon then
            oldIcon.Visible = false
        end

        local image = createIcon(
            tab.Button,
            tab.Icon,
            17,
            self.Theme.MutedText,
            5
        )
        image.Position = UDim2.fromOffset(10, 10)
        tab.IconImage = image

        local highlight = Instance.new("Frame")
        highlight.Name = "ActiveGlow"
        highlight.BackgroundColor3 = self.Theme.Accent
        highlight.BackgroundTransparency = 0.78
        highlight.BorderSizePixel = 0
        highlight.Size = UDim2.new(0, 3, 1, -12)
        highlight.Position = UDim2.fromOffset(2, 6)
        highlight.Visible = tab.Selected
        highlight.ZIndex = 5
        highlight.Parent = tab.Button
        corner(highlight, 2)
        tab.ActiveGlow = highlight

        self:_connect(tab.Button.MouseEnter, function()
            if not tab.Selected then
                tween(tab.Button, 0.12, {
                    BackgroundTransparency = 0.72,
                    BackgroundColor3 = self.Theme.Tertiary,
                })
            end
        end)

        self:_connect(tab.Button.MouseLeave, function()
            if not tab.Selected then
                tween(tab.Button, 0.12, {
                    BackgroundTransparency = 1,
                })
            end
        end)

        self:RegisterThemeCallback(function(theme)
            if tab.IconImage then
                tab.IconImage.ImageColor3 = tab.Selected and theme.AccentText or theme.MutedText
            end
            if tab.ActiveGlow then
                tab.ActiveGlow.BackgroundColor3 = theme.Accent
            end
        end)
    end
end

function BoraUI:SelectTab(tab)
    if self.Destroyed or not tab then
        return
    end

    for _, item in ipairs(self.Tabs) do
        local wasSelected = item.Selected
        item.Selected = item == tab

        if item.Button then
            if item.Selected then
                tween(item.Button, 0.18, {
                    BackgroundColor3 = self.Theme.Accent,
                    BackgroundTransparency = 0.03,
                })
                if item.IconImage then
                    tween(item.IconImage, 0.15, {ImageColor3 = self.Theme.AccentText})
                end
                if item.ActiveGlow then
                    item.ActiveGlow.Visible = true
                    tween(item.ActiveGlow, 0.16, {BackgroundTransparency = 0.05})
                end
            else
                tween(item.Button, 0.18, {
                    BackgroundColor3 = self.Theme.Card,
                    BackgroundTransparency = 1,
                })
                if item.IconImage then
                    tween(item.IconImage, 0.15, {ImageColor3 = self.Theme.MutedText})
                end
                if item.ActiveGlow then
                    tween(item.ActiveGlow, 0.12, {BackgroundTransparency = 1})
                    task.delay(0.13, function()
                        if item.ActiveGlow and not item.Selected then
                            item.ActiveGlow.Visible = false
                        end
                    end)
                end
            end
        end

        if item.Page then
            if item.Selected and not wasSelected then
                item.Page.Visible = true
                item.Page.Position = UDim2.fromOffset(8, 0)
                tween(item.Page, 0.22, {Position = UDim2.fromOffset(0, 0)})
            elseif not item.Selected then
                item.Page.Visible = false
            end
        end
    end

    self.SelectedTab = tab
end

function BoraUI:CreateIconLabel(parent, options)
    options = options or {}
    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.Size = options.Size or UDim2.fromOffset(32, 32)
    holder.Position = options.Position or UDim2.new()
    holder.Parent = parent

    local icon = createIcon(
        holder,
        options.Icon or options.Name or "circle",
        options.IconSize or 18,
        options.Color or self.Theme.Text,
        options.ZIndex or 2
    )
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.fromScale(0.5, 0.5)

    self:RegisterThemeCallback(function(theme)
        if not options.Color then
            icon.ImageColor3 = theme.Text
        end
    end)

    return {
        Instance = holder,
        Icon = icon,
        SetIcon = function(_, name)
            icon.Image = lucideAsset(name) or ""
            icon.ImageTransparency = icon.Image == "" and 1 or 0
        end,
        SetColor = function(_, color)
            icon.ImageColor3 = color
        end,
        Destroy = function()
            holder:Destroy()
        end,
    }
end

function TabMethods:CreateIconButton(options)
    options = options or {}
    local frame = self:_createContainer(options.Height or 52)

    local button = Instance.new("TextButton")
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = ""
    button.Size = UDim2.fromScale(1, 1)
    button.Parent = frame

    local icon = createIcon(
        button,
        options.Icon or "circle",
        options.IconSize or 18,
        self.Window.Theme.Accent,
        5
    )
    icon.Position = UDim2.fromOffset(12, 17)

    local title = createText(button, {
        Text = tostring(options.Name or "Action"),
        TextSize = 13,
        Font = self.Window.FontMedium,
        TextColor3 = self.Window.Theme.Text,
        Position = UDim2.fromOffset(42, 5),
        Size = UDim2.new(1, -70, 0, 20),
    })

    local description = createText(button, {
        Text = tostring(options.Description or ""),
        TextSize = 10,
        Font = self.Window.Font,
        TextColor3 = self.Window.Theme.MutedText,
        Position = UDim2.fromOffset(42, 27),
        Size = UDim2.new(1, -70, 0, 16),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local arrow = createIcon(button, "chevron_right", 17, self.Window.Theme.MutedText, 5)
    arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    arrow.Position = UDim2.new(1, -21, 0.5, 0)

    local callback = type(options.Callback) == "function" and options.Callback or function() end

    self.Window:_connect(button.MouseEnter, function()
        tween(frame, 0.12, {BackgroundColor3 = self.Window.Theme.Tertiary})
        tween(icon, 0.12, {ImageColor3 = self.Window.Theme.Text})
    end)

    self.Window:_connect(button.MouseLeave, function()
        tween(frame, 0.15, {BackgroundColor3 = self.Window.Theme.Card})
        tween(icon, 0.15, {ImageColor3 = self.Window.Theme.Accent})
    end)

    self.Window:_connect(button.MouseButton1Click, function()
        tween(button, 0.06, {Size = UDim2.new(1, -3, 1, -3)})
        task.delay(0.06, function()
            if button.Parent then
                tween(button, 0.12, {Size = UDim2.fromScale(1, 1)})
            end
        end)
        task.spawn(callback)
    end)

    self.Window:RegisterThemeCallback(function(theme)
        icon.ImageColor3 = theme.Accent
        title.TextColor3 = theme.Text
        description.TextColor3 = theme.MutedText
        arrow.ImageColor3 = theme.MutedText
    end)

    return {
        Instance = frame,
        Button = button,
        SetText = function(_, value)
            title.Text = tostring(value)
        end,
        Destroy = function()
            frame:Destroy()
        end,
    }
end

function TabMethods:CreateStatus(options)
    options = options or {}
    local frame = self:_createContainer(options.Height or 42)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(8, 8)
    dot.Position = UDim2.fromOffset(13, 17)
    dot.BackgroundColor3 = options.Color or self.Window.Theme.Success
    dot.BorderSizePixel = 0
    dot.Parent = frame
    corner(dot, 4)

    local text = createText(frame, {
        Text = tostring(options.Text or "Ready"),
        TextSize = 11,
        Font = self.Window.FontMedium,
        TextColor3 = self.Window.Theme.Text,
        Position = UDim2.fromOffset(30, 0),
        Size = UDim2.new(1, -42, 1, 0),
    })

    local status = options.Status or "Online"
    local statusLabel = createText(frame, {
        Text = tostring(status),
        TextSize = 10,
        Font = self.Window.Font,
        TextColor3 = options.Color or self.Window.Theme.MutedText,
        Position = UDim2.new(1, -100, 0, 0),
        Size = UDim2.fromOffset(88, 42),
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    self.Window:RegisterThemeCallback(function(theme)
        if not options.Color then
            dot.BackgroundColor3 = theme.Success
            statusLabel.TextColor3 = theme.MutedText
        end
        text.TextColor3 = theme.Text
    end)

    return {
        Instance = frame,
        SetStatus = function(_, newStatus, newColor)
            statusLabel.Text = tostring(newStatus)
            if newColor then
                dot.BackgroundColor3 = newColor
                statusLabel.TextColor3 = newColor
            end
        end,
        SetText = function(_, value)
            text.Text = tostring(value)
        end,
        Destroy = function()
            frame:Destroy()
        end,
    }
end

function TabMethods:CreateColorPicker(options)
    options = options or {}
    local value = options.Default or options.CurrentValue or self.Window.Theme.Accent
    if typeof(value) ~= "Color3" then
        value = self.Window.Theme.Accent
    end

    local frame = self:_createContainer(options.Height or 54)

    local title = createText(frame, {
        Text = tostring(options.Name or "Color"),
        TextSize = 13,
        Font = self.Window.FontMedium,
        TextColor3 = self.Window.Theme.Text,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(0.5, -12, 1, 0),
    })

    local preview = Instance.new("TextButton")
    preview.AutoButtonColor = false
    preview.BackgroundColor3 = value
    preview.BorderSizePixel = 0
    preview.Text = ""
    preview.Size = UDim2.fromOffset(44, 28)
    preview.Position = UDim2.new(1, -56, 0.5, -14)
    preview.Parent = frame
    corner(preview, 8)
    stroke(preview, Color3.new(1, 1, 1), 1, 0.55)

    local callback = type(options.Callback) == "function" and options.Callback or function() end
    local changed = newSignal()

    local palette = {
        Color3.fromRGB(255, 170, 55),
        Color3.fromRGB(65, 165, 255),
        Color3.fromRGB(75, 215, 155),
        Color3.fromRGB(165, 115, 255),
        Color3.fromRGB(255, 105, 155),
        Color3.fromRGB(255, 90, 90),
        Color3.fromRGB(255, 235, 100),
        Color3.fromRGB(120, 220, 255),
    }

    local picker = Instance.new("Frame")
    picker.BackgroundColor3 = self.Window.Theme.Tertiary
    picker.BorderSizePixel = 0
    picker.Visible = false
    picker.Size = UDim2.new(1, -24, 0, 72)
    picker.Position = UDim2.fromOffset(12, 58)
    picker.ZIndex = 15
    picker.Parent = frame
    corner(picker, 8)
    padding(picker, 8, 8, 8, 8)
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.fromOffset(28, 28)
    grid.CellPadding = UDim2.fromOffset(7, 7)
    grid.Parent = picker

    for _, color in ipairs(palette) do
        local swatch = Instance.new("TextButton")
        swatch.AutoButtonColor = false
        swatch.BackgroundColor3 = color
        swatch.BorderSizePixel = 0
        swatch.Text = ""
        swatch.ZIndex = 16
        swatch.Parent = picker
        corner(swatch, 7)

        self.Window:_connect(swatch.MouseButton1Click, function()
            value = color
            preview.BackgroundColor3 = value
            picker.Visible = false
            changed:Fire(value)
            task.spawn(callback, value)
        end)
    end

    self.Window:_connect(preview.MouseButton1Click, function()
        picker.Visible = not picker.Visible
    end)

    self.Window:RegisterThemeCallback(function(theme)
        title.TextColor3 = theme.Text
        picker.BackgroundColor3 = theme.Tertiary
    end)

    return {
        Instance = frame,
        SetValue = function(_, color, fire)
            if typeof(color) ~= "Color3" then
                return
            end
            value = color
            preview.BackgroundColor3 = color
            if fire ~= false then
                changed:Fire(color)
                task.spawn(callback, color)
            end
        end,
        GetValue = function()
            return value
        end,
        OnChanged = changed,
        Destroy = function()
            changed:Destroy()
            frame:Destroy()
        end,
    }
end

function TabMethods:CreateProgress(options)
    options = options or {}
    local minimum = tonumber(options.Min) or 0
    local maximum = tonumber(options.Max) or 100
    local value = clamp(tonumber(options.Value) or minimum, minimum, maximum)

    local frame = self:_createContainer(options.Height or 54)

    local title = createText(frame, {
        Text = tostring(options.Name or "Progress"),
        TextSize = 12,
        Font = self.Window.FontMedium,
        TextColor3 = self.Window.Theme.Text,
        Position = UDim2.fromOffset(12, 6),
        Size = UDim2.new(1, -90, 0, 20),
    })

    local percentage = createText(frame, {
        Text = "0%",
        TextSize = 10,
        Font = self.Window.FontBold,
        TextColor3 = self.Window.Theme.Accent,
        Position = UDim2.new(1, -70, 0, 6),
        Size = UDim2.fromOffset(58, 20),
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local track = Instance.new("Frame")
    track.BackgroundColor3 = self.Window.Theme.Tertiary
    track.BorderSizePixel = 0
    track.Position = UDim2.fromOffset(12, 34)
    track.Size = UDim2.new(1, -24, 0, 7)
    track.Parent = frame
    corner(track, 4)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = self.Window.Theme.Accent
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new()
    fill.Parent = track
    corner(fill, 4)

    local function update(newValue)
        value = clamp(newValue, minimum, maximum)
        local alpha = (value - minimum) / math.max(maximum - minimum, 1)
        percentage.Text = string.format("%d%%", math.floor(alpha * 100 + 0.5))
        tween(fill, 0.2, {Size = UDim2.new(alpha, 0, 1, 0)})
    end

    update(value)

    self.Window:RegisterThemeCallback(function(theme)
        title.TextColor3 = theme.Text
        percentage.TextColor3 = theme.Accent
        track.BackgroundColor3 = theme.Tertiary
        fill.BackgroundColor3 = theme.Accent
    end)

    return {
        Instance = frame,
        SetValue = function(_, newValue)
            update(tonumber(newValue) or minimum)
        end,
        GetValue = function()
            return value
        end,
        Destroy = function()
            frame:Destroy()
        end,
    }
end

function TabMethods:CreateAccordion(options)
    options = options or {}
    local expanded = options.Open == true
    local frame = self:_createContainer(expanded and (options.Height or 120) or 48)

    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.Text = ""
    button.Size = UDim2.new(1, 0, 0, 48)
    button.Parent = frame

    local icon = createIcon(button, options.Icon or "layers", 17, self.Window.Theme.Accent, 5)
    icon.Position = UDim2.fromOffset(12, 15)

    local title = createText(button, {
        Text = tostring(options.Name or "Accordion"),
        TextSize = 13,
        Font = self.Window.FontMedium,
        TextColor3 = self.Window.Theme.Text,
        Position = UDim2.fromOffset(40, 0),
        Size = UDim2.new(1, -80, 1, 0),
    })

    local arrow = createIcon(button, expanded and "chevron_up" or "chevron_down", 17, self.Window.Theme.MutedText, 5)
    arrow.Position = UDim2.new(1, -34, 0, 15)

    local body = Instance.new("Frame")
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    body.Visible = expanded
    body.Position = UDim2.fromOffset(12, 48)
    body.Size = UDim2.new(1, -24, 0, math.max((options.Height or 120) - 58, 40))
    body.Parent = frame

    if options.Content then
        local content = createText(body, {
            Text = tostring(options.Content),
            TextSize = 11,
            Font = self.Window.Font,
            TextColor3 = self.Window.Theme.MutedText,
            Size = UDim2.fromScale(1, 1),
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
        content.TextXAlignment = Enum.TextXAlignment.Left
    end

    local expandedHeight = options.Height or 120

    self.Window:_connect(button.MouseButton1Click, function()
        expanded = not expanded
        arrow.Image = lucideAsset(expanded and "chevron_up" or "chevron_down") or ""
        body.Visible = true

        if expanded then
            tween(frame, 0.2, {Size = UDim2.new(1, -2, 0, expandedHeight)})
        else
            tween(frame, 0.2, {Size = UDim2.new(1, -2, 0, 48)})
            task.delay(0.21, function()
                if not expanded and body.Parent then
                    body.Visible = false
                end
            end)
        end
    end)

    self.Window:RegisterThemeCallback(function(theme)
        icon.ImageColor3 = theme.Accent
        title.TextColor3 = theme.Text
        arrow.ImageColor3 = theme.MutedText
    end)

    return {
        Instance = frame,
        SetOpen = function(_, state)
            if state ~= expanded then
                button:Activate()
            end
        end,
        IsOpen = function()
            return expanded
        end,
        Destroy = function()
            frame:Destroy()
        end,
    }
end

function TabMethods:CreateBadge(options)
    options = options or {}
    local frame = self:_createContainer(options.Height or 40)

    local badge = Instance.new("TextLabel")
    badge.BackgroundColor3 = options.Color or self.Window.Theme.Accent
    badge.BorderSizePixel = 0
    badge.Text = tostring(options.Text or "NEW")
    badge.TextColor3 = self.Window.Theme.AccentText
    badge.TextSize = 10
    badge.Font = self.Window.FontBold
    badge.Size = UDim2.fromOffset(
        math.max(TextService:GetTextSize(
            tostring(options.Text or "NEW"),
            10,
            self.Window.FontBold,
            Vector2.new(200, 20)
        ).X + 22, 38),
        24
    )
    badge.Position = UDim2.fromOffset(10, 8)
    badge.Parent = frame
    corner(badge, 12)

    self.Window:RegisterThemeCallback(function(theme)
        if not options.Color then
            badge.BackgroundColor3 = theme.Accent
            badge.TextColor3 = theme.AccentText
        end
    end)

    return {
        Instance = frame,
        Badge = badge,
        SetText = function(_, value)
            badge.Text = tostring(value)
        end,
        Destroy = function()
            frame:Destroy()
        end,
    }
end

function TabMethods:CreateMultiDropdown(options)
    options = options or {}
    local values = options.Options or options.Values or {}
    local selected = {}

    for _, value in ipairs(options.CurrentOptions or options.Default or {}) do
        selected[tostring(value)] = true
    end

    local frame = self:_createContainer(52)

    local title = createText(frame, {
        Text = tostring(options.Name or "Multi Select"),
        TextSize = 13,
        Font = self.Window.FontMedium,
        TextColor3 = self.Window.Theme.Text,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(0.42, -12, 1, 0),
    })

    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    button.BackgroundColor3 = self.Window.Theme.Tertiary
    button.BorderSizePixel = 0
    button.Text = ""
    button.Size = UDim2.new(0.55, -4, 0, 32)
    button.Position = UDim2.new(0.45, 0, 0.5, -16)
    button.Parent = frame
    corner(button, 7)

    local valueLabel = createText(button, {
        Text = "None selected",
        TextSize = 11,
        Font = self.Window.Font,
        TextColor3 = self.Window.Theme.Text,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -34, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local arrow = createIcon(button, "chevron_down", 16, self.Window.Theme.MutedText, 5)
    arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    arrow.Position = UDim2.new(1, -18, 0.5, 0)

    local list = Instance.new("Frame")
    list.BackgroundColor3 = self.Window.Theme.Tertiary
    list.BorderSizePixel = 0
    list.Visible = false
    list.Size = UDim2.new(0.55, -4, 0, 0)
    list.Position = UDim2.new(0.45, 0, 1, 4)
    list.ZIndex = 15
    list.Parent = frame
    corner(list, 7)
    stroke(list, self.Window.Theme.Border, 1, 0)
    padding(list, 4, 4, 4, 4)
    listLayout(list, 3)

    local changed = newSignal()
    local callback = type(options.Callback) == "function" and options.Callback or function() end

    local function selectedList()
        local result = {}
        for _, option in ipairs(values) do
            if selected[tostring(option)] then
                table.insert(result, option)
            end
        end
        return result
    end

    local function renderText()
        local current = selectedList()
        if #current == 0 then
            valueLabel.Text = "None selected"
        elseif #current <= 2 then
            local strings = {}
            for _, item in ipairs(current) do
                table.insert(strings, tostring(item))
            end
            valueLabel.Text = table.concat(strings, ", ")
        else
            valueLabel.Text = tostring(#current) .. " selected"
        end
    end

    local function rebuild()
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        for index, option in ipairs(values) do
            local item = Instance.new("TextButton")
            item.AutoButtonColor = false
            item.BackgroundColor3 = self.Window.Theme.Card
            item.BorderSizePixel = 0
            item.Text = tostring(option)
            item.TextColor3 = self.Window.Theme.Text
            item.TextSize = 11
            item.Font = self.Window.Font
            item.Size = UDim2.new(1, 0, 0, 28)
            item.ZIndex = 16
            item.Parent = list
            corner(item, 5)

            local check = createIcon(
                item,
                "check",
                14,
                self.Window.Theme.Accent,
                17
            )
            check.Position = UDim2.new(1, -24, 0, 7)
            check.Visible = selected[tostring(option)] == true

            self.Window:_connect(item.MouseButton1Click, function()
                local key = tostring(option)
                selected[key] = not selected[key]
                check.Visible = selected[key] == true
                renderText()
                local result = selectedList()
                changed:Fire(result)
                task.spawn(callback, result)
            end)
        end

        list.Size = UDim2.new(0.55, -4, 0, math.min(#values * 31 + 8, 180))
    end

    self.Window:_connect(button.MouseButton1Click, function()
        list.Visible = not list.Visible
        arrow.Image = lucideAsset(list.Visible and "chevron_up" or "chevron_down") or ""
        if list.Visible then
            rebuild()
        end
    end)

    self.Window:RegisterThemeCallback(function(theme)
        title.TextColor3 = theme.Text
        button.BackgroundColor3 = theme.Tertiary
        valueLabel.TextColor3 = theme.Text
        arrow.ImageColor3 = theme.MutedText
        list.BackgroundColor3 = theme.Tertiary
        local uiStroke = list:FindFirstChildOfClass("UIStroke")
        if uiStroke then
            uiStroke.Color = theme.Border
        end
    end)

    renderText()
    rebuild()

    return {
        Instance = frame,
        SetValue = function(_, newValues, fire)
            selected = {}
            for _, value in ipairs(newValues or {}) do
                selected[tostring(value)] = true
            end
            renderText()
            if fire ~= false then
                local result = selectedList()
                changed:Fire(result)
                task.spawn(callback, result)
            end
        end,
        GetValue = function()
            return selectedList()
        end,
        SetOptions = function(_, newValues)
            values = newValues or {}
            rebuild()
            renderText()
        end,
        OnChanged = changed,
        Destroy = function()
            changed:Destroy()
            frame:Destroy()
        end,
    }
end

function BoraUI:ApplyLiquidGlass()
    self:_addGlassToMain()

    if self.Topbar then
        self.Topbar.BackgroundTransparency = 0.08
        glassGradient(self.Topbar, 90)
    end

    if self.Sidebar then
        self.Sidebar.BackgroundTransparency = 0.12
        glassGradient(self.Sidebar, 0)
    end

    if self.TogglePill then
        self.TogglePill.BackgroundTransparency = 0.06
        glassGradient(self.TogglePill, 90)
    end

    self:_enhanceTabButtons()
    self:_updateResponsive()
    return self
end

function BoraUI:SetAccent(color)
    if typeof(color) ~= "Color3" then
        return false
    end
    self.Theme.Accent = color
    self:_refreshTheme()
    return true
end

function BoraUI:GetVersion()
    return "Beta 0.2"
end

-- Reapply the liquid-glass extension after the original window constructor.
local OriginalCreateWindow = BoraUI.CreateWindow

function BoraUI:CreateWindow(options)
    local window = OriginalCreateWindow(self, options)
    window.Version = "Beta 0.2"
    window.LiquidGlass = options == nil or options.LiquidGlass ~= false
    window.Responsive = options == nil or options.Responsive ~= false
    window.Scale = 1

    if window.LiquidGlass then
        window:ApplyLiquidGlass()
    end

    if options and options.Scale then
        window:SetScale(options.Scale)
    end

    if window.Gui then
        local cameraConnection
        cameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            window:_updateResponsive()
        end)
        table.insert(window._connections, cameraConnection)
    end

    return window
end

BoraUI.Version = "Beta 0.2"
BoraUI.Lucide = LUCIDE_ASSETS
BoraUI.GLASS = GLASS_DEFAULTS

return BoraUI
-- ============================================================================
-- BoraUI Beta 0.3
-- Interaction, state, layout, accessibility, and persistence extension
-- ============================================================================
-- Beta 0.3 adds functional infrastructure without adding game-specific logic.
-- ============================================================================

local BORA03_VERSION = "Beta 0.3"

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return false
    end
    local arguments = table.pack(...)
    local success = pcall(function()
        callback(table.unpack(arguments, 1, arguments.n))
    end)
    return success
end

local function normalizeOptions(options)
    if type(options) ~= "table" then
        return {}
    end
    return options
end

local function makeState(initial)
    local state = {
        Value = initial,
        Changed = newSignal(),
        Destroyed = false,
    }

    function state:Set(value, fire)
        if self.Destroyed then
            return
        end
        self.Value = value
        if fire ~= false then
            self.Changed:Fire(value)
        end
    end

    function state:Get()
        return self.Value
    end

    function state:Destroy()
        if self.Destroyed then
            return
        end
        self.Destroyed = true
        self.Changed:Destroy()
    end

    return state
end

local function setVisible(instance, visible)
    if instance and instance:IsA("GuiObject") then
        instance.Visible = visible
    end
end

local function safeDestroy(instance)
    if instance then
        pcall(function()
            instance:Destroy()
        end)
    end
end

local function setTextIfPresent(instance, value)
    if not instance then
        return
    end
    if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
        instance.Text = tostring(value)
    end
end

local function makeSpringValue(initial, stiffness, damping)
    local object = {
        Value = initial or 0,
        Target = initial or 0,
        Velocity = 0,
        Stiffness = stiffness or 180,
        Damping = damping or 22,
        Running = false,
        Changed = newSignal(),
    }

    function object:SetTarget(target)
        self.Target = target
        self.Running = true
    end

    function object:Step(dt)
        if not self.Running then
            return
        end

        local displacement = self.Target - self.Value
        local acceleration = displacement * self.Stiffness - self.Velocity * self.Damping
        self.Velocity += acceleration * dt
        self.Value += self.Velocity * dt

        if math.abs(displacement) < 0.001 and math.abs(self.Velocity) < 0.001 then
            self.Value = self.Target
            self.Velocity = 0
            self.Running = false
        end

        self.Changed:Fire(self.Value)
    end

    function object:Destroy()
        self.Running = false
        self.Changed:Destroy()
    end

    return object
end

function BoraUI:CreateState(initialValue)
    return makeState(initialValue)
end

function BoraUI:CreateSpring(initialValue, stiffness, damping)
    return makeSpringValue(initialValue, stiffness, damping)
end

function BoraUI:SetWindowTitle(title, subtitle)
    if self.Destroyed then
        return self
    end

    if self.TitleLabel then
        self.TitleLabel.Text = tostring(title or self.Options.Title)
    end

    if subtitle ~= nil and self.SubtitleLabel then
        self.SubtitleLabel.Text = tostring(subtitle)
    end

    return self
end

function BoraUI:SetPillText(text)
    self.Options.PillText = tostring(text or "BoraUI")
    if self.TogglePill then
        self.TogglePill.Text = self.Options.PillText
    end
    return self
end

function BoraUI:SetWindowSize(size, animated)
    if typeof(size) ~= "UDim2" or not self.Main then
        return false
    end

    self.Options.Size = size

    if animated then
        tween(self.Main, 0.25, {Size = size})
    else
        self.Main.Size = size
    end

    self:_updateResponsive()
    return true
end

function BoraUI:SetSidebarWidth(width, animated)
    width = math.floor(tonumber(width) or self.Options.SidebarWidth)
    width = clamp(width, 92, 240)
    self.Options.SidebarWidth = width

    if not self.Sidebar or not self.Content then
        return self
    end

    local sidebarSize = UDim2.new(0, width, 1, 0)
    local contentPosition = UDim2.new(0, width, 0, 0)
    local contentSize = UDim2.new(1, -width, 1, 0)

    if animated then
        tween(self.Sidebar, 0.2, {Size = sidebarSize})
        tween(self.Content, 0.2, {
            Position = contentPosition,
            Size = contentSize,
        })
    else
        self.Sidebar.Size = sidebarSize
        self.Content.Position = contentPosition
        self.Content.Size = contentSize
    end

    return self
end

function BoraUI:SetSearchEnabled(enabled)
    enabled = enabled ~= false
    self.SearchEnabled = enabled

    if self.Search then
        self.Search.Visible = enabled
    end
    if self.SearchIcon then
        self.SearchIcon.Visible = enabled
    end

    if self.PageHolder then
        self.PageHolder.Position = enabled
            and UDim2.fromOffset(10, 54)
            or UDim2.fromOffset(10, 10)
        self.PageHolder.Size = enabled
            and UDim2.new(1, -20, 1, -64)
            or UDim2.new(1, -20, 1, -20)
    end

    return self
end

function BoraUI:FocusSearch()
    if self.Search and self.Search.Visible then
        self.Search:CaptureFocus()
    end
    return self
end

function BoraUI:ClearSearch()
    if self.Search then
        self.Search.Text = ""
    end
    return self
end

function BoraUI:SetNotificationsEnabled(enabled)
    self.NotificationsEnabled = enabled ~= false
    if self._notificationHolder then
        self._notificationHolder.Visible = self.NotificationsEnabled
    end
    return self
end

local originalNotify03 = BoraUI.Notify

function BoraUI:Notify(options)
    if self.NotificationsEnabled == false then
        return nil
    end

    options = normalizeOptions(options)
    options.Duration = clamp(tonumber(options.Duration) or 4, 0.5, 30)

    return originalNotify03(self, options)
end

function BoraUI:CreateNotification(options)
    return self:Notify(options)
end

function BoraUI:CreateToast(text, duration)
    return self:Notify({
        Title = "BoraUI",
        Content = tostring(text or ""),
        Duration = duration or 3,
        Type = "Info",
    })
end

function BoraUI:CreateConfirm(options)
    options = normalizeOptions(options)

    local result = makeState(nil)
    local holder = Instance.new("Frame")
    holder.Name = "ConfirmDialog"
    holder.BackgroundColor3 = self.Theme.Background
    holder.BackgroundTransparency = 0.04
    holder.BorderSizePixel = 0
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = UDim2.fromScale(0.5, 0.5)
    holder.Size = UDim2.fromOffset(
        math.min(360, self.Main.AbsoluteSize.X - 30),
        178
    )
    holder.ZIndex = 100
    holder.Parent = self.Gui
    corner(holder, 14)
    stroke(holder, self.Theme.Border, 1, 0)

    local title = createText(holder, {
        Text = tostring(options.Title or "Confirm action"),
        TextSize = 16,
        Font = self.FontBold,
        TextColor3 = self.Theme.Text,
        Position = UDim2.fromOffset(18, 14),
        Size = UDim2.new(1, -36, 0, 26),
    })

    local message = createText(holder, {
        Text = tostring(options.Content or options.Message or "Are you sure?"),
        TextSize = 11,
        Font = self.Font,
        TextColor3 = self.Theme.MutedText,
        Position = UDim2.fromOffset(18, 43),
        Size = UDim2.new(1, -36, 0, 56),
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
    })

    local cancel = Instance.new("TextButton")
    cancel.AutoButtonColor = false
    cancel.BackgroundColor3 = self.Theme.Tertiary
    cancel.BorderSizePixel = 0
    cancel.Text = tostring(options.CancelText or "Cancel")
    cancel.TextColor3 = self.Theme.Text
    cancel.TextSize = 11
    cancel.Font = self.FontMedium
    cancel.Size = UDim2.fromOffset(105, 34)
    cancel.Position = UDim2.new(1, -230, 1, -48)
    cancel.Parent = holder
    corner(cancel, 8)

    local confirm = Instance.new("TextButton")
    confirm.AutoButtonColor = false
    confirm.BackgroundColor3 = self.Theme.Accent
    confirm.BorderSizePixel = 0
    confirm.Text = tostring(options.ConfirmText or "Confirm")
    confirm.TextColor3 = self.Theme.AccentText
    confirm.TextSize = 11
    confirm.Font = self.FontBold
    confirm.Size = UDim2.fromOffset(105, 34)
    confirm.Position = UDim2.new(1, -115, 1, -48)
    confirm.Parent = holder
    corner(confirm, 8)

    local function finish(value)
        if holder.Parent then
            tween(holder, 0.18, {
                Size = UDim2.fromOffset(holder.AbsoluteSize.X, 0),
            })
            task.delay(0.19, function()
                safeDestroy(holder)
            end)
        end
        result:Set(value)
    end

    self:_connect(cancel.MouseButton1Click, function()
        finish(false)
        safeCall(options.OnCancel)
    end)

    self:_connect(confirm.MouseButton1Click, function()
        finish(true)
        safeCall(options.OnConfirm)
    end)

    self:RegisterThemeCallback(function(theme)
        holder.BackgroundColor3 = theme.Background
        title.TextColor3 = theme.Text
        message.TextColor3 = theme.MutedText
        cancel.BackgroundColor3 = theme.Tertiary
        cancel.TextColor3 = theme.Text
        confirm.BackgroundColor3 = theme.Accent
        confirm.TextColor3 = theme.AccentText
    end)

    table.insert(self._objects, holder)

    return {
        Result = result,
        Close = function()
            finish(nil)
        end,
        Destroy = function()
            finish(nil)
        end,
    }
end

function BoraUI:CreateModal(options)
    return self:CreateConfirm(options)
end

function BoraUI:CreateOverlay(options)
    options = normalizeOptions(options)

    local overlay = Instance.new("Frame")
    overlay.Name = options.Name or "Overlay"
    overlay.BackgroundColor3 = options.Color or Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = options.Transparency or 0.4
    overlay.BorderSizePixel = 0
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.ZIndex = options.ZIndex or 90
    overlay.Parent = self.Gui

    if options.CloseOnClick ~= false then
        local closeButton = Instance.new("TextButton")
        closeButton.BackgroundTransparency = 1
        closeButton.BorderSizePixel = 0
        closeButton.Text = ""
        closeButton.Size = UDim2.fromScale(1, 1)
        closeButton.ZIndex = overlay.ZIndex + 1
        closeButton.Parent = overlay

        self:_connect(closeButton.MouseButton1Click, function()
            safeDestroy(overlay)
            safeCall(options.OnClose)
        end)
    end

    table.insert(self._objects, overlay)
    return overlay
end

function BoraUI:CreateSectionHeader(parent, options)
    options = normalizeOptions(options)

    local holder = Instance.new("Frame")
    holder.Name = "SectionHeader"
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.Size = options.Size or UDim2.new(1, 0, 0, 30)
    holder.Parent = parent

    local icon
    if options.Icon then
        icon = createIcon(
            holder,
            options.Icon,
            options.IconSize or 15,
            options.IconColor or self.Theme.Accent,
            3
        )
        icon.Position = UDim2.fromOffset(0, 7)
    end

    local label = createText(holder, {
        Text = tostring(options.Text or "Section"),
        TextSize = options.TextSize or 11,
        Font = self.FontBold,
        TextColor3 = options.TextColor or self.Theme.MutedText,
        Position = icon and UDim2.fromOffset(24, 0) or UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, icon and -24 or 0, 1, 0),
    })

    self:RegisterThemeCallback(function(theme)
        if not options.TextColor then
            label.TextColor3 = theme.MutedText
        end
        if icon and not options.IconColor then
            icon.ImageColor3 = theme.Accent
        end
    end)

    return {
        Instance = holder,
        Label = label,
        Icon = icon,
        SetText = function(_, value)
            label.Text = tostring(value)
        end,
        Destroy = function()
            holder:Destroy()
        end,
    }
end

function BoraUI:CreateDivider(parent, options)
    options = normalizeOptions(options)

    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.BackgroundColor3 = options.Color or self.Theme.Border
    divider.BackgroundTransparency = options.Transparency or 0.25
    divider.BorderSizePixel = 0
    divider.Size = options.Size or UDim2.new(1, 0, 0, 1)
    divider.Parent = parent

    self:RegisterThemeCallback(function(theme)
        if not options.Color then
            divider.BackgroundColor3 = theme.Border
        end
    end)

    return divider
end

function BoraUI:CreateContainer(parent, options)
    options = normalizeOptions(options)

    local frame = Instance.new("Frame")
    frame.Name = options.Name or "Container"
    frame.BackgroundTransparency = options.Transparent == false and 0 or 1
    frame.BackgroundColor3 = options.Color or self.Theme.Card
    frame.BorderSizePixel = 0
    frame.Size = options.Size or UDim2.new(1, 0, 0, 100)
    frame.Position = options.Position or UDim2.new()
    frame.Parent = parent

    if options.Glass then
        glassSurface(frame, self.Theme, {
            Color = options.Color or self.Theme.Card,
            Transparency = options.Transparency or GLASS_DEFAULTS.SurfaceTransparency,
            CornerRadius = options.CornerRadius or GLASS_DEFAULTS.CornerRadius,
        })
    elseif options.Rounded ~= false then
        corner(frame, options.CornerRadius or 10)
    end

    if options.Border then
        stroke(frame, options.BorderColor or self.Theme.Border, 1, options.BorderTransparency or 0.2)
    end

    if options.Padding then
        local p = options.Padding
        padding(frame, p.Left or 0, p.Right or 0, p.Top or 0, p.Bottom or 0)
    end

    if options.Layout then
        listLayout(
            frame,
            options.LayoutPadding or 6,
            options.Layout == "Horizontal"
        )
    end

    table.insert(self._objects, frame)
    return frame
end

function BoraUI:CreateSpacer(parent, size)
    local spacer = Instance.new("Frame")
    spacer.Name = "Spacer"
    spacer.BackgroundTransparency = 1
    spacer.BorderSizePixel = 0
    spacer.Size = UDim2.new(1, 0, 0, tonumber(size) or 8)
    spacer.Parent = parent
    return spacer
end

function BoraUI:BindVisibility(source, target, invert)
    if not source or not target then
        return nil
    end

    local connection = source.OnChanged and source.OnChanged:Connect(function(value)
        local visible = value == true
        if invert then
            visible = not visible
        end
        setVisible(target.Instance or target, visible)
    end)

    if connection then
        table.insert(self._connections, connection)
    end

    return connection
end

function BoraUI:BindText(source, target)
    if not source or not target or not source.OnChanged then
        return nil
    end

    local connection = source.OnChanged:Connect(function(value)
        setTextIfPresent(target.Label or target, value)
    end)

    table.insert(self._connections, connection)
    return connection
end

function BoraUI:BindValue(source, target)
    if not source or not target or not source.OnChanged then
        return nil
    end

    local connection = source.OnChanged:Connect(function(value)
        if target.SetValue then
            target:SetValue(value, false)
        elseif target.SetText then
            target:SetText(value)
        end
    end)

    table.insert(self._connections, connection)
    return connection
end

function BoraUI:CreateCommandPalette(options)
    options = normalizeOptions(options)

    local commands = options.Commands or {}
    local overlay = Instance.new("Frame")
    overlay.Name = "CommandPalette"
    overlay.BackgroundColor3 = self.Theme.Background
    overlay.BackgroundTransparency = 0.04
    overlay.BorderSizePixel = 0
    overlay.AnchorPoint = Vector2.new(0.5, 0)
    overlay.Position = UDim2.new(0.5, 0, 0, 74)
    overlay.Size = UDim2.new(
        0,
        math.min(options.Width or 420, 520),
        0,
        options.Height or 320
    )
    overlay.ZIndex = 120
    overlay.Visible = false
    overlay.Parent = self.Gui
    corner(overlay, 12)
    stroke(overlay, self.Theme.Border, 1, 0)

    local search = Instance.new("TextBox")
    search.BackgroundColor3 = self.Theme.Tertiary
    search.BorderSizePixel = 0
    search.ClearTextOnFocus = false
    search.PlaceholderText = "Type a command..."
    search.PlaceholderColor3 = self.Theme.MutedText
    search.Text = ""
    search.TextColor3 = self.Theme.Text
    search.TextSize = 12
    search.Font = self.Font
    search.Size = UDim2.new(1, -20, 0, 38)
    search.Position = UDim2.fromOffset(10, 10)
    search.Parent = overlay
    corner(search, 8)
    padding(search, 12, 8, 0, 0)

    local list = Instance.new("ScrollingFrame")
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.Size = UDim2.new(1, -20, 1, -58)
    list.Position = UDim2.fromOffset(10, 54)
    list.CanvasSize = UDim2.new()
    list.ScrollBarThickness = 2
    list.Parent = overlay
    listLayout(list, 5)

    local function rebuild(filter)
        filter = string.lower(tostring(filter or ""))

        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        for index, command in ipairs(commands) do
            local name = tostring(command.Name or "Command " .. index)
            local description = tostring(command.Description or "")
            local haystack = string.lower(name .. " " .. description)

            if filter == "" or string.find(haystack, filter, 1, true) then
                local button = Instance.new("TextButton")
                button.AutoButtonColor = false
                button.BackgroundColor3 = self.Theme.Card
                button.BorderSizePixel = 0
                button.Text = ""
                button.Size = UDim2.new(1, 0, 0, 46)
                button.Parent = list
                corner(button, 8)

                createText(button, {
                    Text = name,
                    TextSize = 12,
                    Font = self.FontMedium,
                    TextColor3 = self.Theme.Text,
                    Position = UDim2.fromOffset(12, 4),
                    Size = UDim2.new(1, -24, 0, 18),
                })

                createText(button, {
                    Text = description,
                    TextSize = 10,
                    Font = self.Font,
                    TextColor3 = self.Theme.MutedText,
                    Position = UDim2.fromOffset(12, 22),
                    Size = UDim2.new(1, -24, 0, 17),
                    TextTruncate = Enum.TextTruncate.AtEnd,
                })

                self:_connect(button.MouseButton1Click, function()
                    overlay.Visible = false
                    safeCall(command.Callback)
                end)
            end
        end
    end

    self:_connect(search:GetPropertyChangedSignal("Text"), function()
        rebuild(search.Text)
    end)

    self:RegisterThemeCallback(function(theme)
        overlay.BackgroundColor3 = theme.Background
        search.BackgroundColor3 = theme.Tertiary
        search.TextColor3 = theme.Text
        search.PlaceholderColor3 = theme.MutedText
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = theme.Card
            end
        end
    end)

    rebuild()

    local palette = {
        Instance = overlay,
        Search = search,
        Open = function()
            overlay.Visible = true
            search:CaptureFocus()
        end,
        Close = function()
            overlay.Visible = false
        end,
        Toggle = function()
            overlay.Visible = not overlay.Visible
            if overlay.Visible then
                search:CaptureFocus()
            end
        end,
        SetCommands = function(_, newCommands)
            commands = newCommands or {}
            rebuild(search.Text)
        end,
        Destroy = function()
            overlay:Destroy()
        end,
    }

    table.insert(self._objects, overlay)
    return palette
end

function BoraUI:CreateContextMenu(parent, options)
    options = normalizeOptions(options)

    local menu = Instance.new("Frame")
    menu.Name = "ContextMenu"
    menu.BackgroundColor3 = self.Theme.Tertiary
    menu.BorderSizePixel = 0
    menu.Size = UDim2.fromOffset(options.Width or 180, 0)
    menu.AutomaticSize = Enum.AutomaticSize.Y
    menu.Visible = false
    menu.ZIndex = 80
    menu.Parent = parent
    corner(menu, 9)
    stroke(menu, self.Theme.Border, 1, 0.15)
    padding(menu, 5, 5, 5, 5)
    listLayout(menu, 4)

    local items = options.Items or {}

    local function rebuild()
        for _, child in ipairs(menu:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        for _, item in ipairs(items) do
            local button = Instance.new("TextButton")
            button.AutoButtonColor = false
            button.BackgroundColor3 = self.Theme.Card
            button.BorderSizePixel = 0
            button.Text = tostring(item.Name or "Item")
            button.TextColor3 = self.Theme.Text
            button.TextSize = 11
            button.Font = self.FontMedium
            button.Size = UDim2.new(1, 0, 0, 32)
            button.ZIndex = 81
            button.Parent = menu
            corner(button, 6)

            self:_connect(button.MouseButton1Click, function()
                menu.Visible = false
                safeCall(item.Callback)
            end)

            self:_connect(button.MouseEnter, function()
                tween(button, 0.1, {
                    BackgroundColor3 = self.Theme.Accent,
                    TextColor3 = self.Theme.AccentText,
                })
            end)

            self:_connect(button.MouseLeave, function()
                tween(button, 0.12, {
                    BackgroundColor3 = self.Theme.Card,
                    TextColor3 = self.Theme.Text,
                })
            end)
        end
    end

    rebuild()

    local api = {
        Instance = menu,
        Open = function(_, position)
            if position then
                menu.Position = position
            end
            menu.Visible = true
        end,
        Close = function()
            menu.Visible = false
        end,
        Toggle = function()
            menu.Visible = not menu.Visible
        end,
        SetItems = function(_, newItems)
            items = newItems or {}
            rebuild()
        end,
        Destroy = function()
            menu:Destroy()
        end,
    }

    self:RegisterThemeCallback(function(theme)
        menu.BackgroundColor3 = theme.Tertiary
        local uiStroke = menu:FindFirstChildOfClass("UIStroke")
        if uiStroke then
            uiStroke.Color = theme.Border
        end
        for _, child in ipairs(menu:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = theme.Card
                child.TextColor3 = theme.Text
            end
        end
    end)

    table.insert(self._objects, menu)
    return api
end

function BoraUI:CreateHotkey(options)
    options = normalizeOptions(options)

    local key = options.Key
    local callback = options.Callback

    local connection = self:_connect(UserInputService.InputBegan, function(input, processed)
        if processed or not key then
            return
        end

        local matches = false

        if typeof(key) == "EnumItem" then
            matches = input.KeyCode == key
        elseif type(key) == "string" then
            matches = input.KeyCode.Name == key
        end

        if matches then
            safeCall(callback, input)
        end
    end)

    return {
        Connection = connection,
        SetKey = function(_, newKey)
            key = newKey
        end,
        GetKey = function()
            return key
        end,
        Destroy = function()
            if connection then
                connection:Disconnect()
            end
        end,
    }
end

function BoraUI:CreateSoundFeedback(options)
    options = normalizeOptions(options)

    local clickId = options.ClickSound or ""
    local hoverId = options.HoverSound or ""
    local volume = tonumber(options.Volume) or 0.2

    local click = Instance.new("Sound")
    click.Name = "BoraClick"
    click.SoundId = clickId
    click.Volume = volume
    click.Parent = self.Gui

    local hover = Instance.new("Sound")
    hover.Name = "BoraHover"
    hover.SoundId = hoverId
    hover.Volume = volume
    hover.Parent = self.Gui

    table.insert(self._objects, click)
    table.insert(self._objects, hover)

    return {
        PlayClick = function()
            if click.SoundId ~= "" then
                click:Play()
            end
        end,
        PlayHover = function()
            if hover.SoundId ~= "" then
                hover:Play()
            end
        end,
        Destroy = function()
            click:Destroy()
            hover:Destroy()
        end,
    }
end

function BoraUI:CreateAnimationController()
    local controller = {
        Duration = 0.2,
        EasingStyle = Enum.EasingStyle.Quint,
        EasingDirection = Enum.EasingDirection.Out,
    }

    function controller:SetDuration(value)
        self.Duration = clamp(tonumber(value) or 0.2, 0.05, 2)
        return self
    end

    function controller:SetStyle(style)
        if typeof(style) == "EnumItem" then
            self.EasingStyle = style
        end
        return self
    end

    function controller:SetDirection(direction)
        if typeof(direction) == "EnumItem" then
            self.EasingDirection = direction
        end
        return self
    end

    function controller:Play(instance, properties)
        if not instance then
            return nil
        end
        return tween(
            instance,
            self.Duration,
            properties,
            self.EasingStyle,
            self.EasingDirection
        )
    end

    return controller
end

function BoraUI:SetAnimationSpeed(multiplier)
    multiplier = clamp(tonumber(multiplier) or 1, 0.25, 3)
    self.AnimationSpeed = multiplier
    return self
end

function BoraUI:GetAnimationSpeed()
    return self.AnimationSpeed or 1
end

function BoraUI:SetReducedMotion(enabled)
    self.ReducedMotion = enabled == true
    return self
end

function BoraUI:Animate(instance, properties, duration)
    if self.ReducedMotion then
        for property, value in pairs(properties or {}) do
            instance[property] = value
        end
        return nil
    end

    local speed = self.AnimationSpeed or 1
    return tween(instance, (duration or 0.2) / speed, properties)
end

function BoraUI:SetTransparency(value)
    value = clamp(tonumber(value) or 0.08, 0, 0.5)
    self.Theme.WindowTransparency = value

    if self.Main then
        self.Main.BackgroundTransparency = value
    end

    return self
end

function BoraUI:SetGlassDepth(value)
    value = clamp(tonumber(value) or 8, 0, 24)
    GLASS_DEFAULTS.Depth = value

    if self.Main then
        local depth = self.Main:FindFirstChild("GlassSurfaceHolder")
        if depth then
            local layer = depth:FindFirstChild("GlassDepth")
            if layer then
                layer.Position = UDim2.fromOffset(0, value)
            end
        end
    end

    return self
end

function BoraUI:SetCornerRadius(value)
    value = clamp(tonumber(value) or 12, 2, 24)
    GLASS_DEFAULTS.CornerRadius = value

    for _, object in ipairs(self._objects) do
        if object and object.Parent then
            local uiCorner = object:FindFirstChildOfClass("UICorner")
            if uiCorner then
                uiCorner.CornerRadius = UDim.new(0, value)
            end
        end
    end

    return self
end

function BoraUI:SetBorderTransparency(value)
    value = clamp(tonumber(value) or 0.35, 0, 1)
    GLASS_DEFAULTS.BorderTransparency = value

    for _, object in ipairs(self._objects) do
        if object and object.Parent then
            local uiStroke = object:FindFirstChildOfClass("UIStroke")
            if uiStroke then
                uiStroke.Transparency = value
            end
        end
    end

    return self
end

function BoraUI:Refresh()
    if self.Destroyed then
        return self
    end

    self:_updateResponsive()
    self:_enhanceTabButtons()
    self:_filter(self.Search and self.Search.Text or "")
    self:_refreshTheme()
    return self
end

function BoraUI:GetState()
    return {
        Version = BORA03_VERSION,
        Theme = self.ThemeName,
        Font = tostring(self.Font),
        TabCount = #self.Tabs,
        SelectedTab = self.SelectedTab and self.SelectedTab.Name or nil,
        Minimized = self.Minimized,
        Responsive = self.Responsive,
        ReducedMotion = self.ReducedMotion == true,
        Scale = self.Scale or 1,
    }
end

function BoraUI:ExportState()
    local state = self:GetState()
    state.Options = {
        Title = self.Options.Title,
        Subtitle = self.Options.Subtitle,
        SidebarWidth = self.Options.SidebarWidth,
        PillText = self.Options.PillText,
    }
    return state
end

function BoraUI:ApplyState(state)
    if type(state) ~= "table" then
        return false
    end

    if state.Theme and THEMES[state.Theme] then
        self:SetTheme(state.Theme)
    end

    if state.Font and FONT_MAP[state.Font] then
        self:SetFont(state.Font)
    end

    if state.Scale then
        self:SetScale(state.Scale)
    end

    if state.SidebarWidth then
        self:SetSidebarWidth(state.SidebarWidth)
    end

    if state.Minimized ~= nil then
        self:SetMinimized(state.Minimized)
    end

    if state.SelectedTab then
        for _, tab in ipairs(self.Tabs) do
            if tab.Name == state.SelectedTab then
                self:SelectTab(tab)
                break
            end
        end
    end

    return true
end

function BoraUI:CreateSettingsTab(options)
    options = normalizeOptions(options)

    local tab = self:CreateTab({
        Name = options.Name or "Settings",
        Icon = options.Icon or "settings",
    })

    tab:CreateSection("Appearance")

    tab:CreateDropdown({
        Name = "Theme",
        Options = self:GetThemes(),
        CurrentOption = self.ThemeName,
        Callback = function(value)
            self:SetTheme(value)
        end,
    })

    tab:CreateDropdown({
        Name = "Font",
        Options = self:GetFonts(),
        CurrentOption = "Gotham",
        Callback = function(value)
            self:SetFont(value)
        end,
    })

    tab:CreateSlider({
        Name = "UI Scale",
        Min = 75,
        Max = 135,
        Increment = 5,
        Default = 100,
        Callback = function(value)
            self:SetScale(value / 100)
        end,
    })

    tab:CreateToggle({
        Name = "Reduced Motion",
        Description = "Use instant UI changes instead of animated transitions.",
        CurrentValue = self.ReducedMotion == true,
        Callback = function(value)
            self:SetReducedMotion(value)
        end,
    })

    tab:CreateSection("Window")

    tab:CreateSlider({
        Name = "Sidebar Width",
        Min = 92,
        Max = 220,
        Increment = 4,
        Default = self.Options.SidebarWidth,
        Callback = function(value)
            self:SetSidebarWidth(value, true)
        end,
    })

    tab:CreateToggle({
        Name = "Responsive",
        Description = "Automatically adapt the window to smaller screens.",
        CurrentValue = self.Responsive ~= false,
        Callback = function(value)
            self:SetResponsive(value)
        end,
    })

    tab:CreateToggle({
        Name = "Search",
        Description = "Show the page search field.",
        CurrentValue = self.SearchEnabled ~= false,
        Callback = function(value)
            self:SetSearchEnabled(value)
        end,
    })

    tab:CreateSection("Glass")

    tab:CreateSlider({
        Name = "Glass Depth",
        Min = 0,
        Max = 20,
        Increment = 1,
        Default = GLASS_DEFAULTS.Depth,
        Callback = function(value)
            self:SetGlassDepth(value)
        end,
    })

    tab:CreateSlider({
        Name = "Border Opacity",
        Min = 0,
        Max = 100,
        Increment = 5,
        Default = 65,
        Callback = function(value)
            self:SetBorderTransparency(1 - value / 100)
        end,
    })

    return tab
end

function BoraUI:CreateDebugPanel(parent)
    local panel = self:CreateContainer(parent, {
        Name = "DebugPanel",
        Size = UDim2.new(1, 0, 0, 160),
        Glass = true,
        Border = true,
        Padding = {
            Left = 12,
            Right = 12,
            Top = 8,
            Bottom = 8,
        },
        Layout = "Vertical",
        LayoutPadding = 4,
    })

    local header = self:CreateSectionHeader(panel, {
        Text = "Library State",
        Icon = "activity",
    })

    local stateLabel = createText(panel, {
        Text = "",
        TextSize = 10,
        Font = self.Font,
        TextColor3 = self.Theme.MutedText,
        Size = UDim2.new(1, 0, 0, 90),
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
    })

    local refresh = Instance.new("TextButton")
    refresh.AutoButtonColor = false
    refresh.BackgroundColor3 = self.Theme.Tertiary
    refresh.BorderSizePixel = 0
    refresh.Text = "Refresh"
    refresh.TextColor3 = self.Theme.Text
    refresh.TextSize = 10
    refresh.Font = self.FontBold
    refresh.Size = UDim2.new(1, 0, 0, 30)
    refresh.Parent = panel
    corner(refresh, 7)

    local function render()
        local state = self:GetState()
        local lines = {
            "Version: " .. tostring(state.Version),
            "Theme: " .. tostring(state.Theme),
            "Tabs: " .. tostring(state.TabCount),
            "Selected: " .. tostring(state.SelectedTab or "None"),
            "Scale: " .. string.format("%.2f", state.Scale),
            "Responsive: " .. tostring(state.Responsive),
            "Reduced Motion: " .. tostring(state.ReducedMotion),
            "Minimized: " .. tostring(state.Minimized),
        }
        stateLabel.Text = table.concat(lines, "\n")
    end

    self:_connect(refresh.MouseButton1Click, render)

    self:RegisterThemeCallback(function(theme)
        stateLabel.TextColor3 = theme.MutedText
        refresh.BackgroundColor3 = theme.Tertiary
        refresh.TextColor3 = theme.Text
    end)

    render()
    return panel
end

local originalCreateTab03 = BoraUI.CreateTab

function BoraUI:CreateTab(options)
    local tab = originalCreateTab03(self, options)

    if tab.Page then
        tab.Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    end

    if tab.Button and not tab._hover03 then
        tab._hover03 = true

        self:_connect(tab.Button.MouseButton1Down, function()
            if tab.Selected then
                return
            end
            tween(tab.Button, 0.06, {
                BackgroundTransparency = 0.82,
            })
        end)

        self:_connect(tab.Button.MouseButton1Up, function()
            if not tab.Selected then
                tween(tab.Button, 0.1, {
                    BackgroundTransparency = 1,
                })
            end
        end)
    end

    return tab
end

local originalCreateButton03 = TabMethods.CreateButton

function TabMethods:CreateButton(options)
    local object = originalCreateButton03(self, options)

    if object and object.Button and not object._enhanced03 then
        object._enhanced03 = true
        local window = self.Window

        window:_connect(object.Button.MouseEnter, function()
            tween(object.Instance, 0.12, {
                BackgroundColor3 = window.Theme.Tertiary,
            })
        end)

        window:_connect(object.Button.MouseLeave, function()
            tween(object.Instance, 0.15, {
                BackgroundColor3 = window.Theme.Card,
            })
        end)
    end

    return object
end

local originalCreateToggle03 = TabMethods.CreateToggle

function TabMethods:CreateToggle(options)
    local object = originalCreateToggle03(self, options)
    if object then
        object.State = makeState(object:GetValue())

        local originalSet = object.SetValue
        object.SetValue = function(_, value, fire)
            originalSet(object, value, fire)
            object.State:Set(value, fire ~= false)
        end
    end
    return object
end

local originalCreateSlider03 = TabMethods.CreateSlider

function TabMethods:CreateSlider(options)
    local object = originalCreateSlider03(self, options)
    if object then
        object.State = makeState(object:GetValue())

        local originalSet = object.SetValue
        object.SetValue = function(_, value, fire)
            originalSet(object, value, fire)
            object.State:Set(object:GetValue(), fire ~= false)
        end
    end
    return object
end

function BoraUI:EnableTouchOptimizations(enabled)
    self.TouchOptimized = enabled ~= false

    if not self.TouchOptimized then
        return self
    end

    for _, tab in ipairs(self.Tabs) do
        if tab.Button then
            tab.Button.Size = UDim2.new(1, 0, 0, 42)
        end
    end

    return self
end

function BoraUI:CreateMobileBar(options)
    options = normalizeOptions(options)

    local bar = Instance.new("Frame")
    bar.Name = "MobileBar"
    bar.BackgroundColor3 = self.Theme.Secondary
    bar.BackgroundTransparency = 0.08
    bar.BorderSizePixel = 0
    bar.AnchorPoint = Vector2.new(0.5, 1)
    bar.Position = UDim2.new(0.5, 0, 1, -12)
    bar.Size = UDim2.new(1, -24, 0, 52)
    bar.ZIndex = 40
    bar.Parent = self.Gui
    corner(bar, 14)
    stroke(bar, self.Theme.Border, 1, 0.15)

    local layout = listLayout(bar, 5, true)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center

    local items = options.Items or {}
    for _, item in ipairs(items) do
        local button = Instance.new("TextButton")
        button.AutoButtonColor = false
        button.BackgroundTransparency = 1
        button.BorderSizePixel = 0
        button.Text = ""
        button.Size = UDim2.fromOffset(44, 42)
        button.ZIndex = 41
        button.Parent = bar

        local icon = createIcon(
            button,
            item.Icon or "circle",
            18,
            self.Theme.MutedText,
            42
        )
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.fromScale(0.5, 0.38)

        local label = createText(button, {
            Text = tostring(item.Name or ""),
            TextSize = 8,
            Font = self.FontBold,
            TextColor3 = self.Theme.MutedText,
            Position = UDim2.new(0, 0, 0.58, 0),
            Size = UDim2.new(1, 0, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Center,
        })

        self:_connect(button.MouseButton1Click, function()
            safeCall(item.Callback)
        end)
    end

    self:RegisterThemeCallback(function(theme)
        bar.BackgroundColor3 = theme.Secondary
        local uiStroke = bar:FindFirstChildOfClass("UIStroke")
        if uiStroke then
            uiStroke.Color = theme.Border
        end
    end)

    table.insert(self._objects, bar)
    return bar
end

function BoraUI:DestroyObjects(predicate)
    if type(predicate) ~= "function" then
        return 0
    end

    local destroyed = 0

    for index = #self._objects, 1, -1 do
        local object = self._objects[index]
        local remove = false

        local success = pcall(function()
            remove = predicate(object) == true
        end)

        if success and remove then
            safeDestroy(object)
            table.remove(self._objects, index)
            destroyed += 1
        end
    end

    return destroyed
end

function BoraUI:DisconnectAll()
    for _, connection in ipairs(self._connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    self._connections = {}
    return self
end

function BoraUI:Rebind()
    if self.Destroyed then
        return false
    end

    self:_enhanceTabButtons()
    self:_updateResponsive()
    return true
end

function BoraUI:IsAlive()
    return not self.Destroyed
        and self.Gui ~= nil
        and self.Gui.Parent ~= nil
end

BoraUI.Version = BORA03_VERSION
BoraUI.Release = {
    Name = "BoraUI",
    Version = BORA03_VERSION,
    Style = "Liquid Glass",
    IconSystem = "Lucide",
}

return BoraUI

-- hehe.lua v4
-- Clean smooth Roblox UI library based on the provided screenshots.
-- Includes: Notify, AddParagraph, AddButton, AddToggle, AddSlider, AddDropdown,
-- AddColorpicker, AddKeybind, AddInput, AddRadio, AddNametagPreview, SetConfigs.

local UI = {}
UI.Version = "4.0"
UI.Flags = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Theme = {
    Window = Color3.fromRGB(8, 8, 9),
    Sidebar = Color3.fromRGB(15, 15, 16),
    Card = Color3.fromRGB(18, 18, 19),
    Input = Color3.fromRGB(18, 18, 20),
    Border = Color3.fromRGB(43, 43, 46),
    Divider = Color3.fromRGB(40, 40, 43),
    Text = Color3.fromRGB(238, 238, 240),
    SubText = Color3.fromRGB(158, 158, 164),
    Muted = Color3.fromRGB(92, 92, 98),
    ToggleOff = Color3.fromRGB(95, 95, 100),
    ToggleOn = Color3.fromRGB(255, 255, 255),
    KnobOff = Color3.fromRGB(245, 245, 245),
    KnobOn = Color3.fromRGB(13, 13, 14),
    Green = Color3.fromRGB(132, 165, 33),
    Health = Color3.fromRGB(150, 200, 85)
}

local function getParent()
    local ok, hui = pcall(function()
        return gethui and gethui()
    end)
    if ok and hui then
        return hui
    end

    local okCore = pcall(function()
        local sg = Instance.new("ScreenGui")
        sg.Parent = CoreGui
        sg:Destroy()
    end)
    if okCore then
        return CoreGui
    end

    return LocalPlayer:WaitForChild("PlayerGui")
end

local function new(className, props)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    return obj
end

local function corner(parent, radius)
    return new("UICorner", {
        CornerRadius = radius or UDim.new(0, 14),
        Parent = parent
    })
end

local function stroke(parent, color, thickness, transparency)
    return new("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0.35,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent
    })
end

local function padding(parent, left, right, top, bottom)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
        Parent = parent
    })
end

local function list(parent, dir, gap)
    return new("UIListLayout", {
        FillDirection = dir or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 8),
        Parent = parent
    })
end

local function tween(obj, time, props, style, dir)
    local t = TweenService:Create(
        obj,
        TweenInfo.new(time or 0.18, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
        props
    )
    t:Play()
    return t
end

local function textWidth(txt, size)
    local ok, result = pcall(function()
        return TextService:GetTextSize(tostring(txt), size, Enum.Font.Gotham, Vector2.new(10000, size)).X
    end)
    return ok and result or 80
end

local function makeDraggable(handle, target)
    target = target or handle
    local dragging = false
    local startInput
    local startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startInput = input.Position
            startPos = target.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - startInput
            target.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local function keyName(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then return "MB1" end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then return "MB2" end
    if input.UserInputType == Enum.UserInputType.MouseButton3 then return "MB3" end
    if input.KeyCode and input.KeyCode ~= Enum.KeyCode.Unknown then return input.KeyCode.Name end
    return nil
end

local function setZ(root, z)
    if root:IsA("GuiObject") then
        root.ZIndex = z
    end
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("GuiObject") then
            d.ZIndex = z + 1
        end
    end
end

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Card = {}
Card.__index = Card

local function ensurePopupLayer(window)
    if window.PopupLayer and window.PopupLayer.Parent then
        return window.PopupLayer
    end

    local layer = new("Frame", {
        Name = "PopupLayer",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Parent = window.Gui
    })
    layer.ZIndex = 3000

    local closer = new("TextButton", {
        Name = "PopupCloser",
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        Parent = layer
    })
    closer.ZIndex = 3001

    closer.MouseButton1Click:Connect(function()
        if window.ActivePopup then
            window.ActivePopup.Visible = false
            window.ActivePopup = nil
        end
        closer.Visible = false
    end)

    window.PopupLayer = layer
    window.PopupCloser = closer
    return layer
end

local function popupPos(anchor, width, height)
    local cam = workspace.CurrentCamera
    local view = cam and cam.ViewportSize or Vector2.new(1920, 1080)

    local p = anchor.AbsolutePosition
    local s = anchor.AbsoluteSize
    local x = p.X + s.X - width
    local y = p.Y + s.Y + 8

    if x + width > view.X - 8 then
        x = view.X - width - 8
    end
    if x < 8 then x = 8 end

    if y + height > view.Y - 8 then
        y = math.max(8, p.Y - height - 8)
    end

    return UDim2.fromOffset(math.floor(x), math.floor(y))
end

local function showPopup(window, popup, anchor, width, height)
    ensurePopupLayer(window)

    if window.ActivePopup and window.ActivePopup ~= popup then
        window.ActivePopup.Visible = false
    end

    popup.Parent = window.PopupLayer
    popup.Position = popupPos(anchor, width, height)
    popup.Size = UDim2.fromOffset(width, 0)
    popup.Visible = true
    setZ(popup, 3200)

    window.PopupCloser.Visible = true
    window.ActivePopup = popup

    tween(popup, 0.17, {
        Size = UDim2.fromOffset(width, height)
    })
end

local function hidePopup(window, popup)
    if popup then
        popup.Visible = false
    end
    if window.ActivePopup == popup then
        window.ActivePopup = nil
    end
    if window.PopupCloser then
        window.PopupCloser.Visible = false
    end
end

local function createSwitch(parent, default, callback)
    local button = new("TextButton", {
        AutoButtonColor = false,
        Text = "",
        BackgroundColor3 = default and Theme.ToggleOn or Theme.ToggleOff,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(54, 28),
        Parent = parent
    })
    corner(button, UDim.new(1, 0))

    local knob = new("Frame", {
        BackgroundColor3 = default and Theme.KnobOn or Theme.KnobOff,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = default and UDim2.new(1, -14, 0.5, 0) or UDim2.new(0, 14, 0.5, 0),
        Size = UDim2.fromOffset(22, 22),
        Parent = button
    })
    corner(knob, UDim.new(1, 0))

    local state = default and true or false

    local object = {}

    function object:Set(v)
        state = v and true or false
        tween(button, 0.16, {
            BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff
        })
        tween(knob, 0.16, {
            Position = state and UDim2.new(1, -14, 0.5, 0) or UDim2.new(0, 14, 0.5, 0),
            BackgroundColor3 = state and Theme.KnobOn or Theme.KnobOff
        })
        if callback then
            task.spawn(callback, state)
        end
    end

    function object:Get()
        return state
    end

    button.MouseButton1Click:Connect(function()
        object:Set(not state)
    end)

    object.Button = button
    object.Knob = knob
    return object
end

local function createCheck(parent, default, callback)
    local button = new("TextButton", {
        AutoButtonColor = false,
        Text = "",
        BackgroundColor3 = default and Theme.Text or Color3.fromRGB(98, 98, 102),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(24, 24),
        Parent = parent
    })
    corner(button, UDim.new(0, 6))

    local mark = new("TextLabel", {
        BackgroundTransparency = 1,
        Text = "✓",
        Font = Enum.Font.GothamBold,
        TextSize = 17,
        TextColor3 = Color3.fromRGB(44, 44, 48),
        Size = UDim2.fromScale(1, 1),
        Visible = default and true or false,
        Parent = button
    })

    local state = default and true or false
    local object = {}

    function object:Set(v)
        state = v and true or false
        mark.Visible = state
        button.BackgroundColor3 = state and Theme.Text or Color3.fromRGB(98, 98, 102)
        if callback then
            task.spawn(callback, state)
        end
    end

    function object:Get()
        return state
    end

    button.MouseButton1Click:Connect(function()
        object:Set(not state)
    end)

    object.Button = button
    return object
end

local function createRadio(parent, values, default, callback)
    local frame = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 28),
        Parent = parent
    })

    local layout = list(frame, Enum.FillDirection.Horizontal, 16)
    layout.VerticalAlignment = Enum.VerticalAlignment.Center

    local state = default or values[1]
    local buttons = {}

    local object = {}

    local function render()
        for _, item in ipairs(buttons) do
            local active = item.Value == state
            item.Dot.BackgroundColor3 = active and Theme.Text or Color3.fromRGB(58, 58, 63)
            item.Inner.Visible = active
            item.Label.TextColor3 = active and Theme.Text or Theme.SubText
        end
        if callback then
            task.spawn(callback, state)
        end
    end

    for _, value in ipairs(values) do
        local width = textWidth(value, 15) + 36
        local row = new("TextButton", {
            AutoButtonColor = false,
            Text = "",
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(width, 28),
            Parent = frame
        })

        local dot = new("Frame", {
            BackgroundColor3 = Color3.fromRGB(58, 58, 63),
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 5),
            Size = UDim2.fromOffset(18, 18),
            Parent = row
        })
        corner(dot, UDim.new(1, 0))

        local inner = new("Frame", {
            BackgroundColor3 = Theme.Window,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(8, 8),
            Visible = false,
            Parent = dot
        })
        corner(inner, UDim.new(1, 0))

        local label = new("TextLabel", {
            BackgroundTransparency = 1,
            Text = value,
            Font = Enum.Font.Gotham,
            TextSize = 15,
            TextColor3 = Theme.SubText,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(28, 0),
            Size = UDim2.new(1, -28, 1, 0),
            Parent = row
        })

        row.MouseButton1Click:Connect(function()
            state = value
            render()
        end)

        table.insert(buttons, {
            Value = value,
            Row = row,
            Dot = dot,
            Inner = inner,
            Label = label
        })
    end

    function object:Set(value)
        state = value
        render()
    end

    function object:Get()
        return state
    end

    object.Frame = frame
    render()
    return object
end

function UI:CreateWindow(cfg)
    cfg = cfg or {}

    if self.Window and self.Window.Gui then
        self.Window.Gui:Destroy()
    end

    local gui = new("ScreenGui", {
        Name = cfg.Name or "hehe_SmoothUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 2147483647,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = getParent()
    })

    local windowFrame = new("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = cfg.Size or UDim2.fromOffset(790, 525),
        BackgroundColor3 = Theme.Window,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = gui
    })
    corner(windowFrame, UDim.new(0, 22))
    stroke(windowFrame, Theme.Border, 1, 0.15)

    local scale = new("UIScale", {
        Scale = 0.92,
        Parent = windowFrame
    })
    tween(scale, 0.32, {Scale = 1}, Enum.EasingStyle.Back)

    local tabWidth = cfg.TabWidth or 190

    local sidebar = new("Frame", {
        Name = "Sidebar",
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(0, tabWidth, 1, 0),
        Parent = windowFrame
    })
    corner(sidebar, UDim.new(0, 22))

    new("Frame", {
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 24, 1, 0),
        Parent = sidebar
    })

    new("Frame", {
        BackgroundColor3 = Theme.Border,
        BackgroundTransparency = 0.42,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        Parent = sidebar
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Text = cfg.SidebarTitle or "Modules",
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(18, 20),
        Size = UDim2.new(1, -36, 0, 22),
        Parent = sidebar
    })

    local tabList = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 54),
        Size = UDim2.new(1, -28, 1, -68),
        Parent = sidebar
    })
    list(tabList, Enum.FillDirection.Vertical, 6)

    local content = new("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, tabWidth, 0, 0),
        Size = UDim2.new(1, -tabWidth, 1, 0),
        Parent = windowFrame
    })

    local topbar = new("Frame", {
        Name = "Topbar",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 62),
        Parent = content
    })
    drag(topbar, windowFrame)

    new("Frame", {
        BackgroundColor3 = Theme.Border,
        BackgroundTransparency = 0.42,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 1),
        Parent = topbar
    })

    local configBtn = new("TextButton", {
        AutoButtonColor = false,
        Text = "Select Config",
        Font = Enum.Font.Gotham,
        TextSize = 15,
        TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundColor3 = Theme.Input,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(16, 12),
        Size = UDim2.fromOffset(180, 38),
        Parent = topbar
    })
    corner(configBtn, UDim.new(0, 11))
    stroke(configBtn, Theme.Border, 1, 0.34)
    padding(configBtn, 12, 32, 0, 0)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Text = "⌄",
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = Theme.Text,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, -1),
        Size = UDim2.fromOffset(18, 18),
        Parent = configBtn
    })

    local search = new("TextBox", {
        ClearTextOnFocus = false,
        Text = "",
        PlaceholderText = "Search...",
        TextColor3 = Theme.Text,
        PlaceholderColor3 = Theme.Muted,
        Font = Enum.Font.Gotham,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundColor3 = Theme.Input,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 12),
        Size = UDim2.fromOffset(190, 38),
        Parent = topbar
    })
    corner(search, UDim.new(0, 11))
    stroke(search, Theme.Border, 1, 0.34)
    padding(search, 12, 12, 0, 0)

    local pages = new("Frame", {
        Name = "Pages",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 62),
        Size = UDim2.new(1, 0, 1, -62),
        Parent = content
    })

    local notifyLayer = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -18, 1, -18),
        Size = UDim2.fromOffset(310, 400),
        Parent = gui
    })
    local notifyList = list(notifyLayer, Enum.FillDirection.Vertical, 10)
    notifyList.VerticalAlignment = Enum.VerticalAlignment.Bottom

    local window = setmetatable({
        Gui = gui,
        Frame = windowFrame,
        Scale = scale,
        Sidebar = sidebar,
        Content = content,
        Topbar = topbar,
        TabList = tabList,
        Pages = pages,
        ConfigButton = configBtn,
        Search = search,
        NotifyLayer = notifyLayer,
        Tabs = {},
        SelectedTab = nil,
        Configs = {},
        MinimizeKey = cfg.MinimizeKey or Enum.KeyCode.RightShift,
        Minimized = false
    }, Window)

    self.Window = window
    ensurePopupLayer(window)

    search:GetPropertyChangedSignal("Text"):Connect(function()
        local query = string.lower(search.Text)
        if not window.SelectedTab then return end

        for _, card in ipairs(window.SelectedTab.Cards) do
            local hay = string.lower(card.SearchText or "")
            card.Frame.Visible = query == "" or hay:find(query, 1, true) ~= nil
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == window.MinimizeKey then
            window:SetMinimized(not window.Minimized)
        end
    end)

    return window
end

function Window:SetMinimized(state)
    self.Minimized = state

    if state then
        tween(self.Scale, 0.22, {Scale = 0.92})
        tween(self.Frame, 0.22, {BackgroundTransparency = 1})
        task.delay(0.23, function()
            if self.Minimized then
                self.Frame.Visible = false
            end
        end)
    else
        self.Frame.Visible = true
        self.Scale.Scale = 0.92
        self.Frame.BackgroundTransparency = 1
        tween(self.Scale, 0.26, {Scale = 1}, Enum.EasingStyle.Back)
        tween(self.Frame, 0.22, {BackgroundTransparency = 0})
    end
end

function Window:SetConfigs(configs, defaultName, callback)
    self.Configs = configs or {}
    self.ConfigButton.Text = defaultName or self.Configs[1] or "Select Config"

    if self.ConfigPopup then
        self.ConfigPopup:Destroy()
    end

    local popup = new("Frame", {
        Name = "ConfigPopup",
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        Parent = ensurePopupLayer(self)
    })
    corner(popup, UDim.new(0, 14))
    stroke(popup, Theme.Border, 1, 0.25)
    setZ(popup, 3300)

    list(popup, Enum.FillDirection.Vertical, 0)

    for _, cfgName in ipairs(self.Configs) do
        local item = new("TextButton", {
            AutoButtonColor = false,
            Text = cfgName,
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 30),
            Parent = popup
        })
        item.ZIndex = 3301
        padding(item, 12, 12, 0, 0)

        item.MouseButton1Click:Connect(function()
            self.ConfigButton.Text = cfgName
            hidePopup(self, popup)
            if callback then
                task.spawn(callback, cfgName)
            end
        end)
    end

    self.ConfigPopup = popup

    self.ConfigButton.MouseButton1Click:Connect(function()
        showPopup(self, popup, self.ConfigButton, 180, math.min(#self.Configs * 30, 180))
    end)

    return popup
end

function Window:AddTab(title)
    if type(title) == "table" then
        title = title.Title
    end
    title = title or "Tab"

    local tabButton = new("TextButton", {
        AutoButtonColor = false,
        Text = title,
        Font = Enum.Font.Gotham,
        TextSize = 16,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundColor3 = Color3.fromRGB(68, 68, 72),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 38),
        Parent = self.TabList
    })
    corner(tabButton, UDim.new(0, 10))
    padding(tabButton, 10, 10, 0, 0)

    local page = new("ScrollingFrame", {
        Name = title .. "Page",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
        Size = UDim2.fromScale(1, 1),
        Parent = self.Pages
    })
    padding(page, 14, 14, 16, 16)
    list(page, Enum.FillDirection.Vertical, 14)

    local tab = setmetatable({
        Window = self,
        Button = tabButton,
        Page = page,
        Cards = {},
        Title = title
    }, Tab)

    tabButton.MouseButton1Click:Connect(function()
        self:SelectTab(tab)
    end)

    table.insert(self.Tabs, tab)

    if not self.SelectedTab then
        self:SelectTab(tab)
    end

    return tab
end

function Window:SelectTab(tab)
    if type(tab) == "number" then
        tab = self.Tabs[tab]
    end
    if not tab then return end

    self.SelectedTab = tab

    for _, t in ipairs(self.Tabs) do
        local selected = t == tab
        t.Page.Visible = selected
        tween(t.Button, 0.16, {
            BackgroundTransparency = selected and 0 or 1
        })
    end
end

function Window:Notify(cfg)
    cfg = cfg or {}

    local frame = new("Frame", {
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, cfg.SubContent and 84 or 64),
        Parent = self.NotifyLayer
    })
    corner(frame, UDim.new(0, 16))
    stroke(frame, Theme.Border, 1, 0.25)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Text = cfg.Title or "Notification",
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(16, 10),
        Size = UDim2.new(1, -32, 0, 20),
        Parent = frame
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Text = cfg.Content or "",
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Theme.SubText,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.fromOffset(16, 32),
        Size = UDim2.new(1, -32, 0, cfg.SubContent and 20 or 24),
        Parent = frame
    })

    if cfg.SubContent then
        new("TextLabel", {
            BackgroundTransparency = 1,
            Text = cfg.SubContent,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Theme.Green,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(16, 56),
            Size = UDim2.new(1, -32, 0, 18),
            Parent = frame
        })
    end

    local bar = new("Frame", {
        BackgroundColor3 = Theme.Green,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(0, 0, 0, 3),
        Parent = frame
    })
    corner(bar, UDim.new(1, 0))

    local scale = new("UIScale", {
        Scale = 0.84,
        Parent = frame
    })
    tween(scale, 0.18, {Scale = 1}, Enum.EasingStyle.Back)

    local duration = cfg.Duration
    if duration then
        tween(bar, duration, {
            Size = UDim2.new(1, 0, 0, 3)
        }, Enum.EasingStyle.Linear)

        task.delay(duration, function()
            if frame.Parent then
                tween(scale, 0.16, {Scale = 0.84}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
                task.wait(0.16)
                if frame.Parent then
                    frame:Destroy()
                end
            end
        end)
    end

    return frame
end

function Tab:AddModule(cfg)
    cfg = cfg or {}

    local cardFrame = new("Frame", {
        BackgroundColor3 = Theme.Card,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 100),
        Parent = self.Page
    })
    corner(cardFrame, UDim.new(0, 22))
    stroke(cardFrame, Theme.Border, 1, 0.35)
    padding(cardFrame, 20, 20, 18, 18)
    list(cardFrame, Enum.FillDirection.Vertical, 12)

    local header = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 42),
        Parent = cardFrame
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Text = cfg.Title or "Module",
        Font = Enum.Font.GothamMedium,
        TextSize = 18,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, -140, 0, 22),
        Parent = header
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Text = cfg.Description or "",
        Font = Enum.Font.Gotham,
        TextSize = 15,
        TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(0, 21),
        Size = UDim2.new(1, -140, 0, 20),
        Parent = header
    })

    local right = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(108, 32),
        Parent = header
    })
    local rightList = list(right, Enum.FillDirection.Horizontal, 8)
    rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right
    rightList.VerticalAlignment = Enum.VerticalAlignment.Center

    local more = new("TextButton", {
        AutoButtonColor = false,
        Text = "...",
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(28, 28),
        Parent = right
    })

    local headerToggle
    if cfg.Toggle ~= false then
        local toggleHolder = new("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(54, 28),
            Parent = right
        })
        headerToggle = createSwitch(toggleHolder, cfg.Default or false, function(v)
            UI.Flags[cfg.Flag or cfg.Title or "Module"] = v
            if cfg.Callback then
                task.spawn(cfg.Callback, v)
            end
        end)
    end

    local body = new("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        Parent = cardFrame
    })
    list(body, Enum.FillDirection.Vertical, 10)

    local card = setmetatable({
        Tab = self,
        Window = self.Window,
        Frame = cardFrame,
        Header = header,
        Body = body,
        MoreButton = more,
        HeaderToggle = headerToggle,
        Title = cfg.Title or "Module",
        SearchText = (cfg.Title or "") .. " " .. (cfg.Description or "")
    }, Card)

    table.insert(self.Cards, card)

    card:AttachKeybind({
        Button = more,
        Default = cfg.Keybind or "MB2",
        Mode = cfg.KeybindMode or "Toggle",
        Callback = function(state)
            if headerToggle then
                headerToggle:Set(state)
            end
            if cfg.KeybindCallback then
                task.spawn(cfg.KeybindCallback, state)
            end
        end,
        ChangedCallback = cfg.KeybindChanged
    })

    cardFrame.Position = UDim2.fromOffset(0, 12)
    cardFrame.BackgroundTransparency = 1
    tween(cardFrame, 0.22, {
        Position = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 0
    })

    return card
end

function Card:AddSeparator()
    local sep = new("Frame", {
        BackgroundColor3 = Theme.Divider,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
        Parent = self.Body
    })
    return sep
end

local function row(parent, title, height)
    local frame = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height or 32),
        Parent = parent
    })

    local label = new("TextLabel", {
        BackgroundTransparency = 1,
        Text = title or "",
        Font = Enum.Font.Gotham,
        TextSize = 15,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(0.48, 0, 1, 0),
        Parent = frame
    })

    return frame, label
end

function Card:AddParagraph(cfg)
    cfg = cfg or {}

    local frame = new("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        Parent = self.Body
    })

    local y = 0
    if cfg.Title then
        new("TextLabel", {
            BackgroundTransparency = 1,
            Text = cfg.Title,
            Font = Enum.Font.GothamMedium,
            TextSize = 15,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.new(1, 0, 0, 20),
            Parent = frame
        })
        y = 22
    end

    new("TextLabel", {
        BackgroundTransparency = 1,
        Text = cfg.Content or "",
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Theme.SubText,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 0, 0),
        Parent = frame
    })

    self.SearchText = self.SearchText .. " " .. (cfg.Title or "") .. " " .. (cfg.Content or "")
    return frame
end

function Card:AddButton(cfg)
    cfg = cfg or {}
    local r = row(self.Body, cfg.Title or "Button", 32)

    local btn = new("TextButton", {
        AutoButtonColor = false,
        Text = cfg.Text or "Run",
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Theme.Text,
        BackgroundColor3 = Color3.fromRGB(75, 75, 80),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(82, 28),
        Parent = r
    })
    corner(btn, UDim.new(0, 8))

    btn.MouseButton1Click:Connect(function()
        tween(btn, 0.08, {BackgroundColor3 = Color3.fromRGB(105, 105, 110)})
        task.delay(0.08, function()
            if btn.Parent then
                tween(btn, 0.12, {BackgroundColor3 = Color3.fromRGB(75, 75, 80)})
            end
        end)
        if cfg.Callback then
            task.spawn(cfg.Callback)
        end
    end)

    return btn
end

function Card:AddToggle(cfg)
    cfg = cfg or {}
    local r = row(self.Body, cfg.Title or "Toggle", 32)
    local holder = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(54, 28),
        Parent = r
    })

    return createSwitch(holder, cfg.Default or false, function(v)
        UI.Flags[cfg.Flag or cfg.Title or "Toggle"] = v
        if cfg.Callback then
            task.spawn(cfg.Callback, v)
        end
    end)
end

function Card:AddCheckbox(cfg)
    cfg = cfg or {}
    local r, label = row(self.Body, cfg.Title or "Checkbox", 30)

    local holder = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 3),
        Size = UDim2.fromOffset(24, 24),
        Parent = r
    })

    label.Position = UDim2.fromOffset(34, 0)
    label.Size = UDim2.new(1, -34, 1, 0)

    return createCheck(holder, cfg.Default or false, function(v)
        UI.Flags[cfg.Flag or cfg.Title or "Checkbox"] = v
        if cfg.Callback then
            task.spawn(cfg.Callback, v)
        end
    end)
end

function Card:AddRadio(cfg)
    cfg = cfg or {}
    return createRadio(self.Body, cfg.Options or {"Always On", "On Attack"}, cfg.Default, function(v)
        UI.Flags[cfg.Flag or "Radio"] = v
        if cfg.Callback then
            task.spawn(cfg.Callback, v)
        end
    end)
end

function Card:AddSlider(cfg)
    cfg = cfg or {}

    local min = cfg.Min or 0
    local max = cfg.Max or 100
    local value = cfg.Default or min
    local rounding = cfg.Rounding or 0

    local r = row(self.Body, cfg.Title or "Slider", 32)

    local valueLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Text = tostring(value) .. (cfg.Suffix or ""),
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(0.45, 0, 0, 0),
        Size = UDim2.new(0, 70, 1, 0),
        Parent = r
    })

    local track = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(170, 170, 173),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(170, 5),
        Parent = r
    })
    corner(track, UDim.new(1, 0))

    local fill = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(230, 230, 232),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1),
        Parent = track
    })
    corner(fill, UDim.new(1, 0))

    local knob = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(245, 245, 246),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(16, 16),
        Parent = track
    })
    corner(knob, UDim.new(1, 0))
    stroke(knob, Color3.fromRGB(80, 80, 84), 2, 0.1)

    local input = new("TextButton", {
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(-12, -12),
        Size = UDim2.new(1, 24, 1, 24),
        Parent = track
    })

    local dragging = false

    local function roundNumber(n)
        local mult = 10 ^ rounding
        return math.floor(n * mult + 0.5) / mult
    end

    local object = {}

    function object:Set(v, fire)
        value = math.clamp(roundNumber(v), min, max)
        local alpha = (value - min) / (max - min)
        fill.Size = UDim2.fromScale(alpha, 1)
        knob.Position = UDim2.fromScale(alpha, 0.5)
        valueLabel.Text = tostring(value) .. (cfg.Suffix or "")
        UI.Flags[cfg.Flag or cfg.Title or "Slider"] = value

        if fire ~= false and cfg.Callback then
            task.spawn(cfg.Callback, value)
        end
    end

    function object:Get()
        return value
    end

    local function setFromX(x)
        local alpha = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        object:Set(min + (max - min) * alpha, true)
    end

    input.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(inp.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            setFromX(inp.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    object:Set(value, false)
    return object
end

function Card:AddDropdown(cfg)
    cfg = cfg or {}
    local values = cfg.Values or {}
    local current = cfg.Default

    if type(current) == "number" then
        current = values[current]
    end
    current = current or values[1] or "None"

    local r = row(self.Body, cfg.Title or "Dropdown", 32)

    local btn = new("TextButton", {
        AutoButtonColor = false,
        Text = tostring(current) .. "  ⌄",
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundColor3 = Theme.Input,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(168, 30),
        Parent = r
    })
    corner(btn, UDim.new(0, 9))
    stroke(btn, Theme.Border, 1, 0.35)
    padding(btn, 10, 10, 0, 0)

    local popup = new("Frame", {
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        Parent = ensurePopupLayer(self.Window)
    })
    corner(popup, UDim.new(0, 12))
    stroke(popup, Theme.Border, 1, 0.25)
    list(popup, Enum.FillDirection.Vertical, 0)

    for _, valueItem in ipairs(values) do
        local item = new("TextButton", {
            AutoButtonColor = false,
            Text = tostring(valueItem),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 30),
            Parent = popup
        })
        padding(item, 10, 10, 0, 0)

        item.MouseButton1Click:Connect(function()
            current = valueItem
            btn.Text = tostring(current) .. "  ⌄"
            hidePopup(self.Window, popup)
            UI.Flags[cfg.Flag or cfg.Title or "Dropdown"] = current
            if cfg.Callback then
                task.spawn(cfg.Callback, current)
            end
        end)
    end

    btn.MouseButton1Click:Connect(function()
        showPopup(self.Window, popup, btn, 168, math.min(#values * 30, 180))
    end)

    return {
        Get = function()
            return current
        end,
        Set = function(_, v)
            current = v
            btn.Text = tostring(v) .. "  ⌄"
        end
    }
end

function Card:AddInput(cfg)
    cfg = cfg or {}
    local r = row(self.Body, cfg.Title or "Input", 32)

    local box = new("TextBox", {
        ClearTextOnFocus = false,
        Text = tostring(cfg.Default or ""),
        PlaceholderText = cfg.Placeholder or "",
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Theme.Text,
        PlaceholderColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundColor3 = Theme.Input,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(168, 30),
        Parent = r
    })
    corner(box, UDim.new(0, 9))
    stroke(box, Theme.Border, 1, 0.35)
    padding(box, 10, 10, 0, 0)

    local function fire()
        local text = box.Text
        if cfg.Numeric then
            text = text:gsub("[^%d%.%-]", "")
            box.Text = text
        end
        UI.Flags[cfg.Flag or cfg.Title or "Input"] = text
        if cfg.Callback then
            task.spawn(cfg.Callback, text)
        end
    end

    if cfg.Finished then
        box.FocusLost:Connect(function(enter)
            if enter then fire() end
        end)
    else
        box:GetPropertyChangedSignal("Text"):Connect(fire)
    end

    return {
        Get = function()
            return box.Text
        end,
        Set = function(_, v)
            box.Text = tostring(v)
            fire()
        end
    }
end

function Card:AttachKeybind(cfg)
    cfg = cfg or {}
    local anchor = cfg.Button
    local bind = cfg.Default or "MB2"
    local mode = cfg.Mode or "Toggle"
    local state = false
    local listening = false

    local popup = new("Frame", {
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        Parent = ensurePopupLayer(self.Window)
    })
    corner(popup, UDim.new(0, 17))
    stroke(popup, Theme.Border, 1, 0.25)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Text = "Key",
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(16, 10),
        Size = UDim2.fromOffset(40, 24),
        Parent = popup
    })

    local keyBtn = new("TextButton", {
        AutoButtonColor = false,
        Text = bind,
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Theme.Text,
        BackgroundColor3 = Color3.fromRGB(45, 45, 49),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(86, 7),
        Size = UDim2.fromOffset(58, 30),
        Parent = popup
    })
    corner(keyBtn, UDim.new(0, 9))

    new("Frame", {
        BackgroundColor3 = Theme.Divider,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(14, 46),
        Size = UDim2.new(1, -28, 0, 1),
        Parent = popup
    })

    local modeItems = {}

    local function renderModes()
        for _, item in ipairs(modeItems) do
            local active = item.Mode == mode
            item.Dot.BackgroundColor3 = active and Theme.Text or Color3.fromRGB(58, 58, 63)
            item.Inner.Visible = active
            item.Label.TextColor3 = active and Theme.Text or Theme.SubText
        end
        keyBtn.Text = bind
    end

    local function addMode(name, y)
        local b = new("TextButton", {
            AutoButtonColor = false,
            Text = "",
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(14, y),
            Size = UDim2.new(1, -28, 0, 26),
            Parent = popup
        })

        local dot = new("Frame", {
            BackgroundColor3 = Color3.fromRGB(58, 58, 63),
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 4),
            Size = UDim2.fromOffset(18, 18),
            Parent = b
        })
        corner(dot, UDim.new(1, 0))

        local inner = new("Frame", {
            BackgroundColor3 = Theme.Window,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(8, 8),
            Visible = false,
            Parent = dot
        })
        corner(inner, UDim.new(1, 0))

        local label = new("TextLabel", {
            BackgroundTransparency = 1,
            Text = name,
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.SubText,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(28, 0),
            Size = UDim2.new(1, -28, 1, 0),
            Parent = b
        })

        b.MouseButton1Click:Connect(function()
            mode = name
            renderModes()
            if cfg.ChangedCallback then
                task.spawn(cfg.ChangedCallback, bind, mode)
            end
        end)

        table.insert(modeItems, {
            Mode = name,
            Button = b,
            Dot = dot,
            Inner = inner,
            Label = label
        })
    end

    addMode("Toggle", 56)
    addMode("Hold", 82)
    renderModes()

    anchor.MouseButton1Click:Connect(function()
        showPopup(self.Window, popup, anchor, 160, 112)
    end)

    keyBtn.MouseButton1Click:Connect(function()
        listening = true
        keyBtn.Text = "..."
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end

        if listening then
            local n = keyName(input)
            if n then
                bind = n
                listening = false
                renderModes()
                if cfg.ChangedCallback then
                    task.spawn(cfg.ChangedCallback, bind, mode)
                end
            end
            return
        end

        if keyName(input) == bind then
            if mode == "Toggle" then
                state = not state
            elseif mode == "Hold" then
                state = true
            end

            if cfg.Callback then
                task.spawn(cfg.Callback, state)
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if mode == "Hold" and keyName(input) == bind then
            state = false
            if cfg.Callback then
                task.spawn(cfg.Callback, false)
            end
        end
    end)

    return {
        GetState = function()
            return state
        end,
        GetKey = function()
            return bind
        end,
        SetValue = function(_, key, newMode)
            bind = key or bind
            mode = newMode or mode
            renderModes()
        end
    }
end

function Card:AddKeybind(cfg)
    cfg = cfg or {}
    local r = row(self.Body, cfg.Title or "Keybind", 32)

    local btn = new("TextButton", {
        AutoButtonColor = false,
        Text = cfg.Default or "MB2",
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Theme.Text,
        BackgroundColor3 = Theme.Input,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(62, 30),
        Parent = r
    })
    corner(btn, UDim.new(0, 9))
    stroke(btn, Theme.Border, 1, 0.35)

    local object = self:AttachKeybind({
        Button = btn,
        Default = cfg.Default or "MB2",
        Mode = cfg.Mode or "Toggle",
        Callback = cfg.Callback,
        ChangedCallback = cfg.ChangedCallback
    })

    RunService.RenderStepped:Connect(function()
        if btn.Parent then
            btn.Text = object.GetKey()
        end
    end)

    return object
end

function Card:AddColorpicker(cfg)
    cfg = cfg or {}
    local default = cfg.Default or Theme.Green
    local h, s, v = default:ToHSV()
    local current = default

    local r = row(self.Body, cfg.Title or "Color Picker Test", 32)

    local swatch = new("TextButton", {
        AutoButtonColor = false,
        Text = "",
        BackgroundColor3 = default,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -4, 0.5, 0),
        Size = UDim2.fromOffset(22, 22),
        Parent = r
    })
    corner(swatch, UDim.new(0, 6))

    local popup = new("Frame", {
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        Parent = ensurePopupLayer(self.Window)
    })
    corner(popup, UDim.new(0, 20))
    stroke(popup, Theme.Border, 1, 0.22)

    local square = new("Frame", {
        BackgroundColor3 = Color3.fromHSV(h, 1, 1),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(16, 16),
        Size = UDim2.fromOffset(188, 176),
        Parent = popup
    })
    corner(square, UDim.new(0, 14))
    square.ClipsDescendants = true

    local white = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Parent = square
    })
    white.BackgroundTransparency = 0
    local wg = new("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1)
        }),
        Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
        Parent = white
    })

    local black = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Parent = square
    })
    local bg = new("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0)
        }),
        Color = ColorSequence.new(Color3.fromRGB(0, 0, 0)),
        Parent = black
    })

    local squareButton = new("TextButton", {
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Parent = square
    })

    local cursor = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(s, -6, 1 - v, -6),
        Size = UDim2.fromOffset(12, 12),
        Parent = square
    })
    corner(cursor, UDim.new(1, 0))
    stroke(cursor, Color3.fromRGB(255, 255, 255), 3, 0)

    local hue = new("Frame", {
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(16, 202),
        Size = UDim2.fromOffset(188, 12),
        Parent = popup
    })
    corner(hue, UDim.new(1, 0))
    hue.ClipsDescendants = true

    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0))
        }),
        Parent = hue
    })

    local hueButton = new("TextButton", {
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Parent = hue
    })

    local hueCursor = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(245, 245, 245),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(h, 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        Parent = hue
    })
    corner(hueCursor, UDim.new(1, 0))
    stroke(hueCursor, Theme.Border, 2, 0)

    local modeButton = new("TextButton", {
        AutoButtonColor = false,
        Text = "RGB  ⌄",
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundColor3 = Theme.Input,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(16, 230),
        Size = UDim2.fromOffset(72, 34),
        Parent = popup
    })
    corner(modeButton, UDim.new(0, 10))
    stroke(modeButton, Theme.Border, 1, 0.35)
    padding(modeButton, 12, 12, 0, 0)

    local modePopup = new("Frame", {
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        Parent = ensurePopupLayer(self.Window)
    })
    corner(modePopup, UDim.new(0, 14))
    stroke(modePopup, Theme.Border, 1, 0.25)

    local mode = "RGB"
    local modes = {"Hex", "RGB", "HSL"}

    local function rebuildModePopup()
        modePopup:ClearAllChildren()

        for i, name in ipairs(modes) do
            local item = new("TextButton", {
                AutoButtonColor = false,
                Text = name,
                Font = Enum.Font.Gotham,
                TextSize = 14,
                TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = name == mode and 0.88 or 1,
                BackgroundColor3 = Color3.fromRGB(80, 80, 84),
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(0, (i - 1) * 30),
                Size = UDim2.new(1, 0, 0, 30),
                Parent = modePopup
            })
            padding(item, 12, 26, 0, 0)

            if name == mode then
                new("TextLabel", {
                    BackgroundTransparency = 1,
                    Text = "✓",
                    Font = Enum.Font.GothamBold,
                    TextSize = 14,
                    TextColor3 = Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -10, 0.5, 0),
                    Size = UDim2.fromOffset(16, 16),
                    Parent = item
                })
            end

            item.MouseButton1Click:Connect(function()
                mode = name
                modeButton.Text = mode .. "  ⌄"
                rebuildModePopup()
                hidePopup(self.Window, modePopup)
            end)
        end
    end

    rebuildModePopup()

    local draggingSquare = false
    local draggingHue = false

    local object = {}

    local function render(fire)
        current = Color3.fromHSV(h, s, v)
        swatch.BackgroundColor3 = current
        square.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        cursor.Position = UDim2.new(s, -6, 1 - v, -6)
        hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
        UI.Flags[cfg.Flag or cfg.Title or "Colorpicker"] = current

        if fire and cfg.Callback then
            task.spawn(cfg.Callback, current)
        end
    end

    local function setSV(pos, fire)
        s = math.clamp((pos.X - square.AbsolutePosition.X) / square.AbsoluteSize.X, 0, 1)
        v = 1 - math.clamp((pos.Y - square.AbsolutePosition.Y) / square.AbsoluteSize.Y, 0, 1)
        render(fire)
    end

    local function setHue(pos, fire)
        h = math.clamp((pos.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 1)
        render(fire)
    end

    swatch.MouseButton1Click:Connect(function()
        showPopup(self.Window, popup, swatch, 220, 280)
    end)

    modeButton.MouseButton1Click:Connect(function()
        showPopup(self.Window, modePopup, modeButton, 74, 90)
    end)

    squareButton.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            draggingSquare = true
            setSV(inp.Position, true)
        end
    end)

    hueButton.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            draggingHue = true
            setHue(inp.Position, true)
        end
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if draggingSquare and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            setSV(inp.Position, true)
        elseif draggingHue and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            setHue(inp.Position, true)
        end
    end)

    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            draggingSquare = false
            draggingHue = false
        end
    end)

    function object:Set(color)
        h, s, v = color:ToHSV()
        render(true)
    end

    function object:Get()
        return current
    end

    render(false)
    return object
end

function Card:AddNametagPreview(cfg)
    cfg = cfg or {}

    local holder = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 126),
        Parent = self.Body
    })

    local left = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, -200, 1, 0),
        Parent = holder
    })
    list(left, Enum.FillDirection.Vertical, 14)

    local right = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(170, 108),
        Parent = holder
    })

    local function opt(name, default)
        local optRow = new("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 30),
            Parent = left
        })

        local checkHolder = new("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 3),
            Size = UDim2.fromOffset(24, 24),
            Parent = optRow
        })

        new("TextLabel", {
            BackgroundTransparency = 1,
            Text = name,
            Font = Enum.Font.Gotham,
            TextSize = 16,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(34, 0),
            Size = UDim2.new(1, -34, 1, 0),
            Parent = optRow
        })

        return createCheck(checkHolder, default, nil)
    end

    local showHealth = opt("Show Health", true)
    local showDistance = opt("Show Distance", false)
    local showDecimal = opt("Show Decimal", true)

    local preview = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(92, 92, 96),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(160, 108),
        Parent = right
    })
    corner(preview, UDim.new(0, 18))

    local bubble = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(248, 248, 248),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(18, 31),
        Size = UDim2.fromOffset(124, 32),
        Parent = preview
    })
    corner(bubble, UDim.new(0, 12))

    local tail = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(248, 248, 248),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 1, -1),
        Size = UDim2.fromOffset(12, 12),
        Rotation = 45,
        Parent = bubble
    })

    local nameLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Text = cfg.Name or "BlueWizard",
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(70, 70, 76),
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -20, 1, 0),
        Parent = bubble
    })

    local hpLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Text = "108.8",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Theme.Health,
        TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 0),
        Size = UDim2.fromOffset(56, 32),
        Parent = bubble
    })

    local function refresh()
        hpLabel.Visible = showHealth:Get()
        if not hpLabel.Visible then return end

        local n = math.random(50, 150)
        if showDecimal:Get() then
            hpLabel.Text = string.format("%.1f", n + math.random())
        else
            hpLabel.Text = tostring(n)
        end
    end

    showHealth.Button.MouseButton1Click:Connect(function()
        task.defer(refresh)
    end)

    showDecimal.Button.MouseButton1Click:Connect(function()
        task.defer(refresh)
    end)

    task.spawn(function()
        while preview.Parent do
            refresh()
            task.wait(1)
        end
    end)

    refresh()

    return {
        ShowHealth = showHealth,
        ShowDistance = showDistance,
        ShowDecimal = showDecimal,
        Preview = preview
    }
end

function UI:Notify(cfg)
    if UI.Window then
        return UI.Window:Notify(cfg)
    end
end

return UI

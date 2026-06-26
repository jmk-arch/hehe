--[[
    hehe.lua - Smooth Fluent-style Roblox UI Library
    Single-file UI framework inspired by the screenshots provided by the user.
    This file only creates UI components and demo callbacks. It does not include exploit/game-cheat logic.
]]

local Fluent = {}
Fluent.Version = "Smooth-1.2"
Fluent.Options = {}
Fluent.Unloaded = false

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local Connections = {}

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Connections, c)
    return c
end

local function safeParent()
    local ok, hidden = pcall(function()
        return gethui and gethui()
    end)
    if ok and hidden then return hidden end

    local okCore = pcall(function()
        local t = Instance.new("ScreenGui")
        t.Parent = CoreGui
        t:Destroy()
    end)
    if okCore then return CoreGui end

    return LocalPlayer:WaitForChild("PlayerGui")
end

local function protect(gui)
    if syn and syn.protect_gui then
        pcall(syn.protect_gui, gui)
    end
    return gui
end

local function new(className, props, children)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    for _, child in ipairs(children or {}) do
        child.Parent = obj
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
        Color = color or Color3.fromRGB(45, 45, 45),
        Thickness = thickness or 1,
        Transparency = transparency or 0.35,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent
    })
end

local function padding(parent, l, r, t, b)
    return new("UIPadding", {
        PaddingLeft = l or UDim.new(0, 0),
        PaddingRight = r or UDim.new(0, 0),
        PaddingTop = t or UDim.new(0, 0),
        PaddingBottom = b or UDim.new(0, 0),
        Parent = parent
    })
end

local function list(parent, direction, pad)
    return new("UIListLayout", {
        FillDirection = direction or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = pad or UDim.new(0, 8),
        Parent = parent
    })
end

local function tween(obj, time, props, style, dir)
    local tw = TweenService:Create(
        obj,
        TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
        props
    )
    tw:Play()
    return tw
end

local function textWidth(text, size, font)
    local ok, result = pcall(function()
        return TextService:GetTextSize(tostring(text), size, font, Vector2.new(100000, size)).X
    end)
    return ok and result or 0
end

local function makeDraggable(handle, target)
    target = target or handle
    local dragging = false
    local dragStart
    local startPos

    connect(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position

            connect(input.Changed, function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
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

local function mouseButtonName(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then return "MB1" end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then return "MB2" end
    if input.UserInputType == Enum.UserInputType.MouseButton3 then return "MB3" end
    return nil
end

local function keyNameFromInput(input)
    return mouseButtonName(input) or (input.KeyCode and input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode.Name) or "None"
end

local function matchesBind(input, bindName)
    if not bindName or bindName == "None" then return false end
    local mb = mouseButtonName(input)
    if mb then return mb == bindName end
    return input.KeyCode and input.KeyCode.Name == bindName
end

local Themes = {
    Dark = {
        Background = Color3.fromRGB(13, 13, 13),
        Sidebar = Color3.fromRGB(18, 18, 18),
        Card = Color3.fromRGB(19, 19, 19),
        Card2 = Color3.fromRGB(24, 24, 24),
        Popup = Color3.fromRGB(18, 18, 18),
        Stroke = Color3.fromRGB(45, 45, 45),
        Text = Color3.fromRGB(245, 245, 245),
        SubText = Color3.fromRGB(168, 168, 168),
        Muted = Color3.fromRGB(105, 105, 105),
        Accent = Color3.fromRGB(145, 255, 0),
        Accent2 = Color3.fromRGB(115, 190, 75),
        Danger = Color3.fromRGB(255, 91, 91)
    }
}

local function getTheme(name)
    return Themes[name or "Dark"] or Themes.Dark
end

local WindowMethods = {}
WindowMethods.__index = WindowMethods

local TabMethods = {}
TabMethods.__index = TabMethods

local SectionMethods = {}
SectionMethods.__index = SectionMethods

local OptionMethods = {}
OptionMethods.__index = OptionMethods

local FeatureCardMethods = {}
FeatureCardMethods.__index = FeatureCardMethods

local function createOption(flag, default)
    local opt = setmetatable({
        Value = default,
        Changed = {}
    }, OptionMethods)
    Fluent.Options[flag] = opt
    return opt
end

function OptionMethods:OnChanged(fn)
    table.insert(self.Changed, fn)
    return self
end

function OptionMethods:SetValue(value)
    self.Value = value
    for _, fn in ipairs(self.Changed) do
        task.spawn(fn, value)
    end
end

function OptionMethods:SetValueRGB(color)
    self:SetValue(color)
end

local function fireOption(opt, value)
    opt.Value = value
    for _, fn in ipairs(opt.Changed) do
        task.spawn(fn, value)
    end
end

local function animateIn(frame, delayTime)
    delayTime = delayTime or 0
    local scale = new("UIScale", {
        Scale = 0.965,
        Parent = frame
    })

    if frame:IsA("CanvasGroup") then
        frame.GroupTransparency = 1
    end

    task.delay(delayTime, function()
        if not frame or not frame.Parent then return end
        tween(scale, 0.32, { Scale = 1 }, Enum.EasingStyle.Quint)
        if frame:IsA("CanvasGroup") then
            tween(frame, 0.32, { GroupTransparency = 0 }, Enum.EasingStyle.Quint)
        end
    end)
end

local function createCard(parentTab, title, description, height)
    parentTab._itemCount = (parentTab._itemCount or 0) + 1

    local card = new("CanvasGroup", {
        Name = "Card",
        BackgroundColor3 = parentTab.Window.Theme.Card,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height or (description and 84 or 66)),
        Parent = parentTab.Page
    })
    corner(card, UDim.new(0, 20))
    stroke(card, parentTab.Window.Theme.Stroke, 1, 0.45)
    animateIn(card, math.min(parentTab._itemCount * 0.025, 0.18))

    local titleY = description and 14 or 20
    local titleLabel = new("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Text = title or "",
        TextColor3 = parentTab.Window.Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Size = UDim2.new(1, -130, 0, 24),
        Position = UDim2.new(0, 22, 0, titleY),
        Parent = card
    })

    local descLabel
    if description then
        descLabel = new("TextLabel", {
            Name = "Description",
            BackgroundTransparency = 1,
            Text = description,
            TextColor3 = parentTab.Window.Theme.SubText,
            Font = Enum.Font.Gotham,
            TextSize = 15,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Size = UDim2.new(1, -150, 0, 40),
            Position = UDim2.new(0, 22, 0, 39),
            Parent = card
        })
    end

    return card, titleLabel, descLabel
end

function Fluent:CreateWindow(cfg)
    cfg = cfg or {}
    local theme = getTheme(cfg.Theme)

    local gui = protect(new("ScreenGui", {
        Name = "hehe_SmoothUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = safeParent()
    }))

    local holder = new("CanvasGroup", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = cfg.Size or UDim2.fromOffset(900, 620),
        BackgroundColor3 = theme.Background,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Parent = gui
    })
    corner(holder, UDim.new(0, 26))
    stroke(holder, theme.Stroke, 1, 0.08)

    local scale = new("UIScale", {
        Scale = 0.92,
        Parent = holder
    })

    local shadow = new("ImageLabel", {
        Name = "Shadow",
        BackgroundTransparency = 1,
        Image = "rbxassetid://5028857472",
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = 0.35,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(24, 24, 276, 276),
        Size = UDim2.new(1, 50, 1, 50),
        Position = UDim2.fromOffset(-25, -25),
        ZIndex = -5,
        Parent = holder
    })

    local sidebarWidth = cfg.TabWidth or 160

    local sidebar = new("Frame", {
        Name = "Sidebar",
        BackgroundColor3 = theme.Sidebar,
        BorderSizePixel = 0,
        Size = UDim2.new(0, sidebarWidth, 1, 0),
        Parent = holder
    })
    corner(sidebar, UDim.new(0, 26))

    new("Frame", {
        Name = "SidebarMask",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 28, 1, 0),
        BackgroundColor3 = theme.Sidebar,
        BorderSizePixel = 0,
        Parent = sidebar
    })

    new("Frame", {
        Name = "SidebarDivider",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = theme.Stroke,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Parent = sidebar
    })

    new("TextLabel", {
        Name = "ModulesTitle",
        BackgroundTransparency = 1,
        Text = cfg.UserInfoTitle or "Modules",
        Font = Enum.Font.Gotham,
        TextSize = 16,
        TextColor3 = theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 22, 0, 29),
        Size = UDim2.new(1, -44, 0, 28),
        Parent = sidebar
    })

    local tabsHolder = new("Frame", {
        Name = "Tabs",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 18, 0, 75),
        Size = UDim2.new(1, -36, 1, -95),
        Parent = sidebar
    })
    list(tabsHolder, Enum.FillDirection.Vertical, UDim.new(0, 8))

    local topbar = new("Frame", {
        Name = "Topbar",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, sidebarWidth, 0, 0),
        Size = UDim2.new(1, -sidebarWidth, 0, 74),
        Parent = holder
    })

    new("Frame", {
        Name = "TopbarDivider",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = theme.Stroke,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Parent = topbar
    })

    local configButton = new("TextButton", {
        Name = "SelectConfig",
        AutoButtonColor = false,
        Text = "  Select Config                 ˅",
        TextColor3 = theme.Text,
        TextSize = 18,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundColor3 = theme.Card,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 16, 0, 12),
        Size = UDim2.fromOffset(260, 48),
        Parent = topbar
    })
    corner(configButton, UDim.new(0, 14))
    stroke(configButton, theme.Stroke, 1, 0.28)

    local configMenu = new("CanvasGroup", {
        Name = "ConfigMenu",
        BackgroundColor3 = theme.Popup,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(260, 0),
        Position = UDim2.new(0, 16, 0, 65),
        ClipsDescendants = true,
        ZIndex = 100,
        Parent = topbar
    })
    corner(configMenu, UDim.new(0, 14))
    stroke(configMenu, theme.Stroke, 1, 0.35)
    local configLayout = list(configMenu, Enum.FillDirection.Vertical, UDim.new(0, 0))

    local configs = cfg.Configs or {"Default", "Legit", "Visual", "Rage", "Private"}
    for _, name in ipairs(configs) do
        local item = new("TextButton", {
            AutoButtonColor = false,
            Text = "  " .. tostring(name),
            TextColor3 = theme.Text,
            TextSize = 15,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundColor3 = theme.Popup,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 34),
            ZIndex = 101,
            Parent = configMenu
        })
        connect(item.MouseButton1Click, function()
            configButton.Text = "  " .. tostring(name) .. "                 ˅"
            tween(configMenu, 0.2, { Size = UDim2.fromOffset(260, 0) })
        end)
    end

    connect(configButton.MouseButton1Click, function()
        local open = configMenu.Size.Y.Offset <= 1
        tween(configMenu, 0.22, { Size = UDim2.fromOffset(260, open and math.min(#configs * 34, 210) or 0) })
    end)

    local searchBox
    if cfg.Search ~= false then
        searchBox = new("TextBox", {
            Name = "Search",
            PlaceholderText = "Search...",
            Text = "",
            ClearTextOnFocus = false,
            TextColor3 = theme.Text,
            PlaceholderColor3 = theme.SubText,
            TextSize = 18,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundColor3 = theme.Card,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -16, 0, 12),
            Size = UDim2.fromOffset(260, 48),
            Parent = topbar
        })
        corner(searchBox, UDim.new(0, 14))
        stroke(searchBox, theme.Stroke, 1, 0.28)
        padding(searchBox, UDim.new(0, 14), UDim.new(0, 14), UDim.new(0, 0), UDim.new(0, 0))
    end

    local content = new("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, sidebarWidth, 0, 74),
        Size = UDim2.new(1, -sidebarWidth, 1, -74),
        Parent = holder
    })

    local pages = new("Frame", {
        Name = "Pages",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 18, 0, 18),
        Size = UDim2.new(1, -36, 1, -36),
        Parent = content
    })

    local win = setmetatable({
        Gui = gui,
        Holder = holder,
        Scale = scale,
        Sidebar = sidebar,
        TabsHolder = tabsHolder,
        Pages = pages,
        Theme = theme,
        Tabs = {},
        SelectedTab = nil,
        SearchBox = searchBox,
        MinimizeKey = cfg.MinimizeKey or Enum.KeyCode.LeftControl,
        Minimized = false
    }, WindowMethods)

    if searchBox then
        connect(searchBox:GetPropertyChangedSignal("Text"), function()
            local query = string.lower(searchBox.Text)
            for _, tab in ipairs(win.Tabs) do
                for _, item in ipairs(tab.SearchItems) do
                    local show = query == "" or string.find(string.lower(item.Text), query, 1, true) ~= nil
                    item.Frame.Visible = show
                end
            end
        end)
    end

    connect(UserInputService.InputBegan, function(input, gp)
        if gp then return end
        if input.KeyCode == win.MinimizeKey then
            win:SetMinimized(not win.Minimized)
        end
    end)

    task.delay(0.03, function()
        if holder.Parent then
            tween(holder, 0.42, { GroupTransparency = 0 }, Enum.EasingStyle.Quint)
            tween(scale, 0.42, { Scale = 1 }, Enum.EasingStyle.Back)
        end
    end)

    makeDraggable(topbar, holder)
    Fluent.Window = win
    return win
end

function WindowMethods:SetMinimized(state)
    self.Minimized = state
    if state then
        tween(self.Scale, 0.25, { Scale = 0.92 }, Enum.EasingStyle.Quint)
        tween(self.Holder, 0.22, { GroupTransparency = 1 }, Enum.EasingStyle.Quint)
        task.delay(0.23, function()
            if self.Minimized and self.Holder then
                self.Holder.Visible = false
            end
        end)
    else
        self.Holder.Visible = true
        self.Holder.GroupTransparency = 1
        self.Scale.Scale = 0.92
        tween(self.Scale, 0.33, { Scale = 1 }, Enum.EasingStyle.Back)
        tween(self.Holder, 0.33, { GroupTransparency = 0 }, Enum.EasingStyle.Quint)
    end
end

function WindowMethods:SelectTab(indexOrTab)
    local tab = type(indexOrTab) == "number" and self.Tabs[indexOrTab] or indexOrTab
    if not tab then return end
    self.SelectedTab = tab

    for _, other in ipairs(self.Tabs) do
        local selected = other == tab
        other.Page.Visible = selected
        tween(other.Button, 0.18, {
            BackgroundTransparency = selected and 0 or 1,
            BackgroundColor3 = selected and Color3.fromRGB(68, 68, 68) or self.Theme.Sidebar
        })
        other.Button.TextColor3 = selected and self.Theme.Text or self.Theme.SubText
    end
end

function WindowMethods:AddTab(cfg)
    cfg = cfg or {}
    local title = cfg.Title or "Tab"

    local button = new("TextButton", {
        Name = title,
        AutoButtonColor = false,
        Text = title,
        TextColor3 = self.Theme.SubText,
        TextSize = 18,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundColor3 = Color3.fromRGB(68, 68, 68),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 42),
        Parent = self.TabsHolder
    })
    corner(button, UDim.new(0, 9))
    padding(button, UDim.new(0, 14), UDim.new(0, 8), UDim.new(0, 0), UDim.new(0, 0))

    local page = new("ScrollingFrame", {
        Name = title .. "Page",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        Parent = self.Pages
    })
    list(page, Enum.FillDirection.Vertical, UDim.new(0, 18))
    padding(page, UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 0), UDim.new(0, 24))

    local tab = setmetatable({
        Window = self,
        Button = button,
        Page = page,
        SearchItems = {},
        Name = title,
        _itemCount = 0
    }, TabMethods)

    connect(button.MouseButton1Click, function()
        self:SelectTab(tab)
    end)

    table.insert(self.Tabs, tab)
    if not self.SelectedTab then self:SelectTab(tab) end
    return tab
end

function WindowMethods:Dialog(cfg)
    cfg = cfg or {}
    local overlay = new("TextButton", {
        Name = "DialogOverlay",
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.42,
        Size = UDim2.fromScale(1, 1),
        Parent = self.Gui
    })

    local box = new("CanvasGroup", {
        Name = "Dialog",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(400, 220),
        BackgroundColor3 = self.Theme.Card,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Parent = overlay
    })
    corner(box, UDim.new(0, 20))
    stroke(box, self.Theme.Stroke, 1, 0.18)
    animateIn(box, 0)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Text = cfg.Title or "Dialog",
        TextColor3 = self.Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 21,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 22, 0, 18),
        Size = UDim2.new(1, -44, 0, 28),
        Parent = box
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Text = cfg.Content or "",
        TextColor3 = self.Theme.SubText,
        Font = Enum.Font.Gotham,
        TextSize = 16,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.new(0, 22, 0, 58),
        Size = UDim2.new(1, -44, 0, 90),
        Parent = box
    })

    local buttons = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -18, 1, -18),
        Size = UDim2.new(1, -36, 0, 40),
        Parent = box
    })
    local ll = list(buttons, Enum.FillDirection.Horizontal, UDim.new(0, 10))
    ll.HorizontalAlignment = Enum.HorizontalAlignment.Right

    for _, b in ipairs(cfg.Buttons or {}) do
        local btn = new("TextButton", {
            AutoButtonColor = false,
            Text = b.Title or "Button",
            TextColor3 = self.Theme.Text,
            TextSize = 15,
            Font = Enum.Font.GothamMedium,
            BackgroundColor3 = Color3.fromRGB(42, 42, 42),
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(105, 38),
            Parent = buttons
        })
        corner(btn, UDim.new(0, 10))
        connect(btn.MouseButton1Click, function()
            overlay:Destroy()
            if b.Callback then task.spawn(b.Callback) end
        end)
    end

    connect(overlay.MouseButton1Click, function()
        overlay:Destroy()
    end)
end

function WindowMethods:AddMinimizer(cfg)
    return Fluent:CreateMinimizer(cfg)
end

function Fluent:CreateMinimizer(cfg)
    cfg = cfg or {}
    local gui = self.Window and self.Window.Gui or protect(new("ScreenGui", {
        Name = "hehe_Minimizer",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        Parent = safeParent()
    }))

    local mini = new("TextButton", {
        Name = "Minimizer",
        AutoButtonColor = false,
        Text = cfg.Icon or "⌂",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 20,
        Font = Enum.Font.GothamBold,
        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        BackgroundTransparency = cfg.Transparency or 0,
        BorderSizePixel = 0,
        Size = cfg.Size or UDim2.fromOffset(44, 44),
        Position = cfg.Position or UDim2.new(0, 320, 0, 24),
        Visible = cfg.Visible ~= false,
        Parent = gui
    })
    corner(mini, UDim.new(0, cfg.Corner or 10))
    stroke(mini, Color3.fromRGB(55, 55, 55), 1, 0.3)
    if cfg.Draggable ~= false then makeDraggable(mini, mini) end

    local s = new("UIScale", { Scale = 1, Parent = mini })
    connect(mini.MouseEnter, function() tween(s, 0.16, { Scale = 1.08 }) end)
    connect(mini.MouseLeave, function() tween(s, 0.16, { Scale = 1 }) end)
    connect(mini.MouseButton1Click, function()
        if Fluent.Window then
            Fluent.Window:SetMinimized(not Fluent.Window.Minimized)
        end
    end)

    return mini
end

function TabMethods:_trackSearch(frame, text)
    table.insert(self.SearchItems, {
        Frame = frame,
        Text = tostring(text or "")
    })
end

function TabMethods:AddSection(title, icon)
    local frame = new("Frame", {
        Name = title or "Section",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 34),
        Parent = self.Page
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Text = (icon and icon ~= "" and (tostring(icon) .. "  ") or "") .. (title or "Section"),
        TextColor3 = self.Window.Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 19,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 4, 0, 0),
        Size = UDim2.new(1, -8, 1, 0),
        Parent = frame
    })

    self:_trackSearch(frame, title)
    return setmetatable({ Tab = self, Frame = frame }, SectionMethods)
end

local function addParagraph(tab, cfg)
    cfg = cfg or {}
    local content = tostring(cfg.Content or "")
    local title = cfg.Title
    local lines = select(2, content:gsub("\n", "\n")) + 1
    local height = title and math.max(82, 60 + lines * 18) or math.max(70, 34 + lines * 18)

    local card = createCard(tab, title or content, title and content or nil, height)
    if title then
        card.Title.Text = (cfg.Icon and cfg.Icon ~= "" and tostring(cfg.Icon) .. "  " or "") .. tostring(title)
    else
        card.Title.Text = content
        card.Title.TextWrapped = true
        card.Title.TextYAlignment = Enum.TextYAlignment.Center
        card.Title.Size = UDim2.new(1, -44, 1, 0)
        card.Title.Position = UDim2.new(0, 22, 0, 0)
    end

    tab:_trackSearch(card, (cfg.Title or "") .. " " .. content)
    return card
end

function TabMethods:AddParagraph(cfg)
    return addParagraph(self, cfg)
end

function SectionMethods:AddParagraph(cfg)
    return self.Tab:AddParagraph(cfg)
end

function TabMethods:AddButton(cfg)
    cfg = cfg or {}
    local card = createCard(self, cfg.Title or "Button", cfg.Description, cfg.Description and 84 or 66)
    local btn = new("TextButton", {
        Name = "Button",
        AutoButtonColor = false,
        Text = "›",
        TextColor3 = self.Window.Theme.SubText,
        TextSize = 30,
        Font = Enum.Font.GothamBold,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -20, 0.5, 0),
        Size = UDim2.fromOffset(48, 48),
        Parent = card
    })

    local scale = card:FindFirstChildOfClass("UIScale")
    local function call()
        if scale then
            tween(scale, 0.08, { Scale = 0.985 })
            task.delay(0.08, function() if scale then tween(scale, 0.15, { Scale = 1 }) end end)
        end
        if cfg.Callback then task.spawn(cfg.Callback) end
    end

    connect(btn.MouseButton1Click, call)
    connect(card.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then call() end
    end)

    self:_trackSearch(card, (cfg.Title or "") .. " " .. (cfg.Description or ""))
    return card
end

function SectionMethods:AddButton(cfg)
    return self.Tab:AddButton(cfg)
end

local function createSwitch(theme, parent, default)
    local switch = new("TextButton", {
        Name = "Switch",
        AutoButtonColor = false,
        Text = "",
        BackgroundColor3 = default and theme.Accent2 or Color3.fromRGB(98, 98, 98),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -28, 0.5, 0),
        Size = UDim2.fromOffset(64, 34),
        Parent = parent
    })
    corner(switch, UDim.new(1, 0))

    local dot = new("Frame", {
        Name = "Dot",
        BackgroundColor3 = Color3.fromRGB(245, 245, 245),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = default and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 17, 0.5, 0),
        Size = UDim2.fromOffset(28, 28),
        Parent = switch
    })
    corner(dot, UDim.new(1, 0))
    return switch, dot
end

function TabMethods:AddToggle(flag, cfg)
    cfg = cfg or {}
    local default = cfg.Default == true
    local opt = createOption(flag, default)
    local card = createCard(self, cfg.Title or flag, cfg.Description, cfg.Description and 84 or 66)
    local switch, dot = createSwitch(self.Window.Theme, card, default)

    local object = setmetatable({
        Value = default,
        Option = opt,
        Frame = card
    }, OptionMethods)

    local function render(value)
        object.Value = value
        opt.Value = value
        tween(switch, 0.2, { BackgroundColor3 = value and self.Window.Theme.Accent2 or Color3.fromRGB(98, 98, 98) })
        tween(dot, 0.22, { Position = value and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 17, 0.5, 0) })
    end

    function object:SetValue(value)
        value = value == true
        render(value)
        if cfg.Callback then task.spawn(cfg.Callback, value) end
        fireOption(opt, value)
    end

    function object:OnChanged(fn)
        opt:OnChanged(fn)
        return object
    end

    connect(switch.MouseButton1Click, function()
        object:SetValue(not object.Value)
    end)

    self:_trackSearch(card, (cfg.Title or flag) .. " " .. (cfg.Description or ""))
    return object
end

function SectionMethods:AddToggle(flag, cfg)
    return self.Tab:AddToggle(flag, cfg)
end

function TabMethods:AddCheckbox(flag, cfg)
    cfg = cfg or {}
    local default = cfg.Default == true
    local opt = createOption(flag, default)
    local card = createCard(self, cfg.Title or flag, cfg.Description, cfg.Description and 84 or 60)
    card.Title.Position = UDim2.new(0, 58, 0, cfg.Description and 14 or 18)

    local box = new("TextButton", {
        Name = "Checkbox",
        AutoButtonColor = false,
        Text = default and "✓" or "",
        TextColor3 = Color3.fromRGB(20, 20, 20),
        TextSize = 25,
        Font = Enum.Font.GothamBold,
        BackgroundColor3 = default and Color3.fromRGB(235, 235, 235) or Color3.fromRGB(125, 125, 125),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 22, 0.5, -15),
        Size = UDim2.fromOffset(30, 30),
        Parent = card
    })
    corner(box, UDim.new(0, 7))

    local object = setmetatable({
        Value = default,
        Option = opt,
        Frame = card
    }, OptionMethods)

    local function render(value)
        object.Value = value
        opt.Value = value
        box.Text = value and "✓" or ""
        tween(box, 0.16, { BackgroundColor3 = value and Color3.fromRGB(235, 235, 235) or Color3.fromRGB(125, 125, 125) })
    end

    function object:SetValue(value)
        value = value == true
        render(value)
        if cfg.Callback then task.spawn(cfg.Callback, value) end
        fireOption(opt, value)
    end

    function object:OnChanged(fn)
        opt:OnChanged(fn)
        return object
    end

    connect(box.MouseButton1Click, function()
        object:SetValue(not object.Value)
    end)
    connect(card.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            object:SetValue(not object.Value)
        end
    end)

    self:_trackSearch(card, (cfg.Title or flag) .. " " .. (cfg.Description or ""))
    return object
end

function SectionMethods:AddCheckbox(flag, cfg)
    return self.Tab:AddCheckbox(flag, cfg)
end

function TabMethods:AddSlider(flag, cfg)
    cfg = cfg or {}
    local min = cfg.Min or 0
    local max = cfg.Max or 100
    local rounding = cfg.Rounding or 0
    local default = cfg.Default or min
    local suffix = cfg.Suffix or ""
    local opt = createOption(flag, default)

    local card = createCard(self, cfg.Title or flag, cfg.Description, cfg.Description and 104 or 78)
    local valueText = new("TextLabel", {
        Name = "Value",
        BackgroundTransparency = 1,
        Text = tostring(default) .. tostring(suffix),
        TextColor3 = self.Window.Theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 17,
        TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -290, 0, cfg.Description and 22 or 18),
        Size = UDim2.fromOffset(90, 26),
        Parent = card
    })

    local track = new("Frame", {
        Name = "Track",
        BackgroundColor3 = Color3.fromRGB(150, 150, 150),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -28, 0, cfg.Description and 36 or 32),
        Size = UDim2.fromOffset(240, 8),
        Parent = card
    })
    corner(track, UDim.new(1, 0))

    local fill = new("Frame", {
        Name = "Fill",
        BackgroundColor3 = self.Window.Theme.Accent2,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1),
        Parent = track
    })
    corner(fill, UDim.new(1, 0))

    local knob = new("Frame", {
        Name = "Knob",
        BackgroundColor3 = Color3.fromRGB(240, 240, 240),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(24, 24),
        Parent = track
    })
    corner(knob, UDim.new(1, 0))
    stroke(knob, Color3.fromRGB(80, 80, 80), 2, 0)

    local input = new("TextButton", {
        Name = "Input",
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 30, 1, 30),
        Position = UDim2.fromOffset(-15, -15),
        Parent = track
    })

    local object = setmetatable({ Value = default, Option = opt, Frame = card }, OptionMethods)

    local function round(v)
        local p = 10 ^ rounding
        return math.floor(v * p + 0.5) / p
    end

    local function alphaFromValue(v)
        if max == min then return 0 end
        return math.clamp((v - min) / (max - min), 0, 1)
    end

    local function render(value, callback)
        value = math.clamp(round(value), min, max)
        local alpha = alphaFromValue(value)
        object.Value = value
        opt.Value = value
        valueText.Text = tostring(value) .. tostring(suffix)
        tween(fill, 0.16, { Size = UDim2.fromScale(alpha, 1) })
        tween(knob, 0.16, { Position = UDim2.fromScale(alpha, 0.5) })
        if callback and cfg.Callback then task.spawn(cfg.Callback, value) end
        if callback then fireOption(opt, value) end
    end

    local dragging = false
    local function setFromX(x, callback)
        local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        render(min + (max - min) * a, callback)
    end

    connect(input.InputBegan, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(inp.Position.X, true)
        end
    end)

    connect(UserInputService.InputChanged, function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            setFromX(inp.Position.X, true)
        end
    end)

    connect(UserInputService.InputEnded, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    function object:SetValue(value)
        render(value, true)
    end

    function object:OnChanged(fn)
        opt:OnChanged(fn)
        return object
    end

    render(default, false)
    self:_trackSearch(card, (cfg.Title or flag) .. " " .. (cfg.Description or ""))
    return object
end

function SectionMethods:AddSlider(flag, cfg)
    return self.Tab:AddSlider(flag, cfg)
end

function TabMethods:AddDropdown(flag, cfg)
    cfg = cfg or {}
    local values = cfg.Values or cfg.List or {}
    local default = cfg.Default
    if type(default) == "number" then default = values[default] end
    if default == nil then default = cfg.Multi and {} or values[1] end
    local opt = createOption(flag, default)

    local card = createCard(self, cfg.Title or flag, cfg.Description, cfg.Description and 88 or 68)
    local selectButton = new("TextButton", {
        Name = "Select",
        AutoButtonColor = false,
        Text = "",
        TextColor3 = self.Window.Theme.Text,
        TextSize = 15,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right,
        BackgroundColor3 = Color3.fromRGB(32, 32, 32),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -20, 0.5, 0),
        Size = UDim2.fromOffset(230, 40),
        Parent = card
    })
    corner(selectButton, UDim.new(0, 11))
    stroke(selectButton, Color3.fromRGB(55, 55, 55), 1, 0.35)
    padding(selectButton, UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 0), UDim.new(0, 0))

    local menu = new("CanvasGroup", {
        Name = "DropdownMenu",
        BackgroundColor3 = self.Window.Theme.Popup,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 1, 8),
        ClipsDescendants = true,
        ZIndex = 30,
        Parent = selectButton
    })
    corner(menu, UDim.new(0, 12))
    stroke(menu, Color3.fromRGB(55, 55, 55), 1, 0.35)
    list(menu, Enum.FillDirection.Vertical, UDim.new(0, 0))

    local object = setmetatable({
        Value = default,
        Option = opt,
        Frame = card,
        Open = false
    }, OptionMethods)

    local function asText(value)
        if type(value) == "table" then
            local t = {}
            for k, v in pairs(value) do
                if v then table.insert(t, tostring(k)) end
            end
            table.sort(t)
            return #t > 0 and table.concat(t, ", ") or "None"
        end
        return tostring(value or "None")
    end

    local function setOpen(state)
        object.Open = state
        tween(menu, 0.2, { Size = UDim2.new(1, 0, 0, state and math.min(#values * 34, 204) or 0) })
    end

    local function updateText()
        selectButton.Text = asText(object.Value) .. "   ˅"
    end

    local function fire()
        opt.Value = object.Value
        if cfg.Callback then task.spawn(cfg.Callback, object.Value) end
        fireOption(opt, object.Value)
    end

    function object:SetValue(value)
        if cfg.Multi then
            if type(value) == "table" then object.Value = value end
        else
            object.Value = value
        end
        updateText()
        fire()
    end

    function object:OnChanged(fn)
        opt:OnChanged(fn)
        return object
    end

    for _, value in ipairs(values) do
        local item = new("TextButton", {
            Name = tostring(value),
            AutoButtonColor = false,
            Text = "  " .. tostring(value),
            TextColor3 = self.Window.Theme.Text,
            TextSize = 15,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundColor3 = self.Window.Theme.Popup,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 34),
            ZIndex = 31,
            Parent = menu
        })
        connect(item.MouseButton1Click, function()
            if cfg.Multi then
                local tbl = type(object.Value) == "table" and object.Value or {}
                tbl[value] = not tbl[value]
                object.Value = tbl
            else
                object.Value = value
                setOpen(false)
            end
            updateText()
            fire()
        end)
    end

    connect(selectButton.MouseButton1Click, function()
        setOpen(not object.Open)
    end)

    updateText()
    self:_trackSearch(card, (cfg.Title or flag) .. " " .. (cfg.Description or ""))
    return object
end

function SectionMethods:AddDropdown(flag, cfg)
    return self.Tab:AddDropdown(flag, cfg)
end

function TabMethods:AddColorpicker(flag, cfg)
    cfg = cfg or {}
    local default = cfg.Default or Color3.fromRGB(96, 205, 255)
    local opt = createOption(flag, default)

    local card = createCard(self, cfg.Title or flag, cfg.Description, cfg.Description and 88 or 68)
    local swatch = new("TextButton", {
        Name = "Swatch",
        AutoButtonColor = false,
        Text = "",
        BackgroundColor3 = default,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -28, 0.5, 0),
        Size = UDim2.fromOffset(42, 42),
        Parent = card
    })
    corner(swatch, UDim.new(0, 10))
    stroke(swatch, Color3.fromRGB(235, 235, 235), 2, 0.25)

    local popup = new("CanvasGroup", {
        Name = "ColorPopup",
        BackgroundColor3 = self.Window.Theme.Popup,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(214, 282),
        Position = UDim2.new(1, -224, 1, 8),
        Visible = false,
        GroupTransparency = 1,
        ZIndex = 80,
        Parent = card
    })
    corner(popup, UDim.new(0, 18))
    stroke(popup, Color3.fromRGB(55, 55, 55), 1, 0.25)

    local square = new("ImageButton", {
        Name = "ColorSquare",
        AutoButtonColor = false,
        BackgroundColor3 = Color3.fromHSV(0.25, 1, 1),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(18, 18),
        Size = UDim2.fromOffset(178, 178),
        Image = "rbxassetid://4155801252",
        ZIndex = 81,
        Parent = popup
    })
    corner(square, UDim.new(0, 12))

    local cursor = new("Frame", {
        Name = "Cursor",
        BackgroundTransparency = 1,
        Position = UDim2.new(0.65, -6, 0.35, -6),
        Size = UDim2.fromOffset(12, 12),
        ZIndex = 82,
        Parent = square
    })
    corner(cursor, UDim.new(1, 0))
    stroke(cursor, Color3.fromRGB(255, 255, 255), 3, 0)

    local hue = new("ImageButton", {
        Name = "Hue",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(18, 207),
        Size = UDim2.fromOffset(178, 12),
        Image = "rbxassetid://3641079629",
        ZIndex = 81,
        Parent = popup
    })
    corner(hue, UDim.new(1, 0))

    local hueCursor = new("Frame", {
        Name = "HueCursor",
        BackgroundColor3 = Color3.fromRGB(235, 235, 235),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.25, 0.5),
        Size = UDim2.fromOffset(16, 16),
        ZIndex = 82,
        Parent = hue
    })
    corner(hueCursor, UDim.new(1, 0))
    stroke(hueCursor, Color3.fromRGB(75, 75, 75), 2, 0)

    local modeButton = new("TextButton", {
        Name = "Mode",
        AutoButtonColor = false,
        Text = "RGB ˅",
        TextColor3 = self.Window.Theme.Text,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        BackgroundColor3 = Color3.fromRGB(23, 23, 23),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(18, 234),
        Size = UDim2.fromOffset(82, 34),
        ZIndex = 81,
        Parent = popup
    })
    corner(modeButton, UDim.new(0, 10))
    stroke(modeButton, Color3.fromRGB(55, 55, 55), 1, 0.35)

    local modeMenu = new("CanvasGroup", {
        Name = "ModeMenu",
        BackgroundColor3 = self.Window.Theme.Popup,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(18, 272),
        Size = UDim2.fromOffset(82, 0),
        ClipsDescendants = true,
        ZIndex = 90,
        Parent = popup
    })
    corner(modeMenu, UDim.new(0, 10))
    stroke(modeMenu, Color3.fromRGB(55, 55, 55), 1, 0.35)
    list(modeMenu, Enum.FillDirection.Vertical, UDim.new(0, 0))

    local modes = {"Hex", "RGB", "HSL"}
    for _, m in ipairs(modes) do
        local b = new("TextButton", {
            AutoButtonColor = false,
            Text = "  " .. m,
            TextColor3 = self.Window.Theme.Text,
            TextSize = 14,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundColor3 = self.Window.Theme.Popup,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 30),
            ZIndex = 91,
            Parent = modeMenu
        })
        connect(b.MouseButton1Click, function()
            modeButton.Text = m .. " ˅"
            tween(modeMenu, 0.16, { Size = UDim2.fromOffset(82, 0) })
        end)
    end

    connect(modeButton.MouseButton1Click, function()
        local open = modeMenu.Size.Y.Offset <= 1
        tween(modeMenu, 0.16, { Size = UDim2.fromOffset(82, open and 90 or 0) })
    end)

    local h, s, v = default:ToHSV()
    local object = setmetatable({
        Value = default,
        Transparency = cfg.Transparency,
        Option = opt,
        Frame = card
    }, OptionMethods)

    local function render(callback)
        local color = Color3.fromHSV(h, s, v)
        object.Value = color
        opt.Value = color
        swatch.BackgroundColor3 = color
        square.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        cursor.Position = UDim2.new(s, -6, 1 - v, -6)
        hueCursor.Position = UDim2.fromScale(h, 0.5)
        if callback and cfg.Callback then task.spawn(cfg.Callback, color) end
        if callback then fireOption(opt, color) end
    end

    local draggingSquare = false
    local draggingHue = false

    local function setSquare(pos, callback)
        s = math.clamp((pos.X - square.AbsolutePosition.X) / square.AbsoluteSize.X, 0, 1)
        v = 1 - math.clamp((pos.Y - square.AbsolutePosition.Y) / square.AbsoluteSize.Y, 0, 1)
        render(callback)
    end

    local function setHue(pos, callback)
        h = math.clamp((pos.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 1)
        render(callback)
    end

    local function openPopup(state)
        if state then
            popup.Visible = true
            popup.GroupTransparency = 1
            tween(popup, 0.18, { GroupTransparency = 0 })
        else
            tween(popup, 0.15, { GroupTransparency = 1 })
            task.delay(0.16, function()
                if popup.GroupTransparency >= 0.95 then popup.Visible = false end
            end)
        end
    end

    connect(swatch.MouseButton1Click, function()
        openPopup(not popup.Visible)
    end)

    connect(square.InputBegan, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            draggingSquare = true
            setSquare(inp.Position, true)
        end
    end)

    connect(hue.InputBegan, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            draggingHue = true
            setHue(inp.Position, true)
        end
    end)

    connect(UserInputService.InputChanged, function(inp)
        if draggingSquare and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            setSquare(inp.Position, true)
        elseif draggingHue and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            setHue(inp.Position, true)
        end
    end)

    connect(UserInputService.InputEnded, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            draggingSquare = false
            draggingHue = false
        end
    end)

    function object:SetValueRGB(color)
        h, s, v = color:ToHSV()
        render(true)
    end

    function object:SetValue(color)
        object:SetValueRGB(color)
    end

    function object:OnChanged(fn)
        opt:OnChanged(fn)
        return object
    end

    render(false)
    self:_trackSearch(card, (cfg.Title or flag) .. " " .. (cfg.Description or ""))
    return object
end

function SectionMethods:AddColorpicker(flag, cfg)
    return self.Tab:AddColorpicker(flag, cfg)
end

function TabMethods:AddKeybind(flag, cfg)
    cfg = cfg or {}
    local default = cfg.Default or "None"
    local mode = cfg.Mode or "Toggle"
    local opt = createOption(flag, default)

    local card = createCard(self, cfg.Title or flag, cfg.Description, cfg.Description and 88 or 68)
    local keyText = new("TextLabel", {
        BackgroundTransparency = 1,
        Text = "Key",
        TextColor3 = self.Window.Theme.SubText,
        Font = Enum.Font.Gotham,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -108, 0.5, 0),
        Size = UDim2.fromOffset(40, 40),
        Parent = card
    })

    local bindButton = new("TextButton", {
        Name = "BindButton",
        AutoButtonColor = false,
        Text = tostring(default),
        TextColor3 = self.Window.Theme.Text,
        TextSize = 15,
        Font = Enum.Font.Gotham,
        BackgroundColor3 = Color3.fromRGB(32, 32, 32),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -20, 0.5, 0),
        Size = UDim2.fromOffset(78, 40),
        Parent = card
    })
    corner(bindButton, UDim.new(0, 10))
    stroke(bindButton, Color3.fromRGB(55, 55, 55), 1, 0.35)

    local menu = new("CanvasGroup", {
        Name = "KeybindMenu",
        BackgroundColor3 = self.Window.Theme.Popup,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(180, 0),
        Position = UDim2.new(1, -190, 1, 8),
        ClipsDescendants = true,
        ZIndex = 70,
        Parent = card
    })
    corner(menu, UDim.new(0, 16))
    stroke(menu, Color3.fromRGB(55, 55, 55), 1, 0.35)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Text = "Key",
        TextColor3 = self.Window.Theme.SubText,
        Font = Enum.Font.Gotham,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(18, 10),
        Size = UDim2.fromOffset(40, 26),
        ZIndex = 71,
        Parent = menu
    })

    local popKey = new("TextButton", {
        AutoButtonColor = false,
        Text = tostring(default),
        TextColor3 = self.Window.Theme.Text,
        TextSize = 15,
        Font = Enum.Font.Gotham,
        BackgroundColor3 = Color3.fromRGB(32, 32, 32),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(108, 7),
        Size = UDim2.fromOffset(54, 30),
        ZIndex = 71,
        Parent = menu
    })
    corner(popKey, UDim.new(0, 8))

    new("Frame", {
        BackgroundColor3 = Color3.fromRGB(45, 45, 45),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 14, 0, 48),
        Size = UDim2.new(1, -28, 0, 1),
        ZIndex = 71,
        Parent = menu
    })

    local object = setmetatable({
        Value = default,
        Mode = mode,
        State = false,
        Listening = false,
        Option = opt,
        Frame = card
    }, OptionMethods)

    local modeButtons = {}
    local function renderModes()
        for name, row in pairs(modeButtons) do
            row.Circle.BackgroundColor3 = object.Mode == name and Color3.fromRGB(235, 235, 235) or Color3.fromRGB(67, 67, 67)
        end
    end

    local function addMode(name, y)
        local row = new("TextButton", {
            AutoButtonColor = false,
            Text = "",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 15, 0, y),
            Size = UDim2.new(1, -30, 0, 28),
            ZIndex = 71,
            Parent = menu
        })
        local circle = new("Frame", {
            Name = "Circle",
            BackgroundColor3 = Color3.fromRGB(67, 67, 67),
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 6),
            Size = UDim2.fromOffset(18, 18),
            ZIndex = 72,
            Parent = row
        })
        corner(circle, UDim.new(1, 0))
        new("TextLabel", {
            BackgroundTransparency = 1,
            Text = name,
            TextColor3 = self.Window.Theme.SubText,
            Font = Enum.Font.Gotham,
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(28, 0),
            Size = UDim2.new(1, -28, 1, 0),
            ZIndex = 72,
            Parent = row
        })
        row.Circle = circle
        modeButtons[name] = row
        connect(row.MouseButton1Click, function()
            object.Mode = name
            renderModes()
            if cfg.ChangedCallback then task.spawn(cfg.ChangedCallback, object.Value) end
        end)
    end

    addMode("Toggle", 57)
    addMode("Hold", 84)
    addMode("Always", 111)
    renderModes()

    local function setMenu(open)
        tween(menu, 0.2, { Size = UDim2.fromOffset(180, open and 145 or 0) })
    end

    function object:GetState()
        return self.State
    end

    function object:SetValue(key, newMode)
        if type(key) == "string" then
            object.Value = key
            opt.Value = key
            bindButton.Text = key
            popKey.Text = key
        end
        if newMode then
            object.Mode = newMode
            renderModes()
        end
        if cfg.ChangedCallback then task.spawn(cfg.ChangedCallback, object.Value) end
        fireOption(opt, object.Value)
    end

    function object:OnClick(fn)
        object.ClickCallback = fn
        return object
    end

    function object:OnChanged(fn)
        opt:OnChanged(fn)
        return object
    end

    connect(bindButton.MouseButton1Click, function()
        object.Listening = true
        bindButton.Text = "..."
        popKey.Text = "..."
    end)
    connect(popKey.MouseButton1Click, function()
        object.Listening = true
        bindButton.Text = "..."
        popKey.Text = "..."
    end)
    connect(bindButton.MouseButton2Click, function()
        setMenu(menu.Size.Y.Offset <= 1)
    end)
    connect(card.InputBegan, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton2 then
            setMenu(menu.Size.Y.Offset <= 1)
        end
    end)

    connect(UserInputService.InputBegan, function(inp, gp)
        if gp then return end
        if object.Listening then
            object.Listening = false
            object:SetValue(keyNameFromInput(inp), object.Mode)
            return
        end

        if matchesBind(inp, object.Value) then
            if object.Mode == "Toggle" then
                object.State = not object.State
            elseif object.Mode == "Hold" then
                object.State = true
            elseif object.Mode == "Always" then
                object.State = true
            end
            if cfg.Callback then task.spawn(cfg.Callback, object.State) end
            if object.ClickCallback then task.spawn(object.ClickCallback, object.State) end
        end
    end)

    connect(UserInputService.InputEnded, function(inp)
        if matchesBind(inp, object.Value) and object.Mode == "Hold" then
            object.State = false
            if cfg.Callback then task.spawn(cfg.Callback, false) end
        end
    end)

    self:_trackSearch(card, (cfg.Title or flag) .. " " .. (cfg.Description or ""))
    return object
end

function SectionMethods:AddKeybind(flag, cfg)
    return self.Tab:AddKeybind(flag, cfg)
end

function TabMethods:AddInput(flag, cfg)
    cfg = cfg or {}
    local default = cfg.Default or ""
    local opt = createOption(flag, default)
    local card = createCard(self, cfg.Title or flag, cfg.Description, cfg.Description and 88 or 68)

    local box = new("TextBox", {
        Name = "Input",
        Text = tostring(default),
        PlaceholderText = cfg.Placeholder or "",
        ClearTextOnFocus = false,
        TextColor3 = self.Window.Theme.Text,
        PlaceholderColor3 = self.Window.Theme.SubText,
        TextSize = 15,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundColor3 = Color3.fromRGB(32, 32, 32),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -20, 0.5, 0),
        Size = UDim2.fromOffset(220, 40),
        Parent = card
    })
    corner(box, UDim.new(0, 10))
    stroke(box, Color3.fromRGB(55, 55, 55), 1, 0.35)
    padding(box, UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 0), UDim.new(0, 0))

    local object = setmetatable({
        Value = default,
        Option = opt,
        Frame = card
    }, OptionMethods)

    function object:SetValue(value)
        value = tostring(value)
        if cfg.Numeric then
            value = value:gsub("[^%d%.%-]", "")
        end
        object.Value = value
        opt.Value = value
        if box.Text ~= value then box.Text = value end
        if cfg.Callback then task.spawn(cfg.Callback, value) end
        fireOption(opt, value)
    end

    function object:OnChanged(fn)
        opt:OnChanged(fn)
        return object
    end

    if cfg.Finished then
        connect(box.FocusLost, function(enter)
            if enter then object:SetValue(box.Text) end
        end)
    else
        connect(box:GetPropertyChangedSignal("Text"), function()
            if cfg.Numeric then
                local filtered = box.Text:gsub("[^%d%.%-]", "")
                if filtered ~= box.Text then box.Text = filtered return end
            end
            object:SetValue(box.Text)
        end)
    end

    self:_trackSearch(card, (cfg.Title or flag) .. " " .. (cfg.Description or ""))
    return object
end

function SectionMethods:AddInput(flag, cfg)
    return self.Tab:AddInput(flag, cfg)
end

function TabMethods:AddRadioGroup(flag, cfg)
    cfg = cfg or {}
    local values = cfg.Values or {"Always On", "On Attack"}
    local default = cfg.Default or values[1]
    local opt = createOption(flag, default)
    local card = createCard(self, cfg.Title or flag, cfg.Description, cfg.Description and 88 or 64)

    local row = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -22, 0.5, 0),
        Size = UDim2.fromOffset(330, 40),
        Parent = card
    })
    local ll = list(row, Enum.FillDirection.Horizontal, UDim.new(0, 18))
    ll.HorizontalAlignment = Enum.HorizontalAlignment.Right

    local object = setmetatable({ Value = default, Option = opt, Frame = card, Buttons = {} }, OptionMethods)

    local function render(value)
        object.Value = value
        opt.Value = value
        for name, item in pairs(object.Buttons) do
            item.Circle.BackgroundColor3 = name == value and Color3.fromRGB(235, 235, 235) or Color3.fromRGB(67, 67, 67)
        end
    end

    function object:SetValue(value)
        render(value)
        if cfg.Callback then task.spawn(cfg.Callback, value) end
        fireOption(opt, value)
    end

    function object:OnChanged(fn)
        opt:OnChanged(fn)
        return object
    end

    for _, value in ipairs(values) do
        local b = new("TextButton", {
            AutoButtonColor = false,
            Text = "",
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(textWidth(value, 15, Enum.Font.Gotham) + 32, 32),
            Parent = row
        })
        local circle = new("Frame", {
            Name = "Circle",
            BackgroundColor3 = Color3.fromRGB(67, 67, 67),
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 7),
            Size = UDim2.fromOffset(18, 18),
            Parent = b
        })
        corner(circle, UDim.new(1, 0))
        new("TextLabel", {
            BackgroundTransparency = 1,
            Text = value,
            TextColor3 = self.Window.Theme.SubText,
            TextSize = 15,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(28, 0),
            Size = UDim2.new(1, -28, 1, 0),
            Parent = b
        })
        b.Circle = circle
        object.Buttons[value] = b
        connect(b.MouseButton1Click, function()
            object:SetValue(value)
        end)
    end

    render(default)
    self:_trackSearch(card, (cfg.Title or flag) .. " " .. table.concat(values, " "))
    return object
end

function SectionMethods:AddRadioGroup(flag, cfg)
    return self.Tab:AddRadioGroup(flag, cfg)
end

function TabMethods:AddFeatureCard(flag, cfg)
    cfg = cfg or {}
    local card = createCard(self, cfg.Title or flag, cfg.Description, cfg.Height or 220)
    card.Title.Size = UDim2.new(1, -180, 0, 24)
    if card:FindFirstChild("Description") then
        card.Description.Size = UDim2.new(1, -220, 0, 38)
    end

    local more = new("TextButton", {
        Name = "More",
        AutoButtonColor = false,
        Text = "...",
        TextColor3 = self.Window.Theme.Text,
        TextSize = 20,
        Font = Enum.Font.GothamBold,
        BackgroundColor3 = Color3.fromRGB(23, 23, 23),
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -100, 0, 18),
        Size = UDim2.fromOffset(42, 38),
        Parent = card
    })
    corner(more, UDim.new(0, 12))

    local enabled = cfg.Default == true
    local opt = createOption(flag, enabled)
    local switch, dot = createSwitch(self.Window.Theme, card, enabled)
    switch.Position = UDim2.new(1, -28, 0, 37)

    new("Frame", {
        Name = "Line",
        BackgroundColor3 = self.Window.Theme.Stroke,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 22, 0, 88),
        Size = UDim2.new(1, -44, 0, 1),
        Parent = card
    })

    local left = new("Frame", {
        Name = "LeftContent",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 22, 0, 106),
        Size = UDim2.new(0.48, 0, 1, -116),
        Parent = card
    })
    list(left, Enum.FillDirection.Vertical, UDim.new(0, 12))

    local right = new("Frame", {
        Name = "RightContent",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -28, 0, 104),
        Size = UDim2.new(0.36, 0, 1, -126),
        Parent = card
    })

    local object = setmetatable({
        Value = enabled,
        Option = opt,
        Frame = card,
        Left = left,
        Right = right,
        Theme = self.Window.Theme,
        Tab = self
    }, FeatureCardMethods)

    local function render(value)
        object.Value = value
        opt.Value = value
        tween(switch, 0.2, { BackgroundColor3 = value and self.Window.Theme.Accent2 or Color3.fromRGB(98, 98, 98) })
        tween(dot, 0.22, { Position = value and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 17, 0.5, 0) })
    end

    function object:SetValue(value)
        value = value == true
        render(value)
        if cfg.Callback then task.spawn(cfg.Callback, value) end
        fireOption(opt, value)
    end

    function object:OnChanged(fn)
        opt:OnChanged(fn)
        return object
    end

    connect(switch.MouseButton1Click, function()
        object:SetValue(not object.Value)
    end)

    connect(more.MouseButton1Click, function()
        if cfg.MoreCallback then
            task.spawn(cfg.MoreCallback)
        else
            Fluent:Notify({ Title = cfg.Title or flag, Content = "More menu clicked", Duration = 2 })
        end
    end)

    self:_trackSearch(card, (cfg.Title or flag) .. " " .. (cfg.Description or ""))
    return object
end

function SectionMethods:AddFeatureCard(flag, cfg)
    return self.Tab:AddFeatureCard(flag, cfg)
end

function FeatureCardMethods:AddCheckbox(flag, cfg)
    cfg = cfg or {}
    local default = cfg.Default == true
    local opt = createOption(flag, default)
    local row = new("Frame", {
        Name = flag,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 24),
        Parent = self.Left
    })

    local box = new("TextButton", {
        AutoButtonColor = false,
        Text = default and "✓" or "",
        TextColor3 = Color3.fromRGB(20, 20, 20),
        TextSize = 22,
        Font = Enum.Font.GothamBold,
        BackgroundColor3 = default and Color3.fromRGB(235, 235, 235) or Color3.fromRGB(125, 125, 125),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(24, 24),
        Parent = row
    })
    corner(box, UDim.new(0, 6))

    new("TextLabel", {
        BackgroundTransparency = 1,
        Text = cfg.Title or flag,
        TextColor3 = self.Theme.Text,
        TextSize = 16,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(38, 0),
        Size = UDim2.new(1, -38, 1, 0),
        Parent = row
    })

    local object = setmetatable({ Value = default, Option = opt, Frame = row }, OptionMethods)
    local function render(value)
        object.Value = value
        opt.Value = value
        box.Text = value and "✓" or ""
        tween(box, 0.15, { BackgroundColor3 = value and Color3.fromRGB(235, 235, 235) or Color3.fromRGB(125, 125, 125) })
    end

    function object:SetValue(value)
        value = value == true
        render(value)
        if cfg.Callback then task.spawn(cfg.Callback, value) end
        fireOption(opt, value)
    end
    function object:OnChanged(fn)
        opt:OnChanged(fn)
        return object
    end

    connect(box.MouseButton1Click, function()
        object:SetValue(not object.Value)
    end)
    connect(row.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            object:SetValue(not object.Value)
        end
    end)
    return object
end

function FeatureCardMethods:AddRadioGroup(flag, cfg)
    cfg = cfg or {}
    local values = cfg.Values or {"Always On", "On Attack"}
    local default = cfg.Default or values[1]
    local opt = createOption(flag, default)
    local row = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 28),
        Parent = self.Left
    })
    local ll = list(row, Enum.FillDirection.Horizontal, UDim.new(0, 16))

    local object = setmetatable({ Value = default, Option = opt, Frame = row, Buttons = {} }, OptionMethods)
    local function render(value)
        object.Value = value
        opt.Value = value
        for name, item in pairs(object.Buttons) do
            item.Circle.BackgroundColor3 = name == value and Color3.fromRGB(235, 235, 235) or Color3.fromRGB(67, 67, 67)
        end
    end
    function object:SetValue(value)
        render(value)
        if cfg.Callback then task.spawn(cfg.Callback, value) end
        fireOption(opt, value)
    end
    function object:OnChanged(fn)
        opt:OnChanged(fn)
        return object
    end

    for _, value in ipairs(values) do
        local b = new("TextButton", {
            AutoButtonColor = false,
            Text = "",
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(textWidth(value, 15, Enum.Font.Gotham) + 32, 28),
            Parent = row
        })
        local circle = new("Frame", {
            Name = "Circle",
            BackgroundColor3 = Color3.fromRGB(67, 67, 67),
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 5),
            Size = UDim2.fromOffset(18, 18),
            Parent = b
        })
        corner(circle, UDim.new(1, 0))
        new("TextLabel", {
            BackgroundTransparency = 1,
            Text = value,
            TextColor3 = self.Theme.SubText,
            Font = Enum.Font.Gotham,
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(27, 0),
            Size = UDim2.new(1, -27, 1, 0),
            Parent = b
        })
        b.Circle = circle
        object.Buttons[value] = b
        connect(b.MouseButton1Click, function()
            object:SetValue(value)
        end)
    end

    render(default)
    return object
end

function FeatureCardMethods:AddNametagPreview(cfg)
    cfg = cfg or {}
    local box = new("Frame", {
        Name = "PreviewBox",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0, 118),
        BackgroundColor3 = Color3.fromRGB(93, 93, 93),
        BorderSizePixel = 0,
        Parent = self.Right
    })
    corner(box, UDim.new(0, 16))

    local bubble = new("Frame", {
        Name = "Bubble",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.42),
        Size = UDim2.fromOffset(160, 48),
        BackgroundColor3 = Color3.fromRGB(247, 247, 247),
        BorderSizePixel = 0,
        Parent = box
    })
    corner(bubble, UDim.new(0, 10))

    local tail = new("Frame", {
        Name = "Tail",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 1),
        Rotation = 45,
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = Color3.fromRGB(247, 247, 247),
        BorderSizePixel = 0,
        Parent = bubble
    })

    local name = cfg.Name or "BlueWizard"
    local health = cfg.Health or 102.44
    local color = cfg.HealthColor or self.Theme.Accent2
    local label = new("TextLabel", {
        Name = "Text",
        BackgroundTransparency = 1,
        RichText = true,
        Text = string.format('%s <font color="rgb(%d,%d,%d)">%s</font>', name, math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255), tostring(health)),
        TextColor3 = Color3.fromRGB(45, 45, 45),
        TextSize = 15,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.fromScale(1, 1),
        Parent = bubble
    })

    local object = { Frame = box, Bubble = bubble, Label = label }
    function object:Set(nameText, hp, hpColor)
        local c = hpColor or color
        label.Text = string.format('%s <font color="rgb(%d,%d,%d)">%s</font>', tostring(nameText), math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), tostring(hp))
    end
    return object
end

function Fluent:Notify(cfg)
    cfg = cfg or {}
    local win = Fluent.Window
    if not win then return end
    local holder = win.Gui:FindFirstChild("NotifyHolder")
    if not holder then
        holder = new("Frame", {
            Name = "NotifyHolder",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -18, 1, -18),
            Size = UDim2.fromOffset(340, 520),
            Parent = win.Gui
        })
        local ll = list(holder, Enum.FillDirection.Vertical, UDim.new(0, 10))
        ll.VerticalAlignment = Enum.VerticalAlignment.Bottom
    end

    local frame = new("CanvasGroup", {
        Name = "Notification",
        BackgroundColor3 = win.Theme.Card,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, cfg.SubContent and 96 or 78),
        GroupTransparency = 1,
        Parent = holder
    })
    corner(frame, UDim.new(0, 18))
    stroke(frame, win.Theme.Stroke, 1, 0.25)
    animateIn(frame, 0)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Text = cfg.Title or "Notification",
        TextColor3 = win.Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 17,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 18, 0, 12),
        Size = UDim2.new(1, -36, 0, 22),
        Parent = frame
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Text = cfg.Content or "",
        TextColor3 = win.Theme.SubText,
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.new(0, 18, 0, 38),
        Size = UDim2.new(1, -36, 0, cfg.SubContent and 22 or 28),
        Parent = frame
    })

    if cfg.SubContent then
        new("TextLabel", {
            BackgroundTransparency = 1,
            Text = cfg.SubContent,
            TextColor3 = win.Theme.Accent,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.new(0, 18, 0, 65),
            Size = UDim2.new(1, -36, 0, 18),
            Parent = frame
        })
    end

    local bar = new("Frame", {
        Name = "Progress",
        BackgroundColor3 = win.Theme.Accent,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(0, 0, 0, 3),
        Parent = frame
    })
    corner(bar, UDim.new(1, 0))

    if cfg.Duration ~= nil then
        tween(bar, cfg.Duration, { Size = UDim2.new(1, 0, 0, 3) }, Enum.EasingStyle.Linear)
        task.delay(cfg.Duration, function()
            if frame.Parent then
                tween(frame, 0.18, { GroupTransparency = 1 }, Enum.EasingStyle.Quint)
                local s = frame:FindFirstChildOfClass("UIScale")
                if s then tween(s, 0.18, { Scale = 0.94 }, Enum.EasingStyle.Quint) end
                task.wait(0.2)
                if frame.Parent then frame:Destroy() end
            end
        end)
    end

    return frame
end

function Fluent:CreateBillboardNametag(target, cfg)
    cfg = cfg or {}
    local character = target or (LocalPlayer and LocalPlayer.Character)
    if not character then return nil end
    local head = character:FindFirstChild("Head") or character:FindFirstChildWhichIsA("BasePart")
    if not head then return nil end

    local old = head:FindFirstChild("hehe_DemoNametag")
    if old then old:Destroy() end

    local gui = new("BillboardGui", {
        Name = "hehe_DemoNametag",
        AlwaysOnTop = true,
        Size = UDim2.fromOffset(220, 54),
        StudsOffset = cfg.StudsOffset or Vector3.new(0, 2.7, 0),
        Adornee = head,
        Parent = head
    })

    local bubble = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(170, 38),
        BackgroundColor3 = Color3.fromRGB(250, 250, 250),
        BorderSizePixel = 0,
        Parent = gui
    })
    corner(bubble, UDim.new(0, 10))

    new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 1),
        Rotation = 45,
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Color3.fromRGB(250, 250, 250),
        BorderSizePixel = 0,
        Parent = bubble
    })

    local name = cfg.Name or (LocalPlayer and LocalPlayer.DisplayName) or "Player"
    local health = cfg.Health or 100
    local color = cfg.HealthColor or Color3.fromRGB(105, 190, 75)
    local label = new("TextLabel", {
        BackgroundTransparency = 1,
        RichText = true,
        Text = string.format('%s <font color="rgb(%d,%d,%d)">%s</font>', name, math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255), tostring(health)),
        TextColor3 = Color3.fromRGB(50, 50, 50),
        TextSize = 15,
        Font = Enum.Font.GothamMedium,
        Size = UDim2.fromScale(1, 1),
        Parent = bubble
    })

    return gui
end

local SaveManager = {}
function SaveManager:SetLibrary() end
function SaveManager:IgnoreThemeSettings() end
function SaveManager:SetIgnoreIndexes() end
function SaveManager:SetFolder(folder) self.Folder = folder end
function SaveManager:BuildConfigSection(tab)
    if tab and tab.AddParagraph then
        tab:AddParagraph({
            Title = "Config Manager",
            Content = "Single-file demo stub. Replace this with your real readfile/writefile config system if needed."
        })
    end
end
function SaveManager:LoadAutoloadConfig() end

local InterfaceManager = {}
function InterfaceManager:SetLibrary() end
function InterfaceManager:SetFolder(folder) self.Folder = folder end
function InterfaceManager:BuildInterfaceSection(tab)
    if tab and tab.AddParagraph then
        tab:AddParagraph({
            Title = "Interface Manager",
            Content = "Single-file demo stub. Theme/config UI section has been added."
        })
    end
end

function Fluent:Unload()
    self.Unloaded = true
    for _, c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(Connections)
    if self.Window and self.Window.Gui then
        self.Window.Gui:Destroy()
    end
end

Fluent.SaveManager = SaveManager
Fluent.InterfaceManager = InterfaceManager
return Fluent

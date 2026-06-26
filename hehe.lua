--[[
    Fluent-style Roblox UI Library (single file)
    Inspired by the UI layout/screenshots provided by the user.
    API style:
        local Fluent = loadstring(readfile("FluentLikeUI.lua"))()
        local Window = Fluent:CreateWindow({...})
        local Tab = Window:AddTab({...})
        Fluent:Notify({...})
        Tab:AddParagraph({...})
        Tab:AddButton({...})
        Tab:AddToggle("Flag", {...})
        Tab:AddSlider("Flag", {...})
        Tab:AddDropdown("Flag", {...})
        Tab:AddColorpicker("Flag", {...})
        Tab:AddKeybind("Flag", {...})
        Tab:AddInput("Flag", {...})

    This is a UI framework only. It does not include game exploit logic.
]]

local Fluent = {}
Fluent.Version = "Custom-1.0"
Fluent.Options = {}
Fluent.Unloaded = false

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local function safeParent()
    local ok, hidden = pcall(function()
        return gethui and gethui()
    end)
    if ok and hidden then
        return hidden
    end

    local okCore = pcall(function()
        local test = Instance.new("ScreenGui")
        test.Parent = CoreGui
        test:Destroy()
    end)

    if okCore then
        return CoreGui
    end

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
    local c = new("UICorner", {
        CornerRadius = radius or UDim.new(0, 14),
        Parent = parent
    })
    return c
end

local function stroke(parent, color, thickness, transparency)
    return new("UIStroke", {
        Color = color or Color3.fromRGB(45, 45, 45),
        Thickness = thickness or 1,
        Transparency = transparency or 0.25,
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
        TweenInfo.new(time or 0.18, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
        props
    )
    tw:Play()
    return tw
end

local function getTextWidth(text, textSize, font)
    local ok, result = pcall(function()
        return TextService:GetTextSize(tostring(text), textSize, font, Vector2.new(100000, textSize)).X
    end)
    return ok and result or 0
end

local function makeDraggable(handle, target)
    target = target or handle
    local dragging = false
    local dragStart, startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
    local mouse = mouseButtonName(input)
    if mouse then return mouse == bindName end
    return input.KeyCode and input.KeyCode.Name == bindName
end

local Themes = {
    Dark = {
        Background = Color3.fromRGB(13, 13, 13),
        Sidebar = Color3.fromRGB(18, 18, 18),
        Card = Color3.fromRGB(19, 19, 19),
        Card2 = Color3.fromRGB(24, 24, 24),
        Stroke = Color3.fromRGB(45, 45, 45),
        Text = Color3.fromRGB(245, 245, 245),
        SubText = Color3.fromRGB(170, 170, 170),
        Muted = Color3.fromRGB(105, 105, 105),
        Accent = Color3.fromRGB(145, 255, 0),
        Accent2 = Color3.fromRGB(115, 190, 75)
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

local function createCard(parent, title, description)
    local card = new("Frame", {
        Name = "Card",
        BackgroundColor3 = Themes.Dark.Card,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, description and 82 or 64),
        Parent = parent
    })
    corner(card, UDim.new(0, 20))
    stroke(card, Themes.Dark.Stroke, 1, 0.45)

    local titleLabel = new("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Text = title or "",
        TextColor3 = Themes.Dark.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -22, 0, 24),
        Position = UDim2.new(0, 22, 0, description and 15 or 20),
        Parent = card
    })

    local descLabel
    if description then
        descLabel = new("TextLabel", {
            Name = "Description",
            BackgroundTransparency = 1,
            Text = description,
            TextColor3 = Themes.Dark.SubText,
            Font = Enum.Font.Gotham,
            TextSize = 15,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Size = UDim2.new(1, -130, 0, 38),
            Position = UDim2.new(0, 22, 0, 40),
            Parent = card
        })
    end

    return card, titleLabel, descLabel
end

function Fluent:CreateWindow(cfg)
    cfg = cfg or {}

    local theme = getTheme(cfg.Theme)
    local gui = protect(new("ScreenGui", {
        Name = "FluentLikeUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = safeParent()
    }))

    local holder = new("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = cfg.Size or UDim2.fromOffset(860, 610),
        BackgroundColor3 = theme.Background,
        BorderSizePixel = 0,
        Parent = gui
    })
    corner(holder, UDim.new(0, 26))
    stroke(holder, theme.Stroke, 1, 0.1)
    makeDraggable(holder, holder)

    local windowScale = new("UIScale", { Scale = 1, Parent = holder })

    local sidebar = new("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, cfg.TabWidth or 210, 1, 0),
        BackgroundColor3 = theme.Sidebar,
        BorderSizePixel = 0,
        Parent = holder
    })
    corner(sidebar, UDim.new(0, 26))

    local sidebarMask = new("Frame", {
        Name = "SidebarRightMask",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 28, 1, 0),
        BackgroundColor3 = theme.Sidebar,
        BorderSizePixel = 0,
        Parent = sidebar
    })

    local sidebarLine = new("Frame", {
        Name = "Divider",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = theme.Stroke,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Parent = sidebar
    })

    local sidebarTitle = new("TextLabel", {
        Name = "SidebarTitle",
        BackgroundTransparency = 1,
        Text = cfg.UserInfoTitle or "Modules",
        Font = Enum.Font.Gotham,
        TextSize = 16,
        TextColor3 = theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 22, 0, 28),
        Size = UDim2.new(1, -44, 0, 30),
        Parent = sidebar
    })

    local tabsHolder = new("Frame", {
        Name = "Tabs",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 20, 0, 70),
        Size = UDim2.new(1, -40, 1, -90),
        Parent = sidebar
    })
    list(tabsHolder, Enum.FillDirection.Vertical, UDim.new(0, 8))

    local topbar = new("Frame", {
        Name = "Topbar",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, cfg.TabWidth or 210, 0, 0),
        Size = UDim2.new(1, -(cfg.TabWidth or 210), 0, 74),
        Parent = holder
    })

    local topbarLine = new("Frame", {
        Name = "Divider",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = theme.Stroke,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Parent = topbar
    })

    local configButton = new("TextButton", {
        Name = "ConfigDropdown",
        AutoButtonColor = false,
        Text = "  Select Config          ˅",
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
    stroke(configButton, theme.Stroke, 1, 0.3)

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
        stroke(searchBox, theme.Stroke, 1, 0.3)
        padding(searchBox, UDim.new(0, 14), UDim.new(0, 14), UDim.new(0, 0), UDim.new(0, 0))
    end

    local content = new("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, cfg.TabWidth or 210, 0, 74),
        Size = UDim2.new(1, -(cfg.TabWidth or 210), 1, -74),
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
        Scale = windowScale,
        TabsHolder = tabsHolder,
        Pages = pages,
        Tabs = {},
        SelectedTab = nil,
        Theme = theme,
        SearchBox = searchBox,
        MinimizeKey = cfg.MinimizeKey or Enum.KeyCode.LeftControl,
        Minimized = false
    }, WindowMethods)

    if searchBox then
        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            local query = string.lower(searchBox.Text)
            for _, tab in ipairs(win.Tabs) do
                for _, item in ipairs(tab.SearchItems) do
                    local hit = query == "" or string.find(string.lower(item.Text), query, 1, true)
                    item.Frame.Visible = hit
                end
            end
        end)
    end

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == win.MinimizeKey then
            win:SetMinimized(not win.Minimized)
        end
    end)

    Fluent.Window = win
    return win
end

function WindowMethods:SetMinimized(state)
    self.Minimized = state
    tween(self.Scale, 0.24, { Scale = state and 0 or 1 }, Enum.EasingStyle.Quint)
    self.Holder.Visible = true
    if state then
        task.delay(0.25, function()
            if self.Minimized then
                self.Holder.Visible = false
            end
        end)
    end
end

function WindowMethods:SelectTab(indexOrTab)
    local tab = type(indexOrTab) == "number" and self.Tabs[indexOrTab] or indexOrTab
    if not tab then return end

    self.SelectedTab = tab
    for _, other in ipairs(self.Tabs) do
        other.Page.Visible = other == tab
        tween(other.Button, 0.18, {
            BackgroundTransparency = other == tab and 0 or 1,
            BackgroundColor3 = other == tab and Color3.fromRGB(66, 66, 66) or self.Theme.Sidebar
        })
        other.Button.TextColor3 = other == tab and self.Theme.Text or self.Theme.SubText
    end
end

function WindowMethods:AddTab(cfg)
    cfg = cfg or {}
    local button = new("TextButton", {
        Name = cfg.Title or "Tab",
        AutoButtonColor = false,
        Text = cfg.Title or "Tab",
        TextColor3 = self.Theme.SubText,
        TextSize = 18,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        BackgroundColor3 = Color3.fromRGB(66, 66, 66),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 42),
        Parent = self.TabsHolder
    })
    corner(button, UDim.new(0, 9))
    padding(button, UDim.new(0, 14), UDim.new(0, 8), UDim.new(0, 0), UDim.new(0, 0))

    local page = new("ScrollingFrame", {
        Name = (cfg.Title or "Tab") .. "Page",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        Parent = self.Pages
    })

    local layout = list(page, Enum.FillDirection.Vertical, UDim.new(0, 18))
    padding(page, UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 0), UDim.new(0, 24))

    local tab = setmetatable({
        Window = self,
        Button = button,
        Page = page,
        Layout = layout,
        SearchItems = {},
        Name = cfg.Title or "Tab"
    }, TabMethods)

    button.MouseButton1Click:Connect(function()
        self:SelectTab(tab)
    end)

    table.insert(self.Tabs, tab)
    if not self.SelectedTab then
        self:SelectTab(tab)
    end

    return tab
end

function WindowMethods:Dialog(cfg)
    cfg = cfg or {}
    local overlay = new("TextButton", {
        Name = "DialogOverlay",
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.35,
        Size = UDim2.fromScale(1, 1),
        Parent = self.Gui
    })

    local box = new("Frame", {
        Name = "Dialog",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(390, 210),
        BackgroundColor3 = self.Theme.Card,
        BorderSizePixel = 0,
        Parent = overlay
    })
    corner(box, UDim.new(0, 20))
    stroke(box, self.Theme.Stroke, 1, 0.2)

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
        Size = UDim2.new(1, -44, 0, 82),
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
        btn.MouseButton1Click:Connect(function()
            overlay:Destroy()
            if b.Callback then
                task.spawn(b.Callback)
            end
        end)
    end

    overlay.MouseButton1Click:Connect(function()
        overlay:Destroy()
    end)

    box.InputBegan:Connect(function() end)
end

function WindowMethods:AddMinimizer(cfg)
    return Fluent:CreateMinimizer(cfg)
end

function Fluent:CreateMinimizer(cfg)
    cfg = cfg or {}
    local gui = self.Window and self.Window.Gui or protect(new("ScreenGui", {
        Name = "FluentLikeMinimizer",
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
    if cfg.Draggable ~= false then
        makeDraggable(mini, mini)
    end

    mini.MouseButton1Click:Connect(function()
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
    local sectionFrame = new("Frame", {
        Name = title or "Section",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
        Parent = self.Page
    })

    local label = new("TextLabel", {
        BackgroundTransparency = 1,
        Text = (icon and icon ~= "" and (tostring(icon) .. "  ") or "") .. (title or "Section"),
        TextColor3 = self.Window.Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 19,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 4, 0, 0),
        Size = UDim2.new(1, -8, 1, 0),
        Parent = sectionFrame
    })

    local section = setmetatable({
        Tab = self,
        Frame = sectionFrame
    }, SectionMethods)

    self:_trackSearch(sectionFrame, title)
    return section
end

local function createTextBlock(parent, title, content, icon)
    local height = content and #tostring(content) > 80 and 108 or 82
    local card = new("Frame", {
        Name = "Paragraph",
        BackgroundColor3 = Themes.Dark.Card,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, title and height or 70),
        Parent = parent
    })
    corner(card, UDim.new(0, 20))
    stroke(card, Themes.Dark.Stroke, 1, 0.45)

    local y = title and 15 or 14
    if title then
        new("TextLabel", {
            BackgroundTransparency = 1,
            Text = (icon and icon ~= "" and (tostring(icon) .. "  ") or "") .. tostring(title),
            TextColor3 = Themes.Dark.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 18,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.new(0, 22, 0, y),
            Size = UDim2.new(1, -44, 0, 24),
            Parent = card
        })
        y = 42
    end

    new("TextLabel", {
        BackgroundTransparency = 1,
        Text = tostring(content or ""),
        TextColor3 = title and Themes.Dark.SubText or Themes.Dark.Text,
        Font = Enum.Font.Gotham,
        TextSize = title and 15 or 16,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.new(0, 22, 0, y),
        Size = UDim2.new(1, -44, 1, -y - 14),
        Parent = card
    })

    return card
end

function TabMethods:AddParagraph(cfg)
    cfg = cfg or {}
    local card = createTextBlock(self.Page, cfg.Title, cfg.Content, cfg.Icon)
    self:_trackSearch(card, (cfg.Title or "") .. " " .. (cfg.Content or ""))
    return card
end

function SectionMethods:AddParagraph(cfg)
    return self.Tab:AddParagraph(cfg)
end

function TabMethods:AddButton(cfg)
    cfg = cfg or {}
    local card, titleLabel, desc = createCard(self.Page, cfg.Title or "Button", cfg.Description)
    card.Size = UDim2.new(1, 0, 0, cfg.Description and 82 or 64)

    local btn = new("TextButton", {
        Name = "Button",
        AutoButtonColor = false,
        Text = "›",
        TextColor3 = self.Window.Theme.SubText,
        TextSize = 28,
        Font = Enum.Font.GothamBold,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -20, 0.5, 0),
        Size = UDim2.fromOffset(44, 44),
        Parent = card
    })

    btn.MouseButton1Click:Connect(function()
        if cfg.Callback then
            task.spawn(cfg.Callback)
        end
    end)

    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if cfg.Callback then
                task.spawn(cfg.Callback)
            end
        end
    end)

    self:_trackSearch(card, (cfg.Title or "") .. " " .. (cfg.Description or ""))
    return card
end

function SectionMethods:AddButton(cfg)
    return self.Tab:AddButton(cfg)
end

local function addToggleTo(parentTab, flag, cfg)
    cfg = cfg or {}
    local opt = createOption(flag, cfg.Default == true)
    local card, titleLabel, desc = createCard(parentTab.Page, cfg.Title or flag, cfg.Description)
    card.Size = UDim2.new(1, 0, 0, cfg.Description and 82 or 66)

    local switch = new("TextButton", {
        Name = "Toggle",
        AutoButtonColor = false,
        Text = "",
        BackgroundColor3 = Color3.fromRGB(98, 98, 98),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -28, 0.5, 0),
        Size = UDim2.fromOffset(64, 34),
        Parent = card
    })
    corner(switch, UDim.new(1, 0))

    local dot = new("Frame", {
        Name = "Dot",
        BackgroundColor3 = Color3.fromRGB(245, 245, 245),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = opt.Value and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 17, 0.5, 0),
        Size = UDim2.fromOffset(28, 28),
        Parent = switch
    })
    corner(dot, UDim.new(1, 0))

    local object = setmetatable({
        Value = opt.Value,
        Option = opt,
        Frame = card
    }, OptionMethods)

    local function render(value)
        opt.Value = value
        object.Value = value
        tween(switch, 0.2, { BackgroundColor3 = value and parentTab.Window.Theme.Accent2 or Color3.fromRGB(98, 98, 98) })
        tween(dot, 0.2, { Position = value and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 17, 0.5, 0) })
    end

    function object:SetValue(value)
        value = value == true
        render(value)
        if cfg.Callback then task.spawn(cfg.Callback, value) end
        for _, fn in ipairs(opt.Changed) do task.spawn(fn, value) end
    end

    function object:OnChanged(fn)
        opt:OnChanged(fn)
        return object
    end

    switch.MouseButton1Click:Connect(function()
        object:SetValue(not object.Value)
    end)

    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            object:SetValue(not object.Value)
        end
    end)

    render(opt.Value)
    parentTab:_trackSearch(card, (cfg.Title or flag) .. " " .. (cfg.Description or ""))
    return object
end

function TabMethods:AddToggle(flag, cfg)
    return addToggleTo(self, flag, cfg)
end

function SectionMethods:AddToggle(flag, cfg)
    return self.Tab:AddToggle(flag, cfg)
end

local function addSliderTo(parentTab, flag, cfg)
    cfg = cfg or {}
    local min = cfg.Min or 0
    local max = cfg.Max or 100
    local rounding = cfg.Rounding or 0
    local default = cfg.Default or min
    local opt = createOption(flag, default)

    local card, titleLabel, desc = createCard(parentTab.Page, cfg.Title or flag, cfg.Description)
    card.Size = UDim2.new(1, 0, 0, cfg.Description and 104 or 86)

    local valueText = new("TextLabel", {
        Name = "Value",
        BackgroundTransparency = 1,
        Text = tostring(default),
        TextColor3 = parentTab.Window.Theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -285, 0, cfg.Description and 22 or 18),
        Size = UDim2.fromOffset(90, 24),
        Parent = card
    })

    local track = new("Frame", {
        Name = "Track",
        BackgroundColor3 = Color3.fromRGB(150, 150, 150),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -28, 0, cfg.Description and 34 or 32),
        Size = UDim2.fromOffset(240, 8),
        Parent = card
    })
    corner(track, UDim.new(1, 0))

    local fill = new("Frame", {
        Name = "Fill",
        BackgroundColor3 = parentTab.Window.Theme.Accent2,
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

    local object = setmetatable({
        Value = default,
        Option = opt,
        Frame = card
    }, OptionMethods)

    local function roundValue(v)
        local p = 10 ^ rounding
        return math.floor(v * p + 0.5) / p
    end

    local function valueToAlpha(v)
        if max == min then return 0 end
        return math.clamp((v - min) / (max - min), 0, 1)
    end

    local function render(value, callback)
        value = math.clamp(roundValue(value), min, max)
        local alpha = valueToAlpha(value)
        object.Value = value
        opt.Value = value
        valueText.Text = tostring(value) .. (cfg.Suffix and tostring(cfg.Suffix) or "")
        tween(fill, 0.15, { Size = UDim2.fromScale(alpha, 1) })
        tween(knob, 0.15, { Position = UDim2.fromScale(alpha, 0.5) })
        if callback and cfg.Callback then task.spawn(cfg.Callback, value) end
        if callback then
            for _, fn in ipairs(opt.Changed) do task.spawn(fn, value) end
        end
    end

    local dragging = false
    local function setFromX(x, callback)
        local alpha = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        render(min + ((max - min) * alpha), callback)
    end

    input.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(inp.Position.X, true)
        end
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            setFromX(inp.Position.X, true)
        end
    end)

    UserInputService.InputEnded:Connect(function(inp)
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
    parentTab:_trackSearch(card, (cfg.Title or flag) .. " " .. (cfg.Description or ""))
    return object
end

function TabMethods:AddSlider(flag, cfg)
    return addSliderTo(self, flag, cfg)
end

function SectionMethods:AddSlider(flag, cfg)
    return self.Tab:AddSlider(flag, cfg)
end

local function addDropdownTo(parentTab, flag, cfg)
    cfg = cfg or {}
    local values = cfg.Values or cfg.List or {}
    local default = cfg.Default
    if type(default) == "number" then default = values[default] end
    if default == nil then default = cfg.Multi and {} or values[1] end
    local opt = createOption(flag, default)

    local card, titleLabel, desc = createCard(parentTab.Page, cfg.Title or flag, cfg.Description)
    card.Size = UDim2.new(1, 0, 0, cfg.Description and 86 or 66)

    local selectButton = new("TextButton", {
        Name = "Select",
        AutoButtonColor = false,
        Text = "",
        TextColor3 = parentTab.Window.Theme.Text,
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

    local dropFrame = new("Frame", {
        Name = "DropdownMenu",
        BackgroundColor3 = Color3.fromRGB(19, 19, 19),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 1, 8),
        ClipsDescendants = true,
        ZIndex = 20,
        Parent = selectButton
    })
    corner(dropFrame, UDim.new(0, 12))
    stroke(dropFrame, Color3.fromRGB(55, 55, 55), 1, 0.35)
    local dropLayout = list(dropFrame, Enum.FillDirection.Vertical, UDim.new(0, 0))

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

    local function fire()
        opt.Value = object.Value
        if cfg.Callback then task.spawn(cfg.Callback, object.Value) end
        for _, fn in ipairs(opt.Changed) do task.spawn(fn, object.Value) end
    end

    local function setText()
        selectButton.Text = asText(object.Value) .. "   ˅"
    end

    local function setOpen(state)
        object.Open = state
        local itemHeight = 34
        local h = math.min(#values * itemHeight, 190)
        tween(dropFrame, 0.18, { Size = UDim2.new(1, 0, 0, state and h or 0) })
    end

    function object:SetValue(value)
        if cfg.Multi then
            if type(value) == "table" then
                object.Value = value
            end
        else
            object.Value = value
        end
        setText()
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
            Text = tostring(value),
            TextColor3 = parentTab.Window.Theme.Text,
            TextSize = 15,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundColor3 = Color3.fromRGB(24, 24, 24),
            BackgroundTransparency = 0.1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 34),
            ZIndex = 21,
            Parent = dropFrame
        })
        padding(item, UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 0), UDim.new(0, 0))
        item.MouseButton1Click:Connect(function()
            if cfg.Multi then
                local tbl = type(object.Value) == "table" and object.Value or {}
                tbl[value] = not tbl[value]
                object.Value = tbl
            else
                object.Value = value
                setOpen(false)
            end
            setText()
            fire()
        end)
    end

    selectButton.MouseButton1Click:Connect(function()
        setOpen(not object.Open)
    end)

    setText()
    parentTab:_trackSearch(card, (cfg.Title or flag) .. " " .. (cfg.Description or ""))
    return object
end

function TabMethods:AddDropdown(flag, cfg)
    return addDropdownTo(self, flag, cfg)
end

function SectionMethods:AddDropdown(flag, cfg)
    return self.Tab:AddDropdown(flag, cfg)
end

local function addColorpickerTo(parentTab, flag, cfg)
    cfg = cfg or {}
    local default = cfg.Default or Color3.fromRGB(96, 205, 255)
    local opt = createOption(flag, default)

    local card, titleLabel, desc = createCard(parentTab.Page, cfg.Title or flag, cfg.Description)
    card.Size = UDim2.new(1, 0, 0, cfg.Description and 86 or 66)

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

    local popup = new("Frame", {
        Name = "ColorPopup",
        BackgroundColor3 = Color3.fromRGB(19, 19, 19),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(210, 280),
        Position = UDim2.new(1, -220, 1, 8),
        Visible = false,
        ZIndex = 50,
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
        Size = UDim2.fromOffset(174, 174),
        Image = "rbxassetid://4155801252",
        ZIndex = 51,
        Parent = popup
    })
    corner(square, UDim.new(0, 12))

    local cursor = new("Frame", {
        Name = "Cursor",
        BackgroundTransparency = 1,
        Position = UDim2.new(0.65, -6, 0.35, -6),
        Size = UDim2.fromOffset(12, 12),
        ZIndex = 52,
        Parent = square
    })
    corner(cursor, UDim.new(1, 0))
    stroke(cursor, Color3.fromRGB(255, 255, 255), 3, 0)

    local hue = new("ImageButton", {
        Name = "Hue",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(18, 204),
        Size = UDim2.fromOffset(174, 12),
        Image = "rbxassetid://3641079629",
        ZIndex = 51,
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
        ZIndex = 52,
        Parent = hue
    })
    corner(hueCursor, UDim.new(1, 0))
    stroke(hueCursor, Color3.fromRGB(75, 75, 75), 2, 0)

    local modeButton = new("TextButton", {
        Name = "Mode",
        AutoButtonColor = false,
        Text = "RGB ˅",
        TextColor3 = parentTab.Window.Theme.Text,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        BackgroundColor3 = Color3.fromRGB(23, 23, 23),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(18, 232),
        Size = UDim2.fromOffset(78, 34),
        ZIndex = 51,
        Parent = popup
    })
    corner(modeButton, UDim.new(0, 10))
    stroke(modeButton, Color3.fromRGB(55, 55, 55), 1, 0.35)

    local modes = {"Hex", "RGB", "HSL"}
    local modeIndex = 2
    modeButton.MouseButton1Click:Connect(function()
        modeIndex = (modeIndex % #modes) + 1
        modeButton.Text = modes[modeIndex] .. " ˅"
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
        if callback and cfg.Callback then
            task.spawn(cfg.Callback, color)
        end
        if callback then
            for _, fn in ipairs(opt.Changed) do task.spawn(fn, color) end
        end
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

    swatch.MouseButton1Click:Connect(function()
        popup.Visible = not popup.Visible
    end)

    square.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            draggingSquare = true
            setSquare(inp.Position, true)
        end
    end)

    hue.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            draggingHue = true
            setHue(inp.Position, true)
        end
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if draggingSquare and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            setSquare(inp.Position, true)
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

    function object:SetValueRGB(color)
        h, s, v = color:ToHSV()
        render(true)
    end

    function object:SetValue(color)
        self:SetValueRGB(color)
    end

    function object:OnChanged(fn)
        opt:OnChanged(fn)
        return object
    end

    render(false)
    parentTab:_trackSearch(card, (cfg.Title or flag) .. " " .. (cfg.Description or ""))
    return object
end

function TabMethods:AddColorpicker(flag, cfg)
    return addColorpickerTo(self, flag, cfg)
end

function SectionMethods:AddColorpicker(flag, cfg)
    return self.Tab:AddColorpicker(flag, cfg)
end

local function addKeybindTo(parentTab, flag, cfg)
    cfg = cfg or {}
    local default = cfg.Default or "None"
    local mode = cfg.Mode or "Toggle"
    local opt = createOption(flag, default)

    local card, titleLabel, desc = createCard(parentTab.Page, cfg.Title or flag, cfg.Description)
    card.Size = UDim2.new(1, 0, 0, cfg.Description and 86 or 66)

    local bindButton = new("TextButton", {
        Name = "BindButton",
        AutoButtonColor = false,
        Text = tostring(default),
        TextColor3 = parentTab.Window.Theme.Text,
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

    local keyLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Text = "Key",
        TextColor3 = parentTab.Window.Theme.SubText,
        Font = Enum.Font.Gotham,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -108, 0.5, 0),
        Size = UDim2.fromOffset(40, 40),
        Parent = card
    })

    local menu = new("Frame", {
        Name = "KeybindMenu",
        BackgroundColor3 = Color3.fromRGB(19, 19, 19),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(180, 112),
        Position = UDim2.new(1, -190, 1, 8),
        Visible = false,
        ZIndex = 40,
        Parent = card
    })
    corner(menu, UDim.new(0, 16))
    stroke(menu, Color3.fromRGB(55, 55, 55), 1, 0.35)

    local line = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(45, 45, 45),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 14, 0, 48),
        Size = UDim2.new(1, -28, 0, 1),
        ZIndex = 41,
        Parent = menu
    })

    local modeButtons = {}

    local object = setmetatable({
        Value = default,
        Mode = mode,
        State = false,
        Listening = false,
        Option = opt,
        Frame = card
    }, OptionMethods)

    local function updateModeVisual()
        for name, btn in pairs(modeButtons) do
            btn.Circle.BackgroundColor3 = object.Mode == name and Color3.fromRGB(235, 235, 235) or Color3.fromRGB(67, 67, 67)
        end
    end

    local function addMode(name, y)
        local row = new("TextButton", {
            AutoButtonColor = false,
            Text = "",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 15, 0, y),
            Size = UDim2.new(1, -30, 0, 28),
            ZIndex = 41,
            Parent = menu
        })
        local circle = new("Frame", {
            Name = "Circle",
            BackgroundColor3 = Color3.fromRGB(67, 67, 67),
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 6),
            Size = UDim2.fromOffset(18, 18),
            ZIndex = 42,
            Parent = row
        })
        corner(circle, UDim.new(1, 0))
        new("TextLabel", {
            BackgroundTransparency = 1,
            Text = name,
            TextColor3 = parentTab.Window.Theme.SubText,
            Font = Enum.Font.Gotham,
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(28, 0),
            Size = UDim2.new(1, -28, 1, 0),
            ZIndex = 42,
            Parent = row
        })
        row.MouseButton1Click:Connect(function()
            object.Mode = name
            updateModeVisual()
            if cfg.ChangedCallback then task.spawn(cfg.ChangedCallback, object.Value) end
        end)
        modeButtons[name] = row
        row.Circle = circle
    end

    addMode("Toggle", 55)
    addMode("Hold", 82)
    updateModeVisual()

    function object:GetState()
        return self.State
    end

    function object:SetValue(key, newMode)
        if type(key) == "string" then
            object.Value = key
            opt.Value = key
            bindButton.Text = key
        end
        if newMode then
            object.Mode = newMode
            updateModeVisual()
        end
        if cfg.ChangedCallback then task.spawn(cfg.ChangedCallback, object.Value) end
        for _, fn in ipairs(opt.Changed) do task.spawn(fn, object.Value) end
    end

    function object:OnClick(fn)
        object.ClickCallback = fn
        return object
    end

    function object:OnChanged(fn)
        opt:OnChanged(fn)
        return object
    end

    bindButton.MouseButton1Click:Connect(function()
        object.Listening = true
        bindButton.Text = "..."
    end)

    bindButton.MouseButton2Click:Connect(function()
        menu.Visible = not menu.Visible
    end)

    UserInputService.InputBegan:Connect(function(inp, gameProcessed)
        if gameProcessed then return end
        if object.Listening then
            local name = keyNameFromInput(inp)
            object.Listening = false
            object:SetValue(name, object.Mode)
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

    UserInputService.InputEnded:Connect(function(inp)
        if matchesBind(inp, object.Value) and object.Mode == "Hold" then
            object.State = false
            if cfg.Callback then task.spawn(cfg.Callback, false) end
        end
    end)

    parentTab:_trackSearch(card, (cfg.Title or flag) .. " " .. (cfg.Description or ""))
    return object
end

function TabMethods:AddKeybind(flag, cfg)
    return addKeybindTo(self, flag, cfg)
end

function SectionMethods:AddKeybind(flag, cfg)
    return self.Tab:AddKeybind(flag, cfg)
end

local function addInputTo(parentTab, flag, cfg)
    cfg = cfg or {}
    local default = cfg.Default or ""
    local opt = createOption(flag, default)

    local card, titleLabel, desc = createCard(parentTab.Page, cfg.Title or flag, cfg.Description)
    card.Size = UDim2.new(1, 0, 0, cfg.Description and 88 or 68)

    local box = new("TextBox", {
        Name = "Input",
        Text = tostring(default),
        PlaceholderText = cfg.Placeholder or "",
        ClearTextOnFocus = false,
        TextColor3 = parentTab.Window.Theme.Text,
        PlaceholderColor3 = parentTab.Window.Theme.SubText,
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
        box.Text = value
        if cfg.Callback then task.spawn(cfg.Callback, value) end
        for _, fn in ipairs(opt.Changed) do task.spawn(fn, value) end
    end

    function object:OnChanged(fn)
        opt:OnChanged(fn)
        return object
    end

    if cfg.Finished then
        box.FocusLost:Connect(function(enter)
            if enter then object:SetValue(box.Text) end
        end)
    else
        box:GetPropertyChangedSignal("Text"):Connect(function()
            if cfg.Numeric then
                local filtered = box.Text:gsub("[^%d%.%-]", "")
                if filtered ~= box.Text then box.Text = filtered end
            end
            object:SetValue(box.Text)
        end)
    end

    parentTab:_trackSearch(card, (cfg.Title or flag) .. " " .. (cfg.Description or ""))
    return object
end

function TabMethods:AddInput(flag, cfg)
    return addInputTo(self, flag, cfg)
end

function SectionMethods:AddInput(flag, cfg)
    return self.Tab:AddInput(flag, cfg)
end

function Fluent:Notify(cfg)
    cfg = cfg or {}
    local win = Fluent.Window
    if not win then return end

    local gui = win.Gui
    local holder = gui:FindFirstChild("NotifyHolder")
    if not holder then
        holder = new("Frame", {
            Name = "NotifyHolder",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -18, 1, -18),
            Size = UDim2.fromOffset(330, 500),
            Parent = gui
        })
        local ll = list(holder, Enum.FillDirection.Vertical, UDim.new(0, 10))
        ll.VerticalAlignment = Enum.VerticalAlignment.Bottom
    end

    local frame = new("Frame", {
        Name = "Notification",
        BackgroundColor3 = win.Theme.Card,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, cfg.SubContent and 94 or 76),
        BackgroundTransparency = 0.04,
        Parent = holder
    })
    corner(frame, UDim.new(0, 18))
    stroke(frame, win.Theme.Stroke, 1, 0.25)

    local scale = new("UIScale", { Scale = 0, Parent = frame })
    tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)

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

    local duration = cfg.Duration
    if duration == nil then return frame end
    tween(bar, duration, { Size = UDim2.new(1, 0, 0, 3) }, Enum.EasingStyle.Linear)

    task.delay(duration, function()
        if frame.Parent then
            tween(scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
            task.wait(0.22)
            if frame.Parent then frame:Destroy() end
        end
    end)

    return frame
end

function Fluent:Unload()
    self.Unloaded = true
    if self.Window and self.Window.Gui then
        self.Window.Gui:Destroy()
    end
end

-- Small built-in compatibility stubs for the sample format.
local SaveManager = {}
function SaveManager:SetLibrary() end
function SaveManager:IgnoreThemeSettings() end
function SaveManager:SetIgnoreIndexes() end
function SaveManager:SetFolder() end
function SaveManager:BuildConfigSection(tab)
    if tab and tab.AddParagraph then
        tab:AddParagraph({
            Title = "Config",
            Content = "SaveManager stub is included because this is a single-file UI. Add your own writefile/readfile save logic if needed."
        })
    end
end
function SaveManager:LoadAutoloadConfig() end

local InterfaceManager = {}
function InterfaceManager:SetLibrary() end
function InterfaceManager:SetFolder() end
function InterfaceManager:BuildInterfaceSection(tab)
    if tab and tab.AddParagraph then
        tab:AddParagraph({
            Title = "Interface",
            Content = "InterfaceManager stub is included in this single-file version."
        })
    end
end

Fluent.SaveManager = SaveManager
Fluent.InterfaceManager = InterfaceManager

return Fluent

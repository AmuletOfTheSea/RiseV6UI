local Assets = loadstring(game:HttpGet("https://raw.githubusercontent.com/AmuletOfTheSea/RiseV6UI/main/Systems/AssetLoader.lua"))()
local Themes = loadstring(game:HttpGet("https://raw.githubusercontent.com/AmuletOfTheSea/RiseV6UI/main/UI/Themes.lua"))()
local Accents = loadstring(game:HttpGet("https://raw.githubusercontent.com/AmuletOfTheSea/RiseV6UI/main/UI/Accents.lua"))()
local FileManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/AmuletOfTheSea/RiseV6UI/main/Systems/FileManager.lua"))()
local ConfigSystemFactory = loadstring(game:HttpGet("https://raw.githubusercontent.com/AmuletOfTheSea/RiseV6UI/main/Systems/ConfigSystem.lua"))()

local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end

local OutfitFont = (function()
    local ok, result = pcall(function() return Assets:GetFont("Outfit-VariableFont_wght") end)
    if ok and result and result.Family and result.Family ~= "" then
        return result
    end
    -- Fallback: use a built-in Roblox font so FontFace never gets a nil/empty Family
    return { Family = Font.fromEnum(Enum.Font.GothamMedium).Family }
end)()

local ValidGuis = {
    PerseusUI = CoreGui,
    MouseUnlockerUI = PlayerGui,
    PerseusMouseUI = CoreGui,
    PerseusHUD = CoreGui,
    NotificationContainer = CoreGui,
}
local GuiConfigs = {
    PerseusUI = {},

    MouseUnlockerUI = {
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 5,
        Enabled = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    },

    PerseusMouseUI = {
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        DisplayOrder = 2147483647,
        ZIndexBehavior = Enum.ZIndexBehavior.Global
    },

    PerseusHUD = {},

    NotificationContainer = {
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 1000,
        ZIndexBehavior = Enum.ZIndexBehavior.Global
    },
}
local ScreenGuis = {}
local EnsureGuis

getgenv().LibraryInstance = getgenv().LibraryInstance or nil

if getgenv().LibraryInstance then
    pcall(function()
        if getgenv().LibraryInstance.Destroy then
            getgenv().LibraryInstance:Destroy()
        else
            getgenv().LibraryInstance:DisableAllModules()
        end
    end)
end

local Library = {
    ThemeObjects = {},
    AccentObjects = {},
    LoadConfig = nil,
    CurrentConfig = nil,
    Flags = {},
    Modules = {},
    Labels = {},
    Toggles = {}
}


local NotificationTypes = {
    Info = {
        Color = Color3.fromRGB(59, 130, 246),
        Icon = "ℹ"
    },
    Success = {
        Color = Color3.fromRGB(34, 197, 94),
        Icon = "✓"
    },
    Warning = {
        Color = Color3.fromRGB(249, 115, 22),
        Icon = "⚠"
    },
    Error = {
        Color = Color3.fromRGB(239, 68, 68),
        Icon = "X"
    }
}

Library.NotificationSystem = {
    Notifications = {},
    Container = nil,
    MaxNotifications = 5,
    CurrentTheme = "Dark",
    CurrentAccent = "Blue"
}

local function CreateNotificationUI(Message, Type, Duration, CustomColor)
    Type = Type or "Info"
    Duration = Duration or 5
    
    local NotifType = NotificationTypes[Type] or NotificationTypes.Info
    local Color = CustomColor or NotifType.Color
    local _bgOk, BgColor  = pcall(function() return Library:GetTheme("Background") end)
    if not _bgOk or type(BgColor) ~= "userdata" then BgColor = Color3.fromRGB(30, 30, 30) end

    local _txtOk, TxtColor = pcall(function() return Library:GetTheme("Text") end)
    if not _txtOk or type(TxtColor) ~= "userdata" then TxtColor = Color3.fromRGB(255, 255, 255) end
    
    local NotificationFrame = Instance.new("Frame")
    NotificationFrame.Name = "Notification"
    NotificationFrame.Size = UDim2.new(0, 300, 0, 80)
    NotificationFrame.BackgroundColor3 = BgColor
    NotificationFrame.BorderSizePixel = 0
    NotificationFrame.LayoutOrder = #Library.NotificationSystem.Notifications + 1
    NotificationFrame.Parent = Library.NotificationSystem.Container
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = NotificationFrame
    
    local AccentBar = Instance.new("Frame")
    AccentBar.Name = "AccentBar"
    AccentBar.Size = UDim2.new(0, 4, 1, 0)
    AccentBar.BackgroundColor3 = Color
    AccentBar.BorderSizePixel = 0
    AccentBar.Parent = NotificationFrame
    
    local AccentCorner = Instance.new("UICorner")
    AccentCorner.CornerRadius = UDim.new(0, 8)
    AccentCorner.Parent = AccentBar
    
    local Shadow = Instance.new("Frame")
    Shadow.Name = "Shadow"
    Shadow.Size = UDim2.new(1, 8, 1, 8)
    Shadow.Position = UDim2.new(0, -4, 0, 4)
    Shadow.BackgroundColor3 = Color3.new(0, 0, 0)
    Shadow.BackgroundTransparency = 0.7
    Shadow.BorderSizePixel = 0
    Shadow.ZIndex = NotificationFrame.ZIndex - 1
    Shadow.Parent = NotificationFrame
    
    local ShadowCorner = Instance.new("UICorner")
    ShadowCorner.CornerRadius = UDim.new(0, 8)
    ShadowCorner.Parent = Shadow
    
    local ContentContainer = Instance.new("Frame")
    ContentContainer.Size = UDim2.new(1, -10, 1, 0)
    ContentContainer.Position = UDim2.new(0, 10, 0, 0)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = NotificationFrame
    
    local IconLabel = Instance.new("TextLabel")
    IconLabel.Name = "Icon"
    IconLabel.Size = UDim2.new(0, 30, 0, 30)
    IconLabel.Position = UDim2.new(0, 0, 0.5, -15)
    IconLabel.BackgroundTransparency = 1
    IconLabel.Text = NotifType.Icon
    IconLabel.TextSize = 20
    IconLabel.TextColor3 = Color
    IconLabel.Font = Enum.Font.GothamBold
    IconLabel.Parent = ContentContainer
    
    local MessageLabel = Instance.new("TextLabel")
    MessageLabel.Name = "Message"
    MessageLabel.Size = UDim2.new(1, -52, 1, 0)
    MessageLabel.Position = UDim2.new(0, 35, 0, 0)
    MessageLabel.BackgroundTransparency = 1
    MessageLabel.Text = Message
    MessageLabel.TextSize = 14
    MessageLabel.TextColor3 = TxtColor
    MessageLabel.TextWrapped = true
    MessageLabel.TextXAlignment = Enum.TextXAlignment.Left
    MessageLabel.TextYAlignment = Enum.TextYAlignment.Center
    local _fontOk = pcall(function() MessageLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Medium, Enum.FontStyle.Normal) end)
    if not _fontOk then MessageLabel.Font = Enum.Font.GothamMedium end
    MessageLabel.Parent = ContentContainer

    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseButton"
    CloseButton.Size = UDim2.new(0, 22, 0, 22)
    CloseButton.Position = UDim2.new(1, -28, 0.5, -11)
    CloseButton.BackgroundTransparency = 1
    CloseButton.Text = ""
    CloseButton.AutoButtonColor = false
    CloseButton.Parent = ContentContainer

    local CloseBar1 = Instance.new("Frame")
    CloseBar1.Size = UDim2.new(0, 12, 0, 2)
    CloseBar1.AnchorPoint = Vector2.new(0.5, 0.5)
    CloseBar1.Position = UDim2.new(0.5, 0, 0.5, 0)
    CloseBar1.Rotation = 45
    CloseBar1.BackgroundColor3 = TxtColor
    CloseBar1.BackgroundTransparency = 0.3
    CloseBar1.BorderSizePixel = 0
    local CloseBar1Corner = Instance.new("UICorner")
    CloseBar1Corner.CornerRadius = UDim.new(1, 0)
    CloseBar1Corner.Parent = CloseBar1
    CloseBar1.Parent = CloseButton

    local CloseBar2 = Instance.new("Frame")
    CloseBar2.Size = UDim2.new(0, 12, 0, 2)
    CloseBar2.AnchorPoint = Vector2.new(0.5, 0.5)
    CloseBar2.Position = UDim2.new(0.5, 0, 0.5, 0)
    CloseBar2.Rotation = -45
    CloseBar2.BackgroundColor3 = TxtColor
    CloseBar2.BackgroundTransparency = 0.3
    CloseBar2.BorderSizePixel = 0
    local CloseBar2Corner = Instance.new("UICorner")
    CloseBar2Corner.CornerRadius = UDim.new(1, 0)
    CloseBar2Corner.Parent = CloseBar2
    CloseBar2.Parent = CloseButton
    
    local State = {
        Frame = NotificationFrame,
        Shadow = Shadow,
        Duration = Duration,
        StartTime = tick(),
        IsLeaving = false,
        CanClose = true
    }
    
    local function RemoveNotification()
        if State.IsLeaving then return end
        State.IsLeaving = true
        State.CanClose = false
        pcall(function() NotificationFrame:Destroy() end)
        local idx = table.find(Library.NotificationSystem.Notifications, State)
        if idx then table.remove(Library.NotificationSystem.Notifications, idx) end
    end
    
    CloseButton.MouseButton1Click:Connect(function()
        if State.CanClose then
            RemoveNotification()
        end
    end)
    
    CloseButton.MouseEnter:Connect(function()
        TweenService:Create(CloseBar1, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = Color, BackgroundTransparency = 0}):Play()
        TweenService:Create(CloseBar2, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = Color, BackgroundTransparency = 0}):Play()
    end)

    CloseButton.MouseLeave:Connect(function()
        TweenService:Create(CloseBar1, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = TxtColor, BackgroundTransparency = 0.3}):Play()
        TweenService:Create(CloseBar2, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = TxtColor, BackgroundTransparency = 0.3}):Play()
    end)
    
    task.delay(Duration, function()
        if not State.IsLeaving and State.CanClose then
            RemoveNotification()
        end
    end)
    
    table.insert(Library.NotificationSystem.Notifications, State)

    while #Library.NotificationSystem.Notifications > Library.NotificationSystem.MaxNotifications do
        local Oldest = Library.NotificationSystem.Notifications[1]
        if Oldest and not Oldest.IsLeaving then
            Oldest.IsLeaving = true
            Oldest.CanClose = false
            pcall(function() Oldest.Shadow:Destroy() end)
            pcall(function() Oldest.Frame:Destroy() end)
            table.remove(Library.NotificationSystem.Notifications, 1)
        else
            break -- already leaving, don't infinite loop
        end
    end
    
    return State
end

function Library:Notify(Message, Type, Duration, CustomColor)
    EnsureGuis()

    if not self.NotificationSystem.Container then
        self.NotificationSystem.Container = ScreenGuis.NotificationContainer:FindFirstChild("NotificationStack")
        if not self.NotificationSystem.Container then
            self.NotificationSystem.Container = Instance.new("Frame")
            self.NotificationSystem.Container.Name = "NotificationStack"
            self.NotificationSystem.Container.AutomaticSize = Enum.AutomaticSize.Y
            self.NotificationSystem.Container.Size = UDim2.new(0, 320, 0, 0)
            self.NotificationSystem.Container.AnchorPoint = Vector2.new(1, 0)
            self.NotificationSystem.Container.Position = UDim2.new(1, -20, 0, 20)
            self.NotificationSystem.Container.BackgroundTransparency = 1
            self.NotificationSystem.Container.Parent = ScreenGuis.NotificationContainer
            
            local ListLayout = Instance.new("UIListLayout")
            ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
            ListLayout.Padding = UDim.new(0, 8)
            ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
            ListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
            ListLayout.Parent = self.NotificationSystem.Container
        end
    end
    
    return CreateNotificationUI(Message, Type, Duration, CustomColor)
end

function Library:Success(Message, Duration)
    return self:Notify(Message, "Success", Duration or 4)
end

function Library:Error(Message, Duration)
    return self:Notify(Message, "Error", Duration or 5)
end

function Library:Warning(Message, Duration)
    return self:Notify(Message, "Warning", Duration or 4.5)
end

function Library:Info(Message, Duration)
    return self:Notify(Message, "Info", Duration or 3)
end

function Library:SetNotificationTheme(ThemeName)
    self.NotificationSystem.CurrentTheme = ThemeName
end

function Library:SetNotificationMaxNotifications(Max)
    self.NotificationSystem.MaxNotifications = Max
end

function Library:ClearAllNotifications()
    for _, Notification in ipairs(self.NotificationSystem.Notifications) do
        Notification.IsLeaving = true
        Notification.CanClose = false
        pcall(function() Notification.Frame:Destroy() end)
    end
    self.NotificationSystem.Notifications = {}
end

local function ClearExistingGuis()
    for Name, Parent in pairs(ValidGuis) do
        for _, Gui in ipairs(Parent:GetChildren()) do
            if Gui:IsA("ScreenGui") and Gui.Name == Name then
                Gui:Destroy()
            end
        end
    end
end

local function CreateGuis()
    ClearExistingGuis()

    for Name, Parent in pairs(ValidGuis) do
        local Gui = Instance.new("ScreenGui")
        Gui.Name = Name
        Gui.Parent = Parent

        local Config = GuiConfigs[Name]
        if Config then
            for Property, Value in pairs(Config) do
                Gui[Property] = Value
            end
        end

        ProtectGui(Gui)
        ScreenGuis[Name] = Gui
    end
end

EnsureGuis = function()
    for Name, Parent in pairs(ValidGuis) do
        local Gui = ScreenGuis[Name]
        if not Gui or Gui.Parent ~= Parent then
            CreateGuis()
            return
        end
    end
end

local function MakeDraggable(Frame, DragHandle)
    DragHandle = DragHandle or Frame

    local Dragging = false
    local DragStart = nil
    local StartPosition = nil
    local TargetPosition = nil

    local function Lerp(A, B, T)
        return A + (B - A) * T
    end

    DragHandle.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1
        or Input.UserInputType == Enum.UserInputType.Touch then
            Dragging = true
            DragStart = Input.Position
            StartPosition = Frame.Position
            TargetPosition = StartPosition

            Input.Changed:Connect(function()
                if Input.UserInputState == Enum.UserInputState.End then
                    Dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(Input)
        if Dragging and (
            Input.UserInputType == Enum.UserInputType.MouseMovement
            or Input.UserInputType == Enum.UserInputType.Touch
        ) then
            local Delta = Input.Position - DragStart

            TargetPosition = UDim2.new(
                StartPosition.X.Scale,
                StartPosition.X.Offset + Delta.X,
                StartPosition.Y.Scale,
                StartPosition.Y.Offset + Delta.Y
            )
        end
    end)

    RunService.RenderStepped:Connect(function()
        if TargetPosition then
            local Current = Frame.Position

            Frame.Position = UDim2.new(
                Lerp(Current.X.Scale, TargetPosition.X.Scale, 0.2),
                Lerp(Current.X.Offset, TargetPosition.X.Offset, 0.2),
                Lerp(Current.Y.Scale, TargetPosition.Y.Scale, 0.2),
                Lerp(Current.Y.Offset, TargetPosition.Y.Offset, 0.2)
            )
        end
    end)
end

function Library:ToggleWindow(Window, Value)
    local Frame = Window.MainFrame

    Window.Open = Window.Open or false

    local NewState = Value
    if Value == nil then
        NewState = not Window.Open
    end

    if NewState == Window.Open then
        return
    end

    Window.Open = NewState

    local Duration = 0.22

    local ShowTweenInformation = TweenInfo.new(
        Duration,
        Enum.EasingStyle.Sine,
        Enum.EasingDirection.Out
    )

    local HideTweenInformation = TweenInfo.new(
        Duration,
        Enum.EasingStyle.Sine,
        Enum.EasingDirection.In
    )

    if not Window.UIScale then
        local UIScale = Instance.new("UIScale")
        UIScale.Scale = 1
        UIScale.Parent = Frame
        Window.UIScale = UIScale
    end

    if NewState then
        Frame.Visible = true
        Window.UIScale.Scale = 0.95

        TweenService:Create(
            Window.UIScale,
            ShowTweenInformation,
            {Scale = 1}
        ):Play()
    else
        local HideTween = TweenService:Create(
            Window.UIScale,
            HideTweenInformation,
            {Scale = 0.95}
        )

        HideTween:Play()

        task.delay(Duration, function()
            if not Window.Open then
                Frame.Visible = false
            end
        end)
    end
end

function Library:GetTheme(Key)
    local Theme = Themes[self.CurrentTheme] or Themes.Dark
    return Theme[Key]
end

function Library:SetTheme(ThemeName)
    if not Themes[ThemeName] then
        return
    end

    self.CurrentTheme = ThemeName
    self.NotificationSystem.CurrentTheme = ThemeName

    local Path = "RiseV6UI/.style"
    FileManager:CreateFolder("RiseV6UI")

    local AccentName = self.CurrentAccent or "Blue"

    if FileManager:IsFile(Path) then
        local Data = FileManager:ReadFile(Path)
        local SavedAccent = Data:match('Accent%s*=%s*"(.-)"')
        if SavedAccent then
            AccentName = SavedAccent
        end
    end

    local Data =
        'Theme = "' .. tostring(ThemeName) .. '"\n' ..
        'Accent = "' .. tostring(AccentName) .. '"'

    FileManager:WriteFile(Path, Data)

    for i = 1, #self.ThemeObjects do
        local ObjectData = self.ThemeObjects[i]
        local Object = ObjectData.Object
        local Property = ObjectData.Property
        local Key = ObjectData.Key

        if Object and Object.Parent then
            local Value = self:GetTheme(Key)

            TweenService:Create(
                Object,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { [Property] = Value }
            ):Play()
        end
    end
end

function Library:TrackTheme(Object, Property, Key)
    table.insert(self.ThemeObjects, {
        Object = Object,
        Property = Property,
        Key = Key
    })

    local Color = self:GetTheme(Key)

    if typeof(Object) == "table" and Object.SetColor then
        Object:SetColor(Color)
    else
        Object[Property] = Color
    end
end

function Library:GetAccent(Key)
    local Accent = Accents[self.CurrentAccent] or Accents.Blue
    return Accent[Key]
end

function Library:SetAccent(AccentName)
    if not Accents[AccentName] then
        return
    end

    self.CurrentAccent = AccentName

    local Path = "RiseV6UI/.style"
    FileManager:CreateFolder("RiseV6UI")

    local ThemeName = self.CurrentTheme or "Dark"

    if FileManager:IsFile(Path) then
        local Data = FileManager:ReadFile(Path)
        local SavedTheme = Data:match('Theme%s*=%s*"(.-)"')
        if SavedTheme then
            ThemeName = SavedTheme
        end
    end

    local Data =
        'Theme = "' .. tostring(ThemeName) .. '"\n' ..
        'Accent = "' .. tostring(AccentName) .. '"'

    FileManager:WriteFile(Path, Data)

    for i = 1, #self.AccentObjects do
        local ObjectData = self.AccentObjects[i]
        local Object = ObjectData.Object
        local Property = ObjectData.Property
        local Key = ObjectData.Key

        local Value = self:GetAccent(Key)

        if typeof(Object) == "table" and typeof(Object.SetColor) == "function" then
            Object:SetColor(Value)
        elseif Object and Object.Parent and Property then
            TweenService:Create(
                Object,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { [Property] = Value }
            ):Play()
        end
    end
end

function Library:TrackAccent(Object, Property, Key)
    table.insert(self.AccentObjects, {
        Object = Object,
        Property = Property,
        Key = Key
    })

    local Color = self:GetAccent(Key)

    if typeof(Object) == "table" and Object.SetColor then
        Object:SetColor(Color)
    else
        Object[Property] = Color
    end
end

function Library:Untrack(Object, Property)
    for i = #self.ThemeObjects, 1, -1 do
        local v = self.ThemeObjects[i]
        if v.Object == Object and v.Property == Property then
            table.remove(self.ThemeObjects, i)
        end
    end

    for i = #self.AccentObjects, 1, -1 do
        local v = self.AccentObjects[i]
        if v.Object == Object and v.Property == Property then
            table.remove(self.AccentObjects, i)
        end
    end
end

function Library:SaveStyle()
    local Path = "RiseV6UI/.style"

    FileManager:CreateFolder("RiseV6UI")

    local Data =
        'Theme = "' .. tostring(self.CurrentTheme or "Dark") .. '"\n' ..
        'Accent = "' .. tostring(self.CurrentAccent or "Blue") .. '"'

    FileManager:WriteFile(Path, Data)
end

function Library:LoadStyle()
    local Path = "RiseV6UI/.style"

    if not FileManager:IsFile(Path) then
        return
    end

    local Data = FileManager:ReadFile(Path)

    local Theme = Data:match('Theme%s*=%s*"(.-)"')
    local Accent = Data:match('Accent%s*=%s*"(.-)"')

    if Theme and Themes[Theme] then
        self.CurrentTheme = Theme
    end

    if Accent and Accents[Accent] then
        self.CurrentAccent = Accent
    end

    for i = 1, #self.ThemeObjects do
        local ObjectData = self.ThemeObjects[i]
        local Object = ObjectData.Object
        local Property = ObjectData.Property
        local Key = ObjectData.Key

        if Object and Object.Parent then
            local Value = self:GetTheme(Key)
            Object[Property] = Value
        end
    end

    for i = 1, #self.AccentObjects do
        local ObjectData = self.AccentObjects[i]
        local Object = ObjectData.Object
        local Property = ObjectData.Property
        local Key = ObjectData.Key

        local Value = self:GetAccent(Key)

        if typeof(Object) == "table" and typeof(Object.SetColor) == "function" then
            Object:SetColor(Value)
        elseif Object and Object.Parent and Property then
            Object[Property] = Value
        end
    end
end

function Library:InitStyle()
    local Path = "RiseV6UI/.style"

    if FileManager:IsFile(Path) then
        self:LoadStyle()
    else
        self.CurrentTheme = "Dark"
        self.CurrentAccent = "Blue"
        self:SaveStyle()
    end
end

Library:InitStyle()

function Library:DisableAllToggles()
    if not self.ToggleMap then return end
    for _, Toggle in pairs(self.ToggleMap) do
        if Toggle.Enabled then
            Toggle:Set(false)
        end
    end
end

function Library:DisableAllModules()
    self:DisableAllToggles()
    for Flag, Module in pairs(self.Modules) do
        Module:SetEnabled(false)
        self.Flags[Flag] = false
    end
end

getgenv().LibraryInstance = Library

local NewCClosure = (typeof(getnewcclosure) == "function" and getnewcclosure) or function(Fn) return Fn end

do
    local RenderSteppedConnection
    local HeartbeatConnection

    function Library:RenderStepped(Callback)
        if RenderSteppedConnection then
            RenderSteppedConnection:Disconnect()
        end
        RenderSteppedConnection = RunService.RenderStepped:Connect(NewCClosure(Callback))
        return RenderSteppedConnection
    end

    function Library:Heartbeat(Callback)
        if HeartbeatConnection then
            HeartbeatConnection:Disconnect()
        end
        HeartbeatConnection = RunService.Heartbeat:Connect(NewCClosure(Callback))
        return HeartbeatConnection
    end

    function Library:StopRuntime()
        if RenderSteppedConnection then
            RenderSteppedConnection:Disconnect()
            RenderSteppedConnection = nil
        end
        if HeartbeatConnection then
            HeartbeatConnection:Disconnect()
            HeartbeatConnection = nil
        end
    end
end

local function AttachShadow(TargetInstance, CornerRadius, LayerCount, MaxSpread, Gamma, ShadowColor, Alpha)
    Alpha = math.clamp(Alpha or 1, 0, 1)
    LayerCount = math.max(LayerCount or 1, 1)

    local Parent = TargetInstance.Parent
    if not Parent then return end

    local InnerAlpha = 0.9
    local OuterAlpha = 0.97

    local ShadowLayers = {}
    local Connections = {}

    local LastPos = Vector2.new(-1, -1)
    local LastSize = Vector2.new(-1, -1)
    local LastUpdate = 0
    local UpdateRate = 1 / 30

    for LayerIndex = 1, LayerCount do
        local T = LayerCount == 1 and 0 or (LayerIndex - 1) / (LayerCount - 1)
        local Spread = math.floor(T * MaxSpread + 0.5)

        local BaseTransparency = InnerAlpha + (OuterAlpha - InnerAlpha) * (T ^ Gamma)
        local Transparency = BaseTransparency + (1 - BaseTransparency) * (1 - Alpha)

        local Frame = Instance.new("Frame")
        Frame.BackgroundColor3 = ShadowColor
        Frame.BackgroundTransparency = Transparency
        Frame.BorderSizePixel = 0
        Frame.ZIndex = TargetInstance.ZIndex - 1
        Frame.Parent = Parent

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, CornerRadius + Spread)
        Corner.Parent = Frame

        ShadowLayers[#ShadowLayers + 1] = {
            Frame = Frame,
            Spread = Spread,
            BaseTransparency = BaseTransparency
        }
    end

    local function SyncShadow()
        if not TargetInstance.Parent then return end
        if not TargetInstance.Visible then return end

        local Now = tick()
        if Now - LastUpdate < UpdateRate then return end
        LastUpdate = Now

        local AbsPos = TargetInstance.AbsolutePosition
        local ParentAbsPos = Parent.AbsolutePosition

        local RelativeX = AbsPos.X - ParentAbsPos.X
        local RelativeY = AbsPos.Y - ParentAbsPos.Y
        local AbsSize = TargetInstance.AbsoluteSize

        if AbsPos.X == LastPos.X and AbsPos.Y == LastPos.Y
        and AbsSize.X == LastSize.X and AbsSize.Y == LastSize.Y then
            return
        end

        LastPos = AbsPos
        LastSize = AbsSize

        for _, Layer in ipairs(ShadowLayers) do
            local Spread = Layer.Spread
            local Frame = Layer.Frame

            Frame.Position = UDim2.fromOffset(
                RelativeX - Spread,
                RelativeY - Spread
            )

            Frame.Size = UDim2.fromOffset(
                AbsSize.X + Spread * 2,
                AbsSize.Y + Spread * 2
            )
        end
    end

    local function SetShadowVisible(State)
        for _, Layer in ipairs(ShadowLayers) do
            Layer.Frame.Visible = State
        end
    end

    local function TweenShadow(TargetAlpha)
        for _, Layer in ipairs(ShadowLayers) do
            local Base = Layer.BaseTransparency
            local GoalTransparency =
                Base + (1 - Base) * (1 - TargetAlpha)

            TweenService:Create(
                Layer.Frame,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {BackgroundTransparency = GoalTransparency}
            ):Play()
        end
    end

    if TargetInstance.Visible then
        SetShadowVisible(true)
        TweenShadow(Alpha, 0)
    else
        SetShadowVisible(false)
    end

    Connections[#Connections + 1] = RunService.RenderStepped:Connect(SyncShadow)

    Connections[#Connections + 1] = TargetInstance.AncestryChanged:Connect(function(_, ParentNow)
        if ParentNow then return end

        for _, Connection in ipairs(Connections) do
            Connection:Disconnect()
        end

        for _, Layer in ipairs(ShadowLayers) do
            Layer.Frame:Destroy()
        end
    end)

    local Shadow = {}
    Shadow.Alpha = Alpha
    Shadow.Color = ShadowColor

    Connections[#Connections + 1] = TargetInstance:GetPropertyChangedSignal("Visible"):Connect(function()
        if TargetInstance.Visible then
            SetShadowVisible(true)
            TweenShadow(Shadow.Alpha, 0.2)
        else
            TweenShadow(0, 0.15)
            task.delay(0.15, function()
                if not TargetInstance.Visible then
                    SetShadowVisible(false)
                end
            end)
        end
    end)

    function Shadow:SetAlpha(Value)
        self.Alpha = math.clamp(Value or 1, 0, 1)

        for _, Layer in ipairs(ShadowLayers) do
            local Base = Layer.BaseTransparency
            Layer.Frame.BackgroundTransparency =
                Base + (1 - Base) * (1 - self.Alpha)
        end
    end

    function Shadow:SetColor(Color)
        self.Color = Color

        for _, Layer in ipairs(ShadowLayers) do
            Layer.Frame.BackgroundColor3 = Color
        end
    end

    function Shadow:Destroy()
        for _, Connection in ipairs(Connections) do
            Connection:Disconnect()
        end

        for _, Layer in ipairs(ShadowLayers) do
            Layer.Frame:Destroy()
        end
    end

    return Shadow
end

function AttachTextShadow(TextLabel, ShadowOffset, ShadowColor, ShadowTransparency, LayerCount, ZIndexOffset)
    local Offset = ShadowOffset or Vector2.new(1, 1)
    local Color = ShadowColor or Color3.fromRGB(0, 0, 0)
    local Transparency = ShadowTransparency or 0.35
    local Layers = LayerCount or 2
    local ZOffset = ZIndexOffset or -1

    local ShadowLayers = {}
    local Connections = {}

    for Index = 1, Layers do
        local Shadow = TextLabel:Clone()
        Shadow.Name = "TextShadow_" .. Index
        Shadow.Parent = TextLabel.Parent
        Shadow.BackgroundTransparency = 1
        Shadow.TextColor3 = Color
        Shadow.TextTransparency = math.clamp(Transparency + (Index * 0.08), 0, 1)
        Shadow.ZIndex = TextLabel.ZIndex + ZOffset - Index
        Shadow.TextStrokeTransparency = 1

        ShadowLayers[Index] = Shadow
    end

    local function Sync()
        local BasePosition = TextLabel.Position
        local BaseSize = TextLabel.Size
        local BaseText = TextLabel.Text

        for Index, Shadow in ipairs(ShadowLayers) do
            local LayerOffset = Offset * Index

            Shadow.Position = BasePosition + UDim2.fromOffset(LayerOffset.X, LayerOffset.Y)
            Shadow.Size = BaseSize

            Shadow.Text = BaseText
            Shadow.TextSize = TextLabel.TextSize
            Shadow.FontFace = TextLabel.FontFace

            Shadow.TextXAlignment = TextLabel.TextXAlignment
            Shadow.TextYAlignment = TextLabel.TextYAlignment
            Shadow.Visible = TextLabel.Visible
        end
    end

    Sync()

    local function Bind(Property)
        Connections[#Connections + 1] = TextLabel:GetPropertyChangedSignal(Property):Connect(Sync)
    end

    Bind("Position")
    Bind("Size")
    Bind("Text")
    Bind("TextSize")
    Bind("FontFace")
    Bind("Visible")

    local Controller = {}

    function Controller:SetEnabled(State)
        for _, Shadow in ipairs(ShadowLayers) do
            Shadow.Visible = State == true
        end
    end

    function Controller:SetColor(NewColor)
        Color = NewColor or Color
        for _, Shadow in ipairs(ShadowLayers) do
            Shadow.TextColor3 = Color
        end
    end

    function Controller:SetTransparency(Value)
        Transparency = tonumber(Value) or Transparency
        for Index, Shadow in ipairs(ShadowLayers) do
            Shadow.TextTransparency = math.clamp(Transparency + (Index * 0.08), 0, 1)
        end
    end

    function Controller:SetOffset(NewOffset)
        Offset = NewOffset or Offset
        Sync()
    end

    function Controller:Destroy()
        for _, Connection in ipairs(Connections) do
            Connection:Disconnect()
        end
        for _, Shadow in ipairs(ShadowLayers) do
            Shadow:Destroy()
        end
    end

    return Controller
end

function Library:CreateWindow(Options)
    Options = Options or {}
    local Name = Options.Name or "Window"

    EnsureGuis()

    if self.Window then
        return self.Window
    end

    local Window = {}
    Window.Tabs = {}

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = Name
    MainFrame.Size = UDim2.new(0, 700, 0, 550)
    MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGuis.PerseusUI
    MainFrame.Visible = true

    self:TrackTheme(MainFrame, "BackgroundColor3", "Background")

    local SizeConstraint = Instance.new("UISizeConstraint")
    SizeConstraint.MaxSize = Vector2.new(700, 550)
    SizeConstraint.MinSize = Vector2.new(350, 350)
    SizeConstraint.Parent = MainFrame

    MakeDraggable(MainFrame, MainFrame)

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 16)
    Corner.Parent = MainFrame

    AttachShadow(MainFrame, 16, 5, 12, 2.2, Color3.fromRGB(0, 0, 0), self:GetTheme("ShadowAlpha"))

    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, -130, 0, 40)
    TopBar.Position = UDim2.new(0, 130, 0, 0)
    TopBar.BackgroundTransparency = 1
    TopBar.BorderSizePixel = 0
    TopBar.ZIndex = 2
    TopBar.Parent = MainFrame

    local TabTitle = Instance.new("TextLabel")
    TabTitle.Name = "TabTitle"
    TabTitle.Size = UDim2.new(1, 0, 1, 0)
    TabTitle.Position = UDim2.new(0, 0, 0, 0)
    TabTitle.BackgroundTransparency = 1
    TabTitle.TextSize = 24
    TabTitle.ZIndex = 2
    TabTitle.TextXAlignment = Enum.TextXAlignment.Left
    TabTitle.Parent = TopBar

    self:TrackTheme(TabTitle, "TextColor3", "Text")

    pcall(function() TabTitle.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)

    local Padding = Instance.new("UIPadding")
    Padding.PaddingLeft = UDim.new(0, 12)
    Padding.PaddingTop = UDim.new(0, 8)
    Padding.Parent = TabTitle

    local SideBar = Instance.new("Frame")
    SideBar.Name = "SideBar"
    SideBar.Size = UDim2.new(0, 140, 1, 0)
    SideBar.Position = UDim2.new(0, 0, 0, 0)
    SideBar.BorderSizePixel = 0
    SideBar.ClipsDescendants = true
    SideBar.Parent = MainFrame

    self:TrackTheme(SideBar, "BackgroundColor3", "SideBar")

    local SideCorner = Instance.new("UICorner")
    SideCorner.CornerRadius = UDim.new(0, 16)
    SideCorner.Parent = SideBar

    local SideMask = Instance.new("Frame")
    SideMask.Size = UDim2.new(0, 8, 1, 0)
    SideMask.Position = UDim2.new(1, -8, 0, 0)
    SideMask.BorderSizePixel = 0
    SideMask.Parent = SideBar

    self:TrackTheme(SideMask, "BackgroundColor3", "Background")

    local TitleHolder = Instance.new("TextLabel")
    TitleHolder.Name = "TitleHolder"
    TitleHolder.Size = UDim2.new(1, -16, 0, 36)
    TitleHolder.Position = UDim2.new(0, 4, 0, 8)
    TitleHolder.BackgroundTransparency = 1
    TitleHolder.Text = Name
    TitleHolder.TextSize = 30
    TitleHolder.Parent = SideBar
    pcall(function() TitleHolder.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)

    Window.TitleHolder = TitleHolder

    self:TrackTheme(TitleHolder, "TextColor3", "Text")

    AttachTextShadow(TitleHolder, Vector2.new(1.2, 1.2), Color3.fromRGB(0, 0, 0), self:GetTheme("ShadowAlpha"), 2, -1)

    local TabHolder = Instance.new("ScrollingFrame")
    TabHolder.Name = "TabHolder"
    TabHolder.Size = UDim2.new(1, -24, 1, -40)
    TabHolder.Position = UDim2.new(0, 16, 0, 40)
    TabHolder.BackgroundTransparency = 1
    TabHolder.BorderSizePixel = 0
    TabHolder.ScrollBarThickness = 0
    TabHolder.ScrollBarImageTransparency = 1
    TabHolder.ScrollingDirection = Enum.ScrollingDirection.Y
    TabHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
    TabHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
    TabHolder.Active = true
    TabHolder.Parent = SideBar

    local Layout = Instance.new("UIListLayout")
    Layout.FillDirection = Enum.FillDirection.Vertical
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Padding = UDim.new(0, 0)
    Layout.Parent = TabHolder

    Window.MainFrame = MainFrame
    Window.SideBar = SideBar
    Window.TitleHolder = TitleHolder
    Window.TabHolder = TabHolder
    Window.Theme = self.CurrentTheme 
    Window.Open = true

    Window.ActiveTab = nil
    Window.TabTitle = TabTitle

    function Window:AddTab(Config)
        return Library:AddTab(self, Config)
    end

    self.Window = Window

    return Window
end

function Library:SetTitle(NewName)
    if self.Window and self.Window.TitleHolder then
        self.Window.TitleHolder.Text = tostring(NewName or "")
    end
end

function Library:AddTab(Window, Config)
    Config = Config or {}

    local TabName = Config.Name or Config.Title or "Tab"
    local Icon = Config.Icon

    local Tab = {}

    local Button = Instance.new("TextButton")
    Button.Name = TabName
    Button.Size = UDim2.new(0, 0, 0, 40)
    Button.Text = ""
    Button.BackgroundTransparency = 1
    Button.ZIndex = 1
    Button.AutomaticSize = Enum.AutomaticSize.X

    local Order = #Window.Tabs + 1

    if TabName == "Configs" then
        Order = 9999
    elseif TabName == "Style" then
        Order = 9998
    end

    Button.LayoutOrder = Order
    Button.Parent = Window.TabHolder

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = TabName
    Label.TextSize = 18
    Label.ZIndex = 4
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.AutomaticSize = Enum.AutomaticSize.X
    pcall(function() Label.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    Label.Parent = Button

    self:TrackTheme(Label, "TextColor3", "Text")

    local Padding = Instance.new("UIPadding")
    Padding.PaddingLeft = UDim.new(0, 28)
    Padding.Parent = Button

    local IconImage = Instance.new("ImageLabel")
    IconImage.Name = "Icon"
    IconImage.Size = UDim2.new(0, 16, 0, 16)
    IconImage.Position = UDim2.new(0, -20, 0.5, -8)
    IconImage.BackgroundTransparency = 1
    IconImage.Image = typeof(Icon) == "string" and Icon or ""
    IconImage.ZIndex = 4
    IconImage.Parent = Button

    self:TrackTheme(IconImage, "ImageColor3", "Text")

    local Content = Instance.new("ScrollingFrame")
    Content.Name = TabName .. "_Content"
    Content.Size = UDim2.new(1, -130, 1, -40)
    Content.Position = UDim2.new(0, 130, 0, 40)
    Content.BackgroundTransparency = 1
    Content.Visible = false
    Content.Parent = Window.MainFrame

    Content.CanvasSize = UDim2.new(0, 0, 0, 0)
    Content.ScrollBarThickness = 0
    Content.ScrollingDirection = Enum.ScrollingDirection.Y
    Content.AutomaticCanvasSize = Enum.AutomaticSize.None
    Content.ScrollBarImageTransparency = 1

    local Layout = Instance.new("UIListLayout")
    Layout.FillDirection = Enum.FillDirection.Vertical
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Padding = UDim.new(0, 4)
    Layout.Parent = Content

    local function UpdateCanvas()
        local ContentHeight = Layout.AbsoluteContentSize.Y + 10

        Content.CanvasSize = UDim2.new(0, 0, 0, ContentHeight)

        if ContentHeight > Content.AbsoluteSize.Y then
            Content.ScrollingEnabled = true
        else
            Content.ScrollingEnabled = false
            Content.CanvasPosition = Vector2.new(0, 0)
        end
    end

    Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)
    Content:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateCanvas)
    task.defer(UpdateCanvas)

    local LayoutPadding = Instance.new("UIPadding")
    LayoutPadding.PaddingLeft = UDim.new(0, 8)
    LayoutPadding.PaddingTop = UDim.new(0, 10)
    LayoutPadding.Parent = Content

    if not Window.TabSelector then
        local Selector = Instance.new("Frame")
        Selector.Name = "TabSelector"
        Selector.BorderSizePixel = 0
        Selector.ZIndex = 3
        Selector.Parent = Window.SideBar

        self:TrackAccent(Selector, "BackgroundColor3", "Accent")

        local Shadow = AttachShadow(Selector, 10, 10, 9, 1.8, self:GetAccent("Accent"), 0.65)

        self:TrackAccent(Shadow, nil, "Accent")

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 10)
        Corner.Parent = Selector

        Window.TabSelector = Selector

        -- Keep the selector pill synced when the tab list is scrolled
        Window.TabHolder:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
            if not Window.ActiveTab then return end
            local ActiveButton = Window.ActiveTab.Button
            local NewY = ActiveButton.AbsolutePosition.Y - Window.SideBar.AbsolutePosition.Y
            local NewX = ActiveButton.AbsolutePosition.X - Window.SideBar.AbsolutePosition.X
            local Extra = 8
            Window.TabSelector.Position = UDim2.new(0, NewX, 0, NewY + 6)
            Window.TabSelector.Size = UDim2.new(0, ActiveButton.AbsoluteSize.X + Extra, 0, 28)
        end)
    end

    Tab.Button = Button
    Tab.Content = Content
    Tab.Icon = IconImage

    local Hovering = false

    local HoverTweenIn = TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local HoverTweenOut = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    local function ApplyHover()
        if Window.ActiveTab == Tab then
            TweenService:Create(Padding, HoverTweenOut, {
                PaddingLeft = UDim.new(0, 28)
            }):Play()

            TweenService:Create(Button, HoverTweenOut, {
                TextTransparency = 0
            }):Play()

            TweenService:Create(IconImage, HoverTweenOut, {
                ImageTransparency = 0
            }):Play()
            return
        end

        if Hovering then
            TweenService:Create(Padding, HoverTweenIn, {
                PaddingLeft = UDim.new(0, 34)
            }):Play()

            TweenService:Create(Button, HoverTweenIn, {
                TextTransparency = 0.1
            }):Play()

            TweenService:Create(IconImage, HoverTweenIn, {
                ImageTransparency = 0.1
            }):Play()
        else
            TweenService:Create(Padding, HoverTweenOut, {
                PaddingLeft = UDim.new(0, 28)
            }):Play()

            TweenService:Create(Button, HoverTweenOut, {
                TextTransparency = 0
            }):Play()

            TweenService:Create(IconImage, HoverTweenOut, {
                ImageTransparency = 0
            }):Play()
        end
    end

    Button.MouseEnter:Connect(function()
        Hovering = true
        ApplyHover()
    end)

    Button.MouseLeave:Connect(function()
        Hovering = false
        ApplyHover()
    end)

    local Switching = false

    local function SelectTab()
        if Window.ActiveTab == Tab or Switching then return end
        Switching = true

        local PreviousTab = Window.ActiveTab

        RunService.RenderStepped:Wait()

        Padding.PaddingLeft = UDim.new(0, 28)

        RunService.RenderStepped:Wait()

        local BasePadding = 28
        local HoverPadding = 36
        local Extra = HoverPadding - BasePadding

        local SelectorTargetOffsetX = Button.AbsolutePosition.X - Window.SideBar.AbsolutePosition.X
        local SelectorTargetOffsetY = Button.AbsolutePosition.Y - Window.SideBar.AbsolutePosition.Y
        local SelectorTargetWidth = Button.AbsoluteSize.X + Extra

        TweenService:Create(
            Window.TabSelector,
            TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {
                Position = UDim2.new(0, SelectorTargetOffsetX, 0, SelectorTargetOffsetY + 6),
                Size = UDim2.new(0, SelectorTargetWidth, 0, 28)
            }
        ):Play()

        Window.ActiveTab = Tab
        ApplyHover()

        Window.TabTitle.Text = TabName

        Window.MainFrame.ClipsDescendants = true

        if PreviousTab and PreviousTab.Content.Visible then
            PreviousTab.Content.Active = false

            local ExitContentTween = TweenService:Create(
                PreviousTab.Content,
                TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
                {
                    Position = UDim2.new(0, 130, 0, -40)
                }
            )

            ExitContentTween:Play()

            task.wait(0.12)

            PreviousTab.Content.Visible = false
        end

        Content.Visible = true
        Content.Active = true
        Content.Position = UDim2.new(0, 130, 0, 80)
        Content.CanvasPosition = Vector2.new(0, 0)

        local EnterContentTween = TweenService:Create(
            Content,
            TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {
                Position = UDim2.new(0, 130, 0, 40)
            }
        )

        EnterContentTween:Play()
        EnterContentTween.Completed:Wait()

        Switching = false
    end

    Tab.Select = SelectTab

    Button.MouseButton1Click:Connect(SelectTab)

    table.insert(Window.Tabs, Tab)

    if Window.HasSelectedFirst == nil then
        Window.HasSelectedFirst = false
    end

    task.defer(function()
        if Window.HasSelectedFirst then return end
        Window.HasSelectedFirst = true

        local BestTab = nil
        local LowestOrder = math.huge

        for _, TabObj in ipairs(Window.Tabs) do
            local Order = TabObj.Button.LayoutOrder or 0

            if Order < LowestOrder then
                LowestOrder = Order
                BestTab = TabObj
            end
        end

        if BestTab then
            BestTab.Select()
        end
    end)

    function Tab:AddModule(ModuleConfig)
        return Library:AddModule(self, ModuleConfig)
    end

    function Tab:AddParagraph(ParagraphConfig)
        return Library:AddParagraph(self, ParagraphConfig)
    end

    function Tab:AddRadar(ModuleConfig)
        return Library:AddRadar(self, ModuleConfig)
    end

    function Tab:AddThemes(ThemesConfig)
        return Library:AddThemes(self, ThemesConfig)
    end

    function Tab:AddAccents(AccentsConfig)
        return Library:AddAccents(self, AccentsConfig)
    end

    function Tab:AddConfig(Config)
        return Library:AddConfig(self, Config)
    end

    return Tab
end

function Library:AddModule(Tab, Config)
    Config = Config or {}

    local Name = Config.Name or "Module"
    local Flag = Config.Flag or Name:gsub("%s+", "")
    local ToolTipText = Config.ToolTip
    local UpdateInterval = Config.UpdateInterval or 0.1

    local Module = {
        Name = Name,
        Flag = Flag,
        Enabled = false,
        Expanded = false
    }

    Library.Modules[Flag] = Module
    Library.Flags[Flag] = false

    local Holder = Instance.new("Frame")
    Holder.Size = UDim2.new(1, -8, 0, 40)
    Holder.BorderSizePixel = 0
    Holder.BackgroundTransparency = 0
    Holder.Parent = Tab.Content

    self:TrackTheme(Holder, "BackgroundColor3", "SideBar")

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = Holder

    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, 0, 0, 40)
    Button.BackgroundTransparency = 1
    Button.Text = ""
    Button.ZIndex = 2
    Button.Parent = Holder

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0, 0, 0, 40)
    Label.BackgroundTransparency = 1
    Label.Text = Name
    Label.TextSize = 20
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.AutomaticSize = Enum.AutomaticSize.X
    pcall(function() Label.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    Label.Parent = Button

    Library:TrackTheme(Label, "TextColor3", "Text")

    local Padding = Instance.new("UIPadding")
    Padding.PaddingLeft = UDim.new(0, 10)
    Padding.Parent = Label

    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, -8, 0, 0)
    Container.Position = UDim2.new(0, 0, 0, 32)
    Container.BackgroundTransparency = 1
    Container.ClipsDescendants = true

    Container.Visible = false
    Container.Parent = Holder

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 4)
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Parent = Container

    Module.Container = Container
    Module.Button = Button
    Module.Holder = Holder

    local function UpdateVisual()
        Library:Untrack(Label, "TextColor3")

        if Module.Enabled then
            Library:TrackAccent(Label, "TextColor3", "Accent")
        else
            Library:TrackTheme(Label, "TextColor3", "Text")
        end
    end

    function Module:SetEnabled(State)
        if self.Enabled == State then return end
        self.Enabled = State

        Library.Flags[self.Flag] = State

        UpdateVisual()

        if State then
            if Config.OnEnabled then
                task.spawn(Config.OnEnabled)
            end

            if Config.OnUpdate then
                task.spawn(function()
                    while Module.Enabled do
                        Config.OnUpdate()
                        task.wait(UpdateInterval)
                    end
                end)
            end
        else
            if Config.OnDisabled then
                task.spawn(Config.OnDisabled)
            end
        end
    end

    local function UpdateSize()
        local ExtraPadding = Module.Expanded and 8 or 0
        local TargetSizeY = Module.Expanded and (Layout.AbsoluteContentSize.Y + ExtraPadding) or 0

        if Module.Expanded then
            Container.Visible = true
        end

        local Tween = TweenService:Create(
            Container,
            TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {
                Size = UDim2.new(1, -8, 0, TargetSizeY)
            }
        )

        Tween:Play()

        if not Module.Expanded then
            Tween.Completed:Connect(function()
                Container.Visible = false
            end)
        end
    end

    function Module:SetExpanded(State)
        if self.Expanded == State then return end
        self.Expanded = State
        UpdateSize()
    end

    Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateSize)

    Button.MouseButton1Click:Connect(function()
        Module:SetEnabled(not Module.Enabled)
    end)

    Button.MouseButton2Click:Connect(function()
        if Layout.AbsoluteContentSize.Y <= 0 then return end
        Module:SetExpanded(not Module.Expanded)
    end)

    local BaseHolderHeight = 40

    Container:GetPropertyChangedSignal("Size"):Connect(function()
        Holder.Size = UDim2.new(1, -8, 0, BaseHolderHeight + Container.Size.Y.Offset)
    end)

    if ToolTipText then
        -- Expand the holder and button to fit the tooltip row below the name
        BaseHolderHeight = 58
        Holder.Size = UDim2.new(1, -8, 0, 58)
        Button.Size = UDim2.new(1, 0, 0, 58)

        local ToolTipLabel = Instance.new("TextLabel")
        ToolTipLabel.BackgroundTransparency = 1
        ToolTipLabel.Text = ToolTipText
        ToolTipLabel.TextSize = 13
        ToolTipLabel.Visible = true
        ToolTipLabel.TextTransparency = 0.35
        ToolTipLabel.Size = UDim2.new(1, -20, 0, 18)
        ToolTipLabel.Position = UDim2.new(0, 10, 0, 34)
        ToolTipLabel.TextXAlignment = Enum.TextXAlignment.Left
        ToolTipLabel.TextTruncate = Enum.TextTruncate.AtEnd
        ToolTipLabel.Parent = Holder
        pcall(function() ToolTipLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Regular, Enum.FontStyle.Normal) end)

        self:TrackTheme(ToolTipLabel, "TextColor3", "Text")

        -- Keep Container offset below the expanded header
        Container.Position = UDim2.new(0, 0, 0, 50)
    end

    UpdateVisual()

    function Module:AddLabel(Config)
        return Library:AddLabel(self, Config)
    end

    function Module:AddToggle(Config)
        return Library:AddToggle(self, Config)
    end

    function Module:AddSlider(Config)
        return Library:AddSlider(self, Config)
    end

    function Module:AddCarousel(Config)
        return Library:AddCarousel(self, Config)
    end

    function Module:AddKeybind(Config)
        return Library:AddKeybind(self, Config)
    end

    function Module:AddButton(Config)
        return Library:AddButton(self, Config)
    end

    function Module:AddColorPicker(Config)
        return Library:AddColorPicker(self, Config)
    end

    function Module:AddDropdown(Config)
        return Library:AddDropdown(self, Config)
    end

    function Module:AddDropdownMultiSelect(Config)
        return Library:AddDropdownMultiSelect(self, Config)
    end

    function Module:AddTextBox(Config)
        return Library:AddTextBox(self, Config)
    end

    function Module:AddSection(Config)
        return Library:AddSection(self, Config)
    end

    function Module:AddDivider(Config)
        return Library:AddDivider(self, Config)
    end

    function Module:AddProgress(Config)
        return Library:AddProgress(self, Config)
    end

    return Module
end

function Library:AddParagraph(Tab, Config)
    Config = Config or {}

    local function BuildText()
        local Lines = {}

        if Config.Text then
            table.insert(Lines, Config.Text)
        else
            for i = 1, math.huge do
                local Line = Config["Line" .. i]
                if not Line then break end
                table.insert(Lines, Line)
            end
        end

        return table.concat(Lines, "\n")
    end

    local Holder = Instance.new("Frame")
    Holder.Size = UDim2.new(1, -8, 0, 0)
    Holder.BackgroundTransparency = 0
    Holder.BorderSizePixel = 0
    Holder.Parent = Tab.Content

    self:TrackTheme(Holder, "BackgroundColor3", "SideBar")

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = Holder

    local Label = Instance.new("TextLabel")
    Label.BackgroundTransparency = 1
    Label.Size = UDim2.new(1, -12, 0, 0)
    Label.Position = UDim2.new(0, 6, 0, 6)
    Label.AutomaticSize = Enum.AutomaticSize.Y
    Label.TextWrapped = true
    Label.RichText = true
    Label.TextSize = 16
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.TextYAlignment = Enum.TextYAlignment.Top
    pcall(function() Label.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Regular, Enum.FontStyle.Normal) end)
    Label.Parent = Holder

    self:TrackTheme(Label, "TextColor3", "Text")

    local function UpdateSize()
        Holder.Size = UDim2.new(1, -8, 0, Label.AbsoluteSize.Y + 12)
    end

    Label:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateSize)

    local function ApplyText()
        Label.Text = BuildText()
    end

    ApplyText()
    UpdateSize()

    local DynamicText = nil

    local UpdateInterval = Config.UpdateInterval or 0.1

    if Config.OnUpdate then
        task.spawn(function()
            while Label.Parent do
                local Result = Config.OnUpdate(Label)

                if typeof(Result) == "string" then
                    Label.Text = Result
                elseif typeof(Result) == "table" then
                    local Lines = {}
                    for i = 1, math.huge do
                        local Line = Result[i] or Result["Line" .. i]
                        if not Line then break end
                        table.insert(Lines, Line)
                    end
                    Label.Text = table.concat(Lines, "\n")
                else
                    ApplyText()
                end

                task.wait(UpdateInterval)
            end
        end)
    end

    return Label
end

function Library:AddRadar(Tab, Config)
    Config = Config or {}

    EnsureGuis()

    local FrameSize = Config.Size or 200
    local DetectRange = Config.Range or 500
    local DotSize = Config.DotSize or 6
    local ShowNames = Config.ShowNames ~= false
    local ShowSelf = Config.ShowSelf or false
    local ShowGridLines = Config.GridLines ~= false
    local GridDivisions = Config.GridDivs or 4
    local ShowTeammates = Config.ShowTeammates ~= false
    local EnemyColor = Config.EnemyColor or Color3.fromRGB(255, 80, 80)
    local AllyColor = Config.TeamColor or Color3.fromRGB(80, 200, 255)
    local SelfColor = Config.SelfColor or Color3.fromRGB(255, 255, 255)
    local UpdateInterval = Config.UpdateInterval or 0.05
    local CustomPath = Config.CustomPath or nil

    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local RadarFrame = Instance.new("Frame")
    RadarFrame.Size = UDim2.fromOffset(FrameSize, FrameSize)
    RadarFrame.Position = UDim2.fromOffset(20, 20)
    RadarFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    RadarFrame.BackgroundTransparency = 0.15
    RadarFrame.BorderSizePixel = 0
    RadarFrame.ClipsDescendants = true
    RadarFrame.Visible = false
    RadarFrame.Parent = ScreenGuis.PerseusHUD
    self:TrackTheme(RadarFrame, "BackgroundColor3", "Background")
    AttachShadow(RadarFrame, 8, 8, 9, 3.0, Color3.fromRGB(0, 0, 0), 0.6)

    local RadarCorner = Instance.new("UICorner")
    RadarCorner.CornerRadius = UDim.new(0, 8)
    RadarCorner.Parent = RadarFrame

    local CenterDot = Instance.new("Frame")
    CenterDot.Size = UDim2.fromOffset(DotSize, DotSize)
    CenterDot.Position = UDim2.new(0.5, -DotSize / 2, 0.5, -DotSize / 2)
    CenterDot.BackgroundColor3 = SelfColor
    CenterDot.BorderSizePixel = 0
    CenterDot.ZIndex = 10
    CenterDot.Visible = ShowSelf
    CenterDot.Parent = RadarFrame
    Instance.new("UICorner", CenterDot).CornerRadius = UDim.new(1, 0)

    if ShowGridLines then
        for i = 1, GridDivisions - 1 do
            local t = i / GridDivisions

            local HorizontalLine = Instance.new("Frame")
            HorizontalLine.Size = UDim2.new(1, 0, 0, 1)
            HorizontalLine.Position = UDim2.new(0, 0, t, 0)
            HorizontalLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            HorizontalLine.BackgroundTransparency = 0.85
            HorizontalLine.BorderSizePixel = 0
            HorizontalLine.ZIndex = 2
            HorizontalLine.Parent = RadarFrame

            local VerticalLine = Instance.new("Frame")
            VerticalLine.Size = UDim2.new(0, 1, 1, 0)
            VerticalLine.Position = UDim2.new(t, 0, 0, 0)
            VerticalLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            VerticalLine.BackgroundTransparency = 0.85
            VerticalLine.BorderSizePixel = 0
            VerticalLine.ZIndex = 2
            VerticalLine.Parent = RadarFrame
        end

        for _, Axis in ipairs({ "H", "V" }) do
            local CenterLine = Instance.new("Frame")
            CenterLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            CenterLine.BackgroundTransparency = 0.65
            CenterLine.BorderSizePixel = 0
            CenterLine.ZIndex = 3

            if Axis == "H" then
                CenterLine.Size = UDim2.new(1, 0, 0, 1)
                CenterLine.Position = UDim2.new(0, 0, 0.5, 0)
            else
                CenterLine.Size = UDim2.new(0, 1, 1, 0)
                CenterLine.Position = UDim2.new(0.5, 0, 0, 0)
            end

            CenterLine.Parent = RadarFrame
        end
    end

    local RangeLabel = Instance.new("TextLabel")
    RangeLabel.Size = UDim2.new(1, -4, 0, 14)
    RangeLabel.Position = UDim2.new(0, -4, 1, -16)
    RangeLabel.BackgroundTransparency = 1
    RangeLabel.Text = DetectRange .. " studs"
    RangeLabel.TextSize = 12
    RangeLabel.TextTransparency = 0.3
    RangeLabel.TextXAlignment = Enum.TextXAlignment.Right
    pcall(function() RangeLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    RangeLabel.ZIndex = 10
    RangeLabel.Parent = RadarFrame
    self:TrackTheme(RangeLabel, "TextColor3", "Text")

    MakeDraggable(RadarFrame)

    local DotPool = {}

    local function GetDot()
        for _, Dot in ipairs(DotPool) do
            if not Dot.InUse then
                Dot.InUse = true
                Dot.Frame.Visible = true
                return Dot
            end
        end

        local DotFrame = Instance.new("Frame")
        DotFrame.Size = UDim2.fromOffset(DotSize, DotSize)
        DotFrame.BorderSizePixel = 0
        DotFrame.ZIndex = 8
        DotFrame.Parent = RadarFrame
        Instance.new("UICorner", DotFrame).CornerRadius = UDim.new(1, 0)

        local NameLabel = Instance.new("TextLabel")
        NameLabel.BackgroundTransparency = 1
        NameLabel.Size = UDim2.new(0, 60, 0, 12)
        NameLabel.Position = UDim2.fromOffset(DotSize + 2, -2)
        NameLabel.TextSize = 12
        NameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        NameLabel.TextXAlignment = Enum.TextXAlignment.Left
        pcall(function() NameLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
        NameLabel.ZIndex = 9
        NameLabel.Parent = DotFrame

        local Entry = { Frame = DotFrame, NameLabel = NameLabel, InUse = true }
        table.insert(DotPool, Entry)
        return Entry
    end

    local function ReleaseDots()
        for _, Dot in ipairs(DotPool) do
            Dot.InUse = false
            Dot.Frame.Visible = false
        end
    end

    local function RenderRadar()
        local RootPart
        local ResolvedCustomPath = CustomPath and (type(CustomPath) == "function" and CustomPath() or CustomPath) or nil

        if CustomPath then
            local LocalModel = ResolvedCustomPath and ResolvedCustomPath:FindFirstChild(LocalPlayer.Name)
            RootPart = LocalModel and (LocalModel:FindFirstChild("HumanoidRootPart") or LocalModel.PrimaryPart or LocalModel:FindFirstChildWhichIsA("BasePart"))
        else
            RootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        end

        if not RootPart then ReleaseDots() return end

        local Camera = workspace.CurrentCamera
        if not Camera then ReleaseDots() return end

        local LocalPosition = RootPart.Position
        local LocalTeam = LocalPlayer.Team
        local _, CameraAngle, _ = Camera.CFrame:ToEulerAnglesYXZ()

        ReleaseDots()

        if ResolvedCustomPath then
            for _, Model in ipairs(ResolvedCustomPath:GetChildren()) do
                if not Model:IsA("Model") then continue end

                local ModelRootPart = Model:FindFirstChild("HumanoidRootPart") or Model:FindFirstChildWhichIsA("BasePart")
                if not ModelRootPart then continue end

                local Offset = ModelRootPart.Position - LocalPosition
                if Offset.Magnitude > DetectRange then continue end

                local Cos = math.cos(CameraAngle)
                local Sin = math.sin(CameraAngle)

                local RotatedX = Offset.X * Cos - Offset.Z * Sin
                local RotatedZ = Offset.X * Sin + Offset.Z * Cos

                local U = math.clamp(0.5 + (RotatedX / DetectRange) * 0.5, 0.02, 0.98)
                local V = math.clamp(0.5 + (RotatedZ / DetectRange) * 0.5, 0.02, 0.98)

                local Dot = GetDot()

                Dot.Frame.BackgroundColor3 = EnemyColor
                Dot.Frame.Position = UDim2.new(U, -DotSize / 2, V, -DotSize / 2)
                Dot.NameLabel.Visible = ShowNames

                if ShowNames then
                    Dot.NameLabel.Text = Model.Name
                    Dot.NameLabel.TextColor3 = EnemyColor
                end
            end
        else
            for _, Player in ipairs(Players:GetPlayers()) do
                if Player == LocalPlayer then continue end

                local Character = Player.Character
                local PlayerRootPart = Character and Character:FindFirstChild("HumanoidRootPart")
                if not PlayerRootPart then continue end

                if not ShowTeammates and LocalTeam and Player.Team == LocalTeam then continue end

                local Offset = PlayerRootPart.Position - LocalPosition
                if Offset.Magnitude > DetectRange then continue end

                local Cos = math.cos(CameraAngle)
                local Sin = math.sin(CameraAngle)

                local RotatedX = Offset.X * Cos - Offset.Z * Sin
                local RotatedZ = Offset.X * Sin + Offset.Z * Cos

                local U = math.clamp(0.5 + (RotatedX / DetectRange) * 0.5, 0.02, 0.98)
                local V = math.clamp(0.5 + (RotatedZ / DetectRange) * 0.5, 0.02, 0.98)

                local Dot = GetDot()
                local DotColor = (LocalTeam and Player.Team == LocalTeam) and AllyColor or EnemyColor

                Dot.Frame.BackgroundColor3 = DotColor
                Dot.Frame.Position = UDim2.new(U, -DotSize / 2, V, -DotSize / 2)
                Dot.NameLabel.Visible = ShowNames

                if ShowNames then
                    Dot.NameLabel.Text = Player.Name
                    Dot.NameLabel.TextColor3 = DotColor
                end
            end
        end
    end

    local RadarModule = Tab:AddModule({
        Name = Config.Name or "Radar",
        Flag = Config.Flag or "Radar",
        ToolTip = Config.ToolTip,
        UpdateInterval = UpdateInterval,

        OnEnabled = function()
            RadarFrame.Visible = true
        end,

        OnDisabled = function()
            RadarFrame.Visible = false
            ReleaseDots()
        end,

        OnUpdate = function()
            if RadarFrame.Visible then
                RenderRadar()
            end
        end,
    })

    function RadarModule:SetRange(NewRange)
        DetectRange = NewRange
        RangeLabel.Text = NewRange .. " studs"
    end

    function RadarModule:SetSize(NewSize)
        FrameSize = NewSize
        RadarFrame.Size = UDim2.fromOffset(NewSize, NewSize)
    end

    function RadarModule:SetShowNames(State)
        ShowNames = State
    end

    function RadarModule:SetShowTeammates(State)
        ShowTeammates = State
    end

    RadarModule.RadarFrame = RadarFrame

    return RadarModule
end

function Library:AddThemes(Tab, Config)
    Config = Config or {}

    local Holder = Instance.new("Frame")
    Holder.Size = UDim2.new(1, -8, 0, 80)
    Holder.BackgroundTransparency = 0
    Holder.BorderSizePixel = 0
    Holder.Parent = Tab.Content

    self:TrackTheme(Holder, "BackgroundColor3", "SideBar")

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = Holder

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -12, 0, 20)
    Title.Position = UDim2.new(0, 6, 0, 4)
    Title.BackgroundTransparency = 1
    Title.Text = "Themes"
    Title.TextSize = 18
    Title.TextXAlignment = Enum.TextXAlignment.Left
    pcall(function() Title.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    Title.Parent = Holder

    self:TrackTheme(Title, "TextColor3", "Text")

    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, -12, 0, 50)
    Container.Position = UDim2.new(0, 6, 0, 26)
    Container.BackgroundTransparency = 1
    Container.Parent = Holder

    local Layout = Instance.new("UIListLayout")
    Layout.FillDirection = Enum.FillDirection.Horizontal
    Layout.Padding = UDim.new(0, 6)
    Layout.Parent = Container

    local function CreateTheme(Name, Color)
        local Button = Instance.new("TextButton")
        Button.Size = UDim2.new(0.5, -3, 1, 0)
        Button.BackgroundColor3 = Color
        Button.Text = ""
        Button.ClipsDescendants = true
        Button.BorderSizePixel = 0
        Button.Parent = Container

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 10)
        Corner.Parent = Button

        local Clip = Instance.new("Frame")
        Clip.Size = UDim2.new(1, 0, 1, 0)
        Clip.BackgroundTransparency = 1
        Clip.ClipsDescendants = true
        Clip.Parent = Button

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, 0, 0.35, 0)
        Label.Position = UDim2.new(0, 0, 1, 0)
        Label.BackgroundTransparency = 0.8
        Label.BackgroundColor3 = Color3.new(0,0,0)
        Label.Text = Name
        Label.TextScaled = true
        Label.BorderSizePixel = 0
        Label.TextColor3 = Color3.new(1,1,1)
        pcall(function() Label.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
        Label.Parent = Clip

        local function Hover(state)
            TweenService:Create(Label, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = state and UDim2.new(0,0,0.65,0) or UDim2.new(0,0,1,0)
            }):Play()
        end

        Button.MouseEnter:Connect(function() Hover(true) end)
        Button.MouseLeave:Connect(function() Hover(false) end)

        Button.MouseButton1Click:Connect(function()
            Library:SetTheme(Name)
        end)
    end

    CreateTheme("Light", Color3.fromRGB(255,255,255))
    CreateTheme("Dark", Color3.fromRGB(25,25,25))

    return Holder
end

function Library:AddAccents(Tab, Config)
    Config = Config or {}

    local Holder = Instance.new("Frame")
    Holder.Size = UDim2.new(1, -8, 0, 110)
    Holder.BackgroundTransparency = 0
    Holder.BorderSizePixel = 0
    Holder.Parent = Tab.Content

    self:TrackTheme(Holder, "BackgroundColor3", "SideBar")

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = Holder

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -12, 0, 20)
    Title.Position = UDim2.new(0, 6, 0, 4)
    Title.BackgroundTransparency = 1
    Title.Text = "Accents"
    Title.TextSize = 18
    Title.TextXAlignment = Enum.TextXAlignment.Left
    pcall(function() Title.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    Title.Parent = Holder

    self:TrackTheme(Title, "TextColor3", "Text")

    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, -12, 0, 80)
    Container.Position = UDim2.new(0, 6, 0, 26)
    Container.BackgroundTransparency = 1
    Container.Parent = Holder

    local Layout = Instance.new("UIGridLayout")
    Layout.CellSize = UDim2.new(0.25, -6, 0, 32)
    Layout.CellPadding = UDim2.new(0, 6, 0, 6)
    Layout.Parent = Container

    local AccentKeys = {}
    for Name in pairs(Accents) do
        table.insert(AccentKeys, Name)
    end
    table.sort(AccentKeys)

    local function CreateAccent(Name, Data)
        local Button = Instance.new("TextButton")
        Button.Size = UDim2.new(0.5, -3, 1, 0)
        Button.BackgroundColor3 = Data.Accent
        Button.Text = ""
        Button.ClipsDescendants = true
        Button.BorderSizePixel = 0
        Button.Parent = Container

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 8)
        Corner.Parent = Button

        local Clip = Instance.new("Frame")
        Clip.Size = UDim2.new(1, 0, 1, 0)
        Clip.BackgroundTransparency = 1
        Clip.ClipsDescendants = true
        Clip.Parent = Button

        local ClipCorner = Instance.new("UICorner")
        ClipCorner.CornerRadius = UDim.new(0, 8)
        ClipCorner.Parent = Clip

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, 0, 0.35, 0)
        Label.Position = UDim2.new(0, 0, 1, 0)
        Label.BackgroundTransparency = 1
        Label.TextTransparency = 1
        Label.BackgroundColor3 = Color3.new(0,0,0)
        Label.Text = Name
        Label.TextScaled = true
        Label.BorderSizePixel = 0
        Label.TextColor3 = Color3.new(1,1,1)
        pcall(function() Label.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
        Label.Parent = Clip

        local function Hover(state)
            TweenService:Create(Label, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = state and UDim2.new(0,0,0.65,0) or UDim2.new(0,0,1,0),
                BackgroundTransparency = state and 0.3 or 1,
                TextTransparency = state and 0 or 1
            }):Play()
        end

        Button.MouseEnter:Connect(function() Hover(true) end)
        Button.MouseLeave:Connect(function() Hover(false) end)

        Button.MouseButton1Click:Connect(function()
            Library:SetAccent(Name)
        end)
    end

    for _, Name in ipairs(AccentKeys) do
        CreateAccent(Name, Accents[Name])
    end

    return Holder
end

function Library:AddConfig(Tab, ConfigSystem)
    local Holder = Instance.new("Frame")
    Holder.Size = UDim2.new(1, -8, 0, 0)
    Holder.BackgroundTransparency = 0
    Holder.BorderSizePixel = 0
    Holder.Parent = Tab.Content

    self:TrackTheme(Holder, "BackgroundColor3", "SideBar")

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = Holder

    local Input = Instance.new("TextBox")
    Input.Size = UDim2.new(0.6, -6, 0, 28)
    Input.Position = UDim2.new(0, 6, 0, 6)
    Input.PlaceholderText = "Config Name..."
    Input.Text = ""
    Input.ClearTextOnFocus = false
    Input.BackgroundTransparency = 0
    Input.BorderSizePixel = 0
    Input.TextSize = 16
    pcall(function() Input.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    Input.Parent = Holder

    self:TrackTheme(Input, "BackgroundColor3", "Background")
    self:TrackTheme(Input, "TextColor3", "Text")

    local InputCorner = Instance.new("UICorner")
    InputCorner.CornerRadius = UDim.new(0, 6)
    InputCorner.Parent = Input

    local Save = Instance.new("TextButton")
    Save.Size = UDim2.new(0.4, -12, 0, 28)
    Save.Position = UDim2.new(0.6, 6, 0, 6)
    Save.Text = "Save Config"
    Save.BorderSizePixel = 0
    Save.TextSize = 16
    pcall(function() Save.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    Save.Parent = Holder

    self:TrackAccent(Save, "BackgroundColor3", "Accent")
    self:TrackTheme(Save, "TextColor3", "Text")

    local SaveCorner = Instance.new("UICorner")
    SaveCorner.CornerRadius = UDim.new(0, 6)
    SaveCorner.Parent = Save

    local List = Instance.new("Frame")
    List.Size = UDim2.new(1, -12, 0, 0)
    List.Position = UDim2.new(0, 6, 0, 40)
    List.BackgroundTransparency = 1
    List.Parent = Holder

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 6)
    Layout.Parent = List

    local AutoButtons = {}
    local Labels = {}

    local function UpdateHolderSize()
        Holder.Size = UDim2.new(1, -8, 0, 40 + Layout.AbsoluteContentSize.Y + 6)
    end

    Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateHolderSize)

    local function UpdateAutoVisuals()
        local AutoLoad = ConfigSystem:GetAutoLoad()
        for Name, Btn in pairs(AutoButtons) do
            Library:Untrack(Btn, "ImageColor3")
            if Name == AutoLoad then
                Library:TrackAccent(Btn, "ImageColor3", "Accent")
            else
                Library:TrackTheme(Btn, "ImageColor3", "Text")
            end
        end
    end

    local function UpdateLoadedVisuals()
        for Name, Label in pairs(Labels) do
            Library:Untrack(Label, "TextColor3")
            if Name == Library.CurrentConfig then
                Library:TrackAccent(Label, "TextColor3", "Accent")
            else
                Library:TrackTheme(Label, "TextColor3", "Text")
            end
        end
    end

    local function Spin(Button)
        TweenService:Create(Button, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Rotation = Button.Rotation + 360
        }):Play()
    end

    local function PressEffect(Button)
        local down = TweenService:Create(Button, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 16, 0, 16)
        })
        local up = TweenService:Create(Button, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 18, 0, 18)
        })
        down:Play()
        down.Completed:Connect(function()
            up:Play()
        end)
    end

    local function CreateItem(Name)
        local CleanName = tostring(Name):gsub("^.*[\\/]", ""):gsub("%.cfg$", "")
        local Path = ConfigSystem:GetPath(CleanName)
        local Description = ""

        if isfile(Path) then
            local Raw = readfile(Path)
            Description = Raw:match("^%-%-%s*(.-)\n") or ""
        end

        local HasDesc = Description ~= ""

        local Item = Instance.new("TextButton")
        Item.Size = UDim2.new(1, 0, 0, HasDesc and 40 or 30)
        Item.BackgroundTransparency = 0
        Item.BorderSizePixel = 0
        Item.Text = ""
        Item.Parent = List

        self:TrackTheme(Item, "BackgroundColor3", "Background")

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 6)
        Corner.Parent = Item

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, -100, 0, 18)
        Label.Position = UDim2.new(0, 6, 0, HasDesc and 2 or 6)
        Label.BackgroundTransparency = 1
        Label.Text = CleanName
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.TextSize = 16
        pcall(function() Label.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
        Label.Parent = Item

        Labels[CleanName] = Label
        self:TrackTheme(Label, "TextColor3", "Text")

        if HasDesc then
            local Desc = Instance.new("TextLabel")
            Desc.Size = UDim2.new(1, -100, 0, 14)
            Desc.Position = UDim2.new(0, 6, 0, 20)
            Desc.BackgroundTransparency = 1
            Desc.Text = Description
            Desc.TextSize = 14
            Desc.TextXAlignment = Enum.TextXAlignment.Left
            Desc.TextTransparency = 0.2
            pcall(function() Desc.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
            Desc.Parent = Item

            self:TrackTheme(Desc, "TextColor3", "Text")
        end

        local function CreateIcon(X, Image)
            local Btn = Instance.new("ImageButton")
            Btn.Size = UDim2.new(0, 18, 0, 18)
            Btn.Position = UDim2.new(1, X, 0.5, -9)
            Btn.BackgroundTransparency = 1
            Btn.Image = Image
            Btn.Parent = Item
            return Btn
        end

        local Auto = CreateIcon(-80, Assets:GetImage("Icons/Renew.png"))
        local Copy = CreateIcon(-55, Assets:GetImage("Icons/Copy.png"))
        local Delete = CreateIcon(-30, Assets:GetImage("Icons/Delete.png"))

        AutoButtons[CleanName] = Auto

        self:TrackTheme(Auto, "ImageColor3", "Text")
        self:TrackTheme(Copy, "ImageColor3", "Text")
        self:TrackTheme(Delete, "ImageColor3", "Text")

        Item.MouseButton1Click:Connect(function()
            Library.CurrentConfig = CleanName
            UpdateLoadedVisuals()
            ConfigSystem:Load(CleanName)
        end)

        Copy.MouseButton1Click:Connect(function()
            PressEffect(Copy)
            local Path = ConfigSystem:GetPath(CleanName)
            if isfile(Path) then
                setclipboard(readfile(Path))
            end
        end)

        Delete.MouseButton1Click:Connect(function()
            PressEffect(Delete)

            ConfigSystem:Delete(CleanName)

            if ConfigSystem:GetAutoLoad() == CleanName then
                ConfigSystem:SetAutoLoad("")
                Library.LoadConfig = nil
            end

            if Library.CurrentConfig == CleanName then
                Library.CurrentConfig = nil
            end

            Refresh()
        end)

        Auto.MouseButton1Click:Connect(function()
            Spin(Auto)

            local Current = ConfigSystem:GetAutoLoad()

            if Current == CleanName then
                ConfigSystem:SetAutoLoad("")
                Library.LoadConfig = nil
            else
                ConfigSystem:SetAutoLoad(CleanName)
                Library.LoadConfig = CleanName
                Library.CurrentConfig = CleanName
            end

            UpdateAutoVisuals()
            UpdateLoadedVisuals()

            if Library.LoadConfig then
                ConfigSystem:Load(Library.LoadConfig)
            end
        end)
    end

    function Refresh()
        AutoButtons = {}
        Labels = {}

        for _, v in ipairs(List:GetChildren()) do
            if v:IsA("GuiObject") then
                v:Destroy()
            end
        end

        for _, Name in ipairs(ConfigSystem:List()) do
            CreateItem(Name)
        end

        UpdateAutoVisuals()
        UpdateHolderSize()
        UpdateLoadedVisuals()
    end

    Save.MouseButton1Click:Connect(function()
        local Name = Input.Text ~= "" and Input.Text or "Default"
        Library.CurrentConfig = Name
        ConfigSystem:Save(Name)
        Refresh()
    end)

    Refresh()

    return Holder
end

function Library:AddLabel(Module, Config)
    Config = Config or {}

    local Text = Config.Text or "Label"

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0, 0, 0, 20)
    Label.BackgroundTransparency = 1
    Label.AutomaticSize = Enum.AutomaticSize.X
    Label.Text = Text
    Label.TextSize = 16
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Module.Container
    pcall(function() Label.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)

    Library:TrackTheme(Label, "TextColor3", "Text")

    local Padding = Instance.new("UIPadding")
    Padding.PaddingLeft = UDim.new(0, 10)
    Padding.Parent = Label

    return Label
end

function Library:AddToggle(Module, Config)
    Config = Config or {}

    local Text = Config.Text or "Toggle"
    local Flag = Config.Flag or Text:gsub("%s+", "")
    local Default = Config.Default or false
    local OnEnabled = Config.OnEnabled
    local OnDisabled = Config.OnDisabled
    local OnUpdate = Config.OnUpdate
    local UpdateInterval = Config.UpdateInterval or 0.1

    local Toggle = {
        Text = Text,
        Flag = Flag,
        Enabled = false
    }

    Module.Toggles = Module.Toggles or {}
    Module.Toggles[Flag] = Toggle

    Library.Flags[Flag] = Library.Flags[Flag] ~= nil and Library.Flags[Flag] or Default

    Library.ToggleMap = Library.ToggleMap or {}
    Library.ToggleMap[Flag] = Toggle

    local Wrapper = Instance.new("Frame")
    Wrapper.Size = UDim2.new(1, 0, 0, 20)
    Wrapper.BackgroundTransparency = 1
    Wrapper.ClipsDescendants = false
    Wrapper.Parent = Module.Container

    local Label = Instance.new("TextButton")
    Label.Size = UDim2.new(0, 0, 1, 0)
    Label.AutomaticSize = Enum.AutomaticSize.X
    Label.BackgroundTransparency = 1
    Label.Text = Text
    Label.TextSize = 16
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.AutoButtonColor = false
    Label.Parent = Wrapper
    pcall(function() Label.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)

    Library:TrackTheme(Label, "TextColor3", "Text")

    local Padding = Instance.new("UIPadding")
    Padding.PaddingLeft = UDim.new(0, 10)
    Padding.Parent = Label

    local Icon = Instance.new("Frame")
    Icon.Size = UDim2.new(0, 8, 0, 8)
    Icon.AnchorPoint = Vector2.new(0, 0.5)
    Icon.BackgroundTransparency = 1
    Icon.ZIndex = Label.ZIndex + 1
    Icon.Parent = Wrapper

    local IconCorner = Instance.new("UICorner")
    IconCorner.CornerRadius = UDim.new(1, 0)
    IconCorner.Parent = Icon

    Library:TrackAccent(Icon, "BackgroundColor3", "Accent")
    local IconShadow = AttachShadow(Icon, 360, 6, 6, 1.2, Color3.new(0,0,0), 0.35)
    Library:TrackAccent(IconShadow, nil, "Accent")

    local function UpdateIconPosition()
        Icon.Position = UDim2.new(0, Label.AbsoluteSize.X + 6, 0.5, 1)
    end

    Label:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateIconPosition)
    task.defer(UpdateIconPosition)

    Toggle.Label = Label
    Toggle.Icon = Icon

    local function UpdateVisual()
        local Tween = TweenService:Create(Icon, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = Toggle.Enabled and 0 or 1
        })

        if Toggle.Enabled then
            Icon.Visible = true
        end

        Tween:Play()

        Tween.Completed:Connect(function()
            if not Toggle.Enabled then
                Icon.Visible = false
            end
        end)
    end

    function Toggle:Set(State)
        if self.Enabled == State then return end
        self.Enabled = State

        Library.Flags[self.Flag] = State

        UpdateVisual()

        if State then
            if OnEnabled then
                task.spawn(OnEnabled)
            end

            if OnUpdate then
                task.spawn(function()
                    while Toggle.Enabled do
                        OnUpdate()
                        task.wait(UpdateInterval)
                    end
                end)
            end
        else
            if OnDisabled then
                task.spawn(OnDisabled)
            end
        end
    end

    function Toggle:Get()
        return self.Enabled
    end

    function Toggle:UpdateVisuals()
        UpdateVisual()
    end

    Label.MouseButton1Click:Connect(function()
        Toggle:Set(not Toggle.Enabled)
    end)

    Toggle.Enabled = Library.Flags[Flag]

    UpdateVisual()

    if Toggle.Enabled then
        if OnEnabled then
            task.spawn(OnEnabled)
        end

        if OnUpdate then
            task.spawn(function()
                while Toggle.Enabled do
                    OnUpdate()
                    task.wait(UpdateInterval)
                end
            end)
        end
    end

    return Toggle
end

function Library:AddButton(Module, Config)
    Config = Config or {}

    local Text    = Config.Text    or "Button"
    local OnClick = Config.OnClick or Config.Callback or function() end
    local SubText = Config.SubText or nil  

    local Wrapper = Instance.new("Frame")
    Wrapper.Size = UDim2.new(1, 0, 0, 26)
    Wrapper.BackgroundTransparency = 1
    Wrapper.ClipsDescendants = false
    Wrapper.Parent = Module.Container

 
    local Pill = Instance.new("Frame")
    Pill.Size = UDim2.new(1, -10, 1, 0)
    Pill.Position = UDim2.new(0, 10, 0, 0)
    Pill.BorderSizePixel = 0
    Pill.BackgroundTransparency = 0.85
    Pill.Parent = Wrapper
    self:TrackTheme(Pill, "BackgroundColor3", "Background")

    local PillCorner = Instance.new("UICorner")
    PillCorner.CornerRadius = UDim.new(0, 6)
    PillCorner.Parent = Pill


    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 1, 0)
    Btn.BackgroundTransparency = 1
    Btn.Text = ""
    Btn.AutoButtonColor = false
    Btn.ZIndex = 2
    Btn.Parent = Pill

    local BtnLabel = Instance.new("TextLabel")
    BtnLabel.Size = UDim2.new(1, -12, 1, 0)
    BtnLabel.Position = UDim2.new(0, 8, 0, 0)
    BtnLabel.BackgroundTransparency = 1
    BtnLabel.Text = Text
    BtnLabel.TextSize = 15
    BtnLabel.TextXAlignment = Enum.TextXAlignment.Left
    BtnLabel.ZIndex = 2
    pcall(function() BtnLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    BtnLabel.Parent = Pill
    self:TrackTheme(BtnLabel, "TextColor3", "Text")

        local SubLabel = nil

    if SubText then
        SubLabel = Instance.new("TextLabel")
        SubLabel.Size = UDim2.new(0, 0, 1, 0)
        SubLabel.AnchorPoint = Vector2.new(1, 0)
        SubLabel.Position = UDim2.new(1, -8, 0, 0)
        SubLabel.AutomaticSize = Enum.AutomaticSize.X
        SubLabel.BackgroundTransparency = 1
        SubLabel.Text = SubText
        SubLabel.TextSize = 13
        SubLabel.TextTransparency = 0.35
        SubLabel.TextXAlignment = Enum.TextXAlignment.Right
        SubLabel.ZIndex = 2
        pcall(function() SubLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Regular, Enum.FontStyle.Normal) end)
        SubLabel.Parent = Pill
        self:TrackTheme(SubLabel, "TextColor3", "Text")
    end

    -- Press ripple effect
    Btn.MouseButton1Down:Connect(function()
        TweenService:Create(Pill, TweenInfo.new(0.08, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.6}):Play()
    end)

    Btn.MouseButton1Up:Connect(function()
        TweenService:Create(Pill, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.85}):Play()
    end)

    Btn.MouseEnter:Connect(function()
        TweenService:Create(Pill, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.75}):Play()
    end)

    Btn.MouseLeave:Connect(function()
        TweenService:Create(Pill, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.85}):Play()
    end)

    Btn.MouseButton1Click:Connect(function()
        task.spawn(OnClick)
    end)

    local Button = {}

    function Button:SetText(NewText)
        BtnLabel.Text = NewText
    end

    function Button:SetSubText(NewSubText)
        if SubLabel then
            SubLabel.Text = NewSubText or ""
        end
    end

    function Button:SetEnabled(State)
        Btn.Active = State
        BtnLabel.TextTransparency = State and 0 or 0.5
    end

    return Button
end

function Library:AddKeybind(Module, Config)
    Config = Config or {}

    local Text     = Config.Text     or "Keybind"
    local Flag     = Config.Flag     or Text:gsub("%s+", "")
    local Default  = Config.Default  or nil   -- Enum.KeyCode.X  or  nil
    local OnChange = Config.OnChange or function() end
    local OnPress  = Config.OnPress  or function() end

    local CurrentKey = Default
    local IsListening = false

    Library.Flags[Flag] = CurrentKey

    -- ── Outer wrapper (same height as a button row) ──────────────────────
    local Wrapper = Instance.new("Frame")
    Wrapper.Size = UDim2.new(1, 0, 0, 26)
    Wrapper.BackgroundTransparency = 1
    Wrapper.ClipsDescendants = false
    Wrapper.Parent = Module.Container

    local WrapperPad = Instance.new("UIPadding")
    WrapperPad.PaddingLeft = UDim.new(0, 10)
    WrapperPad.Parent = Wrapper

    -- ── Name label ───────────────────────────────────────────────────────
    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(1, -90, 1, 0)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = Text
    NameLabel.TextSize = 15
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    pcall(function() NameLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    NameLabel.Parent = Wrapper
    self:TrackTheme(NameLabel, "TextColor3", "Text")

    -- ── Pill / badge showing the bound key ───────────────────────────────
    local Pill = Instance.new("Frame")
    Pill.Size = UDim2.new(0, 76, 0, 20)
    Pill.AnchorPoint = Vector2.new(1, 0.5)
    Pill.Position = UDim2.new(1, -6, 0.5, 0)
    Pill.BorderSizePixel = 0
    Pill.BackgroundTransparency = 0.6
    Pill.Parent = Wrapper
    self:TrackTheme(Pill, "BackgroundColor3", "Background")

    local PillCorner = Instance.new("UICorner")
    PillCorner.CornerRadius = UDim.new(0, 6)
    PillCorner.Parent = Pill

    local PillStroke = Instance.new("UIStroke")
    PillStroke.Thickness = 1
    PillStroke.Transparency = 0.6
    PillStroke.Parent = Pill
    self:TrackTheme(PillStroke, "Color", "Text")

    local KeyLabel = Instance.new("TextLabel")
    KeyLabel.Size = UDim2.new(1, 0, 1, 0)
    KeyLabel.BackgroundTransparency = 1
    KeyLabel.TextSize = 13
    KeyLabel.TextXAlignment = Enum.TextXAlignment.Center
    pcall(function() KeyLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    KeyLabel.Parent = Pill
    self:TrackTheme(KeyLabel, "TextColor3", "Text")

    -- ── Click button over the pill ────────────────────────────────────────
    local PillBtn = Instance.new("TextButton")
    PillBtn.Size = UDim2.new(1, 0, 1, 0)
    PillBtn.BackgroundTransparency = 1
    PillBtn.Text = ""
    PillBtn.AutoButtonColor = false
    PillBtn.ZIndex = 3
    PillBtn.Parent = Pill

    -- ── Helper: pretty key name ───────────────────────────────────────────
    local function KeyName(KeyCode)
        if not KeyCode then return "None" end
        local n = tostring(KeyCode):gsub("Enum%.KeyCode%.", "")
        return n
    end

    local function UpdateLabel()
        if IsListening then
            KeyLabel.Text = "..."
            self:TrackAccent(PillStroke, "Color", "Accent")
        else
            KeyLabel.Text = KeyName(CurrentKey)
            self:Untrack(PillStroke, "Color")
            self:TrackTheme(PillStroke, "Color", "Text")
        end
    end

    -- ── Enter / exit listening mode ───────────────────────────────────────
    local InputConn = nil

    local function StartListening()
        if IsListening then return end
        IsListening = true
        UpdateLabel()

        InputConn = UserInputService.InputBegan:Connect(function(Input, GameProcessed)
            if GameProcessed then return end

            IsListening = false
            if InputConn then InputConn:Disconnect(); InputConn = nil end

            if Input.KeyCode == Enum.KeyCode.Backspace then
                -- Remove / clear the keybind
                CurrentKey = nil
            elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                CurrentKey = Input.KeyCode
            else
                -- Non-keyboard input (e.g. mouse click) cancels without changing
                UpdateLabel()
                return
            end

            Library.Flags[Flag] = CurrentKey
            UpdateLabel()
            task.spawn(OnChange, CurrentKey)
        end)
    end

    PillBtn.MouseButton1Click:Connect(function()
        StartListening()
    end)

    PillBtn.MouseEnter:Connect(function()
        TweenService:Create(Pill, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.4}):Play()
    end)

    PillBtn.MouseLeave:Connect(function()
        TweenService:Create(Pill, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.6}):Play()
    end)

    -- ── Global key listener for triggering OnPress ────────────────────────
    UserInputService.InputBegan:Connect(function(Input, GameProcessed)
        if GameProcessed then return end
        if IsListening then return end
        if CurrentKey and Input.KeyCode == CurrentKey then
            task.spawn(OnPress)
        end
    end)

    -- ── Public API ────────────────────────────────────────────────────────
    local Keybind = {}
    Keybind.Flag = Flag

    function Keybind:GetKey()
        return CurrentKey
    end

    function Keybind:SetKey(KeyCode)
        CurrentKey = KeyCode
        Library.Flags[Flag] = CurrentKey
        UpdateLabel()
        task.spawn(OnChange, CurrentKey)
    end

    Module.Keybinds = Module.Keybinds or {}
    Module.Keybinds[Flag] = Keybind

    Library.KeybindMap = Library.KeybindMap or {}
    Library.KeybindMap[Flag] = Keybind

    UpdateLabel()
    return Keybind
end

function Library:AddColorPicker(Module, Config)
    Config = Config or {}

    local Text     = Config.Text     or "Color"
    local Flag     = Config.Flag     or Text:gsub("%s+", "")
    local Default  = Config.Default  or Color3.fromRGB(255, 80, 80)
    local OnChange = Config.OnChange or function() end

    local H, S, V = Color3.toHSV(Default)
    Library.Flags[Flag] = Default

    local Wrapper = Instance.new("Frame")
    Wrapper.Size = UDim2.new(1, 0, 0, 28)
    Wrapper.BackgroundTransparency = 1
    Wrapper.ClipsDescendants = false
    Wrapper.AutomaticSize = Enum.AutomaticSize.None
    Wrapper.Parent = Module.Container

    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 28)
    Row.BackgroundTransparency = 1
    Row.Parent = Wrapper

    local RowPadding = Instance.new("UIPadding")
    RowPadding.PaddingLeft = UDim.new(0, 10)
    RowPadding.Parent = Row

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(1, -44, 1, 0)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = Text
    NameLabel.TextSize = 15
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    pcall(function() NameLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    NameLabel.Parent = Row
    self:TrackTheme(NameLabel, "TextColor3", "Text")

    local Swatch = Instance.new("TextButton")
    Swatch.Size = UDim2.new(0, 30, 0, 18)
    Swatch.AnchorPoint = Vector2.new(1, 0.5)
    Swatch.Position = UDim2.new(1, -4, 0.5, 0)
    Swatch.BackgroundColor3 = Default
    Swatch.Text = ""
    Swatch.BorderSizePixel = 0
    Swatch.AutoButtonColor = false
    Swatch.Parent = Row

    local SwatchCorner = Instance.new("UICorner")
    SwatchCorner.CornerRadius = UDim.new(0, 4)
    SwatchCorner.Parent = Swatch

    local SwatchStroke = Instance.new("UIStroke")
    SwatchStroke.Thickness = 1.5
    SwatchStroke.Transparency = 0.6
    SwatchStroke.Parent = Swatch
    self:TrackTheme(SwatchStroke, "Color", "Text")

    local Panel = Instance.new("Frame")
    Panel.Size = UDim2.new(1, 0, 0, 148)
    Panel.Position = UDim2.new(0, 0, 0, 30)
    Panel.BackgroundTransparency = 1
    Panel.Visible = false
    Panel.ClipsDescendants = false
    Panel.Parent = Wrapper

    local PanelPadding = Instance.new("UIPadding")
    PanelPadding.PaddingLeft = UDim.new(0, 10)
    PanelPadding.PaddingRight = UDim.new(0, 4)
    PanelPadding.Parent = Panel

    local SvSize = 110
    local SvFrame = Instance.new("Frame")
    SvFrame.Size = UDim2.new(0, SvSize, 0, SvSize)
    SvFrame.Position = UDim2.new(0, 0, 0, 0)
    SvFrame.BorderSizePixel = 0
    SvFrame.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
    SvFrame.ClipsDescendants = true
    SvFrame.Parent = Panel

    Instance.new("UICorner", SvFrame).CornerRadius = UDim.new(0, 5)

    local SvWhite = Instance.new("Frame")
    SvWhite.Size = UDim2.new(1, 0, 1, 0)
    SvWhite.BackgroundColor3 = Color3.new(1, 1, 1)
    SvWhite.BorderSizePixel = 0
    SvWhite.Parent = SvFrame
    local SvWhiteGrad = Instance.new("UIGradient")
    SvWhiteGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)})
    SvWhiteGrad.Parent = SvWhite

    local SvBlack = Instance.new("Frame")
    SvBlack.Size = UDim2.new(1, 0, 1, 0)
    SvBlack.BackgroundColor3 = Color3.new(0, 0, 0)
    SvBlack.BorderSizePixel = 0
    SvBlack.Parent = SvFrame
    local SvBlackGrad = Instance.new("UIGradient")
    SvBlackGrad.Rotation = 270
    SvBlackGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)})
    SvBlackGrad.Parent = SvBlack

    local SvCursor = Instance.new("Frame")
    SvCursor.Size = UDim2.new(0, 10, 0, 10)
    SvCursor.AnchorPoint = Vector2.new(0.5, 0.5)
    SvCursor.BackgroundColor3 = Color3.new(1, 1, 1)
    SvCursor.BorderSizePixel = 0
    SvCursor.ZIndex = 5
    SvCursor.Parent = SvFrame
    Instance.new("UICorner", SvCursor).CornerRadius = UDim.new(1, 0)
    local SvStroke = Instance.new("UIStroke")
    SvStroke.Thickness = 2
    SvStroke.Color = Color3.new(1, 1, 1)
    SvStroke.Parent = SvCursor

    local SvBtn = Instance.new("TextButton")
    SvBtn.Size = UDim2.new(1, 0, 1, 0)
    SvBtn.BackgroundTransparency = 1
    SvBtn.Text = ""
    SvBtn.ZIndex = 6
    SvBtn.Parent = SvFrame

    local HueFrame = Instance.new("Frame")
    HueFrame.Size = UDim2.new(0, 14, 0, SvSize)
    HueFrame.Position = UDim2.new(0, SvSize + 8, 0, 0)
    HueFrame.BorderSizePixel = 0
    HueFrame.ClipsDescendants = true
    HueFrame.Parent = Panel
    Instance.new("UICorner", HueFrame).CornerRadius = UDim.new(0, 4)

    local HueGrad = Instance.new("UIGradient")
    HueGrad.Rotation = 270
    local HueKeys = {}
    for i = 0, 6 do
        HueKeys[i+1] = ColorSequenceKeypoint.new(i/6, Color3.fromHSV(i/6, 1, 1))
    end
    HueGrad.Color = ColorSequence.new(HueKeys)
    HueGrad.Parent = HueFrame

    local HueCursor = Instance.new("Frame")
    HueCursor.Size = UDim2.new(1, 4, 0, 4)
    HueCursor.AnchorPoint = Vector2.new(0.5, 0.5)
    HueCursor.BackgroundColor3 = Color3.new(1, 1, 1)
    HueCursor.BorderSizePixel = 0
    HueCursor.ZIndex = 5
    HueCursor.Position = UDim2.new(0.5, 0, 1 - H, 0)
    HueCursor.Parent = HueFrame
    Instance.new("UICorner", HueCursor).CornerRadius = UDim.new(0, 2)

    local HueBtn = Instance.new("TextButton")
    HueBtn.Size = UDim2.new(1, 0, 1, 0)
    HueBtn.BackgroundTransparency = 1
    HueBtn.Text = ""
    HueBtn.ZIndex = 6
    HueBtn.Parent = HueFrame

    local HexRow = Instance.new("Frame")
    HexRow.Size = UDim2.new(1, 0, 0, 24)
    HexRow.Position = UDim2.new(0, 0, 0, SvSize + 8)
    HexRow.BackgroundTransparency = 1
    HexRow.Parent = Panel

    local HexBox = Instance.new("TextBox")
    HexBox.Size = UDim2.new(0, SvSize, 1, 0)
    HexBox.BackgroundTransparency = 0.7
    HexBox.BorderSizePixel = 0
    HexBox.Text = string.format("%02X%02X%02X", math.floor(Default.R*255+0.5), math.floor(Default.G*255+0.5), math.floor(Default.B*255+0.5))
    HexBox.TextSize = 13
    HexBox.ClearTextOnFocus = false
    HexBox.PlaceholderText = "RRGGBB"
    pcall(function() HexBox.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Regular, Enum.FontStyle.Normal) end)
    HexBox.Parent = HexRow
    self:TrackTheme(HexBox, "BackgroundColor3", "Background")
    self:TrackTheme(HexBox, "TextColor3", "Text")
    Instance.new("UICorner", HexBox).CornerRadius = UDim.new(0, 4)

    local IsDraggingSv  = false
    local IsDraggingHue = false
    local LastUpdateTime = 0
    local MinUpdateDelta = 0.01  -- Minimum time between updates (seconds)

    local function GetCurrentColor()
        return Color3.fromHSV(H, S, V)
    end

    local function UpdateAll()
        local currentTime = tick()
        if currentTime - LastUpdateTime < MinUpdateDelta then
            return
        end
        LastUpdateTime = currentTime
        
        local Color = GetCurrentColor()
        Swatch.BackgroundColor3 = Color
        SvFrame.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
        SvCursor.Position = UDim2.new(S, 0, 1 - V, 0)
        HueCursor.Position = UDim2.new(0.5, 0, 1 - H, 0)
        HexBox.Text = string.format("%02X%02X%02X", math.floor(Color.R*255+0.5), math.floor(Color.G*255+0.5), math.floor(Color.B*255+0.5))
        Library.Flags[Flag] = Color
        task.spawn(OnChange, Color)
    end

    local function ApplySvFromMouse(Pos)
        if not IsDraggingSv then return end
        
        local Abs  = SvFrame.AbsolutePosition
        local Size = SvFrame.AbsoluteSize
        if Size.X <= 0 or Size.Y <= 0 then return end
        
        local newS = math.clamp((Pos.X - Abs.X) / Size.X, 0, 1)
        local newV = math.clamp(1 - (Pos.Y - Abs.Y) / Size.Y, 0, 1)
        
        S = newS
        V = newV
        UpdateAll()
    end

    local function ApplyHueFromMouse(Pos)
        if not IsDraggingHue then return end
        
        local Abs  = HueFrame.AbsolutePosition
        local Size = HueFrame.AbsoluteSize
        if Size.Y <= 0 then return end
        
        local newH = math.clamp(1 - (Pos.Y - Abs.Y) / Size.Y, 0, 1)
        H = newH
        UpdateAll()
    end

    SvBtn.MouseButton1Down:Connect(function()  IsDraggingSv = true end)
    HueBtn.MouseButton1Down:Connect(function() IsDraggingHue = true end)

    UserInputService.InputChanged:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseMovement then
            if IsDraggingSv  then ApplySvFromMouse(Input.Position)  end
            if IsDraggingHue then ApplyHueFromMouse(Input.Position) end
        end
    end)

    UserInputService.InputEnded:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            IsDraggingSv  = false
            IsDraggingHue = false
        end
    end)

    HexBox.FocusLost:Connect(function()
        local hex = HexBox.Text:gsub("#",""):upper():match("^([0-9A-F]+)$")
        if hex and #hex == 6 then
            local r = tonumber(hex:sub(1,2),16)/255
            local g = tonumber(hex:sub(3,4),16)/255
            local b = tonumber(hex:sub(5,6),16)/255
            H, S, V = Color3.toHSV(Color3.new(r, g, b))
            UpdateAll()
        else
            local c = GetCurrentColor()
            HexBox.Text = string.format("%02X%02X%02X", math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5))
        end
    end)

    local PanelOpen = false
    local PanelHeight = SvSize + 8 + 24 + 8  

    Swatch.MouseButton1Click:Connect(function()
        PanelOpen = not PanelOpen
        Panel.Visible = PanelOpen
        Wrapper.Size = UDim2.new(1, 0, 0, PanelOpen and (28 + PanelHeight) or 28)
    end)

    UpdateAll()

    local ColorPicker = {}

    function ColorPicker:GetValue()
        return GetCurrentColor()
    end

    function ColorPicker:SetValue(Color)
        H, S, V = Color3.toHSV(Color)
        UpdateAll()
    end

    ColorPicker.Flag = Flag

    Module.ColorPickers = Module.ColorPickers or {}
    Module.ColorPickers[Flag] = ColorPicker

    Library.ColorPickerMap = Library.ColorPickerMap or {}
    Library.ColorPickerMap[Flag] = ColorPicker

    return ColorPicker
end

function Library:AddSlider(Module, Config)

    local Text = Config.Text or "Slider"
    local Flag = Config.Flag or Text:gsub("%s+", "")
    local Minimum = Config.Min or 0
    local Maximum = Config.Max or 100
    local Default = Config.Default or Minimum
    local Suffix = Config.Suffix or ""
    local Stepping = Config.Stepping or 1
    local Decimal = Config.Decimal or 0
    local DualHandle = Config.DualHandle or false
    local OnChange = Config.OnChange or function() end

    local CurrentValue = Default
    local CurrentMinimum = Minimum
    local IsDraggingMain = false
    local IsDraggingMin = false

    local function RoundValue(Value)
        local Factor = 10 ^ Decimal
        Value = math.clamp(Value, Minimum, Maximum)
        Value = math.round(Value / Stepping) * Stepping
        return math.round(Value * Factor) / Factor
    end

    local function FormatValue(Value)
        if Decimal > 0 then
            return string.format("%." .. Decimal .. "f", Value) .. Suffix
        end
        return tostring(Value) .. Suffix
    end

    local function GetAlpha(Value, Min, Max)
        if Max == Min then return 0 end
        return (Value - Min) / (Max - Min)
    end

    Module.Sliders = Module.Sliders or {}

    Library.Flags[Flag] = Library.Flags[Flag] ~= nil and Library.Flags[Flag] or Default

    Library.SliderMap = Library.SliderMap or {}

    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, 0, 0, 20)
    Container.BackgroundTransparency = 1
    Container.AutomaticSize = Enum.AutomaticSize.Y
    Container.ClipsDescendants = false
    Container.Parent = Module.Container

    local ContainerPadding = Instance.new("UIPadding")
    ContainerPadding.PaddingLeft = UDim.new(0, 10)
    ContainerPadding.Parent = Container

    local RowFrame = Instance.new("Frame")
    RowFrame.Size = UDim2.new(1, -10, 0, 20)
    RowFrame.BackgroundTransparency = 1
    RowFrame.ClipsDescendants = false
    RowFrame.Parent = Container

    local RowLayout = Instance.new("UIListLayout")
    RowLayout.FillDirection = Enum.FillDirection.Horizontal
    RowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    RowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    RowLayout.Padding = UDim.new(0, 8)
    RowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    RowLayout.Parent = RowFrame

    local TextLabel = Instance.new("TextLabel")
    TextLabel.Size = UDim2.new(0, 0, 1, 0)
    TextLabel.AutomaticSize = Enum.AutomaticSize.X
    TextLabel.BackgroundTransparency = 1
    TextLabel.Text = Text
    TextLabel.TextSize = 16
    TextLabel.TextXAlignment = Enum.TextXAlignment.Left
    pcall(function() TextLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    TextLabel.LayoutOrder = 1
    TextLabel.Parent = RowFrame

    Library:TrackTheme(TextLabel, "TextColor3", "Text")

    local TrackWrapper = Instance.new("Frame")
    TrackWrapper.BackgroundTransparency = 1
    TrackWrapper.Size = UDim2.new(1, 0, 1, 0)
    TrackWrapper.ClipsDescendants = false
    TrackWrapper.LayoutOrder = 2
    TrackWrapper.Parent = RowFrame

    local TrackWrapperFlex = Instance.new("UIFlexItem")
    TrackWrapperFlex.FlexMode = Enum.UIFlexMode.Fill
    TrackWrapperFlex.Parent = TrackWrapper

    local SliderTrack = Instance.new("Frame")
    SliderTrack.Size = UDim2.new(1, 0, 0, 2)
    SliderTrack.AnchorPoint = Vector2.new(0, 0.5)
    SliderTrack.Position = UDim2.new(0, 0, 0.5, 1)
    SliderTrack.BorderSizePixel = 0
    SliderTrack.ClipsDescendants = false
    SliderTrack.Parent = TrackWrapper

    Library:TrackTheme(SliderTrack, "BackgroundColor3", "Background")

    local SliderTrackCorner = Instance.new("UICorner")
    SliderTrackCorner.CornerRadius = UDim.new(1, 0)
    SliderTrackCorner.Parent = SliderTrack

    local SliderFill = Instance.new("Frame")
    SliderFill.Size = UDim2.new(0, 0, 1, 0)
    SliderFill.BorderSizePixel = 0
    SliderFill.Parent = SliderTrack

    Library:TrackAccent(SliderFill, "BackgroundColor3", "Accent")

    local SliderFillCorner = Instance.new("UICorner")
    SliderFillCorner.CornerRadius = UDim.new(1, 0)
    SliderFillCorner.Parent = SliderFill

    local MainHandle = Instance.new("TextButton")
    MainHandle.Size = UDim2.new(0, 8, 0, 8)
    MainHandle.AnchorPoint = Vector2.new(0.5, 0.5)
    MainHandle.Position = UDim2.new(0, 0, 0.5, 0)
    MainHandle.BackgroundTransparency = 0
    MainHandle.Text = ""
    MainHandle.ZIndex = 3
    MainHandle.Parent = SliderTrack
    Library:TrackAccent(MainHandle, "BackgroundColor3", "Accent")
    local MainHandleCorner = Instance.new("UICorner")
    MainHandleCorner.CornerRadius = UDim.new(1, 0)
    MainHandleCorner.Parent = MainHandle
    local HandleShadow = AttachShadow(MainHandle, 360, 6, 6, 1.2, Color3.new(0,0,0), 0.35)
    Library:TrackAccent(HandleShadow, nil, "Accent")

    local MinHandle = nil

    if DualHandle then
        MinHandle = Instance.new("TextButton")
        MinHandle.Size = UDim2.new(0, 8, 0, 8)
        MinHandle.AnchorPoint = Vector2.new(0.5, 0.5)
        MinHandle.Position = UDim2.new(0, 0, 0.5, 0)
        MinHandle.BackgroundTransparency = 0
        MinHandle.Text = ""
        MinHandle.ZIndex = 3
        MinHandle.Parent = SliderTrack
        Library:TrackAccent(MinHandle, "BackgroundColor3", "Accent")
        local MinHandleCorner = Instance.new("UICorner")
        MinHandleCorner.CornerRadius = UDim.new(1, 0)
        MinHandleCorner.Parent = MinHandle
        local MinShadow = AttachShadow(MinHandle, 360, 6, 6, 1.2, Color3.new(0,0,0), 0.35)
        Library:TrackAccent(MinShadow, nil, "Accent")
    end

    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Size = UDim2.new(0, 0, 1, 0)
    ValueLabel.AutomaticSize = Enum.AutomaticSize.X
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.TextSize = 16
    ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    pcall(function() ValueLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    ValueLabel.LayoutOrder = 3
    ValueLabel.Parent = RowFrame

    Library:TrackTheme(ValueLabel, "TextColor3", "Text")


    local SliderTweenInfo = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local function TweenProperties(Instance, Properties)
        TweenService:Create(Instance, SliderTweenInfo, Properties):Play()
    end

    local function UpdateVisual()
        local MainAlpha = GetAlpha(CurrentValue, Minimum, Maximum)
        local MinAlpha = DualHandle and GetAlpha(CurrentMinimum, Minimum, Maximum) or 0

        TweenProperties(MainHandle, {Position = UDim2.new(MainAlpha, 0, 0.5, 0)})

        if DualHandle and MinHandle then
            TweenProperties(MinHandle, {Position = UDim2.new(MinAlpha, 0, 0.5, 0)})
            TweenProperties(SliderFill, {
                Position = UDim2.new(MinAlpha, 0, 0, 0),
                Size = UDim2.new(MainAlpha - MinAlpha, 0, 1, 0)
            })
            ValueLabel.Text = FormatValue(CurrentMinimum) .. " " .. FormatValue(CurrentValue)
        else
            TweenProperties(SliderFill, {
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(MainAlpha, 0, 1, 0)
            })
            ValueLabel.Text = FormatValue(CurrentValue)
        end
    end

    local function SetValue(Value)
        CurrentValue = RoundValue(Value)
        if DualHandle then
            CurrentValue = math.max(CurrentValue, CurrentMinimum)
            Library.Flags[Flag] = {Min = CurrentMinimum, Max = CurrentValue}
        else
            Library.Flags[Flag] = CurrentValue
        end
        UpdateVisual()
        OnChange(CurrentValue, DualHandle and CurrentMinimum or nil)
    end

    local function SetMinimum(Value)
        CurrentMinimum = RoundValue(Value)
        CurrentMinimum = math.min(CurrentMinimum, CurrentValue)
        Library.Flags[Flag] = {Min = CurrentMinimum, Max = CurrentValue}
        UpdateVisual()
        OnChange(CurrentValue, CurrentMinimum)
    end

    local function GetValueFromPosition(PositionX)
        local TrackPosition = SliderTrack.AbsolutePosition.X
        local TrackSize = SliderTrack.AbsoluteSize.X
        local Alpha = math.clamp((PositionX - TrackPosition) / TrackSize, 0, 1)
        return Minimum + Alpha * (Maximum - Minimum)
    end

    MainHandle.MouseButton1Down:Connect(function()
        IsDraggingMain = true
        IsDraggingMin = false
    end)

    if DualHandle and MinHandle then
        MinHandle.MouseButton1Down:Connect(function()
            IsDraggingMin = true
            IsDraggingMain = false
        end)
    end

    SliderTrack.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ClickValue = GetValueFromPosition(Input.Position.X)

            if DualHandle then
                local MainDistance = math.abs(ClickValue - CurrentValue)
                local MinDistance = math.abs(ClickValue - CurrentMinimum)

                if MinDistance < MainDistance then
                    IsDraggingMin = true
                    IsDraggingMain = false
                    SetMinimum(ClickValue)
                else
                    IsDraggingMain = true
                    IsDraggingMin = false
                    SetValue(ClickValue)
                end
            else
                IsDraggingMain = true
                SetValue(ClickValue)
            end
        end
    end)

    UserInputService.InputChanged:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseMovement then
            if IsDraggingMain then
                SetValue(GetValueFromPosition(Input.Position.X))
            elseif IsDraggingMin then
                SetMinimum(GetValueFromPosition(Input.Position.X))
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            IsDraggingMain = false
            IsDraggingMin = false
        end
    end)

    local Slider = {}

    function Slider:SetValue(Value)
        SetValue(Value)
    end

    function Slider:SetMinimum(Value)
        if DualHandle then
            SetMinimum(Value)
        end
    end

    function Slider:GetValue()
        return CurrentValue, DualHandle and CurrentMinimum or nil
    end

    Slider.Flag = Flag

    Module.Sliders[Flag] = Slider
    Library.SliderMap[Flag] = Slider
    Library.Flags[Flag] = DualHandle and {Min = CurrentMinimum, Max = CurrentValue} or CurrentValue

    UpdateVisual()

    return Slider
end

function Library:AddCarousel(Module, Config)
    Config = Config or {}

    local Values = Config.Values or {"Option 1", "Option 2", "Option 3"}
    local OptionChildren = Config.OptionChildren or {}
    local Default = Config.Default or 1
    local Text = Config.Text or "Carousel"
    local Flag = Config.Flag or Text:gsub("[^%w]", "")
    local OnChange = Config.OnChange or function() end

    local CurrentIndex = Default
    local IsExpanded = false
    local OptionContainers = {}

    local function BuildDisplayText(Value)
        return Text .. tostring(Value)
    end

    local function CurrentOptionHasChildren()
        local CurrentOption = Values[CurrentIndex]
        return OptionChildren[CurrentOption] ~= nil and #OptionChildren[CurrentOption] > 0
    end

    local MainContainer = Instance.new("Frame")
    MainContainer.Size = UDim2.new(1, 0, 0, 20)
    MainContainer.BackgroundTransparency = 1
    MainContainer.AutomaticSize = Enum.AutomaticSize.Y
    MainContainer.ClipsDescendants = false
    MainContainer.Parent = Module.Container

    local MainPadding = Instance.new("UIPadding")
    MainPadding.PaddingLeft = UDim.new(0, 10)
    MainPadding.Parent = MainContainer

    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Size = UDim2.new(1, -10, 0, 20)
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.AutomaticSize = Enum.AutomaticSize.X
    ValueLabel.Text = BuildDisplayText(Values[CurrentIndex])
    ValueLabel.TextSize = 16
    ValueLabel.TextXAlignment = Enum.TextXAlignment.Left
    pcall(function() ValueLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    ValueLabel.Parent = MainContainer

    Library:TrackTheme(ValueLabel, "TextColor3", "Text")

    local ClickButton = Instance.new("TextButton")
    ClickButton.Size = UDim2.new(1, 0, 0, 20)
    ClickButton.BackgroundTransparency = 1
    ClickButton.Text = ""
    ClickButton.ZIndex = 2
    ClickButton.Parent = MainContainer

    local ChildrenContainer = Instance.new("Frame")
    ChildrenContainer.Size = UDim2.new(1, -10, 0, 0)
    ChildrenContainer.Position = UDim2.new(0, 10, 0, 25)
    ChildrenContainer.BackgroundTransparency = 1
    ChildrenContainer.AutomaticSize = Enum.AutomaticSize.Y
    ChildrenContainer.Visible = false
    ChildrenContainer.Parent = MainContainer

    local ChildrenListLayout = Instance.new("UIListLayout")
    ChildrenListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ChildrenListLayout.Padding = UDim.new(0, 4)
    ChildrenListLayout.Parent = ChildrenContainer

    Module.Carousels = Module.Carousels or {}
    Module.Toggles = Module.Toggles or {}
    Module.Sliders = Module.Sliders or {}

    for _, OptionName in ipairs(Values) do
        if OptionChildren[OptionName] then
            local OptionContainer = Instance.new("Frame")
            OptionContainer.Size = UDim2.new(1, 0, 0, 0)
            OptionContainer.BackgroundTransparency = 1
            OptionContainer.AutomaticSize = Enum.AutomaticSize.Y
            OptionContainer.Visible = false
            OptionContainer.Parent = ChildrenContainer

            local OptionListLayout = Instance.new("UIListLayout")
            OptionListLayout.SortOrder = Enum.SortOrder.LayoutOrder
            OptionListLayout.Padding = UDim.new(0, 4)
            OptionListLayout.Parent = OptionContainer

            local OptionModule = {
                Container = OptionContainer,
                Toggles = Module.Toggles,
                Sliders = Module.Sliders,
                Carousels = Module.Carousels
            }

            for _, BuilderFunction in ipairs(OptionChildren[OptionName]) do
                BuilderFunction(OptionModule)
            end

            OptionContainers[OptionName] = OptionContainer
        end
    end

    local function RefreshVisibleOptionContainer()
        local CurrentOption = Values[CurrentIndex]
        for OptionName, OptionContainer in pairs(OptionContainers) do
            OptionContainer.Visible = IsExpanded and OptionName == CurrentOption
        end
    end

    ClickButton.MouseButton1Click:Connect(function()
        CurrentIndex = (CurrentIndex % #Values) + 1
        ValueLabel.Text = BuildDisplayText(Values[CurrentIndex])
        ChildrenContainer.Visible = IsExpanded and CurrentOptionHasChildren()
        RefreshVisibleOptionContainer()
        Library.Flags[Flag] = Values[CurrentIndex]
        OnChange(Values[CurrentIndex], CurrentIndex)
    end)

    ClickButton.MouseButton2Click:Connect(function()
        if not CurrentOptionHasChildren() then
            return
        end

        IsExpanded = not IsExpanded
        ChildrenContainer.Visible = IsExpanded
        RefreshVisibleOptionContainer()
    end)

    local Carousel = {}

    function Carousel:GetValue()
        return Values[CurrentIndex], CurrentIndex
    end

    function Carousel:SetValue(Index)
        if Values[Index] then
            CurrentIndex = Index
            ValueLabel.Text = BuildDisplayText(Values[CurrentIndex])
            ChildrenContainer.Visible = IsExpanded and CurrentOptionHasChildren()
            RefreshVisibleOptionContainer()
            Library.Flags[Flag] = Values[CurrentIndex]
            OnChange(Values[CurrentIndex], CurrentIndex)
        end
    end

    function Carousel:SetExpanded(State)
        if not CurrentOptionHasChildren() then
            return
        end

        IsExpanded = State
        ChildrenContainer.Visible = IsExpanded
        RefreshVisibleOptionContainer()
    end

    Carousel.Values = Values

    Module.Carousels = Module.Carousels or {}
    Module.Carousels[Flag] = Carousel

    Library.CarouselMap = Library.CarouselMap or {}
    Library.CarouselMap[Flag] = Carousel

    Library.Flags[Flag] = Library.Flags[Flag] ~= nil and Library.Flags[Flag] or Values[CurrentIndex]

    Carousel.Container = ChildrenContainer
    Carousel.Instance = MainContainer

    return Carousel
end

function Library:AddTextBox(Module, Config)
    Config = Config or {}

    local Text = Config.Text or "Input"
    local Flag = Config.Flag or Text:gsub("%s+", "")
    local Placeholder = Config.Placeholder or ""
    local Default = Config.Default or ""
    local OnChange = Config.OnChange or function() end

    Library.Flags[Flag] = type(Library.Flags[Flag]) == "string" and Library.Flags[Flag] or Default

    local Wrapper = Instance.new("Frame")
    Wrapper.Size = UDim2.new(1, 0, 0, 28)
    Wrapper.BackgroundTransparency = 1
    Wrapper.ClipsDescendants = false
    Wrapper.Parent = Module.Container

    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 28)
    Row.BackgroundTransparency = 1
    Row.Parent = Wrapper

    local RowPadding = Instance.new("UIPadding")
    RowPadding.PaddingLeft = UDim.new(0, 10)
    RowPadding.PaddingRight = UDim.new(0, 6)
    RowPadding.Parent = Row

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(1, -130, 1, 0)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = Text
    NameLabel.TextSize = 15
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    pcall(function() NameLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    NameLabel.Parent = Row
    self:TrackTheme(NameLabel, "TextColor3", "Text")

    local Input = Instance.new("TextBox")
    Input.Size = UDim2.new(0, 120, 0, 22)
    Input.AnchorPoint = Vector2.new(1, 0.5)
    Input.Position = UDim2.new(1, 0, 0.5, 0)
    Input.BackgroundTransparency = 0.6
    Input.BorderSizePixel = 0
    Input.PlaceholderText = Placeholder
    Input.PlaceholderColor3 = Color3.fromRGB(128, 128, 128)
    Input.Text = Library.Flags[Flag]
    Input.TextSize = 13
    Input.TextXAlignment = Enum.TextXAlignment.Center
    Input.ClearTextOnFocus = false
    Input.Parent = Row
    self:TrackTheme(Input, "BackgroundColor3", "Background")
    self:TrackTheme(Input, "TextColor3", "Text")

    local InputCorner = Instance.new("UICorner")
    InputCorner.CornerRadius = UDim.new(0, 5)
    InputCorner.Parent = Input

    local InputStroke = Instance.new("UIStroke")
    InputStroke.Thickness = 1
    InputStroke.Transparency = 0.7
    InputStroke.Parent = Input
    self:TrackTheme(InputStroke, "Color", "Text")

    local function ApplyText()
        Library.Flags[Flag] = Input.Text
        task.spawn(OnChange, Input.Text)
    end

    Input.FocusLost:Connect(function(EnterPressed)
        ApplyText()
    end)

    local TextBox = {}
    TextBox.Flag = Flag

    function TextBox:GetText()
        return Input.Text
    end

    function TextBox:SetText(Value)
        Input.Text = tostring(Value or "")
        ApplyText()
    end

    function TextBox:Clear()
        Input.Text = ""
        ApplyText()
    end

    function TextBox:Focus()
        pcall(function() Input:CaptureFocus() end)
    end

    function TextBox:Unfocus()
        pcall(function() Input:ReleaseFocus() end)
    end

    function TextBox:SetTextSize(Size)
        Input.TextSize = Size
    end

    function TextBox:SetVisible(State)
        Wrapper.Visible = State == true
    end

    function TextBox:Destroy()
        pcall(function() Wrapper:Destroy() end)
    end

    Module.TextBoxes = Module.TextBoxes or {}
    Module.TextBoxes[Flag] = TextBox

    Library.TextBoxMap = Library.TextBoxMap or {}
    Library.TextBoxMap[Flag] = TextBox

    return TextBox
end

function Library:AddDropdown(Module, Config)
    Config = Config or {}

    local Text = Config.Text or "Dropdown"
    local Flag = Config.Flag or Text:gsub("%s+", "")
    local Options = Config.Options or {}
    local Default = Config.Default
    local MaxHeight = Config.MaxHeight
    local OnChange = Config.OnChange or function() end

    local CurrentIndex = 0
    for i, opt in ipairs(Options) do
        if opt == (Default or Library.Flags[Flag]) then
            CurrentIndex = i
            break
        end
    end
    if CurrentIndex == 0 and #Options > 0 and Default == nil and Library.Flags[Flag] == nil then
        CurrentIndex = 1
    end

    local CurrentValue = CurrentIndex > 0 and Options[CurrentIndex] or nil
    Library.Flags[Flag] = CurrentValue

    local Wrapper = Instance.new("Frame")
    Wrapper.Size = UDim2.new(1, 0, 0, 28)
    Wrapper.BackgroundTransparency = 1
    Wrapper.ClipsDescendants = false
    Wrapper.AutomaticSize = Enum.AutomaticSize.None
    Wrapper.Parent = Module.Container

    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 28)
    Header.BackgroundTransparency = 1
    Header.Parent = Wrapper

    local HeaderPad = Instance.new("UIPadding")
    HeaderPad.PaddingLeft = UDim.new(0, 10)
    HeaderPad.Parent = Header

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(1, -44, 1, 0)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = Text
    NameLabel.TextSize = 15
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    pcall(function() NameLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    NameLabel.Parent = Header
    self:TrackTheme(NameLabel, "TextColor3", "Text")

    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Size = UDim2.new(0, 0, 1, 0)
    ValueLabel.AutomaticSize = Enum.AutomaticSize.X
    ValueLabel.AnchorPoint = Vector2.new(1, 0.5)
    ValueLabel.Position = UDim2.new(1, -30, 0.5, 0)
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.TextSize = 13
    ValueLabel.TextTransparency = 0.4
    ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    pcall(function() ValueLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Regular, Enum.FontStyle.Normal) end)
    ValueLabel.Parent = Header
    self:TrackTheme(ValueLabel, "TextColor3", "Text")

    local Arrow = Instance.new("TextButton")
    Arrow.Size = UDim2.new(0, 20, 0, 20)
    Arrow.AnchorPoint = Vector2.new(1, 0.5)
    Arrow.Position = UDim2.new(1, -6, 0.5, 0)
    Arrow.BackgroundTransparency = 1
    Arrow.Text = ""
    Arrow.AutoButtonColor = false
    Arrow.ZIndex = 3
    Arrow.Parent = Header

    local ChevronLeft = Instance.new("Frame")
    ChevronLeft.Size = UDim2.new(0, 10, 0, 2)
    ChevronLeft.AnchorPoint = Vector2.new(1, 0.5)
    ChevronLeft.Position = UDim2.new(0.5, 1, 0.5, 0)
    ChevronLeft.Rotation = 45
    ChevronLeft.BorderSizePixel = 0
    ChevronLeft.ZIndex = 4
    ChevronLeft.Parent = Arrow
    Instance.new("UICorner", ChevronLeft).CornerRadius = UDim.new(1, 0)
    self:TrackTheme(ChevronLeft, "BackgroundColor3", "Text")

    local ChevronRight = Instance.new("Frame")
    ChevronRight.Size = UDim2.new(0, 10, 0, 2)
    ChevronRight.AnchorPoint = Vector2.new(0, 0.5)
    ChevronRight.Position = UDim2.new(0.5, -1, 0.5, 0)
    ChevronRight.Rotation = -45
    ChevronRight.BorderSizePixel = 0
    ChevronRight.ZIndex = 4
    ChevronRight.Parent = Arrow
    Instance.new("UICorner", ChevronRight).CornerRadius = UDim.new(1, 0)
    self:TrackTheme(ChevronRight, "BackgroundColor3", "Text")

    local Panel = Instance.new("ScrollingFrame")
    Panel.Size = UDim2.new(1, -4, 0, 0)
    Panel.Position = UDim2.new(0, 0, 0, 30)
    Panel.BackgroundTransparency = 0
    Panel.BorderSizePixel = 0
    Panel.Visible = false
    Panel.ClipsDescendants = true
    Panel.Active = true
    Panel.ZIndex = 10
    Panel.ScrollBarThickness = 0
    Panel.ScrollBarImageTransparency = 1
    Panel.ScrollingDirection = Enum.ScrollingDirection.Y
    Panel.CanvasSize = UDim2.new(0, 0, 0, 0)
    Panel.Parent = Wrapper
    self:TrackTheme(Panel, "BackgroundColor3", "SideBar")

    local PanelCorner = Instance.new("UICorner")
    PanelCorner.CornerRadius = UDim.new(0, 8)
    PanelCorner.Parent = Panel

    local PanelStroke = Instance.new("UIStroke")
    PanelStroke.Thickness = 1
    PanelStroke.Transparency = 0.7
    PanelStroke.Parent = Panel
    self:TrackAccent(PanelStroke, "Color", "Accent")

    local PanelLayout = Instance.new("UIListLayout")
    PanelLayout.Padding = UDim.new(0, 2)
    PanelLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PanelLayout.Parent = Panel

    local PanelPad = Instance.new("UIPadding")
    PanelPad.PaddingTop = UDim.new(0, 4)
    PanelPad.PaddingBottom = UDim.new(0, 4)
    PanelPad.PaddingLeft = UDim.new(0, 4)
    PanelPad.PaddingRight = UDim.new(0, 4)
    PanelPad.Parent = Panel

    local IsOpen = false
    local TargetPanelHeight = 0
    local OptionRows = {}

    local function UpdateValueLabel()
        ValueLabel.Text = CurrentValue ~= nil and tostring(CurrentValue) or (#Options > 0 and "Select..." or "No options")
    end

    local function UpdateFlag()
        Library.Flags[Flag] = CurrentValue
        task.spawn(OnChange, CurrentValue, CurrentIndex)
    end

    local function UpdatePanelSize()
        local ContentHeight = PanelLayout.AbsoluteContentSize.Y + 8
        Panel.CanvasSize = UDim2.new(0, 0, 0, ContentHeight)
        if MaxHeight and MaxHeight > 0 then
            ContentHeight = math.min(ContentHeight, MaxHeight)
        end
        TargetPanelHeight = ContentHeight
        if IsOpen then
            Panel.Size = UDim2.new(1, -4, 0, TargetPanelHeight)
            Wrapper.Size = UDim2.new(1, 0, 0, 30 + TargetPanelHeight + 4)
        end
    end

    local function SetOpen(State)
        IsOpen = State

        if State then
            Panel.Visible = true
            TweenService:Create(ChevronLeft,  TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = -45}):Play()
            TweenService:Create(ChevronRight, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = 45}):Play()
            TweenService:Create(Panel, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, -4, 0, TargetPanelHeight)
            }):Play()
            Wrapper.Size = UDim2.new(1, 0, 0, 30 + TargetPanelHeight + 4)
        else
            TweenService:Create(ChevronLeft,  TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = 45}):Play()
            TweenService:Create(ChevronRight, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = -45}):Play()
            local t = TweenService:Create(Panel, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(1, -4, 0, 0)
            })
            t:Play()
            t.Completed:Connect(function()
                if not IsOpen then
                    Panel.Visible = false
                end
            end)
            Wrapper.Size = UDim2.new(1, 0, 0, 28)
        end
    end

    local function BuildRows(NewOptions)
        for _, row in ipairs(OptionRows) do
            pcall(function() row.Row:Destroy() end)
        end
        OptionRows = {}
        Options = NewOptions or {}

        if #Options == 0 then
            CurrentIndex = 0
            CurrentValue = nil
            UpdateValueLabel()
            UpdatePanelSize()
            return
        end

        if CurrentIndex > #Options or CurrentIndex == 0 or Options[CurrentIndex] ~= CurrentValue then
            local FoundIndex = 0
            for i, opt in ipairs(Options) do
                if opt == CurrentValue then
                    FoundIndex = i
                    break
                end
            end
            if FoundIndex == 0 then
                FoundIndex = 1
                CurrentValue = Options[1]
            end
            CurrentIndex = FoundIndex
        end

        for i, opt in ipairs(Options) do
            local Row = Instance.new("TextButton")
            Row.Size = UDim2.new(1, 0, 0, 26)
            Row.BackgroundTransparency = 1
            Row.Text = ""
            Row.LayoutOrder = i
            Row.ZIndex = 11
            Row.AutoButtonColor = false
            Row.Parent = Panel

            local RowHover = Instance.new("Frame")
            RowHover.Size = UDim2.new(1, 0, 1, 0)
            RowHover.BackgroundTransparency = 1
            RowHover.BorderSizePixel = 0
            RowHover.ZIndex = 10
            RowHover.Parent = Row
            self:TrackTheme(RowHover, "BackgroundColor3", "Background")

            local RowHoverCorner = Instance.new("UICorner")
            RowHoverCorner.CornerRadius = UDim.new(0, 6)
            RowHoverCorner.Parent = RowHover

            local Dot = Instance.new("Frame")
            Dot.Size = UDim2.new(0, 7, 0, 7)
            Dot.AnchorPoint = Vector2.new(0, 0.5)
            Dot.Position = UDim2.new(0, 6, 0.5, 0)
            Dot.BackgroundTransparency = (opt == CurrentValue) and 0 or 1
            Dot.BorderSizePixel = 0
            Dot.ZIndex = 12
            Dot.Parent = Row
            self:TrackAccent(Dot, "BackgroundColor3", "Accent")
            Instance.new("UICorner", Dot).CornerRadius = UDim.new(1, 0)

            local Label = Instance.new("TextLabel")
            Label.Size = UDim2.new(1, -20, 1, 0)
            Label.Position = UDim2.new(0, 20, 0, 0)
            Label.BackgroundTransparency = 1
            Label.Text = tostring(opt)
            Label.TextSize = 14
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.ZIndex = 12
            pcall(function() Label.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
            Label.Parent = Row
            if opt == CurrentValue then
                self:TrackAccent(Label, "TextColor3", "Accent")
            else
                self:TrackTheme(Label, "TextColor3", "Text")
            end

            Row.MouseEnter:Connect(function()
                TweenService:Create(RowHover, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.75}):Play()
            end)
            Row.MouseLeave:Connect(function()
                TweenService:Create(RowHover, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
            end)

            Row.MouseButton1Click:Connect(function()
                CurrentIndex = i
                CurrentValue = Options[i]
                for _, row2 in ipairs(OptionRows) do
                    local isOn = row2.Option == CurrentValue
                    TweenService:Create(row2.Dot, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
                        BackgroundTransparency = isOn and 0 or 1
                    }):Play()
                    Library:Untrack(row2.Label, "TextColor3")
                    if isOn then
                        Library:TrackAccent(row2.Label, "TextColor3", "Accent")
                    else
                        Library:TrackTheme(row2.Label, "TextColor3", "Text")
                    end
                end
                UpdateValueLabel()
                UpdateFlag()
                SetOpen(false)
            end)

            table.insert(OptionRows, { Row = Row, Dot = Dot, Label = Label, Option = opt })
        end

        UpdateValueLabel()
        UpdatePanelSize()
    end

    PanelLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdatePanelSize)

    Arrow.MouseButton1Click:Connect(function()
        SetOpen(not IsOpen)
    end)

    local HeaderBtn = Instance.new("TextButton")
    HeaderBtn.Size = UDim2.new(1, -28, 1, 0)
    HeaderBtn.BackgroundTransparency = 1
    HeaderBtn.Text = ""
    HeaderBtn.ZIndex = 2
    HeaderBtn.Parent = Header
    HeaderBtn.MouseButton1Click:Connect(function()
        SetOpen(not IsOpen)
    end)

    -- Close on Escape or when clicking outside the dropdown
    UserInputService.InputBegan:Connect(function(Input, GameProcessed)
        if GameProcessed then return end
        if not IsOpen then return end

        if Input.UserInputType == Enum.UserInputType.Keyboard then
            if Input.KeyCode == Enum.KeyCode.Escape then
                SetOpen(false)
            end
            return
        end

        if Input.UserInputType ~= Enum.UserInputType.MouseButton1
        and Input.UserInputType ~= Enum.UserInputType.Touch then return end

        local Ok, AbsPos = pcall(function() return Wrapper.AbsolutePosition end)
        local Ok2, AbsSize = pcall(function() return Wrapper.AbsoluteSize end)
        if not (Ok and Ok2) then return end

        local Pos = Input.Position
        if Pos.X < AbsPos.X or Pos.X > AbsPos.X + AbsSize.X
        or Pos.Y < AbsPos.Y or Pos.Y > AbsPos.Y + AbsSize.Y then
            SetOpen(false)
        end
    end)

    BuildRows(Options)

    -- Public API
    local Dropdown = {}
    Dropdown.Flag = Flag
    Dropdown.IsMulti = false

    function Dropdown:GetValue()
        return CurrentValue
    end

    function Dropdown:GetIndex()
        return CurrentIndex
    end

    function Dropdown:SetValue(Value)
        for i, opt in ipairs(Options) do
            if opt == Value then
                CurrentIndex = i
                CurrentValue = Options[i]
                for _, row2 in ipairs(OptionRows) do
                    local isOn = row2.Option == CurrentValue
                    TweenService:Create(row2.Dot, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
                        BackgroundTransparency = isOn and 0 or 1
                    }):Play()
                    Library:Untrack(row2.Label, "TextColor3")
                    if isOn then
                        Library:TrackAccent(row2.Label, "TextColor3", "Accent")
                    else
                        Library:TrackTheme(row2.Label, "TextColor3", "Text")
                    end
                end
                UpdateValueLabel()
                UpdateFlag()
                return
            end
        end
    end

    function Dropdown:SetIndex(Index)
        if Options[Index] then
            CurrentIndex = Index
            CurrentValue = Options[Index]
            UpdateValueLabel()
            UpdateFlag()
        end
    end

    function Dropdown:SetOptions(NewOptions, KeepValue)
        BuildRows(NewOptions or {})
        if not KeepValue and #Options > 0 then
            CurrentIndex = 1
            CurrentValue = Options[1]
            UpdateValueLabel()
        end
        UpdateFlag()
    end

    function Dropdown:SetOpen(State)
        SetOpen(State == true)
    end

    function Dropdown:Open()
        SetOpen(true)
    end

    function Dropdown:Close()
        SetOpen(false)
    end

    function Dropdown:IsOpen()
        return IsOpen
    end

    function Dropdown:Reset()
        for i, opt in ipairs(Options) do
            if opt == Default then
                CurrentIndex = i
                break
            end
        end
        if CurrentIndex == 0 and Default == nil and #Options > 0 then
            CurrentIndex = 1
        end
        CurrentValue = CurrentIndex > 0 and Options[CurrentIndex] or nil
        UpdateValueLabel()
        UpdateFlag()
    end

    function Dropdown:SetVisible(State)
        Wrapper.Visible = State == true
        if not State and IsOpen then
            SetOpen(false)
        end
    end

    function Dropdown:Destroy()
        pcall(function() Wrapper:Destroy() end)
    end

    Module.Dropdowns = Module.Dropdowns or {}
    Module.Dropdowns[Flag] = Dropdown

    Library.DropdownMap = Library.DropdownMap or {}
    Library.DropdownMap[Flag] = Dropdown

    return Dropdown
end

function Library:AddSection(Module, Config)
    Config = Config or {}

    local Text = Config.Text or "Section"

    local Section = Instance.new("TextLabel")
    Section.Size = UDim2.new(1, 0, 0, Config.Height or 26)
    Section.BackgroundTransparency = 1
    Section.Text = string.upper(Text)
    Section.TextSize = Config.TextSize or 14
    Section.TextXAlignment = Enum.TextXAlignment.Left
    Section.TextTransparency = Config.Transparency or 0
    pcall(function() Section.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    Section.Parent = Module.Container

    local Padding = Instance.new("UIPadding")
    Padding.PaddingLeft = UDim.new(0, 10)
    Padding.PaddingTop = UDim.new(0, 4)
    Padding.Parent = Section

    self:TrackAccent(Section, "TextColor3", "Accent")

    return Section
end

function Library:AddDivider(Module, Config)
    Config = Config or {}

    local Holder = Instance.new("Frame")
    Holder.Size = UDim2.new(1, 0, 0, Config.PaddingY or 8)
    Holder.BackgroundTransparency = 1
    Holder.Parent = Module.Container

    local Line = Instance.new("Frame")
    Line.Size = UDim2.new(1, -20, 0, 1)
    Line.Position = UDim2.new(0, 10, 0.5, 0)
    Line.BackgroundTransparency = 0.6
    Line.BorderSizePixel = 0
    Line.Parent = Holder

    self:TrackTheme(Line, "BackgroundColor3", "Text")

    return Holder
end

function Library:AddProgress(Module, Config)
    Config = Config or {}

    local Text = Config.Text or "Progress"
    local Flag = Config.Flag or Text:gsub("%s+", "")
    local Suffix = Config.Suffix or ""
    local CurrentValue = Config.Value or 0
    local MaxValue = Config.Max or 100

    Library.Flags[Flag] = CurrentValue

    local Wrapper = Instance.new("Frame")
    Wrapper.Size = UDim2.new(1, 0, 0, 32)
    Wrapper.BackgroundTransparency = 1
    Wrapper.ClipsDescendants = false
    Wrapper.Parent = Module.Container

    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 24)
    Row.BackgroundTransparency = 1
    Row.Parent = Wrapper

    local RowPadding = Instance.new("UIPadding")
    RowPadding.PaddingLeft = UDim.new(0, 10)
    RowPadding.Parent = Row

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(1, -44, 1, 0)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = Text
    NameLabel.TextSize = 15
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    pcall(function() NameLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    NameLabel.Parent = Row
    self:TrackTheme(NameLabel, "TextColor3", "Text")

    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Size = UDim2.new(0, 0, 1, 0)
    ValueLabel.AutomaticSize = Enum.AutomaticSize.X
    ValueLabel.AnchorPoint = Vector2.new(1, 0.5)
    ValueLabel.Position = UDim2.new(1, -4, 0.5, 0)
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.TextSize = 13
    ValueLabel.TextTransparency = 0.35
    ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    pcall(function() ValueLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    ValueLabel.Parent = Row
    self:TrackTheme(ValueLabel, "TextColor3", "Text")

    local Track = Instance.new("Frame")
    Track.Size = UDim2.new(1, -20, 0, 4)
    Track.Position = UDim2.new(0, 10, 0, 27)
    Track.BackgroundTransparency = 0.5
    Track.BorderSizePixel = 0
    Track.ClipsDescendants = true
    Track.Parent = Wrapper
    self:TrackTheme(Track, "BackgroundColor3", "Background")

    local TrackCorner = Instance.new("UICorner")
    TrackCorner.CornerRadius = UDim.new(1, 0)
    TrackCorner.Parent = Track

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new(0, 0, 1, 0)
    Fill.BorderSizePixel = 0
    Fill.Parent = Track
    self:TrackAccent(Fill, "BackgroundColor3", "Accent")

    local FillCorner = Instance.new("UICorner")
    FillCorner.CornerRadius = UDim.new(1, 0)
    FillCorner.Parent = Fill

    local function FormatValue()
        return tostring(CurrentValue) .. Suffix
    end

    local function UpdateVisual()
        local Alpha = MaxValue > 0 and math.clamp(CurrentValue / MaxValue, 0, 1) or 0
        TweenService:Create(Fill, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(Alpha, 0, 1, 0)
        }):Play()
        ValueLabel.Text = FormatValue()
    end

    local Progress = {}

    function Progress:SetValue(Value)
        CurrentValue = Value or 0
        Library.Flags[Flag] = CurrentValue
        UpdateVisual()
    end

    function Progress:GetValue()
        return CurrentValue
    end

    function Progress:SetMax(Max)
        MaxValue = Max or 0
        UpdateVisual()
    end

    function Progress:GetMax()
        return MaxValue
    end

    function Progress:SetVisible(State)
        Wrapper.Visible = State == true
    end

    function Progress:Destroy()
        pcall(function() Wrapper:Destroy() end)
    end

    Progress.Flag = Flag

    UpdateVisual()

    return Progress
end

function Library:AddDropdownMultiSelect(Module, Config)
    Config = Config or {}

    local Text     = Config.Text     or "Dropdown"
    local Flag     = Config.Flag     or Text:gsub("%s+", "")
    local Options  = Config.Options  or {}
    local Default  = Config.Default  or {}
    local MaxSelect = Config.MaxSelect or math.huge
    local MaxHeight = Config.MaxHeight
    local OnChange = Config.OnChange or function() end

    -- Selected is a set: selected[optionName] = true
    local Selected = {}
    for _, v in ipairs(Default) do
        Selected[v] = true
    end

    Library.Flags[Flag] = {}

    local function GetSelected()
        local t = {}
        for _, opt in ipairs(Options) do
            if Selected[opt] then
                table.insert(t, opt)
            end
        end
        return t
    end

    local function UpdateFlag()
        Library.Flags[Flag] = GetSelected()
        OnChange(GetSelected())
    end

    -- Outer wrapper that grows when dropdown is open
    local Wrapper = Instance.new("Frame")
    Wrapper.Size = UDim2.new(1, 0, 0, 28)
    Wrapper.BackgroundTransparency = 1
    Wrapper.ClipsDescendants = false
    Wrapper.AutomaticSize = Enum.AutomaticSize.None
    Wrapper.Parent = Module.Container

    -- Header row
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 28)
    Header.BackgroundTransparency = 1
    Header.Parent = Wrapper

    local HeaderPad = Instance.new("UIPadding")
    HeaderPad.PaddingLeft = UDim.new(0, 10)
    HeaderPad.Parent = Header

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(1, -44, 1, 0)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = Text
    NameLabel.TextSize = 15
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    pcall(function() NameLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
    NameLabel.Parent = Header
    self:TrackTheme(NameLabel, "TextColor3", "Text")

    local CountLabel = Instance.new("TextLabel")
    CountLabel.Size = UDim2.new(0, 0, 1, 0)
    CountLabel.AutomaticSize = Enum.AutomaticSize.X
    CountLabel.AnchorPoint = Vector2.new(1, 0.5)
    CountLabel.Position = UDim2.new(1, -30, 0.5, 0)
    CountLabel.BackgroundTransparency = 1
    CountLabel.TextSize = 13
    CountLabel.TextTransparency = 0.4
    CountLabel.TextXAlignment = Enum.TextXAlignment.Right
    pcall(function() CountLabel.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Regular, Enum.FontStyle.Normal) end)
    CountLabel.Parent = Header
    self:TrackTheme(CountLabel, "TextColor3", "Text")

    -- Arrow button — two properly sized bars forming a V chevron
    local Arrow = Instance.new("TextButton")
    Arrow.Size = UDim2.new(0, 20, 0, 20)
    Arrow.AnchorPoint = Vector2.new(1, 0.5)
    Arrow.Position = UDim2.new(1, -6, 0.5, 0)
    Arrow.BackgroundTransparency = 1
    Arrow.Text = ""
    Arrow.AutoButtonColor = false
    Arrow.ZIndex = 3
    Arrow.Parent = Header

    local ChevronLeft = Instance.new("Frame")
    ChevronLeft.Size = UDim2.new(0, 10, 0, 2)
    ChevronLeft.AnchorPoint = Vector2.new(1, 0.5)
    ChevronLeft.Position = UDim2.new(0.5, 1, 0.5, 0)
    ChevronLeft.Rotation = 45
    ChevronLeft.BorderSizePixel = 0
    ChevronLeft.ZIndex = 4
    ChevronLeft.Parent = Arrow
    Instance.new("UICorner", ChevronLeft).CornerRadius = UDim.new(1, 0)
    self:TrackTheme(ChevronLeft, "BackgroundColor3", "Text")

    local ChevronRight = Instance.new("Frame")
    ChevronRight.Size = UDim2.new(0, 10, 0, 2)
    ChevronRight.AnchorPoint = Vector2.new(0, 0.5)
    ChevronRight.Position = UDim2.new(0.5, -1, 0.5, 0)
    ChevronRight.Rotation = -45
    ChevronRight.BorderSizePixel = 0
    ChevronRight.ZIndex = 4
    ChevronRight.Parent = Arrow
    Instance.new("UICorner", ChevronRight).CornerRadius = UDim.new(1, 0)
    self:TrackTheme(ChevronRight, "BackgroundColor3", "Text")

    -- Dropdown panel (list of options)
    local Panel = Instance.new("ScrollingFrame")
    Panel.Size = UDim2.new(1, -4, 0, 0)
    Panel.Position = UDim2.new(0, 0, 0, 30)
    Panel.BackgroundTransparency = 0
    Panel.BorderSizePixel = 0
    Panel.Visible = false
    Panel.ClipsDescendants = true
    Panel.Active = true
    Panel.ZIndex = 10
    Panel.ScrollBarThickness = 0
    Panel.ScrollBarImageTransparency = 1
    Panel.ScrollingDirection = Enum.ScrollingDirection.Y
    Panel.CanvasSize = UDim2.new(0, 0, 0, 0)
    Panel.Parent = Wrapper
    self:TrackTheme(Panel, "BackgroundColor3", "SideBar")

    local PanelCorner = Instance.new("UICorner")
    PanelCorner.CornerRadius = UDim.new(0, 8)
    PanelCorner.Parent = Panel

    local PanelStroke = Instance.new("UIStroke")
    PanelStroke.Thickness = 1
    PanelStroke.Transparency = 0.7
    PanelStroke.Parent = Panel
    self:TrackAccent(PanelStroke, "Color", "Accent")

    local PanelLayout = Instance.new("UIListLayout")
    PanelLayout.Padding = UDim.new(0, 2)
    PanelLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PanelLayout.Parent = Panel

    local PanelPad = Instance.new("UIPadding")
    PanelPad.PaddingTop = UDim.new(0, 4)
    PanelPad.PaddingBottom = UDim.new(0, 4)
    PanelPad.PaddingLeft = UDim.new(0, 4)
    PanelPad.PaddingRight = UDim.new(0, 4)
    PanelPad.Parent = Panel

    local IsOpen = false
    local TargetPanelHeight = 0

    local OptionRows = {}

    local function RefreshRows()
        for _, row in ipairs(OptionRows) do
            local opt = row.Option
            local isOn = Selected[opt] == true
            -- Dot visibility
            TweenService:Create(row.Dot, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
                BackgroundTransparency = isOn and 0 or 1
            }):Play()
            -- Label color via tracking swap
            Library:Untrack(row.Label, "TextColor3")
            if isOn then
                Library:TrackAccent(row.Label, "TextColor3", "Accent")
            else
                Library:TrackTheme(row.Label, "TextColor3", "Text")
            end
        end

        local Count = #GetSelected()
        CountLabel.Text = Count > 0 and tostring(Count) .. " selected" or "None"
    end

    local function BuildRows(NewOptions)
        for _, row in ipairs(OptionRows) do
            pcall(function() row.Row:Destroy() end)
        end
        OptionRows = {}
        Options = NewOptions or {}

        for i, opt in ipairs(Options) do
            local Row = Instance.new("TextButton")
            Row.Size = UDim2.new(1, 0, 0, 26)
            Row.BackgroundTransparency = 1
            Row.Text = ""
            Row.LayoutOrder = i
            Row.ZIndex = 11
            Row.AutoButtonColor = false
            Row.Parent = Panel

            local RowHover = Instance.new("Frame")
            RowHover.Size = UDim2.new(1, 0, 1, 0)
            RowHover.BackgroundTransparency = 1
            RowHover.BorderSizePixel = 0
            RowHover.ZIndex = 10
            RowHover.Parent = Row
            self:TrackTheme(RowHover, "BackgroundColor3", "Background")

            local RowHoverCorner = Instance.new("UICorner")
            RowHoverCorner.CornerRadius = UDim.new(0, 6)
            RowHoverCorner.Parent = RowHover

            local Dot = Instance.new("Frame")
            Dot.Size = UDim2.new(0, 7, 0, 7)
            Dot.AnchorPoint = Vector2.new(0, 0.5)
            Dot.Position = UDim2.new(0, 6, 0.5, 0)
            Dot.BackgroundTransparency = Selected[opt] and 0 or 1
            Dot.BorderSizePixel = 0
            Dot.ZIndex = 12
            Dot.Parent = Row
            self:TrackAccent(Dot, "BackgroundColor3", "Accent")
            Instance.new("UICorner", Dot).CornerRadius = UDim.new(1, 0)

            local Label = Instance.new("TextLabel")
            Label.Size = UDim2.new(1, -20, 1, 0)
            Label.Position = UDim2.new(0, 20, 0, 0)
            Label.BackgroundTransparency = 1
            Label.Text = tostring(opt)
            Label.TextSize = 14
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.ZIndex = 12
            pcall(function() Label.FontFace = Font.new(OutfitFont.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal) end)
            Label.Parent = Row
            if Selected[opt] then
                self:TrackAccent(Label, "TextColor3", "Accent")
            else
                self:TrackTheme(Label, "TextColor3", "Text")
            end

            Row.MouseEnter:Connect(function()
                TweenService:Create(RowHover, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.75}):Play()
            end)
            Row.MouseLeave:Connect(function()
                TweenService:Create(RowHover, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
            end)

            Row.MouseButton1Click:Connect(function()
                if Selected[opt] then
                    Selected[opt] = nil
                else
                    -- enforce MaxSelect
                    local count = 0
                    for _ in pairs(Selected) do count = count + 1 end
                    if count < MaxSelect then
                        Selected[opt] = true
                    end
                end
                RefreshRows()
                UpdateFlag()
            end)

            table.insert(OptionRows, { Row = Row, Dot = Dot, Label = Label, Option = opt })
        end
    end

    BuildRows(Options)

    -- compute target height after layout
    local function UpdatePanelSize()
        local ContentHeight = PanelLayout.AbsoluteContentSize.Y + 8
        Panel.CanvasSize = UDim2.new(0, 0, 0, ContentHeight)
        if MaxHeight and MaxHeight > 0 then
            ContentHeight = math.min(ContentHeight, MaxHeight)
        end
        TargetPanelHeight = ContentHeight
        if IsOpen then
            Panel.Size = UDim2.new(1, -4, 0, TargetPanelHeight)
            Wrapper.Size = UDim2.new(1, 0, 0, 30 + TargetPanelHeight + 4)
        end
    end

    task.defer(UpdatePanelSize)

    PanelLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdatePanelSize)

    local function SetOpen(State)
        IsOpen = State

        if State then
            Panel.Visible = true
            TweenService:Create(ChevronLeft,  TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = -45}):Play()
            TweenService:Create(ChevronRight, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = 45}):Play()
            TweenService:Create(Panel, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, -4, 0, TargetPanelHeight)
            }):Play()
            Wrapper.Size = UDim2.new(1, 0, 0, 30 + TargetPanelHeight + 4)
        else
            TweenService:Create(ChevronLeft,  TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = 45}):Play()
            TweenService:Create(ChevronRight, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = -45}):Play()
            local t = TweenService:Create(Panel, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(1, -4, 0, 0)
            })
            t:Play()
            t.Completed:Connect(function()
                if not IsOpen then
                    Panel.Visible = false
                end
            end)
            Wrapper.Size = UDim2.new(1, 0, 0, 28)
        end
    end

    Arrow.MouseButton1Click:Connect(function()
        SetOpen(not IsOpen)
    end)

    -- Also allow clicking the header row itself
    local HeaderBtn = Instance.new("TextButton")
    HeaderBtn.Size = UDim2.new(1, -28, 1, 0)
    HeaderBtn.BackgroundTransparency = 1
    HeaderBtn.Text = ""
    HeaderBtn.ZIndex = 2
    HeaderBtn.Parent = Header
    HeaderBtn.MouseButton1Click:Connect(function()
        SetOpen(not IsOpen)
    end)

    -- Close on Escape or when clicking outside the dropdown
    UserInputService.InputBegan:Connect(function(Input, GameProcessed)
        if GameProcessed then return end
        if not IsOpen then return end

        if Input.UserInputType == Enum.UserInputType.Keyboard then
            if Input.KeyCode == Enum.KeyCode.Escape then
                SetOpen(false)
            end
            return
        end

        if Input.UserInputType ~= Enum.UserInputType.MouseButton1
        and Input.UserInputType ~= Enum.UserInputType.Touch then return end

        local Ok, AbsPos = pcall(function() return Wrapper.AbsolutePosition end)
        local Ok2, AbsSize = pcall(function() return Wrapper.AbsoluteSize end)
        if not (Ok and Ok2) then return end

        local Pos = Input.Position
        if Pos.X < AbsPos.X or Pos.X > AbsPos.X + AbsSize.X
        or Pos.Y < AbsPos.Y or Pos.Y > AbsPos.Y + AbsSize.Y then
            SetOpen(false)
        end
    end)

    -- Public API
    local Dropdown = {}
    Dropdown.Flag = Flag
    Dropdown.IsMulti = true

    function Dropdown:GetSelected()
        return GetSelected()
    end

    function Dropdown:SetSelected(List)
        Selected = {}
        for _, v in ipairs(List) do
            Selected[v] = true
        end
        RefreshRows()
        UpdateFlag()
    end

    function Dropdown:SetOptions(NewOptions)
        -- prune selections that no longer exist
        local Seen = {}
        for _, opt in ipairs(NewOptions or {}) do
            Seen[opt] = true
        end
        for opt in pairs(Selected) do
            if not Seen[opt] then
                Selected[opt] = nil
            end
        end

        BuildRows(NewOptions or {})
        RefreshRows()
        UpdateFlag()
    end

    function Dropdown:SelectAll()
        for _, opt in ipairs(Options) do
            Selected[opt] = true
        end
        RefreshRows()
        UpdateFlag()
    end

    function Dropdown:Clear()
        Selected = {}
        RefreshRows()
        UpdateFlag()
    end

    function Dropdown:ToggleOption(Option)
        if Selected[Option] then
            Selected[Option] = nil
        else
            local count = 0
            for _ in pairs(Selected) do count = count + 1 end
            if count < MaxSelect then
                Selected[Option] = true
            end
        end
        RefreshRows()
        UpdateFlag()
    end

    function Dropdown:SetOpen(State)
        SetOpen(State == true)
    end

    function Dropdown:IsOpen()
        return IsOpen
    end

    Module.Dropdowns = Module.Dropdowns or {}
    Module.Dropdowns[Flag] = Dropdown

    Library.DropdownMap = Library.DropdownMap or {}
    Library.DropdownMap[Flag] = Dropdown
    Library.Flags[Flag] = GetSelected()

    return Dropdown
end

local Window = Library:CreateWindow({
    Name = "Perseus"
})

local StyleTab = Window:AddTab({
    Name = "Style",
    Icon = Assets:GetImage("Icons/Palette.png")
})

StyleTab:AddThemes()
StyleTab:AddAccents()

local ConfigsTab = Window:AddTab({
    Name = "Configs",
    Icon = Assets:GetImage("Icons/Folder.png")
})

local ConfigSystem = ConfigSystemFactory(Library)
ConfigsTab:AddConfig(ConfigSystem)

-- (Removed hardcoded RightControl/RightShift toggle — handled by the Keybind system)

EnsureGuis()

local PreviousMouseBehavior = UserInputService.MouseBehavior
local PreviousMouseIconEnabled = UserInputService.MouseIconEnabled

local ModalButton = Instance.new("TextButton")
ModalButton.Size = UDim2.fromScale(1, 1)
ModalButton.BackgroundTransparency = 1
ModalButton.Text = ""
ModalButton.ZIndex = 0
ModalButton.AutoButtonColor = false
ModalButton.Parent = ScreenGuis.MouseUnlockerUI

local Cursor = Instance.new("Frame")
Cursor.Size = UDim2.fromOffset(12, 12)
Cursor.BackgroundTransparency = 0
Cursor.Visible = false
Cursor.AnchorPoint = Vector2.new(0.5, 0.5)
Cursor.ZIndex = 999
Cursor.Parent = ScreenGuis.PerseusMouseUI

local CursorCorner = Instance.new("UICorner")
CursorCorner.CornerRadius = UDim.new(1, 0)
CursorCorner.Parent = Cursor

Library:TrackAccent(Cursor, "BackgroundColor3", "Accent")
local CursorShadow = AttachShadow(Cursor, 6, 6, 6, 1.2, Color3.new(0, 0, 0), 0.35)
Library:TrackAccent(CursorShadow, nil, "Accent")

local function SetState(State)
    if State == ScreenGuis.MouseUnlockerUI.Enabled then return end

    if State then
        PreviousMouseBehavior = UserInputService.MouseBehavior
        PreviousMouseIconEnabled = UserInputService.MouseIconEnabled

        ScreenGuis.MouseUnlockerUI.Enabled = true

        ModalButton.Active = true
        ModalButton.Modal = true

        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        -- Do NOT hide MouseIconEnabled; custom dot renders on top

        Cursor.Visible = true
    else
        ModalButton.Modal = false
        ModalButton.Active = false

        task.defer(function()
            ScreenGuis.MouseUnlockerUI.Enabled = false
            UserInputService.MouseBehavior = PreviousMouseBehavior
            Cursor.Visible = false
        end)
    end
end

Library:RenderStepped(function()
    local State = Window and Window.Open or false
    SetState(State)

    if not (Window and Window.Open) then return end

    local Pos = UserInputService:GetMouseLocation()
    local Inset = GuiService:GetGuiInset()

    Cursor.Position = UDim2.fromOffset(
        Pos.X,
        Pos.Y - Inset.Y
    )
end)

return Library

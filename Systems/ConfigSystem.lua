local HttpService = game:GetService("HttpService")

local function LoadFileManager()
    local Genv = getgenv and getgenv() or _G
    if Genv.RiseV6Modules and Genv.RiseV6Modules["FileManager.lua"] then
        return loadstring(Genv.RiseV6Modules["FileManager.lua"])()
    end

    local Ok, Source = pcall(readfile, "RiseV6UI/Systems/FileManager.lua")
    if Ok and Source and #Source > 0 then
        local Factory, Err = loadstring(Source)
        if Factory then return Factory() end
    end

    return loadstring(game:HttpGet("https://raw.githubusercontent.com/AmuletOfTheSea/RiseV6UI/main/Systems/FileManager.lua"))()
end

local FileManager = LoadFileManager()

local function NewConfigSystem(Library)
    local ConfigSystem = {}

    ConfigSystem.BasePath = "RiseV6UI/Configs/" .. tostring(game.GameId)

    function ConfigSystem:Init()
        FileManager:CreateFolder(self.BasePath)
    end

    function ConfigSystem:GetPath(Name)
        return self.BasePath .. "/" .. tostring(Name or "Default") .. ".cfg"
    end

    function ConfigSystem:Build()
        local Data = {}

        for Flag, Module in pairs(Library.Modules or {}) do
            local ModuleData = {
                Enabled = Module.Enabled
            }

            if Module.Toggles then
                local ToggleData = {}

                for ToggleFlag, Toggle in pairs(Module.Toggles) do
                    ToggleData[ToggleFlag] = Library.Flags[ToggleFlag]
                end

                if next(ToggleData) then
                    ModuleData.Toggles = ToggleData
                end
            end

            if Module.Sliders then
                local SliderData = {}

                for SliderFlag, Slider in pairs(Module.Sliders) do
                    local Value, MinValue = Slider:GetValue()
                    if MinValue ~= nil then
                        SliderData[SliderFlag] = {Value = Value, MinValue = MinValue}
                    else
                        SliderData[SliderFlag] = Value
                    end
                end

                if next(SliderData) then
                    ModuleData.Sliders = SliderData
                end
            end

            if Module.Carousels then
                local CarouselData = {}

                for CarouselFlag, Carousel in pairs(Module.Carousels) do
                    CarouselData[CarouselFlag] = Library.Flags[CarouselFlag]
                end

                if next(CarouselData) then
                    ModuleData.Carousels = CarouselData
                end
            end

            if Module.Dropdowns then
                local DropdownData = {}

                for DropdownFlag, Dropdown in pairs(Module.Dropdowns) do
                    local Value = Library.Flags[DropdownFlag]

                    if Dropdown and Dropdown.IsMulti then
                        Value = type(Value) == "table" and Value or (Dropdown:GetSelected() or {})
                    elseif Dropdown and not Dropdown.IsMulti then
                        Value = Value ~= nil and Value or (Dropdown:GetValue() or nil)
                    end

                    DropdownData[DropdownFlag] = Value
                end

                if next(DropdownData) then
                    ModuleData.Dropdowns = DropdownData
                end
            end

            if Module.ColorPickers then
                local ColorData = {}

                for ColorFlag, ColorPicker in pairs(Module.ColorPickers) do
                    local Color = Library.Flags[ColorFlag]

                    if typeof(Color) ~= "Color3" then
                        Color = ColorPicker:GetValue()
                    end

                    ColorData[ColorFlag] = {
                        R = math.floor(Color.R * 255 + 0.5),
                        G = math.floor(Color.G * 255 + 0.5),
                        B = math.floor(Color.B * 255 + 0.5)
                    }
                end

                if next(ColorData) then
                    ModuleData.ColorPickers = ColorData
                end
            end

            if Module.TextBoxes then
                local TextBoxData = {}

                for TextBoxFlag, TextBox in pairs(Module.TextBoxes) do
                    TextBoxData[TextBoxFlag] = Library.Flags[TextBoxFlag]

                    if type(TextBoxData[TextBoxFlag]) ~= "string" then
                        TextBoxData[TextBoxFlag] = TextBox:GetText()
                    end
                end

                if next(TextBoxData) then
                    ModuleData.TextBoxes = TextBoxData
                end
            end

            if Module.Keybinds then
                local KeybindData = {}

                for KeybindFlag, Keybind in pairs(Module.Keybinds) do
                    local Key = Keybind:GetKey()
                    if Key and typeof(Key) == "EnumItem" then
                        local KeyName = tostring(Key)
                        KeyName = KeyName:gsub("Enum%.KeyCode%.", ""):gsub("Enum%.UserInputType%.", "")
                        KeybindData[KeybindFlag] = KeyName
                    else
                        KeybindData[KeybindFlag] = ""
                    end
                end

                if next(KeybindData) then
                    ModuleData.Keybinds = KeybindData
                end
            end

            Data[Flag] = ModuleData
        end

        return Data
    end

    function ConfigSystem:Apply(Data)
        Data = Data or {}

        for ModuleFlag, Module in pairs(Library.Modules or {}) do
            local ModuleData = Data[ModuleFlag]
            if ModuleData and ModuleData.Enabled ~= nil then
                Module:SetEnabled(ModuleData.Enabled)
            else
                Module:SetEnabled(false)
            end
        end

        local AppliedToggles = {}

        for ModuleFlag, ModuleData in pairs(Data) do
            if ModuleData.Toggles then
                for ToggleFlag, State in pairs(ModuleData.Toggles) do
                    AppliedToggles[ToggleFlag] = true
                    Library.Flags[ToggleFlag] = State

                    if Library.ToggleMap and Library.ToggleMap[ToggleFlag] then
                        Library.ToggleMap[ToggleFlag]:Set(State)
                    end
                end
            end

            if ModuleData.Sliders then
                for SliderFlag, SliderData in pairs(ModuleData.Sliders) do
                    if Library.SliderMap and Library.SliderMap[SliderFlag] then
                        local SliderInstance = Library.SliderMap[SliderFlag]

                        if type(SliderData) == "table" then
                            SliderInstance:SetValue(SliderData.Value)
                            SliderInstance:SetMinimum(SliderData.MinValue)
                            Library.Flags[SliderFlag] = {Min = SliderData.MinValue, Max = SliderData.Value}
                        else
                            SliderInstance:SetValue(SliderData)
                            Library.Flags[SliderFlag] = SliderData
                        end
                    else
                        Library.Flags[SliderFlag] = type(SliderData) == "table" and {Min = SliderData.MinValue, Max = SliderData.Value} or SliderData
                    end
                end
            end

            if ModuleData.Carousels then
                for CarouselFlag, Value in pairs(ModuleData.Carousels) do
                    Library.Flags[CarouselFlag] = Value

                    if Library.CarouselMap and Library.CarouselMap[CarouselFlag] then
                        local CarouselInstance = Library.CarouselMap[CarouselFlag]
                        local Values = CarouselInstance.Values

                        for Index, OptionName in ipairs(Values) do
                            if OptionName == Value then
                                CarouselInstance:SetValue(Index)
                                break
                            end
                        end
                    end
                end
            end

            if ModuleData.Dropdowns then
                for DropdownFlag, Value in pairs(ModuleData.Dropdowns) do
                    if Library.DropdownMap and Library.DropdownMap[DropdownFlag] then
                        local DropdownInstance = Library.DropdownMap[DropdownFlag]

                        if DropdownInstance.IsMulti then
                            DropdownInstance:SetSelected(type(Value) == "table" and Value or {})
                        else
                            DropdownInstance:SetValue(Value)
                        end
                    else
                        Library.Flags[DropdownFlag] = Value
                    end
                end
            end

            if ModuleData.ColorPickers then
                for ColorFlag, Data in pairs(ModuleData.ColorPickers) do
                    if Library.ColorPickerMap and Library.ColorPickerMap[ColorFlag] then
                        local Color = Color3.fromRGB(
                            Data.R or 255,
                            Data.G or 255,
                            Data.B or 255
                        )
                        Library.ColorPickerMap[ColorFlag]:SetValue(Color)
                        Library.Flags[ColorFlag] = Color
                    end
                end
            end

            if ModuleData.TextBoxes then
                for TextBoxFlag, Value in pairs(ModuleData.TextBoxes) do
                    if Library.TextBoxMap and Library.TextBoxMap[TextBoxFlag] then
                        Library.TextBoxMap[TextBoxFlag]:SetText(Value)
                        Library.Flags[TextBoxFlag] = Value
                    end
                end
            end

            if ModuleData.Keybinds then
                for KeybindFlag, KeyName in pairs(ModuleData.Keybinds) do
                    if Library.KeybindMap and Library.KeybindMap[KeybindFlag] then
                        if KeyName and KeyName ~= "" then
                            local KeyItem = Enum.KeyCode[KeyName] or Enum.UserInputType[KeyName]
                            if KeyItem then
                                Library.KeybindMap[KeybindFlag]:SetKey(KeyItem)
                            end
                        else
                            Library.KeybindMap[KeybindFlag]:SetKey(nil)
                        end
                    end
                end
            end
        end

        for ToggleFlag, Toggle in pairs(Library.ToggleMap or {}) do
            if not AppliedToggles[ToggleFlag] then
                Library.Flags[ToggleFlag] = false
                Toggle:Set(false)
            end
        end

        if Library.LoadStyle then
            Library:LoadStyle()
            Library:SetTheme(Library.CurrentTheme)
            Library:SetAccent(Library.CurrentAccent)
        end
    end

    function ConfigSystem:Prettify(Table)
        local function Encode(Value, Indent)
            Indent = Indent or 0
            local Spacing = string.rep("    ", Indent)
            local NextSpacing = string.rep("    ", Indent + 1)

            if type(Value) == "table" then
                local IsArray = (#Value > 0)
                local Result = "{\n"

                for Key, Val in pairs(Value) do
                    local FormattedKey = IsArray and "" or ('"' .. tostring(Key) .. '": ')
                    Result = Result .. NextSpacing .. FormattedKey .. Encode(Val, Indent + 1) .. ",\n"
                end

                Result = Result:sub(1, -3) .. "\n" .. Spacing .. "}"
                return Result
            elseif type(Value) == "string" then
                local Escaped = Value:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
                return '"' .. Escaped .. '"'
            elseif type(Value) == "boolean" or type(Value) == "number" then
                return tostring(Value)
            else
                return 'null'
            end
        end

        return Encode(Table, 0)
    end

    function ConfigSystem:Save(Name, Description)
        local Path = self:GetPath(Name)
        local Data = self:Build()
        local Encoded = self:Prettify(Data)

        local Comment = Description and ("-- " .. Description .. "\n") or ""

        FileManager:WriteFile(Path, Comment .. Encoded)
    end

    function ConfigSystem:Load(Name)
        local Path = self:GetPath(Name)

        if not FileManager:IsFile(Path) then
            return
        end

        local Raw = FileManager:ReadFile(Path)

        while Raw:match("^%s*%-%-") do
            Raw = Raw:gsub("^%s*%-%-[^\n]*\n?", "")
        end

        local Success, Decoded = pcall(function()
            return HttpService:JSONDecode(Raw)
        end)

        if Success and Decoded then
            self:Apply(Decoded)
        end
    end

    function ConfigSystem:List()
        local Files = FileManager:ListFiles(self.BasePath)
        local Results = {}

        for _, File in ipairs(Files) do
            local Name = File:match("([^/]+)%.cfg$")
            if Name then
                table.insert(Results, Name)
            end
        end

        return Results
    end

    function ConfigSystem:Delete(Name)
        local Path = self:GetPath(Name)

        if FileManager:IsFile(Path) then
            delfile(Path)
        end
    end

    function ConfigSystem:GetAutoLoadPath()
        return self.BasePath .. "/AutoLoad.txt"
    end

    function ConfigSystem:SetAutoLoad(Name)
        local Path = self:GetAutoLoadPath()
        FileManager:WriteFile(Path, Name or "")
    end

    function ConfigSystem:GetAutoLoad()
        local Path = self:GetAutoLoadPath()

        if FileManager:IsFile(Path) then
            local Name = FileManager:ReadFile(Path)
            return Name ~= "" and Name or nil
        end

        return nil
    end

    ConfigSystem:Init()

    local Auto = ConfigSystem:GetAutoLoad()
    if Auto and Auto ~= "" then
        Library.LoadConfig = Auto
        Library.CurrentConfig = Auto

        task.spawn(function()
            local StableTime = 0
            local LastModuleCount = 0
            local LastFlagCount = 0

            while StableTime < 5 do
                task.wait(0.1)

                local ModuleCount = 0
                local FlagCount = 0

                for _ in pairs(Library.Modules or {}) do
                    ModuleCount += 1
                end

                for _ in pairs(Library.Flags or {}) do
                    FlagCount += 1
                end

                if ModuleCount == LastModuleCount and FlagCount == LastFlagCount and ModuleCount > 0 then
                    StableTime += 1
                else
                    StableTime = 0
                    LastModuleCount = ModuleCount
                    LastFlagCount = FlagCount
                end
            end

            ConfigSystem:Load(Auto)

            if Library.LoadStyle then
                Library:LoadStyle()
                Library:SetTheme(Library.CurrentTheme)
                Library:SetAccent(Library.CurrentAccent)
            end
        end)
    end

    return ConfigSystem
end

return NewConfigSystem

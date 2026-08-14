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

-- Minimal Base64 codec (works on any executor, no dependencies)
local Base64Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function Base64Encode(Value)
    local Result = {}

    for Index = 1, #Value, 3 do
        local B1 = Value:byte(Index) or 0
        local B2 = Value:byte(Index + 1) or 0
        local B3 = Value:byte(Index + 2) or 0

        local N = B1 * 65536 + B2 * 256 + B3

        Result[#Result + 1] = Base64Chars:sub(N // 262144 + 1, N // 262144 + 1)
        Result[#Result + 1] = Base64Chars:sub(N // 4096 % 64 + 1, N // 4096 % 64 + 1)
        Result[#Result + 1] = Base64Chars:sub(N // 64 % 64 + 1, N // 64 % 64 + 1)
        Result[#Result + 1] = Base64Chars:sub(N % 64 + 1, N % 64 + 1)
    end

    local Padding = #Value % 3
    if Padding == 1 then
        Result[#Result - 1] = "="
        Result[#Result] = "="
    elseif Padding == 2 then
        Result[#Result] = "="
    end

    return table.concat(Result)
end

local function Base64Decode(Value)
    Value = tostring(Value):gsub("%s", "")

    local Data = {}
    for Index = 1, #Value do
        local Pos = Base64Chars:find(Value:sub(Index, Index), 1, true)
        Data[Index] = (Pos and Pos - 1) or 0
    end

    local Result = {}
    for Index = 1, #Value, 4 do
        local N = (Data[Index] or 0) * 262144
            + (Data[Index + 1] or 0) * 4096
            + (Data[Index + 2] or 0) * 64
            + (Data[Index + 3] or 0)

        if Index + 2 <= #Value then
            Result[#Result + 1] = string.char(N // 65536)
        end
        if Index + 3 <= #Value then
            Result[#Result + 1] = string.char(N // 256 % 256)
        end
        if Index + 4 <= #Value then
            Result[#Result + 1] = string.char(N % 256)
        end
    end

    return table.concat(Result)
end

local function CopyToClipboard(Text)
    local Ok, Err = pcall(function()
        if setclipboard then
            setclipboard(Text)
        elseif toclipboard then
            toclipboard(Text)
        elseif set_clipboard then
            set_clipboard(Text)
        else
            error("no clipboard function available")
        end
    end)

    return Ok, Err
end

local function NewConfigSystem(Library)
    local ConfigSystem = {}

    ConfigSystem.BasePath = "RiseV6UI/Configs/" .. tostring(game.GameId)

    -- Current schema version. Older files are migrated through ConfigSystem.Migrations.
    ConfigSystem.SchemaVersion = 2
    ConfigSystem.Migrations = {
        -- v1 -> v2: old files had no Version field. Normalize keybind entries so
        -- the migration pipeline has a clean baseline for future schema changes.
        [2] = function(Data)
            for ModuleFlag, ModuleData in pairs(Data) do
                if type(ModuleData) == "table" and type(ModuleData.Keybinds) == "table" then
                    for KeyFlag, Key in pairs(ModuleData.Keybinds) do
                        if type(Key) ~= "string" then
                            ModuleData.Keybinds[KeyFlag] = ""
                        end
                    end
                end
            end
            return Data
        end,
    }

    -- Auto-save: enabled by default; saves into the active profile 1.5s
    -- after the last flag change (debounced).
    ConfigSystem.AutoSaveEnabled = true
    ConfigSystem.AutoSaveName = nil
    ConfigSystem.AutoSaveDebounce = nil
    ConfigSystem.CurrentProfile = nil

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

        local Wrapped = {
            Version = self.SchemaVersion,
            Description = Description or "",
            Config = Data
        }

        FileManager:WriteFile(Path, HttpService:JSONEncode(Wrapped))

        self.CurrentProfile = Name
        self.AutoSaveName = Name
    end

    -- Strips legacy "-- description" comment lines from old-format files
    function ConfigSystem:SanitizeRaw(Raw)
        while Raw:match("^%s*%-%-") do
            Raw = Raw:gsub("^%s*%-%-[^\n]*\n?", "")
        end
        return Raw
    end

    -- Migrates config data from an older schema to the current one
    function ConfigSystem:Migrate(Data, FromVersion)
        for Version = FromVersion + 1, self.SchemaVersion do
            local Migration = self.Migrations[Version]
            if Migration then
                local Result = Migration(Data)
                if Result then
                    Data = Result
                end
            end
        end
        return Data
    end

    function ConfigSystem:Load(Name)
        local Path = self:GetPath(Name)

        if not FileManager:IsFile(Path) then
            return
        end

        local Raw = self:SanitizeRaw(FileManager:ReadFile(Path))

        local Success, Decoded = pcall(function()
            return HttpService:JSONDecode(Raw)
        end)

        if not (Success and Decoded) then
            return
        end

        -- New format: { Version, Description, Config = ... }.
        -- Old format: the config table is the file root itself (v1).
        local Version = tonumber(Decoded.Version) or 1
        local Data = Decoded.Config or Decoded

        if Version < self.SchemaVersion then
            Data = self:Migrate(Data, Version)
        end

        self:Apply(Data)
        self.CurrentProfile = Name
        self.AutoSaveName = Name

        if Library then
            Library.CurrentConfig = Name
        end
    end

    -- Reads the header of a saved config (description + schema version)
    function ConfigSystem:GetInfo(Name)
        local Path = self:GetPath(Name)

        if not FileManager:IsFile(Path) then
            return {}
        end

        local Raw = self:SanitizeRaw(FileManager:ReadFile(Path))

        local Success, Decoded = pcall(function()
            return HttpService:JSONDecode(Raw)
        end)

        if Success and type(Decoded) == "table" then
            return {
                Description = Decoded.Config and (Decoded.Description or "") or "",
                Version = tonumber(Decoded.Version) or 1
            }
        end

        return {}
    end

    -- ── Auto-save (debounced) ─────────────────────────────────────────────
    function ConfigSystem:SetAutoSave(State)
        self.AutoSaveEnabled = State == true

        if self.AutoSaveEnabled then
            self:ScheduleSave()
        end
    end

    function ConfigSystem:ScheduleSave()
        if self.AutoSaveEnabled == false then return end

        if self.AutoSaveDebounce then
            task.cancel(self.AutoSaveDebounce)
            self.AutoSaveDebounce = nil
        end

        self.AutoSaveDebounce = task.delay(1.5, function()
            self.AutoSaveDebounce = nil
            self:Save(self.AutoSaveName or self.CurrentProfile or "Default")
        end)
    end

    -- ── Profiles ──────────────────────────────────────────────────────────
    function ConfigSystem:SwitchProfile(Name)
        if Name == nil or Name == "" then return end

        self:SetAutoLoad(Name)
        self.CurrentProfile = Name
        self.AutoSaveName = Name

        if Library then
            Library.LoadConfig = Name
            Library.CurrentConfig = Name
        end

        self:Load(Name)
    end

    -- ── Sharing: export/import as a Base64 string ─────────────────────────
    function ConfigSystem:Export(Name)
        Name = Name or self.CurrentProfile or "Default"

        local Info = self:GetInfo(Name)
        local Packed = {
            Version = self.SchemaVersion,
            Name = Name,
            Description = Info.Description or "",
            Config = self:Build()
        }

        return Base64Encode(HttpService:JSONEncode(Packed))
    end

    -- Copies the shareable code to the clipboard; returns the code itself
    function ConfigSystem:CopyExport(Name)
        local Code = self:Export(Name)
        local Ok, Err = CopyToClipboard(Code)

        if Ok then
            return Code
        end

        return nil, Err
    end

    function ConfigSystem:Import(Code)
        local Ok, Json = pcall(Base64Decode, Code)
        if not Ok or not Json or Json == "" then
            return false
        end

        local Success, Decoded = pcall(function()
            return HttpService:JSONDecode(Json)
        end)
        if not (Success and type(Decoded) == "table") then
            return false
        end

        local Version = tonumber(Decoded.Version) or 1
        local Data = Decoded.Config or Decoded

        if Version < self.SchemaVersion then
            Data = self:Migrate(Data, Version)
        end

        self:Apply(Data)

        local Name = tostring(Decoded.Name or "Imported")
        self:Save(Name, Decoded.Description or "")
        self:SetAutoLoad(Name)

        if Library then
            Library.CurrentConfig = Name
        end

        return true
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

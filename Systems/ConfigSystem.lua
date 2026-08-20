-- Fast pure-Luau JSON codec
-- HttpService:JSONEncode/JSONDecode are slow inside executors (often a
-- pure-Lua implementation that takes multiple seconds on large configs),
-- and string-concat pretty printers are O(n^2). This codec is single-pass
-- with table.concat buffering: linear time, identical output format.

local JsonEscapes = {
    ['"'] = '\\"',
    ['\\'] = '\\\\',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
}

local function JsonEncode(Value, Compact)
    local Buffer = {}
    local Count = 0

    local function Push(Text)
        Count = Count + 1
        Buffer[Count] = Text
    end

    local function Encode(Value, Indent)
        local ValueType = type(Value)

        if ValueType == "table" then
            local IsArray = (#Value > 0)
            local Padding = ""
            local NextPadding = ""

            if not Compact then
                Padding = string.rep("    ", Indent)
                NextPadding = string.rep("    ", Indent + 1)
            end

            local Entries = 0
            for _, Item in pairs(Value) do
                if Item ~= nil then
                    Entries = Entries + 1
                end
            end

            if Entries == 0 then
                Push(IsArray and "[]" or "{}")
                return
            end

            Push(IsArray and "[" or "{")
            if not Compact then
                Push("\n")
            end

            local Written = 0
            for Key, Item in pairs(Value) do
                if Item ~= nil then
                    if Written > 0 then
                        Push(",")
                        if not Compact then
                            Push("\n")
                        end
                    end
                    Written = Written + 1

                    if not Compact then
                        Push(NextPadding)
                    end

                    if not IsArray then
                        Push('"' .. tostring(Key):gsub('["\\\n\r\t\b\f]', JsonEscapes) .. '"')
                        Push(Compact and ":" or ": ")
                    end

                    Encode(Item, Indent + 1)
                end
            end

            if not Compact then
                Push("\n" .. Padding)
            end
            Push(IsArray and "]" or "}")
        elseif ValueType == "string" then
            Push('"' .. Value:gsub('["\\\n\r\t\b\f]', JsonEscapes) .. '"')
        elseif ValueType == "number" then
            if Value ~= Value or Value == math.huge or Value == -math.huge then
                Push("0")
            else
                Push(tostring(Value))
            end
        elseif ValueType == "boolean" then
            Push(Value and "true" or "false")
        else
            Push("null")
        end
    end

    Encode(Value, 0)
    return table.concat(Buffer)
end

local function JsonDecode(Text)
    Text = tostring(Text)
    local Length = #Text
    local Position = 1

    local function SkipWhitespace()
        while Position <= Length do
            local Char = Text:byte(Position)
            if Char == 32 or Char == 9 or Char == 10 or Char == 13 then
                Position = Position + 1
            else
                return
            end
        end
    end

    local function ParseString(Start)
        local Chunks = {}
        local ChunkCount = 0
        Position = Start + 1

        while Position <= Length do
            local ChunkStart = Position
            local NextPos = Text:find('["\\]', Position)

            if not NextPos then
                return nil
            end

            if Text:byte(NextPos) == 34 then -- closing "
                if NextPos > ChunkStart then
                    ChunkCount = ChunkCount + 1
                    Chunks[ChunkCount] = Text:sub(ChunkStart, NextPos - 1)
                end
                Position = NextPos + 1
                return table.concat(Chunks)
            end

            -- escape sequence at NextPos
            if NextPos > ChunkStart then
                ChunkCount = ChunkCount + 1
                Chunks[ChunkCount] = Text:sub(ChunkStart, NextPos - 1)
            end

            local EscChar = Text:byte(NextPos + 1)
            local Escaped = EscChar and ({
                [34] = '"',
                [47] = "/",
                [92] = "\\",
                [98] = "\b",
                [102] = "\f",
                [110] = "\n",
                [114] = "\r",
                [116] = "\t",
            })[EscChar]

            if Escaped then
                ChunkCount = ChunkCount + 1
                Chunks[ChunkCount] = Escaped
                Position = NextPos + 2
            elseif EscChar == 117 then -- 'u'
                local Code = tonumber(Text:sub(NextPos + 2, NextPos + 5), 16)
                Position = NextPos + 6

                if Code and Code >= 0xD800 and Code <= 0xDBFF then
                    if Text:sub(NextPos + 6, NextPos + 7) == "\\u" then
                        local Low = tonumber(Text:sub(NextPos + 8, NextPos + 11), 16)
                        if Low and Low >= 0xDC00 and Low <= 0xDFFF then
                            Code = 0x10000 + (Code - 0xD800) * 0x400 + (Low - 0xDC00)
                            Position = NextPos + 12
                        end
                    end
                end

                if Code then
                    local Ok, Char8 = pcall(utf8.char, Code)
                    if Ok then
                        ChunkCount = ChunkCount + 1
                        Chunks[ChunkCount] = Char8
                    end
                end
            else
                return nil
            end
        end

        return nil
    end

    local function ParseValue()
        SkipWhitespace()
        if Position > Length then
            return nil, false
        end

        local Char = Text:byte(Position)

        if Char == 34 then -- "
            local String = ParseString(Position)
            if String == nil then
                return nil, false
            end
            return String, true
        end

        if Char == 123 or Char == 91 then -- { or [
            local IsObject = Char == 123
            local Result = {}
            local Count = 0
            Position = Position + 1
            SkipWhitespace()

            if Text:byte(Position) == (IsObject and 125 or 93) then -- } or ]
                Position = Position + 1
                return Result, true
            end

            while true do
                if IsObject then
                    SkipWhitespace()
                    local Key = ParseString(Position)
                    if Key == nil then
                        return nil, false
                    end
                    SkipWhitespace()
                    if Text:byte(Position) ~= 58 then -- :
                        return nil, false
                    end
                    Position = Position + 1

                    local Item, ItemOk = ParseValue()
                    if not ItemOk then
                        return nil, false
                    end
                    Result[Key] = Item
                else
                    local Item, ItemOk = ParseValue()
                    if not ItemOk then
                        return nil, false
                    end
                    Count = Count + 1
                    Result[Count] = Item
                end

                SkipWhitespace()
                local NextByte = Text:byte(Position)
                if NextByte == 44 then -- ,
                    Position = Position + 1
                elseif NextByte == (IsObject and 125 or 93) then
                    Position = Position + 1
                    return Result, true
                else
                    return nil, false
                end
            end
        end

        if Char == 45 or (Char >= 48 and Char <= 57) then -- number
            local Start = Position
            Position = Position + 1

            while Position <= Length do
                local Byte = Text:byte(Position)
                if (Byte >= 48 and Byte <= 57) or Byte == 45 or Byte == 43 or Byte == 46 or Byte == 101 or Byte == 69 then
                    Position = Position + 1
                else
                    break
                end
            end

            local Number = tonumber(Text:sub(Start, Position - 1))
            if Number == nil then
                return nil, false
            end
            return Number, true
        end

        if Char == 116 then -- true
            if Text:sub(Position, Position + 3) == "true" then
                Position = Position + 4
                return true, true
            end
        elseif Char == 102 then -- false
            if Text:sub(Position, Position + 4) == "false" then
                Position = Position + 5
                return false, true
            end
        elseif Char == 110 then -- null
            if Text:sub(Position, Position + 3) == "null" then
                Position = Position + 4
                return nil, true
            end
        end

        return nil, false
    end

    local Result, Ok = ParseValue()
    if not Ok then
        return nil
    end
    SkipWhitespace()
    if Position <= Length then
        return nil
    end
    return Result
end

local function SameValue(A, B)
    if A == B then
        return true
    end

    if type(A) == "table" and type(B) == "table" then
        local Count = 0

        for Key, Value in pairs(A) do
            Count = Count + 1
            if B[Key] ~= Value then
                return false
            end
        end

        for Key in pairs(B) do
            Count = Count - 1
            if Count < 0 then
                return false
            end
        end

        return Count == 0
    end

    return false
end

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

local Base64Map = {}
for Index = 1, #Base64Chars do
    Base64Map[Base64Chars:byte(Index, Index)] = Index - 1
end

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
    Value = tostring(Value or "")
	Value = Value:gsub("^%s*```[%w_%-]*%s*", ""):gsub("%s*```%s*$", "")
	Value = Value:match("^%s*['\"](.-)['\"]%s*$") or Value
	Value = Value:gsub("%s", ""):gsub("%-", "+"):gsub("_", "/")
	if Value == "" or #Value % 4 == 1 or Value:find("[^A-Za-z0-9+/=]") or Value:find("=[^=]") then
		error("invalid base64")
	end

    local Decoded = {}
    local Buffer = 0
    local Bits = 0

    for Index = 1, #Value do
        local Byte = Value:byte(Index, Index)
        if Byte == 61 then -- '='
            break
        end

        local Digit = Base64Map[Byte]
        if Digit then
            Buffer = Buffer * 64 + Digit
            Bits = Bits + 6

            if Bits >= 8 then
                Bits = Bits - 8
                Decoded[#Decoded + 1] = string.char(math.floor(Buffer / (2 ^ Bits)) % 256)
				Buffer = Buffer % (2 ^ Bits)
            end
		else
			error("invalid base64")
        end
    end

    return table.concat(Decoded)
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

    -- Auto-save: enabled by default; saves into the active profile shortly
    -- after the last flag change. Uses ONE persistent heartbeat loop with a
    -- dirty flag instead of task.delay/cancel per flag write (thread churn
    -- is what makes executors lag).
    ConfigSystem.AutoSaveEnabled = true
    ConfigSystem.AutoSaveName = nil
    ConfigSystem.CurrentProfile = nil
    ConfigSystem.AutoSaveDirty = false
    ConfigSystem.AutoSaveInterval = 2.5
    ConfigSystem.AutoSaveReady = false
    ConfigSystem.DefaultAutoSaveName = "Autosave"

    -- Last serialized payload per profile: identical saves skip disk I/O.
    -- Executor writefile is slow and blocks the game thread, so avoiding
    -- redundant writes is what keeps save clicks instant.
    ConfigSystem.LastWrites = {}
    ConfigSystem.LastAutoLoad = nil

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
                        local CurrentValue, CurrentMinimum = SliderInstance:GetValue()

                        if type(SliderData) == "table" then
                            if CurrentValue ~= SliderData.Value then
                                SliderInstance:SetValue(SliderData.Value)
                            end
                            if CurrentMinimum ~= SliderData.MinValue then
                                SliderInstance:SetMinimum(SliderData.MinValue)
                            end
                            Library.Flags[SliderFlag] = {Min = SliderData.MinValue, Max = SliderData.Value}
                        else
                            if CurrentValue ~= SliderData then
                                SliderInstance:SetValue(SliderData)
                            end
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

                        if CarouselInstance:GetValue() ~= Value then
                            for Index, OptionName in ipairs(CarouselInstance.Values) do
                                if OptionName == Value then
                                    CarouselInstance:SetValue(Index)
                                    break
                                end
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
                            if not SameValue(DropdownInstance:GetSelected() or {}, Value) then
                                DropdownInstance:SetSelected(type(Value) == "table" and Value or {})
                            end
                        else
                            if DropdownInstance:GetValue() ~= Value then
                                DropdownInstance:SetValue(Value)
                            end
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
                        local ColorInstance = Library.ColorPickerMap[ColorFlag]
                        if ColorInstance:GetValue() ~= Color then
                            ColorInstance:SetValue(Color)
                        end
                        Library.Flags[ColorFlag] = Color
                    end
                end
            end

            if ModuleData.TextBoxes then
                for TextBoxFlag, Value in pairs(ModuleData.TextBoxes) do
                    if Library.TextBoxMap and Library.TextBoxMap[TextBoxFlag] then
                        local TextBoxInstance = Library.TextBoxMap[TextBoxFlag]
                        if TextBoxInstance:GetText() ~= Value then
                            TextBoxInstance:SetText(Value)
                        end
                        Library.Flags[TextBoxFlag] = Value
                    end
                end
            end

            if ModuleData.Keybinds then
                for KeybindFlag, KeyName in pairs(ModuleData.Keybinds) do
                    if Library.KeybindMap and Library.KeybindMap[KeybindFlag] then
                        local KeybindInstance = Library.KeybindMap[KeybindFlag]

                        if KeyName and KeyName ~= "" then
                            local KeyItem = Enum.KeyCode[KeyName] or Enum.UserInputType[KeyName]
                            if KeyItem and KeybindInstance:GetKey() ~= KeyItem then
                                KeybindInstance:SetKey(KeyItem)
                            end
                        elseif KeybindInstance:GetKey() ~= nil then
                            KeybindInstance:SetKey(nil)
                        end
                    end
                end
            end
        end

        for ToggleFlag, Toggle in pairs(Library.ToggleMap or {}) do
            local IsInternalConfigFlag = tostring(ToggleFlag):match("^Configs%.") ~= nil
            if not AppliedToggles[ToggleFlag] and not IsInternalConfigFlag then
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

    function ConfigSystem:Save(Name, Description)
        local Path = self:GetPath(Name)
        local Data = self:Build()

        local Wrapped = {
            Version = self.SchemaVersion,
            Description = Description or "",
            Config = Data
        }

        local Json = JsonEncode(Wrapped)

        -- Skip the disk write entirely when the payload is byte-identical
        -- to the last one we wrote for this profile.
        if self.LastWrites[Name] ~= Json then
            FileManager:WriteFile(Path, Json)
            self.LastWrites[Name] = Json
        end

        self.CurrentProfile = Name
        self.AutoSaveName = Name
        self.AutoSaveDirty = false
        if Library then
            Library.LoadConfig = Name
            Library.CurrentConfig = Name
        end
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

        local Decoded = JsonDecode(Raw)
        if type(Decoded) ~= "table" then
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
            Library.LoadConfig = Name
            Library.CurrentConfig = Name
        end
        self.AutoSaveDirty = false
        return true
    end

    -- Reads the header of a saved config (description + schema version)
    function ConfigSystem:GetInfo(Name)
        local Path = self:GetPath(Name)

        if not FileManager:IsFile(Path) then
            return {}
        end

        local Raw = self:SanitizeRaw(FileManager:ReadFile(Path))

        local Decoded = JsonDecode(Raw)
        if type(Decoded) == "table" then
            return {
                Description = Decoded.Config and (Decoded.Description or "") or "",
                Version = tonumber(Decoded.Version) or 1
            }
        end

        return {}
    end

    -- Auto-save (single heartbeat and dirty flag)
    function ConfigSystem:SetAutoSave(State)
        self.AutoSaveEnabled = State == true

        if self.AutoSaveEnabled then
            self:ScheduleSave()
        end
    end

    -- Called on every flag change. Just flips a flag: no threads, no I/O.
    function ConfigSystem:ScheduleSave()
        self.AutoSaveDirty = true
    end

    function ConfigSystem:StartAutoSaveLoop()
        task.spawn(function()
            while true do
                task.wait(self.AutoSaveInterval)

                if self.AutoSaveReady and self.AutoSaveEnabled ~= false and self.AutoSaveDirty then
                    self.AutoSaveDirty = false
                    local Ok = pcall(function()
                        self:Save(self.AutoSaveName or self.CurrentProfile or self.DefaultAutoSaveName)
                    end)
                    if not Ok then
                        self.AutoSaveDirty = true
                    end
                end
            end
        end)
    end

    -- Profiles
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

    -- Sharing: export/import as a Base64 string
    function ConfigSystem:Export(Name)
        Name = Name or self.CurrentProfile or "Default"

        local Info = self:GetInfo(Name)
        local Packed = {
            Version = self.SchemaVersion,
            Name = Name,
            Description = Info.Description or "",
            Config = self:Build()
        }

        return Base64Encode(JsonEncode(Packed, true))
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

        local DecodeOk, Decoded = pcall(JsonDecode, Json)
        if not DecodeOk or type(Decoded) ~= "table" then
            return false
        end

        local Version = tonumber(Decoded.Version) or 1
        local Data = Decoded.Config or Decoded
		if type(Data) ~= "table" then
			return false
		end

        if Version < self.SchemaVersion then
            Data = self:Migrate(Data, Version)
        end

		local ImportOk = pcall(function()
			self:Apply(Data)

			local Name = tostring(Decoded.Name or "Imported")
			Name = Name:gsub("[<>:%\"/\\|%?%*]", "_"):sub(1, 64)
			if Name == "" then Name = "Imported" end
			self:Save(Name, Decoded.Description or "")
			self:SetAutoLoad(Name)

			if Library then
				Library.LoadConfig = Name
				Library.CurrentConfig = Name
			end
		end)

		return ImportOk
    end

    function ConfigSystem:List()
        local Files = FileManager:ListFiles(self.BasePath)
        local Results = {}

        for _, File in ipairs(Files) do
            local Name = File:match("([^/\\]+)%.cfg$")
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

        if self:GetAutoLoad() == Name or self.CurrentProfile == Name then
            local Fallback = self.DefaultAutoSaveName
            self:SetAutoLoad(Fallback)
            self.CurrentProfile = Fallback
            self.AutoSaveName = Fallback
            self.AutoSaveDirty = true
            if Library then
                Library.LoadConfig = Fallback
                Library.CurrentConfig = Fallback
            end
        end
    end

    function ConfigSystem:GetAutoLoadPath()
        return self.BasePath .. "/AutoLoad.txt"
    end

    function ConfigSystem:SetAutoLoad(Name)
        Name = Name or ""

        if self.LastAutoLoad == Name then
            return
        end

        self.LastAutoLoad = Name

        local Path = self:GetAutoLoadPath()
        FileManager:WriteFile(Path, Name)
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
    local Auto = ConfigSystem:GetAutoLoad() or ConfigSystem.DefaultAutoSaveName
    ConfigSystem:SetAutoLoad(Auto)
    ConfigSystem.CurrentProfile = Auto
    ConfigSystem.AutoSaveName = Auto
    Library.LoadConfig = Auto
    Library.CurrentConfig = Auto
    ConfigSystem:StartAutoSaveLoop()

    task.spawn(function()
            local StableTime = 0
            local LastModuleCount = 0
            local LastFlagCount = 0
            local ReadyDeadline = os.clock() + 10

            while StableTime < 5 and os.clock() < ReadyDeadline do
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

            if not ConfigSystem:Load(Auto) then
                ConfigSystem:Save(Auto)
            end
            ConfigSystem.AutoSaveDirty = false
            ConfigSystem.AutoSaveReady = true

            if Library.LoadStyle then
                Library:LoadStyle()
                Library:SetTheme(Library.CurrentTheme)
                Library:SetAccent(Library.CurrentAccent)
            end
        end)

    return ConfigSystem
end

return NewConfigSystem

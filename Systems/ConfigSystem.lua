local HttpService = game:GetService("HttpService")

local FileManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/AmuletOfTheSea/RiseV6UI/main/Systems/FileManager.lua"))()

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
        local AppliedCarousels = {}
        local AppliedSliders = {}

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
                    AppliedSliders[SliderFlag] = true

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
                    AppliedCarousels[CarouselFlag] = true
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
                return '"' .. Value .. '"'
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

        Raw = Raw:gsub("^%-%-.-\n", "")

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

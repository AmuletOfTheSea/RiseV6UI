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

local function AssetLoader()
    local VersionPath = "RiseV6UI/.version"

    local function BuildAssetLoader()
        local AssetLoader = {
            Cache = {},
            Roots = {
                "RiseV6UI/Assets/"
            }
        }

        local function ResolvePath(Path)
            for _, Root in ipairs(AssetLoader.Roots) do
                local FullPath = Root .. Path
                if FileManager:IsFile(FullPath) then
                    return FullPath
                end
            end
        end

        local function ConvertAsset(FullPath)
            if AssetLoader.Cache[FullPath] then
                return AssetLoader.Cache[FullPath]
            end

            local AssetId
            for Index = 1, 3 do
                local Success, Result = pcall(function()
                    return (getcustomasset and getcustomasset(FullPath)) or getsynasset(FullPath)
                end)
                if Success and Result then
                    AssetId = Result
                    break
                end
                task.wait()
            end

            if not AssetId then
                AssetId = (getcustomasset and getcustomasset(FullPath)) or getsynasset(FullPath)
            end

            AssetLoader.Cache[FullPath] = AssetId
            return AssetId
        end

        function AssetLoader:GetImage(Path)
            local FullPath = ResolvePath(Path)
            return FullPath and ConvertAsset(FullPath)
        end

        function AssetLoader:GetSound(Path)
            local FullPath = ResolvePath(Path)
            return FullPath and ConvertAsset(FullPath)
        end

        function AssetLoader:GetFont(FontName)
            local TtfPath = "RiseV6UI/Assets/Fonts/" .. FontName
            if not TtfPath:lower():match("%.ttf$") then
                TtfPath = TtfPath .. ".ttf"
            end

            if not FileManager:IsFile(TtfPath) then
                return Font.new("rbxasset://fonts/families/SourceSansPro.json")
            end

            if self.Cache[TtfPath] then
                return self.Cache[TtfPath]
            end

            local AssetId = (getcustomasset and getcustomasset(TtfPath)) or (getsynasset and getsynasset(TtfPath))
            if not AssetId then
                return Font.new("rbxasset://fonts/families/SourceSansPro.json")
            end

            local JsonPath = "RiseV6UI/Assets/Fonts/" .. FontName .. ".json"

            if not FileManager:IsFile(JsonPath) then
                local FontData = {
                    name = FontName,
                    faces = {
                        {
                            name = "Regular",
                            weight = 400,
                            style = "normal",
                            assetId = AssetId
                        }
                    }
                }
                FileManager:WriteFile(JsonPath, HttpService:JSONEncode(FontData))
            end

            local FamilyAssetId = (getcustomasset and getcustomasset(JsonPath)) or (getsynasset and getsynasset(JsonPath))
            if not FamilyAssetId then
                return Font.new("rbxasset://fonts/families/SourceSansPro.json")
            end

            local NewFont = Font.new(FamilyAssetId)
            self.Cache[TtfPath] = NewFont
            return NewFont
        end

        function AssetLoader:LoadModel(Path, Parent)
            local FullPath = ResolvePath(Path)
            if not FullPath then
                return
            end

            local Objects = game:GetObjects(ConvertAsset(FullPath))
            if Objects and Objects[1] then
                Objects[1].Parent = Parent or workspace
                return Objects[1]
            end
        end

        return AssetLoader
    end

    local function HttpGet(Url)
        local Response = request({
            Url = Url,
            Method = "GET",
            Headers = {
                ["User-Agent"] = "Roblox",
                ["Accept"] = "application/vnd.github+json"
            }
        })
        return Response.Body
    end

    local function GetRemoteSHA()
        local Url = "https://api.github.com/repos/AmuletOfTheSea/RiseV6UI/commits/main"
        local Data = HttpService:JSONDecode(HttpGet(Url))
        return Data and Data.sha
    end

    local function GetLocalSHA()
        if FileManager:IsFile(VersionPath) then
            return FileManager:ReadFile(VersionPath)
        end
    end

    local RemoteSHA = GetRemoteSHA()
    local LocalSHA = GetLocalSHA()

    if LocalSHA and RemoteSHA and LocalSHA == RemoteSHA then
        return BuildAssetLoader()
    end

    local function WalkFolder(RepoPath, LocalPath)
        local Url = "https://api.github.com/repos/AmuletOfTheSea/RiseV6UI/contents/" .. RepoPath .. "?ref=main"
        local Items = HttpService:JSONDecode(HttpGet(Url))

        for _, Item in ipairs(Items) do
            local OutputPath = LocalPath .. "/" .. Item.name

            if Item.type == "dir" then
                FileManager:CreateFolder(OutputPath)
                WalkFolder(Item.path, OutputPath)
            elseif Item.type == "file" then
                if not FileManager:IsFile(OutputPath) then
                    FileManager:WriteFile(OutputPath, HttpGet(Item.download_url))
                end
            end
        end
    end

    FileManager:CreateFolder("RiseV6UI/Assets")
    WalkFolder("Assets", "RiseV6UI/Assets")

    local function CreateFontJson(TtfPath)
        TtfPath = FileManager:Normalize(TtfPath)

        if not TtfPath:lower():match("%.ttf$") then
            return
        end

        local Directory, FileName = TtfPath:match("(.+)/([^/]+)$")
        if not Directory or not FileName then
            return
        end

        local BaseName = FileName:gsub("%.ttf$", "")
        local JsonPath = Directory .. "/" .. BaseName .. ".json"

        if FileManager:IsFile(JsonPath) then
            return
        end

        local AssetId = (getcustomasset and getcustomasset(TtfPath)) or (getsynasset and getsynasset(TtfPath))
        if not AssetId then
            return
        end

        local FontData = {
            name = BaseName,
            faces = {
                {
                    name = "Regular",
                    assetId = AssetId,
                    weight = 400,
                    style = "normal"
                }
            }
        }

        FileManager:WriteFile(JsonPath, HttpService:JSONEncode(FontData))
    end

    local function ScanFonts(Root)
        Root = FileManager:Normalize(Root)

        if not FileManager:IsFolder(Root) then
            return
        end

        for _, Item in ipairs(FileManager:ListFiles(Root)) do
            Item = FileManager:Normalize(Item)

            if Item:lower():match("%.ttf$") then
                CreateFontJson(Item)
            elseif not Item:match("%.%w+$") then
                ScanFonts(Item)
            end
        end
    end

    ScanFonts("RiseV6UI/Assets/Fonts")

    local PreloadList = {}

    if FileManager:IsFolder("RiseV6UI/Assets") then
        for _, File in ipairs(FileManager:ListFiles("RiseV6UI/Assets")) do
            if File:match("%.(png|jpg|jpeg|wav|mp3|ogg|json|rbxm|rbxmx|ttf|otf)$") then
                table.insert(PreloadList, File)
            end
        end
    end

    local Loader = BuildAssetLoader()

    for _, File in ipairs(PreloadList) do
        Loader.Cache[File] = (getcustomasset and getcustomasset(File)) or (getsynasset and getsynasset(File))
    end

    if RemoteSHA then
        FileManager:WriteFile(VersionPath, RemoteSHA)
    end

    return Loader
end

return AssetLoader()

local function FileManager()
    local Manager = {}

    function Manager:Normalize(Path)
        return Path:gsub("\\", "/")
    end

    function Manager:Exists(Path)
        Path = self:Normalize(Path)
        return isfile(Path) or isfolder(Path)
    end

    function Manager:IsFile(Path)
        Path = self:Normalize(Path)
        return isfile(Path)
    end

    function Manager:IsFolder(Path)
        Path = self:Normalize(Path)
        return isfolder(Path)
    end

    function Manager:CreateFolder(Path)
        Path = self:Normalize(Path)

        if Path == "" then
            return
        end

        local Parts = Path:split("/")
        local Current = ""

        for _, Part in ipairs(Parts) do
            Current = Current == "" and Part or (Current .. "/" .. Part)

            if not isfolder(Current) then
                makefolder(Current)
            end
        end
    end

    function Manager:WriteFile(Path, Content)
        Path = self:Normalize(Path)

        local Directory = Path:match("(.+)/[^/]+$")
        if Directory then
            self:CreateFolder(Directory)
        end

        writefile(Path, Content)
    end

    function Manager:ReadFile(Path)
        Path = self:Normalize(Path)

        if isfile(Path) then
            return readfile(Path)
        end
    end

    function Manager:ListFiles(Path)
        Path = self:Normalize(Path)

        if not isfolder(Path) then
            return {}
        end

        return listfiles(Path)
    end

    function Manager:GetExtension(Path)
        return Path:match("%.([%w]+)$")
    end

    function Manager:EnsureFile(Path, Content)
        if not self:IsFile(Path) then
            self:WriteFile(Path, Content or "")
        end
    end

    return Manager
end

return FileManager()
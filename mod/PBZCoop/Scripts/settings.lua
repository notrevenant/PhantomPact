-- What the panels remember between game starts: settings.txt in the mod folder (instN for copy N). The mod writes it and
-- reads it; players never need to open it. The F5 panel (online: Host, Guest, Leave, language, MORE) and the F4 panel
-- (local co-op's way back to multiplayer) are the only ways to change a setting. No file yet means the defaults: online
-- co-op off until Host or Guest is pressed.
--
-- One "key=value" a line, keys in lowercase.

return function(api)
    local log = api.log
    local settings = {}

    local function path()
        return api.modDir() .. "settings.txt"
    end

    -- Every setting kept, by lowercase key. Empty when nothing has been saved yet.
    function settings.read()
        local out = {}
        local f = io.open(path(), "r")
        if not f then
            return out
        end
        local text = f:read("a") or ""
        f:close()
        for line in text:gmatch("[^\r\n]+") do
            local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
            if key then
                out[key:lower()] = value
            end
        end
        return out
    end

    -- Keeps these values ({ Role = "Host", Language = "English" }) and every other one as it was. Written whole to a
    -- temporary file and renamed, so a crash mid-write can't leave half a file.
    function settings.save(values)
        local kept = settings.read()
        for key, value in pairs(values) do
            kept[key:lower()] = tostring(value)
        end
        local keys = {}
        for key in pairs(kept) do
            keys[#keys + 1] = key
        end
        table.sort(keys)
        local lines = {}
        for _, key in ipairs(keys) do
            lines[#lines + 1] = key .. "=" .. kept[key] .. "\n"
        end
        local file = path()
        local tmp = io.open(file .. ".tmp", "wb")
        local wrote = tmp and tmp:write(table.concat(lines))
        if tmp then
            tmp:close()
        end
        if not wrote then
            log("Couldn't save settings.txt: this choice lasts until the game closes.")
            return
        end
        os.remove(file)
        if not os.rename(file .. ".tmp", file) then
            log("Couldn't save settings.txt: see settings.txt.tmp in " .. api.modDir())
        end
    end

    return settings
end

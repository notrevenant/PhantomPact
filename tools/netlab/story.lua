-- The game's own story data, read from a running copy: chapters, maps, bells. Loaded with eval.
STORY = STORY or {}
local log, valid = PBZ.log, PBZ.valid

local function str(v)
    if v == nil then return "nil" end
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" then return tostring(v) end
    local ok, s = pcall(function() return v:get():ToString() end)
    if ok and s then return s end
    ok, s = pcall(function() return v:ToString() end)
    if ok and s then return s end
    return t
end
STORY.str = str

function STORY.bm()
    return FindFirstOf("BellManager")
end

local function list(v)
    local out = {}
    if v == nil then return out end
    pcall(function()
        for i = 1, #v do out[#out + 1] = v[i] end
    end)
    if #out == 0 then
        pcall(function() v:ForEach(function(_, x) out[#out + 1] = x end) end)
    end
    return out
end
STORY.list = list

function STORY.chapters()
    local bm = STORY.bm()
    local ids = list(bm:GetAllChapterIDs())
    log("STORY chapters " .. #ids)
    for _, id in ipairs(ids) do
        log("STORY chapter " .. str(id))
    end
    return "STORY done"
end

function STORY.bells()
    local bm = STORY.bm()
    local ids = list(bm:GetAllActivateBellIDs())
    log("STORY active bells " .. #ids)
    for _, id in ipairs(ids) do
        log("STORY bell " .. str(id))
    end
    return "STORY done"
end

function STORY.rows(t)
    local lib = StaticFindObject("/Script/Engine.Default__DataTableFunctionLibrary")
    local out = {}
    lib:GetDataTableRowNames(t, out)
    return out
end

function STORY.tables()
    local s = FindFirstOf("PBZDestinationLoadingSubsystem")
    local bm = STORY.bm()
    for _, f in ipairs({ "BellTable", "MapTable" }) do
        local t = s[f]
        log("STORY table " .. f .. " " .. (valid(t) and t:GetFullName() or "none"))
        if valid(t) then
            local rows = STORY.rows(t)
            log("STORY rows " .. #rows)
            local names = {}
            for i = 1, #rows do names[#names + 1] = str(rows[i]) end
            STORY[f] = names
            log("STORY " .. f .. " " .. table.concat(names, " "):sub(1, 900))
        end
    end
    return "STORY done"
end

-- Every data table in memory whose name matches, and the asset registry's list if it answers.
function STORY.dts(pattern)
    local n, hits = 0, {}
    for _, t in ipairs(FindAllOf("DataTable") or {}) do
        n = n + 1
        local name = t:GetFullName()
        if not pattern or name:lower():find(pattern) then hits[#hits + 1] = name:gsub("^DataTable ", "") end
    end
    table.sort(hits)
    log("STORY tables loaded " .. n .. ", matching " .. #hits)
    for i = 1, math.min(#hits, 60) do log("STORY dt " .. hits[i]) end
    return "STORY done"
end

function STORY.assets(path, recursive)
    local helpers = StaticFindObject("/Script/AssetRegistry.Default__AssetRegistryHelpers")
    local ar = helpers:GetAssetRegistry()
    log("STORY registry " .. tostring(valid(ar)) .. " " .. type(ar))
    local out = {}
    local ok, err = pcall(function() ar:GetAssetsByPath(FName(path), out, recursive ~= false, false) end)
    log("STORY assets ok " .. tostring(ok) .. " " .. tostring(err) .. " n " .. tostring(#out))
    return out
end

local function assetName(a)
    local v = a
    pcall(function() v = a:get() end)
    local ok, pkg = pcall(function() return v.PackageName:ToString() end)
    local ok2, name = pcall(function() return v.AssetName:ToString() end)
    return ok and pkg or "?", ok2 and name or "?"
end

-- Assets under a path whose package name matches, written to a file for reading on the desk.
function STORY.find(path, pattern, file)
    local list = STORY.assets(path)
    local f = io.open(file, "w")
    local n = 0
    for i = 1, #list do
        local pkg, name = assetName(list[i])
        if not pattern or pkg:lower():find(pattern) then
            n = n + 1
            f:write(pkg, " ", name, "\n")
        end
    end
    f:close()
    return "STORY found " .. n .. " of " .. #list
end

STORY.FLOW = "/Game/PBZContent/Blueprint/FlowGraph/DebugUI/FlowQuest/FlowEventTable.FlowEventTable"
STORY.BRANCH = "/Game/PBZContent/Blueprint/FlowGraph/DebugUI/FlowQuest/FlowQuestBranchStateDataTable.FlowQuestBranchStateDataTable"
STORY.POS = "/Game/PBZContent/Blueprint/FlowGraph/DebugUI/FlowLogic/FlowPosEntryTable.FlowPosEntryTable"

function STORY.table(path)
    local t = StaticFindObject(path)
    if not valid(t) then
        t = LoadAsset(path)
    end
    return valid(t) and t or nil
end

-- One data table to a tab-separated file, a column at a time, through the engine's own export.
function STORY.export(path, columns, file)
    local t = STORY.table(path)
    if not t then return "STORY no table " .. path end
    local lib = StaticFindObject("/Script/Engine.Default__DataTableFunctionLibrary")
    local names = STORY.rows(t)
    local cols = {}
    for _, c in ipairs(columns) do
        local ok, v = pcall(function() return lib:GetDataTableColumnAsString(t, FName(c)) end)
        local vals = {}
        if ok and v then
            for i = 1, #v do vals[i] = str(v[i]) end
        else
            log("STORY column failed " .. c .. " " .. tostring(v))
        end
        cols[#cols + 1] = vals
    end
    local f = io.open(file, "w")
    f:write("row\t", table.concat(columns, "\t"), "\n")
    for i = 1, #names do
        local row = { str(names[i]) }
        for j = 1, #cols do row[#row + 1] = cols[j][i] or "" end
        f:write(table.concat(row, "\t"), "\n")
    end
    f:close()
    return "STORY exported " .. #names .. " rows, column sizes " .. #(cols[1] or {})
end

-- Test copies only, in memory: the achievement table is swapped for an empty one, so nothing done by a test can unlock
-- anything on a real Steam account. Has to run again after every start of a copy.
function STORY.noAchievements()
    local sub = FindFirstOf("PBZAchievementSubsystem")
    if not valid(sub) then return "STORY no achievement subsystem" end
    local before = sub.AchievementTable
    local name = valid(before) and before:GetFullName() or "none"
    local rows = valid(before) and STORY.rows(before) or {}
    if #rows == 0 and STORY.emptied then return "STORY achievements already off" end
    local ids = {}
    for i = 1, #rows do ids[#ids + 1] = str(rows[i]) end
    log("STORY achievements in " .. name .. ": " .. #ids .. ": " .. table.concat(ids, " "):sub(1, 700))
    local empty = StaticConstructObject(StaticFindObject("/Script/Engine.DataTable"), sub, FName("PhantomPactTestNoAchievements"))
    if not valid(empty) then return "STORY could not make the empty table" end
    sub.AchievementTable = empty
    STORY.emptied = true
    local after = sub.AchievementTable
    return "STORY achievement table now " .. (valid(after) and after:GetFullName() or "none") .. " rows " .. #STORY.rows(after)
end

-- Does the empty table really stop an unlock? Tried with a name that isn't an achievement, so Steam has nothing to grant.
function STORY.achievementGate()
    local sub = FindFirstOf("PBZAchievementSubsystem")
    local save = sub.Save
    local function ids()
        local out = {}
        pcall(function() save.UnlockedIds:ForEach(function(_, v) out[#out + 1] = str(v) end) end)
        return out
    end
    local before = ids()
    local fake = FName("PP_TEST_NOT_AN_ACHIEVEMENT")
    sub:UnlockAchievement(fake)
    local after = ids()
    local unlocked = "?"
    pcall(function() unlocked = tostring(sub:IsUnlocked(fake)) end)
    return string.format("STORY gate: saved unlocks %d -> %d, fake reads unlocked=%s, save valid=%s", #before, #after, unlocked, tostring(valid(save)))
end

function STORY.saveIds()
    local sub = FindFirstOf("PBZAchievementSubsystem")
    local out = {}
    pcall(function() sub.Save.UnlockedIds:ForEach(function(_, v) out[#out + 1] = str(v) end) end)
    local pend = {}
    pcall(function()
        sub.Save.PlatformPending:ForEach(function(_, v)
            local a = v:get()
            pend[#pend + 1] = "pending"
        end)
    end)
    return "STORY unlocked ids: " .. table.concat(out, " ") .. " | pending " .. #pend
end

function STORY.restoreAchievements()
    local sub = FindFirstOf("PBZAchievementSubsystem")
    local t = STORY.table("/Game/PBZContent/DataTable/DT_Achievement.DT_Achievement")
    if not valid(t) then return "STORY real table not found" end
    sub.AchievementTable = t
    STORY.emptied = false
    return "STORY achievement table back: " .. sub.AchievementTable:GetFullName() .. " rows " .. #STORY.rows(sub.AchievementTable)
end

----------------------------------------------------------------- travel and story jumps

local function nums(s)
    local out = {}
    for n in s:gmatch("=(-?[%d%.]+)") do out[#out + 1] = tonumber(n) end
    return out
end

-- Bell rows: row name -> { id, map, level, x, y, z, t }. Read once a copy.
function STORY.loadBells()
    if STORY.bellData then return STORY.bellData end
    local lib = StaticFindObject("/Script/Engine.Default__DataTableFunctionLibrary")
    local t = STORY.table("/Game/PBZContent/DataTable/UI/DT_BellData.DT_BellData")
    local rows = STORY.rows(t)
    local function col(c)
        local v = lib:GetDataTableColumnAsString(t, FName(c))
        local out = {}
        for i = 1, #v do out[i] = str(v[i]) end
        return out
    end
    local ids, maps, tf = col("BellID"), col("MapID"), col("TeleportTransform")
    local mt = STORY.table("/Game/PBZContent/DataTable/UI/DT_MapData.DT_MapData")
    local mrows = STORY.rows(mt)
    local levels = {}
    do
        local v = lib:GetDataTableColumnAsString(mt, FName("LevelName"))
        local m = lib:GetDataTableColumnAsString(mt, FName("MapID"))
        for i = 1, #v do levels[str(m[i])] = str(v[i]) end
    end
    STORY.levels = levels
    local data = {}
    for i = 1, #rows do
        local n = nums(tf[i] or "")
        data[str(rows[i])] = { id = ids[i], map = maps[i], level = levels[maps[i]], t = n }
    end
    STORY.bellData = data
    return data
end

-- Sends player 1 to a bell the way the bell menu does: the game saves, then loads there if it's another map.
function STORY.go(row)
    local b = STORY.loadBells()[row]
    if not b then return "STORY no bell " .. tostring(row) end
    local n = b.t
    if #n < 10 then return "STORY bad transform for " .. row end
    local s = FindFirstOf("PBZSaveLoadSubsystem")
    local tf = { Rotation = { X = n[1], Y = n[2], Z = n[3], W = n[4] }, Translation = { X = n[5], Y = n[6], Z = n[7] },
        Scale3D = { X = 1.0, Y = 1.0, Z = 1.0 } }
    log(string.format("STORY going to %s %s level %s at %.0f %.0f %.0f", row, b.id, tostring(b.level), n[5], n[6], n[7]))
    s:TeleportTo(FName(b.level), tf, FName(b.id))
    return "STORY teleport asked"
end

function STORY.where()
    local w = FindFirstOf("World")
    local _, p = PBZ.getPlayer1()
    local l = valid(p) and p:K2_GetActorLocation()
    local hp, max = PBZ.game.getHealth(p)
    return string.format("STORY at %s %.0f %.0f %.0f hp %.0f/%.0f map %s", valid(p) and "pawn" or "nopawn", l and l.X or 0, l and l.Y or 0,
        l and l.Z or 0, hp or -1, max or -1, tostring(PBZ.net and PBZ.net.localMap))
end

-- Story events by table order. The FNames come straight from the table, so the Chinese row names survive the trip.
function STORY.flowRows()
    if STORY.flow then return STORY.flow end
    local t = STORY.table(STORY.FLOW)
    local rows = STORY.rows(t)
    local out = {}
    for i = 1, #rows do out[i] = rows[i] end
    STORY.flow = out
    return out
end

function STORY.apply(from, to)
    local rows = STORY.flowRows()
    local lib = StaticFindObject("/Script/ProjectPBZ.Default__PBZDebugFlowEventLibrary")
    local names = {}
    for i = from, math.min(to, #rows) do
        local r = rows[i]
        pcall(function() r = r:get() end)
        names[#names + 1] = r
    end
    local _, p = PBZ.getPlayer1()
    local ok, err = pcall(function()
        lib:ApplyFlowEvents(p, STORY.table(STORY.FLOW), STORY.table(STORY.BRANCH), names)
    end)
    return "STORY applied " .. #names .. " rows: " .. tostring(ok) .. " " .. tostring(err)
end

-- The game's own QA commands. In a shipping build the player controller may have no cheat manager, so one is made.
function STORY.gm()
    local pc = PBZ.getPlayer1()
    local cm = nil
    pcall(function() cm = pc.CheatManager end)
    if valid(cm) then return cm, "had one" end
    local cls = StaticFindObject("/Script/ProjectPBZ.PBZCheatManager")
    if not valid(cls) then return nil, "no class" end
    cm = StaticConstructObject(cls, pc)
    if valid(cm) then
        pc.CheatManager = cm
        return cm, "made one"
    end
    return nil, "couldn't make one"
end

function STORY.gmProbe()
    local cm, how = STORY.gm()
    if not cm then return "GM " .. how end
    local out = { "GM " .. how .. " " .. cm:GetFullName():sub(1, 80) }
    for _, f in ipairs({ "GM_GetPlayerInfo", "GM_GetPlayerLocation", "GM_GetNPCCount", "GM_GetHealth", "GM_FindAllSaveGame" }) do
        local ok, r = pcall(function() return cm[f](cm) end)
        out[#out + 1] = f .. "=" .. tostring(ok) .. ":" .. str(r)
    end
    return table.concat(out, " | ")
end

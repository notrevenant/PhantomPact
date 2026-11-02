-- Plays the story: reads the quest the game is tracking, goes where it points, fights what's there and uses what's there,
-- with the game's own QA commands. WALK.look() reads; WALK.start() runs it on this copy.
WALK = WALK or {}
local log, valid, game = PBZ.log, PBZ.valid, PBZ.game

local function str(v) return STORY.str(v) end
local function arr(v)
    local out = {}
    pcall(function()
        for i = 1, #v do
            local x = v[i]
            pcall(function() x = x:get() end)
            out[#out + 1] = x
        end
    end)
    return out
end
WALK.arr = arr

function WALK.nc()
    if not valid(WALK.comp) then
        WALK.comp = FindFirstOf("PBZNarrativeComponent")
    end
    return WALK.comp
end

local function qname(q)
    local n = "?"
    pcall(function() n = q:GetClass():GetFName():ToString() end)
    return n
end

-- The branches this quest could take from where it stands now.
function WALK.branches(q)
    local out = {}
    local s = q.CurrentState
    if not valid(s) then return out end
    for _, b in ipairs(arr(s.Branches)) do
        if valid(b) then
            local e = { obj = b, id = "?", state = -1, text = "", world = "", point = "", loc = nil }
            pcall(function() e.id = b:GetFName():ToString() end)
            pcall(function() e.state = b:GetBranchState() end)
            pcall(function() e.text = b:GetTargetTextString():ToString() end)
            pcall(function() e.world = b.BelongToWorld:ToString() end)
            pcall(function() e.point = b.BranchTargetPointID:ToString() end)
            pcall(function() local l = b.Location e.loc = { X = l.X, Y = l.Y, Z = l.Z } end)
            out[#out + 1] = e
        end
    end
    return out
end

-- Where the game itself would point the quest marker for this branch.
function WALK.point(q, b)
    local nc = WALK.nc()
    local map, at = {}, {}
    local mapName, loc
    local ok, err = pcall(function()
        local outMap, outLoc = {}, {}
        nc:ResolveQuestPoint(q, FName(b.id), FName(b.point), outMap, outLoc)
        mapName, loc = outMap, outLoc
    end)
    return ok, mapName, loc, err
end

function WALK.look()
    local nc = WALK.nc()
    if not valid(nc) then return "WALK no narrative component" end
    local all = arr(nc.QuestList)
    local main, tracked = nc.CurrentMainQuest, nc.CurrentTrackedQuest
    log(string.format("WALK quests %d, done %d, main %s, tracked %s", #all, #arr(nc.CompletedQuestObjects),
        valid(main) and qname(main) or "-", valid(tracked) and qname(tracked) or "-"))
    local shown = 0
    for _, q in ipairs(all) do
        if valid(q) and shown < 12 then
            local bs = WALK.branches(q)
            if #bs > 0 then
                shown = shown + 1
                local st = "?"
                pcall(function() st = q.CurrentState:GetFName():ToString() end)
                log(string.format("WALK quest %s state %s comp %s", qname(q), st, tostring(q.QuestCompletion)))
                for _, b in ipairs(bs) do
                    log(string.format("WALK   branch %s st=%s world=%s point=%s at %s [%s]", b.id, tostring(b.state), b.world, b.point,
                        b.loc and string.format("%.0f,%.0f,%.0f", b.loc.X, b.loc.Y, b.loc.Z) or "-", b.text:sub(1, 60)))
                end
            end
        end
    end
    return "WALK listed " .. shown
end

function WALK.dump()
    local nc = WALK.nc()
    for i, q in ipairs(arr(nc.QuestList)) do
        local line = { i, qname(q) }
        local s
        pcall(function() s = q.CurrentState end)
        line[#line + 1] = "state " .. (valid(s) and s:GetFName():ToString() or "nil")
        local n, m = -1, -1
        pcall(function() n = #s.Branches end)
        pcall(function() m = #q.Branches end)
        line[#line + 1] = "stateBranches " .. n .. " questBranches " .. m
        pcall(function() line[#line + 1] = "completion " .. tostring(q.QuestCompletion) end)
        log("WALK q " .. table.concat(line, " "))
        for _, b in ipairs(arr(q.Branches)) do
            if valid(b) then
                local st = -1
                pcall(function() st = b:GetBranchState() end)
                if st == 1 then
                    local t = ""
                    pcall(function() t = b:GetTargetTextString():ToString() end)
                    log("WALK   active " .. b:GetFName():ToString() .. " point " .. b.BranchTargetPointID:ToString() .. " world " .. b.BelongToWorld:ToString() .. " [" .. t:sub(1, 70) .. "]")
                end
            end
        end
    end
    return "WALK dumped"
end

-- The steps in progress, main quest first: { quest, branch, id, point, world, text }.
function WALK.active()
    local nc = WALK.nc()
    local out = {}
    for _, q in ipairs(arr(nc.QuestList)) do
        if valid(q) then
            for _, b in ipairs(arr(q.Branches)) do
                if valid(b) then
                    local st = -1
                    pcall(function() st = b:GetBranchState() end)
                    if st == 1 then
                        local e = { quest = q, branch = b, qname = qname(q), id = b:GetFName():ToString(),
                            point = b.BranchTargetPointID:ToString(), world = b.BelongToWorld:ToString() }
                        pcall(function() e.text = b:GetTargetTextString():ToString() end)
                        pcall(function() e.desc = b:GetTargetDescString():ToString() end)
                        pcall(function()
                            local l = b.Location
                            if math.abs(l.X) + math.abs(l.Y) > 1 then e.loc = { X = l.X, Y = l.Y, Z = l.Z } end
                        end)
                        out[#out + 1] = e
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        local am, bm = a.qname:find("^Main") and 0 or 1, b.qname:find("^Main") and 0 or 1
        if am ~= bm then return am < bm end
        return a.qname < b.qname
    end)
    return out
end

function WALK.resolve(e)
    local nc = WALK.nc()
    local outMap, outLoc = {}, {}
    local ok, r1, r2 = pcall(function()
        return nc:ResolveQuestPoint(e.quest, FName(e.id), FName(e.point), outMap, outLoc)
    end)
    return ok, r1, r2, outMap, outLoc
end

function WALK.targets()
    local ms = FindFirstOf("MapSubsystem")
    local n = 0
    local out = {}
    pcall(function()
        ms.TargetPointComponents:ForEach(function(k, v)
            n = n + 1
            local c = v:get()
            local id = k:get():ToString()
            local o = c:GetOwner()
            local l = o:K2_GetActorLocation()
            out[id] = { X = l.X, Y = l.Y, Z = l.Z, owner = o:GetClass():GetFName():ToString() }
        end)
    end)
    return out, n
end

function WALK.show()
    local tg, n = WALK.targets()
    log("WALK target points loaded " .. n)
    for _, e in ipairs(WALK.active()) do
        local ok, r1, r2, m, l = WALK.resolve(e)
        local t = tg[e.point]
        local keys = {}
        for k, v in pairs(type(l) == "table" and l or {}) do keys[#keys + 1] = tostring(k) .. "=" .. tostring(v) end
        local mk = {}
        for k, v in pairs(type(m) == "table" and m or {}) do mk[#mk + 1] = tostring(k) .. "=" .. STORY.str(v) end
        log(string.format("WALK step %s %s point %s world %s", e.qname, e.id, e.point, e.world))
        log(string.format("WALK   resolve ok=%s r1=%s r2=%s map{%s} loc{%s} tg=%s", tostring(ok), STORY.str(r1), STORY.str(r2), table.concat(mk, " "), table.concat(keys, " "),
            t and string.format("%.0f,%.0f,%.0f %s", t.X, t.Y, t.Z, t.owner) or "-"))
    end
    return "WALK shown"
end

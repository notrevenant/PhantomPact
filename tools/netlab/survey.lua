-- A flight over a map: at each point of a grid the player hovers, the world streams in, and everything worth testing is
-- written down. SURVEY.run(level name, x0, y0, x1, y1, step, z).
SURVEY = SURVEY or {}
local log, valid, game = PBZ.log, PBZ.valid, PBZ.game

local function loc(a)
    local ok, l = pcall(function() return a:K2_GetActorLocation() end)
    if ok and l and l.X then return string.format("%.0f %.0f %.0f", l.X, l.Y, l.Z) end
    return "? ? ?"
end

local function each(class, fn)
    for _, a in ipairs(FindAllOf(class) or {}) do
        pcall(fn, a)
    end
end

function SURVEY.scan(seen, f)
    each("AISpawner", function(s)
        local id = s.SpawnerID:ToString()
        local key = "S" .. id
        if not seen[key] then
            seen[key] = true
            local cls = "?"
            pcall(function() cls = s.Class:ToString() end)
            if cls == "?" then pcall(function() cls = s.Class.AssetPath.AssetName:ToString() end) end
            local a = s.SpawnedAI
            local got = valid(a) and a:GetClass():GetFName():ToString() or "-"
            f:write(string.format("SPAWNER\t%s\t%s\t%s\t%s\t%s\n", id, s:GetClass():GetFName():ToString(), cls, got, loc(s)))
        end
    end)
    each("BP_RenewalNPC_C", function(a)
        local key = "E" .. a:GetFName():ToString()
        if not seen[key] then
            seen[key] = true
            local hp, max = game.getHealth(a)
            f:write(string.format("ENEMY\t%s\t%s\t%s\t%s\t%s\n", a:GetClass():GetFName():ToString(), tostring(game.isBoss and game.isBoss(a)),
                tostring(max), tostring(game.isDead(a)), loc(a)))
        end
    end)
    each("BP_FogDoor_C", function(a)
        local key = "F" .. a:GetFName():ToString()
        if not seen[key] then seen[key] = true f:write("FOG\t" .. a:GetFName():ToString() .. "\t" .. loc(a) .. "\n") end
    end)
    each("BP_NPC_Base_C", function(a)
        local key = "N" .. a:GetFName():ToString()
        if not seen[key] then seen[key] = true f:write("NPC\t" .. a:GetClass():GetFName():ToString() .. "\t" .. loc(a) .. "\n") end
    end)
    each("PBZPickupActor", function(a)
        local key = "P" .. a:GetFName():ToString()
        if not seen[key] then seen[key] = true f:write("PICKUP\t" .. a:GetClass():GetFName():ToString() .. "\t" .. loc(a) .. "\n") end
    end)
end

-- Flies a list of points, one every `every` seconds, on the game thread's own clock; never touches the ground.
function SURVEY.run(file, points, every)
    local f = io.open(file, "a")
    local seen, n = {}, 0
    SURVEY.seen = seen
    local _, p = PBZ.getPlayer1()
    p.CharacterMovement:SetMovementMode(5, 0)
    game.setMinHealth(p, 1)
    local function step()
        if n >= 1 then pcall(SURVEY.scan, seen, f) end
        n = n + 1
        local q = points[n]
        if not q then
            f:close()
            local c = 0
            for _ in pairs(seen) do c = c + 1 end
            log("SURVEY done: " .. (n - 1) .. " points, " .. c .. " things")
            return
        end
        local _, pawn = PBZ.getPlayer1()
        pawn.CharacterMovement:SetMovementMode(5, 0)
        pawn:K2_SetActorLocation({ X = q[1], Y = q[2], Z = q[3] }, false, {}, true)
        game.after(every or 4, step)
    end
    step()
    return "SURVEY started " .. #points .. " points"
end

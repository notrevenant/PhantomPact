-- Every move the host's enemies play, against what the guest's copies really show.
-- Host: MOVES.host() writes each one sent. Guest: MOVES.guest() looks a moment after each one arrives.
MOVES = MOVES or {}
local PBZ, game = PBZ, PBZ.game

local function findApi()
    local a
    for _, f in pairs(PBZ.coop.handlers) do
        for i = 1, 250 do
            local n, v = debug.getupvalue(f, i)
            if n == nil then break end
            if n == "api" then a = v end
        end
    end
    return a
end

local function short(s)
    return (s or "-"):match("[^%./]+$") or "-"
end

function MOVES.host()
    if MOVES.hostOn then return "on already" end
    MOVES.hostOn = true
    local api = findApi()
    local send = api.coop.sendEvent
    MOVES.sent = {}
    api.coop.sendEvent = function(kind, x, y, z, w, v, ...)
        if kind == "A" then
            local k = short(z) .. " | " .. short(y)
            MOVES.sent[k] = (MOVES.sent[k] or 0) + 1
        end
        return send(kind, x, y, z, w, v, ...)
    end
    return "watching what's sent"
end

function MOVES.hostList()
    local rows = {}
    for k, c in pairs(MOVES.sent or {}) do rows[#rows + 1] = { k, c } end
    table.sort(rows, function(a, b) return a[2] > b[2] end)
    local out = {}
    for i = 1, math.min(#rows, 40) do out[#out + 1] = rows[i][2] .. " " .. rows[i][1] end
    return table.concat(out, " ; ")
end

function MOVES.guest()
    if MOVES.guestOn then return "on already" end
    MOVES.guestOn = true
    MOVES.ok, MOVES.miss, MOVES.missed = 0, 0, {}
    local api = findApi()
    local handle = api.coop.handlers.A
    api.coop.handlers.A = function(rest)
        handle(rest)
        local name, ability, path = (rest or ""):match("^(%S+) (%S+) (%S+) ")
        if not name or path == "-" then return end
        local want = short(path)
        local e = api.coop.enemyActor(name)
        if not PBZ.valid(e) or game.isDead(e) then return end
        local now = "-"
        pcall(function()
            local mo = e.Mesh:GetAnimInstance():GetCurrentActiveMontage()
            if PBZ.valid(mo) then now = mo:GetFName():ToString() end
        end)
        if now == want then
            MOVES.ok = MOVES.ok + 1
        else
            MOVES.miss = MOVES.miss + 1
            local k = want .. " (playing " .. now .. ", " .. short(ability) .. ")"
            MOVES.missed[k] = (MOVES.missed[k] or 0) + 1
        end
    end
    return "checking what plays"
end

function MOVES.guestList()
    local rows = {}
    for k, c in pairs(MOVES.missed or {}) do rows[#rows + 1] = { k, c } end
    table.sort(rows, function(a, b) return a[2] > b[2] end)
    local out = {}
    for i = 1, math.min(#rows, 24) do out[#out + 1] = rows[i][2] .. " " .. rows[i][1] end
    return "showing " .. tostring(MOVES.ok) .. ", not showing " .. tostring(MOVES.miss) .. " | " .. table.concat(out, " ; ")
end
return "movecheck loaded"

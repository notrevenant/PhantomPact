-- Host: every hit the guest reports, to see what the guest's copies are losing health to. Reads only.
HITLOG = HITLOG or { n = 0, sum = 0, big = 0, rows = {} }
if not HITLOG.on then
    HITLOG.on = true
    local handle = PBZ.coop.handlers.D
    PBZ.coop.handlers.D = function(rest)
        local name, amount, posture, lethal = (rest or ""):match("^(%S+) (%S+)%s*(%S*)%s*(%S*)")
        amount = tonumber(amount) or 0
        HITLOG.n = HITLOG.n + 1
        HITLOG.sum = HITLOG.sum + amount
        if amount > 300 or lethal == "L" then
            HITLOG.big = HITLOG.big + 1
            if #HITLOG.rows < 60 then
                local e = PBZ.coop.enemyActor(name)
                local hp, max = nil, nil
                if PBZ.valid(e) then hp, max = PBZ.game.getHealth(e) end
                HITLOG.rows[#HITLOG.rows + 1] = string.format("%s %s -%.0f%s (host had %.0f/%.0f)", os.date("%H:%M:%S"), name:sub(-24), amount, lethal == "L" and " LETHAL" or "", hp or -1, max or -1)
            end
        end
        return handle(rest)
    end
end
function HITLOG.show()
    return HITLOG.n .. " hits reported, " .. math.floor(HITLOG.sum) .. " total, " .. HITLOG.big .. " big | " .. table.concat(HITLOG.rows, " ; ")
end
return "hit log on"

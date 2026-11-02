-- Writes one enemy's health to a file once a second, with how many reported hits the host has applied.
HPLOG = HPLOG or {}
function HPLOG.run(name, seconds)
    HPLOG.id = (HPLOG.id or 0) + 1
    local id, stop = HPLOG.id, os.clock() + (seconds or 240)
    local path = "C:/PBZDev/pp-netlab/bosshp.txt"
    local last
    local function step()
        if id ~= HPLOG.id or os.clock() > stop then return end
        local e = PBZ.coop.enemyActor(name)
        local h, m
        if PBZ.valid(e) then h, m = PBZ.game.getHealth(e) end
        local line = string.format("%s %.0f/%.0f applied %s", os.date("%H:%M:%S"), h or -1, m or -1, tostring(PBZ.net.stats.hitsApplied))
        local short = string.format("%.0f %s", h or -1, tostring(PBZ.net.stats.hitsApplied))
        if short ~= last then
            last = short
            local f = io.open(path, "a")
            if f then f:write(line .. "\n"); f:close() end
        end
        PBZ.game.after(0.5, step)
    end
    step()
    return "logging"
end
return "hplog loaded"

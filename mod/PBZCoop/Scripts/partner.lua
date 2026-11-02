-- How your partner is doing, as short tips (the game's ink-bar tip, see status.lua): partner down, partner back,
-- partner watching a cutscene, and the two of you far apart in the same area.
-- (From appdoze's PR #5.) A guest goes to the host once, on joining. After that F3 goes to the partner, if TP > PARTNER
-- is on (PartnerTeleport, off unless chosen: it's a lot of power to have on one key).
-- Each player's death and respawn stay their own game's; there is no revive. Spectating is in coop.lua.

return function(api)
    local log, valid = api.log, api.valid
    local coop = api.coop
    local net = coop.net

    local POLL_S = 0.5
    local FRESH_S = 3.0             -- a partner position older than this is stale
    local FAR_CM = 15000            -- "far apart" above 150 m (same area)
    local KEY_MS = 40               -- how often F3 is looked at; a press lasts longer
    local LINK_WAIT_S = 120         -- from the link, a joining guest has this long to reach the host (a cutscene may be on)

    local partner = { down = false, zeroReads = 0, far = false, cine = false }
    local nextPoll = 0
    local wasKey = false

    local function tip(key, text)
        if api.status and api.status.notify then
            api.status.notify(key, text)
        else
            log(text)
        end
    end

    local function fresh()
        return net.enabled and not net.partnerGone and net.target ~= nil and net.lastRemoteAt ~= nil
            and os.clock() - net.lastRemoteAt <= FRESH_S
    end

    -- Down after two reads in a row at 0 health (one bad read during a teleport isn't "down"); back when health
    -- returns.
    local function check()
        if not fresh() then
            return
        end
        local t = net.target
        if not (t.MaxHp and t.MaxHp > 0 and t.Hp) then
            return
        end
        if partner.joining then
            partner.joining = false
            partner.goUntil = os.clock() + LINK_WAIT_S
        end
        if partner.goUntil and net.partnerFighting then
            -- Not into the middle of a boss fight: it's watched, and the trip made when it's over, whoever won.
            partner.goUntil = os.clock() + LINK_WAIT_S
            coop.watchFight(true)
        elseif partner.goUntil then
            coop.watchFight(net.watchingFight == true)      -- (held till the trip: they may have to get up first)
            if os.clock() > partner.goUntil then
                partner.goUntil = nil
                coop.watchFight(false)
                tip("join", "couldn't reach your partner in time. TP > PARTNER in MORE (F5) can take you there.")
            elseif coop.joinPartner() == nil then
                partner.goUntil = nil
                coop.watchFight(false)
            end
        end
        if t.Hp <= 0 then
            partner.zeroReads = partner.zeroReads + 1
            if partner.zeroReads >= 2 and not partner.down then
                partner.down = true
                tip("partner", "your partner is down.")
            end
            return
        end
        partner.zeroReads = 0
        if partner.down then
            partner.down = false
            tip("partner", "your partner is back.")
            return
        end
        if t.Cine ~= partner.cine then
            partner.cine = t.Cine
            if t.Cine then
                tip("cine", "your partner is watching a cutscene.")
            end
        end
        -- Another map: the ghost hides, so this says why. (Two saves can be far apart in the story.)
        local otherMap = t.Map ~= nil and net.localMap ~= nil and t.Map ~= net.localMap
        if otherMap and not partner.otherMap then
            tip("map", "your partner is on another map." .. (partner.teleport and " F3 takes you there." or ""))
        end
        partner.otherMap = otherMap
        -- Far apart in the same area: one tip each time you drift apart.
        local l = net.localLoc
        if l and t.Map ~= nil and t.Map == net.localMap then
            local d = math.sqrt((l.X - t.X) ^ 2 + (l.Y - t.Y) ^ 2)
            local far = d > FAR_CM
            if far and not partner.far then
                tip("far", string.format("your partner is %d m away.", math.floor(d / 100))
                    .. (partner.teleport and " F3 takes you there." or ""))
            end
            partner.far = far
        end
    end

    coop.extraTicks.partner = function()
        local now = os.clock()
        if now < nextPoll then
            return
        end
        nextPoll = now + POLL_S
        check()
    end

    -- Sync on as a guest: this player goes to the host as soon as they're linked, on whatever map. (As a host, not.)
    function partner.goOnLink(joining)
        partner.joining, partner.goUntil = joining, nil
    end

    -- F3, online. (Read on the game thread, like the panels' keys.)
    function partner.go()
        if not partner.teleport then
            tip("join", "TP > PARTNER is off. Turn it on in MORE (F5).")
            return
        end
        local why = coop.joinPartner()
        if why then
            api.status.lastShown.join = nil     -- (a press deserves its answer, however soon after the last)
            tip("join", why)
        end
    end

    local function readKey()
        local controller, pawn = api.getPlayer1()
        if not valid(pawn) then
            wasKey = false
            return
        end
        local down = controller:IsInputKeyDown(api.panel.kit.key("F3"))
        if down and not wasKey and net.enabled then
            partner.go()
        end
        wasKey = down
    end

    function partner.start()
        LoopInGameThreadWithDelay(KEY_MS, function()
            local ok, err = pcall(readKey)
            if not ok then
                log("Partner key error: " .. tostring(err))
            end
            return false
        end)
    end

    -- partner: print what the mod knows about your partner
    function partner.command()
        local t = net.target
        if not fresh() then
            log("Partner: no recent position" .. (net.partnerGone and " (gone)." or "."))
            return
        end
        log(string.format("Partner: %s, health %s/%s, area %s%s%s", partner.down and "down" or "up", tostring(t.Hp),
            tostring(t.MaxHp), tostring(t.Map), t.Map == net.localMap and " (same as yours)" or "",
            t.Cine and ", in a cutscene" or ""))
    end

    return partner
end

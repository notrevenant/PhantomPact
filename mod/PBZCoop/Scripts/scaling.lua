-- Co-op difficulty, Elden Ring style: while your partner is with you, enemies and bosses get more health and
-- posture (PhantomPact.ini CoopEnemyHealth / CoopEnemyPosture, in percent; 100 = off).
--
-- Both players' games scale the same enemies by the same factor, so the host's numbers (which the guest's copies
-- follow down) and the guest's own copies stay in step. Each enemy is scaled once, keeping its current share of
-- health; enemies that respawn (bell rest) are new actors and get scaled again.

return function(api)
    local log, valid, game = api.log, api.valid, api.game
    local net = api.coop.net

    local scaling = {
        health = 1.5,       -- CoopEnemyHealth / 100
        posture = 1.3,      -- CoopEnemyPosture / 100
    }

    local PASS_S = 1.0              -- a look over the enemies starts this often while the partner is here
    local LOOKS_PER_TICK = 16       -- enemies looked at per tick, and at most one scaled: that takes about 25 calls through
                                    -- UE4SS, and all those near a new player scaled in one frame was a 23 ms frame

    local scaled = {}               -- enemy address -> true once scaled

    local function scaleAttr(set, name, maxName, factor)
        pcall(function()
            local mx, cur = set[maxName], set[name]
            local share = (mx.CurrentValue > 0) and (cur.CurrentValue / mx.CurrentValue) or 1
            local newMax = mx.CurrentValue * factor
            mx.BaseValue = newMax
            mx.CurrentValue = newMax
            cur.BaseValue = newMax * share
            cur.CurrentValue = newMax * share
        end)
    end

    -- While the partner is here: scale enemies we haven't scaled yet, a few looks a tick. The list is the one the net loop
    -- keeps: the search for enemies is its job, once a second, and two in one frame was part of the worst case.
    local next, todo, addrs, at, n = 0, {}, {}, 1, 0
    local function tick()
        if scaling.health == 1 and scaling.posture == 1 then
            return
        end
        if at > #todo then
            if n > 0 then
                log(string.format("Co-op difficulty: %d enem%s at %d%% health, %d%% posture.", n, n == 1 and "y" or "ies",
                    math.floor(scaling.health * 100 + 0.5), math.floor(scaling.posture * 100 + 0.5)))
                n = 0
            end
            if os.clock() < next then
                return
            end
            next = os.clock() + PASS_S
            -- "With you": synced and the partner's ghost is in this world (same map, alive).
            if not (net.enabled and net.target and valid(net.ghost) and not net.ghostHidden) then
                return
            end
            todo, addrs = game.enemiesSoFar()
            at = 1
        end
        for _ = 1, LOOKS_PER_TICK do
            local e, addr = todo[at], addrs[at]
            if e == nil then
                return
            end
            at = at + 1
            if not scaled[addr] and valid(e) then
                scaled[addr] = true       -- (or it's dead, and nothing brings it back as the same actor)
                if not game.isDead(e) then
                    local set = e.AttributeSetBase
                    scaleAttr(set, "Health", "Health_Max", scaling.health)
                    scaleAttr(set, "Shachi", "Shachi_Max", scaling.posture)
                    n = n + 1
                    return
                end
            end
        end
    end
    api.coop.extraTicks.scaling = tick

    -- scale <health %> [posture %]   (100 100 = normal enemies)
    function scaling.command(args)
        local h, p = (args or ""):match("^%s*(%d+)%s*(%d*)")
        if tonumber(h) then
            scaling.health = math.max(1.0, math.min(5.0, tonumber(h) / 100))
            scaling.posture = tonumber(p) and math.max(1.0, math.min(5.0, tonumber(p) / 100)) or scaling.posture
        end
        log(string.format("Co-op difficulty: enemies at %d%% health, %d%% posture while your partner is here.",
            math.floor(scaling.health * 100 + 0.5), math.floor(scaling.posture * 100 + 0.5)))
    end

    return scaling
end

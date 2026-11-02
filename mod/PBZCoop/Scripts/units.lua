-- Does the game itself allow several player units in one fight? Development only: the wall in a game like this tends to be
-- its own gameplay code, not the network (Black Myth: Wukong threw an error for any second copy of the player class), and two
-- accounts can only ever show one partner. This shows three or more, with no second PC. (EXACG's, PR #11.)
--
-- Nothing here runs unless asked for through cmd.txt on a developer install (dev.txt, which tools\install-mod.ps1 writes; the
-- release zip has none). tools\mp-units.ps1 drives it.
--
-- units            where things stand now
-- units 3          remove what's there, then place 3 copies of player 1 in a ring around them
-- units 0          remove them
--
-- Each unit is set up like a partner's ghost: walking, no pawn collision, Attack 0, full health. But it isn't shielded, as a real
-- ghost is, because the question is whether enemies fight it. They stand where they're put, with no controller, which is
-- all this needs: do enemies take several player units onto their hatred list, do they hit them, and does the game complain.

return function(api)
    local log, valid, distance = api.log, api.valid, api.distance
    local game = api.game

    local RING_CM = 250             -- where the units stand, from player 1
    local MAX_UNITS = 6
    local HATE_CM = 2500            -- the distance pbz.lua uses for a partner's ghost
    local HATE_EVERY_S = 1.0
    local MOVE_WALKING = 1          -- EMovementMode::MOVE_Walking
    local ECC_PAWN = 2              -- ECollisionChannel::ECC_Pawn
    local ECR_IGNORE = 0            -- ECollisionResponse::ECR_Ignore

    local units = { list = {} }     -- { actor = pawn, maxHp = number }

    local function devAllowed()
        local f = io.open(api.modRoot() .. "dev.txt", "r")
        if f then
            f:close()
            return true
        end
        return os.getenv("PBZCOOP_DEBUG") == "1"
    end

    -- Returns its full health, or nil when it couldn't be read.
    local function setUpLikeGhost(actor)
        game.setupGhost(actor)
        pcall(function()
            local cmc = actor.CharacterMovement
            cmc.bRunPhysicsWithNoController = true
            cmc:SetMovementMode(MOVE_WALKING, 0)
        end)
        pcall(function() actor.CapsuleComponent:SetCollisionResponseToChannel(ECC_PAWN, ECR_IGNORE) end)
        -- A spawned unit starts with no health, which the game counts as dead: a full bar, so enemies can fight it and a
        -- lost point shows as damage taken.
        local _, maxhp = game.getHealth(actor)
        if maxhp and maxhp > 0 then
            game.setHealth(actor, maxhp)
        end
        return maxhp
    end

    local function clear()
        local n = 0
        for _, u in ipairs(units.list) do
            if valid(u.actor) then
                pcall(function() u.actor:K2_DestroyActor() end)
                n = n + 1
            end
        end
        units.list = {}
        return n
    end

    -- Enemies near this unit that have it on their hatred list, adding it where it's missing, as for a partner's ghost.
    local function syncHate(actor)
        local hated = 0
        local g = actor:K2_GetActorLocation()
        for _, e in ipairs((game.listEnemies(true))) do
            local ok, loc = pcall(function() return e:K2_GetActorLocation() end)
            if ok and loc.X and distance(loc, g) <= HATE_CM and not game.isDead(e) then
                local already = false
                pcall(function()
                    local hm = e.BP_PBZHatredManagerComponent
                    hm.HatredList:ForEach(function(_, a)
                        local other = a:get()
                        if valid(other) and other:GetAddress() == actor:GetAddress() then
                            already = true
                        end
                    end)
                    if not already then
                        hm:AddActorToHatredList(actor, {})
                        already = true
                    end
                end)
                if already then
                    hated = hated + 1
                end
            end
        end
        return hated
    end

    -- Once a second while they're there: an enemy that only ever looked at player 1 would read as "nobody hates them" when the
    -- answer is "the game picks one target". On a timer of its own, as this works with the network off, and started by the
    -- first spawn, so nobody who never runs the command pays for it.
    local looping = false
    local function loop()
        if #units.list == 0 then
            looping = false
            return
        end
        for _, u in ipairs(units.list) do
            if valid(u.actor) then
                syncHate(u.actor)
            end
        end
        game.after(HATE_EVERY_S, loop)
    end

    local function spawn(n)
        local _, pawn = api.getPlayer1()
        if not valid(pawn) then
            log("units: no player 1 to place them around (get into gameplay first).")
            return 0
        end
        local pawnClass = pawn:GetClass()
        local loc = pawn:K2_GetActorLocation()
        clear()
        for i = 1, n do
            local angle = math.pi / 2 + (i - 1) * (2 * math.pi / n)
            local actor = nil
            local ok, err = pcall(function() actor = api.spawnBesidePlayer1(pawnClass) end)
            if ok and valid(actor) then
                pcall(function()
                    actor:K2_SetActorLocationAndRotation({
                        X = loc.X + math.cos(angle) * RING_CM,
                        Y = loc.Y + math.sin(angle) * RING_CM,
                        Z = loc.Z,
                    }, { Pitch = 0.0, Yaw = math.deg(angle) + 180.0, Roll = 0.0 }, false, {}, true)
                end)
                units.list[#units.list + 1] = { actor = actor, maxHp = setUpLikeGhost(actor) }
            else
                log("units: unit " .. i .. " wasn't spawned: " .. tostring(err or "no actor back from the spawner"))
            end
        end
        if #units.list > 0 and not looping then
            looping = true
            game.after(HATE_EVERY_S, loop)
        end
        return #units.list
    end

    -- The game's own error dialog (what Wukong used to say no to a second player class).
    local function exceptionPanel()
        local panel = FindFirstOf("BP_UI_ExceptionPanel_C")
        if not valid(panel) or not panel:IsVisible() then
            return nil
        end
        local text = "?"
        pcall(function() text = panel.TextArea:GetText():ToString() end)
        return text
    end

    local function report()
        local alive, damaged, hatedAny = 0, 0, 0
        for i, u in ipairs(units.list) do
            if valid(u.actor) then
                alive = alive + 1
                local hp, maxhp = game.getHealth(u.actor)
                hp, maxhp = hp or 0, maxhp or u.maxHp
                local hated = syncHate(u.actor)
                if hated > 0 then
                    hatedAny = hatedAny + 1
                end
                local lost = (maxhp and maxhp > 0) and (maxhp - hp) or 0
                if lost > 0.5 then
                    damaged = damaged + 1
                end
                log(string.format("units: unit %d hp %.0f/%.0f (-%.0f), hated by %d enemies", i, hp, maxhp or 0, lost, hated))
            else
                log(string.format("units: unit %d is gone (the game destroyed it)", i))
            end
        end
        log(string.format("units: %d spawned, %d alive, ring %d cm, %d took damage, %d hated by an enemy", #units.list, alive, RING_CM,
            damaged, hatedAny))
        local panel = exceptionPanel()
        log("units: error panel: " .. (panel and ("VISIBLE: " .. panel) or "none"))
    end

    -- units | units 0 | units <1-6>
    function units.command(args)
        if not devAllowed() then
            log("units is off (development only): create dev.txt in the mod folder to enable it.")
            return
        end
        local a = (args or ""):match("^%s*(%S*)")
        if a == "" or a == "report" then
            report()
            return
        end
        if a == "0" or a == "clear" then
            log("units: removed " .. clear() .. ".")
            return
        end
        local n = math.floor(tonumber(a) or 0)
        if n < 1 or n > MAX_UNITS then
            log("Usage: units [0|<1-" .. MAX_UNITS .. ">]  (no argument: report)")
            return
        end
        log(string.format("units: spawning %d...", n))
        log(string.format("units: %d of %d accepted by the game.", spawn(n), n))
        report()
    end

    return units
end

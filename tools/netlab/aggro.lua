-- Who each enemy is after, by the game's own blackboard, on the copy that runs the enemies.
AGGRO = AGGRO or {}
local PBZ, game = PBZ, PBZ.game
local valid = PBZ.valid
local AI_LIB = "/Script/SGameAI.Default__SGameAIFunctionLibrary"
local BB_LIB = "/Script/AIModule.Default__AIBlueprintHelperLibrary"

local function say(s) print("[PBZCoop] AGGRO " .. s .. "\n") end

local function targetOf(e)
    local c = e:GetController()
    if not valid(c) then return nil end
    local out = {}
    StaticFindObject(AI_LIB):GetTargetActor(c, out)
    return out.Target
end
AGGRO.targetOf = targetOf

local function nameOf(a)
    if not valid(a) then return "nobody" end
    local _, p = PBZ.getPlayer1()
    if valid(p) and a:GetAddress() == p:GetAddress() then return "HOST" end
    local g = PBZ.net.ghost
    if valid(g) and a:GetAddress() == g:GetAddress() then return "GUEST" end
    return a:GetFName():ToString():sub(1, 24)
end
AGGRO.nameOf = nameOf

local function hatred(e)
    local out = {}
    pcall(function()
        e.BP_PBZHatredManagerComponent.HatredList:ForEach(function(_, a) out[#out + 1] = nameOf(a:get()) end)
    end)
    return table.concat(out, ",")
end
AGGRO.hatred = hatred

-- One line per enemy within this range of the host.
function AGGRO.now(cm)
    local _, p = PBZ.getPlayer1()
    local here = p:K2_GetActorLocation()
    local g = PBZ.net.ghost
    local there = valid(g) and g:K2_GetActorLocation() or nil
    local out, tally = {}, {}
    for name, e in pairs(PBZ.coop.enemies()) do
        if valid(e) and not game.isDead(e) then
            local l = e:K2_GetActorLocation()
            local d = PBZ.distance(l, here)
            if d <= (cm or 4000) then
                local who = nameOf(targetOf(e))
                tally[who] = (tally[who] or 0) + 1
                out[#out + 1] = string.format("%s%s -> %s (host %.0f m, guest %.0f m) list [%s]", game.isBoss(e) and "BOSS " or "",
                    e:GetClass():GetFName():ToString():sub(12, 34), who, d / 100, there and PBZ.distance(l, there) / 100 or -1, hatred(e))
            end
        end
    end
    return table.concat(out, " ; ")
end

-- Logs each change of target, for this long.
function AGGRO.watch(seconds, cm)
    AGGRO.id = (AGGRO.id or 0) + 1
    local id, stop, last = AGGRO.id, os.clock() + (seconds or 20), {}
    local function step()
        if id ~= AGGRO.id or os.clock() > stop then say("watch over"); return end
        local _, p = PBZ.getPlayer1()
        local here = p:K2_GetActorLocation()
        for name, e in pairs(PBZ.coop.enemies()) do
            if valid(e) and not game.isDead(e) and PBZ.distance(e:K2_GetActorLocation(), here) <= (cm or 4000) then
                local who = nameOf(targetOf(e))
                if last[name] ~= who then
                    last[name] = who
                    say(string.format("%.1f %s%s now after %s", os.clock() % 1000, game.isBoss(e) and "BOSS " or "", name:sub(-22), who))
                end
            end
        end
        game.after(0.25, step)
    end
    step()
    return "watching"
end
-- Keeps telling one enemy who to go for, this long. who: "HOST" or "GUEST".
function AGGRO.force(name, who, seconds)
    AGGRO.forceId = (AGGRO.forceId or 0) + 1
    local id, stop = AGGRO.forceId, os.clock() + (seconds or 10)
    local lib = StaticFindObject(AI_LIB)
    local tag = { TagName = FName("AI.BlackboardKey.Object.TargetActor") }
    local fixed = 0
    local function step()
        local e = PBZ.coop.enemyActor(name)
        if id ~= AGGRO.forceId or os.clock() > stop or not valid(e) then
            say("force over, put back " .. fixed .. " times")
            return
        end
        local _, p = PBZ.getPlayer1()
        local want = who == "HOST" and p or PBZ.net.ghost
        local c = e:GetController()
        local out = {}
        lib:GetTargetActor(c, out)
        if not (valid(out.Target) and out.Target:GetAddress() == want:GetAddress()) then
            fixed = fixed + 1
            lib:SetValueAsObjectByTag(StaticFindObject(BB_LIB):GetBlackboard(c), tag, want)
        end
        game.after(0.1, step)
    end
    step()
    return "forcing " .. who
end
-- The enemy's own target picker, the script the game runs for it.
local function selector(e)
    local found
    e:GetController().SGameAIComponent.SpawnedAIScripts:ForEach(function(_, s)
        local o = s:get()
        if valid(o) and o:GetClass():GetFName():ToString() == "AIScript_TargetSelector_C" then found = o end
    end)
    return found
end
AGGRO.selector = selector

-- Turns an enemy to one player the game's own way: with the other off its list for a moment its picker chooses that one,
-- then the cooldown holds it there.
function AGGRO.turn(name, who, holdS)
    local e = PBZ.coop.enemyActor(name)
    if not valid(e) then return "gone" end
    local _, p = PBZ.getPlayer1()
    local want, other = p, PBZ.net.ghost
    if who == "GUEST" then want, other = other, want end
    local hm, sel = e.BP_PBZHatredManagerComponent, selector(e)
    local before = sel.SwitchTargetCooldown
    if holdS then sel.SwitchTargetCooldown = holdS end
    hm:RemoveActorFromHatredList(other)
    hm:AddActorToHatredList(want, {})
    sel.LastSwitchTime = 0
    sel:TrySwitchTarget()
    hm:AddActorToHatredList(other, {})
    return "turned, cooldown was " .. tostring(before) .. ", target " .. nameOf(targetOf(e)) .. ", list " .. hatred(e)
end
-- The focus rule, as a test: run on the host for this long over every enemy near both players.
AGGRO.cfg = { reach = 2500, near = 400, min = 4.0, max = 10.0, hit = 1.5 }
function AGGRO.steer(seconds)
    AGGRO.steerId = (AGGRO.steerId or 0) + 1
    local id, stop, focus, partnerHit = AGGRO.steerId, os.clock() + (seconds or 40), {}, {}
    local turns, nameTurns = 0, {}
    AGGRO.partnerHit = partnerHit
    local cfg = AGGRO.cfg
    local function turn(e, sel, want, other)
        local hm = e.BP_PBZHatredManagerComponent
        if hm:CheckCanHatredTarget(want) == false then return false end
        hm:AddActorToHatredList(want, {})
        hm:RemoveActorFromHatredList(other)
        sel.LastSwitchTime = 0
        sel:TrySwitchTarget()
        hm:AddActorToHatredList(other, {})
        return true
    end
    local function one(name, e, pawn, ghost, now)
        local addr = e:GetAddress()
        local l = e:K2_GetActorLocation()
        local dHost, dGuest = PBZ.distance(l, pawn:K2_GetActorLocation()), PBZ.distance(l, ghost:K2_GetActorLocation())
        if dHost > cfg.reach or dGuest > cfg.reach then return end
        local target = targetOf(e)
        if not valid(target) then focus[addr] = nil; return end
        local ta = target:GetAddress()
        if ta ~= pawn:GetAddress() and ta ~= ghost:GetAddress() then return end
        local onGuest = ta == ghost:GetAddress()
        local f = focus[addr]
        local hp = game.getHealth(e)
        if not f or f.onGuest ~= onGuest then
            f = { onGuest = onGuest, since = now, hp = hp, sel = f and f.sel or selector(e) }
            focus[addr] = f
            f.sel.SwitchTargetCooldown = cfg.max * 2
            say(string.format("%.1f %s after %s (host %.0f m, guest %.0f m)", now % 1000, name:sub(-18), onGuest and "GUEST" or "HOST", dHost / 100, dGuest / 100))
        end
        local dropped = f.hp and hp and hp < f.hp - 0.5
        f.hp = hp
        local held = now - f.since
        if held < cfg.min then return end
        local dOn, dOff = onGuest and dGuest or dHost, onGuest and dHost or dGuest
        local hitByOther
        if onGuest then hitByOther = dropped and game.localMoveRecent(cfg.hit)
        else hitByOther = now - (partnerHit[addr] or -1e9) < cfg.hit end
        local drawn = dOff <= cfg.near and dOff < dOn
        if hitByOther or drawn or held >= cfg.max then
            local why = hitByOther and "hit" or drawn and "near" or "time"
            if turn(e, f.sel, onGuest and pawn or ghost, onGuest and ghost or pawn) then
                turns = turns + 1
                f.since = now
                say(string.format("%.1f %s turned (%s)", now % 1000, name:sub(-18), why))
            end
        end
    end
    local function step()
        if id ~= AGGRO.steerId or os.clock() > stop then say("steer over, " .. turns .. " turns"); return end
        local _, pawn = PBZ.getPlayer1()
        local ghost = PBZ.net.ghost
        local now = os.clock()
        if valid(pawn) and valid(ghost) and not PBZ.net.ghostHidden and not game.isDead(pawn) then
            for name, e in pairs(PBZ.coop.enemies()) do
                if valid(e) and not game.isDead(e) then one(name, e, pawn, ghost, now) end
            end
        end
        game.after(1.0, step)
    end
    step()
    return "steering"
end
-- The partner's stand-in put into the fight areas around it, the way player 2 is in local co-op.
function AGGRO.enterDomains(cm)
    local g = PBZ.net.ghost
    local here = g:K2_GetActorLocation()
    local out = {}
    for _, d in ipairs(FindAllOf("BP_MobDomain_C") or {}) do
        local listed, nearest, n = 0, nil, 0
        d.ActorsInMobDomain:ForEach(function(_, el)
            local a = el:get()
            if valid(a) then
                n = n + 1
                if a:GetAddress() == g:GetAddress() then listed = listed + 1
                elseif not game.isDead(a) then
                    local dist = PBZ.distance(a:K2_GetActorLocation(), here)
                    if nearest == nil or dist < nearest then nearest = dist end
                end
            end
        end)
        if nearest and nearest <= (cm or 3000) then
            if listed == 0 then d:OnTriggerEnteredEvent(g) end
            out[#out + 1] = string.format("%s members %d nearest %.0f m listed before %d", d:GetFName():ToString():sub(-16), n, nearest / 100, listed)
        end
    end
    return #out .. " areas: " .. table.concat(out, " ; ")
end
return "aggro loaded"

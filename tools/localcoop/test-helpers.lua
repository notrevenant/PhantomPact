-- Test helpers for local co-op debugging, loaded in game with: eval dofile("<path>/t.lua")
T = T or {}
local valid = PBZ.valid
function T.pawn(n) if n == 1 then local _, p = PBZ.getPlayer1() return p end return PBZ.state.p2Pawn end
function T.pc(n) if n == 1 then return (PBZ.getPlayer1()) end return PBZ.state.p2Controller end
function T.sub(n)
    local pc = T.pc(n)
    for _, s in ipairs(FindAllOf("EnhancedInputLocalPlayerSubsystem") or {}) do
        if s:GetOuter().ControllerId == pc.Player.ControllerId then return s end
    end
end
function T.ia(name)
    for _, a in ipairs(FindAllOf("InputAction") or {}) do if a:GetFName():ToString() == name then return a end end
end
function T.inject(n, name, x, y, z)
    local s, a = T.sub(n), T.ia(name)
    if not (s and a) then return "no sub/ia" end
    s:InjectInputVectorForAction(a, { X = x or 1, Y = y or 0, Z = z or 0 }, {}, {})
    return "ok"
end
T.holds = T.holds or {}
if not T.loop then
    T.loop = true
    LoopInGameThreadWithDelay(16, function()
        local now = os.clock()
        for k, h in pairs(T.holds) do
            if now > h.until_ then T.holds[k] = nil else pcall(T.inject, h.n, h.ia, h.x, h.y, h.z) end
        end
        return false
    end)
end
function T.hold(n, ia, x, y, s, z) T.holds[n .. ia] = { n = n, ia = ia, x = x, y = y, z = z, until_ = os.clock() + (s or 1) } end
function T.move(n, x, y, s) T.hold(n, n == 1 and "IA_KeyboardMoveInput" or "IA_JoystickMoveInput", x, y, s) end
function T.press(n, ia, s) T.hold(n, ia, 1, 0, s or 0.2) end
function T.comp(p, cls)
    for _, c in ipairs(FindAllOf(cls) or {}) do
        local ok, own = pcall(function() return c:GetOwner() end)
        if ok and valid(own) and own:GetAddress() == p:GetAddress() then return c end
    end
end
function T.name(o, n) return valid(o) and o:GetFName():ToString():sub(1, n or 30) or "none" end
function T.find(cls, part)
    for _, o in ipairs(FindAllOf(cls) or {}) do if o:GetFName():ToString():find(part, 1, true) then return o end end
end
function T.at(n, x, y, z, yaw)
    T.pawn(n):K2_SetActorLocationAndRotation({ X = x, Y = y, Z = z }, { Pitch = 0, Yaw = yaw or 0, Roll = 0 }, false, {}, true)
end
function T.atActor(n, actor, back, side, up, face)
    local l, yaw = actor:K2_GetActorLocation(), actor:K2_GetActorRotation().Yaw
    local r = math.rad(yaw)
    local fx, fy = math.cos(r), math.sin(r)
    T.at(n, l.X - fx * (back or 0) - fy * (side or 0), l.Y - fy * (back or 0) + fx * (side or 0), l.Z + (up or 0), face or yaw)
end
function T.where(n)
    local p = T.pawn(n)
    local q = p:K2_GetActorLocation()
    return string.format("P%d %.0f,%.0f,%.0f yaw %.0f mode %s", n, q.X, q.Y, q.Z, p:K2_GetActorRotation().Yaw, tostring(p.CharacterMovement.MovementMode))
end
function T.climb(n)
    local p = T.pawn(n)
    local a, b = T.comp(p, "ASM_SpecialMoveComponent_C"), T.comp(p, "SpecialMoveComponent")
    local cur, cur2 = "?", "?"
    pcall(function() cur = T.name(a.CurSpecialMoveVolume) end)
    pcall(function() cur2 = T.name(b.CurrentSpecialMoveVolume) end)
    return string.format("%s asm=%s smc=%s", T.where(n), cur, cur2)
end
function T.interact(n)
    local c = T.comp(T.pawn(n), "PBZInteractComponent")
    local cur, ing, lp = "?", "?", "?"
    pcall(function() cur = T.name(c.CurrentInteractActor) end)
    pcall(function() ing = T.name(c.InteractingActor) end)
    pcall(function() lp = tostring(valid(c.LocalPlayerSubsystem)) end)
    return string.format("P%d interact cur=%s ing=%s lps=%s", n, cur, ing, lp)
end
-- Give player 2's interact component the local player subsystem it never got (the pawn was spawned unpossessed).
function T.fixInteract(n)
    local c = T.comp(T.pawn(n), "PBZInteractComponent")
    local s = T.sub(n)
    if not (c and s) then return "no comp/sub" end
    c.LocalPlayerSubsystem = s
    return "set lps on P" .. n
end
function T.shotInfo() return T.climb(1) .. " | " .. T.climb(2) .. " | " .. T.interact(1) .. " | " .. T.interact(2) end
-- Enemy watch: each loaded enemy's distance to both players, plus both players' health.
function T.enemies()
    local p1, p2 = T.pawn(1), T.pawn(2)
    local a, b = p1:K2_GetActorLocation(), p2:K2_GetActorLocation()
    local out = {}
    for _, e in ipairs(PBZ.game.listEnemies(true)) do
        local q = e:K2_GetActorLocation()
        local hp = PBZ.game.getHealth(e)
        local tgt = "?"
        pcall(function()
            local bb = e:GetController().BrainComponent.BlackboardComponent
            local t = bb:GetValueAsObject(FName("TargetActor"))
            tgt = T.name(t, 24)
        end)
        local d1, d2 = PBZ.distance(q, a), PBZ.distance(q, b)
        if d1 < 4000 or d2 < 4000 then
            out[#out + 1] = string.format("%s d1=%.0f d2=%.0f hp=%.0f tgt=%s", e:GetClass():GetFName():ToString():sub(1, 22), d1, d2, hp or -1, tgt)
        end
    end
    local h1, h2 = PBZ.game.getHealth(p1), PBZ.game.getHealth(p2)
    return string.format("P1 hp %s, P2 hp %s | %d near: %s", tostring(h1), tostring(h2), #out, table.concat(out, "; "))
end

-- Streaming-safe teleport: hold in flying mode until the ground loads, then land.
function T.go(n, x, y, z, yaw)
    local p = T.pawn(n)
    p.CharacterMovement:SetMovementMode(5, 0)
    p.CharacterMovement:StopMovementImmediately()
    T.at(n, x, y, z, yaw)
end
function T.land(n) T.pawn(n).CharacterMovement:SetMovementMode(1, 0) end

function T.backpack()
    return StaticFindObject("/Script/Engine.Default__SubsystemBlueprintLibrary"):GetWorldSubsystem(T.pawn(1),
        StaticFindObject("/Script/ProjectPBZ.PBZBackPackSubsystem"))
end
function T.items()
    local bp = T.backpack()
    local n, total = 0, 0
    pcall(function() bp.Inventories:ForEach(function(k, v) n = n + 1 total = total + v:get().CurrentAmount end) end)
    return string.format("%d kinds, %d items", n, total)
end
function T.widgets()
    local out = {}
    for _, w in ipairs(FindAllOf("UserWidget") or {}) do
        local ok, vis = pcall(function() return w:IsVisible() end)
        if ok and vis then
            local n = w:GetClass():GetFName():ToString()
            if n:find("Item") or n:find("Display") or n:find("Dust") or n:find("Pickup") or n:find("pickup") or n:find("Confirm") then
                out[#out + 1] = n
            end
        end
    end
    return table.concat(out, ", ")
end

-- Gameplay tags owned by a player's ability system, as one sorted string.
function T.tags(n)
    local p = T.pawn(n)
    local out = {}
    pcall(function()
        local asc = StaticFindObject("/Script/GameplayAbilities.Default__AbilitySystemBlueprintLibrary"):GetAbilitySystemComponent(p)
        local c = {}
        asc:GetOwnedGameplayTags(c)
        local tags = c.GameplayTags
        if type(tags) == "table" then
            for _, t in ipairs(tags) do out[#out + 1] = tostring(type(t) == "table" and t.TagName and t.TagName:ToString() or t) end
        else
            tags:ForEach(function(_, e) local t = e:get() out[#out + 1] = tostring(t.TagName and t.TagName:ToString() or t) end)
        end
    end)
    table.sort(out)
    return "P" .. n .. " tags(" .. #out .. "): " .. table.concat(out, " ")
end

-- Both players side by side at a spot, both cameras turned to look at a world point.
function T.pair(x, y, z, yaw)
    local r = math.rad(yaw)
    T.at(1, x, y, z, yaw)
    T.at(2, x - math.sin(r) * 90, y + math.cos(r) * 90, z, yaw)
end
function T.lookAt(n, q)
    local p = T.pawn(n):K2_GetActorLocation()
    local yaw = math.deg(math.atan(q.Y - p.Y, q.X - p.X))
    T.pc(n):SetControlRotation({ Pitch = -10, Yaw = yaw, Roll = 0 })
    return yaw
end
-- The nearest live enemy of a class name part within range of player 1, or nil.
function T.nearEnemy(part, range)
    local a = T.pawn(1):K2_GetActorLocation()
    local best, bestD
    for _, x in ipairs(FindAllOf("PBZCharacter_NPC") or {}) do
        if valid(x) and x:GetClass():GetFName():ToString():find(part, 1, true) then
            local ok, q = pcall(function() return x:K2_GetActorLocation() end)
            if ok and q.X and (q.X ~= 0 or q.Y ~= 0) then
                local d = PBZ.distance(q, a)
                if d < (range or 1500) and (not bestD or d < bestD) then best, bestD = x, d end
            end
        end
    end
    return best, bestD
end

-- ---- enemy AI probes (2026-11-01): hatred lists, AI state tag, mob domains ----
function T.nearestEnemy(n)
    local to = T.pawn(n):K2_GetActorLocation()
    local best, bestD
    for _, e in ipairs(PBZ.game.listEnemies(true)) do
        local ok, q = pcall(function() return e:K2_GetActorLocation() end)
        if ok and q.X then
            local d = PBZ.distance(q, to)
            if not bestD or d < bestD then best, bestD = e, d end
        end
    end
    return best, bestD
end
function T.compOn(owner, className)
    for _, c in ipairs(FindAllOf(className) or {}) do
        local ok, o = pcall(function() return c:GetOwner() end)
        if ok and valid(o) and o:GetAddress() == owner:GetAddress() then return c end
    end
end
function T.aiState()
    local e, d = T.nearestEnemy(2)
    if not valid(e) then return "no enemy" end
    local s = string.format("%s d2=%.0f hp=%s P2hp=%s", e:GetClass():GetFName():ToString():sub(1, 26), d, tostring(PBZ.game.getHealth(e)), tostring(PBZ.game.getHealth(T.pawn(2))))
    pcall(function()
        local hm = e.BP_PBZHatredManagerComponent
        local names = {}
        hm.HatredList:ForEach(function(_, el) names[#names + 1] = T.name(el:get(), 22) end)
        s = s .. " hatred=[" .. table.concat(names, ",") .. "]"
    end)
    pcall(function()
        local ai = T.compOn(e.Controller, "BP_SGameAIComponent_C")
        s = s .. " state=" .. tostring(ai and ai["Current State"].TagName:ToString())
    end)
    pcall(function()
        local tgt = {}
        FindFirstOf("BP_SGameAITargetingUtils_C"):GetTargetActor(e.Controller, e.Controller, tgt)
        s = s .. " target=" .. T.name(tgt.Target or tgt[1], 22)
    end)
    pcall(function()
        local out = {}
        e.Controller.PerceptionComponent:GetCurrentlyPerceivedActors(StaticFindObject("/Script/AIModule.AISense_Sight"), out)
        local names = {}
        for _, x in ipairs(out) do names[#names + 1] = T.name(x, 22) end
        s = s .. " seen=[" .. table.concat(names, ",") .. "]"
    end)
    return s
end
function T.forceCombat()
    local e = T.nearestEnemy(2)
    local ai = T.compOn(e.Controller, "BP_SGameAIComponent_C")
    if not ai then return "no ai comp" end
    ai:ForceIntoCombat(T.pawn(2))
    return "forced " .. T.name(e, 26) .. " into combat with P2"
end
local function who(x)
    if not valid(x) then return "none" end
    if x:GetAddress() == T.pawn(1):GetAddress() then return "P1" end
    if x:GetAddress() == T.pawn(2):GetAddress() then return "P2" end
    return T.name(x, 18)
end
function T.hatredOf(e)
    local names = {}
    pcall(function() e.BP_PBZHatredManagerComponent.HatredList:ForEach(function(_, el) names[#names + 1] = who(el:get()) end) end)
    return names
end
T.watched = nil
function T.aiState()
    local e = valid(T.watched) and T.watched or T.nearestEnemy(2)
    if not valid(e) then return "no enemy" end
    local d1, d2 = T.dist1(e), T.dist2(e)
    return string.format("%s d1=%.0f d2=%.0f hp=%s P2hp=%s hatred=[%s]", e:GetClass():GetFName():ToString():sub(1, 26), d1, d2,
        tostring(PBZ.game.getHealth(e)), tostring(PBZ.game.getHealth(T.pawn(2))), table.concat(T.hatredOf(e), ","))
end
function T.dist1(e) return PBZ.distance(e:K2_GetActorLocation(), T.pawn(1):K2_GetActorLocation()) end
function T.dist2(e) return PBZ.distance(e:K2_GetActorLocation(), T.pawn(2):K2_GetActorLocation()) end
-- All live enemies: hatred and distances.
function T.enemyList()
    local out = {}
    for _, e in ipairs(PBZ.game.listEnemies(true)) do
        local ok, q = pcall(function() return e:K2_GetActorLocation() end)
        if ok and q.X and (q.X ~= 0 or q.Y ~= 0) then
            out[#out + 1] = string.format("%s d1=%.0f d2=%.0f hp=%s h=[%s]", e:GetClass():GetFName():ToString():sub(12, 34), T.dist1(e), T.dist2(e), tostring(PBZ.game.getHealth(e)), table.concat(T.hatredOf(e), ","))
        end
    end
    return #out .. " enemies: " .. table.concat(out, " ; ")
end
-- Nearest enemy to player 2 that is calm (no hatred) and far from player 1.
function T.calmFar(minD1)
    local best, bestD
    for _, e in ipairs(PBZ.game.listEnemies(true)) do
        local ok, q = pcall(function() return e:K2_GetActorLocation() end)
        if ok and q.X and (q.X ~= 0 or q.Y ~= 0) and #T.hatredOf(e) == 0 and T.dist1(e) > (minD1 or 5000) then
            local d = T.dist2(e)
            if not bestD or d < bestD then best, bestD = e, d end
        end
    end
    T.watched = best
    return best, bestD
end
-- Fly player 2 to a spot in front of an actor, land after the ground has streamed in.
function T.frontOf(n, e, back)
    local l, yaw = e:K2_GetActorLocation(), e:K2_GetActorRotation().Yaw
    local r = math.rad(yaw)
    local x, y = l.X + math.cos(r) * (back or 300), l.Y + math.sin(r) * (back or 300)
    T.go(n, x, y, l.Z + 150, yaw + 180)
end
local function who(x)
    if not valid(x) then return "none" end
    if x:GetAddress() == T.pawn(1):GetAddress() then return "P1" end
    if x:GetAddress() == T.pawn(2):GetAddress() then return "P2" end
    return T.name(x, 18)
end
-- Mob domains within range of player n: who is inside, groups active, trigger count.
function T.domains(n, range)
    local to = T.pawn(n):K2_GetActorLocation()
    local out = {}
    for _, d in ipairs(FindAllOf("BP_MobDomain_C") or {}) do
        local ok, q = pcall(function() return d:K2_GetActorLocation() end)
        if ok and q.X then
            local dist = PBZ.distance(q, to)
            if dist <= (range or 15000) then
                local inside, groups, trig, in1, in2 = {}, 0, 0, "?", "?"
                pcall(function() d.ActorsInMobDomain:ForEach(function(_, el) inside[#inside + 1] = who(el:get()) end) end)
                pcall(function() d.ActivatingGroups:ForEach(function() groups = groups + 1 end) end)
                pcall(function() d.ReferencedTriggers:ForEach(function() trig = trig + 1 end) end)
                pcall(function() local r = {} d:IsActorInMobDomain(T.pawn(1), r) in1 = tostring(r.ReturnValue) end)
                pcall(function() local r = {} d:IsActorInMobDomain(T.pawn(2), r) in2 = tostring(r.ReturnValue) end)
                local ng = 0
                pcall(function() d.MobDomainConfig.MobGroups:ForEach(function() ng = ng + 1 end) end)
                out[#out + 1] = string.format("%s dist=%.0f inside=[%s] activeGroups=%d/%d triggers=%d inDomain P1=%s P2=%s", T.name(d, 24), dist, table.concat(inside, ","), groups, ng, trig, in1, in2)
            end
        end
    end
    return #out .. " domains: " .. table.concat(out, " ;; ")
end
function T.nearestDomain(n)
    local to = T.pawn(n):K2_GetActorLocation()
    local best, bestD
    for _, d in ipairs(FindAllOf("BP_MobDomain_C") or {}) do
        local ok, q = pcall(function() return d:K2_GetActorLocation() end)
        if ok and q.X then
            local dist = PBZ.distance(q, to)
            if not bestD or dist < bestD then best, bestD = d, dist end
        end
    end
    return best, bestD
end
function T.aiTag(e)
    local s = "?"
    pcall(function()
        local ai = T.compOn(e.Controller, "BP_SGameAIComponent_C")
        s = ai.CurrentStateTag.TagName:ToString() .. " started=" .. tostring(ai.bAIStarted)
    end)
    return s
end
local old = T.aiState
function T.aiState()
    local e = valid(T.watched) and T.watched or T.nearestEnemy(2)
    if not valid(e) then return "no enemy" end
    return old() .. " state=" .. T.aiTag(e)
end


-- ---- enemy baseline row and the automated lone-approach test (2026-11-01) ----
-- Baseline of every loaded enemy: optimizer wave, movement, tick intervals. Safe reads only.

local out = {}
local a, b = T.pawn(1):K2_GetActorLocation(), T.pawn(2):K2_GetActorLocation()
local proxies = {}
for _, px in ipairs(FindAllOf("OptimizationProxyComponent") or {}) do
    local ok, o = pcall(function() return px:GetOwner() end)
    if ok and valid(o) then proxies[o:GetAddress()] = px end
end
function T.enemyRow(e)
    local q = e:K2_GetActorLocation()
    local s = string.format("%s d1=%.0f d2=%.0f hp=%s", e:GetClass():GetFName():ToString():sub(12, 32), PBZ.distance(q, a), PBZ.distance(q, b), tostring(PBZ.game.getHealth(e)))
    local px = proxies[e:GetAddress()]
    pcall(function() s = s .. " wave=" .. (px and tostring(px:GetOptimizationWave()) or "-") end)
    pcall(function() s = s .. " mode=" .. tostring(e.CharacterMovement.MovementMode) .. " moveTick=" .. string.format("%.2f", e.CharacterMovement:GetComponentTickInterval()) .. "/" .. tostring(e.CharacterMovement:IsComponentTickEnabled()) end)
    pcall(function() s = s .. " actorTick=" .. string.format("%.2f", e:GetActorTickInterval()) .. "/" .. tostring(e:IsActorTickEnabled()) end)
    pcall(function() s = s .. " meshVis=" .. tostring(e.Mesh:IsVisible()) .. " meshTick=" .. tostring(e.Mesh:IsComponentTickEnabled()) .. " animOpt=" .. tostring(e.Mesh.VisibilityBasedAnimTickOption) end)
    pcall(function() local c = e.Controller s = s .. " ctlTick=" .. string.format("%.2f", c:GetActorTickInterval()) .. "/" .. tostring(c:IsActorTickEnabled()) end)
    pcall(function() s = s .. " state=" .. T.aiTag(e) end)
    pcall(function() s = s .. " hatred=[" .. table.concat(T.hatredOf(e), ",") .. "]" end)
    return s
end
for _, e in ipairs(PBZ.game.listEnemies(true)) do
    local ok, q = pcall(function() return e:K2_GetActorLocation() end)
    if ok and q.X and (q.X ~= 0 or q.Y ~= 0) then
        out[#out + 1] = T.enemyRow(e)
    end
end

-- Automated approach test: player 2 alone walks up to a calm enemy far from player 1; log what the enemy does.

function T.approachTest(minD1, seconds)
    local e, d = T.calmFar(minD1 or 6000)
    if not valid(e) then PBZ.log("APPROACH: no calm enemy beyond " .. tostring(minD1)) return "none" end
    T.watched = e
    local name = e:GetClass():GetFName():ToString():gsub("^BP_Monster_", ""):gsub("_C$", "")
    PBZ.log(string.format("APPROACH start: %s d1=%.0f (%s)", name, T.dist1(e), T.enemyRow(e)))
    T.frontOf(2, e, 300)
    local t0 = os.clock()
    local landed, noticedAt, combatAt, hitAt, modes = false, nil, nil, nil, {}
    local hp0 = PBZ.game.getHealth(T.pawn(2)) or 0
    local function step()
        local t = os.clock() - t0
        if not landed and t >= 3.5 then
            T.land(2)
            landed = true
        end
        if not valid(e) or (PBZ.game.getHealth(e) or 0) <= 0 then
            PBZ.log("APPROACH end: enemy gone/dead")
            return
        end
        local ok, row = pcall(T.enemyRow, e)
        local hp = PBZ.game.getHealth(T.pawn(2)) or 0
        local mode = "?"
        pcall(function() mode = tostring(e.CharacterMovement.MovementMode) end)
        modes[mode] = (modes[mode] or 0) + 1
        local hates = false
        for _, w in ipairs(T.hatredOf(e)) do if w == "P2" then hates = true end end
        if hates and not noticedAt then noticedAt = t end
        if not combatAt and T.aiTag(e):find("Combat") then combatAt = t end
        if not hitAt and hp < hp0 - 1 then hitAt = t end
        if landed and math.floor(t) % 4 == 0 then
            PBZ.log(string.format("APPROACH t=%.0f d2=%.0f P2hp=%.0f %s", t, T.dist2(e), hp, ok and row or "?"))
        end
        if t >= (seconds or 24) or hp <= 1 then
            local ms = {}
            for k, v in pairs(modes) do ms[#ms + 1] = k .. "x" .. v end
            PBZ.log(string.format("APPROACH summary %s: noticed=%s combat=%s firstHit=%s modes=%s", name, tostring(noticedAt), tostring(combatAt), tostring(hitAt), table.concat(ms, ",")))
            return
        end
        PBZ.game.after(1.0, step)
    end
    step()
    return "approach test running on " .. name
end


-- Walking (2026-11-01): T.walkTo(n, {X=,Y=,Z=}, radius, seconds, sprint) steers player n toward a point with held
-- move input (forward is the X axis of the move action), jumping when stuck, until within radius or the time is up;
-- T.walkPair does both players; T.stopWalk(n) ends it. T.dist(n, q) is the flat distance to q.
T.FWD = T.FWD or { x = 1, y = 0 }
T.walks = T.walks or {}
function T.walkTo(n, q, radius, seconds, sprint)
    T.walks[n] = { q = q, r = radius or 150, until_ = os.clock() + (seconds or 60), sprint = sprint, t0 = os.clock(), last = nil, stuck = 0 }
    return "walking " .. n
end
function T.stopWalk(n) T.walks[n] = nil end
function T.dist(n, q)
    local l = T.pawn(n):K2_GetActorLocation()
    return math.sqrt((q.X - l.X) ^ 2 + (q.Y - l.Y) ^ 2)
end
function T.walkPair(q, radius, seconds, sprint)
    T.walkTo(1, q, radius, seconds, sprint)
    T.walkTo(2, q, (radius or 150) + 150, seconds, sprint)
    return "walking both"
end
if not T.walkLoop then
    T.walkLoop = true
    LoopInGameThreadWithDelay(50, function()
        for n, w in pairs(T.walks) do
            local ok, err = pcall(function()
                local p = T.pawn(n)
                if not valid(p) then T.walks[n] = nil return end
                local l = p:K2_GetActorLocation()
                local d = math.sqrt((w.q.X - l.X) ^ 2 + (w.q.Y - l.Y) ^ 2)
                if d <= w.r then
                    PBZ.log(string.format("walk %d: arrived (%.0f cm, %.1f s)", n, d, os.clock() - w.t0))
                    T.walks[n] = nil
                    return
                end
                if os.clock() > w.until_ then
                    PBZ.log(string.format("walk %d: timeout at %.0f cm", n, d))
                    T.walks[n] = nil
                    return
                end
                local yaw = math.deg(math.atan(w.q.Y - l.Y, w.q.X - l.X))
                T.pc(n):SetControlRotation({ Pitch = -10, Yaw = yaw, Roll = 0 })
                T.inject(n, n == 1 and "IA_KeyboardMoveInput" or "IA_JoystickMoveInput", T.FWD.x, T.FWD.y, 0)
                if w.sprint then T.inject(n, "IA_Sprint", 1, 0, 0) end
                if w.last and math.abs(w.last - d) < 2 then
                    w.stuck = w.stuck + 1
                    if w.stuck == 20 then
                        pcall(function() p:Jump() end)
                        w.stuck = 0
                    end
                else
                    w.stuck = 0
                end
                w.last = d
            end)
            if not ok then PBZ.log("walk error: " .. tostring(err)) T.walks[n] = nil end
        end
        return false
    end)
end

return "test-helpers loaded"

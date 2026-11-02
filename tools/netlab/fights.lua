-- Boss and enemy fights on two real copies. Loaded with eval next to perf.lua and pair.lua:
--   FIGHT.state(boss id)     one line: player, boss, bar, fog and what the sync believes
--   FIGHT.swing()            a real attack, through the player's own ability
--   FIGHT.look()             the living enemy nearest player 1, what it's doing, and its loot table
--   FIGHT.dust()             dust and health of player 1, for before and after a kill

local log, valid = PBZ.log, PBZ.valid
local game, coop = PBZ.game, PBZ.coop
FIGHT = FIGHT or {}
FIGHT.ELITE = "sp:XIGU_1_4_A_EliteSword"

local function pawn()
    local _, p = PBZ.getPlayer1()
    return p
end

local function keys(t)
    local out = {}
    for k in pairs(t or {}) do out[#out + 1] = tostring(k) end
    table.sort(out)
    return table.concat(out, ",")
end

function FIGHT.bars()
    local out = {}
    pcall(function()
        local bars = FindFirstOf("PBZHUDLayout"):GetBossHPBarInstances()
        for i = 1, #bars do
            local w = bars[i]:get()
            if valid(w) then
                local pct = "?"
                pcall(function() pct = string.format("%.2f", w.hpbar.RealBar.Percent) end)
                out[#out + 1] = pct
            end
        end
    end)
    return #out .. "[" .. table.concat(out, " ") .. "]"
end

function FIGHT.fog()
    local p, out = pawn(), {}
    local here = p:K2_GetActorLocation()
    for _, d in ipairs(FindAllOf("BP_FogDoor_C") or {}) do
        local ok, loc = pcall(function() return d:K2_GetActorLocation() end)
        if ok and loc.X and PBZ.distance(loc, here) < 12000 then
            local st = "?"
            pcall(function() st = tostring(d.bDesiredState) end)
            out[#out + 1] = string.format("%.0f,%.0f=%s(%.0fm)", loc.X, loc.Y, st, PBZ.distance(loc, here) / 100)
        end
    end
    return table.concat(out, " ")
end

function FIGHT.boss(id)
    id = id or FIGHT.ELITE
    local e = coop.enemyActor(id)
    if valid(e) then
        return e
    end
    local sid = id:match("^sp:(.+)$")
    for _, s in ipairs(sid and FindAllOf("AISpawner") or {}) do
        local got
        pcall(function() got = s.SpawnerID:ToString() end)
        if got == sid or s:GetFName():ToString() == sid then
            local a
            pcall(function() a = s.SpawnedAI end)
            if valid(a) then
                return a
            end
        end
    end
    return nil
end

function FIGHT.state(id)
    local p, net = pawn(), PBZ.net
    local l = p:K2_GetActorLocation()
    local hp, max = game.getHealth(p)
    local e = FIGHT.boss(id)
    local bossText = "no boss"
    if valid(e) then
        local b, bm = game.getHealth(e)
        local bl = e:K2_GetActorLocation()
        bossText = string.format("boss %.0f/%.0f dead=%s isBoss=%s at %.0f %.0f %.0f (%.0f m) min=%.0f",
            b or -1, bm or -1, tostring(game.isDead(e)), tostring(game.isBoss(e)), bl.X, bl.Y, bl.Z,
            PBZ.distance(bl, l) / 100, e.AttributeSetBase.Health_Min.CurrentValue)
    end
    return string.format("STATE me %.0f %.0f %.0f hp %.0f/%.0f mode %s dust %s | %s | bars %s active=%s | fog %s | fogged {%s} partner {%s} pending {%s} hostBosses {%s} joined %s",
        l.X, l.Y, l.Z, hp or -1, max or -1, tostring(p.CharacterMovement.MovementMode), tostring(p.ConsciousnessDust),
        bossText, FIGHT.bars(), tostring(game.bossFightActive()), FIGHT.fog(), keys(net.foggedBosses), keys(net.partnerBosses),
        keys(net.pendingBosses), keys(net.hostBosses), tostring(net.joinedBoss))
end

local function abilityClass()
    local asc = StaticFindObject("/Script/GameplayAbilities.Default__AbilitySystemBlueprintLibrary"):GetAbilitySystemComponent(pawn())
    local c
    asc.ActivatableAbilities.Items:ForEach(function(_, x)
        pcall(function()
            local ab = x:get().Ability
            if c == nil and valid(ab) then
                local n = ab:GetClass():GetFName():ToString()
                if n:match("^GA_Hun_.+_A_C$") then c = ab:GetClass() end
            end
        end)
    end)
    return c, asc
end

function FIGHT.swing()
    if FIGHT.use("BP_SwitchAttack_Default_C") == "true" then return "swing true" end   -- what the attack key starts
    local c, asc = abilityClass()
    if not valid(c) then return "no attack ability" end
    return "swing " .. tostring(asc:TryActivateAbilityByClass(c, true))
end

-- The abilities player 1 owns whose class name matches, to find what a key really does.
function FIGHT.abilities(pattern)
    local asc = StaticFindObject("/Script/GameplayAbilities.Default__AbilitySystemBlueprintLibrary"):GetAbilitySystemComponent(pawn())
    local out = {}
    asc.ActivatableAbilities.Items:ForEach(function(_, x)
        pcall(function()
            local ab = x:get().Ability
            if valid(ab) then
                local n = ab:GetClass():GetFName():ToString()
                if not pattern or n:match(pattern) then out[#out + 1] = n end
            end
        end)
    end)
    table.sort(out)
    return table.concat(out, " ")
end

-- One of player 1's abilities by class name, the way its key would start it.
function FIGHT.use(name)
    local asc = StaticFindObject("/Script/GameplayAbilities.Default__AbilitySystemBlueprintLibrary"):GetAbilitySystemComponent(pawn())
    local c
    asc.ActivatableAbilities.Items:ForEach(function(_, x)
        pcall(function()
            local ab = x:get().Ability
            if c == nil and valid(ab) and ab:GetClass():GetFName():ToString() == name then c = ab:GetClass() end
        end)
    end)
    if not valid(c) then return "no " .. name end
    return tostring(asc:TryActivateAbilityByClass(c, true))
end

-- Logs each change to player 1's health and posture for this long, starting an ability every so many seconds if given
-- (a guard kept up, or tapped). The loop can't be ended from here, so it just goes quiet.
function FIGHT.hits(seconds, ability, every)
    local p, t0, nextUse = pawn(), os.clock(), 0
    local hp, posture = game.getHealth(p), game.getPosture(p)
    local tally = { hits = 0, lost = 0, posture = 0, used = 0 }
    FIGHT.tally = tally
    FIGHT.hitsId = (FIGHT.hitsId or 0) + 1
    local id = FIGHT.hitsId
    LoopInGameThreadWithDelay(50, function()
        if id ~= FIGHT.hitsId then return false end
        local t = os.clock() - t0
        if t > seconds then
            FIGHT.hitsId = FIGHT.hitsId + 1
            log(string.format("HITS over: %d changes, health -%.0f, posture -%.0f, %s used %d times", tally.hits, tally.lost,
                tally.posture, tostring(ability), tally.used))
            return false
        end
        if ability and t >= nextUse then
            nextUse = t + (every or 0.4)
            if FIGHT.use(ability) == "true" then tally.used = tally.used + 1 end
        end
        local h, s = game.getHealth(p), game.getPosture(p)
        if h and hp and (math.abs(h - hp) > 0.5 or (s and posture and math.abs(s - posture) > 0.5)) then
            tally.hits = tally.hits + 1
            tally.lost = tally.lost + math.max(0, hp - h)
            tally.posture = tally.posture + math.max(0, (posture or 0) - (s or 0))
            log(string.format("HITS %.2f health %.0f -> %.0f posture %.0f -> %.0f", t, hp, h, posture or -1, s or -1))
        end
        hp, posture = h or hp, s or posture
        return false
    end)
end

-- Faces player 1 at an actor from this far away. A stale actor reads as the world origin: player 1 stays put then.
function FIGHT.beside(e, cm)
    local p = pawn()
    local l = valid(e) and e:K2_GetActorLocation()
    if not (l and l.X and (math.abs(l.X) > 100 or math.abs(l.Y) > 100)) then
        return false
    end
    p:K2_SetActorLocation({ X = l.X - (cm or 180), Y = l.Y, Z = l.Z + 30 }, false, {}, true)
    p:K2_SetActorRotation({ Pitch = 0.0, Yaw = 0.0, Roll = 0.0 }, false)
    return true
end

local function show(v)
    local t = type(v)
    if t == "userdata" or t == "table" then
        local s = t
        pcall(function() s = t .. ":" .. v:ToString() end)
        pcall(function() s = t .. ":get " .. tostring(v:get()) end)
        pcall(function() s = t .. ":get " .. v:get():ToString() end)
        return s
    end
    return t .. ":" .. tostring(v)
end

-- What the loot tables hold, raw: each enemy class loaded, at its own level and a few forced ones.
function FIGHT.lootScan()
    local seen, n = {}, 0
    for _, e in ipairs(game.listEnemies(true)) do
        local cn = valid(e) and e:GetClass():GetFName():ToString()
        if cn and not seen[cn] and n < 12 then
            seen[cn], n = true, n + 1
            local own = 0
            pcall(function() own = math.floor(e.AttributeSetBase.Level.CurrentValue + 0.5) end)
            local found = {}
            for _, lv in ipairs({ own, 1, 3, 5, 10, 20, 40 }) do
                local data = {}
                if pcall(function() e:GetCombatLootDataBySelf(lv, data) end) then
                    for _, f in ipairs({ "LootItems", "LootWeapons", "Medicines", "Accessories" }) do
                        for k, v in pairs(type(data[f]) == "table" and data[f] or {}) do
                            found[#found + 1] = string.format("L%d %s %s=%s", lv, f, show(k), show(v))
                        end
                    end
                end
            end
            log(string.format("LOOT scan %s own level %d: %d entries %s", cn, own, #found,
                table.concat(found, " | "):sub(1, 260)))
        end
    end
    return "LOOT scan done, " .. n .. " classes"
end

-- Gets the next kill's roll ready: the first level at which this enemy's table gives items. With none at any level, one
-- prop the backpack already holds goes through that roll instead, so the way to the partner still runs, and the log says so.
function FIGHT.armLoot(e)
    local own = 0
    pcall(function() own = math.floor(e.AttributeSetBase.Level.CurrentValue + 0.5) end)
    for _, lv in ipairs({ own, 1, 3, 5, 10, 20, 40, 60 }) do
        game.lootLevelOverride = lv
        local dust, items = game.rollLoot(e)
        if #items > 0 then
            local list = {}
            for _, item in ipairs(items) do
                list[#list + 1] = string.format("%s x%d %s", item.id, item.count, tostring(item.kind))
            end
            return string.format("LOOT real items at level %d: dust %d, %s", lv, dust, table.concat(list, ", "))
        end
    end
    game.lootLevelOverride = nil
    local p = pawn()
    local bp = StaticFindObject("/Script/Engine.Default__SubsystemBlueprintLibrary"):GetWorldSubsystem(p,
        StaticFindObject("/Script/ProjectPBZ.PBZBackPackSubsystem"))
    local id
    pcall(function()
        bp.Inventories:ForEach(function(k, v)
            pcall(function()
                if id == nil and v:get().CurrentAmount > 0 then
                    id = k:get():ToString()
                end
            end)
        end)
    end)
    if id == nil then
        return "LOOT no real items and no prop to test with"
    end
    local orig = game.rollLoot
    game.rollLoot = function(a)
        game.rollLoot = orig
        local dust, items, level = orig(a)
        items[#items + 1] = { id = id, count = 1 }
        log("LOOT test item added to this roll (not from the table): " .. id)
        return dust, items, level
    end
    return "LOOT no real items at any level; test item armed: " .. id
end

-- One line a second: is the bar up, and is the fight still on?
function FIGHT.watchBars(seconds)
    local n = 0
    local function step()
        n = n + 1
        local e = coop.enemyActor(FIGHT.ELITE)
        log(string.format("STATE bars #%d %s active=%s boss alive=%s partner {%s}", n, FIGHT.bars(), tostring(game.bossFightActive()),
            tostring(valid(e) and not game.isDead(e)), keys(PBZ.net.partnerBosses)))
        if n < seconds then
            game.after(1.0, step)
        end
    end
    step()
    return "watching bars"
end

-- Takes the bar down as the game would, without a word to the mod's fight: keepBossBar must put it back.
function FIGHT.dropBar()
    local e = coop.enemyActor(FIGHT.ELITE)
    if not valid(e) then
        return "STATE no boss to drop the bar of"
    end
    FindFirstOf("PBZHUDLayout"):UnRegisterBossHPBar(e)
    return "STATE bar dropped, bars now " .. FIGHT.bars()
end

-- Is a fight still believed in, and does the list of live bosses agree?
function FIGHT.active()
    local before = game.bossFightActive()
    local live = #game.bossActors()
    return string.format("STATE active %s, live bosses %d, active after asking %s, bars %s, calm left %.1f", tostring(before), live,
        tostring(game.bossFightActive()), FIGHT.bars(), (PBZ.net.noPullUntil or 0) - os.clock())
end

-- Back to normal after a fight: the health floor off, full health, nothing armed, no loot card left up.
function FIGHT.tidy()
    local p = pawn()
    game.lootLevelOverride = nil
    game.setMinHealth(p, 0)
    local _, m = game.getHealth(p)
    if m then
        game.setHealth(p, m)
    end
    for _, w in ipairs(FindAllOf("W_pickupgear_C") or {}) do
        pcall(function()
            if w:IsVisible() then
                w:DeactivateWidget()
            end
        end)
    end
    return FIGHT.state()
end

function FIGHT.dust()
    local p = pawn()
    local hp, max = game.getHealth(p)
    return string.format("DUST %s hp %.0f/%.0f", tostring(p.ConsciousnessDust), hp or -1, max or -1)
end

function FIGHT.nearest()
    local p = pawn()
    local here, best, bd = p:K2_GetActorLocation(), nil, 1e12
    for _, e in ipairs(game.listEnemies(true)) do
        if valid(e) and not game.isDead(e) then
            local d = PBZ.distance(e:K2_GetActorLocation(), here)
            if d < bd then best, bd = e, d end
        end
    end
    return best, bd
end

-- What the enemy is doing right now: montage, position and the running ability.
function FIGHT.doing(e)
    local m, pos = "-", 0
    pcall(function()
        local ai = e.Mesh:GetAnimInstance()
        local mo = ai:GetCurrentActiveMontage()
        if valid(mo) then
            m = mo:GetFName():ToString()
            pos = ai:Montage_GetPosition(mo) or 0
        end
    end)
    local ab = game.activeAbility(e, function(n) return n:find("Passive") or n:find("Subtitles") or n:find("Locomotion") or n:find("SpaceState") or n:find("Stance") or n:find("Utilities") end)
    return string.format("montage %s @%.2f ability %s", m, pos, tostring(ab and ab:match("[^%.]+$")))
end

-- The classes an enemy is made of, for finding blueprint function paths.
function FIGHT.chain(e)
    local out, c = {}, e:GetClass()
    for _ = 1, 12 do
        if not valid(c) then break end
        out[#out + 1] = c:GetFullName():gsub("^%S+ ", "")
        c = c:GetSuperStruct()
    end
    return table.concat(out, " < ")
end

-- Reads one loot roll of this enemy at a level; all the fields, each in its own pcall.
function FIGHT.loot(e, level)
    local lv = -1
    pcall(function() lv = e.AttributeSetBase.Level.CurrentValue end)
    level = level or math.floor(lv + 0.5)
    local data = {}
    local ok, err = pcall(function() e:GetCombatLootDataBySelf(level, data) end)
    log(string.format("LOOT %s attr level %.1f rolled at %d ok=%s err=%s dust=%s", e:GetFName():ToString(), lv, level, tostring(ok), tostring(err), tostring(data.LootDust)))
    local function try(label, f)
        local okf, e2 = pcall(f)
        log("LOOT " .. label .. " read: " .. tostring(okf) .. " " .. tostring(e2) .. " type " .. type(data[label]))
    end
    try("LootItems", function() data.LootItems:ForEach(function(k, v) log("LOOT item " .. k:get():ToString() .. " x" .. tostring(v:get())) end) end)
    try("LootWeapons", function() data.LootWeapons:ForEach(function(k, v) log("LOOT weapon " .. k:get():ToString() .. " " .. tostring(v:get())) end) end)
    try("Medicines", function() log("LOOT medicines " .. #data.Medicines) for i = 1, #data.Medicines do log("LOOT medicine " .. data.Medicines[i]:get():ToString()) end end)
    try("Accessories", function() log("LOOT accessories " .. #data.Accessories) for i = 1, #data.Accessories do log("LOOT accessory " .. data.Accessories[i]:get():ToString()) end end)
    return "loot read"
end

-- Spawners within this far of a spot, with what they have out.
function FIGHT.spawners(x, y, cm)
    local spot = { X = x, Y = y, Z = 0 }
    for _, s in ipairs(FindAllOf("AISpawner") or {}) do
        local ok, l = pcall(function() return s:K2_GetActorLocation() end)
        if ok and l.X and math.sqrt((l.X - x) ^ 2 + (l.Y - y) ^ 2) <= cm then
            local sid, a = "?", nil
            pcall(function() sid = s.SpawnerID:ToString() end)
            pcall(function() a = s.SpawnedAI end)
            log(string.format("SPAWNER %s %s at %.0f %.0f %.0f has %s", sid, s:GetFName():ToString(), l.X, l.Y, l.Z,
                valid(a) and a:GetClass():GetFName():ToString() or "-"))
        end
    end
    return "spawners listed"
end

-- Every HUD layout the game holds, and the boss bars of each.
function FIGHT.huds()
    local out = {}
    for _, h in ipairs(FindAllOf("PBZHUDLayout") or {}) do
        local n, line = "?", h:GetFullName()
        pcall(function() n = #h:GetBossHPBarInstances() end)
        out[#out + 1] = tostring(n) .. " bars in " .. line:sub(-70)
    end
    return "HUDS " .. #out .. ": " .. table.concat(out, " | ")
end

-- Logs every call of the game's own loot step.
function FIGHT.hookLoot(path)
    if FIGHT.lootHooked then return "already" end
    local ok, err = pcall(function()
        RegisterHook(path, function(self)
            local who = "?"
            pcall(function() who = self:get():GetFName():ToString() end)
            log("LOOT native LootItems ran on " .. who .. " dust now " .. tostring(pawn().ConsciousnessDust))
        end)
    end)
    FIGHT.lootHooked = ok
    return "hook " .. tostring(ok) .. " " .. tostring(err)
end

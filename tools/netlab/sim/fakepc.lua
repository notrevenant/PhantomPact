-- One PC with no game on it: the Lua globals UE4SS gives the mod, a file system in memory, a clock that only moves when the
-- test says so, and as much of the game as the online code touches. Each PC loads the mod's real scripts into a world of its
-- own, so four of them in one Lua state know each other only through the relay in simrelay.lua.
--
-- Objects act like UObjects: what's not defined here is nil, as a wrong name would be in the game. Every call or write that
-- changes something goes into pc.trace, so two runs can be compared call by call (two.lua).

local Fake = {}

local READING = { "^Get", "^K2_Get", "^Is", "^Find", "^Check", "^Can", "^Montage_Get", "^ToString$", "^Project" }

local function reads(name)
    for _, pattern in ipairs(READING) do
        if name:find(pattern) then
            return true
        end
    end
    return false
end

local function show(v)
    if type(v) == "number" then
        return math.type(v) == "integer" and tostring(v) or string.format("%.3f", v)
    elseif type(v) == "function" then
        return "function"
    elseif type(v) == "table" then
        local class = rawget(v, "__class")
        if class then
            return class
        end
        if v.X then
            return string.format("(%.1f %.1f %.1f)", v.X, v.Y or 0, v.Z or 0)
        end
        if v.Yaw then
            return string.format("yaw %.1f", v.Yaw)
        end
        return "{}"
    end
    return tostring(v)
end

local function record(pc, class, name, ...)
    if pc.quiet then
        return
    end
    local parts = { string.format("%.3f", pc.now), class, name }
    for i = 1, select("#", ...) do
        parts[#parts + 1] = show((select(i, ...)))
    end
    pc.trace[#pc.trace + 1] = table.concat(parts, " ")
end

local Common = {
    IsValid = function(self) return rawget(self, "__alive") end,
    GetAddress = function(self) return rawget(self, "__addr") end,
    GetClass = function(self) return rawget(self, "__classObject") or self end,
    GetFName = function(self)
        local name = rawget(self, "__name") or rawget(self, "__class")
        return { ToString = function() return name end }
    end,
    GetFullName = function(self) return "Fake " .. tostring(rawget(self, "__path") or rawget(self, "__class")) end,
    IsA = function() return true end,
    ForEachProperty = function() end,
}

local function makeMeta(pc)
    return {
        __index = function(t, k)
            pc.calls = pc.calls + 1
            local f = rawget(t, "__fields")[k]
            if f ~= nil then
                return f
            end
            if Common[k] then
                return Common[k]
            end
            if rawget(t, "__open") then           -- UI: anything goes, and nothing about it is tested
                return function() end
            end
            pc.missing[rawget(t, "__class") .. "." .. tostring(k)] = true
            return nil
        end,
        __newindex = function(t, k, v)
            record(pc, rawget(t, "__class"), "set " .. tostring(k), v)
            rawget(t, "__fields")[k] = v
        end,
    }
end

-- Writes without leaving a trace: the test's own hand on the world.
local function put(o, k, v)
    rawget(o, "__fields")[k] = v
end

local function object(pc, class, fields, open)
    pc.nextAddress = pc.nextAddress + 16
    local o = { __addr = pc.nextAddress, __class = class, __alive = true, __fields = {}, __open = open }
    setmetatable(o, pc.meta)
    for k, v in pairs(fields or {}) do
        put(o, k, v)
    end
    return o
end

-- A method that goes into the trace unless it only reads.
local function def(pc, o, name, fn)
    local class = rawget(o, "__class")
    local quietly = reads(name)
    put(o, name, function(self, ...)
        if not quietly then
            record(pc, class, name, ...)
        end
        if fn then
            return fn(self, ...)
        end
    end)
end

local function defs(pc, o, list)
    for name, fn in pairs(list) do
        def(pc, o, name, fn or nil)
    end
end

local function attribute(pc, value)
    return object(pc, "Attr", { BaseValue = value, CurrentValue = value })
end

local function list(items)
    return {
        ForEach = function(_, fn)
            for i, v in ipairs(items) do
                fn(i, { get = function() return v end })
            end
        end,
        items = items,
    }
end

local function name(text)
    return { ToString = function() return text end }
end

function Fake.character(pc, class, x, y, z, hp, posture)
    local a = object(pc, class)
    put(a, "loc", { X = x, Y = y, Z = z })
    put(a, "yaw", 0.0)
    put(a, "dead", false)
    put(a, "AttributeSetBase", object(pc, "Attributes", {
        Health = attribute(pc, hp), Health_Max = attribute(pc, hp), Health_Min = attribute(pc, 0), Attack = attribute(pc, 50),
        Shachi = attribute(pc, posture or 100), Shachi_Max = attribute(pc, posture or 100), Level = attribute(pc, 1),
    }))
    local cmc = object(pc, "Movement", { MovementMode = 1, Velocity = { X = 0.0, Y = 0.0, Z = 0.0 }, MaxWalkSpeed = 0, AirControl = 0,
        MaxAcceleration = 0, bRunPhysicsWithNoController = false, bOrientRotationToMovement = true })
    defs(pc, cmc, { SetMovementMode = function(self, mode) put(self, "MovementMode", mode) end, DisableMovement = false,
        IsFalling = function() return false end })
    put(a, "CharacterMovement", cmc)
    local capsule = object(pc, "Capsule")
    defs(pc, capsule, { SetCollisionResponseToChannel = false })
    put(a, "CapsuleComponent", capsule)
    local anim = object(pc, "Anim", { montage = nil })
    defs(pc, anim, {
        GetCurrentActiveMontage = function(self) return rawget(self, "__fields").montage end,
        Montage_GetPosition = function() return 0.25 end,
        Montage_Play = function(self, m) put(self, "montage", m) put(self, "played", (rawget(self, "__fields").played or 0) + 1) return 1.0 end,
        Montage_Stop = function(self) put(self, "montage", nil) end,
    })
    local mesh = object(pc, "Mesh")
    defs(pc, mesh, { GetAnimInstance = function() return anim end })
    put(a, "Mesh", mesh)
    put(a, "anim", anim)
    local weapons = object(pc, "Weapons", { armed = false, config = nil })
    defs(pc, weapons, {
        IsArmed = function(self) return rawget(self, "__fields").armed end,
        GetCurrentWeapon = function(self, _, data) data.WeaponConfig = rawget(self, "__fields").config end,
        GetCurrentWeaponIndex = function() return 0 end,
        SetSlotWeapon = function(self, _, _, cfg) put(self, "config", cfg) end,
        SetArmed = function(self, _, on) put(self, "armed", on) end,
        SetWeaponAndScabbardForceHide = function(self, _, _, hide) put(self, "hidden", hide) end,
    })
    put(a, "Character Weapons Component", weapons)
    defs(pc, a, {
        K2_GetActorLocation = function(self)
            local l = rawget(self, "__fields").loc
            return { X = l.X, Y = l.Y, Z = l.Z }
        end,
        K2_GetActorRotation = function(self) return { Pitch = 0.0, Yaw = rawget(self, "__fields").yaw, Roll = 0.0 } end,
        K2_SetActorLocation = function(self, l)
            put(self, "loc", { X = l.X, Y = l.Y, Z = l.Z })
            return true
        end,
        K2_SetActorLocationAndRotation = function(self, l, r)
            put(self, "loc", { X = l.X, Y = l.Y, Z = l.Z })
            put(self, "yaw", r.Yaw)
            return true
        end,
        K2_SetActorRotation = function(self, r) put(self, "yaw", r.Yaw) return true end,
        K2_DestroyActor = function(self)
            rawset(self, "__alive", false)
        end,
        AddMovementInput = function(self, dir, scale)
            -- A ghost walks where it's told, one frame's worth.
            local f = rawget(self, "__fields")
            local speed = f.CharacterMovement.MaxWalkSpeed
            local step = speed * scale / 60
            f.loc = { X = f.loc.X + dir.X * step, Y = f.loc.Y + dir.Y * step, Z = f.loc.Z }
        end,
        LaunchCharacter = false,
        SetActorHiddenInGame = function(self, on) put(self, "hidden", on) end,
        SetActorEnableCollision = false,
        IsDead = function(self) return rawget(self, "__fields").dead end,
    })
    local hit = object(pc, "HitreactComponent", { state = "None" })
    defs(pc, hit, {
        GetOwner = function() return a end,
        GetCurrentHitState = function(self) return { TagName = name(rawget(self, "__fields").state) } end,
        ChangeHitState = function(self, tag) put(self, "state", tag.TagName:ToString()) end,
    })
    put(a, "hit", hit)
    pc.hitComps[#pc.hitComps + 1] = hit
    local side = object(pc, "FactionComponent")
    defs(pc, side, { GetOwner = function() return a end, SetFactionRelationOverride = false, ClearFactionRelationOverride = false })
    pc.factions[#pc.factions + 1] = side
    return a
end

-- Things lying in the world, named alike on every PC.
function Fake.pickup(pc, id, item, x, y, z)
    local p = object(pc, "PBZPickupActor", { ItemId = name(item), bIsPickable = true })
    rawset(p, "__name", id)
    defs(pc, p, { K2_GetActorLocation = function() return { X = x, Y = y, Z = z } end, K2_DestroyActor = function(self) rawset(self, "__alive", false) end })
    pc.pickups[#pc.pickups + 1] = p
    return p
end

function Fake.chest(pc, id, x, y, z)
    local c = object(pc, "BP_Chest_C", { CurSwitchState = false, bInteracted = false })
    rawset(c, "__name", id)
    defs(pc, c, { K2_GetActorLocation = function() return { X = x, Y = y, Z = z } end,
        SwitchWithoutPlaySequence = function(self) put(self, "CurSwitchState", true) end })
    pc.chests[#pc.chests + 1] = c
    return c
end

function Fake.setHealth(a, hp)
    local h = rawget(a, "__fields").AttributeSetBase.Health
    put(h, "CurrentValue", hp)
    put(h, "BaseValue", hp)
end

function Fake.health(a)
    local set = rawget(a, "__fields").AttributeSetBase
    return set.Health.CurrentValue, set.Health_Max.CurrentValue, set.Shachi_Max.CurrentValue
end

local function hatredOf(pc, owner)
    local h = object(pc, "Hatred", { HatredList = list({}), CanBeHatredNow = true })
    local items = rawget(h, "__fields").HatredList.items
    defs(pc, h, {
        AddActorToHatredList = function(_, actor)
            for _, a in ipairs(items) do
                if a == actor then
                    return
                end
            end
            if rawget(rawget(actor, "__fields").BP_PBZHatredManagerComponent or {}, "__fields")
                and rawget(actor, "__fields").BP_PBZHatredManagerComponent.CanBeHatredNow == false then
                return
            end
            items[#items + 1] = actor
        end,
        RemoveActorFromHatredList = function(_, actor)
            for i, a in ipairs(items) do
                if a == actor then
                    table.remove(items, i)
                    return
                end
            end
        end,
        CheckCanHatredTarget = function(_, actor)
            return rawget(actor, "__fields").BP_PBZHatredManagerComponent.CanBeHatredNow ~= false
        end,
    })
    put(owner, "BP_PBZHatredManagerComponent", h)
    return h
end

-- The enemy's own target picker: the nearest on its hatred list, as the game's AIScript_TargetSelector does, looked at again
-- after the cooldown. With nobody on the list it keeps the target it has, as the game's does: a boss went on swinging at the spot.
local function pick(pc, e)
    local f = rawget(e, "__fields")
    local items = rawget(f.BP_PBZHatredManagerComponent, "__fields").HatredList.items
    local best, bestD = nil, 1e18
    for _, a in ipairs(items) do
        if rawget(a, "__alive") and not rawget(a, "__fields").dead then
            local l, m = rawget(a, "__fields").loc, f.loc
            local d = (l.X - m.X) ^ 2 + (l.Y - m.Y) ^ 2
            if d < bestD then
                best, bestD = a, d
            end
        end
    end
    if best ~= nil and best ~= f.target then
        put(e, "target", best)
        put(e, "targetChanges", (f.targetChanges or 0) + 1)
    end
end

function Fake.enemy(pc, id, class, x, y, z, hp, posture, boss)
    local e = Fake.character(pc, class, x, y, z, hp, posture)
    rawset(e, "__name", id .. "_actor")
    local f = rawget(e, "__fields")
    put(e, "BIsMonster", true)
    put(e, "boss", boss == true)
    put(e, "dustLoot", 0)
    hatredOf(pc, e)
    local picker = object(pc, "AIScript_TargetSelector_C", { LastSwitchTime = -1e9, SwitchTargetCooldown = 1.5 })
    defs(pc, picker, { TrySwitchTarget = function(self)
        put(self, "LastSwitchTime", pc.now)
        pick(pc, e)
    end })
    put(e, "picker", picker)
    local brain = object(pc, "Brain", { running = true })
    defs(pc, brain, {
        IsRunning = function(self) return rawget(self, "__fields").running end,
        StopLogic = function(self) put(self, "running", false) end,
        RestartLogic = function(self) put(self, "running", true) end,
    })
    local controller = object(pc, "AIController", { BrainComponent = brain,
        SGameAIComponent = { SpawnedAIScripts = list({ picker }) }, Blackboard = object(pc, "Blackboard") })
    put(e, "Controller", controller)
    defs(pc, e, {
        GetController = function() return controller end,
        Kill = function(self, reason)
            put(self, "dead", true)
            Fake.setHealth(self, 0)
            put(self, "killedBy", reason)
        end,
        GetCombatLootDataBySelf = function(self, _, data) data.LootDust = f.dustLoot end,
    })
    local spawner = object(pc, "AISpawner", { SpawnerID = name(id), SpawnedAI = e })
    defs(pc, spawner, { K2_GetActorLocation = function() return { X = x, Y = y, Z = z } end, ClaimSeqSpawn = false })
    pc.spawners[#pc.spawners + 1] = spawner
    pc.enemies[#pc.enemies + 1] = e
    return e
end

-- The AI of an enemy nobody stopped: it looks at its target again when its cooldown is up.
function Fake.thinkEnemies(pc)
    for _, e in ipairs(pc.enemies) do
        local f = rawget(e, "__fields")
        local picker = rawget(f.picker, "__fields")
        if rawget(f.Controller, "__fields").BrainComponent and not f.dead
            and rawget(rawget(f.Controller, "__fields").BrainComponent, "__fields").running
            and pc.now - picker.LastSwitchTime >= picker.SwitchTargetCooldown then
            picker.LastSwitchTime = pc.now
            pick(pc, e)
        end
    end
end

-- Files, in memory, by name: all the mod's are in one folder.
local function files(pc)
    local function base(path)
        return (path:gsub("\\", "/"):match("([^/]+)$"))
    end
    local fs = {}
    function fs.open(path, mode)
        local key = base(path)
        mode = mode or "r"
        if mode:find("r") then
            local text = pc.files[key]
            if text == nil then
                return nil
            end
            local pos = 1
            return {
                read = function(_, what)
                    if what == "a" then
                        local rest = text:sub(pos)
                        pos = #text + 1
                        return rest
                    end
                    return nil
                end,
                seek = function() return #text end,
                close = function() end,
            }
        end
        local out = {}
        return {
            write = function(self, s)
                out[#out + 1] = s
                return self
            end,
            close = function() pc.files[key] = table.concat(out) end,
        }
    end
    function fs.remove(path)
        pc.files[base(path)] = nil
        return true
    end
    function fs.rename(a, b)
        pc.files[base(b)] = pc.files[base(a)]
        pc.files[base(a)] = nil
        return true
    end
    return fs
end

function Fake.new(id, scripts, ini, link)
    local pc = { id = id, scripts = scripts, now = 100.0, trace = {}, logs = {}, errors = {}, missing = {}, files = {}, loops = {}, hooks = {},
        nextAddress = 0x100000, calls = 0, keys = {}, enemies = {}, spawners = {}, spawned = {}, hitComps = {}, factions = {}, pickups = {}, chests = {}, link = link, map = "Map_Xigu",
        paused = false }
    pc.meta = makeMeta(pc)
    -- The same lines as settings.txt (what the panels save now) and PhantomPact.ini (what scripts before 1.6 read), so
    -- two.lua can run old scripts against new ones.
    pc.files["settings.txt"] = ini
    pc.files["PhantomPact.ini"] = ini
    pc.files["enabled.txt"] = ""

    local world = {}
    pc.world = world
    local pawnClass = object(pc, "BP_Renewal_Hun_C")
    pc.pawnClass = pawnClass
    local function newPawn(x, y, z)
        local p = Fake.character(pc, "BP_Renewal_Hun_C", x, y, z, 1000, 100)
        rawset(p, "__classObject", pawnClass)
        hatredOf(pc, p)
        put(p, "ConsciousnessDust", 0)
        put(p, "ChangeDustNumInternal", function(self, n)
            record(pc, "Pawn", "ChangeDustNumInternal", n)
            put(self, "ConsciousnessDust", rawget(self, "__fields").ConsciousnessDust + n)
        end)
        put(p, "GiveItem", function() end)
        return p
    end
    pc.newPawn = newPawn
    local pawn = newPawn(0.0, 0.0, 100.0)
    pc.pawn = pawn
    local death = object(pc, "DeathWidget", { NotTick = false }, true)
    put(pawn, "Death Widget", death)
    pc.deathWidget = death
    local widgets = {}
    local camera = object(pc, "Camera")
    defs(pc, camera, { GetCameraRotation = function() return { Yaw = 0.0 } end, GetCameraLocation = function() return { X = 0, Y = 0, Z = 0 } end })
    local controller = object(pc, "PlayerController", { Pawn = pawn, PlayerCameraManager = camera, viewTarget = nil })
    pc.controller = controller
    defs(pc, controller, {
        IsInputKeyDown = function(_, key) return pc.keys[key.KeyName:ToString()] == true end,
        SetViewTargetWithBlend = function(self, target) put(self, "viewTarget", target) end,
    })
    local mode = object(pc, "GameMode")
    put(mode, "Refresh Monster", function()
        record(pc, "GameMode", "Refresh Monster")
        for _, fn in ipairs(pc.hooks["/Game/PBZContent/Blueprint/BP_GameMode_Build.BP_GameMode_Build_C:Refresh Monster"] or {}) do
            fn()
        end
    end)
    local gs = object(pc, "GameplayStatics")
    defs(pc, gs, {
        GetPlayerController = function() return controller end,
        GetGameMode = function() return mode end,
        IsGamePaused = function() return pc.paused end,
        SetGamePaused = function(_, _, on) pc.paused = on end,
        GetTimeSeconds = function() return pc.now end,
        GetCurrentLevelName = function() return name(pc.map) end,
        BeginDeferredActorSpawnFromClass = function(_, _, cls, t)
            if cls == pawnClass then
                local g = newPawn(t.Translation.X, t.Translation.Y, t.Translation.Z)
                pc.spawned[#pc.spawned + 1] = g
                return g
            end
            local cam = object(pc, "CameraActor", { loc = { X = t.Translation.X, Y = t.Translation.Y, Z = t.Translation.Z } }, true)
            put(cam, "K2_GetActorLocation", function(self) return rawget(self, "__fields").loc end)
            put(cam, "K2_SetActorLocationAndRotation", function(self, l) put(self, "loc", l) end)
            return cam
        end,
        FinishSpawningActor = function(_, actor) return actor end,
    })
    local hudLayout = object(pc, "PBZHUDLayout", { bars = {} })
    defs(pc, hudLayout, {
        RegisterBossHPBar = function(_, boss)
            for _, fn in ipairs(pc.hooks["/Script/ProjectPBZ.PBZHUDLayout:RegisterBossHPBar"] or {}) do
                fn(hudLayout, { get = function() return boss end })
            end
        end,
        UnRegisterBossHPBar = function(_, boss)
            for _, fn in ipairs(pc.hooks["/Script/ProjectPBZ.PBZHUDLayout:UnRegisterBossHPBar"] or {}) do
                fn(hudLayout, { get = function() return boss end })
            end
        end,
        GetBossHPBarInstances = function() return {} end,
    })
    pc.hudLayout = hudLayout
    local gourd = object(pc, "Gourd", { CurrentTime = 2, MaxTime = 2 })
    defs(pc, gourd, { SetCurrentTime = function(self, n) put(self, "CurrentTime", n) end, SetDisplayTime = false })
    pc.gourd = gourd
    local gourds = { ForEach = function(_, fn) fn({ get = function() return name("Hulu") end }, { get = function() return gourd end }) end }
    local bag = object(pc, "Backpack", { MedicineInfos = gourds, BottomMedicineID = name("Hulu"), Accessories = list({}), Inventories = list({}), items = {} })
    pc.bag = bag
    local BELL_HEAL = "/Script/ProjectPBZ.MelodiousBell:RestoreHealth"
    local bell = object(pc, "Bell")
    defs(pc, bell, { RestoreHealth = function()
        local _, maxhp = Fake.health(pawn)
        Fake.setHealth(pawn, maxhp)
        for _, fn in ipairs(pc.hooks[BELL_HEAL] or {}) do
            fn()
        end
    end })
    pc.bell = bell
    local BACKPACK = "/Script/ProjectPBZ.PBZBackPackSubsystem"
    local function given(self, count, id, push)
        local key = id.ToString and id:ToString() or id
        local items = rawget(self, "__fields").items
        items[key] = (items[key] or 0) + count
        for _, fn in ipairs(pc.hooks[BACKPACK .. ":AddPropsToBackPack"] or {}) do
            fn(self, { get = function() return count end }, { get = function() return name(key) end }, { get = function() return push end })
        end
    end
    defs(pc, bag, { AddPropsToBackPack = given, PushMedicineToInventory = false, PushAccessoryToInventory = false, AddWeaponItem = false })
    local subsystems = object(pc, "SubsystemLibrary")
    defs(pc, subsystems, { GetWorldSubsystem = function(_, _, cls)
        return rawget(cls, "__path") == BACKPACK and bag or nil
    end })
    local aiLibrary = object(pc, "SGameAIFunctionLibrary")
    defs(pc, aiLibrary, {
        GetTargetActor = function(_, controllerOfEnemy, out)
            for _, e in ipairs(pc.enemies) do
                if rawget(e, "__fields").Controller == controllerOfEnemy then
                    out.Target = rawget(e, "__fields").target
                end
            end
        end,
        SetValueAsObjectByTag = function(_, _, _, target)
            pc.lastAim = target
            pc.aims = (pc.aims or 0) + 1
        end,
    })
    local widgetLibrary = object(pc, "WidgetBlueprintLibrary")
    defs(pc, widgetLibrary, { SetInputMode_UIOnlyEx = false, SetInputMode_GameOnly = false, Create = function(_, _, cls)
        local circle = object(pc, "Image", { Brush = {} }, true)
        put(circle, "SetColorAndOpacity", function(self, tint) put(self, "tint", tint) end)
        local w = object(pc, "Widget", { Circle = circle, FadeIn = {} }, true)
        put(w, "SetColorAndOpacity", function(self, tint) put(self, "colour", tint) end)
        put(w, "IsInViewport", function() return true end)
        put(w, "SetVisibility", function(self, v) put(self, "visibility", v) end)
        put(w, "SetPositionInViewport", function(self, at) put(self, "position", at) end)
        put(w, "GetDesiredSize", function() return { X = 40, Y = 40 } end)
        put(w, "RemoveFromParent", function(self) put(self, "removed", true) end)
        widgets[#widgets + 1] = w
        return w
    end })
    pc.widgets = widgets
    local layoutLibrary = object(pc, "WidgetLayoutLibrary")
    defs(pc, layoutLibrary, { GetViewportSize = function() return { X = 1920, Y = 1080 } end, GetViewportScale = function() return 1.0 end })
    local abilities = object(pc, "AbilitySystemLibrary")
    defs(pc, abilities, { GetAbilitySystemComponent = function(_, actor)
        local asc = rawget(actor, "__fields").asc
        if asc == nil then
            asc = object(pc, "ASC", { ActivatableAbilities = { Items = list({}) } }, true)
            put(actor, "asc", asc)
        end
        return asc
    end })
    local rendering = object(pc, "RenderingLibrary")
    defs(pc, rendering, { ImportFileAsTexture2D = function() return object(pc, "Texture", {}, true) end })
    local codex = object(pc, "DataTable")
    defs(pc, codex, { FindRow = function() return nil end })
    local widgetClass = object(pc, "WidgetClass")
    pc.mapWidgets = {}
    local slotProto = { GetAutoSize = function() return false end, GetSize = function() return { X = 40, Y = 40 } end,
        GetAlignment = function() return { X = 0.5, Y = 0.5 } end, GetPosition = function() return { X = 500, Y = 500 } end }
    local mapCanvas = { AddChildToCanvas = function(_, w)
        local slot = setmetatable({ SetAutoSize = function() end, SetSize = function() end, SetAlignment = function() end,
            SetPosition = function() end }, { __index = slotProto })
        put(w, "Slot", slot)
        pc.mapWidgets[#pc.mapWidgets + 1] = w
        return slot
    end }
    local playerIcon = object(pc, "WB_PlayerIcon", { Slot = slotProto })
    defs(pc, playerIcon, { GetParent = function() return mapCanvas end, GetClass = function() return widgetClass end })
    local mapScreen = object(pc, "WB_MapNew_C", { WB_PlayerIcon = playerIcon })
    put(mapScreen, "IsVisible", function() return pc.mapOpen == true end)
    local mapSystem = object(pc, "MapSubsystem")
    defs(pc, mapSystem, { GetCurrentMapID = function() return 1 end, ProjectWorldLocationToMap = function(_, at)
        return { X = 0.5 + at.X / 1e6, Y = 0.5 + at.Y / 1e6 }
    end })

    local found = {
        ["/Script/Engine.Default__GameplayStatics"] = gs,
        ["/Script/Engine.Default__SubsystemBlueprintLibrary"] = subsystems,
        ["/Script/SGameAI.Default__SGameAIFunctionLibrary"] = aiLibrary,
        ["/Script/UMG.Default__WidgetBlueprintLibrary"] = widgetLibrary,
        ["/Script/UMG.Default__WidgetLayoutLibrary"] = layoutLibrary,
        ["/Script/GameplayAbilities.Default__AbilitySystemBlueprintLibrary"] = abilities,
        ["/Script/Engine.Default__KismetRenderingLibrary"] = rendering,
        ["/Game/PBZContent/DataTable/DT_CodexEnemyDataTable.DT_CodexEnemyDataTable"] = codex,
        ["/UltraVolumetrics/UltraVolumetrics/Core/PaintMode/Blueprint/W_PaintSize.W_PaintSize_C"] = widgetClass,
        ["/Game/PBZContent/UI/InGame/SwitchUI/WB_TipsText.WB_TipsText_C"] = widgetClass,
        ["/Game/PBZContent/Blueprint/BP_GameMode_Build.BP_GameMode_Build_C:Refresh Monster"] = object(pc, "Function"),
        ["/Game/RenewalContent/Prototypes/Character/BP_RenewalPlayer.BP_RenewalPlayer_C:Respawn Refresh Monster"] = object(pc, "Function"),
        [BELL_HEAL] = object(pc, "Function"),
        [BACKPACK] = object(pc, "BackpackClass"),
    }
    rawset(found[BACKPACK], "__path", BACKPACK)
    local statics = object(pc, "StaticObject", {}, true)
    pc.montages, pc.weaponConfigs = {}, {}

    local env = setmetatable({}, { __index = _G })
    pc.env = env
    env.print = function(text)
        local line = tostring(text):gsub("\n$", "")
        pc.logs[#pc.logs + 1] = line
        if line:find("net error", 1, true) or line:find(" error: ", 1, true) or line:find("Timer error", 1, true) then
            pc.errors[#pc.errors + 1] = line
        end
    end
    env.StaticFindObject = function(path)
        if found[path] then
            return found[path]
        end
        if path:find("^/Game/Move") then
            local m = pc.montages[path]
            if m == nil then
                m = object(pc, "AnimMontage")
                rawset(m, "__path", path)
                defs(pc, m, { GetPlayLength = function() return 1.5 end })
                pc.montages[path] = m
            end
            return m
        end
        if path:find("^/Game/Weapon") then
            local c = pc.weaponConfigs[path]
            if c == nil then
                c = object(pc, "WeaponConfig")
                rawset(c, "__path", path)
                pc.weaponConfigs[path] = c
            end
            return c
        end
        return statics.nothing
    end
    env.FindObject = function(kind) return kind == "WidgetBlueprintGeneratedClass" and widgetClass or nil end
    env.FindFirstOf = function(class)
        if class == "PlayerController" then
            return controller
        elseif class == "PBZHUDLayout" then
            return hudLayout
        elseif class == "MapSubsystem" then
            return mapSystem
        elseif class == "MelodiousBell" then
            return bell
        end
        return nil
    end
    env.FindAllOf = function(class)
        if class == "PBZCharacter_NPC" then
            return pc.enemies
        elseif class == "AISpawner" then
            return pc.spawners
        elseif class == "HitreactComponent" then
            return pc.hitComps
        elseif class == "FactionComponent" then
            return pc.factions
        elseif class == "PBZPickupActor" then
            local alive = {}
            for _, p in ipairs(pc.pickups) do
                if rawget(p, "__alive") then
                    alive[#alive + 1] = p
                end
            end
            return alive
        elseif class == "BP_Chest_C" then
            return pc.chests
        elseif class == "WB_MapNew_C" then
            return { mapScreen }
        end
        return nil
    end
    env.FName = function(text)
        return setmetatable({ TagName = nil }, { __index = { ToString = function() return text end } })
    end
    env.FText = function(text) return text end
    env.LoadAsset = function() end
    env.ExecuteInGameThread = function(fn) fn() end
    env.RegisterKeyBind = function() end
    env.Key = {}
    env.RegisterHook = function(path, fn)
        pc.hooks[path] = pc.hooks[path] or {}
        table.insert(pc.hooks[path], fn)
    end
    env.RegisterLoadMapPreHook = function(fn) pc.loadMapHook = fn end
    env.LoopInGameThreadWithDelay = function(ms, fn)
        pc.loops[#pc.loops + 1] = { every = ms / 1000, at = pc.now + ms / 1000, fn = fn }
    end
    env.os = setmetatable({ clock = function() return pc.now end, time = function() return 1800000000 + math.floor(pc.now) end,
        getenv = function() return nil end, remove = nil, rename = nil }, { __index = os })
    local fs = files(pc)
    env.os.remove, env.os.rename = fs.remove, fs.rename
    env.io = setmetatable({ open = fs.open }, { __index = io })
    env.package = { loadlib = function(_, entry)
        return link[entry:gsub("^pp_", "")]
    end }
    env.dofile = function(path)
        local f = assert(io.open(path, "rb"))
        local text = f:read("a")
        f:close()
        return assert(load(text, "@" .. path, "t", env))()
    end
    return pc
end

function Fake.start(pc)
    pc.env.dofile(pc.scripts .. "/main.lua")
end

-- One frame of the game.
function Fake.frame(pc, dt)
    pc.now = pc.now + dt
    for _, loop in ipairs(pc.loops) do
        if pc.now >= loop.at then
            loop.at = pc.now + loop.every
            loop.fn()
        end
    end
    Fake.thinkEnemies(pc)
end

Fake.put = put
Fake.list = list
return Fake

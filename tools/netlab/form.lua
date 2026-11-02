-- Test of the guard on the game's group formation solver: logs each call, and can force the bad location it hung on.
FORM = FORM or { calls = 0 }
local PBZ = PBZ
local SOLVER = "/Script/SGameAI.SGameAIMathUtils:SolveAssignment"
local AI_LIB = "/Script/SGameAI.Default__SGameAIFunctionLibrary"
local CENTER = "AI.BlackboardKey.Vector.DomainCenter"

local function say(s) print("[PBZCoop] FORM " .. s .. "\n") end
local function offMap(v) return not (math.abs(v.X) < 1e9 and math.abs(v.Y) < 1e9 and math.abs(v.Z) < 1e9) end

if FORM.fix == nil then FORM.fix = true end

function FORM.hook()
    if FORM.hooked then return "hooked already" end
    FORM.hooked = true
    RegisterHook(SOLVER, function(_, actors, goals)
        FORM.calls = FORM.calls + 1
        local spots, bad, n = {}, 0, 0
        actors:get():ForEach(function(i, el)
            local a = el:get()
            if PBZ.valid(a) then spots[i] = a:K2_GetActorLocation() end
        end)
        goals:get():ForEach(function(i, el)
            n = n + 1
            local v, at = el:get(), spots[i] or spots[1]
            if offMap(v) then
                bad = bad + 1
                if FORM.fix and at then v.X, v.Y, v.Z = at.X, at.Y, at.Z end
            end
        end)
        local first = "none"
        goals:get():ForEach(function(i, el)
            if i == 1 then local v = el:get(); first = string.format("%.0f %.0f %.0f", v.X, v.Y, v.Z) end
        end)
        say(string.format("solver call %d: %d goals, %d off the map, first now %s", FORM.calls, n, bad, first))
    end)
    return "hooked"
end

-- The blackboard of a named enemy.
local function board(name)
    local e = PBZ.coop.enemyActor(name)
    if not PBZ.valid(e) then e = FindFirstOf("BP_Monster_HuaShan_RedTroop_BigBro_C") end
    if not PBZ.valid(e) then return nil end
    local c = e:GetController()
    if not PBZ.valid(c) then return nil end
    return StaticFindObject("/Script/AIModule.Default__AIBlueprintHelperLibrary"):GetBlackboard(c), e
end

function FORM.center(name)
    local bb = board(name)
    if not PBZ.valid(bb) then return "no blackboard" end
    local v = StaticFindObject(AI_LIB):GetValueAsVectorByTag(bb, { TagName = FName(CENTER) })
    return string.format("center %.0f %.0f %.0f", v.X, v.Y, v.Z)
end

function FORM.setCenter(name, x, y, z)
    local bb, e = board(name)
    if not PBZ.valid(bb) then return "no blackboard" end
    local at = e:K2_GetActorLocation()
    StaticFindObject(AI_LIB):SetValueAsVectorByTag(bb, { TagName = FName(CENTER) }, { X = x or at.X, Y = y or at.Y, Z = z or at.Z })
    return FORM.center(name)
end

-- The running copies of the task: those made for one enemy's behaviour tree, with the place they were last told to use.
function FORM.tasks()
    local out = {}
    for _, t in ipairs(FindAllOf("BTTask_AssignBehaviorTreesToGroupMember_C") or {}) do
        local owner, n = nil, 0
        pcall(function() owner = t.ControlledPawn end)
        if PBZ.valid(owner) then
            pcall(function() n = t.ActorsToAssign:GetArrayNum() end)
            out[#out + 1] = owner:GetFName():ToString() .. " actors " .. n .. " type " .. tostring(t.BaseLocationType)
        end
    end
    return #out .. " running: " .. table.concat(out, " ; ")
end

-- Runs one of them right now, the way the behaviour tree would.
function FORM.run(ownerPart)
    for _, t in ipairs(FindAllOf("BTTask_AssignBehaviorTreesToGroupMember_C") or {}) do
        local owner
        pcall(function() owner = t.ControlledPawn end)
        if PBZ.valid(owner) and owner:GetFName():ToString():find(ownerPart, 1, true) then
            t:ExecuteInternal(false)
            return "ran it, calls " .. FORM.calls
        end
    end
    return "no such task"
end

-- Runs the running task that reads this key, as if its search for a place had just failed: what the game did when it hung.
function FORM.runTag(part)
    for _, t in ipairs(FindAllOf("BTTask_AssignBehaviorTreesToGroupMember_C") or {}) do
        local owner, tag
        pcall(function() owner = t.ControlledPawn; tag = t.BlackboardLocationTag.TagName:ToString() end)
        if PBZ.valid(owner) and tag and tag:find(part, 1, true) then
            local before = FORM.calls
            t:ExecuteInternal(false)
            return "ran " .. t:GetFName():ToString():sub(-14) .. ", solver calls " .. before .. " -> " .. FORM.calls
        end
    end
    return "no running task reads " .. part
end

function FORM.list()
    local out = {}
    for _, t in ipairs(FindAllOf("BTTask_AssignBehaviorTreesToGroupMember_C") or {}) do
        local o, tag, ty = nil, "?", "?"
        pcall(function() o = t.ControlledPawn; tag = t.BlackboardLocationTag.TagName:ToString(); ty = t.BaseLocationType end)
        if PBZ.valid(o) then out[#out + 1] = t:GetFName():ToString():sub(-3) .. " " .. o:GetFName():ToString():sub(-26, -12) .. " type " .. tostring(ty) .. " " .. tag:sub(-16) end
    end
    return table.concat(out, " ; ")
end
-- Waits for that task to be running, then does the same.
function FORM.trap(part, seconds)
    local left = (seconds or 30) * 4
    local function step()
        left = left - 1
        local r = FORM.runTag(part)
        local before, after = r:match("calls (%d+) %-> (%d+)")
        if r:find("no running", 1, true) or before == after then
            if left > 0 then PBZ.game.after(0.25, step) else say("trap gave up: " .. r) end
        else
            say("trap: " .. r)
        end
    end
    step()
    return "trap set"
end
return "form loaded"

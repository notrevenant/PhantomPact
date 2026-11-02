-- Plays the story, on top of walker.lua. WALK.start(seconds, killRadius) runs it on this copy.
local log, valid, game = PBZ.log, PBZ.valid, PBZ.game

WALK.cfg = { rate = 4.0, stuckS = 25, forceS = 45, moveS = 30, reach = 350 }

local function note(text)
    log("WALK " .. text)
    local f = io.open(WALK.file or "C:/PBZDev/pp-netlab/walk.txt", "a")
    if f then
        f:write(os.date("%H:%M:%S "), text, "\n")
        f:close()
    end
end
WALK.note = note

local function dist(a, b)
    return math.sqrt((a.X - b.X) ^ 2 + (a.Y - b.Y) ^ 2 + (a.Z - b.Z) ^ 2)
end

local function interactComp(pawn)
    if not valid(WALK.icCls) then
        WALK.icCls = StaticFindObject("/Script/ProjectPBZ.PBZInteractComponent")
    end
    local c
    pcall(function() c = pawn:GetComponentByClass(WALK.icCls) end)
    return c
end

local function offer(pawn)
    local ic = interactComp(pawn)
    if not valid(ic) then return nil end
    local a
    pcall(function() a = ic.CurrentInteractActor end)
    return valid(a) and a or nil
end

local function dialog()
    local d
    pcall(function()
        for _, w in ipairs(FindAllOf("WBP_FlowDialog_C") or {}) do
            if valid(w) and w:IsVisible() then d = w end
        end
    end)
    return d
end

-- A line is skipped the way the Skip button does it. On a list of topics each is clicked once, like a player reading
-- them all; a list with nothing new left takes its last option, which ends the talk.
function WALK.advance(d)
    local shown = {}
    pcall(function()
        local es = d.ChoiceEntryBox:GetAllEntries()
        for i = 1, #es do
            local b = es[i]:get()
            if valid(b) and b:IsVisible() then shown[#shown + 1] = b end
        end
    end)
    if #shown > 0 then
        WALK.clicked = WALK.clicked or {}
        local pick, text = shown[#shown], "?"
        for _, b in ipairs(shown) do
            local t = "?"
            pcall(function() t = b.PBZCommonLocRichText_39:GetText():ToString() end)
            if not WALK.clicked[t] then
                pick, text = b, t
                WALK.clicked[t] = true
                break
            end
        end
        note("option [" .. tostring(text) .. "] of " .. #shown)
        pcall(function() pick:HandleButtonClicked() end)
        return
    end
    pcall(function() d:OnManualSkip() end)
    pcall(function() d:SkipCurrentLine() end)
end

-- The nearest living enemy the sync knows of.
function WALK.nearest(pawn)
    local here, best, bd = pawn:K2_GetActorLocation(), nil, 1e12
    for _, a in pairs(PBZ.coop.enemies()) do
        if valid(a) and not game.isDead(a) then
            local d = dist(a:K2_GetActorLocation(), here)
            if d < bd then best, bd = a, d end
        end
    end
    return best, bd
end

local function pass(s, why)
    note(string.format("FORCED %s %s point %s: %s", s.qname, s.id, s.point, why))
    pcall(function() s.branch:SucceedBranch() end)
    WALK.stepSince = os.clock()
end

local function play()
    local _, pawn = PBZ.getPlayer1()
    if not valid(pawn) then
        WALK.pc = nil
        return
    end
    local cm = STORY.gm()
    if WALK.pc ~= pawn:GetAddress() then
        -- A new pawn: a load happened.
        WALK.pc = pawn:GetAddress()
        WALK.comp = nil
        cm:GM_State("preset", "immortal", "on")
        if WALK.kills then cm:GM_AutoKillNearby("on", WALK.kills) end
        local l = pawn:K2_GetActorLocation()
        note(string.format("in world %s at %.0f %.0f %.0f", tostring(game.mapName(pawn)), l.X, l.Y, l.Z))
    end
    -- Cutscenes run faster here, and a QTE counts as passed.
    if game.inCutscene() then
        local seq = FindFirstOf("PBZLevelSequenceManager")
        if not WALK.inSeq then
            WALK.inSeq = os.clock()
            local name = "?"
            pcall(function() name = seq:GetCurrentSequence():GetFName():ToString() end)
            note("cutscene " .. name)
            pcall(function() seq.ActiveSessionPlayer:SetPlayRate(WALK.cfg.rate) end)
        end
        pcall(function() if valid(seq.QTE) then seq:OnQTESuccess() end end)
        return
    elseif WALK.inSeq then
        note(string.format("cutscene over after %.0f s", os.clock() - WALK.inSeq))
        WALK.inSeq = nil
    end
    local d = dialog()
    if d then
        if not WALK.inTalk then
            WALK.inTalk = os.clock()
            note("dialogue")
        end
        WALK.advance(d)
        return
    elseif WALK.inTalk then
        note(string.format("dialogue over after %.0f s", os.clock() - WALK.inTalk))
        WALK.inTalk = nil
        WALK.clicked = {}
    end
    local steps = WALK.active()
    local tg = WALK.targets()
    local s
    -- A marker in a part of the world that isn't loaded has no actor yet; the quest's own location stands in for it.
    -- (A step that belongs to another map has nothing here: its coordinates would be empty air.)
    local mapId
    pcall(function() mapId = FindFirstOf("MapSubsystem"):GetCurrentMapID():ToString() end)
    for _, e in ipairs(steps) do
        local here = e.world == "None" or e.world == mapId or mapId == nil
        e.at = tg[e.point] or (here and e.loc) or nil
    end
    -- Main quest first, then each other marker in turn: nothing happening at one, it goes on to the next.
    WALK.seen = WALK.seen or {}
    for _ = 1, 2 do
        for _, e in ipairs(steps) do
            if e.at and e.qname:find("^Main") and not WALK.seen[e.qname .. e.id] then s = e break end
        end
        if not s then
            for _, e in ipairs(steps) do
                if e.at and not WALK.seen[e.qname .. e.id] then s = e break end
            end
        end
        if s then break end
        WALK.seen = {}
    end
    if not s then
        local main = steps[1]
        local key = main and (main.qname .. main.id .. main.point) or "none"
        if key ~= WALK.noPoint then
            WALK.noPoint = key
            note("no target loaded for: " .. (main and (main.qname .. " " .. main.id .. " point " .. main.point .. " world " .. main.world) or "no active step"))
        end
        return
    end
    local key = s.qname .. s.id
    if key ~= WALK.sameStep then
        WALK.sameStep = key
        WALK.stepSince = os.clock()
        WALK.moveAt = 0
        note(string.format("step %s %s point %s [%s]", s.qname, s.id, s.point, tostring(s.text):sub(1, 50)))
    end
    local t = s.at
    local here = pawn:K2_GetActorLocation()
    local far = math.sqrt((here.X - t.X) ^ 2 + (here.Y - t.Y) ^ 2)    -- (a marker can float high above the ground)
    local waited = os.clock() - WALK.stepSince
    if far > WALK.cfg.reach then
        if os.clock() >= (WALK.moveAt or 0) then
            WALK.moveAt = os.clock() + WALK.cfg.moveS
            if waited > WALK.cfg.stuckS then
                note(string.format("teleport for %s, %.0f m away", s.point, far / 100))
                pawn.CharacterMovement:SetMovementMode(5, 0)
                pawn:K2_SetActorLocation({ X = t.X, Y = t.Y, Z = t.Z + 150 }, false, {}, true)
                WALK.moveAt = os.clock() + 14
                game.after(9.0, function()
                    local _, p = PBZ.getPlayer1()
                    if valid(p) then p.CharacterMovement:SetMovementMode(1, 0) end
                end)
            else
                cm:GM_MoveTo(string.format("%.0f,%.0f,%.0f", t.X, t.Y, t.Z), 200.0, WALK.cfg.moveS - 2.0, "auto")
            end
        end
        return
    end
    if WALK.arrived ~= key then
        WALK.arrived = key
        WALK.arrivedAt = os.clock()
    end
    local a = offer(pawn)
    if a then
        local name = a:GetClass():GetFName():ToString()
        if name ~= WALK.lastOffer then
            WALK.lastOffer = name
            note("interact " .. name)
        end
        cm:GM_Input("interact")
        return
    end
    -- Enemies by the objective: it may well be about them.
    local e, d = WALK.nearest(pawn)
    if e and d < 6000 then
        if os.clock() >= (WALK.huntAt or 0) then
            WALK.huntAt = os.clock() + 8
            local l = e:K2_GetActorLocation()
            note(string.format("hunting %s, %.0f m", e:GetClass():GetFName():ToString(), d / 100))
            cm:GM_MoveTo(string.format("%.0f,%.0f,%.0f", l.X, l.Y, l.Z), 150.0, 7.0, "auto")
        end
        cm:GM_Input("attack")
        WALK.arrivedAt = math.max(WALK.arrivedAt, os.clock() - WALK.cfg.forceS + 20)
        return
    end
    if os.clock() - WALK.arrivedAt > (WALK.cfg.nextS or 25) then
        note("nothing at " .. s.point .. ", next marker")
        WALK.seen[key] = true
        WALK.arrived = nil
        return
    end
    if os.clock() - WALK.arrivedAt > WALK.cfg.forceS then
        local tasks = {}
        pcall(function()
            for _, q in ipairs(WALK.arr(s.branch.QuestTasks)) do
                tasks[#tasks + 1] = q:GetClass():GetFName():ToString()
            end
        end)
        pass(s, "nothing to do at the target; tasks " .. table.concat(tasks, ","))
        WALK.arrived = nil
    end
end

local function tick()
    if not WALK.on then return true end
    if PBZ.link.wall() > WALK.untilAt then
        note("TIME UP")
        WALK.on = false
        return true
    end
    local ok, err = pcall(play)
    if not ok then
        note("tick error " .. tostring(err))
    end
    return false
end

function WALK.start(seconds, kills)
    WALK.on = true
    WALK.kills = kills
    WALK.pc, WALK.sameStep, WALK.noPoint = nil, nil, nil
    WALK.seen = {}
    WALK.stepSince = os.clock()
    WALK.untilAt = PBZ.link.wall() + (seconds or 300)
    WALK.file = "C:/PBZDev/pp-netlab/walk-" .. tostring(PBZ.net.role or "x") .. ".txt"
    WALK.loopId = (WALK.loopId or 0) + 1
    local id = WALK.loopId
    LoopInGameThreadWithDelay(1000, function()
        if id ~= WALK.loopId then return true end
        return tick()
    end)
    return "WALK started"
end

function WALK.stop()
    WALK.on = false
    return "WALK stopped"
end

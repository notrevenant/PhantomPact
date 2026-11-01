-- Story probe: current quests (Narrative), active flow nodes, switches/doors in the level. Writes STORY_OUT.
local valid = PBZ.valid
local pc1, p1 = PBZ.getPlayer1()
local here = p1:K2_GetActorLocation()
local out = {}
local function put(s) out[#out + 1] = s end
local function nm(o) return valid(o) and o:GetFName():ToString() or "nil" end
local function cls(o) return valid(o) and o:GetClass():GetFName():ToString() or "nil" end
local function txt(ft) local ok, s = pcall(function() return ft:ToString() end) return ok and s or "?" end
local function vec(v) return string.format("%.0f,%.0f,%.0f", v.X, v.Y, v.Z) end
local function dist(a) local d = -1 pcall(function() d = PBZ.distance(a:K2_GetActorLocation(), here) end) return d end

-- 1. Quests
put("== QUESTS")
for _, nc in ipairs(FindAllOf("PBZNarrativeComponent") or {}) do
    if valid(nc) then
        put(string.format("NarrativeComponent %s owner=%s mainQuest=%s tracked=%s branch=%s point=%s",
            nm(nc), nm(nc.OwnerPC), cls(nc.CurrentMainQuest), cls(nc.CurrentTrackedQuest),
            tostring(nc.TrackedBranchID and nc.TrackedBranchID:ToString()), tostring(nc.TrackedTaskPointID and nc.TrackedTaskPointID:ToString())))
        pcall(function()
            nc.QuestList:ForEach(function(_, el)
                local q = el:get()
                if valid(q) then
                    local st = q.CurrentState
                    put(string.format("  QUEST %s primary=%s completion=%s state=%s loc=%s",
                        cls(q), tostring(q.bIsPrimaryQuest), tostring(q.QuestCompletion),
                        valid(st) and st.ID:ToString() or "nil", valid(st) and vec(st.QuestLocation) or "-"))
                    pcall(function() put("    name: " .. txt(q:GetQuestName()) .. " | target: " .. txt(q:GetCurrentTargetText())) end)
                    if valid(st) then
                        pcall(function()
                            st.Branches:ForEach(function(_, b)
                                local br = b:get()
                                if valid(br) then
                                    put(string.format("    BRANCH %s activated=%s dest=%s point=%s loc=%s world=%s",
                                        br.ID:ToString(), tostring(br.bActivated), valid(br.DestinationState) and br.DestinationState.ID:ToString() or "nil",
                                        br.BranchTargetPointID:ToString(), vec(br.Location), br.BelongToWorld:ToString()))
                                    pcall(function()
                                        br.QuestTasks:ForEach(function(_, t)
                                            local task = t:get()
                                            if valid(task) then
                                                put(string.format("      TASK %s progress=%d/%d point=%s desc=%s", cls(task), task.CurrentProgress, task.RequiredQuantity,
                                                    task.TargetPointID:ToString(), txt(task.DescriptionOverride)))
                                            end
                                        end)
                                    end)
                                end
                            end)
                        end)
                    end
                end
            end)
        end)
    end
end

-- 2. Active flow nodes
put("== FLOW (components with executing nodes)")
local nflow = 0
for _, fc in ipairs(FindAllOf("BP_PBZFlowComponent_C") or {}) do
    if valid(fc) then
        nflow = nflow + 1
        local n = 0
        local names = {}
        pcall(function()
            fc.CurrentExecuteNode:ForEach(function(_, el)
                local node = el:get()
                n = n + 1
                if valid(node) then names[#names + 1] = cls(node) end
            end)
        end)
        if n > 0 then
            local owner = nil
            pcall(function() owner = fc:GetOwner() end)
            put(string.format("  %7.0f cm %s (%s) nodes=%d [%s] loaded=%s", valid(owner) and dist(owner) or -1, nm(owner), cls(owner), n, table.concat(names, ","), tostring(fc.LoadedComplete)))
        end
    end
end
put("  flow components: " .. nflow)

-- 3. Switches / doors
put("== SWITCHES (BP_Switch_C and subclasses)")
local rows = {}
for _, s in ipairs(FindAllOf("BP_Switch_C") or {}) do
    if valid(s) and not s:GetFullName():find("Default__") then
        local id = ""
        pcall(function() id = s["Switch Item ID"]:ToString() end)
        local bq = "nil"
        pcall(function() bq = valid(s.BeginQuest) and s.BeginQuest:GetFName():ToString() or "nil" end)
        rows[#rows + 1] = { d = dist(s), s = string.format("%s %s state=%s commonItem=%s itemId=%s quest=%s mode=%s", cls(s), nm(s), tostring(s.CurSwitchState), tostring(s.bUseCommonRequiredItem), id, bq, tostring(s.SwitchMode)) }
    end
end
table.sort(rows, function(a, b) return a.d < b.d end)
for i = 1, math.min(#rows, 150) do put(string.format("  %7.0f cm %s", rows[i].d, rows[i].s)) end
put("== INTERACTABLE CLASSES (BP_InterBase_C)")
local counts = {}
for _, s in ipairs(FindAllOf("BP_InterBase_C") or {}) do
    if valid(s) and not s:GetFullName():find("Default__") then counts[cls(s)] = (counts[cls(s)] or 0) + 1 end
end
for k, v in pairs(counts) do put(string.format("  %s x%d", k, v)) end

local f = io.open(STORY_OUT, "w")
f:write(table.concat(out, "\n"))
f:close()
return "story done"

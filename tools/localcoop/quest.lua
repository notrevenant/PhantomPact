-- Quest graph probe: states/branches of the in-progress quests. Writes QUEST_OUT.
local valid = PBZ.valid
local out = {}
local function put(s) out[#out + 1] = s end
local function cls(o) return valid(o) and o:GetClass():GetFName():ToString() or "nil" end
local function txt(ft) local ok, s = pcall(function() return ft:ToString() end) return ok and s or "?" end
local function vec(v) return string.format("%.0f,%.0f,%.0f", v.X, v.Y, v.Z) end
local function loc(fl) local ok, s = pcall(function() return fl.ValueCache:ToString() end) if ok and s ~= "" then return s end ok, s = pcall(function() return fl.Key:ToString() end) return ok and s or "?" end
for _, nc in ipairs(FindAllOf("PBZNarrativeComponent") or {}) do
    if valid(nc) and valid(nc.OwnerPC) then
        pcall(function()
            nc.QuestList:ForEach(function(_, el)
                local q = el:get()
                if valid(q) and q.QuestCompletion == 1 then
                    put(string.format("QUEST %s name=%s", cls(q), txt(q:GetQuestName())))
                    pcall(function() put("  activities: " .. (function() local t = {} q.QuestActivities:ForEach(function(_, s) t[#t + 1] = s:get():ToString() end) return table.concat(t, " | ") end)()) end)
                    pcall(function()
                        put("  reached states:")
                        q.ReachedStates:ForEach(function(_, s)
                            local st = s:get()
                            if valid(st) then put(string.format("    %s type=%s loc=%s target=%s", st.ID:ToString(), tostring(st.StateType), vec(st.QuestLocation), loc(st.FlowLocTarget))) end
                        end)
                    end)
                    pcall(function()
                        put("  all states:")
                        q.States:ForEach(function(_, s)
                            local st = s:get()
                            if valid(st) then
                                local nb = 0
                                pcall(function() st.Branches:ForEach(function() nb = nb + 1 end) end)
                                put(string.format("    %s type=%s branches=%d loc=%s target=%s", st.ID:ToString(), tostring(st.StateType), nb, vec(st.QuestLocation), loc(st.FlowLocTarget)))
                            end
                        end)
                    end)
                    pcall(function()
                        put("  all branches:")
                        q.Branches:ForEach(function(_, b)
                            local br = b:get()
                            if valid(br) then
                                put(string.format("    %s activated=%s dest=%s point=%s loc=%s world=%s target=%s desc=%s", br.ID:ToString(), tostring(br.bActivated),
                                    valid(br.DestinationState) and br.DestinationState.ID:ToString() or "nil", br.BranchTargetPointID:ToString(), vec(br.Location), br.BelongToWorld:ToString(), loc(br.FlowLocTarget), loc(br.FlowLocDesc)))
                            end
                        end)
                    end)
                end
            end)
        end)
    end
end
local f = io.open(QUEST_OUT, "w") f:write(table.concat(out, "\n")) f:close()
return "quest done"

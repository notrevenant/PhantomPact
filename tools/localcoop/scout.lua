-- Scout: story/flow actors near player 1, grouped by class, with distance. Writes SCOUT_OUT.
local valid = PBZ.valid
local _, p1 = PBZ.getPlayer1()
local here = p1:K2_GetActorLocation()
local pats = SCOUT_PATS or { "Door", "Key", "Merchant", "Shop", "Flow", "Cutscene", "Sequence", "Pickup", "NPC", "Fog", "Boss", "Quest", "Teleport", "Portal", "Gate", "Trigger", "Save", "Bell", "Chapter", "Stream", "Lock", "Loot", "Item", "Collect" }
local rows, counts = {}, {}
local all = FindAllOf("Actor") or {}
local total = #all
for _, a in ipairs(all) do
    if valid(a) then
        local full = a:GetFullName()
        if full:find("PersistentLevel") then
            local cls = full:match("^(%S+)") or "?"
            local nm = a:GetFName():ToString()
            local hit = nil
            for _, pt in ipairs(pats) do
                if cls:find(pt) or nm:find(pt) then hit = pt break end
            end
            if hit and not full:find("Default__") then
                local d = -1
                pcall(function() local l = a:K2_GetActorLocation() if l.X ~= 0 or l.Y ~= 0 then d = PBZ.distance(l, here) end end)
                counts[cls] = (counts[cls] or 0) + 1
                if d >= 0 then rows[#rows + 1] = { cls = cls, nm = nm, d = d } end
            end
        end
    end
end
table.sort(rows, function(a, b) return a.d < b.d end)
local ncls = 0
for _ in pairs(counts) do ncls = ncls + 1 end
local out = { string.format("actors=%d matched=%d classes=%d", total, #rows, ncls) }
for cls, n in pairs(counts) do out[#out + 1] = string.format("CLASS %s x%d", cls, n) end
for i = 1, math.min(#rows, SCOUT_MAX or 400) do out[#out + 1] = string.format("%8.0f cm  %s  %s", rows[i].d, rows[i].cls, rows[i].nm) end
local f = io.open(SCOUT_OUT, "w")
f:write(table.concat(out, "\n"))
f:close()
return "scout done: " .. #rows

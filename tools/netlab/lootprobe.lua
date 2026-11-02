-- Watches the game's loot rolls and backpack entry points, for finding out how a drop reaches a player. Log only.
local log = PBZ.log
LOOTP = LOOTP or {}
local function names(t)
    local out = {}
    pcall(function() t:ForEach(function(k, v) out[#out + 1] = k:get():ToString() .. "=" .. tostring(v:get()) end) end)
    return table.concat(out, " ")
end
function LOOTP.hook(cls)
    if LOOTP.on then return "already" end
    LOOTP.on = true
    local path = "/Script/ProjectPBZ." .. cls .. ":GetCombatLootDataForOwner"
    local ok, err = pcall(function()
        RegisterHook(path, function(self, owner, level, class, data)
            local who, lv = "?", "?"
            pcall(function() who = owner:get():GetFName():ToString() end)
            pcall(function() lv = tostring(level:get()) end)
            local d = data:get()
            local dust, items, weapons, med, acc = "?", "?", "?", "?", "?"
            pcall(function() dust = tostring(d.LootDust) end)
            pcall(function() items = names(d.LootItems) end)
            pcall(function() weapons = names(d.LootWeapons) end)
            log("LOOTROLL " .. who .. " level " .. lv .. " dust " .. dust .. " items[" .. items .. "] weapons[" .. weapons .. "]")
        end)
    end)
    return "hook " .. tostring(ok) .. " " .. tostring(err)
end
function LOOTP.back()
    if LOOTP.backOn then return "already" end
    LOOTP.backOn = true
    local out = {}
    for _, fn in ipairs({ "AddPropsToBackPack", "AddPropsByMap", "AddPropsSilently", "AddWeaponItem" }) do
        local ok = pcall(function()
            RegisterHook("/Script/ProjectPBZ.PBZBackPackSubsystem:" .. fn, function(self, a, b)
                local x, y = "?", "?"
                pcall(function() x = tostring(a:get()) end)
                pcall(function() y = b:get():ToString() end)
                log("LOOTBAG " .. fn .. " " .. x .. " " .. y)
            end)
        end)
        out[#out + 1] = fn .. "=" .. tostring(ok)
    end
    return table.concat(out, " ")
end
-- What each enemy near this player can drop, from a few rolls: only those with items.
function LOOTP.tables(n)
    local out, seen = {}, {}
    for name, a in pairs(PBZ.coop.enemies()) do
        if PBZ.valid(a) and not PBZ.game.isDead(a) then
            local c = a:GetClass():GetFName():ToString():gsub("BP_Monster_", ""):gsub("_C$", "")
            if not seen[c] then
                seen[c] = true
                local got = {}
                for _ = 1, n or 5 do
                    local _, items = PBZ.game.rollLoot(a)
                    for _, i in ipairs(items) do got[i.id] = (got[i.id] or 0) + 1 end
                end
                local t = {}
                for k, v in pairs(got) do t[#t + 1] = k .. ":" .. v end
                out[#out + 1] = c .. "[" .. table.concat(t, " ") .. "]"
            end
        end
    end
    return "TABLES " .. table.concat(out, " "):sub(1, 700)
end

-- The game's loot tables: which enemy classes have items, weapons, medicines or accessories at all.
function LOOTP.dump(path)
    local out = {}
    local lib = StaticFindObject("/Script/Engine.Default__DataTableFunctionLibrary")
    for _, t in ipairs(FindAllOf("DataTable") or {}) do
        local n = t:GetFullName()
        if n:find("Loot", 1, true) then out[#out + 1] = n end
    end
    local f = io.open(path or "C:/PBZDev/pp-netlab/loot-tables.txt", "w")
    for _, full in ipairs(out) do
        local p = full:gsub("^%S+%s+", "")
        local t = StaticFindObject(p)
        f:write("# " .. p .. "\n")
        local ok, err = pcall(function()
            local rows = lib:GetDataTableColumnAsString(t, FName("EntryDatas"))
            local cls = lib:GetDataTableColumnAsString(t, FName("NPCClass"))
            for i = 1, #rows do
                f:write(cls[i]:get():ToString() .. "\t" .. rows[i]:get():ToString() .. "\n")
            end
        end)
        if not ok then f:write("error " .. tostring(err) .. "\n") end
    end
    f:close()
    return "TABLES files " .. #out .. " " .. table.concat(out, " | "):sub(1, 300)
end

function LOOTP.level(columns, path)
    local lib = StaticFindObject("/Script/Engine.Default__DataTableFunctionLibrary")
    local t = StaticFindObject("/Game/PBZContent/DataTable/DT_LevelLootDataTable.DT_LevelLootDataTable")
    local f = io.open(path or "C:/PBZDev/pp-netlab/loot-level.txt", "w")
    local cols, n = {}, 0
    for c in columns:gmatch("%S+") do
        local ok, r = pcall(function() return lib:GetDataTableColumnAsString(t, FName(c)) end)
        cols[#cols + 1] = { c, ok and r or nil }
        if ok and r then n = math.max(n, #r) end
    end
    for i = 1, n do
        local row = {}
        for _, c in ipairs(cols) do
            local v = "?"
            if c[2] and c[2][i] then pcall(function() v = c[2][i]:get():ToString() end) end
            row[#row + 1] = c[1] .. "=" .. v
        end
        f:write(table.concat(row, "\t"):sub(1, 2000) .. "\n")
    end
    f:close()
    return "LEVEL rows " .. n
end

-- Chests near this player: class, name, metres, and the fields that say whether they're open and what's inside.
function LOOTP.chests(n)
    local _, p = PBZ.getPlayer1()
    local here, rows = p:K2_GetActorLocation(), {}
    for _, a in ipairs(FindAllOf("PBZSwitchBase") or {}) do
        if PBZ.valid(a) then
            local c = a:GetClass():GetFName():ToString()
            if c:find("Chest", 1, true) or c:find("Box", 1, true) then
                local ok, l = pcall(function() return a:K2_GetActorLocation() end)
                if ok and l.X then
                    rows[#rows + 1] = { d = PBZ.distance(l, here) / 100, c = c, n = a:GetFName():ToString(), a = a, l = l }
                end
            end
        end
    end
    table.sort(rows, function(x, y) return x.d < y.d end)
    local out = {}
    for i = 1, math.min(n or 5, #rows) do
        local r = rows[i]
        local st = "?"
        pcall(function() st = tostring(r.a.CurSwitchState) end)
        out[#out + 1] = string.format("%.0fm %s %s st=%s at %.0f,%.0f,%.0f", r.d, r.c, r.n, st, r.l.X, r.l.Y, r.l.Z)
    end
    return "CHESTS " .. #rows .. " | " .. table.concat(out, " | ")
end

function LOOTP.chest(name)
    for _, a in ipairs(FindAllOf("BP_Chest_C") or {}) do
        if PBZ.valid(a) and a:GetFName():ToString() == name then return a end
    end
end

-- Every function and interesting property of the chest class, for finding how it opens.
function LOOTP.chestClass(name)
    local a = LOOTP.chest(name)
    if not a then return "no chest" end
    local out = {}
    local cls = a:GetClass()
    pcall(function()
        cls:ForEachFunction(function(f) out[#out + 1] = f:GetFName():ToString() end)
    end)
    local props = {}
    pcall(function()
        cls:ForEachProperty(function(p) props[#props + 1] = p:GetFName():ToString() end)
    end)
    return "CLASS fn " .. table.concat(out, " "):sub(1, 700) .. " || props " .. table.concat(props, " "):sub(1, 500)
end

function LOOTP.mirror(name)
    local a = LOOTP.chest(name)
    if not a then return "no chest" end
    local before = tostring(a.CurSwitchState)
    local ok, err = pcall(function() a:SwitchWithoutPlaySequence() end)
    return "MIRROR " .. before .. " -> " .. tostring(a.CurSwitchState) .. " " .. tostring(ok) .. " " .. tostring(err)
end

function LOOTP.groups()
    local out = {}
    for _, g in ipairs(FindAllOf("PBZMobGroupScript_KillLoot") or {}) do
        if PBZ.valid(g) then
            local id = "?"
            pcall(function() id = g.KillLootItemID:ToString() end)
            out[#out + 1] = g:GetFName():ToString() .. "=" .. id
        end
    end
    return "GROUPS " .. #out .. " " .. table.concat(out, " "):sub(1, 400)
end

function LOOTP.chestHooks(name)
    if LOOTP.chestOn then return "already" end
    local a = LOOTP.chest(name) or FindFirstOf("BP_Chest_C")
    if not a then return "no chest" end
    LOOTP.chestOn = true
    local path = a:GetClass():GetFullName():gsub("^%S+%s+", "")
    local out = {}
    for _, fn in ipairs({ "OnInteract", "Collect Items", "Pickup Items", "ChangeSwitchState", "Change Switch State", "UpdateProps_Event", "GetWeapon_Event", "Spawn", "Disappear", "RefreshActorByData" }) do
        local ok = pcall(function()
            RegisterHook(path .. ":" .. fn, function(self)
                local n, st = "?", "?"
                pcall(function() n = self:get():GetFName():ToString():sub(-22) end)
                pcall(function() st = tostring(self:get().CurSwitchState) end)
                log("LOOTCHEST " .. fn .. " " .. n .. " st=" .. st)
            end)
        end)
        out[#out + 1] = fn .. "=" .. tostring(ok)
    end
    return table.concat(out, " ")
end

function LOOTP.mapHook()
    if LOOTP.mapOn then return "already" end
    LOOTP.mapOn = true
    return tostring(pcall(function()
        RegisterHook("/Script/ProjectPBZ.PBZBackPackSubsystem:AddPropsByMap", function(self, map, push)
            local t = {}
            pcall(function() map:get():ForEach(function(k, v) t[#t + 1] = k:get():ToString() .. "x" .. tostring(v:get()) end) end)
            local pushed = "?"
            pcall(function() pushed = tostring(push:get()) end)
            log("LOOTMAP " .. table.concat(t, " ") .. " push " .. pushed)
        end)
    end))
end

-- The partner's copy of a chest pays out by itself: the chest's own steps, run on this player's copy.
function LOOTP.pay(name, steps)
    local a = LOOTP.chest(name)
    if not a then return "no chest" end
    local before = tostring(a.CurSwitchState)
    local out = {}
    for fn in steps:gmatch("[^,]+") do
        local ok, err = pcall(function() a[fn](a) end)
        out[#out + 1] = fn .. "=" .. tostring(ok) .. (ok and "" or (" " .. tostring(err):sub(1, 60)))
    end
    return "PAY " .. before .. " -> " .. tostring(a.CurSwitchState) .. " " .. table.concat(out, " ")
end

function LOOTP.props(name)
    local a = LOOTP.chest(name)
    if not a then return "no chest" end
    local props, cls = {}, a:GetClass()
    pcall(function() cls:ForEachProperty(function(p) props[#props + 1] = p:GetFName():ToString() end) end)
    local vals = {}
    for _, k in ipairs({ "Pickups", "HasStick", "Interacted", "IsOpened", "bOpened", "LootItemID", "LootID", "ItemID", "ItemId" }) do
        local ok, v = pcall(function() return a[k] end)
        if ok and v ~= nil then vals[#vals + 1] = k .. "=" .. tostring(v) end
    end
    return "PROPS " .. table.concat(props, " ") .. " || " .. table.concat(vals, " ")
end

function LOOTP.kinds()
    local by, dust = {}, {}
    for _, a in ipairs(FindAllOf("PBZSwitchBase") or {}) do
        if PBZ.valid(a) then
            local c = a:GetClass():GetFName():ToString()
            by[c] = (by[c] or 0) + 1
            if by[c] == 1 then
                local fns = {}
                pcall(function() a:GetClass():ForEachFunction(function(f)
                    local n = f:GetFName():ToString()
                    if n == "Collect Items" or n == "Pickup Items" then fns[#fns + 1] = n end
                end) end)
                dust[c] = table.concat(fns, ",")
            end
        end
    end
    local out = {}
    for c, n in pairs(by) do out[#out + 1] = c .. "=" .. n .. (dust[c] ~= "" and ("(" .. dust[c] .. ")") or "") end
    table.sort(out)
    local d, m = 0, 0
    for _, a in ipairs(FindAllOf("BP_Chest_C") or {}) do
        pcall(function() local v = a["Get Dust"] if type(v) == "number" and v > 0 then d = d + 1 m = math.max(m, v) end end)
    end
    return "KINDS " .. table.concat(out, " "):sub(1, 500) .. " | chests with dust " .. d .. " max " .. m
end

-- A kind of container: its functions, and the nearest few with what they hold.
function LOOTP.kind(cls, n)
    local _, p = PBZ.getPlayer1()
    local here, rows = p:K2_GetActorLocation(), {}
    for _, a in ipairs(FindAllOf(cls) or {}) do
        if PBZ.valid(a) then
            local ok, l = pcall(function() return a:K2_GetActorLocation() end)
            if ok and l.X then rows[#rows + 1] = { d = PBZ.distance(l, here) / 100, a = a, l = l } end
        end
    end
    table.sort(rows, function(x, y) return x.d < y.d end)
    if #rows == 0 then return "none" end
    local fns, props = {}, {}
    pcall(function() rows[1].a:GetClass():ForEachFunction(function(f) fns[#fns + 1] = f:GetFName():ToString() end) end)
    pcall(function() rows[1].a:GetClass():ForEachProperty(function(q) props[#props + 1] = q:GetFName():ToString() end) end)
    local out = {}
    for i = 1, math.min(n or 4, #rows) do
        local r = rows[i]
        local st, dust, inter = "?", "?", "?"
        pcall(function() st = tostring(r.a.CurSwitchState) end)
        pcall(function() dust = tostring(r.a["Get Dust"]) end)
        pcall(function() inter = tostring(r.a.bInteracted) end)
        out[#out + 1] = string.format("%.0fm %s st=%s dust=%s int=%s at %.0f,%.0f,%.0f", r.d, r.a:GetFName():ToString():sub(-26), st, dust, inter, r.l.X, r.l.Y, r.l.Z)
    end
    return "KIND fn " .. table.concat(fns, " "):sub(1, 420) .. " || props " .. table.concat(props, " "):sub(1, 360) .. " || " .. table.concat(out, " | ")
end

function LOOTP.rubbishHooks()
    if LOOTP.rubbishOn then return "already" end
    local a = FindFirstOf("BP_Rubbish_C")
    if not a then return "none" end
    LOOTP.rubbishOn = true
    local path = a:GetClass():GetFullName():gsub("^%S+%s+", "")
    local out = {}
    for _, fn in ipairs({ "OnInteract", "Collect Items", "ChangeSwitchState", "End Interact", "TryToAddDust", "Disappear" }) do
        local ok = pcall(function()
            RegisterHook(path .. ":" .. fn, function(self)
                local n, st, de = "?", "?", "?"
                pcall(function() n = self:get():GetFName():ToString():sub(-22) end)
                pcall(function() st = tostring(self:get().CurSwitchState) end)
                pcall(function() de = tostring(self:get().bDestroyed) end)
                log("LOOTCHEST rubbish " .. fn .. " " .. n .. " st=" .. st .. " destroyed=" .. de)
            end)
        end)
        out[#out + 1] = fn .. "=" .. tostring(ok)
    end
    return table.concat(out, " ")
end

-- What the mod will do on the partner's copy of a chest.
function LOOTP.mirrorPay(name)
    local c = LOOTP.chest(name)
    if not c then return "no chest" end
    local d0 = "?"
    pcall(function() d0 = tostring(c["Get Dust"]) end)
    local okD = pcall(function() c["Get Dust"] = 0 end)
    local d1 = "?"
    pcall(function() d1 = tostring(c["Get Dust"]) end)
    pcall(function() c["Collect Items"](c) end)
    pcall(function() c["Pickup Items"](c) end)
    pcall(function() c:SwitchWithoutPlaySequence() end)
    return "MIRRORPAY dust " .. d0 .. " -> " .. d1 .. " write " .. tostring(okD) .. " open " .. tostring(c.CurSwitchState)
end

function LOOTP.mirrorPay(name)
    local c = LOOTP.chest(name)
    if not c then return "no chest" end
    local _, p = PBZ.getPlayer1()
    local before = p.ConsciousnessDust
    pcall(function() c["Collect Items"](c) end)
    pcall(function() c["Pickup Items"](c) end)
    pcall(function() c:SwitchWithoutPlaySequence() end)
    local paid = p.ConsciousnessDust - before
    local ok = true
    if paid > 0 then ok = pcall(function() p:ChangeDustNumInternal(-paid) end) end
    return "MIRRORPAY chest paid dust " .. paid .. " taken back " .. tostring(ok) .. " now " .. (p.ConsciousnessDust - before) .. " open " .. tostring(c.CurSwitchState)
end

function LOOTP.find(cls, tail)
    for _, a in ipairs(FindAllOf(cls) or {}) do
        if PBZ.valid(a) and a:GetFName():ToString():sub(-#tail) == tail then return a end
    end
end

function LOOTP.pile(tail)
    local a = LOOTP.find("BP_Rubbish_C", tail)
    if not a then return "PILE none" end
    return "PILE " .. a:GetFName():ToString():sub(-30) .. " destroyed=" .. tostring(a.bDestroyed) .. " st=" .. tostring(a.CurSwitchState)
end

function LOOTP.payPile(tail)
    local a = LOOTP.find("BP_Rubbish_C", tail)
    if not a then return "PILE none" end
    local out = {}
    local ok1 = pcall(function() a["Collect Items"](a) end)
    local ok2 = pcall(function() a:SwitchWithoutPlaySequence() end)
    return "PAYPILE collect " .. tostring(ok1) .. " switch " .. tostring(ok2) .. " destroyed=" .. tostring(a.bDestroyed) .. " st=" .. tostring(a.CurSwitchState)
end

-- Chests loaded here with what's inside: "name|lootid|x|y|z|open" for those whose loot id has a word from the list.
function LOOTP.scan(words)
    local out = {}
    for _, a in ipairs(FindAllOf("BP_Chest_C") or {}) do
        if PBZ.valid(a) then
            local id = "?"
            pcall(function() id = a["Loot Item ID"]:ToString() end)
            for w in words:gmatch("%S+") do
                if id:find(w, 1, true) then
                    local l = a:K2_GetActorLocation()
                    out[#out + 1] = string.format("%s|%s|%.0f|%.0f|%.0f|%s", a:GetFName():ToString(), id, l.X, l.Y, l.Z, tostring(a.CurSwitchState))
                    break
                end
            end
        end
    end
    return "SCAN " .. table.concat(out, " ; ")
end

-- What's right around this player: every switch-like or pickup actor within reach, nearest first.
function LOOTP.around(cm)
    local _, p = PBZ.getPlayer1()
    local here, rows = p:K2_GetActorLocation(), {}
    for _, cn in ipairs({ "PBZSwitchBase", "PBZPickupActor" }) do
        for _, a in ipairs(FindAllOf(cn) or {}) do
            if PBZ.valid(a) then
                local ok, l = pcall(function() return a:K2_GetActorLocation() end)
                if ok and l.X then
                    local d = PBZ.distance(l, here)
                    if d <= (cm or 3000) then
                        local st, de, inter = "?", "?", "?"
                        pcall(function() st = tostring(a.CurSwitchState) end)
                        pcall(function() de = tostring(a.bDestroyed) end)
                        rows[#rows + 1] = { d, a:GetClass():GetFName():ToString(), a:GetFName():ToString():sub(-24), st, de }
                    end
                end
            end
        end
    end
    table.sort(rows, function(x, y) return x[1] < y[1] end)
    local out = {}
    for i = 1, math.min(10, #rows) do
        local r = rows[i]
        out[#out + 1] = string.format("%.0fm %s %s st=%s destroyed=%s", r[1] / 100, r[2], r[3], r[4], r[5]:sub(1, 5))
    end
    return "AROUND " .. math.floor(here.X) .. " " .. math.floor(here.Y) .. " " .. math.floor(here.Z) .. " | " .. table.concat(out, " | ")
end

-- Every chest loaded here and whether it's open, for comparing the two sides, written to a file per copy.
function LOOTP.openList(path)
    local f = io.open(path, "w")
    local n = 0
    for _, a in ipairs(FindAllOf("BP_Chest_C") or {}) do
        if PBZ.valid(a) then
            local l = a:K2_GetActorLocation()
            local id = "?"
            pcall(function() id = a["Loot Item ID"]:ToString() end)
            f:write(string.format("%s\t%s\t%s\t%.0f,%.0f,%.0f\n", a:GetFName():ToString(), tostring(a.CurSwitchState), id, l.X, l.Y, l.Z))
            n = n + 1
        end
    end
    f:close()
    return "LIST " .. n
end

-- Every rubbish pile near this player with the fields that could say it's been searched.
function LOOTP.piles(cm, path)
    local _, p = PBZ.getPlayer1()
    local here = p:K2_GetActorLocation()
    local f = io.open(path, "w")
    local n = 0
    for _, a in ipairs(FindAllOf("BP_Rubbish_C") or {}) do
        if PBZ.valid(a) then
            local l = a:K2_GetActorLocation()
            local d = PBZ.distance(l, here)
            if d <= (cm or 8000) then
                local v = {}
                for _, k in ipairs({ "bDestroyed", "Not Interact", "bHidden", "bActorEnableCollision", "HasStinger", "Get Dust", "UseLegacyType" }) do
                    local s = "?"
                    pcall(function() s = tostring(a[k]) end)
                    v[#v + 1] = k:gsub(" ", "") .. "=" .. s:sub(1, 6)
                end
                local vis, col, mesh = "?", "?", "?"
                pcall(function() vis = tostring(a.StaticMesh:IsVisible()) end)
                pcall(function() col = tostring(a.TriggerBox:GetCollisionEnabled()) end)
                pcall(function() mesh = tostring(a.StaticMesh.StaticMesh ~= nil) end)
                f:write(string.format("%.0fm %s %s vis=%s col=%s\n", d / 100, a:GetFName():ToString():sub(-22), table.concat(v, " "), vis, col))
                n = n + 1
            end
        end
    end
    f:close()
    return "PILES " .. n .. " " .. tostring(here.X)
end

function LOOTP.payPile2(tail)
    local a = LOOTP.find("BP_Rubbish_C", tail)
    if not a then return "PILE none" end
    local _, p = PBZ.getPlayer1()
    local before = p.ConsciousnessDust
    local ok1, e1 = pcall(function() a["Collect Items"](a) end)
    local paid = p.ConsciousnessDust - before
    local ok2 = pcall(function() a.bDestroyed = true end)
    local ok3, e3 = pcall(function() a:Disappear() end)
    local ok4 = false
    if not ok3 then ok4 = pcall(function() a["Disappear"](a) end) end
    return "PAYPILE collect " .. tostring(ok1) .. " dust " .. paid .. " flag " .. tostring(ok2) .. " disappear " .. tostring(ok3) .. "/" .. tostring(ok4) .. " " .. tostring(e3):sub(1, 60)
end

function LOOTP.pileLoot(cm)
    local _, p = PBZ.getPlayer1()
    local here, rows = p:K2_GetActorLocation(), {}
    for _, a in ipairs(FindAllOf("BP_Rubbish_C") or {}) do
        if PBZ.valid(a) then
            local l = a:K2_GetActorLocation()
            local d = PBZ.distance(l, here)
            if d <= (cm or 30000) then
                local id, dust, de = "?", "?", "?"
                pcall(function() id = a["Loot Item ID"]:ToString() end)
                pcall(function() dust = tostring(math.floor(a["Get Dust"])) end)
                pcall(function() de = tostring(a.bDestroyed) end)
                rows[#rows + 1] = { d, a:GetFName():ToString():sub(-22), id, dust, de, l }
            end
        end
    end
    table.sort(rows, function(x, y) return x[1] < y[1] end)
    local out = {}
    for i = 1, math.min(14, #rows) do
        local r = rows[i]
        out[#out + 1] = string.format("%.0fm %s %s dust %s done %s at %.0f,%.0f,%.0f", r[1] / 100, r[2], r[3], r[4], r[5], r[6].X, r[6].Y, r[6].Z)
    end
    return "LOOT " .. table.concat(out, " ; ")
end

function LOOTP.params(path)
    local f = StaticFindObject(path)
    if not PBZ.valid(f) then return "no function" end
    local out = {}
    pcall(function() f:ForEachProperty(function(p) out[#out + 1] = p:GetFName():ToString() .. ":" .. p:GetClass():GetFName():ToString() end) end)
    return "PARAMS " .. table.concat(out, " "):sub(1, 400)
end

function LOOTP.payPile3(tail)
    local a = LOOTP.find("BP_Rubbish_C", tail)
    if not a then return "PILE none" end
    local _, p = PBZ.getPlayer1()
    local before = p.ConsciousnessDust
    local ok1, e1 = pcall(function() a:OnInteract(p) end)
    local paid = p.ConsciousnessDust - before
    return "PAYPILE oninteract " .. tostring(ok1) .. " " .. tostring(e1):sub(1, 80) .. " dust " .. paid .. " destroyed " .. tostring(a.bDestroyed)
end

function LOOTP.pileFields(tail)
    local a = LOOTP.find("BP_Rubbish_C", tail)
    if not a then return "PILE gone" end
    local v = {}
    for _, k in ipairs({ "bDestroyed", "Not Interact", "bHidden", "bActorEnableCollision", "Get Dust", "Item Level" }) do
        local s = "?"
        pcall(function() s = tostring(a[k]) end)
        v[#v + 1] = k .. "=" .. s:sub(1, 12)
    end
    local inter, vi = "?", "?"
    pcall(function() inter = tostring(a:IsValidInteract(select(2, PBZ.getPlayer1()))) end)
    pcall(function() vi = tostring(a.StaticMesh:IsVisible()) end)
    return "FIELDS " .. table.concat(v, " ") .. " canInteract " .. inter .. " meshVisible " .. vi
end

function LOOTP.pileEnd(tail, how)
    local a = LOOTP.find("BP_Rubbish_C", tail)
    if not a then return "PILE gone" end
    local _, p = PBZ.getPlayer1()
    local ok, e
    if how == "switch" then
        ok, e = pcall(function() a:SwitchWithoutPlaySequence() end)
    elseif how == "end" then
        ok, e = pcall(function() a["End Interact"](a, p) end)
    elseif how == "state" then
        ok, e = pcall(function() a:ChangeSwitchState(true) end)
    end
    return "END " .. how .. " " .. tostring(ok) .. " " .. tostring(e):sub(1, 70)
end

function LOOTP.payPile4(tail)
    local a = LOOTP.find("BP_Rubbish_C", tail)
    if not a then return "PILE none" end
    local _, p = PBZ.getPlayer1()
    local before = p.ConsciousnessDust
    local ok1 = pcall(function() a:OnInteract(p) end)
    local paid = p.ConsciousnessDust - before
    if paid > 0 then pcall(function() p:ChangeDustNumInternal(-paid) end) end
    local ok2 = pcall(function() a:K2_DestroyActor() end)
    return "PAYPILE interact " .. tostring(ok1) .. " dust taken back " .. paid .. " removed " .. tostring(ok2)
end

function LOOTP.findClass(word)
    local out = {}
    for _, c in ipairs(FindAllOf("BlueprintGeneratedClass") or {}) do
        local n = c:GetFName():ToString()
        if n:find(word, 1, true) then out[#out + 1] = c:GetFullName() end
    end
    return "CLASS " .. #out .. " " .. table.concat(out, " | "):sub(1, 500)
end

function LOOTP.geKill(path)
    local _, p = PBZ.getPlayer1()
    local cls = StaticFindObject(path)
    if not PBZ.valid(cls) then return "no class" end
    local asc = StaticFindObject("/Script/GameplayAbilities.Default__AbilitySystemBlueprintLibrary"):GetAbilitySystemComponent(p)
    PBZ.game.setMinHealth(p, 0)
    local ok, r = pcall(function() return asc:BP_ApplyGameplayEffectToSelf(cls, 1.0, {}) end)
    local h, m = PBZ.game.getHealth(p)
    return "GEKILL " .. tostring(ok) .. " " .. tostring(r):sub(1, 60) .. " hp " .. tostring(h)
end

function LOOTP.scan(words)
    local out = {}
    for _, cls in ipairs({ "BP_Chest_C", "BP_Rubbish_C" }) do
        for _, a in ipairs(FindAllOf(cls) or {}) do
            if PBZ.valid(a) then
                local id = "?"
                pcall(function() id = a["Loot Item ID"]:ToString() end)
                for w in words:gmatch("%S+") do
                    if id:find(w, 1, true) then
                        local l = a:K2_GetActorLocation()
                        out[#out + 1] = string.format("%s|%s|%.0f|%.0f|%.0f", a:GetFName():ToString(), id, l.X, l.Y, l.Z)
                        break
                    end
                end
            end
        end
    end
    return "SCAN " .. table.concat(out, " ; ")
end

-- Weapons, medicines and accessories this player holds: lists the backpack diff can't see.
function LOOTP.gear()
    local _, p = PBZ.getPlayer1()
    local bp = StaticFindObject("/Script/Engine.Default__SubsystemBlueprintLibrary"):GetWorldSubsystem(p, StaticFindObject("/Script/ProjectPBZ.PBZBackPackSubsystem"))
    local out = {}
    for _, field in ipairs(LOOTP.GEAR or {}) do
        local n, names = 0, {}
        pcall(function()
            bp[field]:ForEach(function(k, v)
                n = n + 1
                local s = "?"
                pcall(function() s = k:get():ToString() end)
                names[#names + 1] = s
            end)
        end)
        out[field] = names
    end
    return out
end

function LOOTP.gearMark()
    LOOTP.gear0 = LOOTP.gear()
    local t = {}
    for f, v in pairs(LOOTP.gear0) do t[#t + 1] = f .. "=" .. #v end
    table.sort(t)
    return "GEAR " .. table.concat(t, " ")
end

function LOOTP.gearDiff()
    local now, out = LOOTP.gear(), {}
    for f, v in pairs(now) do
        local had = {}
        for _, s in ipairs(LOOTP.gear0[f] or {}) do had[s] = true end
        for _, s in ipairs(v) do
            if not had[s] then out[#out + 1] = f .. "+" .. s end
        end
    end
    table.sort(out)
    return "GEAR new [" .. table.concat(out, " ") .. "]"
end

LOOTP.GEAR = { "MainWeaponInfos", "ShaqiWeaponInfos", "MedicineInfos", "Accessories" }

function LOOTP.gearFile(path)
    local f = io.open(path, "w")
    for field, names in pairs(LOOTP.gear()) do
        for _, n in ipairs(names) do f:write(field, " ", n, "\n") end
    end
    f:close()
    return "GEARFILE ok"
end

local function listOf(data)
    local out = {}
    local function text(v)
        if type(v) == "string" then return v end
        local ok, s = pcall(function() return v:ToString() end)
        return ok and s or tostring(v)
    end
    for k, v in pairs(type(data.LootItems) == "table" and data.LootItems or {}) do out[#out + 1] = text(k) .. "x" .. tostring(v) end
    for k, v in pairs(type(data.LootWeapons) == "table" and data.LootWeapons or {}) do out[#out + 1] = "weapon:" .. text(k) end
    for _, v in pairs(type(data.Medicines) == "table" and data.Medicines or {}) do out[#out + 1] = "medicine:" .. text(v) end
    for _, v in pairs(type(data.Accessories) == "table" and data.Accessories or {}) do out[#out + 1] = "accessory:" .. text(v) end
    return "dust " .. tostring(data.LootDust) .. " [" .. table.concat(out, " ") .. "]"
end

-- The loot table's row for an id, rolled without the chest: on any enemy, then on the class default.
function LOOTP.roll(id, level)
    local npc = FindFirstOf("PBZCharacter_NPC")
    local out = {}
    for _, who in ipairs({ npc, StaticFindObject("/Script/ProjectPBZ.Default__PBZCharacter_NPC") }) do
        if who then
            local data = {}
            local ok, err = pcall(function() who:GetCombatLootData(level or 0, nil, FName(id), data, false, false) end)
            if not ok then
                data = {}
                ok, err = pcall(function() who:GetCombatLootData(level or 0, {}, FName(id), data, false) end)
            end
            out[#out + 1] = tostring(who:GetFName():ToString()):sub(1, 30) .. " " .. tostring(ok) .. " " .. (ok and listOf(data) or tostring(err):sub(1, 90))
        end
    end
    return "ROLL " .. table.concat(out, " || ")
end

function LOOTP.pileAt(tail)
    local a = LOOTP.find("BP_Rubbish_C", tail)
    if not a then return "PILE gone" end
    local id, lvl, il = "?", "?", "?"
    pcall(function() id = a["Loot Item ID"]:ToString() end)
    pcall(function() lvl = tostring(a.LootLevel) end)
    pcall(function() il = tostring(a["Item Level"]) end)
    return "PILEAT " .. id .. " lootlevel " .. lvl .. " itemlevel " .. il
end

function LOOTP.roll2(id, level)
    local _, p = PBZ.getPlayer1()
    local out = {}
    for _, who in ipairs({ FindFirstOf("PBZCharacter_NPC"), StaticFindObject("/Script/ProjectPBZ.Default__PBZCharacter_NPC") }) do
        if who then
            local data = {}
            local ok, err = pcall(function() who:GetCombatLootData(level or 0, nil, FName(id), data, false, p) end)
            out[#out + 1] = tostring(ok) .. " " .. (ok and listOf(data) or tostring(err):sub(1, 110))
        else
            out[#out + 1] = "no object"
        end
    end
    return "ROLL " .. table.concat(out, " || ")
end

function LOOTP.gearHooks()
    if LOOTP.gearOn then return "already" end
    LOOTP.gearOn = true
    local out = {}
    for _, fn in ipairs({ "PushAccessoryToInventory", "AddMedicineConfig", "AddMedicineAmount", "AddSpecifiedMedicineAmount", "AddSkin" }) do
        local ok = pcall(function()
            RegisterHook("/Script/ProjectPBZ.PBZBackPackSubsystem:" .. fn, function(self, a, b)
                local x, y = "?", "?"
                pcall(function() x = a:get():ToString() end)
                pcall(function() y = tostring(b:get()) end)
                log("LOOTBAG " .. fn .. " " .. x .. " " .. y)
            end)
        end)
        out[#out + 1] = fn .. "=" .. tostring(ok)
    end
    return table.concat(out, " ")
end

function LOOTP.addAc(id, how)
    local _, p = PBZ.getPlayer1()
    local bp = StaticFindObject("/Script/Engine.Default__SubsystemBlueprintLibrary"):GetWorldSubsystem(p, StaticFindObject("/Script/ProjectPBZ.PBZBackPackSubsystem"))
    local ok, err
    if how == "push" then
        ok, err = pcall(function() bp:PushAccessoryToInventory(FName(id), false) end)
    elseif how == "give" then
        ok, err = pcall(function() p:GiveItem(FName(id), 1) end)
    end
    return "ADD " .. how .. " " .. tostring(ok) .. " " .. tostring(err):sub(1, 90)
end

function LOOTP.buy(id)
    local _, p = PBZ.getPlayer1()
    local bp = StaticFindObject("/Script/Engine.Default__SubsystemBlueprintLibrary"):GetWorldSubsystem(p, StaticFindObject("/Script/ProjectPBZ.PBZBackPackSubsystem"))
    local d0 = p.ConsciousnessDust
    local ok, err = pcall(function() bp:BuyItem(FName(id), 1) end)
    return "BUY " .. tostring(ok) .. " " .. tostring(err):sub(1, 70) .. " dust " .. (p.ConsciousnessDust - d0)
end

function LOOTP.addMed(id)
    local _, p = PBZ.getPlayer1()
    local bp = StaticFindObject("/Script/Engine.Default__SubsystemBlueprintLibrary"):GetWorldSubsystem(p, StaticFindObject("/Script/ProjectPBZ.PBZBackPackSubsystem"))
    local ok, err = pcall(function() bp:PushMedicineToInventory(FName(id), false, true) end)
    return "ADDMED " .. tostring(ok) .. " " .. tostring(err):sub(1, 90)
end

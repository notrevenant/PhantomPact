-- The online panel (F4 with any Role but Local): host, join or leave from inside the game, with no ini to edit and no
-- restart. It's drawn and read as the local co-op panel is (panel.lua, whose notes on the mouse hold here too): pictures
-- from art/make_online_panel.py, and the words that change in the game's own ink-bar text. autostart.lua does the
-- connecting (api.online); this file picks what to ask for, keeps it in PhantomPact.ini and says how it's going.

return function(api)
    local log, valid, hud, game, kit = api.log, api.valid, api.hud, api.game, api.panel.kit

    local KEY_MS = 40               -- how often F4 is looked at; a press lasts longer
    local TICK_MS = 15
    local WORDS_S = 0.5
    local NO_MOUSE_S = 3.0          -- no answer from main.dll for this long: the panel couldn't be closed by hand
    local Z = 900
    local CARD_W, CARD_H = 176, 58
    local BUTTON_W, BUTTON_H = 170, 46
    local WORDS_Y = 155             -- middle of the status box, in panel units
    local TIP_FROM_BOTTOM = 30      -- where the game lays out the ink-bar text: centred, this far above the screen's bottom
    local CLOSE = { x = 848, y = 14, w = 38, h = 38 }
    -- Nothing at the panel's middle: main.dll clicks there once as it opens (see free_cursor).
    local CONNECT = { steam = { x = 40, y = 244 }, tailscale = { x = 228, y = 244 } }
    local BUTTONS = { host = { x = 40, y = 350 }, join = { x = 228, y = 350 }, leave = { x = 416, y = 350 } }

    local panel = { open = false }
    local choice = { connect = "tailscale" }
    local pc = nil
    local wasF4, wasDown, f4Armed, f4Held, escHeld = false, false, false, false, false
    local words, wordsWidget, wordsAt, note, mouseAt = nil, nil, 0, nil, 0

    ------------------------------------------------------------------ PhantomPact.ini

    -- Only these lines change: comments, the other settings and the file's line ends stay as they are.
    local function save(values)
        local path = api.modDir() .. "PhantomPact.ini"
        local f = io.open(path, "rb")
        local text = f and f:read("a") or ""
        if f then
            f:close()
        end
        local out, seen, at = {}, {}, 1
        while at <= #text do
            local stop = text:find("\n", at, true) or #text
            local line = text:sub(at, stop)
            local key = line:match("^%s*([%w_]+)%s*=")
            for name, value in pairs(values) do
                if key and key:lower() == name:lower() then
                    line = name .. " = " .. value .. (line:match("\r?\n$") or "")
                    seen[name] = true
                end
            end
            out[#out + 1] = line
            at = stop + 1
        end
        for name, value in pairs(values) do
            if not seen[name] then
                out[#out + 1] = name .. " = " .. value .. "\n"
            end
        end
        local tmp = io.open(path .. ".tmp", "wb")
        local wrote = tmp and tmp:write(table.concat(out))
        if tmp then
            tmp:close()
        end
        if not wrote then
            log("Couldn't save PhantomPact.ini: this choice lasts until the game closes.")
            return
        end
        os.remove(path)
        if not os.rename(path .. ".tmp", path) then
            log("Couldn't save PhantomPact.ini: see PhantomPact.ini.tmp in " .. api.modDir())
        end
    end

    local function connectIn(settings)
        return (settings and settings.connect or "tailscale"):lower() == "steam" and "steam" or "tailscale"
    end

    ------------------------------------------------------------------ what's going on, in plain words

    local function relayStatus()
        local line = api.link and api.link.status() or ""
        local kv = {}
        for k, v in line:gmatch("([%w_]+)=(%S+)") do
            kv[k] = v
        end
        kv.error = line:match(" error=(.*)$")       -- the last field, and it may hold spaces
        return kv
    end

    local function describe()
        local c = api.online and api.online.current()
        if not c then
            return note or "Not connected."
        end
        local s = relayStatus()
        if s.stopped == "yes" or s.role ~= c.modRole then
            return s.error and s.role == c.modRole and ("Couldn't start: " .. s.error) or "Starting..."
        end
        if s.connected == "yes" then
            local text = "Connected to " .. (s.peer or "?"):gsub(":%d+$", "") .. "."
            if tonumber(s.rtt_ms) then
                text = text .. " Ping " .. s.rtt_ms .. " ms."
            end
            if s.route and s.route ~= "-" then
                text = text .. " Route: " .. s.route .. "."
            end
            return text
        end
        if c.modRole == "host" then
            return "Waiting for a partner."
        end
        return c.hostAddress ~= "" and ("Looking for " .. c.hostAddress .. "...")
            or "Looking for a Steam friend who's hosting..."
    end

    local function showWords(now)
        if now < wordsAt then
            return
        end
        wordsAt = now + WORDS_S
        local text = describe()
        if not api.status.onScreen(wordsWidget) then
            wordsWidget, words = api.status.newTipWidget(Z + 5), nil
        end
        if not wordsWidget then
            return
        end
        if words == nil then
            pcall(function() wordsWidget:PlayAnimation(wordsWidget.FadeIn, 0, 1, 0, 1, false) end)
        end
        if text ~= words then
            words = text
            wordsWidget:SetText(FText(text))
            log("Online panel: " .. text)
        end
        -- Moved as a picture, up from where the game lays it out: its own layout fills the screen and stays as it is.
        local o = kit.origin
        local screenH = 2 * o.y + kit.H * o.scale
        wordsWidget:SetRenderTranslation({ X = 0, Y = o.y + WORDS_Y * o.scale - (screenH - TIP_FROM_BOTTOM) })
        hud.show(wordsWidget, true)
    end

    ------------------------------------------------------------------ the buttons

    local function act(what)
        note = nil
        wordsAt = 0
        if what == "leave" then
            api.online.stop()
            save({ Role = "Off" })
            return
        end
        local settings = api.online.settings() or {}
        settings.connect = choice.connect
        local c, why = api.online.connection(settings, what == "host" and "host" or "guest")
        if not c then
            note = why
            log("Online panel: " .. why)
            return
        end
        -- Saved first: the relay reads the ini as it starts.
        save({ Role = what == "host" and "Host" or "Guest", Connect = choice.connect == "steam" and "Steam" or "Tailscale" })
        api.online.start(c, settings)
    end

    local function running()
        return api.online and api.online.current() ~= nil
    end

    local function press(x, y)
        if kit.inside(x, y, CLOSE) then
            panel.close()
            return
        end
        for name, r in pairs(BUTTONS) do
            if kit.inside(x, y, r, BUTTON_W, BUTTON_H) then
                local c = running() and api.online.current()
                if name == "leave" and c then
                    act("leave")
                elseif name ~= "leave" and not (c and c.modRole == (name == "host" and "host" or "client")) then
                    act(name)
                end
            end
        end
        for name, r in pairs(CONNECT) do
            if not running() and name ~= choice.connect and kit.inside(x, y, r, CARD_W, CARD_H) then
                choice.connect = name
                note, wordsAt = nil, 0
                save({ Connect = name == "steam" and "Steam" or "Tailscale" })
            end
        end
    end

    ------------------------------------------------------------------ on screen

    local function drawAll()
        local c = api.online and api.online.current()
        kit.place(kit.part("on_bg", "online_bg", kit.W, kit.H, 0), 0, 0)
        kit.place(kit.part("on_close", "close", CLOSE.w, CLOSE.h, 1), CLOSE.x, CLOSE.y)
        for name, r in pairs(CONNECT) do
            local p = kit.part("on_" .. name, "online_" .. name, CARD_W, CARD_H, 1)
            kit.place(p, r.x, r.y)
            kit.dim(p, (c and name ~= choice.connect) and 0.3 or 1.0)
        end
        local at = CONNECT[choice.connect]
        kit.place(kit.part("on_sel_card", "sel_card", CARD_W, CARD_H, 2), at.x, at.y)
        for name, r in pairs(BUTTONS) do
            local p = kit.part("on_" .. name, "online_" .. name, BUTTON_W, BUTTON_H, 1)
            kit.place(p, r.x, r.y)
            kit.dim(p, (name == "leave" and not c) and 0.35 or 1.0)
        end
        local mine = c and BUTTONS[c.modRole == "host" and "host" or "join"]
        if mine then
            kit.place(kit.part("on_sel_button", "sel_button", BUTTON_W, BUTTON_H, 2), mine.x, mine.y)
        else
            kit.hide("on_sel_button")
        end
    end

    local function tick()
        if not panel.open then
            return
        end
        if not valid(pc) then
            panel.close()
            return
        end
        kit.measure(pc)
        local x, y, down, esc, f4, focused = kit.input()
        if x ~= nil then
            mouseAt = os.clock()
        elseif os.clock() - mouseAt > NO_MOUSE_S then
            log("Online panel: no mouse from main.dll, closing.")
            panel.close()
            return
        end
        if x ~= nil and focused then
            if down and not wasDown then
                press(x, y)
            end
            wasDown = down
            if not panel.open then
                return
            end
            -- Closed on the key's release, so the game doesn't see it go down too. The F4 that opened it doesn't count.
            f4Armed = f4Armed or not f4
            f4Held = f4Held or (f4Armed and f4)
            if (escHeld and not esc) or (f4Held and not f4) then
                panel.close()
                return
            end
            escHeld = esc
        end
        drawAll()
        showWords(os.clock())
    end

    -- The game's own screens and menus keep the mouse and the pause to themselves, and a load has nobody to open it for.
    local function canOpen(controller, pawn)
        return not (api.gs():IsGamePaused(controller) or game.inCutscene() or game.isDead(pawn)
            or api.localcoop.bellMenuUp() or api.localcoop.screenUp())
    end

    function panel.show()
        local controller, pawn = api.getPlayer1()
        if panel.open or not valid(pawn) or not canOpen(controller, pawn) then
            return
        end
        pc = controller
        choice.connect = connectIn(api.online.settings())
        -- Widgets don't survive a map change.
        for name, p in pairs(kit.parts) do
            if not api.status.onScreen(p.widget) then
                kit.parts[name] = nil
            end
        end
        panel.open = true
        wasDown, f4Armed, f4Held, escHeld = false, false, false, false
        words, wordsAt, mouseAt = nil, 0, os.clock()
        os.remove(api.modDir() .. "mouse.txt")
        kit.writeWant(true)
        kit.blockPlay(pc, true)
        log("Online panel open.")
    end

    function panel.close()
        panel.open = false
        kit.writeWant(false)
        for _, p in pairs(kit.parts) do
            hud.show(p.widget, false)
        end
        hud.show(wordsWidget, false)
        if valid(pc) then
            kit.blockPlay(pc, false)
        end
        log("Online panel closed.")
    end

    -- F4 is read on the game thread, as in panel.lua. Only from here on does Lua look at it: never with Role = Local.
    local function readKey()
        local controller, pawn = api.getPlayer1()
        if not valid(pawn) then
            wasF4 = false
            return
        end
        local f4 = controller:IsInputKeyDown(kit.key("F4"))
        if f4 and not wasF4 and not panel.open then
            panel.show()
        end
        wasF4 = f4
    end

    local function guarded(fn)
        local ok, err = pcall(fn)
        if not ok then
            log("Online panel error: " .. tostring(err))
            if panel.open then
                pcall(panel.close)
            end
        end
    end

    function panel.start()
        os.remove(api.modDir() .. "pads_want.txt")      -- left by a crash with the panel open
        LoopInGameThreadWithDelay(KEY_MS, function()
            guarded(readKey)
            return false
        end)
        LoopInGameThreadWithDelay(TICK_MS, function()
            guarded(tick)
            return false
        end)
    end

    panel.describe = describe       -- for tools/netlab/bench/online-panel.ps1

    -- onlinepanel toggle|host|join|leave|steam|tailscale|press <x> <y>: what the keys and the mouse do, for tests.
    function panel.command(rest)
        local word, x, y = (rest or ""):match("^(%S*)%s*(%S*)%s*(%S*)")
        if word == "toggle" then
            if panel.open then
                panel.close()
            else
                panel.show()
            end
        elseif word == "host" or word == "join" or word == "leave" then
            local r = BUTTONS[word]
            press(r.x + 5, r.y + 5)
        elseif CONNECT[word] then
            local r = CONNECT[word]
            press(r.x + 5, r.y + 5)
        elseif word == "press" then
            press(tonumber(x), tonumber(y))
        end
        log("Online panel " .. (panel.open and "open" or "closed") .. ", " .. choice.connect .. ": " .. describe())
    end

    return panel
end

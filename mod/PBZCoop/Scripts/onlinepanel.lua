-- The online panel (F5, in any mode but Local): host, join or leave from inside the game, with nothing to edit and no
-- restart. It's the only place settings change. It's drawn and read as the local co-op panel is (panel.lua, whose notes
-- on the mouse hold here too): pictures from art/make_online_panel.py, and the words that change in the game's own
-- ink-bar text. autostart.lua does the connecting (api.online), always through Steam; this file picks what to ask for,
-- keeps it for the next start (settings.lua) and says how it's going.

return function(api)
    local log, valid, hud, game, kit = api.log, api.valid, api.hud, api.game, api.panel.kit
    local save = api.settings.save

    local KEY_MS = 40               -- how often F5 is looked at; a press lasts longer
    local TICK_MS = 15
    local WORDS_S = 0.5
    local NO_MOUSE_S = 3.0          -- no answer from main.dll for this long: the panel couldn't be closed by hand
    local REFOCUS_S = 0.5           -- back in the game: the click that brought you, and main.dll's, press nothing
    local Z = 900
    local CARD_W, CARD_H = 176, 58
    local BUTTON_W, BUTTON_H = 170, 46
    local WORDS_Y = 155             -- middle of the status box, in panel units
    local TIP_FROM_BOTTOM = 30      -- where the game lays out the ink-bar text: centred, this far above the screen's bottom
    local CLOSE = { x = 848, y = 14, w = 38, h = 38 }
    -- main.dll clicks the panel's middle as it opens and on coming back to the game (see free_cursor): no click counts for
    -- REFOCUS_S then.
    local STEAM = { x = 40, y = 244 }  -- the way to connect: always Steam. Pressed, it picks which friend GUEST joins
    local BUTTONS = { host = { x = 40, y = 350 }, join = { x = 228, y = 350 }, leave = { x = 416, y = 350 } }
    local LANGUAGE = { en = { x = 40, y = 18 }, zh = { x = 124, y = 18 } }
    local LANGUAGE_W, LANGUAGE_H = 76, 30

    local SETTINGS = { x = 690, y = 494 }
    local BACK = { x = 40, y = 494 }
    local OPTION_W, OPTION_H = 124, 40
    local OPTION_X, OPTION_STEP = 300, 136
    -- The gameplay options: a row per setting, top to bottom on the settings page.
    local ROWS = {
        { name = "teleport", y = 84, choices = { "off", "on" } },
        { name = "pvp", y = 186, choices = { "off", "on" } },
        { name = "compass", y = 237, choices = { "off", "on" } },
        { name = "mapicon", y = 288, choices = { "off", "on" } },
        { name = "direct", y = 339, choices = { "off", "on" } },
        { name = "four", y = 390, choices = { "off", "on" } },
        { name = "mode", y = 441, choices = { "multiplayer", "local" } },
    }

    local panel = { open = false }
    local pick = nil                -- the friend GUEST joins: { id, name } from api.online.hosts(), or nil for any friend
    local pc = nil
    local wasKey, wasDown, keyArmed, keyHeld, escHeld = false, false, false, false, false
    local wasFocused, clicksFrom = false, 0
    local page, options, loggedWords = "main", {}, nil
    local words, wordsWidget, wordsAt, note, mouseAt = nil, nil, 0, nil, 0

    ------------------------------------------------------------------ the settings page

    local function readOptions()
        local s = api.settings.read()
        local function onOff(value, default)
            return (value or default):lower() == "on" and "on" or "off"
        end
        options = {
            teleport = onOff(s.partnerteleport, "off"),
            pvp = onOff(s.pvp, "off"),
            compass = onOff(s.partnercompass, "on"),
            mapicon = onOff(s.partnermapicon, "on"),
            direct = onOff(s.steamdirect, "off"),
            four = onOff(s.fourplayers, "off"),
            -- Only a Local role is local: Off, Host and Guest, and a fresh install, are all multiplayer. Read each time this
            -- page opens, as Host, Guest and Leave write Role too.
            mode = (s.role or "off"):lower() == "local" and "local" or "multiplayer",
        }
    end

    -- Kept for the next start, and in force at once. (Steam Direct and 4 players from the next connection: the relay reads
    -- them as it starts. 4 players is the host's choice: a guest follows what the host's relay says. Mode from the next start
    -- of the game: Role is read once, and local co-op can't be taken down live.)
    local function choose(row, value)
        options[row] = value
        local on = value == "on"
        local word = on and "On" or "Off"
        if row == "teleport" then
            save({ PartnerTeleport = word })
            api.partner.teleport = on
        elseif row == "pvp" then
            save({ PvP = word })
            api.pvp.command(on and "on" or "off")
        elseif row == "compass" then
            save({ PartnerCompass = word })
            api.hud.set(on)
        elseif row == "mapicon" then
            save({ PartnerMapIcon = word })
            api.mapicon.on = on
        elseif row == "direct" then
            save({ SteamDirect = word })
        elseif row == "four" then
            save({ FourPlayers = word })
        elseif row == "mode" and value == "local" then
            save({ Role = "Local" })
            api.status.lastShown.mode = nil
            api.status.notify("mode", "Local co-op starts the next time you start the game.")
        elseif row == "mode" and (api.settings.read().role or ""):lower() == "local" then
            save({ Role = "Off" })          -- (never over a Host or Guest: this row only undoes Local)
        end
    end

    local function showPage(name)
        page = name
        for _, p in pairs(kit.parts) do
            hud.show(p.widget, false)
        end
        hud.show(wordsWidget, false)
        words = nil
        if name == "settings" then
            readOptions()
        end
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
            if s.players then
                local here = 1
                for _, p in ipairs(api.coop.partners()) do
                    here = here + ((p.lastRemoteAt and not p.partnerGone) and 1 or 0)
                end
                text = text .. " Players: " .. here .. " of " .. s.players .. "."
                local me = api.coop.players[tonumber(s.slot)]
                if me then
                    text = text .. " You're " .. me.name .. "."
                end
            end
            return text
        end
        if c.modRole == "host" then
            return "Waiting for a partner."
        end
        return c.target and ("Looking for " .. c.targetName .. "...") or "Looking for a Steam friend who's hosting..."
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
            -- (The ping moves all the time: logged only when something else changes.)
            local plain = text:gsub("%d+ ms", "")
            if plain ~= loggedWords then
                loggedWords = plain
                log("Online panel: " .. text)
            end
            words = text
            wordsWidget:SetText(FText(api.lang.say(text)))
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
        local c = api.online.connection(what == "host" and "host" or "guest", pick and pick.id, pick and pick.name)
        save({ Role = what == "host" and "Host" or "Guest" })
        api.online.start(c, api.settings.read())
    end

    -- The Steam card, pressed: the next friend who's hosting, then any friend again. Steam's own list, read each press, so a
    -- friend who stopped hosting drops out. Only for this game: the next start joins any friend again.
    local function pickFriend()
        local list = api.online.hosts and api.online.hosts() or {}
        local nextOne = nil
        if #list > 0 then
            local at = 0
            for i, h in ipairs(list) do
                if pick and h.id == pick.id then
                    at = i
                end
            end
            nextOne = list[at + 1]      -- past the last: any friend. One who stopped hosting: the first again
        end
        pick = nextOne
        wordsAt = 0
        if pick then
            note = "Joining " .. pick.name .. " when you press GUEST. Press Steam for another friend."
        elseif #list == 0 then
            note = "No friend is hosting right now. GUEST waits for one."
        else
            note = string.format("Any friend who's hosting. Press Steam to pick one (%d hosting).", #list)
        end
        log("Online panel: " .. note)
    end

    local function setLanguage(code)
        api.lang.set(code == "zh" and "Chinese" or "English")
        save({ Language = api.lang.word() })
        words, wordsAt = nil, 0
    end

    local function running()
        return api.online and api.online.current() ~= nil
    end

    local function pressSettings(x, y)
        if kit.inside(x, y, BACK, BUTTON_W, BUTTON_H) then
            showPage("main")
            return
        end
        for _, row in ipairs(ROWS) do
            for i, value in ipairs(row.choices) do
                local at = { x = OPTION_X + (i - 1) * OPTION_STEP, y = row.y }
                if value ~= options[row.name] and kit.inside(x, y, at, OPTION_W, OPTION_H) then
                    choose(row.name, value)
                end
            end
        end
    end

    local function press(x, y)
        if kit.inside(x, y, CLOSE) then
            panel.close()
            return
        end
        if page == "settings" then
            pressSettings(x, y)
            return
        end
        if kit.inside(x, y, SETTINGS, BUTTON_W, BUTTON_H) then
            showPage("settings")
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
        for code, r in pairs(LANGUAGE) do
            if code ~= api.lang.code and kit.inside(x, y, r, LANGUAGE_W, LANGUAGE_H) then
                setLanguage(code)
            end
        end
        if not running() and kit.inside(x, y, STEAM, CARD_W, CARD_H) then
            pickFriend()
        end
    end

    ------------------------------------------------------------------ on screen

    -- A picture with words on it, in the language picked.
    local function worded(name, tex, w, h, z)
        tex = (api.lang.code == "zh" and "zh_" or "") .. tex
        local p = kit.part(name, tex, w, h, z)
        kit.picture(p, tex)
        return p
    end

    local function drawSettings()
        kit.place(worded("on_bg2", "online_settings_bg", kit.W, kit.H, 0), 0, 0)
        kit.place(kit.part("on_close", "close", CLOSE.w, CLOSE.h, 1), CLOSE.x, CLOSE.y)
        kit.place(worded("on_back", "online_back", BUTTON_W, BUTTON_H, 1), BACK.x, BACK.y)
        for _, row in ipairs(ROWS) do
            for i, value in ipairs(row.choices) do
                local x = OPTION_X + (i - 1) * OPTION_STEP
                kit.place(worded("on_" .. row.name .. "_" .. value, "opt_" .. value, OPTION_W, OPTION_H, 1), x, row.y)
                if value == options[row.name] then
                    kit.place(kit.part("on_sel_" .. row.name, "sel_opt", OPTION_W, OPTION_H, 2), x, row.y)
                end
            end
        end
    end

    local function drawAll()
        local c = api.online and api.online.current()
        kit.place(worded("on_bg", "online_bg", kit.W, kit.H, 0), 0, 0)
        kit.place(kit.part("on_close", "close", CLOSE.w, CLOSE.h, 1), CLOSE.x, CLOSE.y)
        for code, r in pairs(LANGUAGE) do
            kit.place(kit.part("on_lang_" .. code, "online_lang_" .. code, LANGUAGE_W, LANGUAGE_H, 1), r.x, r.y)
        end
        local lang = LANGUAGE[api.lang.code]
        kit.place(kit.part("on_sel_lang", "sel_lang", LANGUAGE_W, LANGUAGE_H, 2), lang.x, lang.y)
        local card = worded("on_steam", "online_steam", CARD_W, CARD_H, 1)
        kit.place(card, STEAM.x, STEAM.y)
        kit.dim(card, c and 0.3 or 1.0)
        kit.place(kit.part("on_sel_card", "sel_card", CARD_W, CARD_H, 2), STEAM.x, STEAM.y)
        -- Your role is the red one.
        local mine = c and (c.modRole == "host" and "host" or "join")
        for name, r in pairs(BUTTONS) do
            if name == mine then
                kit.hide("on_" .. name)
                kit.place(worded("on_" .. name .. "_on", "online_" .. name .. "_on", BUTTON_W, BUTTON_H, 1), r.x, r.y)
            else
                kit.hide("on_" .. name .. "_on")
                local p = worded("on_" .. name, "online_" .. name, BUTTON_W, BUTTON_H, 1)
                kit.place(p, r.x, r.y)
                kit.dim(p, (name == "leave" and not c) and 0.35 or 1.0)
            end
        end
        kit.place(worded("on_settings", "online_settings", BUTTON_W, BUTTON_H, 1), SETTINGS.x, SETTINGS.y)
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
        local x, y, down, esc, key, focused = kit.input()
        if x ~= nil then
            mouseAt = os.clock()
        elseif os.clock() - mouseAt > NO_MOUSE_S then
            log("Online panel: no mouse from main.dll, closing.")
            panel.close()
            return
        end
        if focused and not wasFocused then
            clicksFrom = os.clock() + REFOCUS_S
        end
        wasFocused = focused
        if x ~= nil and focused then
            if down and not wasDown and os.clock() >= clicksFrom then
                press(x, y)
            end
            wasDown = down
            if not panel.open then
                return
            end
            -- Closed on the key's release, so the game doesn't see it go down too. The F5 that opened it doesn't count.
            keyArmed = keyArmed or not key
            keyHeld = keyHeld or (keyArmed and key)
            if (escHeld and not esc) or (keyHeld and not key) then
                panel.close()
                return
            end
            escHeld = esc
        end
        if page == "settings" then
            drawSettings()
            return
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
        -- Widgets don't survive a map change.
        for name, p in pairs(kit.parts) do
            if not api.status.onScreen(p.widget) then
                kit.parts[name] = nil
            end
        end
        panel.open = true
        page = "main"
        wasDown, keyArmed, keyHeld, escHeld, wasFocused, clicksFrom = false, false, false, false, true, os.clock() + REFOCUS_S
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

    -- F5 is read on the game thread, as in panel.lua. Only from here on does Lua look at it: never in Local mode.
    local function readKey()
        local controller, pawn = api.getPlayer1()
        if not valid(pawn) then
            wasKey = false
            return
        end
        local key = controller:IsInputKeyDown(kit.key("F5"))
        if key and not wasKey and not panel.open then
            panel.show()
        end
        wasKey = key
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

    -- onlinepanel toggle|host|join|leave|steam|press <x> <y>|row <name>: what the keys and the mouse do, for tests.
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
        elseif word == "steam" then
            press(STEAM.x + 5, STEAM.y + 5)
        elseif word == "press" then
            press(tonumber(x), tonumber(y))
        elseif word == "row" then
            log("Online panel row " .. x .. ": " .. tostring(options[x]))
        end
        log("Online panel " .. (panel.open and "open" or "closed") .. ", Steam: " .. describe())
    end

    return panel
end

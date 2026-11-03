-- Phantom Pact auto-start: reads what the panels saved last time (settings.lua), starts the network relay when the game
-- starts, and turns online sync on once the player is in gameplay. Everything is set in the game: the F5 panel hosts,
-- joins and leaves, and there's nothing to edit or run by hand.
--
-- The relay is the built-in one (dlls\main.dll, native/ in the repo), which UE4SS loads with the game and which ends
-- with it, or when the player leaves (api.online, for onlinepanel.lua). It always connects through Steam Networking: a
-- guest joins a Steam friend who is hosting, with no address to type: any of them, the one picked in the panel, or the one
-- whose Join Game or invite the player took in Steam (steam_social.hpp).

return function(api)
    local log, valid, getPlayer1 = api.log, api.valid, api.getPlayer1
    local modDir, modRoot = api.modDir, api.modRoot
    local neton = api.coop.commands.neton

    -- Game builds this version was tested on, by PBZ.exe size (instant to read; hashing a 500 MB exe isn't).
    -- Another build still runs, with a warning: function and field names may have changed. (From appdoze's PR #2.)
    local KNOWN_BUILDS = {
        [511072344] = "Steam build 26266538",
    }
    pcall(function()
        local f = io.open(modRoot() .. "../../../PBZ.exe", "rb")
        if not f then
            return
        end
        local size = f:seek("end")
        f:close()
        if KNOWN_BUILDS[size] then
            log("Game build: " .. KNOWN_BUILDS[size] .. " (tested).")
        else
            api.gameBuildWarning = "this game update isn't tested with this Phantom Pact version; some co-op "
                .. "features may fail."
            log("WARNING: this game build (PBZ.exe " .. tostring(size) .. " bytes) wasn't tested with Phantom Pact "
                .. tostring(api.version) .. ". Co-op may partly fail; check for a Phantom Pact update.")
        end
    end)

    local function writeText(path, text)
        local f = io.open(path, "w")
        if f then
            f:write(text)
            f:close()
        end
    end

    local function onOff(value, default)
        return (value or default):lower() == "on"
    end

    local settings = api.settings.read()
    if api.hud then
        api.hud.set(onOff(settings.partnercompass, "on"))
    end
    if api.mapicon then
        api.mapicon.on = onOff(settings.partnermapicon, "on")
    end
    api.lang.set(settings.language)
    api.partner.teleport = onOff(settings.partnerteleport, "off")
    local role = (settings.role or "off"):lower()
    os.remove(modDir() .. "pads_watch.txt")
    os.remove(modDir() .. "pads_want.txt")      -- left by a crash with a panel open: main.dll would think one still is
    if role == "local" then
        -- Two joysticks to start with; the F4 panel's choices (localcoop.txt) replace that.
        api.localcoop.start(2)
        return
    end
    -- What stops co-op from starting. The player reads it in the game, once in the world: a log line is easy to miss.
    local setupTip = nil
    local function setupProblem(text)
        log(text)
        setupTip = text
    end

    -- Friends hosting Phantom Pact now, as Steam's rich presence says: { { id = "7656...", name = "..." }... }.
    local function hosts()
        local out = {}
        local text = api.link and api.link.steam_hosts and api.link.steam_hosts() or ""
        for id, name in text:gmatch("(%d+)\t([^\n]*)\n") do
            out[#out + 1] = { id = id, name = name }
        end
        return out
    end

    -- What to ask the relay for in this role, or nil if the role isn't an online one. target: a guest's one host, by
    -- SteamID64 (17 digits), and the name to show for it.
    local function connection(wanted, target, targetName)
        local modRole = ({ host = "host", guest = "client" })[wanted]
        if not modRole then
            return nil
        end
        local c = { role = wanted, modRole = modRole }
        if modRole == "client" and type(target) == "string" and target:match("^%d+$") and #target == 17 then
            c.target, c.targetName = target, targetName or target
        end
        return c
    end

    -- The relay's thread waits for net_start.txt, which appears whole thanks to the rename. It carries all the relay
    -- needs: the role, the version, the host's 4 PLAYERS, Steam Direct, and PvP, which both players must have the same.
    local function startRelay(c, s)
        if not api.link then
            setupProblem("Couldn't start the relay: dlls\\main.dll can't be reached. Reinstall Phantom Pact, check your antivirus didn't remove it, and use the UE4SS build from the install guide.")
            return false
        end
        local lines = { "role=" .. c.modRole, "version=" .. (api.version or "?"),
            "fourplayers=" .. (onOff(s.fourplayers, "off") and "on" or "off"),
            "steamdirect=" .. (onOff(s.steamdirect, "off") and "on" or "off"),
            "pvp=" .. (onOff(s.pvp, "off") and "on" or "off") }
        if c.target then
            lines[#lines + 1] = "peer=" .. c.target
        end
        local path = modDir() .. "net_start.txt"
        writeText(path .. ".tmp", table.concat(lines, "\n") .. "\n")
        os.remove(path)
        if not os.rename(path .. ".tmp", path) then
            setupProblem("Couldn't start the relay: net_start.txt can't be written in " .. modDir())
            return false
        end
        local joining = c.modRole ~= "client" and ""
            or c.target and (", joining " .. c.targetName)
            or ", looking for a Steam friend who's hosting"
        log("Relay started as " .. c.role .. joining .. " over Steam.")
        return true
    end

    local current = nil             -- the connection asked for; .settings are the ones it started with, .on once sync is on

    -- The relay asked for has spoken, if only to say it failed (status.lua tells the player), and not the run before it.
    local function relayReady()
        local line = api.link and api.link.status()
        return line ~= nil and line:find("role=" .. current.modRole .. " ", 1, true) ~= nil
    end

    -- Join Game on a friend in Steam's list, or an invite accepted: join that friend as a guest, whatever this PC was
    -- doing. (Kept as Guest for the next start, like the panel's GUEST; the friend picked isn't kept.)
    local function joinFromSteam(id)
        if type(id) ~= "string" or #id ~= 17 or not id:match("^%d+$") then
            log("Steam asked to join something that isn't a SteamID64: ignored.")
            return
        end
        local name = id
        for _, h in ipairs(hosts()) do
            if h.id == id then
                name = h.name
            end
        end
        local c = connection("guest", id, name)
        if not c or not api.online then
            return
        end
        log("Steam asked to join " .. name .. " (" .. id .. ").")
        api.settings.save({ Role = "Guest" })
        api.online.start(c, api.settings.read())
        setupTip = "Joining " .. name .. " from Steam."
    end

    -- Sync on once the relay has answered and the player is in the world.
    LoopInGameThreadWithDelay(500, function()
        local join = api.link and api.link.steam_join and api.link.steam_join()
        if join then
            pcall(joinFromSteam, join)
        end
        if setupTip then
            pcall(function()
                local _, pawn = getPlayer1()
                if valid(pawn) then
                    api.status.notify("setup", setupTip)
                    setupTip = nil
                end
            end)
        end
        if not current or current.on then
            return false    -- (returning true doesn't end this kind of loop in this UE4SS)
        end
        pcall(function()
            local _, pawn = getPlayer1()
            if valid(pawn) and relayReady() then
                current.on = true
                local s = current.settings
                neton(current.modRole)
                api.partner.goOnLink(current.modRole == "client")
                log("Phantom Pact " .. (current.modRole == "host" and "Host" or "Guest") .. ": co-op on.")
                -- Co-op difficulty and PvP's numbers are fixed (scaling.lua, pvp.lua), the same on every PC.
                if onOff(s.pvp, "off") and api.pvp then
                    api.pvp.set(true)
                end
            end
        end)
        return false
    end)

    -- Everything the online panel does to the connection. Stopping is sync first, then the relay. The start file goes
    -- before the stop: main.dll reads them the other way round, so a Leave can't be lost whenever it lands (run_from).
    local function stopOnline()
        current = nil
        if api.coop.net.enabled then
            api.coop.commands.netoff()
        end
        api.status.last = {}
        os.remove(modDir() .. "net_start.txt")
        if api.link then
            api.link.stop()
        end
    end

    api.online = {
        settings = api.settings.read,
        connection = connection,
        hosts = hosts,
        current = function()
            return current
        end,
        stop = stopOnline,
        start = function(c, s)
            stopOnline()
            c.settings = s
            if startRelay(c, s) then
                current = c
            end
        end,
    }

    api.onlinepanel.start()
    -- Also when not connected: the panel can start co-op later, and F3 only acts once connected.
    api.partner.start()

    local c = connection(role)
    if not c then
        log("Online co-op is off: press F5 in the game to host or join.")
        return
    end
    c.settings = settings
    if startRelay(c, settings) then
        current = c
    end
end

-- How steady an enemy moves on this copy: sudden turns back and forth, jumps in place, small shakes, and how far a guest's
-- copy is from where the host has it, over a stretch of time.
TWITCH = TWITCH or {}
local PBZ, game = PBZ, PBZ.game

local function wrap(a)
    while a > 180 do a = a - 360 end
    while a < -180 do a = a + 360 end
    return a
end

function TWITCH.sample(name, seconds)
    local stop = os.clock() + (seconds or 20)
    local yaw, x, y, turn, step, t
    local n, flips, jumps, maxTurn, maxStep = 0, 0, 0, 0, 0
    local px, py, shakes, sumOff, offN, maxOff, slide, ground = nil, nil, 0, 0, 0, 0, 0, 0
    local function tick()
        local e = PBZ.coop.enemyActor(name)
        local now = os.clock()
        if now > stop or not PBZ.valid(e) then
            print(string.format("[PBZCoop] TWITCH %s: %d samples, %d turns back and forth, %d snaps, %d jumps, %d shakes, %.0f%% of its moving looks like sliding, off the host by %.0f cm on average, %.0f at most\n",
                name:sub(-20), n, flips, TWITCH.snaps or 0, jumps, shakes, ground > 0 and 100 * slide / ground or 0, offN > 0 and sumOff / offN or 0, maxOff))
            TWITCH.snaps = 0
            return
        end
        local r, l = e:K2_GetActorRotation(), e:K2_GetActorLocation()
        if yaw and now > t then
            local dt = now - t
            local d = wrap(r.Yaw - yaw) / dt
            local mx, my = l.X - x, l.Y - y
            local s = math.sqrt(mx * mx + my * my) / dt
            n = n + 1
            if turn and math.abs(d) > 120 and math.abs(turn) > 120 and d * turn < 0 then flips = flips + 1 end
            if math.abs(wrap(r.Yaw - yaw)) > 40 or (turn and math.abs(d) > 120 and math.abs(turn) > 120 and d * turn < 0) then
                if math.abs(wrap(r.Yaw - yaw)) > 40 then TWITCH.snaps = (TWITCH.snaps or 0) + 1 end
                local h = PBZ.net.remoteEnemies and PBZ.net.remoteEnemies[name]
                local m = "-"
                pcall(function()
                    local ai = e.Mesh:GetAnimInstance()
                    local mo = ai:GetCurrentActiveMontage()
                    if PBZ.valid(mo) then m = mo:GetFName():ToString():sub(1, 40) .. string.format(" @%.2f", ai:Montage_GetPosition(mo)) end
                end)
                local c = e.CharacterMovement
                print(string.format("[PBZCoop] SNAP %.2f yaw %.0f to %.0f, host %.0f, step %.0f cm/s, %s orient %s desired %s useYaw %s rate %.0f\n", now % 1000, yaw, r.Yaw, h and h.Yaw or 0, s or 0, m,
                    tostring(c.bOrientRotationToMovement), tostring(c.bUseControllerDesiredRotation), tostring(e.bUseControllerRotationYaw), c.RotationRate.Yaw))
            end
            if step and s > 1500 and step < 300 then jumps = jumps + 1 end
            if px and (mx * px + my * py) < 0 and math.sqrt(mx * mx + my * my) > 4 and math.sqrt(px * px + py * py) > 4 then shakes = shakes + 1 end
            px, py = mx, my
            maxTurn, maxStep = math.max(maxTurn, math.abs(d)), math.max(maxStep, s)
            turn, step = d, s
            -- Moving with no attack playing and the animation not walking: sliding.
            if s > 60 then
                ground = ground + 1
                local ok, walking = pcall(function()
                    local ai = e.Mesh:GetAnimInstance()
                    return PBZ.valid(ai:GetCurrentActiveMontage()) or ai.DisplacementSpeed > s * 0.5
                end)
                if ok and walking == false then slide = slide + 1 end
            end
            local h = PBZ.net.remoteEnemies and PBZ.net.remoteEnemies[name]
            if h and h.X then
                local off = math.sqrt((h.X - l.X) ^ 2 + (h.Y - l.Y) ^ 2)
                sumOff, offN, maxOff = sumOff + off, offN + 1, math.max(maxOff, off)
            end
        end
        yaw, x, y, t = r.Yaw, l.X, l.Y, now
        game.after(0.03, tick)
    end
    tick()
    return "sampling"
end
return "twitch loaded"

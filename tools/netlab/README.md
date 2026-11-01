# Online co-op test bench

Everything here tests the relay and the sync on one PC.

## No game needed

    .\tools\netlab\all.ps1                                    (all of the below; the last line says PASS or FAIL)
    native\build\relay_cli.exe test
    .\tools\netlab\bench.ps1 -Delay 40 -Jitter 20 -Loss 2 -StallEvery 6 -StallMs 250
    .\tools\netlab\restart-test.ps1

`relay_cli test` runs real relays against simulated connections, broken packets and a fuzz loop, then real sockets. `bench.ps1`
runs two bots through a bad connection and prints true delays, since both share the PC's clock. `restart-test.ps1` is separate
processes: restarts, Secrets, an old partner, garbage, the sure lane at 5% and 30% loss. Bots bind to loopback only, so
Windows' firewall doesn't ask anything.

## Real game copies

They run from a separate install, `C:\PBZDev`: junctions to the game's content, its own PBZ.exe, UE4SS, mod and saves. Never
delete that folder recursively: the junction targets are the real game. Remove junctions one at a time with rmdir.

`dev.ps1` has the functions. Copy 1 uses the mod folder, copy 2 its `inst2` subfolder. RETURN is posted to the game's own
window, so nothing takes the focus.

`bench\` holds ready scripts:

| Script | What it does |
|---|---|
| `dev-start.ps1 -Role Host` | Installs this repo's mod and main.dll, starts a copy, waits for gameplay |
| `dev-start.ps1 -Role Guest -Instance 2 -NoInstall` | The second copy |
| `pair-run.ps1 [-WalkOnly] [-FightOnly]` | Walk and fight test on two copies, with a report |
| `combat.ps1`, `shield.ps1` | A real fight; health bars, enemy attacks, ghost distance |
| `together.ps1` | Brings the host beside the guest and walks |
| `badnet.ps1` | The same through `relay_cli netem` |
| `probe.ps1` | One line of state from each copy |
| `weird1.ps1` | Bell rest, sync off and on |
| `fights.ps1 [-From n] [-To n]` | (Skip step 2: it teleports the guest to the world origin.) Boss fights, kills, a death and a revive, with `x.ps1` for single steps and `fights.lua` (`FIGHT.*`) |
| `online-panel.ps1` | The F4 online panel: Host, Join, Leave, a refused Host, swapped roles, with PASS or FAIL per check |

`dev-start.ps1 -Role Host` restarts nothing: stop your old copies first. Only ever stop a process whose path is under
`C:\PBZDev`.

`perf.lua` and `pair.lua` are loaded into a running copy with `eval dofile("<path>")`, and provide `PERF.*` and `PAIR.*`.
`pair_report.py` compares two recordings.

Run the game with `Role = Host`/`Guest` and `ThisPcOnly = On` (dev-start sets it), which binds to loopback.

## Rules that keep tests honest and the game safe

- CONTINUE, never New Game. RETURN on the title screen takes CONTINUE when a save exists.
- UE4SS hot reload (Ctrl+R) crashes the game. A script change needs a restart: about 90 s.
- Don't call methods on an empty UObject from eval: UE4SS crashes. Check with `PBZ.valid` first.
- Never keep a player at Health_Min and teleport: a fall through unloaded ground never ends. Hover in flying mode for 14 s
  before landing somewhere new (`PERF.crowd`).
- `FindAllOf` and other full scans don't belong on a per-frame path. Measure with `PERF.stages`.

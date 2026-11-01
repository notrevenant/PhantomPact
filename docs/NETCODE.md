# Online co-op: how it works now

Protocol 3 (written 2026-11-01). Replaces the file-based relay and the JSON packets of 1.4.1 and earlier. Both players
need this version.

## Why it was rewritten

Measured on a Ryzen 5900X and RTX 4090, 11 enemies around, nobody connected:

| | 1.4.1 | now |
|---|---|---|
| Sync on, in a crowd | 38 FPS | 54-55 FPS, the same as sync off |
| Sync off, same spot, same run | 60 FPS | 52-54 FPS |
| Game-thread time used by the mod | about 300 ms/s | about 45 ms/s |
| Writing a snapshot on exFAT | 5.2 ms a time | no file at all |
| Positions sent per second | 10 (at 60 FPS; the code assumed 20) | up to 60 |

The lag players felt was mostly the mod slowing their own game: `getPlayer1()` cost a full object search about 110 times a
second, a snapshot was written through files on the game thread, and all enemies were read in one frame. The wrong
snapshot rate also doubled the speed used for prediction, which made the ghost overshoot.

Two real copies on one PC, loopback:

| | now |
|---|---|
| Ghost's distance to the real player, walking | 0-2 cm typical, 33 cm at the 95th percentile |
| Same in a moving fight | 19 cm typical, 36 cm at worst |
| Same on a bad link (100 ms ping, 20 ms jitter, 2% loss, 250 ms stall every 7 s) | 1 cm typical, 35 cm at worst, no jumps |
| Host's kill to the guest's copy | 18 ms |
| Guest's killing blow, there and back | 24 ms |
| Enemy position, host's copy against guest's, standing | 0 cm typical |

## The pieces

- `native/relay.hpp`: the relay thread in main.dll, the Mailbox between it and the game thread, the packets.
- `native/lanes.hpp`: the sure lane (arrives, once, in order, resent by acknowledgement) and the quick lane (sent three
  times, played once, dropped if late).
- `native/timeline.hpp`: plays the partner a little in the past, just far enough to stay smooth, following the connection.
- `native/lua_link.hpp`: direct calls from Lua (`api.link`, opened by `openLink` in main.lua). UE4SS doesn't export Lua's C
  API, but it exports its own wrapper class for C++ mods, and that is what's called.
- `mod/PBZCoop/Scripts/coop.lua`: one `tick` every frame. `readPartner`, `steerGhost` and `sendPlayer` run each frame;
  enemies take turns over `ENEMY_ROUND_S`; `watchSlowly` runs ten times a second.

Nothing on the hot path touches a file. `net_start.txt` starts the relay, `pp_stop` ends it (the socket closes, the Mailbox
empties, and another start can follow with another role), and `net_status.txt` is rewritten once a second
for people and tools to read.

## Packets

Little-endian, at most 1100 bytes before signing (`MAX_PACKET`), so a signed packet stays under Tailscale's 1280.

Header: marker 0xA3, protocol 3, flags (1 = from the host), session, the partner's session as we know it, sequence, sender's
time in ms, the partner's time echoed back, how long we held it, sure-lane acknowledgement (next id expected, plus a bitmap
of the 32 after it). Round trip comes from the echo, so no ping packets are needed.

Sections follow: state (40 bytes), sure event, quick event, enemy line, hello (version, map, shared settings).

A session is the sender's clock in ms, always moving on, new per `link.reset()`, so a late packet of an older session can be
told from a new start. A packet's sure and quick sections count only if its "partner's session" is ours.
Seeing a new session from the partner restarts both lanes and hands the mod an `S` event.

## Events

`coop.lua`'s header lists them. `sendEvent` picks the lane: U, M, A and H are quick; the rest are sure.

Enemy lines don't carry names: an `N` event gives each enemy a number first.

## Testing

See `tools/netlab/README.md`. `relay_cli test` is the logic, `tools/netlab/bench.ps1` is two relays through a bad connection,
and `tools/netlab/bench\` drives real game copies from a separate install.

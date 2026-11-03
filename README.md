<p align="center">
  <img src="art/phantom-pact-banner-1300x372.png" alt="Phantom Pact: Online Co-op for Phantom Blade Zero" width="100%">
</p>

# Phantom Pact: online co-op for Phantom Blade Zero

English | [简体中文](README.zh-CN.md)

Phantom Pact adds online co-op to **Phantom Blade Zero**. Two players each run their own game and keep their own
save, and Phantom Pact links the two worlds: you see each other, fight the same enemies, take on bosses as a team,
share loot and dust, and rest at bells together. The host's world leads, and your partner joins in.

**Download:** [latest release](https://github.com/yhsharaf/PhantomPact/releases/latest) · **Install and play:**
[INSTALL.md](INSTALL.md) · **Found a bug?** [Open an issue](https://github.com/yhsharaf/PhantomPact/issues/new/choose)

## Features

- See your partner's Soul live, with their moves, attacks, dodges and hit reactions
- Shared enemies in both worlds, with shared health, posture and executions
- Your partner's hits count in the host's world, so you can fight the same enemy together
- Shared boss fights: the boss health bar and arena fog walls for both players
- Boss fights wait for everyone: die and you watch your partner until it's over; join during one and you watch, then go to them
- Shared loot and dust: what either player picks up or earns goes to both
- Shared resting: sit at a bell and your partner is rested too, and comes to you if they're dead, down or watching a fight
- Elden Ring–style co-op difficulty: enemies and bosses get more health and posture while you play together
- PvP duels (PvP under MORE in the F5 panel): the game's own block, parry and dodge; parries stagger the attacker; the loser dies
- A partner compass in the game's ink style, your partner on the map in jade, partner tips, and spectating your
  partner while you're down
- Connects through Steam Networking: the guest joins a Steam friend who's hosting, with no IP address, VPN or port to
  set up. Steam authenticates and encrypts the connection, and only friends get in
- Everything is set in the game's F5 panel: no settings file to edit
- Local co-op (F5 > MORE > Mode > LOCAL, in testing): two players on one PC in split screen, one pad each or keyboard plus
  pad, with player 2 climbing, opening chests, ringing bells, drinking from the gourd and fighting on their own
  ([docs/LOCAL_COOP.md](docs/LOCAL_COOP.md))
- 4 players (beta): the host turns on 4 PLAYERS under MORE in the F5 panel, and up to three guests can join. Enemies and
  bosses get 50% more health for each person connected ([INSTALL.md](INSTALL.md#4-players-beta))

## Quick start

1. Install [UE4SS for Phantom Blade Zero](https://www.nexusmods.com/phantombladezero/mods/5) (both players). Be Steam friends.
2. Extract the release zip into the game's `PBZ` folder.
3. Start the game, load your save and press **F5**: the host presses HOST, then the guest presses GUEST. The guest joins
   the Steam friend who's hosting, and co-op starts by itself. Your choice is kept for the next start.

Early release, 2 players (4 in beta).

Both players must use the same version. No Python, VPN or port forwarding needed: the connection runs inside the game,
through Steam. Can't connect, or it feels laggy? See Connection problems in [INSTALL.md](INSTALL.md#connection-problems).

For two players on one PC, it's in the same download: press F5 in the game, then MORE > Mode > LOCAL, restart the game and
plug in two pads: see [docs/LOCAL_COOP.md](docs/LOCAL_COOP.md).

## Ground rules

- **No DRM bypassing.** Phantom Pact never touches Denuvo or patches the game executable. Everything loads
  through UE4SS and runs inside the normal, legitimately owned game.
- Each player needs their own copy of the game.
- Nothing here contains game files or assets.

## For developers

| Path | What it is |
|---|---|
| [mod/PBZCoop/](mod/PBZCoop/) | UE4SS Lua mod: `coop.lua` (online sync), `pbz.lua` (game adapter: enemies, health, moves, bosses, items), `localcoop.lua` (split screen: player 2's controls, interactions, enemies), `panel.lua` (local co-op F4 panel), `onlinepanel.lua` (online F5 panel: host, join, leave, settings), `settings.lua` (what the panels keep in `settings.txt`), `autostart.lua` (reads those settings, starts the relay, turns sync on), `main.lua` (loader, commands) |
| [native/](native/) | The relay: C++, loaded by UE4SS as `dlls\main.dll` inside the game, connecting through Steam Networking (`steam.cpp`). Build with `tools\build-native.ps1` (Visual Studio 2022). `native\build\relay_cli.exe test` runs its tests over a loopback link of its own; `relay_cli.exe` is never shipped |
| [tools/netlab/](tools/netlab/) | Online co-op test bench: relay tests through a bad connection, and real game copies from a separate install ([README](tools/netlab/README.md)) |
| [tools/install-mod.ps1](tools/install-mod.ps1) | Installs the mod into the game's UE4SS `Mods` folder (finds the game through Steam) |
| [tools/pbz-e2e.ps1](tools/pbz-e2e.ps1) | End-to-end test, PASS/FAIL per feature. Each copy's settings.txt starts its relay, as for players. Connecting needs two PCs with two Steam accounts |
| [tools/pbz-selftest.ps1](tools/pbz-selftest.ps1) | Starts two copies with `-allowmultipleinstances`, each with a settings.txt for its role; `-Stop` |
| [tools/make-release.ps1](tools/make-release.ps1) | Builds `dist\PhantomPact-<version>.zip` |
| [docs/NETCODE.md](docs/NETCODE.md) | How online co-op works now: protocol 3, packets, the sure and quick lanes, measurements, testing |
| [docs/AUTHORITY.md](docs/AUTHORITY.md) | Which PC decides what, how duplicates are prevented, who may talk to the relay |
| [docs/COOP_GUIDE.md](docs/COOP_GUIDE.md) | What syncs and how: enemy matching, tests and results |
| [docs/RECON_NOTES.md](docs/RECON_NOTES.md) | Classes, functions and data tables found in the game |
| [docs/LOCAL_COOP.md](docs/LOCAL_COOP.md) | Local co-op: setup, player 2's controls, what the game hardwires to player 1 and how the mod bridges it |
| [tools/localcoop/](tools/localcoop/) | Local co-op test tools: launcher, command runner, Lua probes for enemies and fight areas, soak |

## Credits

- **[appdoze](https://github.com/appdoze)**, for the relay security review and code: packet signing, sender
  filtering, event value checks, faster sending, the settings handshake, in-game status tips, the partner on the map, enemies gliding back on the guest, and smoother partner
  movement
- **[EXACG](https://github.com/EXACG)**, for the four-player design and code (PR #11): the host passing players on to
  each other, a ghost, a compass dot and a map pointer for each partner, tips for each partner, enemy health that grows
  with each player, the `units` check on the real game, and the check that every event has one handler
- **Vercadi**, for UE4SS for Phantom Blade Zero, which made modding this game possible
- **The UE4SS team** ([RE-UE4SS](https://github.com/UE4SS-RE/RE-UE4SS))
- **S-GAME and the game's developers** for Phantom Blade Zero

*Fan-made mod, not affiliated with or endorsed by S-GAME.*

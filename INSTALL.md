# Phantom Pact 1.4.2: online co-op for Phantom Blade Zero

Play the campaign with a friend: you see each other as a second Soul, fight the same enemies and bosses, and
share loot, dust and bell rests. The host's world decides enemies, bosses and deaths; the guest's world follows.

Fan-made, unofficial. Each player needs their own copy of the game on Steam. No game files are modified or shared.

**Found a bug?** Post in the Bugs tab on Nexus Mods or open an issue at
https://github.com/yhsharaf/PhantomPact/issues. [What to send](#what-to-send-in-a-bug-report) is at the end of this
guide.

**Two players on one PC?** Set `Role = Local` instead of Host or Guest, plug in two pads, and read
`docs/LOCAL_COOP.md` (in the GitHub repository) for player 2's controls. It is in testing.

## What you need (both players)

1. **Phantom Blade Zero** on Steam.
2. **UE4SS for Phantom Blade Zero** by Vercadi (Nexus Mods), installed in `PBZ\platform\steam`.
3. **Tailscale** (tailscale.com), both signed in to the same network.

You don't need Python: the connection runs inside the game (`PBZCoop\dlls\main.dll`). Its source is in the GitHub
repository (`native/`).

**Both players must use the same version.** 1.4.2 has a new connection, and 1.4.1 or older can't connect to it.

## Install (both players)

1. Open the game folder: Steam > right-click the game > Manage > Browse local files.
2. Extract everything in the zip into that folder (the `PBZ` folder) and say yes to merging folders.
   The mod lands in `platform\steam\ue4ss\Mods\PBZCoop`.
3. Open `platform\steam\ue4ss\Mods\PBZCoop\PhantomPact.ini` in Notepad:
   - **Host:** change `Role = Guest` to `Role = Host`
   - **Guest:** set `HostAddress` to the host's Tailscale IP (it starts with 100.; the host sees it in the
     Tailscale app)
4. Start the game and load your saves, the host first. Co-op starts by itself once you're in the world.
   The first time you host, Windows asks whether the game may use the network: click **Allow**. That window can open
   behind the game, so Alt+Tab if the guest can't connect.

The UE4SS console shows `Phantom Pact Host: co-op on` (or Guest), and
`ue4ss\Mods\PBZCoop\net_status.txt` shows `connected=yes` once you're linked.

**Or try the online panel (in testing):** set `OnlinePanel = On` in `PhantomPact.ini`. In the game, F4 then opens a panel
where you pick Tailscale or Steam, then Host, Join or Leave, with no restart. It shows whether you're connected and your
ping, and it saves your choice in `PhantomPact.ini` (Leave saves `Role = Off`). Joining over Tailscale still needs the
host's address in `HostAddress`; you can add it while the game runs. With `Role = Local`, F4 is the local co-op panel
instead.

- **Updating:** both players update. Extract the new version over the old one, then set `Role` / `HostAddress` again.
  What an older version left in the `PBZCoop` folder (the `relay` folder, and `net_in.txt`, `net_out.txt` and the
  `net_events` files) isn't used any more; you can delete it.
- **Playing alone:** set `Role = Off`.
- **Uninstalling:** delete the `platform\steam\ue4ss\Mods\PBZCoop` folder.

## Other ways to connect

- **Hamachi, Radmin, ZeroTier, UU Accelerator's multiplayer:** any virtual LAN works. The guest puts the host's
  address from that app in `HostAddress` (leave `Connect = Tailscale`: it just means "connect by IP"). If the app
  hands out unusual addresses (UU, ZeroTier), the host also sets `AllowAnyAddress = On`.
- **Steam:** both set `Connect = Steam`; the guest joins a Steam friend who's hosting. No Tailscale needed. You must be
  Steam friends. The guest leaves `HostAddress` empty or puts the host's Steam name; an IP address there is ignored.
  `SteamDirect = Off` (the default) leaves it to Steam's own setting, which normally means Valve's relays: your IP stays
  hidden, with more delay. `On` tries for a direct connection, the quickest, and your partner's PC can then see your IP
  address. A direct connection needs `On` on both PCs.
- **Secret (optional):** the same password in `Secret =` on both PCs signs every packet, so nobody else on the
  network can join. Recommended with `AllowAnyAddress = On`.

## On screen

- **Partner compass:** a silver seal on a line at the top shows which way your partner is. Turn it off with
  `PartnerCompass = Off`.
- **Map:** your partner is a jade copy of your own map marker, turned the way they face, when you're in the same
  area (red while they're down). Turn it off with `PartnerMapIcon = Off`.
- **Tips:** short messages when your partner connects, drops, goes down or wanders far off, and when something is in
  the way: no answer from the host, a refused `Secret`, different versions or settings, a high ping.
- **When you die:** after a few seconds the camera follows your partner until you respawn.

## Co-op difficulty

Like Elden Ring, enemies and bosses get tougher while your partner is with you: 150% health and 130% posture by
default. Change `CoopEnemyHealth` / `CoopEnemyPosture` in `PhantomPact.ini` (percent; 100 = normal). Both
players should use the same numbers.

## PvP (duels)

Both players set `PvP = On` in `PhantomPact.ini`. Your partner becomes an opponent you can fight:

- Their attacks hit you through the game's own combat: **block** (hold the guard button) costs posture,
  a well-timed **parry** (tap guard just before the hit) costs nothing, and dodges work as usual.
- A parry is rewarded like against a boss: the attacker staggers and loses posture (`PvPParryPosture`, default 60).
- The loser dies for real and respawns at their bell, as after any death. A kill by your partner is scored
  in the UE4SS console (`PvP: VICTORY. Your blade was faster. The pact holds. Score 1 - 0.`); dying to an
  enemy doesn't count.
  (In the prologue area the game won't let you die, so duel there for fun and the score still counts.)
- Both players fight with the same strength (your partner's ghost uses your stats), so skill decides.
  `PvPDamage` scales the damage you take (100 = normal).

Not in PvP yet: executions (posture break only staggers).

## Good to know

- Enemies are one fight: the host's game runs them, and the guest sees and fights the same ones. Their attacks work as
  usual on both PCs, so block, parry and dodge do too.
- Boss fights: when one of you starts a boss, the other is brought into the arena. Stay close when you're about to start
  one: far from the host, enemies that aren't loaded on the host's PC fight on their own on the guest's.
- If your partner disappears, they are down, in a cutscene, on another map or disconnected; they come back.
- If the guest dies during a boss fight, the host's fight goes on; the host's win counts for both.
- Not shared yet: cutscenes, dialogue, spending dust, quests and story progress.
- Never press Ctrl+R (UE4SS hot reload) while playing together: it can crash the game. Restart the game instead.

## Troubleshooting

- **No "co-op on" line:** check `PhantomPact.ini` (Role, and HostAddress for the guest). The UE4SS log says what's
  missing.
- **"dlls\main.dll isn't running":** your antivirus may have removed it. Extract the zip again and allow the file,
  then restart the game. Online co-op can't run without it.
- **`relay_error.txt` in the mod folder, or the tip "co-op couldn't start":** the connection couldn't start, and the
  message says why (for example, the port is in use). Post it with your bug report.
- **`connected=no`, or it feels laggy:** see Connection problems below.
- **No `[PBZCoop] Loaded` line at all:** UE4SS isn't installed in `PBZ\platform\steam`, or the mod folder isn't at
  `platform\steam\ue4ss\Mods\PBZCoop`.

## Connection problems

`ue4ss\Mods\PBZCoop\net_status.txt` is rewritten once a second while you play. It's one long line; open it in Notepad,
and open it again to see new numbers. The parts that help:

| Part | What it tells you |
|---|---|
| `connected` | `yes` if your partner was heard in the last 3 seconds |
| `peer` | Your partner's address. On the host, `-` means nothing has arrived from the guest yet |
| `via` | How you connect: `udp` (by IP, over Tailscale or another virtual LAN) or `steam` |
| `route` | Steam only: `direct`, or `relay` through Valve's servers. `-` over IP: see Direct or relayed below |
| `rtt_ms` | Ping, there and back, in ms. The game warns you if it stays above 250 |
| `route_ping_ms` | Steam only: Steam's own ping for that route |
| `jitter_ms` | How late packets arrive compared with the fastest lately, in ms. High jitter with a low ping usually means Wi-Fi |
| `delay_ms` | How far in the past your partner is shown so they move smoothly, in ms. It follows jitter, up to about 220 |
| `loss_pct` | Packets lost in the last second, in percent |
| `partner_version` | Your partner's version. `1.4.1-or-older` or `other-protocol` means one of you must update |
| `mismatch` | Settings that differ between you (`-` = none) |
| `filtered` | Packets refused because of their address. Going up on the host: see `AllowAnyAddress` above |
| `rejected` | Packets refused by `Secret`. Going up: the two `Secret` values differ, or the PCs' clocks are more than 2 minutes apart |
| `stopped` | `yes` when the connection isn't running: you pressed Leave, or it failed and `error` says why |

For scale: the test bench stayed smooth at 100 ms ping, 20 ms jitter and 2% loss. That was two copies on one PC with a
simulated bad connection, not a real one.

**`connected=no`.** Go through these in order:

1. Both on Tailscale, in the same network? The host's IP in the guest's `HostAddress`?
2. The guest runs `tailscale ping 100.x.y.z` in PowerShell, with the host's IP. No reply means Tailscale itself isn't
   connecting the two PCs: fix that first.
3. A reply, but still `connected=no`: Windows Firewall on the host is the likely cause, because `tailscale ping`
   doesn't pass through it. See below.

**Windows Firewall.** The connection is part of the game, so the firewall asks about the game (`PBZ.exe`), not Python.
It asks the first time the game opens the port, so on the host's PC, and the window can open behind the game. Click
Allow, with Private networks ticked (Tailscale counts as private; if your virtual LAN shows as Public in Windows, tick
that too). If you clicked Cancel, open Windows Security > Firewall & network protection > Allow an app through
firewall > Change settings, and tick PBZ. If it isn't in the list, use Allow another app and pick
`platform\steam\PBZ.exe` in the game folder.

**Direct or relayed.** Over Steam, `route` shows it: if it stays `relay`, check `SteamDirect = On` on both PCs, and that
your routers allow a direct connection. Over Tailscale `route` stays `-`, so ask `tailscale ping 100.x.y.z`:

- `pong from ... via 203.0.113.5:41641 in 12ms`: direct, the best case. The command stops by itself once it gets one.
- `pong from ... via DERP(fra) in 80ms`: relayed through a Tailscale server. The first few replies are often like this
  while Tailscale looks for a direct path.
- It ends with `direct connection not established`: you stay relayed, which means a higher ping and more jitter. Turn
  off other VPNs on both PCs, and turn on UPnP on the router, or forward UDP port 41641 (Tailscale's own, not the
  game's) to one of the PCs. A phone hotspot or a provider that shares one address between customers can stop a direct
  path from ever working. If nothing helps, try another virtual LAN.

**Wi-Fi or cable.** Wi-Fi is the usual cause of jitter, loss and short freezes. If `jitter_ms` jumps around or
`loss_pct` isn't 0, plug in a cable, on both PCs if you can, and compare. Stop big downloads and streams on the same
connection too.

## What to send in a bug report

From both players if you can, right after it happens and before you restart the game or reconnect, since these files
start over:

- `ue4ss\UE4SS.log`
- `ue4ss\Mods\PBZCoop\net_status.txt` and `relay_log.txt`, plus `relay_error.txt` if it's there
- What `tailscale ping` prints, if you use Tailscale
- Host or guest, which area or boss, what happened, and Wi-Fi or cable

`net_status.txt` and `relay_log.txt` show your partner's address. Your `Secret` is only in `PhantomPact.ini`: don't post
that file with the `Secret` in it.

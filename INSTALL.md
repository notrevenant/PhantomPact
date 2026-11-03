# Phantom Pact 1.5.1: online co-op for Phantom Blade Zero

Play the campaign with a friend: you see each other as a second Soul, fight the same enemies and bosses, and
share loot, dust and bell rests. The host's world decides enemies, bosses and deaths; the guest's world follows.

Fan-made, unofficial. Each player needs their own copy of the game on Steam. No game files are modified or shared.

**Found a bug?** Post in the Bugs tab on Nexus Mods or open an issue at
https://github.com/yhsharaf/PhantomPact/issues. [What to send](#what-to-send-in-a-bug-report) is at the end of this
guide.

**Two players on one PC?** It's in this same download: in the game press F5, then MORE, set Mode to LOCAL and restart
the game. Plug in two pads, and read `Phantom Pact - LOCAL CO-OP.md`, next to this guide, for player 2's controls and how to
set up pads. It is in testing. (F4 > MULTIPLAYER goes back, from the next start.)

## What you need (both players)

1. **Phantom Blade Zero** on Steam.
2. **UE4SS for Phantom Blade Zero** by Vercadi (Nexus Mods), installed in `PBZ\platform\steam`.
3. **Steam friends:** the host and the guest must be friends on Steam.

That's all. Phantom Pact connects through Steam Networking, inside the game (`PBZCoop\dlls\main.dll`, source in the
GitHub repository's `native/`): no IP address to type, no VPN, no port to open and no Python.

**Both players must use the same version.**

## Install (both players)

1. Open the game folder: Steam > right-click the game > Manage > Browse local files.
2. Extract everything in the zip into that folder (the `PBZ` folder) and say yes to merging folders.
   The mod lands in `platform\steam\ue4ss\Mods\PBZCoop`.
3. Start the game and load your save.
4. Press **F5** for the online panel. The host presses **HOST**, then the guest presses **GUEST**. The guest joins
   whichever Steam friend is hosting Phantom Pact. Co-op starts by itself once you're both in the world.

**Picking a friend, invites and Join Game.**

- **Pick who to join:** before pressing GUEST, click the **Steam** card. Each click goes to the next friend who's hosting,
  then back to any friend; the status box says who. GUEST then joins only that friend.
- **From Steam's friends list:** while you host, your friends see **Join Game** on you in Steam, and you can right-click a
  friend and use **Invite to Game**. When a friend clicks Join Game, or accepts your invite, their game switches to guest
  and joins you, even if they were hosting or alone.
- If their game isn't running yet, Steam starts it. Whether it then joins by itself depends on the game's launcher passing
  Steam's request on; if it doesn't, they press GUEST once in.

There's no file to edit: everything is set in the panel. Your choices are kept for the next start (the mod saves them in
`settings.txt` in the mod folder), so after the first time co-op starts again by itself as Host or Guest. **LEAVE**
goes back to playing alone, and stays that way next time.

The UE4SS console shows `Phantom Pact Host: co-op on` (or Guest), and
`ue4ss\Mods\PBZCoop\net_status.txt` shows `connected=yes` once you're linked.

**The panel.** English and 中文 at the top switch the language of the panel and the co-op messages. The status box says
what's going on: waiting for a partner, looking for a friend who's hosting, or connected with the ping and whether Steam
connects you directly or through its relays.

**MORE** opens the settings: TP > PARTNER, PvP, the partner compass, your partner on the map, Steam Direct and 4 PLAYERS
(Beta), each ON or OFF, and Mode: MULTIPLAYER, or LOCAL for two players on this PC. Mode works from the next time you start the
game. Revive is coming soon. Enemy difficulty is the game's own setting. With a partner, enemies always get extra health and
posture on top of it.

**Steam Direct.** OFF (the default) leaves it to Steam's own setting (Steam > Settings > In Game > Steam Networking), which
normally means Valve's relays: your IP stays hidden, with a little more delay. ON tries for a direct connection, the
quickest, and your partner's PC can then see your IP address. A direct connection needs ON on both PCs, and works from the
next connection.

**Going to your partner.** Joining takes you to the host once, even on another map, so a friend with a new save can
join a host further into the story. Your save stays where you land, so your own story can get ahead of where you were.
After that, **F3** takes you to your partner if you turn TP > PARTNER on under MORE. It's off by default, because it's a
lot of power to have on one key. Neither works during a boss fight, a cutscene, a duel or a menu, or while you or your
partner are down.

### 4 players (Beta)

4 PLAYERS under MORE is off by default, and with it off nothing changes. Turn it on before you press Host, and up to three
guests can join: four players in all. Only the host's switch counts: guests follow it, whatever theirs says. It works from the
next Host. Everyone joins as they would with two players, must be Steam friends with the host, and needs the same version.
It hasn't been played by four people yet: tell us what breaks.

With more than two players:

- Each player has a number and a colour, the same on every PC, on the compass and the map and in the tips: the host is purple,
  player 2 green, player 3 gold, player 4 blue. Red still means down. The panel says how many are connected and who you are.
- F3 goes to the nearest partner who's up. If nobody's on your map, a guest goes to the host.
- Enemies get more health and posture for each person connected: see [Co-op difficulty](#co-op-difficulty).
- Die in a boss fight and you wait until the boss dies or everyone else is down too. The camera moves to someone who's still up.
- What anyone gets, everyone gets, and if two of you are given the same thing at once it counts once.
- If a guest drops out the others play on. If the host leaves, it's over for everyone.
- Enemies are shared near the host, and near a guest up to 120 m from the host. Further off the host's game leaves them
  asleep, so each guest out there fights a copy of their own, and the first kill counts for everyone.
- PvP and Revive stay off.
- The host sends about 50-100 KB/s with three guests, so a slow upload will show.

- **Updating:** both players update. Extract the new version over the old one. An older version's `PhantomPact.ini` isn't
  read any more, so pick your settings again in the F5 panel; you can delete that file. What even older versions left in
  the `PBZCoop` folder (the `relay` folder, and `net_in.txt`, `net_out.txt` and the `net_events` files) isn't used either.
- **Playing alone:** press LEAVE in the F5 panel.
- **Uninstalling:** delete the `platform\steam\ue4ss\Mods\PBZCoop` folder.

## On screen

- **Partner compass:** a silver seal on a line at the top shows which way your partner is. Turn it off under MORE.
- **Map:** your partner is a jade copy of your own map marker, turned the way they face, when you're in the same
  area (red while they're down). Turn it off under MORE.
- **Tips:** short messages when your partner connects, drops, goes down or wanders far off, and when something is in
  the way: no friend hosting found, different versions or settings, a high ping, Steam relaying the connection.
- **When you die:** after a few seconds the camera follows your partner until you respawn.

## Co-op difficulty

Like Elden Ring, enemies and bosses get tougher while your partner is with you: 150% health and 130% posture, the same
on every PC.

With 4 PLAYERS (Beta) on, each person connected adds the same again, wherever they are, on another map, loading or down: 200%
and 160% with two connected, 250% and 190% with three. It only goes up, so a boss doesn't lose health when someone dies or
leaves. Someone who joins during a boss fight only watches, so that boss keeps its number until the fight is over, while other
enemies rise at once.

## PvP (duels)

Both players turn PvP ON under MORE in the F5 panel. Your partner becomes an opponent you can fight:

- Their attacks hit you through the game's own combat: **block** (hold the guard button) costs posture,
  a well-timed **parry** (tap guard just before the hit) costs nothing, and dodges work as usual.
- A parry is rewarded like against a boss: the attacker staggers and loses 60 posture.
- The loser dies for real and respawns at their bell, as after any death. A kill by your partner is scored
  in the UE4SS console (`PvP: VICTORY. Your blade was faster. The pact holds. Score 1 - 0.`); dying to an
  enemy doesn't count.
  (In the prologue area the game won't let you die, so duel there for fun and the score still counts.)
- Both players fight with the same strength (your partner's ghost uses your stats), so skill decides.

Not in PvP yet: executions (posture break only staggers).

## Good to know

- Enemies are one fight: the host's game runs them, and the guest sees and fights the same ones. Their attacks work as
  usual on both PCs, so block, parry and dodge do too.
- Boss fights: when one of you starts a boss, the other is brought into the arena. Stay close when you're about to start
  one: far from the host, enemies that aren't loaded on the host's PC fight on their own on the guest's.
- If your partner disappears, they are down, in a cutscene, on another map or disconnected; they come back.
- With both of you in a fight, an enemy stays on one of you for about 15 seconds, then turns on the other if they've been
  hitting it.
- If one of you dies during a boss fight, they watch the other until it's over, and respawn when the boss dies or the
  other dies too.
- If you join while the host is in a boss fight, you watch it, and go to them when it's over. From another map you only
  get a message, and go across at the end.
- Not shared yet: cutscenes, dialogue, spending dust, quests and story progress.
- Never press Ctrl+R (UE4SS hot reload) while playing together: it can crash the game. Restart the game instead.

## Troubleshooting

- **No "co-op on" line:** press F5 and check that the host pressed HOST and the guest GUEST. The UE4SS log says what's
  missing.
- **"dlls\main.dll isn't running":** your antivirus may have removed it. Extract the zip again and allow the file,
  then restart the game. Online co-op can't run without it.
- **`relay_error.txt` in the mod folder, or the tip "co-op couldn't start":** the connection couldn't start, and the
  message says why (for example, Steam isn't running or isn't logged in). Post it with your bug report.
- **`connected=no`, or it feels laggy:** see Connection problems below.
- **No `[PBZCoop] Loaded` line at all:** UE4SS isn't installed in `PBZ\platform\steam`, or the mod folder isn't at
  `platform\steam\ue4ss\Mods\PBZCoop`.

## Connection problems

`ue4ss\Mods\PBZCoop\net_status.txt` is rewritten once a second while you play. It's one long line; open it in Notepad,
and open it again to see new numbers. The parts that help:

| Part | What it tells you |
|---|---|
| `connected` | `yes` if your partner was heard in the last 3 seconds |
| `peer` | Your partner's Steam name. On the host, `-` means nothing has arrived from the guest yet |
| `via` | Always `steam` |
| `route` | `direct`, or `relay` through Valve's servers |
| `rtt_ms` | Ping, there and back, in ms. The game warns you if it stays above 250 |
| `route_ping_ms` | Steam's own ping for that route |
| `link_problem` | Steam's reason the last try ended, its number and its words, `-` if none |
| `jitter_ms` | How late packets arrive compared with the fastest lately, in ms. High jitter with a low ping usually means Wi-Fi |
| `delay_ms` | How far in the past your partner is shown so they move smoothly, in ms. It follows jitter, up to about 220 |
| `loss_pct` | Packets lost in the last second, in percent |
| `partner_version` | Your partner's version. `1.4.1-or-older` or `other-protocol` means one of you must update |
| `mismatch` | Settings that differ between you (`-` = none) |
| `refused` | Sends Steam turned down. Going up while `connected=no`: Steam couldn't reach your partner |
| `stopped` | `yes` when the connection isn't running: you pressed Leave, or it failed and `error` says why |

For scale: the test bench stayed smooth at 100 ms ping, 20 ms jitter and 2% loss. That was a simulated bad connection on
one PC, not a real one.

**`connected=no`.** Go through these in order:

1. Are you friends on Steam? Both of you need Steam running and logged in.
2. Did the host press HOST, and the guest GUEST? Two Hosts, or two Guests, never find each other.
3. Is the host Invisible in Steam? The guest only finds a friend who shows as playing the game: the host sets their
   status to Online. Several friends hosting at once? Click the Steam card in F5 to pick one.
4. The same Phantom Pact version on both PCs?
5. The tip "Steam couldn't connect" gives Steam's own reason (also `link_problem` in `net_status.txt`): post it with your
   bug report.

**Direct or relayed.** `route` shows it. If it stays `relay`, turn Steam Direct ON under MORE on both PCs, and check that
your routers allow a direct connection (UPnP on). A phone hotspot or a provider that shares one address between customers
can stop a direct path from ever working; the relays still work, with more delay.

**Wi-Fi or cable.** Wi-Fi is the usual cause of jitter, loss and short freezes. If `jitter_ms` jumps around or
`loss_pct` isn't 0, plug in a cable, on both PCs if you can, and compare. Stop big downloads and streams on the same
connection too.

## What to send in a bug report

From both players if you can, right after it happens and before you restart the game or reconnect, since these files
start over:

- `ue4ss\UE4SS.log`
- `ue4ss\Mods\PBZCoop\net_status.txt` and `relay_log.txt`, plus `relay_error.txt` if it's there
- Host or guest, which area or boss, what happened, and Wi-Fi or cable

`net_status.txt` and `relay_log.txt` show your partner's Steam name.

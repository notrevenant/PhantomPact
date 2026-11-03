# Changelog draft: Phantom Pact 1.5.0

Not posted. For the user to edit and post, on GitHub and Nexus.

## Next version: Steam only, no ini

- Phantom Pact now connects only through Steam: the guest joins a Steam friend who's hosting. No IP address, Tailscale,
  VPN, port or firewall prompt. Both players must update, and must be Steam friends
- No more PhantomPact.ini: everything is set in the F5 panel, which keeps your choices for the next start. An old ini
  isn't read: pick your settings again in F5, and delete the file if you like
- Gone with them: Tailscale, Other network, Paste address and the optional password. Steam already checks who's who and
  encrypts the connection, and only friends can join
- Co-op difficulty (150% health, 130% posture) and the PvP numbers are now the same fixed values on every PC
- Join from Steam: while you host, friends see Join Game on you in their Steam friends list, and you can send Invite to
  Game. Accepting takes them straight to you
- Several friends hosting? Click the Steam card in F5 to pick which one GUEST joins

## To post

- New connection, built into the game. Both players must update
- F5 opens the online panel, on by default: pick Steam, Tailscale or another network, then Host or Guest, with no text file and no restart. Joining takes you to the host, even on another map. It speaks English and Chinese, pastes the address and an optional password, and MORE holds PvP and the other options
- Most of the lag came from the mod slowing your own game, and that's gone: with 11 enemies around, sync used to take a
  60 FPS game down to 38. Now it costs nothing we can measure (54-55 FPS with sync on, 52-54 off)
- Your partner's position updates up to 60 times a second, up from 10, and stays within about 35 cm of where they
  really are, even on a bad connection (100 ms ping, 2% loss)
- A kill shows on the other PC about 20 ms after it happens, plus your ping
- If the host restarts, or goes to the title screen and back, enemies respawn for both players, as at a bell, so nobody
  fights enemies the other can't see
- Steam can now connect directly, for less delay: set `SteamDirect = On` on both PCs. Your partner can then see your IP
  address, so it's off by default
- The game now says what's wrong when you can't connect, `net_status.txt` shows ping, jitter and packet loss, and
  INSTALL.md has a Connection problems section
- Local co-op on one PC (split screen, in testing): set `Role = Local`, see docs/LOCAL_COOP.md
- New: TP > PARTNER under MORE (off by default): F3 takes you to your partner, even on another map
- New: everything is shared: whatever one player gets from a chest, a pile or the ground, the other gets too, at any distance, and it can't pay twice. What you buy or make stays yours
- New: die in a boss fight and you watch your partner until it's over: you respawn when the boss dies or your partner dies too
- New: join while the host is in a boss fight and you watch it, then go to them when it's over
- The game no longer pauses with a partner linked, in the F5 panel or the game's own menu: enemies keep coming
- New: with both players in a fight, an enemy stays on one of you for a while, then turns on the other if they've been hitting it
- New (beta): 4 PLAYERS under MORE in the F5 panel. Turn it on as host and up to three guests can join. Each player has a colour on the compass and the map, enemies and bosses get 50% more health for each person connected, and what anyone gets, everyone gets. It's off by default, and with it off nothing changes. PvP and Revive stay off with more than two. Design and first code by EXACG, thank you
- New: Mode under MORE in the F5 panel: pick LOCAL for split screen on one PC instead of editing a file, then restart the game. MULTIPLAYER in the F4 panel goes back
- Fixed: bosses' attacks on the guest looked like hits but did no damage
- Fixed: enemies went on attacking a partner who had left or gone down
- Fixed: enemies could lose huge chunks of health, or die, from hits nobody made, when a guest arrived or rejoined
- Fixed: enemies twitched and slid on the guest's screen, and some of their moves, like a boss's scream, didn't show
- Fixed: a fight against a group of enemies could freeze the game for good when a player died
- Fixed: enemies ignored a partner more than about 150 m from the host
- Fixed: a crash when you changed map within a second of your partner taking a hit
- Fixed: enemies did different attacks on each player's screen, because the guest's copies woke up and fought on their own
- Fixed: some enemies skipped the co-op health boost after a map change, and the guest's copy could show the wrong maximum health

Numbers measured with two copies of the game on one PC (Ryzen 5900X, RTX 4090), including a simulated bad connection.

Install: extract the zip into your Phantom Blade Zero folder (both players), see INSTALL.md. Both players must update:
1.4.1 and older can't connect to 1.5.0.

## Before posting (not for players)

- No session between two real PCs on this connection yet. If that's still true when this goes out, say so in the post.
- The 60 to 38 FPS line is from a run whose baseline was 60; the new run's baseline was 52-54. That's why both numbers
  are given: "38 to 55" alone would overstate it.
- Local co-op ships in the same zip as online, off unless `Role = Local`.
- 4 PLAYERS is a beta: say so in the post.

# Changelog draft: Phantom Pact 1.4.2

Not posted. For the user to edit and post, on GitHub and Nexus.

## To post

- New connection, built into the game. Both players must update
- In testing: with `OnlinePanel = On`, F4 opens an online panel: Host, Join and Leave in the game, with no restart
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

Numbers measured with two copies of the game on one PC (Ryzen 5900X, RTX 4090), including a simulated bad connection.

Install: extract the zip into your Phantom Blade Zero folder (both players), see INSTALL.md. Both players must update:
1.4.1 and older can't connect to 1.4.2.

## Before posting (not for players)

- No session between two real PCs on this connection yet. If that's still true when this goes out, say so in the post.
- The 60 to 38 FPS line is from a run whose baseline was 60; the new run's baseline was 52-54. That's why both numbers
  are given: "38 to 55" alone would overstate it.
- The local co-op line is here because 1.4.2 hasn't been released yet. Cut it if it ships separately.

# Nexus Mods page: Phantom Pact

Sections as in the Nexus form.

## Name and summary

Phantom Pact - Online Co-op

Online co-op for Phantom Blade Zero. Play with a friend online, each in your own game and save: see each other fight, take on shared enemies and bosses together, share loot and dust, and rest at bells together. 2 players, connected over Tailscale or another virtual LAN.

## Description

Phantom Pact adds online co-op to Phantom Blade Zero. Two players each run their own game and keep their own save, and Phantom Pact links the two worlds: you see each other, fight the same enemies, take on bosses as a team, share loot and dust, and rest at bells together. The host’s world leads, and the friend joins in.

## Installation instructions

Install UE4SS for Phantom Blade Zero (see Requirements): put dwmapi.dll and the ue4ss folder in the game’s PBZ\platform\steam folder. To find it: Steam > right-click the game > Manage > Browse local files, then open platform\steam.
Extract everything in the zip into the game’s PBZ folder and say yes to merging folders. The mod lands in platform\steam\ue4ss\Mods\PBZCoop.
Open platform\steam\ue4ss\Mods\PBZCoop\PhantomPact.ini in Notepad. Host: change Role = Guest to Role = Host. Friend: set HostAddress to the host’s Tailscale IP (it starts with 100. and is shown in the host’s Tailscale app).
Start the game and load your saves, the host first. Co-op starts by itself once you’re in the world. The first time you host, Windows asks whether the game may use the network: click Allow.
F5 opens a panel in the game, in English or Chinese: pick Steam, Tailscale or another network, then Host or Guest, with no text file and no restart. Paste the address and an optional password from the clipboard. Joining takes you to the host, even on another map. MORE holds the options, and TP > PARTNER there puts going to your partner on F3.

Updating: both players update. Extract the new version over the old one, then set Role and HostAddress again.
Playing alone: set Role = Off.
To uninstall: delete the platform\steam\ue4ss\Mods\PBZCoop folder.

## Main features

See your partner’s Soul live, with their moves, attacks, dodges and hit reactions
Shared enemies: the same enemies in both worlds, with shared health, posture and executions
Your partner’s hits land in the host’s world, so you can fight the same enemy together
Shared boss fights: boss health bar and arena fog walls for both players
Boss fights wait for everyone: die and you watch your partner until it's over; join during one and you watch, then go to them
Shared loot: when your partner picks up an item, opens a chest or searches a pile, you get it too
Shared dust: dust earned by either player goes to both
Shared resting: rest at a bell and enemies respawn for both
Your partner disappears while they’re down or on another map, and comes back when they return

Local co-op (split screen, in testing): two players on one PC, one pad each or keyboard plus pad. Set Role = Local.
Player 2 climbs, opens chests, rings bells, drinks from the gourd and fights on their own; enemies notice and fight a
lone player 2; menus and the game's screens are shared; bosses get a health bar on player 2's half. F4 in the game
opens the panel for screen layout and pads. It's in the same download: see Phantom Pact - LOCAL CO-OP.md in the zip.

## Requirements

Phantom Blade Zero on Steam, for both players
UE4SS for Phantom Blade Zero 1.0.1 by Vercadi (Nexus Mods), for both players
To connect: both use Tailscale (tailscale.com), signed in to the same network, or another virtual LAN
Both players on the same Phantom Pact version: 1.4.1 or older can’t connect to 1.5.0
No Python needed: the connection runs inside the game

Early release, 2 players. The host leads into new areas and boss arenas. Cutscenes, dialogue and spending dust aren’t shared yet. Don’t press Ctrl+R (UE4SS hot reload) while playing together; restart the game instead.
Can’t connect, or it feels laggy? The install guide in the zip has a Connection problems section.
Please report bugs in the Bugs tab with your ue4ss\UE4SS.log, ue4ss\Mods\PBZCoop\net_status.txt and ue4ss\Mods\PBZCoop\relay_log.txt.

## Shout outs

Vercadi, for UE4SS for Phantom Blade Zero, which made modding this game possible
The UE4SS team, for RE-UE4SS
S-GAME and the game’s developers, for Phantom Blade Zero
Everyone testing this first release

Fan-made mod, not affiliated with or endorsed by S-GAME.

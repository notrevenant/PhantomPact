// Steam's friends features around the link (steam.cpp): joining from Steam's friends list, invites, and which friends are
// hosting. Hosting sets this player's rich presence "connect" key, so Steam shows "Join Game" on them and offers "Invite to
// Game". A friend who accepts either one gets a join request here, which the mod reads (lua_link.hpp, pp_steam_join).
// Everything here is optional: a Steam without these calls still connects, through the friends list alone.
#pragma once
#include <cstdint>
#include <string>

namespace steam_social {

// Once, when main.dll starts: waits for Steam in the background, then listens for join requests. A game started by Steam
// for a join ("+pp_join <id>" on the command line) counts as one.
void start();

// The SteamID64 of the friend whose game the player asked to join, as digits, once; empty if none is waiting.
std::string take_join();

// Friends hosting Phantom Pact right now, one "<SteamID64>\t<name>" a line.
std::string hosts();

// Whether this friend is hosting Phantom Pact, as their rich presence says. False if Steam can't tell.
bool is_hosting(uint64_t friend_id);

// The host's relay: on while it runs, and again now and then in case the game clears its rich presence.
void set_hosting(bool on);

}  // namespace steam_social

# Player Avatars / Identity Tags

## 1. Goal

Give every player a small, persistent visual identity — an emoji or a color, chosen once
— so they're recognizable at a glance across the players list, role reveal, the LAN
identity picker, the voting grid, and stats, instead of being pure text. No photos, no
uploads, no account system — this stays in the same "local, instant, zero-setup" spirit
as the rest of the app.

## 2. Why

Two independent pressures point at the same fix:

- **The voting grid gets harder to scan as player count grows**, and this session's LAN
  work makes larger, multi-device games more common than they used to be (up to
  double-digit players is now realistic when guests join their own phones instead of
  passing one device around). `VotingScreen` currently renders players as a grid of
  text-labeled squares — fine at 4–5 players, noticeably harder to scan at 8–10.
- **Genre precedent is consistent and specific.** Nearly every successful party game in
  this space — Jackbox's player-color system, Among Us's colored/hatted crewmates,
  Codenames apps' team-colored name tags — solves "which one is Alex again" the same way:
  a persistent, glanceable visual tag that doesn't require reading. That convention exists
  because it works, not because it's decorative.
- It also gives the LAN identity picker (`waiting_room_screen.dart`, the browser client's
  picker screen) a way to show *which* connected device picked which name at a glance on
  the host's device list, beyond the current plain-text `selectedPlayerName` display.

## 3. Scope Decision: Emoji + Color, Not Photos

Deliberately avoid camera/gallery access and image storage — that's a meaningfully larger
scope (permissions, storage, moderation-adjacent concerns for a party game with kids
potentially playing) for a feature whose actual job is "fast disambiguation," which an
emoji + color pair does just as well as a photo. Recommended: each player gets an emoji
(from a curated set of ~30–40 faces/animals, or free emoji entry) plus an auto-assigned
or user-picked accent color from a small fixed palette (reuse Material's tonal palette
approach already used elsewhere in the app via `ColorScheme.fromSeed`).

## 4. Data Model

Player identity currently lives as a bare `List<String>` of names
(`PlayersState.players`, `PlayerRepository`) — there's no `Player` class at all. Adding
avatars is the natural forcing function to introduce one:

```dart
class PlayerProfile {
  final String name;
  final String emoji;      // e.g. '🦊'
  final int colorValue;    // Color.value, one of a fixed palette
}
```

- `PlayerRepository` needs to store `List<PlayerProfile>` (as JSON, same pattern as
  `game_history_repository`) instead of `List<String>`. This is the single largest
  mechanical change in this feature — every place that currently treats a player as a
  bare `String` (role assignment, voting, stats, LAN sync, the browser client's JSON
  protocol) needs to either accept a `PlayerProfile` or keep using `.name` as the
  canonical identity key while looking up the emoji/color for display only.
- **Keep the name as the sole identity key everywhere it matters for correctness** —
  `RoleAssignment.playerName`, streak computation (`core/streaks.dart`), LAN
  `selectedPlayerName` — so this feature stays additive and doesn't risk breaking
  anything that already keys off player name as a plain string. Treat `PlayerProfile` as
  a display-layer lookup (`name -> emoji/color`), not a replacement identity type,
  everywhere except the players list itself.
- Auto-assign a color on player creation (cycle through the palette by player index) so
  there's no mandatory extra tap — customization is optional, the default is instant.

## 5. UI Changes by Screen

- **`players_screen.dart`**: each `_PlayerTile` gets a leading avatar (emoji in a colored
  circle) instead of the current numbered `CircleAvatar`; tapping it opens a small emoji +
  color picker (a `showModalBottomSheet` grid, nothing fancier needed).
- **`role_reveal_screen.dart` / `distributed_reveal_screen.dart`**: show the current
  player's avatar large and centered above their name in the hidden state — reinforces
  "this phone is for you" during pass-and-play handoff.
- **`voting_screen.dart`**: replace or augment the text-only player squares with
  avatar + name, which is the main payoff of this feature — this is the screen that gets
  hardest to scan at high player counts.
- **`end_screen.dart` / `stats_screen.dart`**: small avatar next to each player name in
  the impostor/innocent breakdown and the player stats leaderboard.
- **LAN identity picker** (`waiting_room_screen.dart`, browser `app.js` picker screen):
  show each player's avatar on their picker chip — makes "who am I" and "who's already
  taken" both easier to eyeball, especially on the browser client where players are often
  glancing at a phone handed to them rather than one they've used all night.
- **Host device list** (`host_lobby_screen.dart` `_DeviceListCard`): show the claimed
  player's avatar next to each connected device, not just the name string.

## 6. LAN / Browser Client Sync

`PlayerProfile`'s emoji/color needs to travel with the player roster in
`lobbyStateSync` (`lan_message.dart`'s `players` payload is currently `List<String>` —
extend to `List<Map<String, dynamic>>` with `name`/`emoji`/`colorValue`, or add a
parallel `playerProfiles` field to avoid a breaking protocol change for anything still
expecting the old shape). Update:
- `LanSessionState.players` type and every place that reads it
  (`lan_session_notifier.dart`, `host_lobby_screen.dart`'s themes/settings cards which
  don't need this but the player list card does).
- `assets/web_client/app.js`'s `renderPicker()` to render the emoji next to each name —
  this is the browser client's one required change, a small JS/CSS addition (an emoji
  renders fine as plain Unicode text in the chip, no new asset needed).

## 7. Implementation Plan

### Phase A: Data model + local-only UI
`PlayerProfile`, updated `PlayerRepository`, avatar picker on `players_screen.dart`,
avatar display on role reveal and voting (single-device flow only, no LAN changes yet).

### Phase B: Stats & end screen
Avatar display on `end_screen.dart` and `stats_screen.dart`.

### Phase C: LAN sync
Protocol extension, `host_lobby_screen.dart` device list, `waiting_room_screen.dart`
picker, browser client picker — in that order, native before browser, so the protocol
shape is validated against a real client before writing the JS side.

## 8. Acceptance Criteria

- Every player has an emoji + color, auto-assigned by default, editable from the players
  screen.
- Avatars appear consistently across reveal, voting, end screen, and stats.
- LAN and browser guests see avatars in the identity picker once Phase C ships.
- Role assignment, streak computation, and win-rate stats are unaffected — they still key
  off player name exactly as before.
- A player with an emoji that doesn't render on some system font (rare, but emoji support
  varies) degrades to just their initial or name — never a broken glyph or crash.

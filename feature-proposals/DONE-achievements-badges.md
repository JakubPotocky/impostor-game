# Achievements & Badges

## 1. Goal

A persistent, unlockable badge system built entirely on data the app already collects —
game history and win streaks — that gives players a reason to open the app between game
nights and a reason to keep using a consistent player name (which also happens to make
LAN identity-claiming and streak tracking more reliable, since both already key off exact
name matches).

## 2. Why

`GameHistoryRepository` already stores every game ever played, with full detail —
winner names, impostor names, killed names, mode, timestamp. `core/streaks.dart` already
computes current/best streak per player from that history. This is precisely the raw
material achievement systems are built from, and right now it's used for exactly one
thing: a small 🔥 badge shown transiently on the waiting-room and reveal screens. That's
a lot of collected data for a small, ephemeral payoff. Unlockable achievements are one of
the cheapest, most reliable retention mechanics in casual and party games specifically
because they don't require new gameplay mechanics — they require noticing patterns in
data that already exists and giving the player a reason to come back and check.

## 3. Badge Catalog (Starting Set)

Keep the first set small and clearly computable from existing `GameRecord` fields —
resist the urge to invent new tracked stats before shipping the loop once:

| Badge | Condition | Data source |
|---|---|---|
| First Blood | Win your first game | `getGames()` length for player |
| Impostor Initiate | Win a game as impostor | `impostorNames` + `winnerNames` |
| Master of Disguise | Win 5 games as impostor | same, counted |
| Hot Streak | Reach a 3-game win streak | `computePlayerStreaks` (already built) |
| Unstoppable | Reach a 10-game win streak | same |
| Detective | Correctly vote out the impostor 10 times | `killedNames` intersected with `impostorNames`, attributed to... see note below |
| Survivor | Finish a game without being eliminated, 10 times | `killedNames` absence |
| Blank Stare | Play through a Blank Round | `mode`/blank-round flag in the record — confirm `GameRecord` currently captures this; if not, add a `isBlankRound` field |
| Party Starter | Host 5 LAN lobbies | needs a new counter — see §5 |
| Century Club | Play 100 games total | `getGames().length` |

**Note on "Detective":** the current `GameRecord` doesn't attribute *who* cast which
elimination vote, only which players were killed and in what order (`killedIndices` at
capture time, `killedNames` in the record) — there's no per-voter attribution at all
today, since voting is a single shared device tapping eliminations. Either drop
vote-attributed badges from the v1 catalog (recommended — keeps this feature purely
additive with zero changes to `voting_screen.dart`) or scope attributing votes to
specific players as a separate, smaller follow-up once [live voting sync for LAN
guests](lan-live-voting-sync.md) exists and votes are meaningfully individual again.

## 4. Data Model

New repository, `achievement_repository.dart`, same Hive-JSON pattern as everything else
in `lib/data/`:

```dart
class UnlockedAchievement {
  final String badgeId;
  final String playerName;
  final DateTime unlockedAt;
}
```

Store unlocks keyed by player name (matching how streaks already work) so the same
player's progress is tracked consistently across solo and LAN games.

## 5. Detection

Two triggers, both cheap:

- **On every `GameHistoryRepository.addGame()` call** (already the single choke point
  every game result passes through — `end_screen.dart._saveHistory()`), re-evaluate the
  badge catalog against the full updated history for every player in that game's roster,
  and persist any newly-crossed thresholds via `AchievementRepository`. This means
  achievements are recomputed from source-of-truth history rather than incrementally
  tracked — simpler, self-healing if history is ever edited or imported (see [Local
  Backup & Restore](feature-roadmap.md#3-local-backup--restore)), and cheap enough given
  realistic history sizes (hundreds of games, not millions).
- **"Party Starter"** (lobby-hosting count) needs its own counter since it's not derivable
  from `GameRecord` — increment a simple counter in `LanSessionNotifier.createLobby()`
  or track it in `SettingsRepository`/a dedicated small box.

## 6. UI

- New **Achievements** screen, reachable from Home alongside Stats and Word Analytics —
  grid of badges, locked ones shown grayed-out/silhouetted with their unlock condition as
  a caption, unlocked ones in full color with the unlock date.
- **Unlock celebration**: when `end_screen.dart` saves history and a new achievement
  unlocks as a result, show a small toast/snackbar or a lightweight animated banner
  ("🏆 Achievement Unlocked: Hot Streak!") on the end screen itself — reuse the existing
  `_hotStreakMessage` pattern already in `end_screen.dart` as the template, since it's
  solving an almost identical "surface a computed-after-the-fact fact" problem.
- Per-player badge count could optionally surface as a small chip next to their name in
  `stats_screen.dart`'s Player Stats tab, next to existing win-rate data.

## 7. Implementation Plan

### Phase A: Data + detection
`AchievementRepository`, badge catalog as a plain Dart list of predicate functions over
`List<GameRecord>`, wired into `end_screen.dart._saveHistory()`.

### Phase B: Achievements screen
Grid UI, Home screen entry point.

### Phase C: Unlock celebration
End-screen toast/banner on new unlock.

### Phase D (optional): Party Starter + hosting-count badges
Only after Phase A–C are solid — this is the one badge needing a new counter outside
existing history data.

## 8. Acceptance Criteria

- Achievements are computed correctly from existing game history without requiring
  players to have been tracked from day one — importing/replaying old history (see
  backup/restore) retroactively unlocks anything already earned.
- No achievement can be unlocked twice or double-counted.
- The achievements screen loads and renders correctly with zero games played (all badges
  locked, no crash on empty history).
- Unlock detection runs in under a frame's worth of time for realistic history sizes —
  don't block the end-screen save flow noticeably.

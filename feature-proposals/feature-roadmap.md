# Feature Roadmap — What Players Would Want Next

## 1. How This List Was Built

This is a gap analysis, not a customer survey — the app has no analytics, no published
store listing, and no user feedback channel (confirmed: no crash reporting, no analytics
SDK, no in-app rating prompt). So every item below is reasoned from two sources instead:

1. **What's already built**, so nothing here duplicates existing work. Current state in
   one paragraph: a fully-featured local pass-and-play social deduction game (Normal +
   Team modes, blank rounds, sudden death, hints, theme visibility control, 6 languages,
   custom themes with JSON import/export, word like/dislike voting, game history, win
   streaks, dark/light theme, onboarding, changelog, rules) plus, as of this session, a
   genuinely strong LAN multiplayer layer (mDNS + WebSocket, host-authoritative,
   claim-based distributed reveal, browser join via QR with zero install, a mid-session
   "Check Players" readiness gate, and the ability to return to the lobby to change
   settings or add players without ending the session).
2. **Genre convention and concrete gaps found while auditing the codebase.** Where a gap
   is specific and checkable (e.g. "zero `Semantics` widgets anywhere in `lib/`"), that's
   stated plainly rather than guessed at.

Every feature below states its reasoning explicitly — treat that reasoning as the thing
to sanity-check before building, not the instructions.

## 2. The List

| # | Feature | Size | Why (one line) |
|---|---------|------|-----------------|
| 1 | ✅ DONE — [Local Backup & Restore](#3-local-backup--restore) | Small | Local-only Hive storage means one reinstall silently deletes every stat, streak, and custom theme. |
| 2 | ✅ DONE — [Word-Vote-Informed Word Weighting](#4-word-vote-informed-word-weighting) | Small | The app already collects like/dislike data and explicitly does nothing with it yet. |
| 3 | ✅ DONE — [Sound & Haptics Toggle](#5-sound--haptics-toggle) | Small | Feedback is always-on with no mute, and reveals happen in living rooms and quiet houses. |
| 4 | ✅ DONE — [Quick Polish: Tutorial Replay + App Name Fix](#6-quick-polish-tutorial-replay--app-name-fix) | Tiny | A complete onboarding flow has no way back in; the app's home-screen label is "Impostor~". |
| 5 | ✅ DONE — [Round Setting Presets](#7-round-setting-presets) | Small–Medium | Hosts who run the same game night repeatedly reconfigure identical settings every time. |
| 6 | [Theme Pack Sharing via QR](#8-theme-pack-sharing-via-qr) | Small–Medium | Custom themes already export as JSON, but there's no easy channel to move it between phones. |
| 7 | [Accessibility Pass](#feature-proposalsaccessibility-passmd) | Large | Zero screen-reader support found anywhere; red/green role coloring excludes colorblind players. |
| 8 | [Player Avatars / Identity Tags](#feature-proposalsplayer-avatarsmd) | Medium–Large | Name-only chips get error-prone once LAN games regularly run 6–10+ players across devices. |
| 9 | ✅ DONE — [Achievements & Badges](#feature-proposalsachievements-badgesmd) | Large | Full game history + streaks already exist as raw material; there's no persistent payoff for playing more. |
| 10 | [Live Voting & Elimination Sync for LAN Guests](#feature-proposalslan-live-voting-syncmd) | Large | Guests currently see nothing after their own reveal — voting still forces everyone to crowd the host's phone. |
| 11 | [LAN Host Migration](#feature-proposalslan-host-migrationmd) | Large | If the host's phone dies mid-game, every connected guest — native and browser — loses the session with no recovery. |
| 12 | [Remote Play (Not on the Same Network)](#feature-proposalsremote-play-relaymd) | Very Large | The single most-requested feature for any local-multiplayer party game, but it conflicts with the project's own "no backend" principle — presented with that tradeoff explicit. |

Suggested build order if picking a handful: **1, 2, 4** cost almost nothing and remove
real annoyances immediately. **7 (Accessibility)** is the one item on this list that's an
exclusion, not an inconvenience, and arguably deserves priority over everything else.
**10 (Live Voting Sync)** is the highest-leverage next step specifically because it
completes the promise the LAN work already made this session. **12 (Remote Play)** should
be a deliberate yes/no decision, not a default — read its tradeoffs before scheduling it.

---

## 3. Local Backup & Restore

### Why
Every repository in `lib/data/` (`player_repository`, `custom_theme_repository`,
`game_history_repository`, `settings_repository`, `word_vote_repository`) is backed by a
local Hive box with **no cloud or account sync anywhere in the app**. A phone upgrade, an
accidental "clear app data," or an uninstall wipes every custom theme, every game record,
every win streak — silently, with no warning and no recovery path. That's a direct threat
to the two features (`stats_screen.dart`, streaks) explicitly built to reward long-term
play. This is table stakes for any app with meaningful local state, and the custom-theme
screen already proves the team knows how to do import/export — this just extends that
pattern to everything.

### What to build
A single **"Backup & Restore"** section in `SettingsScreen`:
- **Export All Data**: serialize every repository's exportable state into one JSON
  envelope — `{ version, exportedAt, players, customThemes, gameHistory, settings,
  wordVotes }` — using each repository's own get-methods (`getPlayers()`,
  `getCustomThemesJson()` or equivalent, `getGames()`, all the `settings_repository`
  getters, `getVotes()`). Write it to a file via `path_provider` and hand it off with
  `share_plus` (new dependency) so the user can save it to Drive/email/Files — mirroring
  how custom-theme export already goes to the clipboard, just for a bigger payload that
  won't comfortably fit a clipboard paste.
- **Import All Data**: use `file_picker` (new dependency) to select a previously exported
  file, validate its `version` field, and replay it back into each repository via their
  existing save methods. Show a confirmation dialog first ("This replaces your current
  history and themes — continue?") since it's destructive to existing local state.
- Optional stretch: wire Android's native **Auto Backup for Apps** (already free, just
  needs `android:allowBackup="true"` — check current value in `AndroidManifest.xml` — and
  a `data_extraction_rules.xml` including the Hive box files) so most users never have to
  think about this at all; keep the manual export as the cross-device / "share with a
  friend's setup" path regardless.

### Acceptance criteria
- Export produces one shareable file containing every repository's data.
- Import restores it fully on a fresh install and matches the original state.
- Import is guarded by a destructive-action confirmation.
- Existing custom-theme JSON export/import continues to work unchanged (don't fold it
  into this — it serves a different purpose: sharing one theme, not backing up everything).

---

## 4. Word-Vote-Informed Word Weighting

### Why
`lib/data/word_vote_repository.dart` line 14 says it outright: *"This data is collected
for future analytics — no gameplay effect for now."* The like/dislike UI on `EndScreen`
and the `WordAnalyticsScreen` that visualizes it are both fully built — the only missing
piece is closing the loop so the votes actually change what happens in the next game.
Every group that plays a few sessions will start noticing the same weak/confusing words
keep coming back into rotation. This is finishing a feature that's already 80% done, not
starting a new one.

### What to build
`WordPickerService.pickWordIndex()` (`lib/core/word_picker_service.dart`) currently picks
uniformly at random from the not-yet-used pool for a theme. Change the selection to a
weighted pick:
- Inject a `Map<String, WordVote>` (from `WordVoteRepository.getVotes()`) into the picker
  at call time — `HostLobbyScreen._startGame()`, `PreGameScreen._startGame()`,
  `EndScreen._quickRematch()` all already have the theme/word context; thread the vote
  map through the same way `random` is already threaded through for testability.
- Compute a weight per candidate word: something simple and explainable, e.g.
  `weight = 1.0 + likes * 0.15 - dislikes * 0.25`, floored at a small positive minimum
  (never fully exclude a word — a word with two dislikes from one grumpy group shouldn't
  vanish for everyone; this is a nudge, not a ban).
- Words with no votes yet (the common case, especially right after this ships) get the
  baseline weight of `1.0`, so behavior is unchanged until votes accumulate.
- Keep the existing no-repeat-until-exhausted behavior — weighting only affects which
  word is picked *within* the still-available pool for that round, not whether repeats
  happen.

### Acceptance criteria
- A word with several dislikes and no likes appears less often than average across many
  simulated rounds (this is exactly the kind of thing `test/word_picker_test.dart`
  already covers the shape of — add a weighted-selection test following the same pattern).
- A freshly custom-created theme with zero votes behaves identically to today.
- No word is ever fully excluded regardless of vote count.

---

## 5. Sound & Haptics Toggle

### Why
`FeedbackService` (`lib/core/feedback_service.dart`) fires haptics and system sounds on
every reveal, kill, and victory, unconditionally — there's a Reduced Motion toggle in
Settings but nothing for sound/haptics. Party games get played in shared living rooms
after kids are asleep, in dorms, in break rooms — a heavy double-buzz on "you are the
impostor" is exactly the kind of thing that's delightful at a loud party and disruptive
everywhere else. This is a small, well-precedented addition (`reducedMotion` already
established the pattern of a settings-driven bool threaded through gameplay screens as a
constructor field, not read live via Riverpod inside those screens — several of them,
like `RoleRevealScreen`, aren't `Consumer` widgets at all).

### What to build
- Add `soundEnabled` and `hapticsEnabled` (default both `true`) to `GameSetupState`,
  `GameSetupNotifier` (`setSoundEnabled`/`setHapticsEnabled`, persisted via two new keys
  in `SettingsRepository`, same pattern as `reducedMotion`).
- Add two `Switch` rows to `SettingsScreen`, next to the existing Reduced Motion toggle.
- Thread both flags into `RoleRevealScreen`, `VotingScreen`, `EndScreen`,
  `DistributedRevealScreen` as constructor fields (mirroring `reducedMotion` exactly —
  same call sites already pass `reducedMotion: setup.reducedMotion`, add
  `soundEnabled`/`hapticsEnabled` right beside it).
- Update `FeedbackService`'s methods to accept the flags (or have each call site
  early-return before invoking `_feedback.xxx()` when disabled — whichever reads cleaner
  at each call site; `RoleRevealScreen._revealRole()` etc. already gate similar
  conditional behavior inline).

### Acceptance criteria
- Both toggles persist across app restarts.
- With both off, a full round (reveal → vote → end) produces no haptic or sound calls.
- Reduced Motion continues to be independent of these — a user can want silence but keep
  animations, or vice versa.

---

## 6. Quick Polish: Tutorial Replay + App Name Fix

### Why
Two unrelated one-line-effort fixes, bundled because neither deserves its own document:

- **Tutorial replay.** `OnboardingScreen` (5 pages: Welcome, Setup, Role Reveal,
  Discussion, Voting & Winning) is fully built and gated by `hasSeenTutorial` in
  `SettingsRepository` — but there is **no button anywhere in the app that shows it
  again**. A host trying to explain the game to a new friend, or a returning player who
  forgot how sudden death works, currently has no path back to a screen that already
  exists and already explains exactly that.
- **App display name.** `AndroidManifest.xml`'s app label is `"Impostor~"` — a stray
  trailing tilde sitting on every user's home screen and app drawer. Almost certainly an
  unintentional leftover from editing.

### What to build
- Add a "Replay Tutorial" list item to `SettingsScreen` (or a button on `RulesScreen`,
  either works) that pushes `OnboardingScreen` directly — it already accepts an
  `onComplete` callback, so route that to `Navigator.pop`.
- Fix the `android:label` value in `android/app/src/main/AndroidManifest.xml` from
  `"Impostor~"` to `"Impostor"`.

### Acceptance criteria
- Tutorial is reachable from Settings without reinstalling the app.
- Home screen / app drawer / recent-apps label reads exactly "Impostor".

---

## 7. Round Setting Presets

### Why
This session added a full "Round Settings" card (language, impostor count, timer, hints,
theme visibility, sudden death) directly to `HostLobbyScreen` specifically so hosts don't
need to leave the lobby to configure a round. The next friction point is obvious: a host
who runs the same weekly game night with the same group re-taps the same five settings
every single time, because `SettingsRepository` only remembers a single "current" state,
not named configurations. Presets are a small, self-contained addition on top of
infrastructure that already exists.

### What to build
- New Hive box (`SettingsPresetRepository` or a table inside the existing
  `SettingsRepository`) storing a list of named presets — each one a snapshot of the same
  fields already in `GameSetupState` plus `selectedThemes`.
- **"Save as Preset"** button next to the Round Settings / Themes cards on
  `HostLobbyScreen` (and optionally `PreGameScreen`) — prompts for a name, snapshots
  current `GameSetupState`.
- **"Load Preset"** — a dropdown/chip row showing saved presets; tapping one applies all
  its fields via the existing `GameSetupNotifier` setters in sequence.
- Simple delete affordance per preset (long-press or a trailing icon), following the
  existing custom-theme delete-confirmation pattern.

### Acceptance criteria
- Saving and reloading a preset reproduces every setting exactly, including theme
  selection.
- Presets persist across app restarts and across LAN sessions.
- Deleting a preset never affects the currently-active (unsaved) settings.

---

## 8. Theme Pack Sharing via QR

### Why
`ThemeExportScreen` already turns a custom theme into a JSON blob on the clipboard — but
getting that blob from one phone to another still requires a side channel (texting it,
emailing it) that's clunky mid-party. This session built exactly the missing piece for a
different feature: a static-page-over-local-HTTP + QR code pattern
(`assets/web_client/`, `qr_flutter`, `NetworkInfoService`) that turns "type or paste this
long string" into "scan this." Reusing it here is a natural, low-effort extension rather
than new infrastructure.

### What to build
- On `ThemeExportScreen`, add a **"Share via QR"** option alongside the existing
  clipboard export.
- Simplest version (no networking needed): if the JSON is small enough, encode it
  directly as the QR payload (`qr_flutter` supports arbitrary text; most custom theme
  JSON — 15ish words — comfortably fits a QR code's capacity) and add a matching
  **"Scan to Import"** entry point (needs a QR *scanner*, e.g. `mobile_scanner` — new
  dependency, note this is the one new capability this feature needs that the LAN work
  didn't already build) on `ThemeExportScreen`'s import side.
- If a future custom theme grows too large for a single QR code (many words, many
  languages), fall back to the same local-HTTP-serve approach as the LAN browser client:
  briefly host the JSON at `http://<ip>:<port>/theme.json` and QR-encode *that* URL
  instead of the data itself.

### Acceptance criteria
- A custom theme can be transferred from one phone to another via QR scan with zero
  typing and no shared network requirement beyond both phones' cameras (the direct-QR
  path needs no network at all).
- Existing clipboard export/import is unchanged and still works.
- Malformed/foreign QR payloads are rejected with a clear error, not a crash.

---

## 9. Larger Features (Dedicated Documents)

The following are substantial enough to warrant their own implementation document, in
this same folder:

- **[accessibility-pass.md](accessibility-pass.md)** — screen reader support, colorblind-safe
  role indicators, font scaling.
- **[player-avatars.md](player-avatars.md)** — emoji/color identity tags across every
  player-facing screen, including the LAN identity picker and browser client.
- **[achievements-badges.md](achievements-badges.md)** — unlockable badges built on top of
  existing game history and streak data.
- **[lan-live-voting-sync.md](lan-live-voting-sync.md)** — broadcast voting/elimination
  results to connected LAN and browser guests in real time.
- **[lan-host-migration.md](lan-host-migration.md)** — let a connected device take over
  hosting if the original host disconnects.
- **[remote-play-relay.md](remote-play-relay.md)** — play with people not on the same
  network, with the backend-cost tradeoff made explicit.

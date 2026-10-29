# Accessibility Pass — Screen Readers, Colorblind Safety, Text Scaling

## 1. Goal

Make the core game loop (add players → reveal role → discuss → vote → see results)
usable by players who rely on a screen reader, players with color vision deficiency, and
players who run their phone at a larger system font size. Today, none of these are
supported: a repo-wide search for `Semantics`, `semanticLabel`, `ExcludeSemantics`, and
`MediaQuery.textScale` across `lib/` returns zero matches.

## 2. Why This Matters More Than It Looks

Two different severities are bundled in this one document, deliberately:

- **Screen reader support is not a polish item — it's a hard exclusion.** A TalkBack user
  (the target platform is Android) cannot currently operate this app's core loop at all.
  Buttons, cards, and the tap-to-reveal flow have no semantic labels beyond whatever
  incidental text happens to be in a `Text` widget, and several key interactions (the
  reveal card, the voting grid) are built from `Container`/`GestureDetector`-style custom
  widgets that expose nothing to assistive tech by default.
- **Colorblind-safe indicators are lower severity but wider reach.** Red-for-impostor,
  green-for-innocent is used throughout `RoleRevealScreen`, `DistributedRevealScreen`,
  `VotingScreen`, `EndScreen`, and `StatsScreen`. Red-green color vision deficiency
  affects roughly 8% of men and 0.5% of women — in a 6-player game, the odds that *no one*
  at the table is affected are worse than most people assume.
- **Text scaling** is the cheapest of the three and mostly a matter of not fighting
  Flutter's default behavior (removing any hardcoded font sizes that would clip, and not
  wrapping the app in anything that disables `MediaQuery` text scaling).

## 3. Screen Reader Support

### Approach
Don't do a blanket automated pass — prioritize the actual gameplay path, since that's
where silence is worst:

- **Role reveal** (`role_reveal_screen.dart`, `distributed_reveal_screen.dart`,
  `assets/web_client/` for the browser client): the hidden state needs an announcement
  like *"Tap to reveal your role, playing as [name]"*; the revealed state needs the result
  spoken clearly — *"You are the impostor"* or *"The word is: [word]"* — via `Semantics`
  wrapping the icon+text combination (currently just visual: icon + `ShimmerText`/`Text`).
  Use `Semantics(label: ..., child: ...)` around each state's content, and
  `liveRegion: true` on the container that swaps between hidden/revealed so a screen
  reader announces the change without the user needing to swipe to it again.
- **Voting grid** (`voting_screen.dart`): each player square needs a semantic label
  stating the player's name and current state ("Alex, active" / "Sam, eliminated,
  was an impostor" once revealed) — `Semantics(label: ..., button: true, child: ...)`
  per tile.
- **Buttons and icon-only controls**: every `IconButton` without a visible label (exit
  game, copy link, delete player, theme filter chips) needs a `tooltip` at minimum (many
  already have one — audit and fill gaps) since `tooltip` doubles as the accessibility
  label for `IconButton` specifically; bespoke tap targets (`InkWell`-wrapped containers
  like the LAN identity picker chips) need explicit `Semantics`.
- **End screen result** (`end_screen.dart`): the win/loss announcement and secret word
  reveal should be wrapped so a screen reader reads the outcome immediately on screen
  entry, not just visually via `ShimmerText`.
- **Browser client** (`assets/web_client/index.html`/`app.js`): add `aria-live="polite"`
  to the screen container so a screen reader announces screen transitions, and
  `aria-label`s on the reveal button and chip picker — this is regular web accessibility,
  not Flutter-specific, and arguably the easier half of this document.

### What NOT to do
Don't wrap every single decorative element in `Semantics` — over-announcing (reading out
every `SizedBox`, every decorative icon) is its own accessibility failure, making the app
exhausting to navigate by screen reader even though technically "labeled." Use
`ExcludeSemantics` on purely decorative animated effects (`ConfettiBurst`, `GlowRing`,
`ShakeEffect` in `core/animated_effects.dart`) so they don't intrude on the announcement
of the content they're decorating.

## 4. Colorblind-Safe Role Indicators

Red/green is already paired with **distinct icons** in several places
(`Icons.warning_amber_rounded` for impostor vs `Icons.check_circle_rounded` for innocent
in `role_reveal_screen.dart`; `Icons.close_rounded` vs `Icons.check_circle_outline` for
eliminated vs alive in `end_screen.dart`) — audit every red/green usage across
`role_reveal_screen.dart`, `distributed_reveal_screen.dart`, `voting_screen.dart`,
`end_screen.dart`, and `stats_screen.dart` and make sure the icon pairing is consistent
everywhere, not just some places. Where color is the *only* signal (e.g. plain colored
text with no accompanying icon or label), add one. This is cheap once audited — the icon
vocabulary already exists in the app, it just needs to be applied uniformly rather than
introducing a new one.

Consider adding a **"Colorblind Mode"** toggle in Settings (alongside Reduced Motion) that
swaps the red/green palette for a blue/orange pair — a safer combination for the most
common forms of color vision deficiency — for users who want the color signal itself to
be more reliable rather than relying solely on icon redundancy.

## 5. Text Scaling

- Audit for hardcoded pixel heights that would clip text at 150–200% system font scale —
  particularly the fixed-height buttons (`height: 56` appears throughout
  `host_lobby_screen.dart`, `role_reveal_screen.dart`, etc.) and fixed-size icon+text rows
  in cards. Prefer `Wrap`/flexible layouts or explicit `minHeight` over hard `height`
  where feasible, or verify visually at 200% scale that nothing clips.
- Don't wrap `MaterialApp` in anything that overrides `textScaler` to a fixed value —
  confirm `main.dart` doesn't do this (it currently doesn't).
- Test the reveal card and voting grid specifically at large scale, since those have the
  densest text-in-limited-space layouts.

## 6. Implementation Plan

### Phase A: Screen reader — gameplay critical path
Role reveal (native + `DistributedRevealScreen` + browser client), voting grid, end
screen result announcement.

### Phase B: Screen reader — everything else
Settings, Host Lobby, LAN join flows, Stats, Rules — lower urgency since they're
secondary to actually playing a round, but still currently silent.

### Phase C: Colorblind-safe indicators
Icon-pairing audit + optional Colorblind Mode toggle.

### Phase D: Text scaling
Layout audit at 150%/200% system scale.

## 7. Testing

- Manually test the full round loop with TalkBack enabled on a real Android device —
  this cannot be adequately verified by reading code.
- Use Flutter's `flutter_test` `Semantics` matchers (`meetsGuideline`,
  `textContrastGuideline`, `androidTapTargetGuideline`) in a widget test for at least the
  reveal and voting screens, so regressions are caught in CI rather than only by manual
  audit.
- Verify with a colorblind simulation filter (Android's built-in accessibility color
  correction, or a browser devtools filter for the web client) that role state is still
  distinguishable.

## 8. Acceptance Criteria

- A TalkBack user can complete a full round — add players, reveal their role, vote, see
  the result — without sighted assistance.
- No gameplay-critical information is conveyed by color alone anywhere in the app.
- The app renders without clipping or overlap at 200% system text scale on the reveal and
  voting screens.
- Existing Reduced Motion behavior is unaffected by this work (it's a related but
  separate axis of accessibility, already implemented).

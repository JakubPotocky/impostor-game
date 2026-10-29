# Live Voting & Elimination Sync for LAN Guests

## 1. Goal

Once a LAN round's reveals are done, every connected guest — native app or browser —
currently sees nothing more. Voting and the end-of-round result only exist on the host's
`VotingScreen`/`EndScreen`. Broadcast live voting state to every connected device so
guests can watch eliminations happen and see the final result on their own phone, without
needing to crowd around the host's screen — completing the promise the rest of this
session's LAN work already made ("everyone gets their own phone").

## 2. Why

This is the most natural and highest-leverage next step on top of what's already built,
for a specific reason: every other piece of the LAN experience (join, pick identity,
reveal, "Check Players" readiness) already happens on the guest's own device — voting is
the one remaining step that silently reverts to "gather around one phone," which is
exactly the friction the whole LAN feature exists to remove. Leaving it unaddressed makes
the rest of the LAN work feel unfinished at the exact moment tension is highest in a
round (who gets voted out).

## 3. Design Decision: Read-Only Sync, Not Multi-Device Voting Input

Two ways to do this:
- **(a) Read-only**: host keeps sole control of tapping eliminations (matches how the
  group actually plays today — verbal discussion, one person/device drives the tap);
  guests just watch a live-mirrored board.
- **(b) Multi-device voting**: any connected device can tap to vote/eliminate.

Recommend **(a) for v1**, deliberately. The whole LAN architecture is host-authoritative
specifically to avoid conflict resolution (see `feature-proposals/lan-multi-device-lobby.md`
§3: *"Host authoritative: prevents desync and cheating from conflicting role
generation"*) — the same reasoning applies to voting. Option (b) requires deciding what
happens when two devices tap different players within the same second, whether a
majority-vote model replaces the current single-tap-elimination model entirely, and
changes the actual game rules, not just where the UI lives. That's a much bigger,
genuinely different feature (something closer to "add a voting-democracy game mode") and
should be scoped separately if wanted later, not bundled into this doc.

## 4. Protocol Additions

New `LanMessageType` values in `lib/features/lan_lobby/protocol/lan_message.dart`,
following the existing envelope shape exactly:

- `votingStarted` — broadcast once, when the host enters `VotingScreen`. Payload: the
  full player roster in play order (`playerName`, `isImpostor` — **omit `word`/impostor
  status from the payload for players not yet eliminated**, revealing it only as each
  player is actually eliminated, so guests can't peek ahead of the live board just by
  inspecting network traffic — mirrors the same "don't leak unrevealed data" discipline
  already applied to `assignmentDistribution`), plus `word`, `timerSeconds`,
  `isBlankRound`, `suddenDeathEnabled`.
- `votingUpdate` — broadcast on every state change: a new elimination (`killedIndex`,
  and *now* reveal that player's `isImpostor`/`word`), an undo (`unkilledIndex`), or a
  sudden-death trigger. Payload carries the full current `killedIndices` list so a
  reconnecting/late-joining guest's state is always resolvable from the latest message
  alone, not a diff history.
- `votingEnded` — broadcast once voting concludes. Payload: `result` (`innocentsWin` /
  `impostorsWin` / `blankRound`), full `assignments` (all roles now safe to reveal),
  `killedIndices` — everything `EndScreen` needs to render an equivalent read-only
  summary.

## 5. Host-Side Changes

`voting_screen.dart` currently a plain `StatefulWidget`. Convert to
`ConsumerStatefulWidget` (same rationale as `EndScreen`, which already does this to check
`lanSessionProvider` directly rather than threading a flag through every constructor —
follow that established pattern here too):

- On `initState`, if `ref.read(lanSessionProvider)` is `isHost && phase != idle`, send
  `votingStarted` via a new `LanSessionNotifier.broadcastVotingStarted(...)` method
  (`_host.broadcast(...)`, mirroring `triggerStartGame()`'s existing shape).
- On every elimination/undo/sudden-death state change (wherever the existing kill/undo
  handlers currently call `setState`), also call a new
  `LanSessionNotifier.broadcastVotingUpdate(...)`.
- Right before navigating to `EndScreen`, call a new
  `LanSessionNotifier.broadcastVotingEnded(...)` with the final result.
- All three new notifier methods should be cheap no-ops when `!state.isHost`, matching
  the existing guard pattern on every other host-only notifier method
  (`distributeAssignments`, `triggerStartGame`, `returnToLobby`).

## 6. Guest-Side Changes (Native)

New screen, `lan_voting_spectator_screen.dart`, alongside the existing
`distributed_reveal_screen.dart`:

- Reached from `WaitingRoomScreen` (or wherever a guest currently lands after their own
  reveal completes / after `allRevealsComplete`) via a new stream on
  `LanSessionNotifier` — `votingStream`, populated from `votingStarted` the same way
  `assignmentStream` is already populated from `assignmentDistribution`.
- Renders essentially the same grid `VotingScreen` shows, but with no tap handlers —
  purely reflects `votingUpdate` messages as they arrive (subscribe similarly to how
  `DistributedRevealScreen` already subscribes to `allRevealsStream`).
- On `votingEnded`, either navigate to a read-only variant of `EndScreen` (recommended:
  add a `readOnly: bool` flag to `EndScreen` that hides the "Play Again" and "Back to
  Lobby / Settings" buttons for guests, since only the host drives those — everything
  else on that screen, including the word-vote UI, works fine as-is for a guest) or a
  dedicated lightweight results screen if divergence from `EndScreen` grows over time.

## 7. Guest-Side Changes (Browser Client)

`assets/web_client/`:

- New screen section, `#screen-voting`, added to `index.html`.
- `app.js`: handle `votingStarted` (render initial roster, all un-eliminated), track
  state in a module-level `let votingState`, handle `votingUpdate` (re-render, revealing
  the newly eliminated player's role), handle `votingEnded` (show final result — reuse
  visual language from the existing `#screen-done` "ready" banner styling for
  consistency, add role-breakdown lists in the same spirit as `end_screen.dart`'s
  Impostors/Innocents sections).
- No new WebSocket logic needed beyond adding three more `case` branches to
  `onMessage()` — the connection/reconnect/heartbeat machinery is entirely reused as-is.

## 8. Implementation Plan

### Phase A: Protocol + host broadcast
New message types, `voting_screen.dart` conversion to `ConsumerStatefulWidget`, three new
host-only notifier methods. No visible change yet — verify via logging/manual protocol
inspection that broadcasts fire correctly before building any consumer of them.

### Phase B: Native guest spectator
`lan_voting_spectator_screen.dart`, `votingStream`, wiring from `WaitingRoomScreen`.

### Phase C: Read-only `EndScreen` for guests
`readOnly` flag, hide host-only actions.

### Phase D: Browser client
`#screen-voting`, JS message handlers, styling.

## 9. Risks

- **Spoiler leakage**: a technically-savvy guest could inspect WebSocket frames — the
  payload design in §4 (only reveal a player's role at the moment they're actually
  eliminated, never earlier) limits this to "no worse than what a sighted guest at the
  table already learns the moment the host taps the elimination," which is an acceptable
  bar given the existing trust model (LAN-only, same room, optional PIN).
- **Late joiners / reconnects mid-vote**: since `votingUpdate` always carries the full
  current `killedIndices` (not deltas), a guest reconnecting mid-vote can resync
  correctly by just waiting for the next update or (better) requesting current state on
  reconnect — consider adding a `requestVotingState` client→host message for this rather
  than making guests wait for the next organic update.

## 10. Acceptance Criteria

- A connected guest (native or browser) sees eliminations appear on their own screen in
  real time, without any host-side lag beyond normal LAN latency.
- No guest ever sees a player's role before that player is actually eliminated on the
  host's screen.
- The final result screen matches what the host sees, minus host-only controls.
- A guest who disconnects and reconnects mid-vote ends up with the correct current state,
  not stuck on stale data.
- Solo (non-LAN) games are completely unaffected — no new broadcasts fire, no behavior
  changes, when `lanSessionProvider.isHost` is false.

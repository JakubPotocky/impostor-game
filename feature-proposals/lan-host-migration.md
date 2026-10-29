# LAN Host Migration

## 1. Goal

If the hosting phone's battery dies, its app crashes, or it drops off Wi-Fi mid-session,
let another connected device take over as host — so the party doesn't have to
re-join, re-pick identities, and reconfigure settings from scratch just because one
specific phone had a problem.

## 2. Why

This is an explicitly identified gap in the project's own earlier design work — the
original LAN proposal (`feature-proposals/lan-multi-device-lobby.md` §18) lists *"Optional
host transfer if host battery is low"* as a nice-to-have follow-up, never built. Right
now the host is a true single point of failure: `HostServerManager` runs entirely on one
device's `HttpServer`, bound to that device's own IP. If that device disappears, every
connected guest — native app and browser alike — has their WebSocket connection killed
simultaneously with no recovery path at all. For a feature whose entire pitch is "no
backend, resilient local architecture," a single dead phone taking down the whole party
is the most visible way that architecture can currently fail.

## 3. Scope Decision: Session-Level Recovery, Not Mid-Round State Recovery

Be upfront about what this can and can't realistically restore. Role assignments and the
secret word for the *currently in-progress round* only ever exist on the host device that
generated them — they're distributed per-claim to guests (see the redistribution work
from this session), not mirrored in full anywhere else. If the host dies mid-round, that
round's state is genuinely gone; there is no honest way to reconstruct who had which role
without a device that already had a full copy.

**What's recoverable, and worth building:** the lobby itself — the player roster, which
device claimed which identity, and the round settings (themes, impostor count, timer,
etc.) — all of which already live in `LanSessionState` and get broadcast to every
connected device via `lobbyStateSync`. That means every guest already has a recent local
copy of everything needed to resume the *lobby*, even though nobody but the dead host had
the in-flight round. **Recommended behavior: migration recovers the lobby and lets the
group immediately start a fresh round; the round in progress at the time of failure is
lost, same as today.** This is a much smaller, honestly-scoped, buildable feature — don't
try to solve mid-round recovery in the same effort, it would require a fundamentally
different architecture (full state mirroring to a backup device) for a failure mode
(host dies mid-round) that's already rare.

## 4. Choosing a Successor

Every `ConnectedDevice` already carries `joinOrder` (set at join time, used today only for
role-distribution ordering). Reuse it as an implicit, coordination-free succession list:
**the connected device with the lowest `joinOrder` among survivors is the designated
successor.** Every device can compute this independently and identically from the
`devices` list it already has cached from the last `lobbyStateSync` — no new election
message or coordination round-trip needed, and no native app client needs the host's
permission to decide "is it my turn" since the answer is deterministic from data everyone
already has.

Browser-joined devices should **not** be eligible successors — a browser tab can't run
`HostServerManager`/`HttpServer`/mDNS advertisement (host duties require the native app).
Exclude devices whose connection came in via the browser client from succession
eligibility; if the browser client's `helloClient` payload doesn't currently distinguish
itself from a native client, add a `platform: 'web'` field to it
(`assets/web_client/app.js`'s `helloClient` payload) specifically so successor selection
can skip them.

## 5. Detection & Promotion Protocol

- **Detection** already mostly exists: `ClientManager`'s `onDone`/`onError` callback
  (`lan_session_notifier.dart`'s `_onHostDisconnected()`) already fires when the host's
  socket dies. Today it just sets `phase: idle` and an error message. Change it to first
  check eligibility before giving up.
- **If this device is the designated successor**: call a new
  `LanSessionNotifier.promoteToHost()` that:
  1. Starts a new `HostServerManager` on this device (exactly like `createLobby()` does
     today) and a new mDNS advertisement — but reusing the **same `sessionId`** from the
     `LobbySession` this device already had cached (this is why `sessionId` is already
     part of the mDNS TXT attributes in `mdns_service.dart` — it lets other devices
     recognize "this is the same game continuing," not a coincidentally-similar new one).
  2. Seeds `state.devices`/`state.players` from what this device already had from the
     last `lobbyStateSync` (minus the now-departed old host), rather than starting from
     an empty lobby.
  3. Switches `state.role` from `client` to `host` and `state.phase` to `inLobby`.
  4. Surfaces clear UI ("You're now hosting — [old host] disconnected") and pushes this
     device to `HostLobbyScreen`, pre-populated, ready to show a fresh QR code and Start
     Game.
- **If this device is not the successor**: wait a short grace window (recommend 3–5
  seconds, comparable to the existing 6-second stale-device threshold in
  `_startStaleCheck()`) for the promoted device to come back online, then behave
  differently by client type (see §6/§7).

## 6. Native Guest Recovery

After the grace window, a non-promoted native guest should automatically re-browse mDNS
(`MdnsService.browseLobbies()`, already built) filtered for a lobby advertising the
**same `sessionId`** it was previously connected to, and auto-reconnect
(`joinLobby()` → `helloClient` with the same persisted `deviceId`, so the new host's
`_upsertDevice` correctly recognizes it as a returning device rather than a stranger,
matching the reconnect behavior already established for the browser client's own
reconnect-with-stored-`deviceId` pattern). Show a brief "Reconnecting to new host…" state
rather than immediately erroring out the way `_onHostDisconnected()` does today.

## 7. Browser Guest Limitation (Be Honest About This)

Browsers cannot perform mDNS discovery — this was already the reasoning for why the
browser client needs an explicit URL/QR code in the first place
(`feature-proposals/lan-browser-client.md` §4.3). That limitation applies identically
here: **a browser guest has no automatic way to find the new host's new IP:port**, since
migration necessarily moves the game to a different device with a different address.

Accept this rather than over-engineering around it: on detecting the host connection
died, the browser client (`app.js`'s `onClose` handler) should show a clear, honest
message — *"Host disconnected. Ask the host to share the new link."* — rather than
attempting silent reconnection it structurally cannot perform. The promoted device's
`HostLobbyScreen` shows a new QR code exactly like it did on first hosting; a browser
guest scans it again. This is a manual step, but a fast one (a few seconds, same motion
as the original join), and honest about what's actually possible without a component this
project has deliberately chosen not to build (a discovery relay).

## 8. Implementation Plan

### Phase A: Successor selection + detection
`joinOrder`-based successor computation, `platform` field on `helloClient`, updated
`_onHostDisconnected()` branching logic. No promotion yet — just correctly identify who
*would* be promoted, and log/verify it.

### Phase B: Promotion
`LanSessionNotifier.promoteToHost()`, new host bootstrap reusing cached state and
`sessionId`, UI transition to `HostLobbyScreen`.

### Phase C: Native guest auto-reconnect
Grace window, mDNS re-browse filtered by `sessionId`, auto-`joinLobby()`.

### Phase D: Browser guest messaging
Clear "ask for a new link" state in `app.js`, no auto-reconnect attempt.

## 9. Risks

- **Split-brain**: if the network briefly partitions rather than the host actually dying,
  two devices could both believe they're the successor and both start advertising the
  same `sessionId`. Mitigate by having the promoted host, if it later detects mDNS
  advertisements for its own `sessionId` from another device, treat that as a stale
  advertisement conflict and defer to whichever came first (by port/timestamp) — flag
  this as an edge case to test explicitly, not just reason about.
- **Rapid host cycling**: if the successor also has a bad connection, promotion could
  chain repeatedly. Cap it — after one migration, don't auto-promote again within some
  short window; require a manual "try hosting again" action instead of an unbounded
  automatic chain.

## 10. Acceptance Criteria

- If the host's app is force-closed mid-lobby (before a round starts), the designated
  successor's device automatically becomes host within the grace window, with the same
  player roster and settings intact.
- Native guests reconnect automatically to the new host without any manual action beyond
  a brief "Reconnecting…" state.
- Browser guests are told clearly to re-scan a new code, and doing so successfully
  rejoins them with their previously-claimed identity intact (same `deviceId` recognized
  by the new host).
- If the host dies *mid-round*, the round is cleanly abandoned (no crash, no stuck UI) and
  the group lands back in a working lobby ready to start a fresh round — not a
  reconstructed version of the lost round.
- A solo (non-LAN) game is entirely unaffected by any of this.

# Remote Play — Playing With People Not on the Same Network

## 1. Goal

Let a host start a game that friends can join from anywhere — not just the same Wi-Fi or
hotspot — while changing as little as possible about the game itself. This document is
written to be read *before* deciding whether to build it, not just how to build it: the
"why" and the tradeoffs matter more here than in any other document in this folder.

## 2. Why, and Why This Is Different From Everything Else on This List

"Can we play when we're not all in the same room" is the single most common request for
any local-multiplayer party game, in any genre. It would be dishonest to leave it off a
list of "what players would want."

But it directly conflicts with a principle this project has already stated explicitly
(`feature-proposals/lan-multi-device-lobby.md` §3): *"Local first: avoids backend,
billing, account complexity, and privacy concerns."* Every other feature in this roadmap
is additive to that principle. This one isn't — it requires a real, internet-facing,
continuously-running server that didn't exist before, with real operational cost and a
real (if small) privacy surface change. That's not a reason to reject it, but it is a
reason to make the tradeoff explicit and require a deliberate decision before scheduling
this, rather than defaulting to "yes, add it to the pile with everything else."

## 3. Options Considered

| Approach | NAT traversal | New infra | Complexity | Ongoing cost |
|---|---|---|---|---|
| **WebRTC peer-to-peer** (STUN, TURN fallback) | Good via STUN, needs TURN fallback ~20-30% of the time | Signaling server (small) + TURN server | High — new APIs, ICE negotiation, platform quirks | Low-moderate (TURN relay bandwidth) |
| **Stateless WebSocket relay** *(recommended)* | Always works — every participant makes a normal outbound connection | One relay server | Low — reuses existing protocol untouched | Low, predictable (small JSON messages only) |
| **Full backend** (accounts, matchmaking, persistent rooms/history) | N/A | Full backend + database | Very high | Meaningful, ongoing |

**Recommendation: the stateless relay.** The reasoning is specific to this app, not
generic: every message this game ever sends is small JSON (role assignments, votes,
heartbeats) — there's no video/audio/large-payload case where peer-to-peer's bandwidth
and latency advantages actually matter here. WebRTC's main advantage (avoiding relay
bandwidth cost for large media) doesn't apply, so it's pure complexity with no
corresponding benefit for this specific payload profile. A full backend solves problems
this feature doesn't have (no accounts or matchmaking are needed — a friend group already
knows who they're playing with). The relay is the smallest possible addition that
actually solves the NAT-traversal problem, and — critically — it can hold **zero game
state**: no accounts, no player data, no persistence, nothing to leak or moderate. It's
functionally a very long ethernet cable, not a game server.

## 4. Architecture

Introduce a transport abstraction so the existing protocol and all higher-level game
logic (role distribution, reveal, voting sync) stay completely untouched:

```dart
abstract class LanTransport {
  Future<void> start();               // host: begin listening / connect to relay
  Future<void> connect(String target); // client: connect to a host or relay+code
  void send(LanMessage message);
  void broadcast(LanMessage message);  // host only
  void sendTo(String deviceId, LanMessage message); // host only
  Stream<LanMessage> get messages;
}
```

- `LocalHttpTransport` — today's `HostServerManager` + `ClientManager`, unchanged, just
  reorganized behind this interface.
- `RelayTransport` — new. Host side opens one outbound `wss://` connection to the relay
  and registers a room; guest side opens one outbound `wss://` connection with a room
  code. Neither side ever listens for inbound connections — this is what makes it work
  through arbitrary home routers and mobile carrier NAT without any port forwarding or
  STUN/TURN negotiation.

`LanSessionNotifier` picks the transport based on a new explicit user choice — **"Host on
this Wi-Fi"** vs **"Host Remotely"**, **"Join on this Wi-Fi"** vs **"Join with a Code"** —
presented as a clear fork in `LobbyModeScreen`, not an automatic fallback. Users should
always know which mode they're in, since it has real implications (remote play needs
internet, not just Wi-Fi; local play works with zero internet access at all, a property
worth preserving and not quietly regressing for users who don't want or need remote play).

## 5. Connection Flow

- **Host**: connects outbound to the relay, which returns a short room code (6
  alphanumeric characters — typeable over voice chat, unlike a `sessionId` UUID).
  `HostLobbyScreen`'s existing QR/link card (built for the browser-join feature) extends
  naturally here: same UI, just encoding a `relay.example.com/join/<code>` link instead
  of a local IP.
- **Native guest**: enters or scans the code, `RelayTransport.connect(code)` opens an
  outbound WebSocket to `wss://relay.example.com/guest/<code>`.
- **Browser guest**: reuse `assets/web_client/app.js` almost unchanged — its `wsUrl()`
  function currently derives the target from `location.host` (correct for the local-join
  case, where the page is served BY the host's own device); add a landing page at the
  relay's own domain where a visitor enters/scans a code, and `wsUrl()` there points at
  `wss://relay.example.com/guest/<code>` instead. All the message-handling logic
  (`onMessage`, reveal flow, heartbeats, reconnect) needs zero changes — it already only
  cares about the `LanMessage` envelope, not the transport underneath it.

## 6. Relay Server (New Component)

This is a genuinely new, separately-deployed service — not part of the Flutter app.
Recommend implementing it in Dart (`shelf` + `shelf_web_socket`) to keep the whole
project in one language, but the design is intentionally simple enough that the
implementation language doesn't matter much:

- On host connect: generate a room code, hold two structures — `hostSocket` and
  `Map<String, WebSocket> guestSockets` (keyed by the guest's own persisted `deviceId`,
  exactly as `HostServerManager._clients` already does locally).
- On guest connect with a valid code: register it, relay from that point on.
- **Routing needs one thin addition** the current `LanMessage` envelope doesn't carry:
  which of `sendTo(deviceId, ...)` vs `broadcast(...)` a host-originated frame was. Wrap
  host→relay frames in a minimal transport envelope — `{route: 'broadcast', payload:
  <LanMessage JSON>}` or `{route: 'unicast', targetDeviceId: ..., payload: ...}` — added
  only at the `RelayTransport` layer, not the `LanMessage` protocol itself, so the
  protocol stays identical and reusable across both transports.
- Guest→host frames need no wrapper — always forward to `hostSocket` untouched, exactly
  matching how guests never message each other today.
- **The relay parses only the thin routing wrapper — never the game payload inside it.**
  It doesn't need to understand roles, words, or votes to do its job; keep it that way
  deliberately, both for simplicity and so there's truthfully nothing sensitive to log or
  leak even by accident.
- Expire empty/abandoned rooms after a short timeout (a few minutes with no host
  connected) to bound memory use.

## 7. Security, Privacy, and Abuse — New Concerns This Feature Introduces

Everything in this section is new relative to the rest of the app, because this is the
first time anything in this project is reachable from the open internet:

- **`wss://` (TLS) only** — never plaintext `ws://` once traffic leaves a local network;
  the existing LAN transport's plaintext `ws://` is fine specifically because it never
  crosses a network boundary, that justification disappears here.
- **Rate-limit room creation** per source IP, to prevent trivial abuse of a free public
  endpoint.
- **Room codes should not be guessable in a useful timeframe** — 6 alphanumeric characters
  (~2 billion combinations) with a short room lifetime is reasonable; don't make codes
  sequential or short enough to be brute-forced during a typical game's lifetime.
- **No content logging** — the relay should log connection metadata (for abuse debugging)
  but never message payloads, preserving as much of the original privacy posture as
  possible given the architecture change.
- Continue to support an optional join PIN (the field already exists in `LobbySession`,
  just never enforced server-side — see the existing gap noted in
  `feature-proposals/lan-browser-client.md` §8) — it matters more here than on LAN, since
  a leaked room code is reachable by anyone on the internet, not just people already in
  the room.

## 8. Cost

Realistic and worth stating plainly: this is small-JSON traffic, not media — a single
relay server (even a $5-10/month VPS, or a low tier of a serverless WebSocket host) can
comfortably support a meaningful number of concurrent game sessions. This is not
"free" the way the rest of the app is, but it's not the same order of cost as a
traditional game backend either. Budget for this as an ongoing, small, predictable
line item — and decide who owns paying for and operating it before building the feature,
not after.

## 9. Implementation Plan

### Phase A: Transport abstraction (no new behavior yet)
Extract `LanTransport`, reimplement today's local flow as `LocalHttpTransport` with zero
behavior change. This is pure refactoring — ship and verify the existing LAN feature
still works identically before adding anything new.

### Phase B: Relay server
Standalone service, host/guest registration, thin routing wrapper, room expiry, rate
limiting. Deploy to a real environment and test in isolation (a script that connects as
"host" and "guest" and exchanges test frames) before touching the app.

### Phase C: `RelayTransport` + host/guest UI fork
`LobbyModeScreen`'s "Host Remotely" / "Join with a Code" paths, room-code display and
entry, reuse of the existing QR card pattern.

### Phase D: Browser client landing page
Relay-hosted join page reusing `app.js` with a swapped `wsUrl()`.

### Phase E: PIN enforcement
Since it now matters more than it did for LAN — implement the currently-unenforced PIN
check on the relay/host join-request path (applies to both this feature and, as a
byproduct, finally closes the long-standing LAN gap too).

## 10. Risks

- **Scope creep toward a full backend** is the biggest risk to this specific feature —
  resist adding accounts, persistent rooms, or matchmaking "while you're in there." The
  entire value of the recommended approach is staying a dumb, stateless pipe.
- **Abuse of a now-public endpoint** — see §7; underinvesting here turns a small feature
  into an operational headache.
- **Divergent behavior between local and remote play** confusing users — mitigate with
  the explicit, always-visible mode fork in §4 rather than an automatic silent fallback.

## 11. Decision to Make Before Starting

This is the one feature on this roadmap that shouldn't be started opportunistically.
Before scheduling it, get an explicit answer to: who operates and pays for the relay
server long-term, and is introducing the app's first-ever internet-facing, always-on
infrastructure dependency actually worth it for this project's goals. If the answer is
yes, everything above is a workable, appropriately-scoped path that preserves the app's
existing local-first behavior for everyone who doesn't opt into remote play.

## 12. Acceptance Criteria

- A host and guest on different networks (verified: different Wi-Fi, or one on cellular
  data) can complete a full round together via a room code.
- Local (same-network) hosting and joining continue to work completely unchanged, with no
  internet connection required, when "Host on this Wi-Fi" is chosen.
- The relay server never has access to role assignments, words, or player identities in
  any form it could log or leak beyond momentary in-memory forwarding.
- A guest on the browser client can join a remote game via the relay-hosted landing page
  with the same zero-install experience the LAN browser client already provides.
- Abandoned rooms are cleaned up and don't accumulate unbounded server memory over time.

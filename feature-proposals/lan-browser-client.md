# LAN Browser Client — Play From Any Phone, No App Install

## 1. Goal

Let every player except the host join a LAN game from their phone's browser instead of
installing the Impostor app. The host device (running the full Flutter app) already runs
a local WebSocket server for the native multi-device lobby
([lib/features/lan_lobby/services/host_server_manager.dart](../lib/features/lan_lobby/services/host_server_manager.dart)).
This proposal extends that *same* server to also serve a small static web page, so a
player can open a URL (or scan a QR code) in Safari/Chrome, pick which player they are,
and get their own private role reveal on their own screen — with zero installation.

This is strictly additive. Native app-to-app LAN joining
([feature-proposals/lan-multi-device-lobby.md](lan-multi-device-lobby.md)) keeps working
exactly as it does today. Browser joining is a second, lighter-weight join path into the
*same* lobby, using the *same* protocol.

Why this matters:
- The biggest friction in the current LAN feature is "everyone has to install the app
  first." A browser client removes that entirely for guests — only the host needs the app.
- It makes the game viable at parties/gatherings where guests won't install a new app for
  a five-minute game but will happily tap a link.
- No new backend, no accounts, no protocol redesign — the host is already a capable local
  HTTP server; it just needs to also answer plain GET requests.

## 2. User Story and UX Flow

### Host flow (unchanged, plus one addition)
- Host creates a lobby as today (`HostLobbyScreen`).
- New: the lobby screen now also shows a **"Join from a phone browser"** card with:
  - the join URL in large text, e.g. `http://192.168.1.23:53214`
  - a QR code encoding that URL
  - a "Copy link" button
- Everything else — connected device list, player list, Start Game — is unchanged.

### Browser joiner flow (new)
- Guest scans the QR code or types the URL into their phone's browser.
- Page loads instantly (it's a handful of KB, served from the host's own phone over LAN,
  no internet required).
- Guest enters a display name (defaults to something like "Guest 3") and, if the lobby
  requires one, a PIN.
- Guest is dropped into an **identity picker**: the same player-name roster the host
  typed in, shown as tappable chips. Names already claimed by another device are greyed
  out. Guest taps their own name.
- Guest sees a waiting-room view: their chosen name, a "waiting for host to start…"
  message, and (if available) their streak badge.
- When the host starts the game, the guest's browser receives only its assigned subset of
  players (same partitioning algorithm as native clients) and shows the existing
  tap-to-reveal flow: tap to reveal a name's word/impostor status, tap again to advance to
  the next assigned name, pass the phone only if the guest is holding more than one name.
- After the guest's subset is complete, the page shows "You're done — pass the phone back
  to the table" and waits for the `ALL_REVEALS_COMPLETE` signal so it can show a shared
  "everyone's ready" moment.

### Non-goals for this iteration
- No voting/results UI in the browser — discussion and voting remain host-device
  activities as they are today for native clients.
- No offline/PWA install prompt, no service worker caching across sessions — every join is
  a fresh page load from the host.

## 3. Why a Static Page (Not Flutter Web)

Do **not** build this as a `flutter build web` target. Reasons:
- The host is a phone, not a server host with build infrastructure — the web client must
  ship as pre-built static assets bundled into the app, not compiled on demand.
- A Flutter web app pulls in a large JS/canvas runtime; over LAN Wi-Fi to a phone browser
  that's slow to first paint and overkill for "pick your name, tap to reveal a word."
  Guests judge the game by how fast this loads.
- The existing protocol ([lib/features/lan_lobby/protocol/lan_message.dart](../lib/features/lan_lobby/protocol/lan_message.dart))
  is plain JSON over a raw WebSocket — trivial to reimplement in ~150 lines of vanilla
  JavaScript with no build tooling, no npm dependency tree, no framework.

Build the web client as hand-written HTML/CSS/JS, mobile-first, single page, no
bundler. This keeps the whole feature buildable and reviewable without adding a second
toolchain to the repo.

## 4. Server Changes Required

### 4.1 Serve static assets alongside the WebSocket upgrade

`HostServerManager._handleRequest` in
[host_server_manager.dart:46-52](../lib/features/lan_lobby/services/host_server_manager.dart)
currently rejects every non-upgrade request with `400 Bad Request`:

```dart
void _handleRequest(HttpRequest request) async {
  if (!WebSocketTransformer.isUpgradeRequest(request)) {
    request.response
      ..statusCode = HttpStatus.badRequest
      ..close();
    return;
  }
  ...
```

Change this to branch on the request:
- If it's a WebSocket upgrade request → existing behavior (upgrade to socket).
- If it's a plain `GET` → serve a static asset matched by `request.uri.path`:
  - `/` or `/index.html` → the web client's HTML shell
  - `/app.js` → the JS client (protocol + UI logic)
  - `/style.css` → styling
  - anything else → `404`
- Any other method (`POST`, etc.) → `404`.

Load the three assets **once**, at `HostServerManager.start()` time, via
`rootBundle.load('assets/web_client/…')` (Flutter's asset bundle is already initialized
by the time a lobby can be created, since this only runs from within the running app) and
keep them as in-memory `String`/`Uint8List`. Serve from memory on every request — do not
re-read the bundle per request. Set `Content-Type` explicitly (`text/html`,
`application/javascript`, `text/css`) and `Cache-Control: no-store` (the port changes
every session, so nothing should ever be cached across sessions).

### 4.2 Register the new assets

Add the web client files under `assets/web_client/` and register the folder in
[pubspec.yaml](../pubspec.yaml):

```yaml
flutter:
  assets:
    - assets/themes.json
    - assets/web_client/
```

### 4.3 Surface a joinable URL on the host

Browsers cannot resolve the app's mDNS advertisement
(`_impostor._tcp`, via `bonsoir` in
[mdns_service.dart](../lib/features/lan_lobby/services/mdns_service.dart)) — mDNS
discovery/browsing is a native OS capability, not something a mobile browser exposes to
arbitrary pages. The host must show an explicit URL instead.

Add a method to resolve the host's own LAN IPv4 address using `dart:io`
(`NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false)`),
filtering out loopback/link-local interfaces. If more than one non-loopback IPv4 address
is found (e.g. Wi-Fi + a hotspot interface at once), let the host pick which network to
advertise, defaulting to the first. Combine with `HostServerManager.port` to build
`http://<ip>:<port>`.

Surface this as a new card on `HostLobbyScreen` (see
[host_lobby_screen.dart](../lib/features/lan_lobby/screens/host_lobby_screen.dart),
alongside the existing `_LobbyInfoCard`): large monospace URL text, a "Copy link" button
(`Clipboard.setData`), and a QR code. For the QR code, add the `qr_flutter` package
(pure-Dart QR rendering, no native plugin, no camera/permissions needed since the host
only *generates* the code) to `pubspec.yaml`.

## 5. Protocol: Reuse As-Is, No New Message Types

The browser client speaks the **exact same JSON protocol** already defined in
`lan_message.dart` — same envelope, same message names, same field names. Do not fork or
version the protocol for browser clients. Implement, in `app.js`, a JS-side encoder/decoder
matching:

```json
{ "messageType": "helloClient", "sessionId": "", "payload": { ... }, "protocolVersion": "1.0" }
```

Message flow the browser client must implement (mirrors `client_manager.dart`):

1. Open `ws://<host>:<port>` (same origin the page was loaded from — derive host/port from
   `window.location`, don't hardcode).
2. Send `helloClient` with a `deviceId` (generate via `crypto.randomUUID()` on first load,
   persist in `sessionStorage` so a page refresh mid-session reuses the same identity
   instead of registering as a new device), `displayName` (from the name field), and
   `appVersion: "web-1.0"`.
3. Receive `helloHostAck` → store `sessionToken`.
4. Send `joinRequest` with `sessionId`, `deviceId`, `sessionToken`, and `pin` if the lobby
   requires one.
5. Receive `joinAccepted` (proceed to identity picker) or `joinRejected` (show the reason,
   e.g. wrong PIN, and let the guest retry).
6. Receive `lobbyStateSync` broadcasts and re-render the player roster (name → taken/free)
   on every update — this is how the browser client learns which names are already
   claimed by other devices.
7. On tap, send `playerIdentitySelect` with the chosen `playerName`; wait for
   `playerIdentityConfirmed` before locking in the waiting-room view (another device may
   have claimed it first — handle the race by re-showing the picker if rejected via the
   next `lobbyStateSync`).
8. Send `heartbeat` every 2 seconds while connected (the host marks a device stale after 6
   seconds without one — see
   [lan-multi-device-lobby.md §12](lan-multi-device-lobby.md#12-failure-and-recovery-strategy)).
   Missing this makes the guest's tile show as stale/disconnected on the host screen even
   though the tab is open.
9. On `startGame` + a targeted `assignmentDistribution` (only messages addressed to this
   `deviceId` arrive, per `HostServerManager.sendTo`), render the tap-to-reveal flow for
   the `assignments` array in the payload, honoring `hintsEnabled`, `themeVisibilityMode`,
   `impostorHintWord`, and `reducedMotion` (disable CSS transitions when true) exactly as
   the native `RoleRevealScreen` does.
10. After each reveal, send `revealProgressUpdate` with the running `revealsCompleted` /
    `revealsTotal`.
11. On `allRevealsComplete`, show the "everyone's ready" screen.
12. On socket close/error, attempt reconnect with backoff (1s, 2s, 4s, capped), replaying
    `helloClient` with the *same stored* `deviceId`/`sessionToken` so the host can
    reconcile the reconnect rather than treating it as a new join (matches the native
    reconnect story in the existing proposal).

No server-side protocol change is needed to support this — the browser client is just
another WebSocket peer that happens to be written in JS instead of Dart.

## 6. Web Client Structure

```
assets/web_client/
  index.html   — single page, all screens as hidden/shown <section>s
  style.css    — mobile-first, large tap targets, system font stack, light+dark aware
  app.js       — protocol client + screen state machine, no dependencies, no build step
```

Screens (all in one page, toggled by JS, no routing library):
- **Connect** — display name input, optional PIN input, "Join" button. Shown while
  `helloClient`/`joinRequest` are in flight; show a clear error state for `joinRejected`.
- **Pick your player** — chip grid of player names from `lobbyStateSync`; disabled chips
  for names already claimed.
- **Waiting room** — confirmed name, "waiting for host to start" message, streak badge if
  the payload includes one (see §7).
- **Reveal** — one card at a time from the assigned subset: tap to flip/reveal, tap to
  advance. Reuse the same visual language (colors, spacing) as the native
  `role_reveal_screen.dart` so the experience feels like one app, not a bolted-on web page.
- **Done** — "You're finished — hand the phone back," waiting for `allRevealsComplete`.

Design constraints:
- No external CDN dependencies (fonts, JS libraries) — the phone may have no internet
  access at all (LAN-only, possibly a hotspot with no upstream). Everything must be
  self-contained in the three files.
- No caching of the revealed word beyond a JS variable in memory — don't write it to
  `localStorage`/`sessionStorage`, and clear it from the DOM/variable once the guest
  advances past that card, to avoid it lingering in browser history/back-forward cache.
- Large, high-contrast text; this runs at arm's length in a living room, often at night.

## 7. Data Model — No New Entities

No new server-side data model is required. The browser client is represented on the host
exactly like a native client: a `ConnectedDevice`
([models/connected_device.dart](../lib/features/lan_lobby/models/connected_device.dart))
with `isHost: false`. Nothing in `LanSessionState`, `LobbySession`, or the reveal
partitioning logic needs to change — a device is a device regardless of whether it's a
phone running the Flutter app or a phone browser tab.

If/when the optional streak-preview enhancement from
[lan-multi-device-lobby.md §11](lan-multi-device-lobby.md#11-streak-feature-enhancement-in-lan-mode)
ships, include the same compact streak snapshot in `lobbyStateSync` so the browser client
can render it without any browser-specific server logic.

## 8. Security and Privacy Model

- Same trust boundary as the native LAN feature: LAN-only, no cloud relay, no accounts.
- A browser client is *slightly* more exposed than a native client because the join URL
  is a plain link — anyone who sees the QR code or the URL (e.g. a photo of the screen)
  could join from outside the room if they're on the same network. Mitigation: honor the
  existing optional lobby PIN (`requiresPin`) for browser joins exactly as for native
  joins; encourage hosts to enable it for larger gatherings. Don't add a new mitigation
  mechanism beyond what native joins already have — keep the two join paths at parity.
- The static assets are served with `Cache-Control: no-store` so a stale page can't be
  replayed against a different session on the same IP:port later (ports are re-randomized
  per session anyway).
- Rate-limit malformed/oversized frames from browser sockets the same way as native
  sockets — the host doesn't need to distinguish client type at the protocol layer.

## 9. Failure and Recovery

- If the guest's browser tab is backgrounded (phone locked, app-switched), mobile Safari
  and Chrome will suspend the WebSocket and the heartbeat timer; the host will correctly
  mark the device `stale` after 6 seconds, matching existing behavior for a native client
  that loses connectivity. On foreground, `app.js` must detect the closed socket
  (`visibilitychange` listener) and immediately attempt reconnect rather than waiting for
  the next heartbeat tick.
- If the host ends the session, the browser client should show a clear "Host ended the
  game" state rather than a silent broken connection.
- If the guest reloads the page mid-game (accidental), the stored `deviceId` lets them
  reconnect, but reveal progress already shown is not restorable from the host — treat a
  mid-reveal reload as equivalent to a native client's reconnect-after-crash: the host's
  existing reconnect fallback (reassign pending reveals to host, or pause) applies
  unchanged.

## 10. Performance Targets

- Page load over LAN Wi-Fi from the host phone: under 1 second on the join screen (a
  well-under-50KB page with no external requests should comfortably hit this).
- WebSocket handshake + `helloClient`/`helloHostAck` round trip: under 300ms.
- No animation jank on low-end Android/iOS browsers — keep CSS transitions simple
  (opacity/transform only), and skip them entirely when `reducedMotion` is set.

## 11. Implementation Plan by Phases

### Phase A: Server foundation
- Extend `HostServerManager._handleRequest` to serve static GET requests (§4.1).
- Add `assets/web_client/` with placeholder `index.html`/`app.js`/`style.css` and register
  in `pubspec.yaml`.
- Add LAN IPv4 resolution helper and wire it into `HostLobbyScreen` as a URL + "Copy link"
  card (no QR code yet) to validate end-to-end reachability from a real phone browser.

### Phase B: Protocol client
- Implement the JS WebSocket client: `helloClient` → `joinRequest` → identity select →
  waiting room, driven off real `lobbyStateSync` payloads from a live host.
- Implement heartbeat and reconnect-with-backoff.

### Phase C: Reveal flow
- Implement the tap-to-reveal screen consuming `assignmentDistribution`, sending
  `revealProgressUpdate`, and handling `allRevealsComplete`.
- Match visual styling to the native reveal screen closely enough that it reads as the
  same product.

### Phase D: Polish
- Add the QR code to the host card (`qr_flutter`).
- Add PIN entry to the browser connect screen.
- Dark-mode-aware CSS (`prefers-color-scheme`).
- Handle `visibilitychange`-triggered reconnect.

### Phase E: Hardening and QA
- Cross-browser pass (see §12).
- Verify no protocol drift by running a mixed lobby: some native app clients, some browser
  clients, in the same session.

## 12. QA Test Matrix

Functional:
- Host creates lobby, one guest joins via browser only, game starts and reveals correctly.
- Mixed lobby: 2 native app clients + 2 browser clients, distribution stays balanced
  across all 4 (partitioning logic is device-count-based, not client-type-based).
- Two browser tabs race to claim the same player name — loser sees the picker refresh
  with that name now disabled.
- PIN-protected lobby rejects a browser join with the wrong PIN and shows a clear error.

Browser matrix (this is the highest-risk area — test on real devices, not just desktop
devtools device emulation):
- iOS Safari (most restrictive WebSocket/background behavior).
- Android Chrome.
- Android Samsung Internet.

Failure:
- Guest locks phone mid-reveal, unlocks 30s later — reconnect succeeds, host doesn't
  double-count progress.
- Guest closes tab entirely — host sees `disconnected`, not stuck on `stale` forever.
- Host ends session while a guest is on the picker screen — guest sees a clear end state.

Regression:
- Native app-to-app LAN flow (existing feature) is completely unaffected — run its
  existing QA matrix from
  [lan-multi-device-lobby.md §15](lan-multi-device-lobby.md#15-qa-test-matrix) unchanged.
- Single-device pass-and-play mode is unaffected.

## 13. Risks and Mitigations

- **Risk**: some guest phones are on the Wi-Fi network's guest VLAN, which isolates
  clients from each other (common on hotel/office Wi-Fi) — the browser can't reach the
  host's IP even though both show "connected to Wi-Fi." Mitigation: this is a pre-existing
  limitation of the native LAN feature too (same network requirement); document it in the
  host's UI copy ("everyone must be on the same Wi-Fi, not a guest network") rather than
  trying to solve it in software.
- **Risk**: iOS Safari aggressively suspends background tabs/sockets, causing spurious
  stale/disconnect flapping. Mitigation: reconnect-on-foreground (§9) plus a slightly more
  forgiving stale threshold specifically tolerated for browser-origin devices if this
  proves noisy in testing — but start with the same threshold as native and only special-
  case it if QA shows a real problem.
- **Risk**: a stale browser tab left open from a previous session tries to rejoin a
  since-ended session. Mitigation: `Cache-Control: no-store` plus the host rejecting
  `joinRequest`s for a `sessionId` it no longer recognizes with a clear `joinRejected`
  reason.

## 14. Acceptance Criteria

- A guest with no app installed can scan a QR code (or type a URL) shown on the host
  screen and join the lobby from their phone's browser.
- The guest can pick which player they are from the host's roster, with duplicate
  selection prevented.
- When the host starts the game, the guest's browser reveals only its assigned subset of
  players, matching the same partitioning behavior as native clients.
- A lobby can mix native app clients and browser clients in the same session without any
  protocol changes.
- Native app-to-app LAN joining and single-device pass-and-play remain fully unchanged.
- No external network access is required at any point in the browser join flow — it works
  on a phone with Wi-Fi-only connectivity and no mobile data.

## 15. Nice-to-Have Follow-Ups

- Add the guest's chosen player's streak badge to the waiting room once the streak-sync
  enhancement from the native proposal ships.
- Let the host relabel a browser guest's `displayName` if a duplicate/confusing name is
  entered (e.g. two guests both type "Phone").
- Consider a tiny "how to join" illustrated card next to the QR code for less
  tech-savvy hosts (what Wi-Fi to be on, what a QR code is).

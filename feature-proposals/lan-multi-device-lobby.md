# LAN Multi-Device Lobby and Distributed Role Reveal

## 1. Goal

Enable multiple phones running the same app to join one local game lobby over the host phone network, without any third-party server.

Main outcomes:
- Faster role reveal by splitting players across connected phones.
- Better social flow because each person can hold their own phone.
- Better streak visibility by letting users pick their player identity on join.
- Fully local architecture, no cloud cost, no account system required.

## 2. User Story and UX Flow

### Host flow
- User opens app and taps Play.
- User chooses game mode as today (Normal or Team).
- User creates a local lobby and becomes Host.
- Host sees join code, lobby name, and connected devices.
- Host adds or edits player names as today.
- Host taps Start Game.
- Host and all connected clients receive assigned reveal workload.

### Joiner flow
- User taps Join Lobby.
- App discovers lobbies on local network and lists them.
- User selects a lobby and joins.
- User selects which player they are from the host player list.
- User waits in lobby and sees their selected name and win streak badge.
- When host starts, user device reveals only assigned subset of players.

### In-game reveal flow
- If there are P players and D connected devices (including host), each device gets roughly P/D reveals.
- Each device reveals only its assigned subset.
- All role assignment is generated once by host to keep a single source of truth.
- After all subsets are complete, host proceeds to discussion and voting.

## 3. Product Principles and Reasoning

- Local first: avoids backend, billing, account complexity, and privacy concerns.
- Host authoritative: prevents desync and cheating from conflicting role generation.
- Discovery simplicity: local network discovery should feel near-instant.
- Degrade gracefully: if no clients join, game works exactly like current single-phone mode.
- Minimal friction: joining should be 2 to 3 taps.
- Trust and privacy: no internet transfer, no personal account data, no permanent identity requirement.

## 4. High-Level Architecture

Use a host-client model over LAN:

- Discovery layer: mDNS/Bonjour style service advertisement and browsing.
- Session transport: WebSocket server on host, WebSocket client on joiners.
- Protocol: JSON messages with explicit versioning.
- State ownership: host owns canonical lobby, player list, settings, assignment, and game phase.

Why this design:
- mDNS solves local discovery without backend.
- WebSocket provides reliable two-way communication and simple integration in Flutter.
- Host authority keeps game logic deterministic and easy to debug.

## 5. Network Stack Proposal

### Discovery
- Host advertises service type, for example: _impostor._tcp.
- Clients browse same service type and show discovered host entries.
- Include host metadata in TXT fields:
- lobbyName
- mode
- appVersion
- requiresPassword true/false

### Transport
- Host starts WebSocket server on local IP and random available port.
- Clients connect using discovered IP and port.
- All messages are JSON frames with schema:
- messageType
- sessionId
- payload
- protocolVersion
- sentAt

### Suggested Flutter packages
- Discovery package: bonsoir or nsd abstraction package.
- Transport: dart:io WebSocket.
- Connectivity checks: connectivity_plus.

## 6. Core Protocol Messages

Required messages:

- HELLO_CLIENT
- HELLO_HOST_ACK
- JOIN_REQUEST
- JOIN_ACCEPTED
- JOIN_REJECTED
- LOBBY_STATE_SYNC
- PLAYER_IDENTITY_SELECT
- PLAYER_IDENTITY_CONFIRMED
- START_GAME
- ASSIGNMENT_DISTRIBUTION
- REVEAL_PROGRESS_UPDATE
- ALL_REVEALS_COMPLETE
- HEARTBEAT
- DISCONNECT_NOTICE

Protocol rules:
- Host broadcasts full LOBBY_STATE_SYNC on any state change.
- Clients only send intent messages, host validates and commits.
- Unknown messageType should be ignored and logged.
- protocolVersion mismatch should show incompatible version message.

## 7. Data Model Changes

### Session entities
- LobbySession
- sessionId
- hostDeviceId
- mode
- createdAt
- networkName

- ConnectedDevice
- deviceId
- displayName
- isHost
- connectionState
- selectedPlayerName optional
- lastHeartbeatAt

- PlayerAssignment
- playerName
- assignedDeviceId
- role
- word

### Streak linkage
- Keep streak logic based on playerName for now (current model).
- Add optional deviceAlias mapping for better continuity later.
- On join, user selects player name, then app shows streak badge from current local history sync.

Reasoning:
- Reusing playerName avoids account system complexity.
- Optional alias mapping gives a migration path to stronger identity later.

## 8. Role Distribution Algorithm

Inputs:
- Ordered player list from host.
- Ordered active device list.

Algorithm:
- Sort devices by join timestamp then host first.
- Assign each player index i to device index i mod deviceCount.
- Each device receives only players mapped to its deviceId.

Properties:
- Near-even distribution.
- Deterministic and easy to recompute after reconnect.
- No external state required.

Edge handling:
- If a client disconnects before Start Game, recompute and rebroadcast.
- If disconnects during reveal, host offers fallback:
- Reassign pending reveals to host, or
- Pause and wait for reconnect for N seconds.

## 9. Security and Privacy Model

- LAN only, no cloud relay.
- Optional lobby PIN to prevent accidental joins.
- Session tokens generated by host for each accepted client.
- Ignore commands from unknown deviceId/sessionId.
- Rate limit join attempts and malformed frames.
- Do not store network IP history in persistent storage.

## 10. UI/UX Additions

### New screens
- LobbyModeScreen
- HostLobbyScreen
- JoinLobbyScreen
- WaitingRoomScreen
- DistributedRevealScreen

### New UI behaviors
- Connected devices list with status chips.
- Player identity picker for joiners.
- Live badge preview for selected player streak.
- Reveal progress bar per device and global completion.

### Existing screen updates
- Play entry point includes Host and Join options.
- Players screen can run in host-owned mode with remote participants visible.
- Role reveal flow supports distributed subsets.

## 11. Streak Feature Enhancement in LAN Mode

- Host computes winners as today and updates game history.
- Host broadcasts round result summary.
- Clients update local streak views for selected identity.
- In waiting room, show:
- selected player name
- current streak
- best streak

Optional upgrade later:
- Sync compact streak snapshot in lobby sync so all devices show same values instantly.

## 12. Failure and Recovery Strategy

- Heartbeat every 2 seconds from host and clients.
- Mark device stale after 6 seconds without heartbeat.
- Show reconnect banner and automatic retry on client.
- If host dies, session ends with explicit message to clients.
- If client dies mid-reveal, host can absorb pending assignments.

Recovery UX:
- Fast reconnect button.
- Manual rejoin with remembered session if still active.

## 13. Performance Targets

- Lobby discovery visible within 2 to 5 seconds on same network.
- Join handshake under 1 second on stable Wi-Fi hotspot.
- Start game distribution message under 300 ms for 10 players.
- Smooth reveal animations with no frame drops on mid-range Android.

## 14. Implementation Plan by Phases

### Phase A: Foundation
- Add session models and protocol message classes.
- Add host WebSocket server manager.
- Add client WebSocket manager.
- Add mDNS advertise and browse wrappers.

### Phase B: Lobby UX
- Build host lobby and join lobby screens.
- Implement join handshake and lobby sync.
- Add player identity select and streak preview.

### Phase C: Distributed Reveal
- Add assignment partition logic.
- Build distributed reveal screen for subset processing.
- Add reveal progress reporting and completion barrier.

### Phase D: Reliability and polish
- Add heartbeats, stale detection, reconnect flows.
- Add optional lobby PIN.
- Add instrumentation logs for session events.
- Add reduced-motion compatibility in distributed flow.

### Phase E: Release hardening
- Full QA matrix across Android devices.
- Latency and disconnect simulation tests.
- Rules and onboarding updates for multiplayer flow.

## 15. QA Test Matrix

Functional tests:
- Host creates lobby, one client joins, game starts.
- Host creates lobby, multiple clients join, distribution is balanced.
- Client selects player identity and sees streak.
- Team mode + normal mode both run distributed reveal.

Failure tests:
- Client disconnect before start.
- Client disconnect during reveal.
- Host disconnect during session.
- Mixed app versions.

Network tests:
- Host hotspot network.
- Shared Wi-Fi network.
- Weak signal and packet loss simulation.

Regression tests:
- Single-device flow unchanged.
- Existing role assignment correctness unchanged.
- Existing streak calculations unchanged.

## 16. Risks and Mitigations

- Risk: mDNS behavior differs by Android vendor.
- Mitigation: add manual IP join fallback.

- Risk: local firewall blocks ports.
- Mitigation: retry with alternative ports and clear error guidance.

- Risk: player name collisions affect streak identity.
- Mitigation: show disambiguation prompt when duplicates exist.

- Risk: desync from reconnect edge cases.
- Mitigation: host sends full state snapshots after reconnect.

## 17. Proposed Acceptance Criteria

- Users can host and join a lobby over local network with no backend.
- Joiners can select player identity and see streak before game starts.
- Role reveal workload is distributed across connected phones.
- Game outcome and streak updates are consistent across host and clients.
- Single-device mode remains fully functional and unchanged in behavior.
- Reduced-motion setting is respected in new distributed reveal flow.

## 18. Nice-to-Have Follow-Ups

- QR code join with embedded session endpoint.
- Optional host transfer if host battery is low.
- Device trust memory for quick rejoin in future sessions.
- End-of-round LAN leaderboard card for social sharing.

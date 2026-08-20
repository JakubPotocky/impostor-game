import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'lan_session_state.dart';
import 'models/lobby_session.dart';
import 'models/connected_device.dart';
import 'protocol/lan_message.dart';
import 'services/host_server_manager.dart';
import 'services/client_manager.dart';
import 'services/mdns_service.dart';

const _kAppVersion = '1.0.0';

class LanSessionNotifier extends Notifier<LanSessionState> {
  final _host = HostServerManager();
  final _client = ClientManager();
  final _mdns = MdnsService();
  Timer? _heartbeatTimer;
  Timer? _staleCheckTimer;
  final String _myDeviceId = const Uuid().v4();

  @override
  LanSessionState build() {
    ref.onDispose(_dispose);
    _host.addMessageHandler(_onHostMessage);
    _host.addDisconnectHandler(_onClientDisconnected);
    _client.addMessageHandler(_onClientMessage);
    _client.addDisconnectCallback(_onHostDisconnected);
    return const LanSessionState();
  }

  // ── Host actions ──────────────────────────────────────────────────────────

  Future<void> createLobby({
    required String mode,
    required List<String> players,
    String? lobbyName,
  }) async {
    if (state.isActive) return;
    final session = LobbySession.create(
      hostDeviceId: _myDeviceId,
      mode: mode,
      networkName: 'local',
      lobbyName: lobbyName ?? 'Game Lobby',
    );
    final port = await _host.start(session.sessionId);
    await _mdns.startAdvertising(
      session: session,
      port: port,
      appVersion: _kAppVersion,
    );
    final hostDevice = ConnectedDevice(
      deviceId: _myDeviceId,
      displayName: 'Host',
      isHost: true,
      connectionState: DeviceConnectionState.connected,
      lastHeartbeatAt: DateTime.now(),
      joinOrder: 0,
    );
    state = state.copyWith(
      role: LanRole.host,
      phase: LanPhase.inLobby,
      session: session,
      devices: [hostDevice],
      myDeviceId: _myDeviceId,
      players: players,
    );
    _startHeartbeats();
    _startStaleCheck();
  }

  void updatePlayers(List<String> players) {
    if (!state.isHost) return;
    state = state.copyWith(players: players);
    _broadcastLobbyState();
  }

  void triggerStartGame() {
    if (!state.isHost) return;
    _host.broadcast(LanMessage.startGame(sessionId: state.session!.sessionId));
    state = state.copyWith(phase: LanPhase.inGame);
  }

  void distributeAssignments({
    required List<Map<String, dynamic>> allAssignments,
    required String word,
    required String themeName,
    required bool hintsEnabled,
    required bool reducedMotion,
  }) {
    if (!state.isHost) return;
    final session = state.session!;
    final devices = state.devices
        .where((d) => d.connectionState == DeviceConnectionState.connected)
        .toList()
      ..sort((a, b) => a.joinOrder.compareTo(b.joinOrder));

    final deviceCount = devices.length;
    final buckets = List.generate(deviceCount, (_) => <Map<String, dynamic>>[]);
    for (var i = 0; i < allAssignments.length; i++) {
      buckets[i % deviceCount].add(allAssignments[i]);
    }

    final progress = <String, DeviceRevealProgress>{};
    for (var i = 0; i < devices.length; i++) {
      final device = devices[i];
      final bucket = buckets[i];
      if (bucket.isEmpty) continue;
      progress[device.deviceId] = DeviceRevealProgress(
        deviceId: device.deviceId,
        completed: 0,
        total: bucket.length,
      );
      if (device.isHost) continue;
      _host.sendTo(
        device.deviceId,
        LanMessage.assignmentDistribution(
          sessionId: session.sessionId,
          targetDeviceId: device.deviceId,
          assignments: bucket,
          word: word,
          themeName: themeName,
          hintsEnabled: hintsEnabled,
          reducedMotion: reducedMotion,
        ),
      );
    }
    state = state.copyWith(revealProgress: progress);
  }

  // ── Client actions ────────────────────────────────────────────────────────

  Future<void> joinLobby(DiscoveredLobby lobby) async {
    if (state.isActive) return;
    state = state.copyWith(
      role: LanRole.client,
      phase: LanPhase.joining,
      myDeviceId: _myDeviceId,
    );
    try {
      await _client.connect(lobby.host, lobby.port);
      _client.send(LanMessage.helloClient(
        deviceId: _myDeviceId,
        displayName: 'Player',
        appVersion: _kAppVersion,
      ));
      _startHeartbeats();
    } catch (_) {
      state = state
          .copyWith(phase: LanPhase.idle, role: LanRole.none)
          .copyWith(error: 'Connection failed — is the host on the same network?');
    }
  }

  void selectPlayerIdentity(String playerName) {
    if (!state.isClient) return;
    final session = state.session;
    if (session == null) return;
    _client.send(LanMessage.playerIdentitySelect(
      sessionId: session.sessionId,
      deviceId: _myDeviceId,
      playerName: playerName,
      sessionToken: state.mySessionToken ?? '',
    ));
  }

  void reportRevealProgress(int completed, int total) {
    final session = state.session;
    if (session == null) return;
    final msg = LanMessage.revealProgressUpdate(
      sessionId: session.sessionId,
      deviceId: _myDeviceId,
      revealsCompleted: completed,
      revealsTotal: total,
    );
    if (state.isHost) {
      _onHostMessage(msg, _myDeviceId);
    } else {
      _client.send(msg);
    }
    if (completed >= total) {
      _checkAllRevealsComplete();
    }
  }

  Stream<DiscoveredLobby> browseLobbies() => _mdns.browseLobbies();
  Future<void> stopBrowsing() => _mdns.stopBrowsing();

  void clearError() => state = state.clearError();

  // ── Message handlers ──────────────────────────────────────────────────────

  void _onHostMessage(LanMessage msg, String fromDeviceId) {
    final session = state.session;
    if (session == null) return;

    if (msg.protocolVersion != '1.0') {
      _host.sendTo(fromDeviceId, LanMessage.joinRejected(
        sessionId: session.sessionId,
        reason: 'incompatible_version',
      ));
      return;
    }

    switch (msg.messageType) {
      case LanMessageType.helloClient:
        final deviceId = msg.payload['deviceId'] as String? ?? fromDeviceId;
        final displayName = msg.payload['displayName'] as String? ?? 'Guest';
        final updated = _upsertDevice(ConnectedDevice(
          deviceId: deviceId,
          displayName: displayName,
          isHost: false,
          connectionState: DeviceConnectionState.connecting,
          joinOrder: state.devices.length,
        ));
        state = state.copyWith(devices: updated);

      case LanMessageType.joinRequest:
        final deviceId = msg.payload['deviceId'] as String? ?? fromDeviceId;
        _host.sendTo(fromDeviceId, LanMessage.joinAccepted(
          sessionId: session.sessionId,
          deviceId: deviceId,
        ));
        final updated = state.devices.map((d) {
          if (d.deviceId == deviceId) {
            return d.copyWith(connectionState: DeviceConnectionState.connected);
          }
          return d;
        }).toList();
        state = state.copyWith(devices: updated);
        _broadcastLobbyState();

      case LanMessageType.playerIdentitySelect:
        final deviceId = msg.payload['deviceId'] as String? ?? fromDeviceId;
        final playerName = msg.payload['playerName'] as String?;
        if (playerName == null) return;
        final updated = state.devices.map((d) {
          if (d.deviceId == deviceId) return d.copyWith(selectedPlayerName: playerName);
          return d;
        }).toList();
        state = state.copyWith(devices: updated);
        _host.sendTo(fromDeviceId, LanMessage.playerIdentityConfirmed(
          sessionId: session.sessionId,
          deviceId: deviceId,
          playerName: playerName,
        ));
        _broadcastLobbyState();

      case LanMessageType.heartbeat:
        final deviceId = msg.payload['deviceId'] as String? ?? fromDeviceId;
        final updated = state.devices.map((d) {
          if (d.deviceId == deviceId) {
            return d.copyWith(
              lastHeartbeatAt: DateTime.now(),
              connectionState: DeviceConnectionState.connected,
            );
          }
          return d;
        }).toList();
        state = state.copyWith(devices: updated);

      case LanMessageType.revealProgressUpdate:
        final deviceId = msg.payload['deviceId'] as String? ?? fromDeviceId;
        final completed = (msg.payload['revealsCompleted'] as num?)?.toInt() ?? 0;
        final total = (msg.payload['revealsTotal'] as num?)?.toInt() ?? 0;
        final updated = Map<String, DeviceRevealProgress>.from(state.revealProgress);
        updated[deviceId] = DeviceRevealProgress(
          deviceId: deviceId,
          completed: completed,
          total: total,
        );
        state = state.copyWith(revealProgress: updated);
        _host.broadcast(msg);
        _checkAllRevealsComplete();

      case LanMessageType.disconnectNotice:
        final deviceId = msg.payload['deviceId'] as String? ?? fromDeviceId;
        _removeDevice(deviceId);

      default:
        break;
    }
  }

  void _onClientMessage(LanMessage msg) {
    switch (msg.messageType) {
      case LanMessageType.helloHostAck:
        final token = msg.payload['sessionToken'] as String?;
        state = state.copyWith(mySessionToken: token);
        _client.send(LanMessage.joinRequest(
          sessionId: msg.sessionId,
          deviceId: _myDeviceId,
          sessionToken: token ?? '',
        ));

      case LanMessageType.joinAccepted:
        state = state.copyWith(phase: LanPhase.inLobby);

      case LanMessageType.joinRejected:
        final reason = msg.payload['reason'] as String? ?? 'rejected';
        state = state.copyWith(phase: LanPhase.idle, role: LanRole.none).copyWith(error: reason);

      case LanMessageType.lobbyStateSync:
        final players = (msg.payload['players'] as List?)?.cast<String>() ?? state.players;
        final devicesJson = (msg.payload['devices'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final devices = devicesJson.map(ConnectedDevice.fromJson).toList();
        final sessionJson = msg.payload['session'] as Map<String, dynamic>?;
        final session = sessionJson != null ? LobbySession.fromJson(sessionJson) : state.session;
        state = state.copyWith(session: session, players: players, devices: devices);

      case LanMessageType.heartbeat:
        _client.send(LanMessage.heartbeat(
          sessionId: state.session?.sessionId ?? msg.sessionId,
          deviceId: _myDeviceId,
        ));

      case LanMessageType.startGame:
        state = state.copyWith(phase: LanPhase.inGame);

      case LanMessageType.assignmentDistribution:
        // Handled at UI layer (DistributedRevealScreen reads this from a stream).
        // Re-emit through a stream controller so the screen can act on it.
        _assignmentController.add(msg.payload);

      case LanMessageType.revealProgressUpdate:
        final deviceId = msg.payload['deviceId'] as String? ?? '';
        final completed = (msg.payload['revealsCompleted'] as num?)?.toInt() ?? 0;
        final total = (msg.payload['revealsTotal'] as num?)?.toInt() ?? 0;
        final updated = Map<String, DeviceRevealProgress>.from(state.revealProgress);
        updated[deviceId] = DeviceRevealProgress(
          deviceId: deviceId,
          completed: completed,
          total: total,
        );
        state = state.copyWith(revealProgress: updated);

      case LanMessageType.allRevealsComplete:
        _allRevealsController.add(null);

      default:
        break;
    }
  }

  void _onClientDisconnected(String deviceId) {
    if (!state.isHost) return;
    _removeDevice(deviceId);
    _recomputeRevealProgress();
  }

  void _onHostDisconnected() {
    if (!state.isClient) return;
    state = state.copyWith(phase: LanPhase.idle, role: LanRole.none)
        .copyWith(error: 'Host disconnected');
    _heartbeatTimer?.cancel();
  }

  // ── Streams for UI consumption ────────────────────────────────────────────

  final _assignmentController = StreamController<Map<String, dynamic>>.broadcast();
  final _allRevealsController = StreamController<void>.broadcast();

  Stream<Map<String, dynamic>> get assignmentStream => _assignmentController.stream;
  Stream<void> get allRevealsStream => _allRevealsController.stream;

  // ── Internal helpers ──────────────────────────────────────────────────────

  List<ConnectedDevice> _upsertDevice(ConnectedDevice device) {
    final existing = state.devices.any((d) => d.deviceId == device.deviceId);
    if (existing) {
      return state.devices.map((d) => d.deviceId == device.deviceId ? device : d).toList();
    }
    return [...state.devices, device];
  }

  void _broadcastLobbyState() {
    final session = state.session;
    if (session == null) return;
    _host.broadcast(LanMessage.lobbyStateSync(
      sessionId: session.sessionId,
      lobbyState: {
        'session': session.toJson(),
        'players': state.players,
        'devices': state.devices.map((d) => d.toJson()).toList(),
      },
    ));
  }

  void _removeDevice(String deviceId) {
    final updated = state.devices.where((d) => d.deviceId != deviceId).toList();
    state = state.copyWith(devices: updated);
    if (state.isHost) {
      _broadcastLobbyState();
    }
  }

  void _recomputeRevealProgress() {
    if (!state.isHost) return;
    final connectedIds = state.devices
        .where((d) => d.connectionState == DeviceConnectionState.connected)
        .map((d) => d.deviceId)
        .toSet();
    final updated = Map<String, DeviceRevealProgress>.from(state.revealProgress)
      ..removeWhere((id, _) => !connectedIds.contains(id));
    state = state.copyWith(revealProgress: updated);
  }

  void _checkAllRevealsComplete() {
    if (!state.isHost) return;
    if (state.allRevealsComplete && state.revealProgress.isNotEmpty) {
      _host.broadcast(LanMessage.allRevealsComplete(
        sessionId: state.session!.sessionId,
      ));
      _allRevealsController.add(null);
    }
  }

  void _startHeartbeats() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final session = state.session;
      if (session == null) return;
      final msg = LanMessage.heartbeat(sessionId: session.sessionId, deviceId: _myDeviceId);
      if (state.isHost) {
        _host.broadcast(msg);
      } else if (state.isClient) {
        _client.send(msg);
      }
    });
  }

  void _startStaleCheck() {
    _staleCheckTimer?.cancel();
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!state.isHost) return;
      final now = DateTime.now();
      final updated = state.devices.map((d) {
        if (d.isHost) return d;
        final last = d.lastHeartbeatAt;
        if (last == null) return d;
        if (now.difference(last).inSeconds > 6) {
          return d.copyWith(connectionState: DeviceConnectionState.stale);
        }
        return d;
      }).toList();
      if (updated.map((d) => d.connectionState).toList() !=
          state.devices.map((d) => d.connectionState).toList()) {
        state = state.copyWith(devices: updated);
      }
    });
  }

  Future<void> endSession() async {
    final session = state.session;
    if (session != null) {
      final notice = LanMessage.disconnectNotice(
        sessionId: session.sessionId,
        deviceId: _myDeviceId,
      );
      if (state.isHost) _host.broadcast(notice);
      if (state.isClient) _client.send(notice);
    }
    await _dispose();
    state = const LanSessionState();
  }

  Future<void> _dispose() async {
    _heartbeatTimer?.cancel();
    _staleCheckTimer?.cancel();
    _mdns.dispose();
    await _mdns.stopBrowsing();
    await _host.stop();
    await _client.disconnect();
    await _assignmentController.close();
    await _allRevealsController.close();
  }
}

final lanSessionProvider = NotifierProvider<LanSessionNotifier, LanSessionState>(
  LanSessionNotifier.new,
);

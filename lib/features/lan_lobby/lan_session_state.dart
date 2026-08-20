import 'models/lobby_session.dart';
import 'models/connected_device.dart';

enum LanRole { none, host, client }

enum LanPhase { idle, hosting, joining, inLobby, inGame }

class DeviceRevealProgress {
  final String deviceId;
  final int completed;
  final int total;

  const DeviceRevealProgress({
    required this.deviceId,
    required this.completed,
    required this.total,
  });
}

class LanSessionState {
  final LanRole role;
  final LanPhase phase;
  final LobbySession? session;
  final List<ConnectedDevice> devices;
  final String? myDeviceId;
  final String? mySessionToken;
  final String? error;
  final List<String> players;
  final Map<String, DeviceRevealProgress> revealProgress;

  const LanSessionState({
    this.role = LanRole.none,
    this.phase = LanPhase.idle,
    this.session,
    this.devices = const [],
    this.myDeviceId,
    this.mySessionToken,
    this.error,
    this.players = const [],
    this.revealProgress = const {},
  });

  bool get isActive => phase != LanPhase.idle;
  bool get isHost => role == LanRole.host;
  bool get isClient => role == LanRole.client;

  ConnectedDevice? get myDevice => myDeviceId == null
      ? null
      : devices.where((d) => d.deviceId == myDeviceId).firstOrNull;

  bool get allRevealsComplete {
    if (revealProgress.isEmpty) return false;
    return revealProgress.values.every((p) => p.completed >= p.total);
  }

  LanSessionState copyWith({
    LanRole? role,
    LanPhase? phase,
    LobbySession? session,
    List<ConnectedDevice>? devices,
    String? myDeviceId,
    String? mySessionToken,
    String? error,
    List<String>? players,
    Map<String, DeviceRevealProgress>? revealProgress,
  }) {
    return LanSessionState(
      role: role ?? this.role,
      phase: phase ?? this.phase,
      session: session ?? this.session,
      devices: devices ?? this.devices,
      myDeviceId: myDeviceId ?? this.myDeviceId,
      mySessionToken: mySessionToken ?? this.mySessionToken,
      error: error,
      players: players ?? this.players,
      revealProgress: revealProgress ?? this.revealProgress,
    );
  }

  LanSessionState clearError() => LanSessionState(
    role: role,
    phase: phase,
    session: session,
    devices: devices,
    myDeviceId: myDeviceId,
    mySessionToken: mySessionToken,
    error: null,
    players: players,
    revealProgress: revealProgress,
  );
}

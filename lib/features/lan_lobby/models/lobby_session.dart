import 'package:uuid/uuid.dart';

class LobbySession {
  final String sessionId;
  final String hostDeviceId;
  final String mode;
  final DateTime createdAt;
  final String networkName;
  final String lobbyName;
  final bool requiresPin;

  const LobbySession({
    required this.sessionId,
    required this.hostDeviceId,
    required this.mode,
    required this.createdAt,
    required this.networkName,
    required this.lobbyName,
    this.requiresPin = false,
  });

  factory LobbySession.create({
    required String hostDeviceId,
    required String mode,
    required String networkName,
    String? lobbyName,
    bool requiresPin = false,
  }) {
    return LobbySession(
      sessionId: const Uuid().v4(),
      hostDeviceId: hostDeviceId,
      mode: mode,
      createdAt: DateTime.now(),
      networkName: networkName,
      lobbyName: lobbyName ?? 'Game Lobby',
      requiresPin: requiresPin,
    );
  }

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'hostDeviceId': hostDeviceId,
    'mode': mode,
    'createdAt': createdAt.toIso8601String(),
    'networkName': networkName,
    'lobbyName': lobbyName,
    'requiresPin': requiresPin,
  };

  factory LobbySession.fromJson(Map<String, dynamic> json) => LobbySession(
    sessionId: json['sessionId'] as String,
    hostDeviceId: json['hostDeviceId'] as String,
    mode: json['mode'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    networkName: json['networkName'] as String,
    lobbyName: json['lobbyName'] as String,
    requiresPin: json['requiresPin'] as bool? ?? false,
  );
}

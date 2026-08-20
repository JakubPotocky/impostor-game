import 'dart:convert';

const _kProtocolVersion = '1.0';

enum LanMessageType {
  helloClient,
  helloHostAck,
  joinRequest,
  joinAccepted,
  joinRejected,
  lobbyStateSync,
  playerIdentitySelect,
  playerIdentityConfirmed,
  startGame,
  assignmentDistribution,
  revealProgressUpdate,
  allRevealsComplete,
  heartbeat,
  disconnectNotice,
}

class LanMessage {
  final LanMessageType messageType;
  final String sessionId;
  final Map<String, dynamic> payload;
  final String protocolVersion;

  const LanMessage({
    required this.messageType,
    required this.sessionId,
    required this.payload,
    this.protocolVersion = _kProtocolVersion,
  });

  String encode() => jsonEncode({
    'messageType': messageType.name,
    'sessionId': sessionId,
    'payload': payload,
    'protocolVersion': protocolVersion,
  });

  static LanMessage? tryDecode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final typeName = map['messageType'] as String?;
      final type = LanMessageType.values.firstWhere(
        (t) => t.name == typeName,
      );
      return LanMessage(
        messageType: type,
        sessionId: map['sessionId'] as String? ?? '',
        payload: (map['payload'] as Map<String, dynamic>?) ?? {},
        protocolVersion: map['protocolVersion'] as String? ?? _kProtocolVersion,
      );
    } catch (_) {
      return null;
    }
  }

  static LanMessage helloClient({
    required String deviceId,
    required String displayName,
    required String appVersion,
  }) => LanMessage(
    messageType: LanMessageType.helloClient,
    sessionId: '',
    payload: {
      'deviceId': deviceId,
      'displayName': displayName,
      'appVersion': appVersion,
    },
  );

  static LanMessage helloHostAck({
    required String sessionId,
    required String sessionToken,
    required String hostDeviceId,
    required String appVersion,
  }) => LanMessage(
    messageType: LanMessageType.helloHostAck,
    sessionId: sessionId,
    payload: {
      'sessionToken': sessionToken,
      'hostDeviceId': hostDeviceId,
      'appVersion': appVersion,
    },
  );

  static LanMessage joinRequest({
    required String sessionId,
    required String deviceId,
    required String sessionToken,
    String? pin,
  }) => LanMessage(
    messageType: LanMessageType.joinRequest,
    sessionId: sessionId,
    payload: {
      'deviceId': deviceId,
      'sessionToken': sessionToken,
      if (pin != null) 'pin': pin,
    },
  );

  static LanMessage joinAccepted({
    required String sessionId,
    required String deviceId,
  }) => LanMessage(
    messageType: LanMessageType.joinAccepted,
    sessionId: sessionId,
    payload: {'deviceId': deviceId},
  );

  static LanMessage joinRejected({
    required String sessionId,
    required String reason,
  }) => LanMessage(
    messageType: LanMessageType.joinRejected,
    sessionId: sessionId,
    payload: {'reason': reason},
  );

  static LanMessage lobbyStateSync({
    required String sessionId,
    required Map<String, dynamic> lobbyState,
  }) => LanMessage(
    messageType: LanMessageType.lobbyStateSync,
    sessionId: sessionId,
    payload: lobbyState,
  );

  static LanMessage playerIdentitySelect({
    required String sessionId,
    required String deviceId,
    required String playerName,
    required String sessionToken,
  }) => LanMessage(
    messageType: LanMessageType.playerIdentitySelect,
    sessionId: sessionId,
    payload: {
      'deviceId': deviceId,
      'playerName': playerName,
      'sessionToken': sessionToken,
    },
  );

  static LanMessage playerIdentityConfirmed({
    required String sessionId,
    required String deviceId,
    required String playerName,
  }) => LanMessage(
    messageType: LanMessageType.playerIdentityConfirmed,
    sessionId: sessionId,
    payload: {'deviceId': deviceId, 'playerName': playerName},
  );

  static LanMessage startGame({required String sessionId}) => LanMessage(
    messageType: LanMessageType.startGame,
    sessionId: sessionId,
    payload: {},
  );

  static LanMessage assignmentDistribution({
    required String sessionId,
    required String targetDeviceId,
    required List<Map<String, dynamic>> assignments,
    required String word,
    required String themeName,
    required bool hintsEnabled,
    required bool reducedMotion,
  }) => LanMessage(
    messageType: LanMessageType.assignmentDistribution,
    sessionId: sessionId,
    payload: {
      'targetDeviceId': targetDeviceId,
      'assignments': assignments,
      'word': word,
      'themeName': themeName,
      'hintsEnabled': hintsEnabled,
      'reducedMotion': reducedMotion,
    },
  );

  static LanMessage revealProgressUpdate({
    required String sessionId,
    required String deviceId,
    required int revealsCompleted,
    required int revealsTotal,
  }) => LanMessage(
    messageType: LanMessageType.revealProgressUpdate,
    sessionId: sessionId,
    payload: {
      'deviceId': deviceId,
      'revealsCompleted': revealsCompleted,
      'revealsTotal': revealsTotal,
    },
  );

  static LanMessage allRevealsComplete({required String sessionId}) => LanMessage(
    messageType: LanMessageType.allRevealsComplete,
    sessionId: sessionId,
    payload: {},
  );

  static LanMessage heartbeat({
    required String sessionId,
    required String deviceId,
  }) => LanMessage(
    messageType: LanMessageType.heartbeat,
    sessionId: sessionId,
    payload: {'deviceId': deviceId},
  );

  static LanMessage disconnectNotice({
    required String sessionId,
    required String deviceId,
    String? reason,
  }) => LanMessage(
    messageType: LanMessageType.disconnectNotice,
    sessionId: sessionId,
    payload: {
      'deviceId': deviceId,
      if (reason != null) 'reason': reason,
    },
  );
}

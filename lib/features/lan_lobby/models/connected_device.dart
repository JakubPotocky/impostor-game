enum DeviceConnectionState { connecting, connected, stale, disconnected }

class ConnectedDevice {
  final String deviceId;
  final String displayName;
  final bool isHost;
  final DeviceConnectionState connectionState;
  final String? selectedPlayerName;
  final DateTime? lastHeartbeatAt;
  final String? sessionToken;
  final int joinOrder;

  const ConnectedDevice({
    required this.deviceId,
    required this.displayName,
    required this.isHost,
    required this.connectionState,
    required this.joinOrder,
    this.selectedPlayerName,
    this.lastHeartbeatAt,
    this.sessionToken,
  });

  ConnectedDevice copyWith({
    String? displayName,
    DeviceConnectionState? connectionState,
    String? selectedPlayerName,
    DateTime? lastHeartbeatAt,
  }) {
    return ConnectedDevice(
      deviceId: deviceId,
      displayName: displayName ?? this.displayName,
      isHost: isHost,
      connectionState: connectionState ?? this.connectionState,
      selectedPlayerName: selectedPlayerName ?? this.selectedPlayerName,
      lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
      sessionToken: sessionToken,
      joinOrder: joinOrder,
    );
  }

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'displayName': displayName,
    'isHost': isHost,
    'connectionState': connectionState.name,
    'selectedPlayerName': selectedPlayerName,
    'joinOrder': joinOrder,
  };

  factory ConnectedDevice.fromJson(Map<String, dynamic> json) => ConnectedDevice(
    deviceId: json['deviceId'] as String,
    displayName: json['displayName'] as String,
    isHost: json['isHost'] as bool,
    connectionState: DeviceConnectionState.values.firstWhere(
      (s) => s.name == (json['connectionState'] as String?),
      orElse: () => DeviceConnectionState.connected,
    ),
    selectedPlayerName: json['selectedPlayerName'] as String?,
    joinOrder: (json['joinOrder'] as num?)?.toInt() ?? 0,
  );
}

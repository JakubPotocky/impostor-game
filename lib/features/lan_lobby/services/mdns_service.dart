import 'package:bonsoir/bonsoir.dart';
import '../models/lobby_session.dart';

const _kServiceType = '_impostor._tcp';

class DiscoveredLobby {
  final String name;
  final String host;
  final int port;
  final String mode;
  final String appVersion;
  final bool requiresPin;
  final String sessionId;

  const DiscoveredLobby({
    required this.name,
    required this.host,
    required this.port,
    required this.mode,
    required this.appVersion,
    required this.requiresPin,
    required this.sessionId,
  });
}

class MdnsService {
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;

  Future<void> startAdvertising({
    required LobbySession session,
    required int port,
    required String appVersion,
  }) async {
    await stopAdvertising();
    final service = BonsoirService(
      name: session.lobbyName,
      type: _kServiceType,
      port: port,
      attributes: {
        'lobbyName': session.lobbyName,
        'mode': session.mode,
        'appVersion': appVersion,
        'requiresPin': session.requiresPin.toString(),
        'sessionId': session.sessionId,
      },
    );
    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.ready;
    await _broadcast!.start();
  }

  Future<void> stopAdvertising() async {
    await _broadcast?.stop();
    _broadcast = null;
  }

  Stream<DiscoveredLobby> browseLobbies() async* {
    await _discovery?.stop();
    _discovery = BonsoirDiscovery(type: _kServiceType);
    await _discovery!.ready;
    await _discovery!.start();

    await for (final event in _discovery!.eventStream!) {
      if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
        event.service!.resolve(_discovery!.serviceResolver);
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved) {
        final resolved = event.service as ResolvedBonsoirService;
        final attrs = resolved.attributes;
        final host = resolved.host ?? '';
        if (host.isEmpty) continue;
        yield DiscoveredLobby(
          name: attrs['lobbyName'] ?? resolved.name,
          host: host,
          port: resolved.port,
          mode: attrs['mode'] ?? 'normal',
          appVersion: attrs['appVersion'] ?? '',
          requiresPin: attrs['requiresPin'] == 'true',
          sessionId: attrs['sessionId'] ?? '',
        );
      }
    }
  }

  Future<void> stopBrowsing() async {
    await _discovery?.stop();
    _discovery = null;
  }

  void dispose() {
    _broadcast?.stop();
    _discovery?.stop();
  }
}

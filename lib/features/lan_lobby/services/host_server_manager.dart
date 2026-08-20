import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart';
import '../protocol/lan_message.dart';

typedef HostMessageHandler = void Function(LanMessage message, String fromDeviceId);
typedef ClientDisconnectHandler = void Function(String deviceId);

class _ClientSocket {
  final WebSocket socket;
  final String deviceId;
  final String sessionToken;

  const _ClientSocket({
    required this.socket,
    required this.deviceId,
    required this.sessionToken,
  });
}

/// A pre-loaded static asset for the browser join page, kept in memory so
/// every request is served straight from RAM rather than re-reading the
/// Flutter asset bundle each time.
class _StaticAsset {
  final List<int> bytes;
  final String contentType;

  const _StaticAsset({required this.bytes, required this.contentType});
}

const Map<String, String> _webAssetPaths = {
  '/': 'assets/web_client/index.html',
  '/index.html': 'assets/web_client/index.html',
  '/app.js': 'assets/web_client/app.js',
  '/style.css': 'assets/web_client/style.css',
};

const Map<String, String> _webAssetContentTypes = {
  '/': 'text/html; charset=utf-8',
  '/index.html': 'text/html; charset=utf-8',
  '/app.js': 'application/javascript; charset=utf-8',
  '/style.css': 'text/css; charset=utf-8',
};

class HostServerManager {
  HttpServer? _server;
  String _sessionId = '';
  final Map<String, _ClientSocket> _clients = {};
  final List<HostMessageHandler> _messageHandlers = [];
  final List<ClientDisconnectHandler> _disconnectHandlers = [];
  bool _running = false;

  int get port => _server?.port ?? 0;
  bool get isRunning => _running;
  List<String> get connectedDeviceIds => List.unmodifiable(_clients.keys);

  void addMessageHandler(HostMessageHandler h) => _messageHandlers.add(h);
  void removeMessageHandler(HostMessageHandler h) => _messageHandlers.remove(h);
  void addDisconnectHandler(ClientDisconnectHandler h) => _disconnectHandlers.add(h);
  void removeDisconnectHandler(ClientDisconnectHandler h) => _disconnectHandlers.remove(h);

  Future<int> start(String sessionId) async {
    _sessionId = sessionId;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _running = true;
    _server!.listen(_handleRequest, onError: (_) {});
    return _server!.port;
  }

  void _handleRequest(HttpRequest request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocket socket;
      try {
        socket = await WebSocketTransformer.upgrade(request);
      } catch (_) {
        return;
      }
      _handleNewSocket(socket);
      return;
    }

    if (request.method == 'GET') {
      await _serveWebAsset(request);
      return;
    }

    request.response
      ..statusCode = HttpStatus.notFound
      ..close();
  }

  // ── Browser client static assets ────────────────────────────────────────

  Map<String, _StaticAsset>? _webAssetsCache;

  Future<Map<String, _StaticAsset>> _loadWebAssets() async {
    final cached = _webAssetsCache;
    if (cached != null) return cached;
    final assets = <String, _StaticAsset>{};
    for (final entry in _webAssetPaths.entries) {
      final data = await rootBundle.load(entry.value);
      assets[entry.key] = _StaticAsset(
        bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        contentType: _webAssetContentTypes[entry.key]!,
      );
    }
    _webAssetsCache = assets;
    return assets;
  }

  Future<void> _serveWebAsset(HttpRequest request) async {
    final assets = await _loadWebAssets();
    final asset = assets[request.uri.path];
    if (asset == null) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.set(HttpHeaders.contentTypeHeader, asset.contentType)
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..add(asset.bytes)
      ..close();
  }

  void _handleNewSocket(WebSocket socket) {
    String? clientDeviceId;
    bool helloReceived = false;

    socket.listen(
      (dynamic data) {
        final raw = data as String?;
        if (raw == null) return;
        final msg = LanMessage.tryDecode(raw);
        if (msg == null) return;

        if (!helloReceived) {
          if (msg.messageType != LanMessageType.helloClient) {
            socket.close(WebSocketStatus.policyViolation, 'expected_hello');
            return;
          }
          helloReceived = true;
          clientDeviceId = msg.payload['deviceId'] as String? ?? const Uuid().v4();
          final token = const Uuid().v4();
          _clients[clientDeviceId!] = _ClientSocket(
            socket: socket,
            deviceId: clientDeviceId!,
            sessionToken: token,
          );
          socket.add(LanMessage.helloHostAck(
            sessionId: _sessionId,
            sessionToken: token,
            hostDeviceId: 'host',
            appVersion: '1.0.0',
          ).encode());
          _fireMessage(msg, clientDeviceId!);
          return;
        }

        if (clientDeviceId != null) {
          _fireMessage(msg, clientDeviceId!);
        }
      },
      onError: (_) {
        if (clientDeviceId != null) _removeClient(clientDeviceId!);
      },
      onDone: () {
        if (clientDeviceId != null) _removeClient(clientDeviceId!);
      },
      cancelOnError: false,
    );
  }

  void _fireMessage(LanMessage msg, String deviceId) {
    for (final h in List.of(_messageHandlers)) {
      h(msg, deviceId);
    }
  }

  void _removeClient(String deviceId) {
    if (_clients.remove(deviceId) != null) {
      for (final h in List.of(_disconnectHandlers)) {
        h(deviceId);
      }
    }
  }

  void sendTo(String deviceId, LanMessage message) {
    final client = _clients[deviceId];
    if (client != null && client.socket.readyState == WebSocket.open) {
      client.socket.add(message.encode());
    }
  }

  void broadcast(LanMessage message) {
    final encoded = message.encode();
    for (final c in _clients.values) {
      if (c.socket.readyState == WebSocket.open) {
        c.socket.add(encoded);
      }
    }
  }

  Future<void> stop() async {
    _running = false;
    for (final c in List.of(_clients.values)) {
      await c.socket.close(WebSocketStatus.normalClosure, 'host_stopped');
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }
}

import 'dart:async';
import 'dart:io';
import '../protocol/lan_message.dart';

typedef ClientMessageHandler = void Function(LanMessage message);
typedef ClientDisconnectCallback = void Function();

class ClientManager {
  WebSocket? _socket;
  StreamSubscription? _sub;
  final List<ClientMessageHandler> _messageHandlers = [];
  final List<ClientDisconnectCallback> _disconnectCallbacks = [];
  bool _connected = false;

  bool get isConnected => _connected;

  void addMessageHandler(ClientMessageHandler h) => _messageHandlers.add(h);
  void removeMessageHandler(ClientMessageHandler h) => _messageHandlers.remove(h);
  void addDisconnectCallback(ClientDisconnectCallback h) => _disconnectCallbacks.add(h);
  void removeDisconnectCallback(ClientDisconnectCallback h) => _disconnectCallbacks.remove(h);

  Future<void> connect(String host, int port) async {
    await disconnect();
    _socket = await WebSocket.connect('ws://$host:$port');
    _connected = true;
    _sub = _socket!.listen(
      (dynamic data) {
        final raw = data as String?;
        if (raw == null) return;
        final msg = LanMessage.tryDecode(raw);
        if (msg == null) return;
        for (final h in List.of(_messageHandlers)) {
          h(msg);
        }
      },
      onError: (_) => _handleDisconnect(),
      onDone: () => _handleDisconnect(),
      cancelOnError: false,
    );
  }

  void send(LanMessage message) {
    if (_connected && _socket?.readyState == WebSocket.open) {
      _socket!.add(message.encode());
    }
  }

  void _handleDisconnect() {
    _connected = false;
    _sub?.cancel();
    _sub = null;
    for (final cb in List.of(_disconnectCallbacks)) {
      cb();
    }
  }

  Future<void> disconnect() async {
    _connected = false;
    await _sub?.cancel();
    _sub = null;
    await _socket?.close(WebSocketStatus.normalClosure, 'client_disconnect');
    _socket = null;
  }
}

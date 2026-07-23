import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants.dart';

class WebSocketClient {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;
  String? _token;
  String? _driverId;
  Timer? _reconnectTimer;
  bool _disposed = false;

  void setToken(String token) {
    _token = token;
  }

  void setDriverId(String driverId) {
    _driverId = driverId;
  }

  Stream<Map<String, dynamic>> get stream =>
      (_controller ??= StreamController.broadcast()).stream;

  void connect() {
    if (_disposed || _token == null) return;

    // WS_URL already points at the realtime-gateway's /ws endpoint; only
    // append /ws if the configured URL doesn't already end with it.
    final base = ApiConstants.wsUrl;
    final wsUrl = base.endsWith('/ws') ? base : '$base/ws';
    final uri = Uri.parse(wsUrl);
    _channel = WebSocketChannel.connect(
      uri,
      protocols: [_token!],
    );

    _channel!.stream.listen(
      (data) {
        try {
          final parsed = jsonDecode(data as String);
          if (parsed is Map<String, dynamic>) {
            _controller?.add(parsed);
          }
        } catch (_) {}
      },
      onDone: _scheduleReconnect,
      onError: _scheduleReconnect,
    );

    if (_driverId != null && _driverId!.isNotEmpty) {
      _subscribeToDriver(_driverId!);
    }
  }

  void _subscribeToDriver(String driverId) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'subscribe': 'driver:$driverId',
      }));
    }
  }

  void _scheduleReconnect([_]) {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  void disconnect() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _controller?.close();
  }
}

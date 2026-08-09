import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api.dart';

class WsService {
  static final WsService _instance = WsService._();
  factory WsService() => _instance;
  WsService._();

  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  bool get isConnected => _channel != null;

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  Future<void> connect() async {
    if (_channel != null) return;
    try {
      final base = Api.baseUrl;
      final wsBase = base.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
      final token = await Api.getToken();
      if (token == null) return;
      final uri = Uri.parse('$wsBase/ws?token=$token');
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            _controller.add(json);
          } catch (_) {}
        },
        onDone: () {
          _channel = null;
        },
        onError: (_) {
          _channel = null;
        },
      );
    } catch (_) {}
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  /// Push a JSON frame up the socket. Used for ephemeral events that
  /// don't need a REST round-trip, like live-location pings while a
  /// "share live location" chat session is active.
  void send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/network/websocket_client.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';

/// Holds the live chat with the customer for the driver's current trip.
/// Messages arrive in real time over the shared WebSocket (type=chat.message)
/// and are sent through the message-service, which bridges to WhatsApp.
class ChatProvider extends ChangeNotifier {
  final ChatService _service;
  final WebSocketClient _ws;
  StreamSubscription? _wsSub;

  String? _tripId;
  bool _active = false;
  bool _loading = false;
  int _unread = 0;
  final List<ChatMessage> _messages = [];

  ChatProvider(this._service, this._ws) {
    _wsSub = _ws.stream.listen(_onWsEvent);
  }

  String? get tripId => _tripId;
  bool get active => _active;
  bool get loading => _loading;
  int get unread => _unread;
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void _onWsEvent(Map<String, dynamic> event) {
    if ((event['type'] ?? '') != 'chat.message') return;
    final tripId = (event['trip_id'] ?? '').toString();
    if (_tripId != null && tripId != _tripId) return;
    _messages.add(ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      tripId: tripId,
      sender: (event['sender'] ?? 'customer').toString(),
      text: (event['text'] ?? '').toString(),
      createdAt: DateTime.now(),
    ));
    _unread++;
    notifyListeners();
  }

  /// Opens (or switches to) the conversation for a trip and loads history.
  Future<void> open(String tripId,
      {String driverRefId = '', String customerRefId = '', String orderId = ''}) async {
    _tripId = tripId;
    _loading = true;
    _unread = 0;
    notifyListeners();
    await _service.openRoom(tripId,
        driverRefId: driverRefId, customerRefId: customerRefId, orderId: orderId);
    final (active, history) = await _service.fetchRoom(tripId);
    _active = active;
    _messages
      ..clear()
      ..addAll(history);
    _loading = false;
    notifyListeners();
  }

  /// Loads a trip's chat history read-only, WITHOUT opening/reactivating the
  /// room (used to review past conversations after a trip finished).
  Future<void> openHistory(String tripId) async {
    _tripId = tripId;
    _loading = true;
    _unread = 0;
    notifyListeners();
    final (_, history) = await _service.fetchRoom(tripId);
    _active = false; // history view is always read-only
    _messages
      ..clear()
      ..addAll(history);
    _loading = false;
    notifyListeners();
  }

  void markRead() {
    if (_unread == 0) return;
    _unread = 0;
    notifyListeners();
  }

  Future<bool> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || _tripId == null || !_active) return false;
    final msg = await _service.send(_tripId!, t);
    if (msg != null) {
      _messages.add(msg);
    } else {
      _messages.add(ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        tripId: _tripId!,
        sender: 'driver',
        text: t,
        createdAt: DateTime.now(),
      ));
    }
    notifyListeners();
    return true;
  }

  /// Marks the room closed locally (trip finished) and clears context.
  void close() {
    _active = false;
    notifyListeners();
  }

  void reset() {
    _tripId = null;
    _active = false;
    _unread = 0;
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }
}

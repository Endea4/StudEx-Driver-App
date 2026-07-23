import 'dart:convert';
import '../core/network/api_client.dart';
import '../core/constants.dart';
import '../models/chat.dart';

class ChatService {
  final ApiClient _api;
  ChatService(this._api);

  /// Loads the room status + message history for a trip.
  /// Returns (isActive, messages).
  Future<(bool, List<ChatMessage>)> fetchRoom(String tripId) async {
    final res = await _api.get(ApiConstants.chatRoom(tripId));
    if (res.statusCode != 200) return (false, <ChatMessage>[]);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final room = data['room'] as Map<String, dynamic>?;
    final active = (room?['status'] ?? '') == 'active';
    final list = (data['messages'] as List? ?? [])
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
    return (active, list);
  }

  Future<ChatMessage?> send(String tripId, String text) async {
    final res = await _api.post(ApiConstants.chatSend(tripId), body: {
      'sender': 'driver',
      'text': text,
    });
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return ChatMessage.fromJson(data['message'] as Map<String, dynamic>);
  }

  Future<void> openRoom(String tripId,
      {String driverRefId = '', String customerRefId = '', String orderId = ''}) async {
    await _api.post(ApiConstants.chatOpen(tripId), body: {
      'driver_ref_id': driverRefId,
      'customer_ref_id': customerRefId,
      'order_id': orderId,
    });
  }
}

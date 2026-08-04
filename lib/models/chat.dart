class ChatMessage {
  final String id;
  final String tripId;
  final String sender; // 'driver' | 'customer' | 'system'
  final String text;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.tripId,
    required this.sender,
    required this.text,
    required this.createdAt,
  });

  bool get isDriver => sender == 'driver';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      tripId: (json['trip_id'] ?? '').toString(),
      sender: (json['sender'] ?? 'system').toString(),
      text: (json['text'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
    );
  }
}

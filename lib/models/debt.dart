class Debt {
  final String id;
  final String orderId;
  final int amount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? paidAt;

  Debt({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.isActive,
    required this.createdAt,
    this.paidAt,
  });

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'] ?? '',
      orderId: json['order_id'] ?? '',
      amount: json['amount'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
    );
  }
}

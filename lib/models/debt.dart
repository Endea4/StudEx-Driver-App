class Debt {
  final String id;
  final String orderId;
  final String orderNumber;
  final String driverPhone;
  final double amount;
  final double remaining;
  final String status;
  final bool isActive;
  final String description;
  final DateTime createdAt;
  final DateTime? paidAt;

  Debt({
    required this.id,
    required this.orderId,
    this.orderNumber = '',
    this.driverPhone = '',
    required this.amount,
    this.remaining = 0,
    this.status = '',
    required this.isActive,
    this.description = '',
    required this.createdAt,
    this.paidAt,
  });

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'] ?? '',
      orderId: json['order_id'] ?? '',
      orderNumber: json['order_number'] ?? '',
      driverPhone: json['driver_phone'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      remaining: (json['remaining'] ?? 0).toDouble(),
      status: json['status'] ?? '',
      isActive: json['is_active'] ?? true,
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
    );
  }
}

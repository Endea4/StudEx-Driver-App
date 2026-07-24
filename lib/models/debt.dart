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

  /// True only for money the driver actually owes.
  ///
  /// The backend writes one record per completed trip — `earned` for a normal
  /// cash fare and `unpaid` when the passenger left a debt. Treating every
  /// record as a debt (the old `is_active` default) listed earnings under
  /// "Daftar Utang" and inflated the total owed.
  bool get isOutstanding {
    final s = status.toLowerCase();
    return s == 'unpaid' || s == 'disputed' || s == 'partial';
  }

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

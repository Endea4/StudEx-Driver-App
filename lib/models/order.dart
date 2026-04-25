class Order {
  final String id;
  final String status;
  final String serviceType;
  final String originLabel;
  final String destinationLabel;
  final String? itemOriginLabel;
  final int estimatedPrice;
  final int finalPrice;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.status,
    required this.serviceType,
    required this.originLabel,
    required this.destinationLabel,
    this.itemOriginLabel,
    this.estimatedPrice = 0,
    this.finalPrice = 0,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      status: json['status'] ?? '',
      serviceType: json['service_type'] ?? '',
      originLabel: json['origin_label'] ?? '',
      destinationLabel: json['destination_label'] ?? '',
      itemOriginLabel: json['item_origin_label'],
      estimatedPrice: json['estimated_price'] ?? 0,
      finalPrice: json['final_price'] ?? 0,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

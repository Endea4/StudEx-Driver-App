class Order {
  final String id;
  final String status;
  final String serviceType;
  final String originLabel;
  final String destinationLabel;
  final String? itemOriginLabel;
  final int estimatedPrice;
  final int finalPrice;
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;
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
    this.pickupLat = 0,
    this.pickupLng = 0,
    this.destLat = 0,
    this.destLng = 0,
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
      pickupLat: (json['pickup_lat'] ?? 0).toDouble(),
      pickupLng: (json['pickup_lng'] ?? 0).toDouble(),
      destLat: (json['dest_lat'] ?? 0).toDouble(),
      destLng: (json['dest_lng'] ?? 0).toDouble(),
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  String get pickupDisplay {
    if (originLabel.isNotEmpty) return originLabel;
    if (pickupLat != 0 && pickupLng != 0) return '${pickupLat.toStringAsFixed(4)}, ${pickupLng.toStringAsFixed(4)}';
    return 'Pickup';
  }

  String get destDisplay {
    if (destinationLabel.isNotEmpty) return destinationLabel;
    if (destLat != 0 && destLng != 0) return '${destLat.toStringAsFixed(4)}, ${destLng.toStringAsFixed(4)}';
    return 'Destination';
  }
}

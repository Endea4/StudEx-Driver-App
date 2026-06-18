class PendingRating {
  final String id;
  final String orderId;
  final String customerName;
  final String serviceType;
  final String origin;
  final String destination;
  final bool driverResponded;

  PendingRating({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.serviceType,
    required this.origin,
    required this.destination,
    this.driverResponded = false,
  });

  factory PendingRating.fromJson(Map<String, dynamic> json) {
    return PendingRating(
      id: json['id'] ?? '',
      orderId: json['order_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      serviceType: json['service_type'] ?? '',
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      driverResponded: json['driver_responded'] ?? false,
    );
  }
}

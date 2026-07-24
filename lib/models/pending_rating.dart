class PendingRating {
  final String id;
  final String orderId;
  final String customerName;
  final String serviceType;
  final String origin;
  final String destination;
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;
  final double finalPrice;
  final bool driverResponded;

  PendingRating({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.serviceType,
    required this.origin,
    required this.destination,
    this.pickupLat = 0,
    this.pickupLng = 0,
    this.destLat = 0,
    this.destLng = 0,
    this.finalPrice = 0,
    this.driverResponded = false,
  });

  /// True when the trip's route coordinates are available (so the UI can show
  /// reverse-geocoded place names instead of an empty row).
  bool get hasRoute => pickupLat != 0 || destLat != 0;

  factory PendingRating.fromJson(Map<String, dynamic> json) {
    return PendingRating(
      id: json['id'] ?? '',
      orderId: json['order_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      serviceType: json['service_type'] ?? '',
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      pickupLat: (json['pickup_lat'] ?? 0).toDouble(),
      pickupLng: (json['pickup_lng'] ?? 0).toDouble(),
      destLat: (json['dest_lat'] ?? 0).toDouble(),
      destLng: (json['dest_lng'] ?? 0).toDouble(),
      finalPrice: (json['final_price'] ?? 0).toDouble(),
      driverResponded: json['driver_responded'] ?? false,
    );
  }
}

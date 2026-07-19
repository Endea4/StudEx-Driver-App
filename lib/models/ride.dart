class RideOffer {
  final String orderId;
  final String requestId;
  final String customerRefId;
  final String serviceType;
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;
  final double estimatedPrice;
  final double score;

  RideOffer({
    required this.orderId,
    required this.requestId,
    required this.customerRefId,
    required this.serviceType,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
    required this.estimatedPrice,
    required this.score,
  });

  factory RideOffer.fromJson(Map<String, dynamic> json) {
    return RideOffer(
      orderId: json['order_id'] ?? '',
      requestId: json['request_id'] ?? '',
      customerRefId: json['customer_ref_id'] ?? '',
      serviceType: json['service_type'] ?? '',
      pickupLat: (json['pickup_lat'] ?? 0).toDouble(),
      pickupLng: (json['pickup_lng'] ?? 0).toDouble(),
      destLat: (json['dest_lat'] ?? 0).toDouble(),
      destLng: (json['dest_lng'] ?? 0).toDouble(),
      estimatedPrice: (json['estimated_price'] ?? 0).toDouble(),
      score: (json['score'] ?? 0).toDouble(),
    );
  }
}

class ActiveTrip {
  final String id;
  final String orderId;
  final String status;
  final String serviceType;
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;
  final double finalPrice;
  final double currentBidPrice;
  final String? lastBidder;
  final String? reason;
  final String paymentStatus;

  ActiveTrip({
    required this.id,
    required this.orderId,
    required this.status,
    required this.serviceType,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
    this.finalPrice = 0,
    this.currentBidPrice = 0,
    this.lastBidder,
    this.reason,
    this.paymentStatus = '',
  });

  factory ActiveTrip.fromJson(Map<String, dynamic> json) {
    return ActiveTrip(
      id: json['id'] ?? '',
      orderId: json['order_id'] ?? '',
      status: json['status'] ?? '',
      serviceType: json['service_type'] ?? '',
      pickupLat: (json['pickup_lat'] ?? 0).toDouble(),
      pickupLng: (json['pickup_lng'] ?? 0).toDouble(),
      destLat: (json['dest_lat'] ?? 0).toDouble(),
      destLng: (json['dest_lng'] ?? 0).toDouble(),
      finalPrice: (json['final_price'] ?? 0).toDouble(),
      currentBidPrice: (json['current_bid_price'] ?? 0).toDouble(),
      lastBidder: json['last_bidder'],
      reason: json['reason'],
      paymentStatus: json['payment_status'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_id': orderId,
    'status': status,
    'service_type': serviceType,
    'pickup_lat': pickupLat,
    'pickup_lng': pickupLng,
    'dest_lat': destLat,
    'dest_lng': destLng,
    'final_price': finalPrice,
    'current_bid_price': currentBidPrice,
    'last_bidder': lastBidder,
    'reason': reason,
    'payment_status': paymentStatus,
  };
}

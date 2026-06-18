class Driver {
  final String id;
  final String phone;
  final String name;
  final String displayName;
  final String gender;
  final String vehicleType;
  final String plateNumber;
  final String profilePhoto;
  final List<String> inventory;
  final bool isActive;
  final String status;
  final double reputationScore;
  final int totalOrders;
  final int totalRejects;
  final int totalCancels;
  final int totalIncome;

  Driver({
    required this.id,
    required this.phone,
    required this.name,
    required this.displayName,
    required this.gender,
    required this.vehicleType,
    required this.plateNumber,
    this.profilePhoto = '',
    this.inventory = const [],
    required this.isActive,
    required this.status,
    this.reputationScore = 0,
    this.totalOrders = 0,
    this.totalRejects = 0,
    this.totalCancels = 0,
    this.totalIncome = 0,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle_info'] as Map<String, dynamic>? ?? {};
    final metrics = json['performance_metrics'] as Map<String, dynamic>? ?? {};

    String phone = '';
    if (json['phone_wa_primary'] != null) {
      phone = json['phone_wa_primary'].toString();
    } else if (json['phone'] is List && (json['phone'] as List).isNotEmpty) {
      phone = json['phone'][0].toString();
    } else if (json['phone'] is String) {
      phone = json['phone'];
    }

    bool isActive = json['is_active'] ?? false;
    if (!isActive && json['driver_status'] == 'READY') {
      isActive = true;
    }

    String status = json['driver_status']?.toString().isNotEmpty == true
        ? json['driver_status']
        : json['checkpoint_status'] ?? json['status'] ?? 'offline';

    return Driver(
      id: json['id'] ?? '',
      phone: phone,
      name: json['fullname'] ?? json['name'] ?? '',
      displayName: json['display_name']?.toString().isNotEmpty == true
          ? json['display_name']
          : json['fullname'] ?? json['name'] ?? '',
      gender: json['gender'] ?? '',
      vehicleType: vehicle['vehicle_type'] ?? json['vehicle_type'] ?? '',
      plateNumber: vehicle['license_plate'] ?? json['plate_number'] ?? '',
      profilePhoto: json['profile_photo'] ?? '',
      inventory: json['inventory'] != null ? List<String>.from(json['inventory']) : [],
      isActive: isActive,
      status: status,
      reputationScore: (metrics['average_rating'] ?? json['reputation_score'] ?? 0).toDouble(),
      totalOrders: metrics['completed_orders'] ?? metrics['total_orders'] ?? json['total_orders'] ?? 0,
      totalRejects: metrics['failed_orders'] ?? json['total_rejects'] ?? 0,
      totalCancels: json['total_cancels'] ?? metrics['failed_orders'] ?? json['total_cancels'] ?? 0,
      totalIncome: (metrics['total_earnings'] ?? json['total_income'] ?? 0).toInt(),
    );
  }
}

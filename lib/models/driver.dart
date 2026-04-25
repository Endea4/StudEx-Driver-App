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
    return Driver(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      name: json['name'] ?? '',
      displayName: json['display_name'] ?? '',
      gender: json['gender'] ?? '',
      vehicleType: json['vehicle_type'] ?? '',
      plateNumber: json['plate_number'] ?? '',
      profilePhoto: json['profile_photo'] ?? '',
      inventory: json['inventory'] != null ? List<String>.from(json['inventory']) : [],
      isActive: json['is_active'] ?? false,
      status: json['status'] ?? 'offline',
      reputationScore: (json['reputation_score'] ?? 0).toDouble(),
      totalOrders: json['total_orders'] ?? 0,
      totalRejects: json['total_rejects'] ?? 0,
      totalCancels: json['total_cancels'] ?? 0,
      totalIncome: json['total_income'] ?? 0,
    );
  }
}

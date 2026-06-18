import 'env_config.dart';

class ApiConstants {
  static const String baseUrl = EnvConfig.serverUrl;
  static const String realtimeUrl = EnvConfig.realtimeUrl;
  static const String wsUrl = EnvConfig.wsUrl;

  static const String auth = '/drivers/auth';
  static const String authLogout = '/drivers/auth/logout';
  static const String driverMe = '/drivers/me';
  static const String driverStatus = '/drivers/me/status';
  static const String locationUpdate = '/location';
  static const String driverDebts = '/drivers/debts';
  static const String driverRatingsPending = '/drivers/ratings/pending';
  static const String driverRatings = '/drivers/ratings';
  static const String driverOrders = '/drivers/orders';
  static const String driverReputation = '/drivers/reputation';
}

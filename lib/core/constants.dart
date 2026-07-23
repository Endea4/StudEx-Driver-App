import 'env_config.dart';

class ApiConstants {
  static const String baseUrl = EnvConfig.serverUrl;
  static const String realtimeUrl = EnvConfig.realtimeUrl;
  static const String wsUrl = EnvConfig.wsUrl;

  static const String auth = '/drivers/auth';
  static const String authLogout = '/auth/logout';
  static const String driverMe = '/users';
  static const String driverStatus = '/drivers/status';
  static const String locationUpdate = '/location';
  static const String driverDebts = '/drivers/debts';
  static const String driverRatingsPending = '/drivers/ratings/pending';
  static const String driverRatings = '/drivers/ratings';
  static const String driverOrders = '/drivers/orders';
  static const String driverReputation = '/drivers/reputation';

  // Chat / message-service (bridged to the customer's WhatsApp)
  static String chatRoom(String tripId) => '/messages/rooms/$tripId';
  static String chatSend(String tripId) => '/messages/rooms/$tripId/send';
  static String chatOpen(String tripId) => '/messages/rooms/$tripId/open';
}

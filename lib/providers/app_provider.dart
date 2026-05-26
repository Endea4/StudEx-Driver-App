import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/network/websocket_client.dart';
import '../core/storage/local_storage.dart';
import '../services/auth_service.dart';
import '../services/history_service.dart';
import '../services/debt_service.dart';
import '../services/rating_service.dart';
import '../services/reputation_service.dart';
import '../services/location_service.dart';

class AppProvider extends ChangeNotifier {
  final ApiClient apiClient;
  final WebSocketClient wsClient;
  final LocalStorage localStorage;
  late final AuthService authService;
  late final HistoryService historyService;
  late final DebtService debtService;
  late final RatingService ratingService;
  late final ReputationService reputationService;
  late final LocationService locationService;

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AppProvider({
    required this.localStorage,
  })  : apiClient = ApiClient(),
        wsClient = WebSocketClient() {
    authService = AuthService(apiClient, localStorage);
    historyService = HistoryService(apiClient);
    debtService = DebtService(apiClient);
    ratingService = RatingService(apiClient);
    reputationService = ReputationService(apiClient);
    locationService = LocationService(localStorage);

    final token = localStorage.getToken();
    if (token != null && token.isNotEmpty) {
      apiClient.setToken(token);
      wsClient.setToken(token);
      final driverId = localStorage.getDriverId();
      if (driverId != null && driverId.isNotEmpty) {
        wsClient.setDriverId(driverId);
      }
      _isAuthenticated = true;
      wsClient.connect();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> signIn(String phone, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final driver = await authService.signIn(phone, password);
      await localStorage.savePhone(phone);
      final token = localStorage.getToken();
      if (token != null && token.isNotEmpty) {
        wsClient.setToken(token);
      }
      final driverId = await localStorage.getDriverId();
      if (driverId != null && driverId.isNotEmpty) {
        wsClient.setDriverId(driverId);
      }
      _isAuthenticated = true;
      wsClient.connect();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    try {
      locationService.stopStreaming();
      wsClient.disconnect();
      await authService.logout();
    } catch (_) {}
    await localStorage.clear();
    apiClient.clearToken();
    _isAuthenticated = false;
    notifyListeners();
  }
}

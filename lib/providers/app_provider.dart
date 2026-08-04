import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/network/websocket_client.dart';
import '../core/storage/local_storage.dart';
import '../core/errors.dart';
import '../services/auth_service.dart';
import '../services/history_service.dart';
import '../services/debt_service.dart';
import '../services/rating_service.dart';
import '../services/reputation_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/push_service.dart';

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
  StreamSubscription? _wsSubscription;

  // Latest incoming ride offer received via WS
  Map<String, dynamic>? _latestRideOffer;
  Map<String, dynamic>? get latestRideOffer => _latestRideOffer;
  void setLatestRideOffer(Map<String, dynamic>? offer) {
    _latestRideOffer = offer;
    notifyListeners();
  }
  void clearLatestOffer() { _latestRideOffer = null; }

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AppProvider({
    required this.localStorage,
  })  : apiClient = ApiClient(),
        wsClient = WebSocketClient() {
    authService = AuthService(apiClient, localStorage);
    historyService = HistoryService(apiClient, localStorage);
    debtService = DebtService(apiClient, localStorage);
    ratingService = RatingService(apiClient, localStorage);
    reputationService = ReputationService(apiClient, localStorage);
    locationService = LocationService(apiClient, localStorage);

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
      _syncFcmToken();
    }

    _listenWs();
    PushService.instance.onTokenRefresh((token) => _sendFcmToken(token));
  }

  Future<void> _syncFcmToken() async {
    final token = await PushService.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await _sendFcmToken(token);
    }
  }

  Future<void> _sendFcmToken(String token) async {
    try {
      await authService.updateProfile({'fcm_token': token});
    } catch (_) {}
  }

  // Owns the single, app-lifetime WS subscription that drives OS
  // notifications, so notifications keep firing regardless of which screen
  // is currently mounted (DashboardScreen previously held this subscription
  // itself and cancelled it in dispose() the moment the driver navigated
  // away, silently dropping every event until Dashboard was reopened).
  void _listenWs() {
    _wsSubscription = wsClient.stream.listen((event) {
      final type = event['type'] as String? ?? '';
      if (type == 'match.completed') {
        NotificationService.instance.show('Pesanan Baru!', 'Ada pesanan masuk');
        setLatestRideOffer(event['data'] as Map<String, dynamic>?);
      } else if (type == 'trip.created') {
        NotificationService.instance.show('Trip Dibuat', 'Trip menunggu konfirmasi');
      } else if (type == 'trip.started') {
        NotificationService.instance.show('Trip Dimulai', 'Perjalanan dimulai');
      } else if (type == 'trip.completed') {
        NotificationService.instance.show('Trip Selesai', 'Perjalanan selesai');
      } else if (type == 'trip.cancelled') {
        NotificationService.instance.show('Trip Dibatalkan', 'Perjalanan dibatalkan');
      }
      // match.timeout ("tidak ada driver tersedia") is addressed to the
      // customer who is still waiting for a match; it says nothing to a
      // driver, so it is deliberately not surfaced here.
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
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
      _syncFcmToken();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(friendlyError(e));
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

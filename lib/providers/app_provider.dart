import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/nav.dart';
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

  // Latest incoming ride offer received via WS. Offers expire server-side
  // (trip-service rejects them as "ignored by driver" after
  // [RideProvider.offerTimeout]); the getter self-expires so a stale offer is
  // never replayed into the Ride screen, where accepting it would only yield
  // "Trip tidak ditemukan".
  Map<String, dynamic>? _latestRideOffer;
  DateTime? _latestRideOfferAt;
  Map<String, dynamic>? get latestRideOffer {
    if (_latestRideOffer != null &&
        _latestRideOfferAt != null &&
        DateTime.now().difference(_latestRideOfferAt!) > const Duration(seconds: 180)) {
      _latestRideOffer = null;
    }
    return _latestRideOffer;
  }

  void setLatestRideOffer(Map<String, dynamic>? offer) {
    _latestRideOffer = offer;
    _latestRideOfferAt = DateTime.now();
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
        // Auto-open the Ride screen so the driver sees the offer immediately
        // instead of having to find it via Menu → Ride. Skipped when already
        // there (RideProvider updates that screen in place).
        if (currentRouteName != '/ride') {
          navigatorKey.currentState?.pushNamed('/ride');
        }
      } else if (type == 'trip.created') {
        NotificationService.instance.show('Trip Dibuat', 'Trip menunggu konfirmasi');
      } else if (type == 'trip.started') {
        NotificationService.instance.show('Trip Dimulai', 'Perjalanan dimulai');
      } else if (type == 'trip.completed') {
        NotificationService.instance.show('Trip Selesai', 'Perjalanan selesai');
      } else if (type == 'trip.cancelled') {
        NotificationService.instance.show('Trip Dibatalkan', 'Perjalanan dibatalkan');
        // The offer (if any) is dead now — trip-service cancels ignored offers
        // after the response window. Drop it so it can't be replayed stale.
        clearLatestOffer();
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

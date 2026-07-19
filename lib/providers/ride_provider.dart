import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/network/websocket_client.dart';
import '../core/storage/local_storage.dart';
import '../services/ride_service.dart';
import '../models/ride.dart';

enum RideState { idle, offer, active, bidRequest, completed }

class RideProvider extends ChangeNotifier {
  final ApiClient _api;
  final WebSocketClient _ws;
  final LocalStorage _storage;
  late final RideService rideService;
  StreamSubscription? _wsSub;

  RideState _state = RideState.idle;
  RideOffer? _currentOffer;
  ActiveTrip? _activeTrip;
  String? _error;
  bool _isLoading = false;

  RideState get state => _state;
  RideOffer? get currentOffer => _currentOffer;
  ActiveTrip? get activeTrip => _activeTrip;
  String? get error => _error;
  bool get isLoading => _isLoading;

  RideProvider(this._api, this._ws, this._storage) {
    rideService = RideService(_api);
    _listenWs();
  }

  void _listenWs() {
    debugPrint('[RideProvider] Subscribing to WS stream...');
    _wsSub = _ws.stream.listen((event) {
      debugPrint('[RideProvider] WS event: ${event['type']}');
      final type = event['type'] as String? ?? '';
      final data = event['data'] as Map<String, dynamic>? ?? {};
      debugPrint('[RideProvider] type=$type');

      switch (type) {
        case 'match.completed':
          debugPrint('[RideProvider] Processing match.completed, data=${event['data']}');
          _currentOffer = RideOffer.fromJson(data);
          _state = RideState.offer;
          _error = null;
          debugPrint('[RideProvider] State → OFFER, orderId=${_currentOffer?.orderId}');
          notifyListeners();
          break;

        case 'trip.created':
          _activeTrip = ActiveTrip.fromJson(data);
          if (_state != RideState.offer) {
            _state = RideState.active;
            _currentOffer = null;
          }
          _error = null;
          notifyListeners();
          break;

        case 'trip.started':
          if (_activeTrip != null) {
            _activeTrip = ActiveTrip.fromJson({...data, 'id': _activeTrip!.id, 'orderId': _activeTrip!.orderId});
          }
          _state = RideState.active;
          notifyListeners();
          break;

        case 'trip.completed':
          if (_activeTrip != null) {
            _activeTrip = ActiveTrip.fromJson(data);
          }
          _state = RideState.completed;
          notifyListeners();
          break;

        case 'trip.bargaining':
          if (_activeTrip != null) {
            _activeTrip = ActiveTrip.fromJson(data);
          }
          _state = RideState.bidRequest;
          notifyListeners();
          break;

        case 'trip.cancelled':
          _reset();
          break;
      }
    });
  }

  Future<bool> acceptOffer() async {
    if (_currentOffer == null) return false;
    _setLoading(true);
    try {
      final driverId = _storage.getDriverId();
      final pending = await rideService.fetchPendingTrip(driverId ?? '');
      if (pending != null && pending['id'] != null) {
        _activeTrip = await rideService.acceptTrip(pending['id'] as String);
        _state = RideState.active;
        _currentOffer = null;
        return true;
      }
      _setError('Trip tidak ditemukan');
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> rejectOffer({String reason = ''}) async {
    String? tripId;
    try {
      final driverId = _storage.getDriverId();
      final pending = await rideService.fetchPendingTrip(driverId ?? '');
      if (pending != null && pending['id'] != null) {
        tripId = pending['id'] as String;
      }
    } catch (_) {}

    _currentOffer = null;
    _state = RideState.idle;
    notifyListeners();

    if (tripId != null) {
      try {
        await rideService.rejectTrip(tripId, reason: reason);
      } catch (_) {}
    }
    return true;
  }

  Future<bool> startTrip() async {
    if (_activeTrip == null) return false;
    _setLoading(true);
    try {
      _activeTrip = await rideService.startTrip(_activeTrip!.id);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> completeTrip({bool isDebt = false}) async {
    if (_activeTrip == null) return false;
    _setLoading(true);
    try {
      _activeTrip = await rideService.completeTrip(
        _activeTrip!.id,
        paymentStatus: isDebt ? 'debt' : 'paid',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> submitBid(double amount, {String reason = ''}) async {
    if (_activeTrip == null) return false;
    _setLoading(true);
    try {
      _activeTrip = await rideService.submitBid(_activeTrip!.id, amount, reason: reason);
      _state = RideState.active;
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> acceptDeal() async {
    if (_activeTrip == null) return false;
    _setLoading(true);
    try {
      _activeTrip = await rideService.dealTrip(_activeTrip!.id);
      _state = RideState.active;
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void testSimulateOffer() {
    _currentOffer = RideOffer(
      orderId: 'test-001',
      requestId: 'req-001',
      customerRefId: 'cust123',
      serviceType: 'anjem',
      pickupLat: -7.558,
      pickupLng: 110.827,
      destLat: -7.768,
      destLng: 110.839,
      estimatedPrice: 15000,
      score: 0.95,
    );
    _state = RideState.offer;
    _error = null;
    notifyListeners();
  }

  void testSimulateOfferFromData(Map<String, dynamic> data) {
    _currentOffer = RideOffer.fromJson(data);
    _state = RideState.offer;
    _error = null;
    notifyListeners();
  }

  void resumeActiveTrip(Map<String, dynamic> data) {
    _activeTrip = ActiveTrip.fromJson(data);
    _state = RideState.active;
    _currentOffer = null;
    _error = null;
    notifyListeners();
  }

  void _reset() {
    _state = RideState.idle;
    _currentOffer = null;
    _activeTrip = null;
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? e) {
    _error = e;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }
}

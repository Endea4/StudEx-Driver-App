import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/network/websocket_client.dart';
import '../core/storage/local_storage.dart';
import '../services/ride_service.dart';
import '../models/ride.dart';
import '../core/constants.dart';

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

        case 'trip.deal':
          // The deal event payload omits status/service_type/coords; force
          // status=deal and preserve prior trip fields so the ride screen
          // renders the "Start Trip" action for the agreed price.
          if (_activeTrip != null) {
            _activeTrip = ActiveTrip.fromJson({
              ...data,
              'id': _activeTrip!.id,
              'order_id': _activeTrip!.orderId,
              'status': 'deal',
              'service_type': _activeTrip!.serviceType,
              'pickup_lat': _activeTrip!.pickupLat,
              'pickup_lng': _activeTrip!.pickupLng,
              'dest_lat': _activeTrip!.destLat,
              'dest_lng': _activeTrip!.destLng,
            });
          } else {
            _activeTrip = ActiveTrip.fromJson({...data, 'status': 'deal'});
          }
          _state = RideState.active;
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
            _activeTrip = ActiveTrip.fromJson({...data, 'id': _activeTrip!.id, 'orderId': _activeTrip!.orderId});
          }
          _state = RideState.completed;
          notifyListeners();
          break;

        case 'trip.bargaining':
          // The bargaining event omits status/service_type/coords; keep the
          // prior trip fields and force status=bargaining so the driver sees
          // the bid-response UI (accept the counter or re-bid).
          _activeTrip = ActiveTrip.fromJson({
            if (_activeTrip != null) ...{
              'id': _activeTrip!.id,
              'service_type': _activeTrip!.serviceType,
              'pickup_lat': _activeTrip!.pickupLat,
              'pickup_lng': _activeTrip!.pickupLng,
              'dest_lat': _activeTrip!.destLat,
              'dest_lng': _activeTrip!.destLng,
            },
            ...data,
            'status': 'bargaining',
          });
          _state = RideState.bidRequest;
          _error = null;
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
        // Open the chat room now that the driver has accepted.
        _openChatRoom(_activeTrip!.id, driverId ?? '', _activeTrip!.customerRefId);
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

  // Best-effort: tell the message-service to open the trip's chat room.
  void _openChatRoom(String tripId, String driverRefId, String customerRefId) {
    _api.post(ApiConstants.chatOpen(tripId), body: {
      'driver_ref_id': driverRefId,
      'customer_ref_id': customerRefId,
    }).then((_) {}, onError: (_) {});
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

  Future<bool> completeTrip({bool isDebt = false, double debtAmount = 0}) async {
    if (_activeTrip == null) return false;
    _setLoading(true);
    try {
      _activeTrip = await rideService.completeTrip(
        _activeTrip!.id,
        paymentStatus: isDebt ? 'debt' : 'paid',
        debtAmount: debtAmount,
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
      // Stay in the bid view so the driver can see the negotiation and accept
      // the customer's counter (instead of dropping to the plain active view).
      _state = RideState.bidRequest;
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

  void resumeBidRequest(Map<String, dynamic> data) {
    _activeTrip = ActiveTrip.fromJson(data);
    _state = RideState.bidRequest;
    _currentOffer = null;
    _error = null;
    notifyListeners();
  }

  void reset() => _reset();

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

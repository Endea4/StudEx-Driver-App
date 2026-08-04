import 'dart:async';
import 'dart:convert';
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

  List<Map<String, dynamic>> _tripHistory = [];
  bool _isLoadingTrips = false;
  List<Map<String, dynamic>> get tripHistory => _tripHistory;
  bool get isLoadingTrips => _isLoadingTrips;

  Future<void> fetchTrips() async {
    _isLoadingTrips = true;
    notifyListeners();
    try {
      final driverId = _storage.getDriverId();
      final res = await _api.get('/trips/driver/$driverId');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          _tripHistory = data.cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
    _isLoadingTrips = false;
    notifyListeners();
  }

  /// A one-off failure from a driver action (bid, deal, start, complete).
  /// Unlike [error] this must NOT replace the screen — the trip is still
  /// valid, the action just did not go through — so the UI shows it as a
  /// snackbar and clears it via [clearActionError].
  String? get actionError => _actionError;
  String? _actionError;

  void clearActionError() {
    _actionError = null;
  }

  void _setActionError(Object e) {
    _actionError = e.toString().replaceFirst('Exception: ', '');
    notifyListeners();
  }
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
          // The "Ride" menu's trip-history list is a separate REST snapshot;
          // refresh it now so it reflects the completion without requiring
          // the driver to close and reopen the screen.
          fetchTrips();
          break;

        case 'trip.bargaining':
          // The bargaining event omits status/service_type/coords. Start from
          // the event, then backfill anything it left out from the trip we
          // already hold — putting the event first meant its absent/zero
          // coords wiped the route, leaving an empty map and "Jemput: -".
          final merged = <String, dynamic>{...data, 'status': 'bargaining'};
          void keep(String key, dynamic prior) {
            final v = merged[key];
            if (v == null || v == 0 || v == '') merged[key] = prior;
          }
          if (_activeTrip != null) {
            keep('id', _activeTrip!.id);
            keep('service_type', _activeTrip!.serviceType);
            keep('pickup_lat', _activeTrip!.pickupLat);
            keep('pickup_lng', _activeTrip!.pickupLng);
            keep('dest_lat', _activeTrip!.destLat);
            keep('dest_lng', _activeTrip!.destLng);
          }
          _activeTrip = ActiveTrip.fromJson(merged);
          _state = RideState.bidRequest;
          _error = null;
          notifyListeners();
          // If we still have no route (e.g. the app restarted mid-negotiation
          // and held no prior trip), pull the full trip from the backend.
          if (_activeTrip!.pickupLat == 0 && _activeTrip!.destLat == 0) {
            _refreshTripFromBackend();
          }
          break;

        case 'trip.cancelled':
          _reset();
          fetchTrips();
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
      _setActionError(e);
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
      // Set locally rather than waiting for the trip.completed WS event to
      // bounce back -- if that event is delayed or missed, the screen was
      // getting stuck showing the active/map view for an already-completed
      // trip, even after leaving and re-entering the Ride screen.
      _state = RideState.completed;
      notifyListeners();
      fetchTrips();
      return true;
    } catch (e) {
      _setActionError(e);
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
      _setActionError(e);
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
      _setActionError(e);
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

  /// Re-reads the driver's current trip so a partial realtime event cannot
  /// leave the UI without a pickup/destination.
  Future<void> _refreshTripFromBackend() async {
    try {
      final driverId = _storage.getDriverId();
      if (driverId == null || driverId.isEmpty) return;
      final pending = await rideService.fetchPendingTrip(driverId);
      if (pending == null) return;
      final full = ActiveTrip.fromJson(pending);
      if (full.id != _activeTrip?.id) return;
      _activeTrip = full;
      notifyListeners();
    } catch (_) {}
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

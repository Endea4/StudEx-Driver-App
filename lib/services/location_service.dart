import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/network/api_client.dart';
import '../core/storage/local_storage.dart';

class LocationService {
  final ApiClient _api;
  final LocalStorage _storage;
  StreamSubscription<Position>? _positionSubscription;
  bool _isStreaming = false;
  DateTime? _lastSent;
  static const _minInterval = Duration(seconds: 3);

  // Exposes the driver's live position to the UI (e.g. the trip map's live
  // marker/re-routing) -- separate from _sendLocationUpdate below, which is
  // the fire-and-forget push to the backend and was previously the only
  // consumer of the GPS stream.
  final ValueNotifier<Position?> positionNotifier = ValueNotifier(null);

  LocationService(this._api, this._storage);

  bool get isStreaming => _isStreaming;

  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  void startStreaming() {
    if (_isStreaming) return;
    _isStreaming = true;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.low,
      distanceFilter: 10,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      positionNotifier.value = position;
      _sendLocationUpdate(position.latitude, position.longitude);
    });
  }

  Future<void> _sendLocationUpdate(double lat, double lng) async {
    final now = DateTime.now();
    if (_lastSent != null && now.difference(_lastSent!) < _minInterval) return;
    _lastSent = now;

    try {
      final driverId = await _storage.getDriverId();
      if (driverId == null || driverId.isEmpty) return;

      await http.post(
        Uri.parse('${ApiConstants.realtimeUrl}/location'),
        headers: _api.currentHeaders,
        body: jsonEncode({
          'ref_id': driverId,
          'latitude': lat,
          'longitude': lng,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<void> setGpsStatus(bool active) async {
    try {
      final driverId = await _storage.getDriverId();
      if (driverId == null || driverId.isEmpty) return;

      await _api.put(
        '/location/$driverId/gps-status',
        body: {'gps_active': active},
      );
    } catch (_) {}
  }

  void stopStreaming() {
    _isStreaming = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/storage/local_storage.dart';

class LocationService {
  final LocalStorage _storage;
  StreamSubscription<Position>? _positionSubscription;
  bool _isStreaming = false;

  LocationService(this._storage);

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
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _sendLocationUpdate(position.latitude, position.longitude);
    });
  }

  Future<void> _sendLocationUpdate(double lat, double lng) async {
    try {
      final driverId = await _storage.getDriverId();
      if (driverId == null || driverId.isEmpty) return;

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.locationUpdate}');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driver_id': driverId,
          'latitude': lat,
          'longitude': lng,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  void stopStreaming() {
    _isStreaming = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}

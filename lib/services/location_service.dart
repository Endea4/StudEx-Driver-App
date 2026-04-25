import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../core/network/websocket_client.dart';

class LocationService {
  final WebSocketClient _ws;
  StreamSubscription<Position>? _positionSubscription;
  bool _isStreaming = false;

  LocationService(this._ws);

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
      _ws.sendLocation(position.latitude, position.longitude);
    });
  }

  void stopStreaming() {
    _isStreaming = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}

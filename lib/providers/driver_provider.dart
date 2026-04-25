import 'package:flutter/foundation.dart';
import '../models/driver.dart';
import '../services/auth_service.dart';
import '../core/storage/local_storage.dart';

class DriverProvider extends ChangeNotifier {
  final AuthService _authService;

  Driver? _driver;
  bool _isLoading = false;
  String? _error;

  Driver? get driver => _driver;
  bool get isLoading => _isLoading;
  String? get error => _error;

  DriverProvider(this._authService);

  Future<void> fetchProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _driver = await _authService.getProfile();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateStatus(String status, {String? reason}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _driver = await _authService.updateStatus(status, reason: reason);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

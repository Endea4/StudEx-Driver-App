import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/driver.dart';
import '../services/auth_service.dart';
import '../core/network/api_client.dart';
import '../core/constants.dart';
import '../core/storage/local_storage.dart';
import '../core/errors.dart';

class DriverProvider extends ChangeNotifier {
  final AuthService _authService;
  final ApiClient _api;

  Driver? _driver;
  double _reputationScore = 0;
  int _totalReviews = 0;
  bool _isLoading = false;
  String? _error;

  Driver? get driver => _driver;
  double get reputationScore => _reputationScore;
  int get totalReviews => _totalReviews;
  bool get isLoading => _isLoading;
  String? get error => _error;

  DriverProvider(this._authService, this._api);

  Future<void> fetchProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _driver = await _authService.getProfile();
      // Fetch reputation from reputation API
      await _fetchReputation();
    } catch (e) {
      _error = friendlyError(e);
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
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> fields) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _driver = await _authService.updateProfile(fields);
      return true;
    } catch (e) {
      _error = friendlyError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword(String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final ok = await _authService.changePassword(newPassword);
      return ok;
    } catch (e) {
      _error = friendlyError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchReputation() async {
    try {
      final res = await _api.get('/drivers/reputation');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _reputationScore = (data['score'] ?? 0).toDouble();
        _totalReviews = (data['total_reviews'] ?? 0).toInt();
      } else {
        _reputationScore = 0;
        _totalReviews = 0;
      }
    } catch (_) {
      _reputationScore = 0;
      _totalReviews = 0;
    }
  }
}

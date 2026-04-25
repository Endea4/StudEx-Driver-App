import 'package:flutter/foundation.dart';
import '../models/reputation.dart';
import '../services/reputation_service.dart';

class ReputationProvider extends ChangeNotifier {
  final ReputationService _service;

  Reputation? _reputation;
  bool _isLoading = false;
  String? _error;

  Reputation? get reputation => _reputation;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ReputationProvider(this._service);

  Future<void> fetchReputation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _reputation = await _service.getReputation();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

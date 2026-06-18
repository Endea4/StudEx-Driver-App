import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../services/history_service.dart';
import '../core/errors.dart';

class HistoryProvider extends ChangeNotifier {
  final HistoryService _service;

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  HistoryProvider(this._service);

  Future<void> fetchOrders({int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _orders = await _service.getOrders(limit: limit);
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

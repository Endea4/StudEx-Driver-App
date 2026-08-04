import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/network/websocket_client.dart';
import '../models/order.dart';
import '../services/history_service.dart';
import '../core/errors.dart';

class HistoryProvider extends ChangeNotifier {
  final HistoryService _service;
  final WebSocketClient? _ws;
  StreamSubscription? _wsSub;

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  HistoryProvider(this._service, [this._ws]) {
    // Income figures are computed client-side from `orders`, so without this
    // they only refresh on a manual pull-to-refresh or full screen remount.
    _wsSub = _ws?.stream.listen((event) {
      final type = event['type'] as String? ?? '';
      if (type == 'trip.completed' || type == 'trip.cancelled') {
        fetchOrders();
      }
    });
  }

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

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';
import '../models/debt.dart';
import '../services/debt_service.dart';

class DebtProvider extends ChangeNotifier {
  final DebtService _service;

  List<Debt> _debts = [];
  bool _isLoading = false;
  String? _error;

  List<Debt> get debts => _debts;
  List<Debt> get activeDebts => _debts.where((d) => d.isActive).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  DebtProvider(this._service);

  Future<void> fetchDebts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _debts = await _service.getDebts();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

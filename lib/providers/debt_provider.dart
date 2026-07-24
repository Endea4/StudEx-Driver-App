import 'package:flutter/foundation.dart';
import '../models/debt.dart';
import '../services/debt_service.dart';
import '../core/errors.dart';

class DebtProvider extends ChangeNotifier {
  final DebtService _service;

  List<Debt> _debts = [];
  bool _isLoading = false;
  String? _error;

  List<Debt> get debts => _debts;
  List<Debt> get activeDebts => _debts.where((d) => d.isOutstanding).toList();
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
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> confirmPaid(String debtId) async {
    try {
      final ok = await _service.confirmPaid(debtId);
      if (ok) {
        // Refresh list
        await fetchDebts();
      }
      return ok;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }
}

import 'dart:convert';
import '../core/network/api_client.dart';
import '../core/constants.dart';
import '../core/storage/local_storage.dart';
import '../models/debt.dart';

class DebtService {
  final ApiClient _api;
  final LocalStorage _storage;

  DebtService(this._api, this._storage);

  Future<List<Debt>> getDebts() async {
    final phone = _storage.getPhone();
    final res = await _api.get('${ApiConstants.driverDebts}?phone=$phone');
    if (res.statusCode == 200) {
      final dynamic data = jsonDecode(res.body);
      if (data == null) return <Debt>[];
      final List<dynamic> list = data is List ? data : (data is Map && data['debts'] != null ? data['debts'] as List<dynamic> : <dynamic>[]);
      return list.map((e) => Debt.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to fetch debts');
    }
  }

  Future<bool> confirmPaid(String debtId) async {
    final res = await _api.put('${ApiConstants.driverDebts}/$debtId/pay');
    return res.statusCode == 200;
  }
}

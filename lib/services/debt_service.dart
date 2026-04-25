import 'dart:convert';
import '../core/network/api_client.dart';
import '../core/constants.dart';
import '../models/debt.dart';

class DebtService {
  final ApiClient _api;

  DebtService(this._api);

  Future<List<Debt>> getDebts() async {
    final res = await _api.get(ApiConstants.driverDebts);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data is List ? data : data['debts'] ?? [];
      return list.map((e) => Debt.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch debts');
    }
  }
}

import 'dart:convert';
import '../core/network/api_client.dart';
import '../core/constants.dart';
import '../models/order.dart';

class HistoryService {
  final ApiClient _api;

  HistoryService(this._api);

  Future<List<Order>> getOrders({int limit = 20, int offset = 0}) async {
    final res = await _api.get(
      '${ApiConstants.driverOrders}?limit=$limit&offset=$offset',
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data is List ? data : data['orders'] ?? [];
      return list.map((e) => Order.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch orders');
    }
  }
}

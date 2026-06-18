import 'dart:convert';
import '../core/network/api_client.dart';
import '../core/constants.dart';
import '../core/storage/local_storage.dart';
import '../models/order.dart';

class HistoryService {
  final ApiClient _api;
  final LocalStorage _storage;

  HistoryService(this._api, this._storage);

  Future<List<Order>> getOrders({int limit = 20, int offset = 0}) async {
    final phone = _storage.getPhone();
    final res = await _api.get(
      '${ApiConstants.driverOrders}?phone=$phone&limit=$limit&offset=$offset',
    );
    if (res.statusCode == 200) {
      final dynamic data = jsonDecode(res.body);
      final List<dynamic> list = data is List ? data : (data is Map && data['orders'] != null ? data['orders'] as List<dynamic> : <dynamic>[]);
      return list.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (res.statusCode == 400 || res.statusCode == 401) {
      throw Exception('Sesi berakhir. Silakan login ulang.');
    }
    throw Exception('Failed to fetch orders');
  }
}

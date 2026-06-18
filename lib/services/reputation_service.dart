import 'dart:convert';
import '../core/network/api_client.dart';
import '../core/constants.dart';
import '../core/storage/local_storage.dart';
import '../models/reputation.dart';

class ReputationService {
  final ApiClient _api;
  final LocalStorage _storage;

  ReputationService(this._api, this._storage);

  Future<Reputation?> getReputation() async {
    final phone = _storage.getPhone();
    final res = await _api.get('${ApiConstants.driverReputation}?phone=$phone');
    if (res.statusCode == 200) {
      return Reputation.fromJson(jsonDecode(res.body));
    } else if (res.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to fetch reputation');
    }
  }
}

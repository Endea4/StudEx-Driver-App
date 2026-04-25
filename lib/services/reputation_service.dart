import 'dart:convert';
import '../core/network/api_client.dart';
import '../core/constants.dart';
import '../models/reputation.dart';

class ReputationService {
  final ApiClient _api;

  ReputationService(this._api);

  Future<Reputation> getReputation() async {
    final res = await _api.get(ApiConstants.driverReputation);
    if (res.statusCode == 200) {
      return Reputation.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Failed to fetch reputation');
    }
  }
}

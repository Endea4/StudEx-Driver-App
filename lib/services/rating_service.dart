import 'dart:convert';
import '../core/network/api_client.dart';
import '../core/constants.dart';
import '../core/storage/local_storage.dart';
import '../models/pending_rating.dart';

class RatingService {
  final ApiClient _api;
  final LocalStorage _storage;

  RatingService(this._api, this._storage);

  Future<List<PendingRating>> getPendingRatings() async {
    final phone = _storage.getPhone();
    final res = await _api.get('${ApiConstants.driverRatingsPending}?phone=$phone');
    if (res.statusCode == 200) {
      final dynamic data = jsonDecode(res.body);
      if (data == null) return <PendingRating>[];
      final List<dynamic> list = data is List ? data : (data is Map && data['ratings'] != null ? data['ratings'] as List<dynamic> : <dynamic>[]);
      return list.map((e) => PendingRating.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to fetch pending ratings');
    }
  }

  Future<void> submitRating(String ratingId, int score, {String? review}) async {
    final body = <String, dynamic>{'score': score};
    if (review != null) body['review'] = review;
    final res = await _api.post('${ApiConstants.driverRatings}/$ratingId', body: body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to submit rating');
    }
  }
}

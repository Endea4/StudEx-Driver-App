import 'dart:convert';
import '../core/network/api_client.dart';
import '../core/constants.dart';
import '../models/pending_rating.dart';

class RatingService {
  final ApiClient _api;

  RatingService(this._api);

  Future<List<PendingRating>> getPendingRatings() async {
    final res = await _api.get(ApiConstants.driverRatingsPending);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data is List ? data : data['ratings'] ?? [];
      return list.map((e) => PendingRating.fromJson(e)).toList();
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

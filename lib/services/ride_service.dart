import 'dart:convert';
import '../core/network/api_client.dart';
import '../models/ride.dart';

class RideService {
  final ApiClient _api;

  RideService(this._api);

  Future<Map<String, dynamic>?> fetchPendingTrip(String driverRefId) async {
    final res = await _api.get('/trips/driver/$driverRefId');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is List && data.isNotEmpty) {
        for (final t in data) {
          final status = t['status'] ?? '';
          if (status == 'pending_acceptance' || status == 'bargaining') {
            return t as Map<String, dynamic>;
          }
        }
      }
    }
    return null;
  }

  Future<ActiveTrip> acceptTrip(String tripId) async {
    final res = await _api.put('/trips/$tripId/accept');
    if (res.statusCode == 200) {
      return ActiveTrip.fromJson(jsonDecode(res.body));
    }
    throw Exception('Gagal menerima trip: ${res.body}');
  }

  Future<void> rejectTrip(String tripId, {String reason = ''}) async {
    final body = <String, dynamic>{};
    if (reason.isNotEmpty) body['reason'] = reason;
    await _api.put('/trips/$tripId/reject', body: body);
  }

  Future<ActiveTrip> startTrip(String tripId) async {
    final res = await _api.put('/trips/$tripId/start');
    if (res.statusCode == 200) {
      return ActiveTrip.fromJson(jsonDecode(res.body));
    }
    throw Exception('Gagal memulai trip: ${res.body}');
  }

  Future<ActiveTrip> completeTrip(String tripId, {String paymentStatus = 'paid'}) async {
    final res = await _api.put('/trips/$tripId/complete', body: {
      'payment_status': paymentStatus,
    });
    if (res.statusCode == 200) {
      return ActiveTrip.fromJson(jsonDecode(res.body));
    }
    throw Exception('Gagal menyelesaikan trip: ${res.body}');
  }

  Future<ActiveTrip> submitBid(String tripId, double amount) async {
    final res = await _api.put('/trips/$tripId/bid', body: {
      'bid_price': amount,
    });
    if (res.statusCode == 200) {
      return ActiveTrip.fromJson(jsonDecode(res.body));
    }
    throw Exception('Gagal mengirim bid: ${res.body}');
  }
}

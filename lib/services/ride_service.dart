import 'dart:convert';
import '../core/network/api_client.dart';
import '../models/ride.dart';

/// A failed API call, carrying a message that is safe to show to the driver.
///
/// The backend replies with `{"error":"..."}`; dumping that raw JSON (or a
/// Dart "Exception:" prefix) on screen is meaningless to a driver, so known
/// causes are mapped to plain Indonesian and anything unknown falls back to a
/// generic line.
class RideException implements Exception {
  final String message;
  const RideException(this.message);
  @override
  String toString() => message;

  factory RideException.from(String action, String body) {
    var reason = '';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) {
        reason = decoded['error'].toString();
      }
    } catch (_) {}

    const known = {
      'same party already bid, wait for the other side':
          'Bid kamu sudah terkirim. Tunggu balasan penumpang dulu.',
      'trip not found': 'Pesanan ini sudah tidak berlaku.',
      'invalid trip status': 'Status pesanan sudah berubah. Muat ulang halaman.',
    };
    final mapped = known[reason.toLowerCase()];
    if (mapped != null) return RideException(mapped);
    if (reason.isEmpty) return RideException('$action. Coba lagi.');
    return RideException('$action: $reason');
  }
}

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
    throw RideException.from('Gagal menerima trip', res.body);
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
    throw RideException.from('Gagal memulai trip', res.body);
  }

  Future<ActiveTrip> completeTrip(String tripId,
      {String paymentStatus = 'paid', double debtAmount = 0}) async {
    final body = <String, dynamic>{'payment_status': paymentStatus};
    if (paymentStatus == 'debt' && debtAmount > 0) {
      body['debt_amount'] = debtAmount;
    }
    final res = await _api.put('/trips/$tripId/complete', body: body);
    if (res.statusCode == 200) {
      return ActiveTrip.fromJson(jsonDecode(res.body));
    }
    throw RideException.from('Gagal menyelesaikan trip', res.body);
  }

  Future<ActiveTrip> submitBid(String tripId, double amount, {String reason = '', String bidderRole = 'driver'}) async {
    final res = await _api.put('/trips/$tripId/bid', body: {
      'amount': amount,
      'reason': reason,
      'bidder_role': bidderRole,
    });
    if (res.statusCode == 200) {
      return ActiveTrip.fromJson(jsonDecode(res.body));
    }
    throw RideException.from('Gagal mengirim bid', res.body);
  }

  Future<ActiveTrip> dealTrip(String tripId) async {
    final res = await _api.put('/trips/$tripId/deal');
    if (res.statusCode == 200) {
      return ActiveTrip.fromJson(jsonDecode(res.body));
    }
    throw RideException.from('Gagal menerima harga', res.body);
  }
}

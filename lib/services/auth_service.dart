import 'dart:convert';
import '../core/network/api_client.dart';
import '../core/constants.dart';
import '../core/storage/local_storage.dart';
import '../models/driver.dart';

class AuthService {
  final ApiClient _api;
  final LocalStorage _storage;

  AuthService(this._api, this._storage);

  Future<Driver> signIn(String phone) async {
    final res = await _api.post(ApiConstants.auth, body: {'phone': phone});
    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body);
      final token = data['token'] ?? '';
      if (token.isNotEmpty) _api.setToken(token);
      return Driver.fromJson(data['driver'] ?? data);
    } else {
      throw Exception('Sign in failed: ${res.body}');
    }
  }

  Future<void> logout() async {
    await _api.post(ApiConstants.authLogout);
    _api.clearToken();
  }

  String? _phone() => _storage.getPhone();

  Future<Driver> getProfile() async {
    final phone = _phone();
    final path = '${ApiConstants.driverMe}${phone != null ? '?phone=$phone' : ''}';
    final res = await _api.get(path);
    if (res.statusCode == 200) {
      return Driver.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Failed to fetch profile');
    }
  }

  Future<Driver> updateStatus(String status, {String? reason}) async {
    final phone = _phone();
    final path = '${ApiConstants.driverStatus}${phone != null ? '?phone=$phone' : ''}';
    final body = <String, dynamic>{'status': status};
    if (reason != null) body['reason'] = reason;
    final res = await _api.put(path, body: body);
    if (res.statusCode == 200) {
      return Driver.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Failed to update status');
    }
  }
}

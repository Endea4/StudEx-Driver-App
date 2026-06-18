import 'dart:convert';
import '../core/network/api_client.dart';
import '../core/constants.dart';
import '../core/storage/local_storage.dart';
import '../models/driver.dart';

class AuthService {
  final ApiClient _api;
  final LocalStorage _storage;

  AuthService(this._api, this._storage);

  Future<Driver> signIn(String phone, String password) async {
    final res = await _api.post(ApiConstants.auth, body: {
      'phone': phone,
      'password': password,
    });
    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body);
      final token = data['token'] ?? '';
      if (token.isNotEmpty) {
        _api.setToken(token);
        await _storage.saveToken(token);
      }
      final driver = Driver.fromJson(data['driver'] ?? data['user'] ?? data);
      if (driver.id.isNotEmpty) {
        await _storage.saveDriverId(driver.id);
      }
      return driver;
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
    if (phone == null) throw Exception('No phone stored');
    final path = '${ApiConstants.driverMe}/$phone';
    final res = await _api.get(path);
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      return Driver.fromJson(decoded);
    } else {
      throw Exception('Failed to fetch profile');
    }
  }

  Future<Driver> updateStatus(String status, {String? reason}) async {
    final phone = _phone();
    final body = <String, dynamic>{'phone': phone, 'status': status};
    if (reason != null) body['reason'] = reason;
    final res = await _api.put(ApiConstants.driverStatus, body: body);
    if (res.statusCode == 200) {
      final updated = await getProfile();
      return updated;
    } else {
      throw Exception('Failed to update status');
    }
  }

  Future<Driver> updateProfile(Map<String, dynamic> fields) async {
    final phone = _phone();
    if (phone == null) throw Exception('No phone stored');
    final res = await _api.put('${ApiConstants.driverMe}/$phone', body: fields);
    if (res.statusCode == 200) {
      final updated = await getProfile();
      return updated;
    } else {
      throw Exception('Failed to update profile');
    }
  }

  Future<bool> changePassword(String newPassword) async {
    final phone = _phone();
    if (phone == null) throw Exception('No phone stored');
    final res = await _api.put('${ApiConstants.driverMe}/$phone/password', body: {
      'password': newPassword,
    });
    return res.statusCode == 200;
  }
}

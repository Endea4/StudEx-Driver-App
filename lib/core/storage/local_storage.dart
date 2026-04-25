import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _keyToken = 'driver_token';
  static const _keyPhone = 'driver_phone';
  static const _keyGpsEnabled = 'gps_enabled';

  final SharedPreferences _prefs;

  LocalStorage(this._prefs);

  Future<void> saveToken(String token) async {
    await _prefs.setString(_keyToken, token);
  }

  String? getToken() => _prefs.getString(_keyToken);

  Future<void> savePhone(String phone) async {
    await _prefs.setString(_keyPhone, phone);
  }

  String? getPhone() => _prefs.getString(_keyPhone);

  Future<void> saveGpsEnabled(bool enabled) async {
    await _prefs.setBool(_keyGpsEnabled, enabled);
  }

  bool getGpsEnabled() => _prefs.getBool(_keyGpsEnabled) ?? false;

  Future<void> clear() async {
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyPhone);
    await _prefs.remove(_keyGpsEnabled);
  }
}

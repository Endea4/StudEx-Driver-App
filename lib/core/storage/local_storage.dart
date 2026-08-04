import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _keyToken = 'driver_token';
  static const _keyPhone = 'driver_phone';
  static const _keyDriverId = 'driver_id';
  static const _keyGpsEnabled = 'gps_enabled';
  static const _keyMapTheme = 'map_theme';

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

  Future<void> saveDriverId(String id) async {
    await _prefs.setString(_keyDriverId, id);
  }

  String? getDriverId() => _prefs.getString(_keyDriverId);

  Future<void> saveGpsEnabled(bool enabled) async {
    await _prefs.setBool(_keyGpsEnabled, enabled);
  }

  bool getGpsEnabled() => _prefs.getBool(_keyGpsEnabled) ?? false;

  // Map light/dark preference -- a device/display setting, so it's
  // intentionally left out of clear() and survives logout.
  Future<void> saveMapTheme(String theme) async {
    await _prefs.setString(_keyMapTheme, theme);
  }

  String getMapTheme() => _prefs.getString(_keyMapTheme) ?? 'light';

  Future<void> clear() async {
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyPhone);
    await _prefs.remove(_keyDriverId);
    await _prefs.remove(_keyGpsEnabled);
  }
}

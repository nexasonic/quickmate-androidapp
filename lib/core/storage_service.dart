import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_profile';
  static const String _themeKey = 'app_theme_mode';
  static const String _languageKey = 'app_language_code';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Language Settings Management
  static Future<bool> saveLanguageCode(String code) async {
    await init();
    return await _prefs!.setString(_languageKey, code);
  }

  static String getLanguageCode() {
    return _prefs?.getString(_languageKey) ?? 'en';
  }

  // Theme Settings Management
  static Future<bool> saveThemeMode(String mode) async {
    await init();
    return await _prefs!.setString(_themeKey, mode);
  }

  static String getThemeMode() {
    return _prefs?.getString(_themeKey) ?? 'System';
  }

  // Token Management
  static Future<bool> saveToken(String token) async {
    await init();
    return await _prefs!.setString(_tokenKey, token);
  }

  static String? getToken() {
    return _prefs?.getString(_tokenKey);
  }

  static Future<bool> removeToken() async {
    await init();
    return await _prefs!.remove(_tokenKey);
  }

  static bool hasToken() {
    final token = getToken();
    return token != null && token.isNotEmpty;
  }

  // User Profile Cache
  static Future<bool> saveUser(Map<String, dynamic> userMap) async {
    await init();
    return await _prefs!.setString(_userKey, jsonEncode(userMap));
  }

  static Map<String, dynamic>? getUser() {
    final userJson = _prefs?.getString(_userKey);
    if (userJson == null || userJson.isEmpty) return null;
    try {
      return jsonDecode(userJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> removeUser() async {
    await init();
    return await _prefs!.remove(_userKey);
  }

  // Guest / Unauthenticated Live GPS Location Cache
  static const String _latKey = 'guest_latitude';
  static const String _lngKey = 'guest_longitude';
  static const String _placeKey = 'guest_place_name';

  static Future<void> saveGuestLocation(double lat, double lng, String placeName) async {
    await init();
    await _prefs?.setDouble(_latKey, lat);
    await _prefs?.setDouble(_lngKey, lng);
    await _prefs?.setString(_placeKey, placeName);
  }

  static Map<String, dynamic>? getGuestLocation() {
    final lat = _prefs?.getDouble(_latKey);
    final lng = _prefs?.getDouble(_lngKey);
    final place = _prefs?.getString(_placeKey);

    if (lat != null && lng != null) {
      return {
        'latitude': lat,
        'longitude': lng,
        'place_name': place ?? 'Location Available',
      };
    }
    return null;
  }

  // Clear Session
  static Future<void> clearSession() async {
    await init();
    await _prefs?.clear();
  }
}

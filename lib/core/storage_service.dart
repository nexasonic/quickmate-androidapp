import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_language.dart';

class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_profile';
  static const String _themeKey = 'app_theme_mode';
  static const String _languageKey = 'app_language_code';

  // Push Notifications & Privacy Keys
  static const String _notifJobAlertsKey = 'notif_job_alerts';
  static const String _notifMessagesKey = 'notif_messages';
  static const String _notifPromotionsKey = 'notif_promotions';
  static const String _privacyShowLocationKey = 'privacy_show_location';

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

  // Push Notifications & Privacy Preference Management
  static Future<bool> saveNotifJobAlerts(bool value) async {
    await init();
    return await _prefs!.setBool(_notifJobAlertsKey, value);
  }

  static bool getNotifJobAlerts() {
    return _prefs?.getBool(_notifJobAlertsKey) ?? true;
  }

  static Future<bool> saveNotifMessages(bool value) async {
    await init();
    return await _prefs!.setBool(_notifMessagesKey, value);
  }

  static bool getNotifMessages() {
    return _prefs?.getBool(_notifMessagesKey) ?? true;
  }

  static Future<bool> saveNotifPromotions(bool value) async {
    await init();
    return await _prefs!.setBool(_notifPromotionsKey, value);
  }

  static bool getNotifPromotions() {
    return _prefs?.getBool(_notifPromotionsKey) ?? true;
  }

  static Future<bool> savePrivacyShowLocation(bool value) async {
    await init();
    return await _prefs!.setBool(_privacyShowLocationKey, value);
  }

  static bool getPrivacyShowLocation() {
    return _prefs?.getBool(_privacyShowLocationKey) ?? true;
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
        'place_name': place ?? AppLanguage.trCode('location_available'),
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

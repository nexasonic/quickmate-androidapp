import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_profile';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
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

  // Clear Session
  static Future<void> clearSession() async {
    await init();
    await _prefs?.clear();
  }
}

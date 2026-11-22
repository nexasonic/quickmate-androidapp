import 'dart:async';
import '../core/api_config.dart';
import '../core/api_service.dart';
import 'auth_service.dart';

class PresenceService {
  static Timer? _pingTimer;

  // Default fallback user coordinates (e.g. Thodupuzha Kerala)
  static double currentLatitude = 9.8920;
  static double currentLongitude = 76.7190;

  /// Start 1-minute periodic GPS location & presence ping
  static void startPeriodicPing() {
    _pingTimer?.cancel();
    // Send immediate ping first
    pingServer();

    // Then schedule every 1 minute
    _pingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      pingServer();
    });
  }

  /// Stop periodic ping
  static void stopPeriodicPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Send presence ping with latitude, longitude to backend
  static Future<bool> pingServer([double? lat, double? lng]) async {
    if (!AuthService.isLoggedIn()) return false;

    if (lat != null && lng != null) {
      currentLatitude = lat;
      currentLongitude = lng;
    }

    final response = await ApiService.post(
      '${ApiConfig.baseUrl}/presence/ping',
      body: {
        'latitude': currentLatitude,
        'longitude': currentLongitude,
      },
    );

    return response.success;
  }
}

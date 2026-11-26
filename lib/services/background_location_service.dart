import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../core/api_config.dart';

const String fetchBackgroundLocationTaskKey = "com.quickmate.fetchBackgroundLocation";

/// Top-level background execution dispatcher required by WorkManager
@pragma('vm:entry-point')
void backgroundLocationCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == fetchBackgroundLocationTaskKey) {
      try {
        // 1. Check if GPS service is enabled
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('[WorkManager] Location services disabled on device');
          return Future.value(true);
        }

        // 2. Check location permissions
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          debugPrint('[WorkManager] Location permission denied for background execution');
          return Future.value(true);
        }

        // 3. Fetch device GPS position
        Position? pos;
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 10),
            ),
          );
        } catch (_) {
          pos = await Geolocator.getLastKnownPosition();
        }

        if (pos == null) {
          debugPrint('[WorkManager] Could not acquire GPS position');
          return Future.value(true);
        }

        final lat = double.parse(pos.latitude.toStringAsFixed(7));
        final lng = double.parse(pos.longitude.toStringAsFixed(7));

        final prefs = await SharedPreferences.getInstance();

        // 4. Update cached guest location in SharedPreferences
        await prefs.setDouble('guest_latitude', lat);
        await prefs.setDouble('guest_longitude', lng);

        // Geocode place name if possible
        String placeName = prefs.getString('guest_place_name') ?? 'Location Available';
        try {
          final geoUrl = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng');
          final geoResponse = await http.get(
            geoUrl,
            headers: {'User-Agent': 'QuickMateApp/1.0'},
          ).timeout(const Duration(seconds: 5));

          if (geoResponse.statusCode == 200) {
            final geoData = jsonDecode(geoResponse.body);
            final address = geoData['address'] as Map<String, dynamic>?;
            if (address != null) {
              final city = address['city'] ??
                  address['town'] ??
                  address['village'] ??
                  address['suburb'] ??
                  address['county'] ??
                  address['state_district'];
              if (city != null && city.toString().isNotEmpty) {
                placeName = city.toString();
                await prefs.setString('guest_place_name', placeName);
              }
            }
          }
        } catch (_) {}

        // 5. Post to backend if user is logged in
        final token = prefs.getString('auth_token');
        final showLocation = prefs.getBool('privacy_show_location') ?? true;
        if (token != null && token.isNotEmpty) {
          final pingUrl = Uri.parse('${ApiConfig.baseUrl}/presence/ping');
          final response = await http.post(
            pingUrl,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'latitude': lat,
              'longitude': lng,
              'lat': lat,
              'lng': lng,
              'place_name': placeName,
              'location': placeName,
              'show_location': showLocation,
              'privacy_show_location': showLocation,
            }),
          );

          debugPrint('[WorkManager] Silent background location synced: $lat, $lng ($placeName) - Status: ${response.statusCode}');
        } else {
          debugPrint('[WorkManager] Location updated locally: $lat, $lng ($placeName)');
        }
      } catch (e) {
        debugPrint('[WorkManager] Background location execution error: $e');
      }
    }
    return Future.value(true);
  });
}

class BackgroundLocationManager {
  static bool _initialized = false;

  /// Initialize WorkManager background dispatcher
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Workmanager().initialize(
        backgroundLocationCallbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      _initialized = true;
      debugPrint('[BackgroundLocationManager] WorkManager initialized');
    } catch (e) {
      debugPrint('[BackgroundLocationManager] WorkManager initialization error: $e');
    }
  }

  /// Register periodic background location task (15 to 30 mins interval without banner)
  static Future<void> startPeriodicLocationTask() async {
    try {
      await initialize();

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      await Workmanager().registerPeriodicTask(
        "quickmate_background_location_task",
        fetchBackgroundLocationTaskKey,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );

      debugPrint('[BackgroundLocationManager] Periodic background location task registered (every 15m)');
    } catch (e) {
      debugPrint('[BackgroundLocationManager] Failed to register background task: $e');
    }
  }

  /// Cancel background location task
  static Future<void> stopPeriodicLocationTask() async {
    try {
      await Workmanager().cancelByUniqueName("quickmate_background_location_task");
      debugPrint('[BackgroundLocationManager] Background location task cancelled');
    } catch (e) {
      debugPrint('[BackgroundLocationManager] Error cancelling background task: $e');
    }
  }
}

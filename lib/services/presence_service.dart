import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/api_service.dart';
import '../core/storage_service.dart';
import 'auth_service.dart';

class UserLocationData {
  final double latitude;
  final double longitude;
  final String placeName;
  final bool hasExactGps;
  final DateTime lastUpdated;

  UserLocationData({
    required this.latitude,
    required this.longitude,
    required this.placeName,
    this.hasExactGps = false,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  UserLocationData copyWith({
    double? latitude,
    double? longitude,
    String? placeName,
    bool? hasExactGps,
  }) {
    return UserLocationData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeName: placeName ?? this.placeName,
      hasExactGps: hasExactGps ?? this.hasExactGps,
      lastUpdated: DateTime.now(),
    );
  }
}

class PresenceService with WidgetsBindingObserver {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  static Timer? _pingTimer;
  static bool _isObserverRegistered = false;
  static bool _isSyncing = false;

  // Live device coordinates and geocoded place name
  static double currentLatitude = 9.8920;
  static double currentLongitude = 76.7190;
  static String currentPlaceName = 'Thodupuzha';
  static double? _lastGeocodedLat;
  static double? _lastGeocodedLng;

  /// Reactive Location State Notifier broadcasting live location across the app
  static final ValueNotifier<UserLocationData> locationNotifier = ValueNotifier<UserLocationData>(
    UserLocationData(
      latitude: currentLatitude,
      longitude: currentLongitude,
      placeName: currentPlaceName,
      hasExactGps: false,
    ),
  );

  /// Fetch live GPS position directly from physical device or Android Emulator location sensor
  static Future<Position?> _fetchDeviceGpsPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[PresenceService] Location service disabled on device');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[PresenceService] Location permission denied by user');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[PresenceService] Location permission denied forever');
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      debugPrint('[PresenceService] Real Device GPS fetched: ${pos.latitude}, ${pos.longitude}');
      return pos;
    } catch (e) {
      debugPrint('[PresenceService] Geolocator error, checking last known position: $e');
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Start 30-second periodic GPS location & presence ping
  static void startPeriodicPing() {
    if (!_isObserverRegistered) {
      WidgetsBinding.instance.addObserver(_instance);
      _isObserverRegistered = true;
    }

    _restoreCachedGuestLocation();

    _pingTimer?.cancel();

    // Send immediate ping first upon starting
    pingServer();

    // Schedule every 30 seconds so user location is continuously updated
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      pingServer();
    });
  }

  static void _restoreCachedGuestLocation() {
    final cached = StorageService.getGuestLocation();
    if (cached != null) {
      if (cached['latitude'] != null && cached['longitude'] != null) {
        currentLatitude = (cached['latitude'] as num).toDouble();
        currentLongitude = (cached['longitude'] as num).toDouble();
      }
      if (cached['place_name'] != null && cached['place_name'].toString().isNotEmpty) {
        currentPlaceName = cached['place_name'].toString();
      }
    }
  }

  /// Stop & cancel periodic ping timer
  static void stopPeriodicPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Handle App Lifecycle transitions (foreground / background)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startPeriodicPing();
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.inactive ||
               state == AppLifecycleState.detached) {
      stopPeriodicPing();
    }
  }

  /// Update current location coordinates with high accuracy (up to 7 decimal places) and sync
  static Future<bool> updateLocation(double lat, double lng, {String? placeName}) async {
    currentLatitude = double.parse(lat.toStringAsFixed(7));
    currentLongitude = double.parse(lng.toStringAsFixed(7));

    if (placeName != null && placeName.isNotEmpty) {
      currentPlaceName = placeName;
    }

    await StorageService.saveGuestLocation(currentLatitude, currentLongitude, currentPlaceName);
    _notifyLocationChange(hasGps: true);
    return await pingServer(lat, lng, currentPlaceName);
  }

  /// Reverse-geocode place_name dynamically from coordinates
  static Future<String> _getOrFetchPlaceName(double lat, double lng) async {
    if (_lastGeocodedLat != null && _lastGeocodedLng != null) {
      final latDiff = (lat - _lastGeocodedLat!).abs();
      final lngDiff = (lng - _lastGeocodedLng!).abs();
      if (latDiff < 0.001 && lngDiff < 0.001 && currentPlaceName.isNotEmpty && currentPlaceName != 'Location Available') {
        return currentPlaceName;
      }
    }

    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng');
      final response = await http.get(
        url,
        headers: {'User-Agent': 'QuickMateApp/1.0'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final city = address['city'] ??
              address['town'] ??
              address['village'] ??
              address['suburb'] ??
              address['county'] ??
              address['state_district'];
          if (city != null && city.toString().isNotEmpty) {
            currentPlaceName = city.toString();
            _lastGeocodedLat = lat;
            _lastGeocodedLng = lng;
            return currentPlaceName;
          }
        }
      }
    } catch (_) {}

    return currentPlaceName.isNotEmpty ? currentPlaceName : 'Location Available';
  }

  /// Send presence ping with high precision latitude, longitude, and place_name every 30s
  static Future<bool> pingServer([double? lat, double? lng, String? placeName]) async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      // Query physical mobile device or Android Emulator location sensor if coordinates are not explicitly passed
      if (lat == null || lng == null) {
        final pos = await _fetchDeviceGpsPosition();
        if (pos != null) {
          lat = pos.latitude;
          lng = pos.longitude;
        }
      }

      if (lat != null && lng != null) {
        currentLatitude = double.parse(lat.toStringAsFixed(7));
        currentLongitude = double.parse(lng.toStringAsFixed(7));
        if (placeName != null && placeName.isNotEmpty) {
          currentPlaceName = placeName;
        } else {
          currentPlaceName = await _getOrFetchPlaceName(currentLatitude, currentLongitude);
        }

        // Save live location locally in SharedPreferences for distance calculation and guest map view
        await StorageService.saveGuestLocation(currentLatitude, currentLongitude, currentPlaceName);
        _notifyLocationChange(hasGps: true);

        // If user is logged in, sync with database backend
        if (AuthService.isLoggedIn()) {
          final payload = {
            'latitude': currentLatitude,
            'longitude': currentLongitude,
            'lat': currentLatitude,
            'lng': currentLongitude,
            'place_name': currentPlaceName,
            'location': currentPlaceName,
          };

          debugPrint('[PresenceService] Syncing GPS ping to ${ApiConfig.baseUrl}/presence/ping: $currentLatitude, $currentLongitude ($currentPlaceName)');

          final response = await ApiService.post(
            '${ApiConfig.baseUrl}/presence/ping',
            body: payload,
          );

          debugPrint('[PresenceService] Sync response: status=${response.statusCode}, success=${response.success}');
          return response.success;
        } else {
          debugPrint('[PresenceService] Guest GPS updated locally in SharedPreferences: $currentLatitude, $currentLongitude ($currentPlaceName)');
          return true;
        }
      } else {
        currentPlaceName = await _getOrFetchPlaceName(currentLatitude, currentLongitude);
        await StorageService.saveGuestLocation(currentLatitude, currentLongitude, currentPlaceName);
        _notifyLocationChange(hasGps: false);

        if (AuthService.isLoggedIn()) {
          final payload = {
            'latitude': double.parse(currentLatitude.toStringAsFixed(7)),
            'longitude': double.parse(currentLongitude.toStringAsFixed(7)),
            'lat': double.parse(currentLatitude.toStringAsFixed(7)),
            'lng': double.parse(currentLongitude.toStringAsFixed(7)),
            'place_name': currentPlaceName,
            'location': currentPlaceName,
          };

          final response = await ApiService.post(
            '${ApiConfig.baseUrl}/presence/ping',
            body: payload,
          );

          return response.success;
        }
        return true;
      }
    } catch (e) {
      debugPrint('[PresenceService] Ping error: $e');
      if (AuthService.isLoggedIn()) {
        final fallbackResponse = await ApiService.post(
          '${ApiConfig.baseUrl}/presence/ping',
          body: {},
        );
        return fallbackResponse.success;
      }
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  static void _notifyLocationChange({required bool hasGps}) {
    locationNotifier.value = UserLocationData(
      latitude: currentLatitude,
      longitude: currentLongitude,
      placeName: currentPlaceName,
      hasExactGps: hasGps,
    );
  }
}

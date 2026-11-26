import '../core/api_config.dart';
import '../core/app_language.dart';
import '../core/app_theme.dart';

class UserModel {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? accountType;
  final bool isVerified;
  final String? avatarUrl;
  final bool isOnline;
  final String? lastSeenHuman;
  final double rating;
  final int reviewsCount;
  final String? location;
  final double? latitude;
  final double? longitude;
  final bool showLocation;
  final bool notifJobAlerts;
  final bool notifMessages;
  final bool notifBookings;
  final bool notifPromotions;
  final int prefTheme;
  final int prefLanguage;

  UserModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.accountType,
    this.isVerified = false,
    this.avatarUrl,
    this.isOnline = false,
    this.lastSeenHuman,
    this.rating = 5.0,
    this.reviewsCount = 1,
    this.location,
    this.latitude,
    this.longitude,
    this.showLocation = true,
    this.notifJobAlerts = true,
    this.notifMessages = true,
    this.notifBookings = true,
    this.notifPromotions = false,
    this.prefTheme = 1,
    this.prefLanguage = 1,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? {};
    final userMap = json['user'] as Map<String, dynamic>? ?? {};

    final rawAvatar = json['avatar_url']?.toString() ??
        json['avatar']?.toString() ??
        profile['avatar_url']?.toString() ??
        profile['avatar']?.toString() ??
        profile['propic']?.toString() ??
        userMap['avatar_url']?.toString() ??
        userMap['avatar']?.toString();

    final int rawId = json['id'] is int
        ? json['id']
        : (int.tryParse(json['id']?.toString() ?? '') ?? (userMap['id'] is int ? userMap['id'] : 0));

    double? parseCoord(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble() != 0 ? val.toDouble() : null;
      if (val is String) {
        final d = double.tryParse(val);
        return d != null && d != 0 ? d : null;
      }
      return null;
    }

    bool parseBoolFlag(dynamic val, bool fallback) {
      if (val == null) return fallback;
      if (val is bool) return val;
      if (val is num) return val.toInt() != 0;
      final s = val.toString().trim().toLowerCase();
      if (s == '1' || s == 'true' || s == 'yes') return true;
      if (s == '0' || s == 'false' || s == 'no' || s == 'hidden' || s == 'disabled') return false;
      return fallback;
    }

    final double? parsedLat = parseCoord(json['latitude']) ?? parseCoord(profile['latitude']) ?? parseCoord(userMap['latitude']);
    final double? parsedLng = parseCoord(json['longitude']) ?? parseCoord(profile['longitude']) ?? parseCoord(userMap['longitude']);

    final bool parsedShowLoc = (json['show_location'] != false &&
        json['show_location'] != 0 &&
        json['privacy_show_location'] != false &&
        json['privacy_show_location'] != 0 &&
        profile['show_location'] != false &&
        profile['show_location'] != 0 &&
        userMap['show_location'] != false &&
        userMap['show_location'] != 0);

    final dynamic rawTheme = profile['pref_theme'] ?? json['pref_theme'] ?? userMap['pref_theme'];
    final dynamic rawLang = profile['pref_language'] ?? json['pref_language'] ?? userMap['pref_language'];

    final int parsedTheme = rawTheme is num
        ? rawTheme.toInt()
        : (rawTheme != null ? themeModeToInt(rawTheme.toString()) : 0);
    final int parsedLang = rawLang is num
        ? rawLang.toInt()
        : (rawLang != null ? AppLanguage.languageCodeToInt(rawLang.toString()) : 1);

    return UserModel(
      id: rawId,
      name: json['name'] ?? userMap['name'] ?? AppLanguage.trCode('user_profile'),
      email: json['email'] ?? userMap['email'],
      phone: json['phone'] ?? userMap['phone'],
      accountType: json['account_type'] ?? userMap['account_type'],
      isVerified: json['is_verified'] == true ||
          json['is_verified'] == 1 ||
          profile['is_verified'] == true ||
          profile['identity_verified'] == true,
      avatarUrl: rawAvatar != null && rawAvatar.isNotEmpty
          ? ApiConfig.fixImageUrl(rawAvatar)
          : null,
      isOnline: json['is_online'] == true || json['is_online'] == 1,
      lastSeenHuman: json['last_seen_human']?.toString(),
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : 5.0,
      reviewsCount: json['reviews_count'] != null ? (json['reviews_count'] as num).toInt() : 1,
      location: json['location']?.toString() ?? profile['location']?.toString() ?? userMap['location']?.toString(),
      latitude: parsedLat,
      longitude: parsedLng,
      showLocation: parsedShowLoc,
      notifJobAlerts: parseBoolFlag(profile['notif_job_alerts'] ?? json['notif_job_alerts'] ?? userMap['notif_job_alerts'], true),
      notifMessages: parseBoolFlag(profile['notif_messages'] ?? json['notif_messages'] ?? userMap['notif_messages'], true),
      notifBookings: parseBoolFlag(profile['notif_bookings'] ?? json['notif_bookings'] ?? userMap['notif_bookings'], true),
      notifPromotions: parseBoolFlag(profile['notif_promotions'] ?? json['notif_promotions'] ?? userMap['notif_promotions'], false),
      prefTheme: parsedTheme,
      prefLanguage: parsedLang,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'account_type': accountType,
      'is_verified': isVerified,
      'avatar_url': avatarUrl,
      'is_online': isOnline,
      'rating': rating,
      'reviews_count': reviewsCount,
      if (location != null) 'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'show_location': showLocation,
      'notif_job_alerts': notifJobAlerts,
      'notif_messages': notifMessages,
      'notif_bookings': notifBookings,
      'notif_promotions': notifPromotions,
      'pref_theme': prefTheme,
      'pref_language': prefLanguage,
    };
  }
}

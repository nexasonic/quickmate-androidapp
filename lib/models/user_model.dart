import '../core/api_config.dart';

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

    final double? parsedLat = parseCoord(json['latitude']) ?? parseCoord(profile['latitude']) ?? parseCoord(userMap['latitude']);
    final double? parsedLng = parseCoord(json['longitude']) ?? parseCoord(profile['longitude']) ?? parseCoord(userMap['longitude']);

    return UserModel(
      id: rawId,
      name: json['name'] ?? userMap['name'] ?? 'User Profile',
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
    };
  }
}

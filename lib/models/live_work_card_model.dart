import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/api_config.dart';
import '../core/app_language.dart';
import '../services/presence_service.dart';
import 'category_model.dart';
import 'user_model.dart';

double? calculateDistanceKm({
  double? lat1,
  double? lon1,
  double? lat2,
  double? lon2,
}) {
  if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
    return null;
  }
  const double earthRadiusKm = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180.0;
  final dLon = (lon2 - lon1) * math.pi / 180.0;

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180.0) *
          math.cos(lat2 * math.pi / 180.0) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

String translateLastSeenHuman(BuildContext context, String? raw) {
  if (raw == null || raw.trim().isEmpty) return context.tr('offline');
  final cleaned = raw
      .replaceAll('Last seen ', '')
      .replaceAll('last seen ', '')
      .replaceAll('seen ', '')
      .replaceAll('Last ', '')
      .trim();
  final lower = cleaned.toLowerCase();
  if (lower.isEmpty || lower == 'offline') return context.tr('offline');
  if (lower.contains('just now') || lower.contains('moments ago') || lower.contains('sec')) {
    return context.tr('just_now');
  }
  final numMatch = RegExp(r'\d+').stringMatch(lower);
  if (numMatch != null) {
    if (lower.contains('min') || RegExp(r'\d+\s*m\b').hasMatch(lower)) {
      return '$numMatch ${context.tr('mins_ago')}';
    }
    if (lower.contains('hour') || lower.contains('hr') || RegExp(r'\d+\s*h\b').hasMatch(lower)) {
      return '$numMatch ${context.tr('hours_ago')}';
    }
    if (lower.contains('day') || RegExp(r'\d+\s*d\b').hasMatch(lower)) {
      return '$numMatch ${context.tr('days_ago')}';
    }
    if (lower.contains('month') || lower.contains('mo')) {
      return '$numMatch ${context.tr('months_ago')}';
    }
  }
  return cleaned;
}

String formatTimeAgoString(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return 'Just now';
  try {
    final dt = DateTime.parse(dateStr).toLocal();
    final diff = DateTime.now().difference(dt);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 30) {
      return '${diff.inDays}d ago';
    } else {
      return '${(diff.inDays / 30).floor()}mo ago';
    }
  } catch (_) {
    return dateStr;
  }
}

class CardReviewModel {
  final int id;
  final int? reviewerId;
  final double rating;
  final String review;
  final String? createdAt;
  final String reviewerName;
  final String? reviewerAvatar;
  final int? cardId;
  final int? cardType;
  final String? cardTitle;

  CardReviewModel({
    required this.id,
    this.reviewerId,
    required this.rating,
    required this.review,
    this.createdAt,
    required this.reviewerName,
    this.reviewerAvatar,
    this.cardId,
    this.cardType,
    this.cardTitle,
  });

  factory CardReviewModel.fromJson(Map<String, dynamic> json) {
    final reviewer = json['reviewer'] as Map<String, dynamic>? ?? {};
    final rawName = reviewer['name']?.toString() ?? json['name']?.toString() ?? json['reviewer_name']?.toString() ?? AppLanguage.trCode('reviewer_fallback');
    final rawAvatar = reviewer['avatar_url']?.toString() ?? json['avatar']?.toString() ?? json['reviewer_avatar']?.toString();
    final rawReviewerId = json['reviewer_id'] is int ? json['reviewer_id'] : (reviewer['id'] is int ? reviewer['id'] : null);

    return CardReviewModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      reviewerId: rawReviewerId,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : 5.0,
      review: json['review']?.toString() ?? json['comment']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? json['date']?.toString(),
      reviewerName: rawName,
      reviewerAvatar: rawAvatar != null ? ApiConfig.fixImageUrl(rawAvatar) : null,
      cardId: json['card_id'] is int ? json['card_id'] : int.tryParse(json['card_id']?.toString() ?? '0'),
      cardType: json['card_type'] is int ? json['card_type'] : int.tryParse(json['card_type']?.toString() ?? '0'),
      cardTitle: json['card_title']?.toString(),
    );
  }
}

class LiveWorkCardModel {
  final int id;
  final String title;
  final String? description;
  final double? price;
  final String? priceType;
  final String? priceUnit;
  final String currency;
  final String? location;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final int status; // 1: Active, 2: Paused
  final int viewsCount;
  final double rating;
  final int reviewsCount;
  final String? thumbnailUrl;
  final List<String> images;
  final List<CardReviewModel> reviews;
  final List<String> tags;
  final String? expiresAt;
  final CategoryModel? category;
  final UserModel? user;
  bool isFavorite;
  final String? createdAt;
  final String? updatedAt;

  LiveWorkCardModel({
    required this.id,
    required this.title,
    this.description,
    this.price,
    this.priceType,
    this.priceUnit,
    this.currency = 'INR',
    this.location,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.status = 1,
    this.viewsCount = 0,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.thumbnailUrl,
    this.images = const [],
    this.reviews = const [],
    this.tags = const [],
    this.expiresAt,
    this.category,
    this.user,
    this.isFavorite = false,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 1;
  bool get isPaused => status == 2;
  bool get isExpired {
    if (status == 3) return true;
    if (status == 1 || status == 2) return false;
    if (expiresAt != null) {
      final dt = DateTime.tryParse(expiresAt!);
      if (dt != null && DateTime.now().isAfter(dt)) return true;
    }
    return false;
  }

  String get statusLabel {
    if (isExpired) return 'Expired';
    if (isPaused) return 'Paused';
    return 'Active';
  }

  String getTrStatusLabel(BuildContext context) {
    if (isExpired) return context.tr('expired');
    if (isPaused) return context.tr('paused');
    return context.tr('active');
  }

  String getTrFormattedExpiresIn(BuildContext context, {bool shortOnly = false}) {
    if (isExpired) return context.tr('expired');
    DateTime? expDate;
    if (expiresAt != null) {
      expDate = DateTime.tryParse(expiresAt!);
    }
    if (expDate == null || expDate.isBefore(DateTime.now())) {
      if (updatedAt != null || createdAt != null) {
        final base = DateTime.tryParse(updatedAt ?? createdAt!);
        if (base != null) {
          expDate = base.add(const Duration(hours: 24));
        }
      }
    }
    final String timeStr;
    if (expDate != null) {
      final diff = expDate.difference(DateTime.now());
      if (diff.isNegative) {
        timeStr = context.tr('less_than_1m');
      } else if (diff.inHours > 0) {
        timeStr = '${diff.inHours}${context.tr('hours_short')} ${diff.inMinutes % 60}${context.tr('mins_short')}';
      } else if (diff.inMinutes > 0) {
        timeStr = '${diff.inMinutes}${context.tr('mins_short')}';
      } else {
        timeStr = context.tr('less_than_1m');
      }
    } else {
      timeStr = '24${context.tr('hours_short')}';
    }
    if (shortOnly) return timeStr;
    return context.trParams('expires_in_time', {'time': timeStr});
  }

  String getTrFormattedLastSeen(BuildContext context) {
    return translateLastSeenHuman(context, user?.lastSeenHuman);
  }

  String get formattedExpiresIn {
    if (isExpired) return 'Expired';
    DateTime? expDate;
    if (expiresAt != null) {
      expDate = DateTime.tryParse(expiresAt!);
    }
    if (expDate == null || expDate.isBefore(DateTime.now())) {
      if (updatedAt != null || createdAt != null) {
        final base = DateTime.tryParse(updatedAt ?? createdAt!);
        if (base != null) {
          expDate = base.add(const Duration(hours: 24));
        }
      }
    }
    if (expDate != null) {
      final diff = expDate.difference(DateTime.now());
      if (diff.isNegative) return 'Expires in < 1m';
      if (diff.inHours > 0) {
        return 'Expires in ${diff.inHours}h ${diff.inMinutes % 60}m';
      } else if (diff.inMinutes > 0) {
        return 'Expires in ${diff.inMinutes}m';
      } else {
        return 'Expires in < 1m';
      }
    }
    return 'Expires in 24h';
  }

  String get formattedTimeAgo => formatTimeAgoString(updatedAt ?? createdAt);

  String get formattedLastSeen {
    if (user?.lastSeenHuman != null && user!.lastSeenHuman!.isNotEmpty) {
      final raw = user!.lastSeenHuman!;
      return raw
          .replaceAll('Last seen ', '')
          .replaceAll('seen ', '')
          .replaceAll('Last ', '')
          .trim();
    }
    return 'Offline';
  }

  String get formattedPrice {
    if (price == null || price == 0) {
      if (priceType != null && priceType!.isNotEmpty && priceType!.toLowerCase() != 'fixed') {
        return priceType!.toUpperCase();
      }
      return 'Negotiable';
    }
    final pStr = price! % 1 == 0 ? price!.toInt().toString() : price!.toStringAsFixed(2);
    return '$currency $pStr${priceUnit != null && priceUnit!.isNotEmpty ? ' / $priceUnit' : ''}';
  }

  String getTrFormattedPrice(BuildContext context) {
    if (price == null || price == 0) {
      if (priceType != null && priceType!.isNotEmpty && priceType!.toLowerCase() != 'fixed') {
        final pt = priceType!.toLowerCase();
        if (pt.contains('negotiable')) return context.tr('negotiable');
        if (pt.contains('hour')) return context.tr('per_hour');
        if (pt.contains('day')) return context.tr('per_day');
        return priceType!.toUpperCase();
      }
      return context.tr('negotiable');
    }
    final pStr = price! % 1 == 0 ? price!.toInt().toString() : price!.toStringAsFixed(2);
    final pUnit = priceUnit?.toLowerCase() ?? '';
    String unitSuffix = '';
    if (pUnit.contains('hour') || pUnit.contains('hr')) {
      unitSuffix = ' ${context.tr('per_hour')}';
    } else if (pUnit.contains('day')) {
      unitSuffix = ' ${context.tr('per_day')}';
    } else if (priceUnit != null && priceUnit!.isNotEmpty) {
      unitSuffix = ' / $priceUnit';
    }
    return '$currency $pStr$unitSuffix';
  }

  String getFormattedDistance([double? userLat, double? userLng]) {
    final curLat = userLat ?? PresenceService.currentLatitude;
    final curLng = userLng ?? PresenceService.currentLongitude;

    final targetLat = latitude ?? user?.latitude;
    final targetLng = longitude ?? user?.longitude;

    double? km = distanceKm;

    if ((km == null || km == 0) && curLat != 0 && curLng != 0 && targetLat != null && targetLng != null && targetLat != 0 && targetLng != 0) {
      km = calculateDistanceKm(
        lat1: curLat,
        lon1: curLng,
        lat2: targetLat,
        lon2: targetLng,
      );
    }

    if (km != null && km > 0) {
      if (km < 1.0) {
        return '${(km * 1000).round()} m away';
      }
      return '${km.toStringAsFixed(1)} km away';
    }

    final locStr = location ?? user?.location;
    return (locStr != null && locStr.isNotEmpty) ? locStr : 'Nearby';
  }

  String getTrFormattedDistance(BuildContext context, [double? userLat, double? userLng]) {
    final curLat = userLat ?? PresenceService.currentLatitude;
    final curLng = userLng ?? PresenceService.currentLongitude;

    final targetLat = latitude ?? user?.latitude;
    final targetLng = longitude ?? user?.longitude;

    double? km = distanceKm;

    if ((km == null || km == 0) && curLat != 0 && curLng != 0 && targetLat != null && targetLng != null && targetLat != 0 && targetLng != 0) {
      km = calculateDistanceKm(
        lat1: curLat,
        lon1: curLng,
        lat2: targetLat,
        lon2: targetLng,
      );
    }

    if (km != null && km > 0) {
      if (km < 1.0) {
        return '${(km * 1000).round()} ${context.tr('meters_away')}';
      }
      return '${km.toStringAsFixed(1)} ${context.tr('km_away')}';
    }

    final locStr = location ?? user?.location;
    return (locStr != null && locStr.isNotEmpty) ? locStr : context.tr('near_you');
  }

  String getTrFormattedTimeAgo(BuildContext context) {
    final rawDateStr = updatedAt ?? createdAt;
    if (rawDateStr == null || rawDateStr.isEmpty) return context.tr('just_now');

    try {
      final dt = DateTime.parse(rawDateStr).toLocal();
      final diff = DateTime.now().difference(dt);

      if (diff.inSeconds < 60) {
        return context.tr('just_now');
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes} ${context.tr('mins_ago')}';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} ${context.tr('hours_ago')}';
      } else if (diff.inDays < 30) {
        return '${diff.inDays} ${context.tr('days_ago')}';
      } else {
        return '${(diff.inDays / 30).floor()} ${context.tr('months_ago')}';
      }
    } catch (_) {
      final str = rawDateStr.toLowerCase().trim();
      if (str.contains('min') || str.contains('m ago')) {
        final num = RegExp(r'\d+').stringMatch(str) ?? '1';
        return '$num ${context.tr('mins_ago')}';
      }
      if (str.contains('hour') || str.contains('h ago')) {
        final num = RegExp(r'\d+').stringMatch(str) ?? '1';
        return '$num ${context.tr('hours_ago')}';
      }
      if (str.contains('day') || str.contains('d ago')) {
        final num = RegExp(r'\d+').stringMatch(str) ?? '1';
        return '$num ${context.tr('days_ago')}';
      }
      if (str.contains('month') || str.contains('mo ago')) {
        final num = RegExp(r'\d+').stringMatch(str) ?? '1';
        return '$num ${context.tr('months_ago')}';
      }
      return str;
    }
  }

  String get formattedDistance => getFormattedDistance();

  /// Formatted string describing user location
  String getUserWhereIs([double? userLat, double? userLng]) {
    final loc = location ?? user?.location ?? PresenceService.currentPlaceName;
    final dist = getFormattedDistance(userLat, userLng);
    return '$loc • $dist';
  }

  factory LiveWorkCardModel.fromJson(Map<String, dynamic> json) {
    // Extract media URLs
    List<String> mediaUrls = [];
    dynamic rawMedia = json['medias'] ??
        json['media'] ??
        json['images'] ??
        json['photos'] ??
        json['user_media'] ??
        json['card_media'] ??
        json['card_images'] ??
        json['media_urls'] ??
        json['gallery'] ??
        json['attachments'];

    if (rawMedia is List) {
      for (final m in rawMedia) {
        if (m is Map) {
          final url = m['file_url'] ??
              m['original_url'] ??
              m['full_url'] ??
              m['url'] ??
              m['preview_url'] ??
              m['media_url'] ??
              m['path'] ??
              m['image_url'] ??
              m['file_path'] ??
              m['src'] ??
              m['file'];
          if (url != null && url.toString().isNotEmpty) {
            final fixed = ApiConfig.fixImageUrl(url.toString());
            if (!mediaUrls.contains(fixed)) mediaUrls.add(fixed);
          }
        } else if (m != null && m.toString().isNotEmpty) {
          final fixed = ApiConfig.fixImageUrl(m.toString());
          if (!mediaUrls.contains(fixed)) mediaUrls.add(fixed);
        }
      }
    } else if (rawMedia is Map) {
      final url = rawMedia['file_url'] ??
          rawMedia['original_url'] ??
          rawMedia['full_url'] ??
          rawMedia['url'] ??
          rawMedia['media_url'] ??
          rawMedia['path'] ??
          rawMedia['image_url'] ??
          rawMedia['file_path'] ??
          rawMedia['src'];
      if (url != null && url.toString().isNotEmpty) {
        final fixed = ApiConfig.fixImageUrl(url.toString());
        if (!mediaUrls.contains(fixed)) mediaUrls.add(fixed);
      }
    }

    dynamic rawThumb = json['thumbnail_url'] ??
        json['thumbnail'] ??
        json['image_url'] ??
        json['image'] ??
        json['cover_image'] ??
        json['cover'] ??
        json['file_path'] ??
        json['file_url'];

    if (rawThumb is Map) {
      rawThumb = rawThumb['file_url'] ??
          rawThumb['original_url'] ??
          rawThumb['url'] ??
          rawThumb['media_url'] ??
          rawThumb['path'] ??
          rawThumb['image_url'];
    }

    if (rawThumb != null && rawThumb.toString().isNotEmpty) {
      final fixedThumb = ApiConfig.fixImageUrl(rawThumb.toString());
      if (!mediaUrls.contains(fixedThumb)) {
        mediaUrls.insert(0, fixedThumb);
      }
    }

    // Extract reviews from card or card owner user
    List<CardReviewModel> reviewList = [];
    final rawCardReviews = json['reviews'] ?? json['latest_reviews'];
    if (rawCardReviews is List && rawCardReviews.isNotEmpty) {
      for (final r in rawCardReviews) {
        if (r is Map<String, dynamic>) {
          reviewList.add(CardReviewModel.fromJson(r));
        }
      }
    }

    final userMap = json['user'] as Map<String, dynamic>?;
    if (reviewList.isEmpty && userMap != null && userMap['reviews'] is List) {
      for (final r in userMap['reviews']) {
        if (r is Map<String, dynamic>) {
          reviewList.add(CardReviewModel.fromJson(r));
        }
      }
    }

    double computedRating = json['rating'] != null ? (json['rating'] as num).toDouble() : 0.0;
    int computedReviewsCount = json['reviews_count'] is int
        ? json['reviews_count']
        : int.tryParse(json['reviews_count']?.toString() ?? '0') ?? 0;

    if (reviewList.isNotEmpty) {
      final double totalRating = reviewList.fold(0.0, (sum, r) => sum + r.rating);
      computedRating = double.parse((totalRating / reviewList.length).toStringAsFixed(1));
      if (computedReviewsCount < reviewList.length) {
        computedReviewsCount = reviewList.length;
      }
    }

    List<String> parsedTags = [];
    if (json['tags'] is List) {
      parsedTags = (json['tags'] as List).map((e) => e.toString()).toList();
    } else if (json['tags'] is String && (json['tags'] as String).isNotEmpty) {
      parsedTags = (json['tags'] as String).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    final String? rawExpiresAt = json['expires_at']?.toString() ?? json['expiry_time']?.toString();

    int parseStatus(dynamic rawStatus) {
      if (rawStatus is int) return rawStatus;
      if (rawStatus == null) return 1;
      final str = rawStatus.toString().trim().toLowerCase();
      if (str == '1' || str == 'active' || str == 'published') return 1;
      if (str == '2' || str == 'paused' || str == 'inactive') return 2;
      if (str == '3' || str == 'expired') return 3;
      if (str == '0' || str == 'draft') return 0;
      return int.tryParse(str) ?? 1;
    }

    final parsedUser = json['user'] != null && json['user'] is Map<String, dynamic>
        ? UserModel.fromJson(json['user'])
        : null;

    double? parseCoord(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble() != 0 ? val.toDouble() : null;
      if (val is String) {
        final d = double.tryParse(val);
        return d != null && d != 0 ? d : null;
      }
      return null;
    }

    final double? cardLat = parseCoord(json['latitude']) ?? parseCoord(json['lat']) ?? parsedUser?.latitude;
    final double? cardLng = parseCoord(json['longitude']) ?? parseCoord(json['lng']) ?? parsedUser?.longitude;
    final String? cardLocation = json['location']?.toString() ?? parsedUser?.location;

    return LiveWorkCardModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      title: json['title'] ?? AppLanguage.trCode('live_work'),
      description: json['description'],
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      priceType: json['price_type'],
      priceUnit: json['price_unit'],
      currency: json['currency'] ?? 'INR',
      location: cardLocation,
      latitude: cardLat,
      longitude: cardLng,
      distanceKm: json['distance_km'] != null ? (json['distance_km'] as num).toDouble() : null,
      status: parseStatus(json['status'] ?? json['status_code'] ?? json['status_name']),
      viewsCount: json['views_count'] is int ? json['views_count'] : int.tryParse(json['views_count'].toString()) ?? 0,
      rating: computedRating,
      reviewsCount: computedReviewsCount,
      thumbnailUrl: rawThumb != null ? ApiConfig.fixImageUrl(rawThumb) : null,
      images: mediaUrls,
      reviews: reviewList,
      tags: parsedTags,
      expiresAt: rawExpiresAt,
      category: json['category'] != null && json['category'] is Map<String, dynamic>
          ? CategoryModel.fromJson(json['category'])
          : null,
      user: parsedUser,
      isFavorite: json['is_favorite'] == true || json['is_favorite'] == 1,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

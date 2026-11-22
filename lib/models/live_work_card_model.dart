import 'dart:math' as math;
import '../core/api_config.dart';
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
  final double rating;
  final String review;
  final String? createdAt;
  final String reviewerName;
  final String? reviewerAvatar;

  CardReviewModel({
    required this.id,
    required this.rating,
    required this.review,
    this.createdAt,
    required this.reviewerName,
    this.reviewerAvatar,
  });

  factory CardReviewModel.fromJson(Map<String, dynamic> json) {
    final reviewer = json['reviewer'] as Map<String, dynamic>? ?? {};
    final rawName = reviewer['name']?.toString() ?? json['name']?.toString() ?? json['reviewer_name']?.toString() ?? 'Reviewer';
    final rawAvatar = reviewer['avatar_url']?.toString() ?? json['avatar']?.toString() ?? json['reviewer_avatar']?.toString();

    return CardReviewModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : 5.0,
      review: json['review']?.toString() ?? json['comment']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? json['date']?.toString(),
      reviewerName: rawName,
      reviewerAvatar: rawAvatar != null ? ApiConfig.fixImageUrl(rawAvatar) : null,
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
    this.category,
    this.user,
    this.isFavorite = false,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 1;
  String get statusLabel => isActive ? 'Active' : 'Paused';

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

  String getFormattedDistance([double? userLat, double? userLng]) {
    double? km = distanceKm;

    if (km == null && userLat != null && userLng != null) {
      final targetLat = latitude;
      final targetLng = longitude;
      if (targetLat != null && targetLng != null) {
        km = calculateDistanceKm(
          lat1: userLat,
          lon1: userLng,
          lat2: targetLat,
          lon2: targetLng,
        );
      }
    }

    if (km != null) {
      if (km < 1.0) {
        return '${(km * 1000).round()} m away';
      }
      return '${km.toStringAsFixed(1)} km away';
    }

    return location ?? 'Nearby';
  }

  String get formattedDistance => getFormattedDistance();

  factory LiveWorkCardModel.fromJson(Map<String, dynamic> json) {
    // Extract media URLs
    List<String> mediaUrls = [];
    if (json['medias'] is List) {
      for (final m in json['medias']) {
        if (m is Map && m['file_url'] != null) {
          mediaUrls.add(ApiConfig.fixImageUrl(m['file_url'].toString()));
        }
      }
    }
    if (mediaUrls.isEmpty && json['thumbnail_url'] != null) {
      mediaUrls.add(ApiConfig.fixImageUrl(json['thumbnail_url'].toString()));
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

    final rawThumb = json['thumbnail_url']?.toString();

    return LiveWorkCardModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      title: json['title'] ?? 'Live Work',
      description: json['description'],
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      priceType: json['price_type'],
      priceUnit: json['price_unit'],
      currency: json['currency'] ?? 'INR',
      location: json['location'],
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      distanceKm: json['distance_km'] != null ? (json['distance_km'] as num).toDouble() : null,
      status: json['status'] is int ? json['status'] : int.tryParse(json['status'].toString()) ?? 1,
      viewsCount: json['views_count'] is int ? json['views_count'] : int.tryParse(json['views_count'].toString()) ?? 0,
      rating: computedRating,
      reviewsCount: computedReviewsCount,
      thumbnailUrl: rawThumb != null ? ApiConfig.fixImageUrl(rawThumb) : null,
      images: mediaUrls,
      reviews: reviewList,
      category: json['category'] != null && json['category'] is Map<String, dynamic>
          ? CategoryModel.fromJson(json['category'])
          : null,
      user: json['user'] != null && json['user'] is Map<String, dynamic>
          ? UserModel.fromJson(json['user'])
          : null,
      isFavorite: json['is_favorite'] == true || json['is_favorite'] == 1,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

import 'dart:io';
import '../core/api_config.dart';
import '../core/api_service.dart';
import '../models/live_work_card_model.dart';

class MyLiveWorkService {
  /// Fetch all Live Work cards owned by the authenticated user.
  static Future<List<LiveWorkCardModel>> fetchMyLiveWorkCards() async {
    final response = await ApiService.get(ApiConfig.myLiveWorks);

    if (response.success && response.data != null) {
      final List list = response.data is List ? response.data : [];
      return list.map((item) => LiveWorkCardModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Create a new Live Work card with optional images.
  static Future<ApiResponse> createLiveWorkCard({
    required String title,
    int? categoryId,
    String? description,
    double? price,
    String? priceType,
    String? location,
    String? expiryTime,
    List<String>? tags,
    List<File>? images,
  }) async {
    final Map<String, dynamic> jsonBody = {
      'title': title,
      if (categoryId != null) 'category_id': categoryId,
      if (description != null) 'description': description,
      if (price != null) 'price': price,
      if (priceType != null) 'price_type': priceType,
      if (location != null) 'location': location,
      if (expiryTime != null) 'expiry_time': expiryTime,
      if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
    };

    if (images != null && images.isNotEmpty) {
      final stringFields = <String, String>{};
      jsonBody.forEach((key, value) {
        if (value != null) stringFields[key] = value.toString();
      });
      return await ApiService.multipartPost(
        ApiConfig.createLiveWork,
        fields: stringFields,
        files: images,
        fileParamName: 'images[]',
      );
    } else {
      return await ApiService.post(
        ApiConfig.createLiveWork,
        body: jsonBody,
      );
    }
  }

  /// Update an existing Live Work card
  static Future<ApiResponse> updateLiveWorkCard({
    required int id,
    required String title,
    int? categoryId,
    String? description,
    double? price,
    String? priceType,
    String? location,
    String? expiryTime,
    List<String>? tags,
    List<File>? images,
  }) async {
    final Map<String, dynamic> jsonBody = {
      'title': title,
      if (categoryId != null) 'category_id': categoryId,
      if (description != null) 'description': description,
      if (price != null) 'price': price,
      if (priceType != null) 'price_type': priceType,
      if (location != null) 'location': location,
      if (expiryTime != null) 'expiry_time': expiryTime,
      if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
    };

    if (images != null && images.isNotEmpty) {
      final stringFields = <String, String>{
        '_method': 'PUT',
      };
      jsonBody.forEach((key, value) {
        if (value != null) stringFields[key] = value.toString();
      });

      return await ApiService.multipartPost(
        ApiConfig.updateLiveWork(id),
        fields: stringFields,
        files: images,
        fileParamName: 'images[]',
      );
    } else {
      var response = await ApiService.put(
        ApiConfig.updateLiveWork(id),
        body: jsonBody,
      );

      if (!response.success) {
        final stringBody = <String, dynamic>{
          '_method': 'PUT',
        };
        jsonBody.forEach((key, value) {
          if (value != null) stringBody[key] = value;
        });
        response = await ApiService.post(
          ApiConfig.updateLiveWork(id),
          body: stringBody,
        );
      }
      return response;
    }
  }

  /// Toggle Live Work card status (Active <-> Paused) and reset expiration if activating.
  static Future<ApiResponse> toggleCardStatus(int id, {bool? currentIsActive}) async {
    final bool isCurrentlyActive = currentIsActive ?? true;
    final nextStatus = isCurrentlyActive ? 'paused' : 'active';
    final nextStatusCode = isCurrentlyActive ? 2 : 1;

    final now = DateTime.now();
    final newExpiryDate = now.add(const Duration(hours: 24));
    final newExpiryFormatted = "${newExpiryDate.year}-${newExpiryDate.month.toString().padLeft(2, '0')}-${newExpiryDate.day.toString().padLeft(2, '0')} ${newExpiryDate.hour.toString().padLeft(2, '0')}:${newExpiryDate.minute.toString().padLeft(2, '0')}:${newExpiryDate.second.toString().padLeft(2, '0')}";

    final body = <String, dynamic>{
      'status': nextStatusCode,
      'status_code': nextStatusCode,
      'status_name': nextStatus,
      'is_active': isCurrentlyActive ? 0 : 1,
      if (!isCurrentlyActive) 'expires_at': newExpiryFormatted,
      if (!isCurrentlyActive) 'expiry_time': '24 hours',
    };

    // 1. Try PUT directly on card endpoint to update MySQL columns
    var response = await ApiService.put(
      ApiConfig.updateLiveWork(id),
      body: body,
    );

    if (!response.success) {
      // 2. Try PATCH on status endpoint
      response = await ApiService.patch(
        ApiConfig.toggleLiveWorkStatus(id),
        body: body,
      );
    }

    if (!response.success) {
      // 3. Try POST on status endpoint
      response = await ApiService.post(
        ApiConfig.toggleLiveWorkStatus(id),
        body: body,
      );
    }

    return response;
  }

  /// Bump / Repost Live Work card: sets status=1 (Active) and extends expires_at by +24 hours.
  static Future<ApiResponse> bumpCard(int id, {String? expiryTime}) async {
    final now = DateTime.now();
    final newExpiryDate = now.add(const Duration(hours: 24));
    final newExpiryFormatted = "${newExpiryDate.year}-${newExpiryDate.month.toString().padLeft(2, '0')}-${newExpiryDate.day.toString().padLeft(2, '0')} ${newExpiryDate.hour.toString().padLeft(2, '0')}:${newExpiryDate.minute.toString().padLeft(2, '0')}:${newExpiryDate.second.toString().padLeft(2, '0')}";

    final body = <String, dynamic>{
      'status': 1,
      'status_code': 1,
      'status_name': 'active',
      'is_active': 1,
      'expiry_time': expiryTime ?? '24 hours',
      'expires_at': newExpiryFormatted,
      'updated_at': now.toIso8601String(),
    };

    // 1. Try PUT update on primary card endpoint to update status=1 & expires_at in MySQL
    var response = await ApiService.put(
      ApiConfig.updateLiveWork(id),
      body: body,
    );

    if (!response.success) {
      // 2. Try POST /my-cards/live-work/{id}/repost
      response = await ApiService.post(
        '${ApiConfig.baseUrl}/my-cards/live-work/$id/repost',
        body: body,
      );
    }

    if (!response.success) {
      // 3. Try POST /my-cards/live-work/{id}/bump
      response = await ApiService.post(
        ApiConfig.bumpLiveWork(id),
        body: body,
      );
    }

    return response;
  }

  /// Delete a Live Work card.
  static Future<ApiResponse> deleteCard(int id) async {
    return await ApiService.delete(ApiConfig.deleteLiveWork(id));
  }
}

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
    List<File>? images,
  }) async {
    final fields = <String, String>{
      'title': title,
    };

    if (categoryId != null) fields['category_id'] = categoryId.toString();
    if (description != null && description.isNotEmpty) fields['description'] = description;
    if (price != null) fields['price'] = price.toString();
    if (priceType != null && priceType.isNotEmpty) fields['price_type'] = priceType;
    if (location != null && location.isNotEmpty) fields['location'] = location;

    if (images != null && images.isNotEmpty) {
      return await ApiService.multipartPost(
        ApiConfig.createLiveWork,
        fields: fields,
        files: images,
        fileParamName: 'images[]',
      );
    } else {
      return await ApiService.post(
        ApiConfig.createLiveWork,
        body: fields,
      );
    }
  }

  /// Toggle Live Work card status (Active <-> Paused).
  static Future<ApiResponse> toggleCardStatus(int id) async {
    return await ApiService.patch(ApiConfig.toggleLiveWorkStatus(id));
  }

  /// Bump Live Work card position to top.
  static Future<ApiResponse> bumpCard(int id) async {
    return await ApiService.post(ApiConfig.bumpLiveWork(id));
  }

  /// Delete a Live Work card.
  static Future<ApiResponse> deleteCard(int id) async {
    return await ApiService.delete(ApiConfig.deleteLiveWork(id));
  }
}

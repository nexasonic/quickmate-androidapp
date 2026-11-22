import '../core/api_config.dart';
import '../core/api_service.dart';
import '../models/category_model.dart';
import '../models/live_work_card_model.dart';

class LiveWorkService {
  /// Fetch paginated Live Work cards with optional search, category, coordinate distance, and sorting.
  static Future<List<LiveWorkCardModel>> fetchLiveWorkCards({
    String? search,
    int? categoryId,
    String? sort,
    double? lat,
    double? lng,
    int page = 1,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
    };

    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (categoryId != null && categoryId > 0) {
      queryParams['category_id'] = categoryId.toString();
    }
    if (sort != null && sort.isNotEmpty) {
      queryParams['sort'] = sort;
    }
    if (lat != null && lng != null) {
      queryParams['lat'] = lat.toString();
      queryParams['lng'] = lng.toString();
    }

    final queryString = Uri(queryParameters: queryParams).query;
    final url = '${ApiConfig.liveWorks}?$queryString';

    final response = await ApiService.get(url, withAuth: true);

    if (response.success && response.data != null) {
      final List list = response.data is List ? response.data : (response.data['data'] ?? []);
      return list.map((item) => LiveWorkCardModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Fetch full details of a specific card by type and ID.
  static Future<LiveWorkCardModel?> fetchLiveWorkDetails(int id, {String cardType = 'live-work'}) async {
    final url = ApiConfig.cardDetail(cardType, id);
    final response = await ApiService.get(url, withAuth: true);
    if (response.success && response.data != null) {
      final map = response.data is Map<String, dynamic> ? response.data : null;
      if (map != null) {
        return LiveWorkCardModel.fromJson(map);
      }
    }
    return null;
  }

  /// Fetch aggregated home feed for Live Works and categories.
  static Future<Map<String, dynamic>> fetchHomeData({double? lat, double? lng}) async {
    String url = ApiConfig.home;
    if (lat != null && lng != null) {
      url += '?lat=$lat&lng=$lng';
    }

    final response = await ApiService.get(url, withAuth: true);

    if (response.success && response.data != null) {
      final data = response.data as Map<String, dynamic>;

      final List liveWorksList = data['live_works'] ?? [];
      final liveWorks = liveWorksList.map((item) => LiveWorkCardModel.fromJson(item as Map<String, dynamic>)).toList();

      final List categoriesList = data['categories'] ?? [];
      final categories = categoriesList.map((item) => CategoryModel.fromJson(item as Map<String, dynamic>)).toList();

      final stats = data['stats'] as Map<String, dynamic>? ?? {};

      return {
        'live_works': liveWorks,
        'categories': categories,
        'stats': stats,
      };
    }

    return {
      'live_works': <LiveWorkCardModel>[],
      'categories': <CategoryModel>[],
      'stats': {},
    };
  }

  /// Fetch top-level categories.
  static Future<List<CategoryModel>> fetchCategories() async {
    final response = await ApiService.get(ApiConfig.categories, withAuth: true);

    if (response.success && response.data != null) {
      final List list = response.data is List ? response.data : [];
      return list.map((item) => CategoryModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Bookmark or unbookmark a card (card_type 1=LiveWork, 2=Service, 3=Job, 4=Freelancer, 5=Business).
  static Future<ApiResponse> toggleSavedCard(int cardId, {int cardType = 1}) async {
    final response = await ApiService.post(
      ApiConfig.toggleSavedCard,
      body: {
        'card_type': cardType,
        'card_id': cardId,
      },
    );
    return response;
  }

  /// Add a review for a user/card in the database.
  static Future<ApiResponse> addReview({
    required int ownerUserId,
    required int cardId,
    required double rating,
    required String review,
  }) async {
    final response = await ApiService.post(
      ApiConfig.addUserReview(ownerUserId),
      body: {
        'rating': rating.round(),
        'review': review,
        'card_type': 2,
        'card_id': cardId,
      },
    );
    return response;
  }
}

import '../core/api_config.dart';
import '../core/api_service.dart';
import '../models/category_model.dart';
import '../models/live_work_card_model.dart';

class PaginatedLiveWorkCards {
  final List<LiveWorkCardModel> cards;
  final int currentPage;
  final int lastPage;
  final int total;
  final bool hasMore;

  PaginatedLiveWorkCards({
    required this.cards,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.hasMore,
  });
}

class LiveWorkService {
  /// Fetch paginated Live Work cards with metadata (page, lastPage, hasMore).
  static Future<PaginatedLiveWorkCards> fetchLiveWorkCardsPaginated({
    String? search,
    int? categoryId,
    String? sort,
    double? lat,
    double? lng,
    int page = 1,
    int perPage = 15,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
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
      final cards = list.map((item) => LiveWorkCardModel.fromJson(item as Map<String, dynamic>)).toList();

      final meta = response.meta ?? (response.data is Map ? response.data['meta'] : null);
      final currentPage = meta?['current_page'] is int ? meta['current_page'] as int : page;
      final lastPage = meta?['last_page'] is int ? meta['last_page'] as int : 1;
      final total = meta?['total'] is int ? meta['total'] as int : cards.length;
      final bool hasMore = meta?['has_more'] is bool
          ? meta['has_more'] as bool
          : (currentPage < lastPage);

      return PaginatedLiveWorkCards(
        cards: cards,
        currentPage: currentPage,
        lastPage: lastPage,
        total: total,
        hasMore: hasMore,
      );
    }

    return PaginatedLiveWorkCards(
      cards: [],
      currentPage: page,
      lastPage: 1,
      total: 0,
      hasMore: false,
    );
  }

  /// Fetch paginated Live Work cards with optional search, category, coordinate distance, and sorting.
  static Future<List<LiveWorkCardModel>> fetchLiveWorkCards({
    String? search,
    int? categoryId,
    String? sort,
    double? lat,
    double? lng,
    int page = 1,
  }) async {
    final paginated = await fetchLiveWorkCardsPaginated(
      search: search,
      categoryId: categoryId,
      sort: sort,
      lat: lat,
      lng: lng,
      page: page,
    );
    return paginated.cards;
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
    int cardId = 0,
    int cardTypeInt = 1,
    required double rating,
    required String review,
  }) async {
    final response = await ApiService.post(
      ApiConfig.addUserReview(ownerUserId),
      body: {
        'rating': rating.round(),
        'review': review,
        'card_type': cardId > 0 ? cardTypeInt : 0,
        if (cardId > 0) 'card_id': cardId,
      },
    );
    return response;
  }
}

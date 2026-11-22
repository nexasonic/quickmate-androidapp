class ApiConfig {
  // Base API URL (Default to Android Emulator loopback, adaptable for physical/web)
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';
  static const String storageUrl = 'http://10.0.2.2:8000/storage/';

  // Auth Endpoints
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';
  static const String logout = '$baseUrl/auth/logout';
  static const String socialLogin = '$baseUrl/auth/social-login';

  // Home & Feed
  static const String home = '$baseUrl/home';
  static const String categories = '$baseUrl/categories';

  // Live Work Cards Exploration
  static const String liveWorks = '$baseUrl/cards/live-works';
  static String liveWorkDetail(int id) => '$baseUrl/cards/live-work/$id';
  static String cardDetail(String type, int id) {
    final formattedType = type.replaceAll('_', '-');
    return '$baseUrl/cards/$formattedType/$id';
  }
  static String addUserReview(int userId) => '$baseUrl/users/$userId/reviews';
  static const String recordView = '$baseUrl/cards/view';

  // My Live Work Cards CRUD
  static const String myLiveWorks = '$baseUrl/my-cards?type=live-work';
  static const String createLiveWork = '$baseUrl/my-cards/live-work';
  static String updateLiveWork(int id) => '$baseUrl/my-cards/live-work/$id';
  static String toggleLiveWorkStatus(int id) => '$baseUrl/my-cards/live-work/$id/status';
  static String bumpLiveWork(int id) => '$baseUrl/my-cards/live-work/$id/bump';
  static String deleteLiveWork(int id) => '$baseUrl/my-cards/live-work/$id';

  // Profile
  static const String profile = '$baseUrl/user/profile';
  static const String updateAvatar = '$baseUrl/user/avatar';

  // Saved Cards / Bookmarks
  static const String savedCards = '$baseUrl/saved-cards';
  static const String toggleSavedCard = '$baseUrl/saved-cards/toggle';

  // Chat Endpoints
  static const String conversations = '$baseUrl/chat/conversations';
  static String conversationMessages(int id) => '$baseUrl/chat/conversations/$id/messages';
  static String sendMessage(int id) => '$baseUrl/chat/conversations/$id/messages';
  static const String unreadChatCount = '$baseUrl/chat/unread-count';

  // Helper to replace 127.0.0.1 / localhost with 10.0.2.2 for Android Emulator image URLs
  static String fixImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.contains('127.0.0.1:8000')) {
      return url.replaceAll('127.0.0.1:8000', '10.0.2.2:8000');
    }
    if (url.contains('localhost:8000')) {
      return url.replaceAll('localhost:8000', '10.0.2.2:8000');
    }
    return url;
  }
}

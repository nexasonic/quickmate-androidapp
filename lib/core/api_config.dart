class ApiConfig {
  // Toggle between Local Server (10.0.2.2:8000) and Production (quickmate.nexasonic.com)
  static const bool useLocalServer = true;

  // Local Server Endpoints (10.0.2.2 loopback for Android Emulator)
  static const String localBaseUrl = 'http://10.0.2.2:8000/api/v1';
  static const String localStorageUrl = 'http://10.0.2.2:8000/storage/';

  // Production Endpoints
  static const String prodBaseUrl = 'https://quickmate.nexasonic.com/api/v1';
  static const String prodStorageUrl = 'https://quickmate.nexasonic.com/storage/';

  // Active Base API & Storage URL
  static const String baseUrl = useLocalServer ? localBaseUrl : prodBaseUrl;
  static const String storageUrl = useLocalServer ? localStorageUrl : prodStorageUrl;

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

  // Helper to normalize image URLs for Local Server & Production
  static String fixImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    var formatted = url.trim();

    if (useLocalServer) {
      if (formatted.contains('127.0.0.1:8000')) {
        formatted = formatted.replaceAll('127.0.0.1:8000', '10.0.2.2:8000');
      }
      if (formatted.contains('localhost:8000')) {
        formatted = formatted.replaceAll('localhost:8000', '10.0.2.2:8000');
      }
      if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
        if (formatted.startsWith('/')) {
          formatted = 'http://10.0.2.2:8000$formatted';
        } else {
          formatted = '$storageUrl$formatted';
        }
      }
    } else {
      if (formatted.contains('127.0.0.1:8000')) {
        formatted = formatted.replaceAll('http://127.0.0.1:8000', 'https://quickmate.nexasonic.com')
                             .replaceAll('127.0.0.1:8000', 'quickmate.nexasonic.com');
      }
      if (formatted.contains('localhost:8000')) {
        formatted = formatted.replaceAll('http://localhost:8000', 'https://quickmate.nexasonic.com')
                             .replaceAll('localhost:8000', 'quickmate.nexasonic.com');
      }
      if (formatted.contains('10.0.2.2:8000')) {
        formatted = formatted.replaceAll('http://10.0.2.2:8000', 'https://quickmate.nexasonic.com')
                             .replaceAll('10.0.2.2:8000', 'quickmate.nexasonic.com');
      }
      if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
        if (formatted.startsWith('/')) {
          formatted = 'https://quickmate.nexasonic.com$formatted';
        } else {
          formatted = '$storageUrl$formatted';
        }
      }
    }
    return formatted;
  }
}

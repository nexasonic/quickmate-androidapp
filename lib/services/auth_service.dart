import 'package:google_sign_in/google_sign_in.dart';
import '../core/api_config.dart';
import '../core/api_service.dart';
import '../core/storage_service.dart';
import '../models/user_model.dart';

class AuthService {
  static Future<ApiResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await ApiService.post(
      ApiConfig.login,
      body: {
        'email': email,
        'password': password,
        'device_name': 'QuickMate Mobile App',
      },
      withAuth: false,
    );

    if (response.success && response.data != null) {
      final token = response.data['token'] as String?;
      final userMap = response.data['user'] as Map<String, dynamic>?;

      if (token != null) {
        await StorageService.saveToken(token);
      }
      if (userMap != null) {
        await StorageService.saveUser(userMap);
      }
    }

    return response;
  }

  static Future<ApiResponse> register({
    required String name,
    required String email,
    String? phone,
    required String password,
  }) async {
    final response = await ApiService.post(
      ApiConfig.register,
      body: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'password_confirmation': password,
        'account_type': 'normal',
        'device_name': 'QuickMate Mobile App',
      },
      withAuth: false,
    );

    if (response.success && response.data != null) {
      final token = response.data['token'] as String?;
      final userMap = response.data['user'] as Map<String, dynamic>?;

      if (token != null) {
        await StorageService.saveToken(token);
      }
      if (userMap != null) {
        await StorageService.saveUser(userMap);
      }
    }

    return response;
  }

  static Future<ApiResponse> socialLogin({
    required String providerName,
    required String providerId,
    required String email,
    required String name,
    String? avatarUrl,
  }) async {
    final response = await ApiService.post(
      ApiConfig.socialLogin,
      body: {
        'provider_name': providerName,
        'provider_id': providerId,
        'email': email,
        'name': name,
        'avatar_url': avatarUrl,
        'device_name': 'QuickMate Mobile App',
      },
      withAuth: false,
    );

    if (response.success && response.data != null) {
      final token = response.data['token'] as String?;
      final userMap = response.data['user'] as Map<String, dynamic>?;

      if (token != null) {
        await StorageService.saveToken(token);
      }
      if (userMap != null) {
        await StorageService.saveUser(userMap);
      }
    }

    return response;
  }

  static Future<ApiResponse> logout() async {
    ApiResponse response;
    try {
      response = await ApiService.post(ApiConfig.logout);
    } catch (e) {
      response = ApiResponse(
        success: false,
        message: 'Logged out locally.',
        statusCode: 500,
      );
    } finally {
      try {
        final googleSignIn = GoogleSignIn();
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.signOut();
        }
      } catch (_) {}
      await StorageService.clearSession();
    }
    return response;
  }

  static UserModel? getStoredUser() {
    final map = StorageService.getUser();
    if (map != null) {
      return UserModel.fromJson(map);
    }
    return null;
  }

  static bool isLoggedIn() {
    return StorageService.hasToken();
  }
}

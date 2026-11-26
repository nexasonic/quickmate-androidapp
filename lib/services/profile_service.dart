import 'dart:io';
import '../core/api_config.dart';
import '../core/api_service.dart';
import '../core/app_language.dart';
import '../core/app_theme.dart';
import '../core/storage_service.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class ProfileService {
  /// Hydrate local SharedPreferences, theme, and locale from server profile payload.
  static Future<void> applySyncedSettings(Map<String, dynamic> dataMap) async {
    final profile = dataMap['profile'] as Map<String, dynamic>? ?? {};
    final userMap = dataMap['user'] as Map<String, dynamic>? ?? {};
    final userModel = UserModel.fromJson(dataMap);

    final hasShowLoc = dataMap.containsKey('show_location') || profile.containsKey('show_location') || userMap.containsKey('show_location');
    if (hasShowLoc) {
      await StorageService.savePrivacyShowLocation(userModel.showLocation);
    }

    if (profile.containsKey('notif_job_alerts') || userMap.containsKey('notif_job_alerts')) {
      await StorageService.saveNotifJobAlerts(userModel.notifJobAlerts);
    }
    if (profile.containsKey('notif_messages') || userMap.containsKey('notif_messages')) {
      await StorageService.saveNotifMessages(userModel.notifMessages);
    }
    if (profile.containsKey('notif_promotions') || userMap.containsKey('notif_promotions')) {
      await StorageService.saveNotifPromotions(userModel.notifPromotions);
    }

    if (profile.containsKey('pref_theme') || userMap.containsKey('pref_theme')) {
      await updateAppTheme(themeModeFromInt(userModel.prefTheme));
    }
    if (profile.containsKey('pref_language') || userMap.containsKey('pref_language')) {
      await AppLanguage.setLanguage(AppLanguage.languageCodeFromInt(userModel.prefLanguage));
    }
  }

  /// Fetch user profile details from backend and update local session storage.
  static Future<UserModel?> fetchUserProfile() async {
    final response = await ApiService.get(ApiConfig.profile);

    if (response.success && response.data != null) {
      final Map<String, dynamic> dataMap = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {};
      final userModel = UserModel.fromJson(dataMap);
      await StorageService.saveUser(userModel.toJson());
      await applySyncedSettings(dataMap);
      return userModel;
    }
    return AuthService.getStoredUser();
  }

  /// Fetch full rich profile data (profile, skills, experiences, educations).
  static Future<Map<String, dynamic>?> fetchFullProfileData() async {
    final response = await ApiService.get(ApiConfig.profile);
    if (response.success && response.data != null) {
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Update user profile details & synced preference fields.
  static Future<ApiResponse> updateProfile({
    String? name,
    String? phone,
    String? bio,
    String? tagline,
    String? headline,
    String? location,
    String? gender,
    String? dateOfBirth,
    String? languages,
    String? whatsapp,
    String? website,
    String? linkedin,
    String? instagram,
    String? workingHours,
    String? availabilityStatus,
    bool? showLocation,
    bool? notifJobAlerts,
    bool? notifMessages,
    bool? notifBookings,
    bool? notifPromotions,
    int? prefTheme,
    int? prefLanguage,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (bio != null) body['bio'] = bio;
    if (tagline != null) body['tagline'] = tagline;
    if (headline != null) body['headline'] = headline;
    if (location != null) body['location'] = location;
    if (gender != null) body['gender'] = gender;
    if (dateOfBirth != null) body['date_of_birth'] = dateOfBirth;
    if (languages != null) body['languages'] = languages;
    if (whatsapp != null) body['whatsapp'] = whatsapp;
    if (website != null) body['website'] = website;
    if (linkedin != null) body['linkedin'] = linkedin;
    if (instagram != null) body['instagram'] = instagram;
    if (workingHours != null) body['working_hours'] = workingHours;
    if (availabilityStatus != null) body['availability_status'] = availabilityStatus;
    if (showLocation != null) body['show_location'] = showLocation;
    if (notifJobAlerts != null) body['notif_job_alerts'] = notifJobAlerts;
    if (notifMessages != null) body['notif_messages'] = notifMessages;
    if (notifBookings != null) body['notif_bookings'] = notifBookings;
    if (notifPromotions != null) body['notif_promotions'] = notifPromotions;
    if (prefTheme != null) body['pref_theme'] = prefTheme;
    if (prefLanguage != null) body['pref_language'] = prefLanguage;

    final response = await ApiService.put(ApiConfig.profile, body: body);

    if (response.success && response.data != null) {
      if (response.data is Map<String, dynamic>) {
        final dataMap = response.data as Map<String, dynamic>;
        final userModel = UserModel.fromJson(dataMap);
        await StorageService.saveUser(userModel.toJson());
      }
    }

    return response;
  }

  /// Store skill
  /// Store skill
  static Future<ApiResponse> storeSkill({
    required String name,
    String proficiency = 'Intermediate',
    int experienceYears = 1,
    String? description,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'proficiency': proficiency,
      'experience_years': experienceYears,
    };
    if (description != null && description.trim().isNotEmpty) {
      body['description'] = description.trim();
    }
    return await ApiService.post(
      '${ApiConfig.baseUrl}/user/skills',
      body: body,
    );
  }

  /// Update skill
  static Future<ApiResponse> updateSkill(
    int id, {
    required String name,
    String proficiency = 'Intermediate',
    int experienceYears = 1,
    String? description,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'proficiency': proficiency,
      'experience_years': experienceYears,
    };
    if (description != null && description.trim().isNotEmpty) {
      body['description'] = description.trim();
    }
    return await ApiService.put(
      '${ApiConfig.baseUrl}/user/skills/$id',
      body: body,
    );
  }

  /// Delete skill
  static Future<ApiResponse> destroySkill(int id) async {
    return await ApiService.delete('${ApiConfig.baseUrl}/user/skills/$id');
  }

  /// Store work experience
  static Future<ApiResponse> storeExperience({
    required String jobTitle,
    required String company,
    String? employmentType,
    required String startDate,
    String? endDate,
    bool isCurrent = false,
    String? location,
    String? description,
  }) async {
    return await ApiService.post(
      '${ApiConfig.baseUrl}/user/experience',
      body: {
        'job_title': jobTitle,
        'company': company,
        'employment_type': employmentType ?? 'Full-time',
        'start_date': startDate,
        'end_date': isCurrent ? null : endDate,
        'is_current': isCurrent,
        'location': location,
        'description': description,
      },
    );
  }

  /// Update work experience
  static Future<ApiResponse> updateExperience(
    int id, {
    required String jobTitle,
    required String company,
    String? employmentType,
    required String startDate,
    String? endDate,
    bool isCurrent = false,
    String? location,
    String? description,
  }) async {
    return await ApiService.put(
      '${ApiConfig.baseUrl}/user/experience/$id',
      body: {
        'job_title': jobTitle,
        'company': company,
        'employment_type': employmentType ?? 'Full-time',
        'start_date': startDate,
        'end_date': isCurrent ? null : endDate,
        'is_current': isCurrent,
        'location': location,
        'description': description,
      },
    );
  }

  /// Delete work experience
  static Future<ApiResponse> destroyExperience(int id) async {
    return await ApiService.delete('${ApiConfig.baseUrl}/user/experience/$id');
  }

  /// Store education
  static Future<ApiResponse> storeEducation({
    required String institution,
    required String degree,
    String? fieldOfStudy,
    required String startYear,
    String? endYear,
    bool isCurrent = false,
    String? description,
  }) async {
    return await ApiService.post(
      '${ApiConfig.baseUrl}/user/education',
      body: {
        'institution': institution,
        'degree': degree,
        'field_of_study': fieldOfStudy,
        'start_year': startYear,
        'end_year': endYear,
        'is_current': isCurrent,
        'description': description,
      },
    );
  }

  /// Update education
  static Future<ApiResponse> updateEducation(
    int id, {
    required String institution,
    required String degree,
    String? fieldOfStudy,
    required String startYear,
    String? endYear,
    bool isCurrent = false,
    String? description,
  }) async {
    return await ApiService.put(
      '${ApiConfig.baseUrl}/user/education/$id',
      body: {
        'institution': institution,
        'degree': degree,
        'field_of_study': fieldOfStudy,
        'start_year': startYear,
        'end_year': endYear,
        'is_current': isCurrent,
        'description': description,
      },
    );
  }

  /// Delete education
  static Future<ApiResponse> destroyEducation(int id) async {
    return await ApiService.delete('${ApiConfig.baseUrl}/user/education/$id');
  }

  /// Upload gallery media / photo
  static Future<ApiResponse> uploadGalleryMedia(File file) async {
    // 1. Try POST /user/media with fileParamName 'media_file'
    var response = await ApiService.multipartPost(
      '${ApiConfig.baseUrl}/user/media',
      files: [file],
      fileParamName: 'media_file',
    );
    // 2. Try POST /user/media with fileParamName 'image'
    if (!response.success) {
      response = await ApiService.multipartPost(
        '${ApiConfig.baseUrl}/user/media',
        files: [file],
        fileParamName: 'image',
      );
    }
    // 3. Try POST /user/gallery with fileParamName 'media_file'
    if (!response.success) {
      response = await ApiService.multipartPost(
        '${ApiConfig.baseUrl}/user/gallery',
        files: [file],
        fileParamName: 'media_file',
      );
    }
    return response;
  }

  /// Delete gallery media / photo
  static Future<ApiResponse> destroyGalleryMedia(int id) async {
    return await ApiService.delete('${ApiConfig.baseUrl}/user/media/$id');
  }

  /// Update user avatar photo
  static Future<ApiResponse> updateAvatarPhoto(File file) async {
    // 1. Try POST /user/avatar with fileParamName 'avatar'
    var response = await ApiService.multipartPost(
      ApiConfig.updateAvatar,
      files: [file],
      fileParamName: 'avatar',
    );

    // 2. Try POST /user/profile with fileParamName 'avatar'
    if (!response.success) {
      response = await ApiService.multipartPost(
        ApiConfig.profile,
        files: [file],
        fileParamName: 'avatar',
      );
    }

    // 3. Try POST /user/avatar with fileParamName 'image'
    if (!response.success) {
      response = await ApiService.multipartPost(
        ApiConfig.updateAvatar,
        files: [file],
        fileParamName: 'image',
      );
    }

    if (response.success && response.data != null) {
      final userMap = response.data['user'] as Map<String, dynamic>? ?? response.data;
      if (userMap is Map<String, dynamic>) {
        await StorageService.saveUser(userMap);
      }
    }
    return response;
  }

  /// Update user cover photo / banner
  static Future<ApiResponse> updateCoverPhoto(File file) async {
    // 1. Try POST /user/cover with fileParamName 'cover'
    var response = await ApiService.multipartPost(
      '${ApiConfig.baseUrl}/user/cover',
      files: [file],
      fileParamName: 'cover',
    );

    // 2. Try POST /user/cover-photo with fileParamName 'cover_photo'
    if (!response.success) {
      response = await ApiService.multipartPost(
        '${ApiConfig.baseUrl}/user/cover-photo',
        files: [file],
        fileParamName: 'cover_photo',
      );
    }

    if (response.success) {
      await fetchUserProfile();
    }

    return response;
  }

  /// Submit profile verification request with ID card documents and Razorpay payment details.
  static Future<ApiResponse> submitVerificationRequest({
    required String idType,
    required String idNumber,
    required File frontPhoto,
    File? backPhoto,
    String? paymentId,
    double feeAmount = 2.00,
  }) async {
    final fields = <String, String>{
      'id_type': idType,
      'id_number': idNumber,
      'fee_amount': feeAmount.toStringAsFixed(2),
      'payment_status': 'paid',
    };
    if (paymentId != null) {
      fields['payment_id'] = paymentId;
    }

    final files = <File>[frontPhoto];
    if (backPhoto != null) files.add(backPhoto);

    final response = await ApiService.multipartPost(
      '${ApiConfig.baseUrl}/user/verification-request',
      fields: fields,
      files: files,
      fileParamName: 'documents[]',
    );

    if (!response.success) {
      return await ApiService.multipartPost(
        '${ApiConfig.baseUrl}/user/verify',
        fields: fields,
        files: files,
        fileParamName: 'documents[]',
      );
    }
    return response;
  }
}

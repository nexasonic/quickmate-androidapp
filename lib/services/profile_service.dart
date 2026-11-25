import 'dart:io';
import '../core/api_config.dart';
import '../core/api_service.dart';
import '../core/storage_service.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class ProfileService {
  /// Fetch user profile details from backend and update local session storage.
  static Future<UserModel?> fetchUserProfile() async {
    final response = await ApiService.get(ApiConfig.profile);

    if (response.success && response.data != null) {
      final Map<String, dynamic> dataMap = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {};
      final userModel = UserModel.fromJson(dataMap);
      await StorageService.saveUser(userModel.toJson());
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

  /// Update user profile details.
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

    final response = await ApiService.put(ApiConfig.profile, body: body);

    if (response.success && response.data != null) {
      final userMap = response.data['user'] as Map<String, dynamic>? ?? response.data;
      if (userMap is Map<String, dynamic>) {
        await StorageService.saveUser(userMap);
      }
    }

    return response;
  }

  /// Store skill
  static Future<ApiResponse> storeSkill({
    required String name,
    String proficiency = 'intermediate',
    int experienceYears = 1,
  }) async {
    return await ApiService.post(
      '${ApiConfig.baseUrl}/user/skills',
      body: {
        'name': name,
        'proficiency': proficiency,
        'experience_years': experienceYears,
      },
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

  /// Delete education
  static Future<ApiResponse> destroyEducation(int id) async {
    return await ApiService.delete('${ApiConfig.baseUrl}/user/education/$id');
  }

  /// Upload gallery media / photo
  static Future<ApiResponse> uploadGalleryMedia(File file) async {
    final response = await ApiService.multipartPost(
      '${ApiConfig.baseUrl}/user/media',
      files: [file],
      fileParamName: 'image',
    );
    if (!response.success) {
      return await ApiService.multipartPost(
        '${ApiConfig.baseUrl}/user/gallery',
        files: [file],
        fileParamName: 'image',
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

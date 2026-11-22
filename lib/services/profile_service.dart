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
      final userMap = response.data['user'] as Map<String, dynamic>? ?? response.data;
      await StorageService.saveUser(userMap);
      return UserModel.fromJson(userMap);
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
}

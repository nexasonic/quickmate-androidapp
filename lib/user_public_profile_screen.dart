import 'package:flutter/material.dart';
import 'chat_detail_screen.dart';
import 'core/api_config.dart';
import 'core/app_dialogs.dart';
import 'core/app_language.dart';
import 'core/app_theme.dart';
import 'core/api_service.dart';
import 'login_screen.dart';
import 'models/live_work_card_model.dart';
import 'models/user_model.dart';
import 'screens/card_reviews_screen.dart';
import 'services/auth_service.dart';
import 'services/live_work_service.dart';
import 'services/presence_service.dart';

class UserPublicProfileScreen extends StatefulWidget {
  final UserModel user;

  const UserPublicProfileScreen({
    super.key,
    required this.user,
  });

  @override
  State<UserPublicProfileScreen> createState() => _UserPublicProfileScreenState();
}

class _UserPublicProfileScreenState extends State<UserPublicProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _fullProfile;

  List<dynamic> _skills = [];
  List<dynamic> _experiences = [];
  List<dynamic> _educations = [];

  @override
  void initState() {
    super.initState();
    _fetchPublicProfile();
  }

  Future<void> _fetchPublicProfile() async {
    setState(() {
      _isLoading = true;
    });

    final url = '${ApiConfig.baseUrl}/users/${widget.user.id}/profile';
    final response = await ApiService.get(url, withAuth: false);

    if (!mounted) return;

    if (response.success && response.data != null && response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _fullProfile = data;
        _skills = data['skills'] is List ? data['skills'] : [];
        _experiences = data['experiences'] is List ? data['experiences'] : [];
        _educations = data['educations'] is List ? data['educations'] : [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getTranslatedGender(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'female':
        return context.tr('female');
      case 'other':
        return context.tr('other');
      case 'male':
        return context.tr('male');
      default:
        return raw;
    }
  }

  String _getTrProficiency(BuildContext context, String? prof) {
    if (prof == null || prof.isEmpty) return '';
    final key = 'prof_${prof.toLowerCase().trim()}';
    final trVal = context.tr(key);
    if (trVal != key && trVal.isNotEmpty) return trVal;
    return prof;
  }

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF094943);
    final profileData = _fullProfile?['profile'] as Map<String, dynamic>? ?? {};

    final userName = _fullProfile?['name']?.toString() ?? widget.user.name;
    final userEmail = _fullProfile?['email']?.toString() ?? widget.user.email ?? context.tr('not_provided');
    final userPhone = _fullProfile?['phone']?.toString() ?? widget.user.phone ?? context.tr('not_provided');
    final accountType = _fullProfile?['account_type']?.toString().toUpperCase() ?? widget.user.accountType?.toUpperCase() ?? context.tr('member');
    final isVerified = _fullProfile?['is_verified'] == true || widget.user.isVerified;
    final avatarUrl = profileData['avatar_url']?.toString() ?? widget.user.avatarUrl;
    final coverPhotoUrl = profileData['cover_photo_url']?.toString();

    final headline = profileData['headline']?.toString() ?? context.tr('service_provider');
    final tagline = profileData['tagline']?.toString() ?? context.tr('any_work');
    final location = profileData['location']?.toString() ?? widget.user.location ?? PresenceService.currentPlaceName;
    final bio = profileData['bio']?.toString() ?? context.tr('working_professional');
    final rawGender = profileData['gender']?.toString().toLowerCase() ?? 'male';
    final gender = _getTranslatedGender(rawGender).toUpperCase();
    final languagesText = (profileData['languages']?.toString().isNotEmpty == true)
        ? profileData['languages'].toString()
        : context.tr('default_languages_value');
    final dob = profileData['date_of_birth']?.toString() ?? context.tr('not_provided');
    final workingHours = profileData['working_hours']?.toString() ?? context.tr('working_hours_hint');
    final availabilityStatus = profileData['availability_status']?.toString() ?? context.tr('available_for_work');
    final rating = _fullProfile?['rating'] != null ? (_fullProfile!['rating'] as num).toDouble() : 5.0;
    final reviewsCount = _fullProfile?['reviews_count'] != null ? (_fullProfile!['reviews_count'] as num).toInt() : 1;

    final isOnline = profileData['is_online'] == true || widget.user.isOnline;
    final lastSeenHuman = translateLastSeenHuman(context, profileData['last_seen_human']?.toString());

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.appBarBg(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('user_profile'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryDark))
          : RefreshIndicator(
              onRefresh: _fetchPublicProfile,
              color: primaryDark,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header Banner Card with Cover Photo
                  _buildProfileHeaderCard(
                    primaryDark: primaryDark,
                    userName: userName,
                    headline: headline,
                    location: location,
                    tagline: tagline,
                    accountType: accountType,
                    isVerified: isVerified,
                    avatarUrl: avatarUrl,
                    coverPhotoUrl: coverPhotoUrl,
                    rating: rating,
                    reviewsCount: reviewsCount,
                    isOnline: isOnline,
                    lastSeenHuman: lastSeenHuman,
                  ),
                  const SizedBox(height: 16),

                  // Quick Stats Row
                  _buildQuickStatsRow(rating, reviewsCount, isVerified),
                  const SizedBox(height: 16),

                  // About Me Card & Equal Size Info Badges Grid
                  _buildAboutMeCard(
                    primaryDark: primaryDark,
                    bio: bio,
                    location: location,
                    languagesText: languagesText,
                    gender: gender,
                    dob: dob,
                    isVerified: isVerified,
                  ),
                  const SizedBox(height: 16),

                  // Availability Card
                  _buildAvailabilityCard(primaryDark, availabilityStatus, workingHours),
                  const SizedBox(height: 16),

                  // Work Experience Section
                  if (_experiences.isNotEmpty) ...[
                    _buildExperienceSection(primaryDark),
                    const SizedBox(height: 16),
                  ],

                  // Education Section
                  if (_educations.isNotEmpty) ...[
                    _buildEducationSection(primaryDark),
                    const SizedBox(height: 16),
                  ],

                  // Skills & Expertise Section
                  if (_skills.isNotEmpty) ...[
                    _buildSkillsSection(primaryDark),
                    const SizedBox(height: 16),
                  ],

                  // Contact Information & Verification Status
                  _buildContactCard(
                    primaryDark: primaryDark,
                    email: userEmail,
                    phone: userPhone,
                    profileData: profileData,
                  ),
                  const SizedBox(height: 16),

                  // User Gallery Section (Positioned under Contact Information)
                  _buildGallerySection(_extractGalleryImages()),
                  const SizedBox(height: 16),

                  // User Reviews & Ratings Section (Positioned at the end)
                  _buildUserReviewsSection(rating, reviewsCount),
                  const SizedBox(height: 24),

                  // Start Chat Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatDetailScreen(
                              targetUserId: widget.user.id,
                              chatData: {
                                'id': widget.user.id.toString(),
                                'name': userName,
                                'subtitle': headline,
                                'avatar': avatarUrl ?? '',
                                'isOnline': widget.user.isOnline,
                              },
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                      label: Text(
                        context.tr('chat_now'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryDark,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildProfileHeaderCard({
    required Color primaryDark,
    required String userName,
    required String headline,
    required String location,
    required String tagline,
    required String accountType,
    required bool isVerified,
    required String? avatarUrl,
    required String? coverPhotoUrl,
    required double rating,
    required int reviewsCount,
    required bool isOnline,
    required String lastSeenHuman,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          // Cover Photo Container with Overlapping Avatar
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Cover Image Banner
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: coverPhotoUrl != null && coverPhotoUrl.isNotEmpty
                    ? Image.network(
                        coverPhotoUrl,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 120,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF064E3B), Color(0xFF094943), Color(0xFF0D9488)],
                            ),
                          ),
                        ),
                      )
                    : Container(
                        height: 120,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF064E3B), Color(0xFF094943), Color(0xFF0D9488)],
                          ),
                        ),
                      ),
              ),

              // Overlapping Avatar Photo
              Positioned(
                bottom: -28,
                left: 16,
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: primaryDark,
                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null || avatarUrl.isEmpty
                            ? const Icon(Icons.person, color: Colors.white, size: 34)
                            : null,
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                      ),
                    ),
                    if (isVerified)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Verification Status & Account Type Badges Top Right of Cover
              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isVerified ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVerified ? Icons.check_circle_rounded : Icons.gpp_bad_rounded,
                            color: Colors.white,
                            size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVerified ? context.tr('verified').toUpperCase() : context.tr('not_verified').toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        accountType,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 36),

          // User Details Body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        userName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isVerified ? const Color(0xFFBBF7D0) : const Color(0xFFFCA5A5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVerified ? Icons.check_circle_rounded : Icons.gpp_bad_rounded,
                            color: isVerified ? const Color(0xFF166534) : const Color(0xFFDC2626),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVerified ? context.tr('verified').toUpperCase() : context.tr('not_verified').toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isVerified ? const Color(0xFF166534) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  headline,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary(context)),
                    const SizedBox(width: 2),
                    Text(
                      location,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB800)),
                    const SizedBox(width: 2),
                    Text(
                      '${rating.toStringAsFixed(1)} ($reviewsCount ${reviewsCount == 1 ? context.tr('review_singular') : context.tr('reviews')})',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Online / Last Seen Pill Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOnline ? const Color(0xFFBBF7D0) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF166534) : const Color(0xFF64748B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOnline ? context.tr('online_now') : lastSeenHuman,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isOnline ? const Color(0xFF166534) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                if (tagline.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.subtleBackground(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border(context)),
                    ),
                    child: Text(
                      '"$tagline"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary(context),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _extractGalleryImages() {
    final List<String> extracted = [];
    if (_fullProfile != null) {
      dynamic mediaData = _fullProfile!['user_media'] ??
          _fullProfile!['media'] ??
          _fullProfile!['medias'] ??
          _fullProfile!['user_medias'] ??
          _fullProfile!['gallery'] ??
          _fullProfile!['photos'];

      if (mediaData == null && _fullProfile!['profile'] is Map) {
        final prof = _fullProfile!['profile'] as Map<String, dynamic>;
        mediaData = prof['user_media'] ?? prof['media'] ?? prof['medias'] ?? prof['gallery'];
      }

      if (mediaData is List) {
        for (final item in mediaData) {
          if (item is String && item.isNotEmpty) {
            extracted.add(ApiConfig.fixImageUrl(item));
          } else if (item is Map) {
            final url = item['file_url'] ?? item['url'] ?? item['media_url'] ?? item['path'] ?? item['file_path'] ?? item['image_url'];
            if (url != null && url.toString().isNotEmpty) {
              extracted.add(ApiConfig.fixImageUrl(url.toString()));
            }
          }
        }
      }
    }

    if (extracted.isEmpty) {
      return const [
        'https://images.unsplash.com/photo-1581578731548-c64695cc6958?q=80&w=600',
        'https://images.unsplash.com/photo-1562259949-e8e7689d7828?q=80&w=600',
        'https://images.unsplash.com/photo-1538688525198-9b88f6f53126?q=80&w=600',
        'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?q=80&w=600',
        'https://images.unsplash.com/photo-1607613009820-a29f7bb81c04?q=80&w=600',
        'https://images.unsplash.com/photo-1584820927498-cfe5211fd8bf?q=80&w=600',
      ];
    }
    return extracted;
  }

  Widget _buildGallerySection(List<String> images) {
    const primaryDark = Color(0xFF094943);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4F1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.collections_rounded, color: primaryDark, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                '${context.tr('user_gallery')} (${images.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length > 5 ? 5 : images.length,
              itemBuilder: (context, idx) {
                final bool isLastItem = idx == 4 && images.length > 5;
                final extraCount = images.length - 4;

                return GestureDetector(
                  onTap: () => _showFullImageViewer(images, idx),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 100,
                    height: 90,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            images[idx],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFFE2E8F0),
                              child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                            ),
                          ),
                          if (isLastItem)
                            Container(
                              color: Colors.black.withValues(alpha: 0.65),
                              child: Center(
                                child: Text(
                                  context.trParams('more_count', {'count': '$extraCount'}),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImageViewer(List<String> images, int initialIndex) {
    int currentIndex = initialIndex;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog.fullscreen(
            backgroundColor: Colors.black,
            child: Stack(
              children: [
                PageView.builder(
                  controller: PageController(initialPage: initialIndex),
                  itemCount: images.length,
                  onPageChanged: (index) {
                    setDialogState(() {
                      currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Center(
                        child: Image.network(
                          images[index],
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.broken_image_rounded,
                                color: Colors.white54,
                                size: 80,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.tr('unable_load_image'),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 40,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          '${currentIndex + 1} / ${images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<CardReviewModel> _extractUserReviews() {
    final List<CardReviewModel> list = [];
    if (_fullProfile != null) {
      final reviewsData = _fullProfile!['reviews'] ?? _fullProfile!['user_reviews'];
      if (reviewsData is List) {
        for (final item in reviewsData) {
          if (item is Map<String, dynamic>) {
            list.add(CardReviewModel.fromJson(item));
          }
        }
      }
    }
    return list;
  }

  void _showAddOrEditReviewDialog(CardReviewModel? existingReview) async {
    if (!AuthService.isLoggedIn()) {
      AppDialogs.showToastModal(
        context,
        message: context.tr('sign_in_to_review'),
        icon: Icons.lock_outline_rounded,
        iconColor: Colors.orange,
        iconBgColor: const Color(0xFFFEF3C7),
      );
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      if (result == true) {
        _fetchPublicProfile();
      }
      return;
    }

    final currentUser = AuthService.getStoredUser();
    if (currentUser?.id == widget.user.id) {
      AppDialogs.showToastModal(
        context,
        message: context.tr('cannot_review_own_profile'),
        icon: Icons.error_outline_rounded,
        iconColor: Colors.redAccent,
        iconBgColor: const Color(0xFFFEE2E2),
      );
      return;
    }

    double selectedRating = existingReview?.rating ?? 5.0;
    final reviewController = TextEditingController(text: existingReview?.review ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              existingReview != null
                  ? dialogContext.trParams('edit_review_for', {'name': widget.user.name})
                  : dialogContext.trParams('rate_review_for', {'name': widget.user.name}),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(dialogContext.tr('rate_your_experience')),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starValue = index + 1;
                    return IconButton(
                      icon: Icon(
                        starValue <= selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: const Color(0xFFFFB800),
                        size: 32,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          selectedRating = starValue.toDouble();
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reviewController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: dialogContext.tr('write_provider_exp_hint'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(dialogContext.tr('cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF094943),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final text = reviewController.text.trim();
                        if (text.isEmpty) {
                          AppDialogs.showToastModal(
                            dialogContext,
                            message: dialogContext.tr('enter_review_text'),
                            icon: Icons.warning_amber_rounded,
                            iconColor: Colors.orange,
                            iconBgColor: const Color(0xFFFEF3C7),
                          );
                          return;
                        }

                        setDialogState(() {
                          isSubmitting = true;
                        });

                        final response = await LiveWorkService.addReview(
                          ownerUserId: widget.user.id,
                          cardId: existingReview?.cardId ?? 0,
                          cardTypeInt: existingReview?.cardType ?? 0,
                          rating: selectedRating,
                          review: text,
                        );

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);

                        if (response.success) {
                          if (mounted) {
                            AppDialogs.showToastModal(
                              this.context,
                              message: existingReview != null
                                  ? this.context.tr('review_updated_success')
                                  : this.context.tr('review_submitted_success'),
                            );
                          }
                          _fetchPublicProfile();
                        } else {
                          if (mounted) {
                            AppDialogs.showToastModal(
                              this.context,
                              message: response.message.isNotEmpty ? response.message : this.context.tr('failed_save_review'),
                              icon: Icons.error_outline_rounded,
                              iconColor: Colors.redAccent,
                              iconBgColor: const Color(0xFFFEE2E2),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(existingReview != null ? dialogContext.tr('update_review') : dialogContext.tr('submit_review'),
                        style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserReviewsSection(double rating, int reviewsCount) {
    const primaryDark = Color(0xFF094943);
    final reviews = _extractUserReviews();
    final currentUser = AuthService.getStoredUser();
    final totalReviewsCount = reviewsCount > reviews.length ? reviewsCount : reviews.length;

    final displayReviews = reviews.take(2).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 22),
                  const SizedBox(width: 6),
                  Text(
                    '${context.tr('user_reviews')} ($totalReviewsCount)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (reviews.isNotEmpty)
                GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CardReviewsScreen(
                          cardId: 0,
                          ownerUserId: widget.user.id,
                          cardTitle: widget.user.name,
                          averageRating: rating,
                          reviews: reviews,
                        ),
                      ),
                    );
                    _fetchPublicProfile();
                  },
                  child: Row(
                    children: [
                      Text(
                        context.tr('view_all'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryDark),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: primaryDark),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Rating Summary Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < rating.round() ? Icons.star_rounded : Icons.star_border_rounded,
                          color: const Color(0xFFFFB800),
                          size: 16,
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  context.trParams('based_on_reviews', {
                    'count': '$totalReviewsCount',
                    'label': reviewsCount == 1 ? context.tr('review_singular') : context.tr('reviews'),
                  }),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // List of User Reviews
          if (reviews.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Icon(Icons.rate_review_outlined, color: Colors.grey, size: 32),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('no_reviews_for_user'),
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr('be_first_leave_review'),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            )
          else
            Column(
              children: displayReviews.map((r) {
                final avatar = r.reviewerAvatar;
                final bool isMyReview = currentUser != null &&
                    (r.reviewerId == currentUser.id ||
                     r.reviewerName.toLowerCase() == currentUser.name.toLowerCase() ||
                     (r.reviewerAvatar != null && r.reviewerAvatar == currentUser.avatarUrl));

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: primaryDark,
                            backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar == null || avatar.isEmpty
                                ? const Icon(Icons.person, color: Colors.white, size: 16)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.reviewerName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    ...List.generate(5, (sIdx) {
                                      return Icon(
                                        sIdx < r.rating ? Icons.star_rounded : Icons.star_border_rounded,
                                        color: const Color(0xFFFFB800),
                                        size: 12,
                                      );
                                    }),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${r.rating.toStringAsFixed(1)} ★',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isMyReview)
                            GestureDetector(
                              onTap: () => _showAddOrEditReviewDialog(r),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F4F1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFC7F3E2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.edit_outlined, size: 12, color: primaryDark),
                                    const SizedBox(width: 3),
                                    Text(
                                      context.tr('edit'),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: primaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (r.createdAt != null && r.createdAt!.isNotEmpty)
                            Text(
                              r.createdAt!,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                            ),
                        ],
                      ),
                      if (r.cardTitle != null && r.cardTitle!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${context.tr('for')}: ${r.cardTitle}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                      if (r.review.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          r.review,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          if (reviews.length > 2) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CardReviewsScreen(
                        cardId: 0,
                        ownerUserId: widget.user.id,
                        cardTitle: widget.user.name,
                        averageRating: rating,
                        reviews: reviews,
                      ),
                    ),
                  );
                  _fetchPublicProfile();
                },
                icon: const Icon(Icons.rate_review_outlined, color: primaryDark, size: 16),
                label: Text(
                  context.trParams('view_all_user_reviews', {'count': '${reviews.length}'}),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryDark),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: primaryDark, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStatsRow(double rating, int reviewsCount, bool isVerified) {
    return Row(
      children: [
        _buildStatCard(context.tr('reviews'), '$reviewsCount'),
        const SizedBox(width: 8),
        _buildStatCard(context.tr('rating'), '${rating.toStringAsFixed(1)} ★'),
        const SizedBox(width: 8),
        _buildStatCard(context.tr('provider_status'), isVerified ? context.tr('verified') : context.tr('not_verified')),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    final bool isLongText = value.length > 7;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isLongText ? 11 : 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary(context),
                height: 1.15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutMeCard({
    required Color primaryDark,
    required String bio,
    required String location,
    required String languagesText,
    required String gender,
    required String dob,
    required bool isVerified,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('about_me'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
          const SizedBox(height: 6),
          Text(bio, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context), height: 1.4)),
          const SizedBox(height: 16),

          // Equal Size Grid Row 1
          Row(
            children: [
              Expanded(child: _buildInfoBadge(Icons.access_time_rounded, '1 ${context.tr('year')}', context.tr('experience'))),
              const SizedBox(width: 10),
              Expanded(child: _buildInfoBadge(Icons.translate_rounded, languagesText, context.tr('languages'))),
            ],
          ),
          const SizedBox(height: 10),

          // Equal Size Grid Row 2
          Row(
            children: [
              Expanded(child: _buildInfoBadge(Icons.location_on_outlined, location, context.tr('location'))),
              const SizedBox(width: 10),
              Expanded(child: _buildInfoBadge(Icons.person_outline, gender, context.tr('gender'))),
            ],
          ),
          const SizedBox(height: 10),

          // Equal Size Grid Row 3
          Row(
            children: [
              Expanded(child: _buildInfoBadge(Icons.cake_outlined, dob, context.tr('date_of_birth'))),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInfoBadge(
                  isVerified ? Icons.check_circle_rounded : Icons.gpp_bad_rounded,
                  isVerified ? context.tr('verified') : context.tr('not_verified'),
                  context.tr('trust_status'),
                  iconColor: isVerified
                      ? (AppTheme.isDark(context) ? const Color(0xFF4ADE80) : const Color(0xFF166534))
                      : (AppTheme.isDark(context) ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                  valueColor: isVerified
                      ? (AppTheme.isDark(context) ? const Color(0xFF4ADE80) : const Color(0xFF166534))
                      : (AppTheme.isDark(context) ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String value, String label, {Color? iconColor, Color? valueColor}) {
    final primaryDark = AppTheme.primary(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.subtleBackground(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor != null
                  ? iconColor.withValues(alpha: 0.12)
                  : (AppTheme.isDark(context) ? const Color(0xFF134E4A) : const Color(0xFFE6F4F1)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor ?? primaryDark),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: value.length > 12 ? 10 : 11,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? AppTheme.textPrimary(context),
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 9, color: AppTheme.textSecondary(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard(Color primaryDark, String status, String hours) {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('availability'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status == 'Available for Work' ? context.tr('available_for_work') : status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule_outlined, size: 16, color: AppTheme.textSecondary(context)),
              const SizedBox(width: 6),
              Text(hours, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceSection(Color primaryDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${context.tr('experience')} (${_experiences.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
          const SizedBox(height: 6),
          ..._experiences.map((exp) {
            final jobTitle = exp['job_title']?.toString() ?? context.tr('role_fallback');
            final company = exp['company']?.toString() ?? context.tr('company_fallback');
            final empType = exp['employment_type']?.toString();
            final startDate = exp['start_date']?.toString();
            final endDate = exp['end_date']?.toString();
            final bool isCurrent = exp['is_current'] == true || exp['is_current'] == 1;
            final location = exp['location']?.toString();
            final desc = exp['description']?.toString();

            String periodStr = '';
            if (startDate != null && startDate.isNotEmpty) {
              periodStr = startDate;
              if (isCurrent) {
                periodStr += ' – ${context.tr('present')}';
              } else if (endDate != null && endDate.isNotEmpty) {
                periodStr += ' – $endDate';
              }
            }

            return Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.subtleBackground(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          jobTitle,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary(context)),
                        ),
                      ),
                      if (empType != null && empType.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryDark.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            empType,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryDark),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    company,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary(context)),
                  ),
                  if (periodStr.isNotEmpty || (location != null && location.isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (periodStr.isNotEmpty) ...[
                          Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.textSecondary(context)),
                          const SizedBox(width: 4),
                          Text(periodStr, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context))),
                        ],
                        if (periodStr.isNotEmpty && location != null && location.isNotEmpty) ...[
                          const SizedBox(width: 12),
                        ],
                        if (location != null && location.isNotEmpty) ...[
                          Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textSecondary(context)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (desc != null && desc.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      desc.trim(),
                      style: TextStyle(fontSize: 12, color: AppTheme.textPrimary(context), height: 1.35),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEducationSection(Color primaryDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${context.tr('education')} (${_educations.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
          const SizedBox(height: 6),
          ..._educations.map((edu) {
            final degree = edu['degree']?.toString() ?? context.tr('degree_fallback');
            final fieldOfStudy = edu['field_of_study']?.toString();
            final institution = edu['institution']?.toString() ?? context.tr('institution_fallback');
            final startYear = edu['start_year']?.toString();
            final endYear = edu['end_year']?.toString();
            final bool isCurrent = edu['is_current'] == true || edu['is_current'] == 1;
            final desc = edu['description']?.toString();

            String titleStr = degree;
            if (fieldOfStudy != null && fieldOfStudy.isNotEmpty) {
              titleStr += ' in $fieldOfStudy';
            }

            String periodStr = '';
            if (startYear != null && startYear.isNotEmpty) {
              periodStr = startYear;
              if (isCurrent) {
                periodStr += ' – ${context.tr('present')}';
              } else if (endYear != null && endYear.isNotEmpty) {
                periodStr += ' – $endYear';
              }
            }

            return Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.subtleBackground(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleStr,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary(context)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    institution,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary(context)),
                  ),
                  if (periodStr.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.school_outlined, size: 13, color: AppTheme.textSecondary(context)),
                        const SizedBox(width: 4),
                        Text(periodStr, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context))),
                      ],
                    ),
                  ],
                  if (desc != null && desc.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      desc.trim(),
                      style: TextStyle(fontSize: 12, color: AppTheme.textPrimary(context), height: 1.35),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSkillsSection(Color primaryDark) {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${context.tr('skills_expertise')} (${_skills.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
          const SizedBox(height: 6),
          ..._skills.map((s) {
            final skillName = s['name']?.toString() ?? context.tr('skill_fallback');
            final prof = s['proficiency']?.toString();
            final expYears = s['experience_years']?.toString();
            final desc = s['description']?.toString();

            return Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.subtleBackground(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        skillName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary(context)),
                      ),
                      if (prof != null && prof.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF134E4A) : const Color(0xFFE6F4F1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF115E59) : const Color(0xFFC7F3E2)),
                          ),
                          child: Text(
                            _getTrProficiency(context, prof),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF2DD4BF) : primaryDark),
                          ),
                        ),
                      if (expYears != null && expYears.isNotEmpty && expYears != '0')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$expYears ${int.tryParse(expYears) == 1 ? context.tr('yr_exp') : context.tr('yrs_exp')}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary(context)),
                          ),
                        ),
                    ],
                  ),
                  if (desc != null && desc.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      desc.trim(),
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context), height: 1.3),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required Color primaryDark,
    required String email,
    required String phone,
    required Map<String, dynamic> profileData,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('contact_information'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
          const SizedBox(height: 12),
          _buildContactRow(Icons.email_outlined, context.tr('email_address'), email),
          const SizedBox(height: 10),
          _buildContactRow(Icons.phone_outlined, context.tr('phone_number'), phone),
          if (profileData['whatsapp'] != null && profileData['whatsapp'].toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildContactRow(Icons.chat_outlined, context.tr('whatsapp'), profileData['whatsapp'].toString()),
          ],
          if (profileData['website'] != null && profileData['website'].toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildContactRow(Icons.language_outlined, context.tr('website'), profileData['website'].toString()),
          ],
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    final primaryDark = AppTheme.primary(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.isDark(context) ? const Color(0xFF134E4A) : const Color(0xFFE6F4F1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: primaryDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary(context))),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
            ],
          ),
        ),
      ],
    );
  }
}

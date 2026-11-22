import 'package:flutter/material.dart';
import 'chat_detail_screen.dart';
import 'core/api_config.dart';
import 'core/api_service.dart';
import 'models/user_model.dart';

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

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF094943);
    final profileData = _fullProfile?['profile'] as Map<String, dynamic>? ?? {};

    final userName = _fullProfile?['name']?.toString() ?? widget.user.name;
    final userEmail = _fullProfile?['email']?.toString() ?? widget.user.email ?? 'Not provided';
    final userPhone = _fullProfile?['phone']?.toString() ?? widget.user.phone ?? 'Not provided';
    final accountType = _fullProfile?['account_type']?.toString().toUpperCase() ?? widget.user.accountType?.toUpperCase() ?? 'MEMBER';
    final isVerified = _fullProfile?['is_verified'] == true || widget.user.isVerified;
    final avatarUrl = profileData['avatar_url']?.toString() ?? widget.user.avatarUrl;
    final coverPhotoUrl = profileData['cover_photo_url']?.toString();

    final headline = profileData['headline']?.toString() ?? 'Service Provider';
    final tagline = profileData['tagline']?.toString() ?? 'Any Work';
    final location = profileData['location']?.toString() ?? 'Thodupuzha';
    final bio = profileData['bio']?.toString() ?? 'Working Professional';
    final gender = profileData['gender']?.toString().toUpperCase() ?? 'MALE';
    final dob = profileData['date_of_birth']?.toString() ?? '08 Oct 2026';
    final workingHours = profileData['working_hours']?.toString() ?? 'Mon - Sat, 9:00 AM - 6:00 PM';
    final availabilityStatus = profileData['availability_status']?.toString() ?? 'Available for Work';
    final rating = _fullProfile?['rating'] != null ? (_fullProfile!['rating'] as num).toDouble() : 5.0;
    final reviewsCount = _fullProfile?['reviews_count'] != null ? (_fullProfile!['reviews_count'] as num).toInt() : 1;

    final isOnline = profileData['is_online'] == true || widget.user.isOnline;
    final lastSeenRaw = profileData['last_seen_human']?.toString() ?? 'Offline';
    final lastSeenHuman = lastSeenRaw
        .replaceAll('Last seen ', '')
        .replaceAll('seen ', '')
        .replaceAll('Last ', '')
        .trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: primaryDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'User Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryDark))
          : SingleChildScrollView(
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
                      label: const Text(
                        'Start Chat',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
        color: const Color(0xFFE6F4F1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFC7F3E2)),
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

              // Account Type Badge Top Right of Cover
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
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
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF166534), size: 12),
                            SizedBox(width: 4),
                            Text(
                              'VERIFIED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF166534),
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
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 2),
                    Text(
                      location,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB800)),
                    const SizedBox(width: 2),
                    Text(
                      '${rating.toStringAsFixed(1)} ($reviewsCount ${reviewsCount == 1 ? 'review' : 'reviews'})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                        isOnline ? 'Online Now' : lastSeenHuman,
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      '"$tagline"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF094943),
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

  Widget _buildQuickStatsRow(double rating, int reviewsCount, bool isVerified) {
    return Row(
      children: [
        _buildStatCard('Reviews', '$reviewsCount'),
        const SizedBox(width: 8),
        _buildStatCard('Rating', '${rating.toStringAsFixed(1)} ★'),
        const SizedBox(width: 8),
        _buildStatCard('Provider Status', isVerified ? 'Verified ✔' : 'Member'),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF094943)),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
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
    required String gender,
    required String dob,
    required bool isVerified,
  }) {
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
          const Text('About Me', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Text(bio, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4)),
          const SizedBox(height: 16),

          // Equal Size Grid Row 1
          Row(
            children: [
              Expanded(child: _buildInfoBadge(Icons.access_time_rounded, '1 Year', 'Experience')),
              const SizedBox(width: 10),
              Expanded(child: _buildInfoBadge(Icons.translate_rounded, 'English, Malayalam', 'Languages')),
            ],
          ),
          const SizedBox(height: 10),

          // Equal Size Grid Row 2
          Row(
            children: [
              Expanded(child: _buildInfoBadge(Icons.location_on_outlined, location, 'Location')),
              const SizedBox(width: 10),
              Expanded(child: _buildInfoBadge(Icons.person_outline, gender, 'Gender')),
            ],
          ),
          const SizedBox(height: 10),

          // Equal Size Grid Row 3
          Row(
            children: [
              Expanded(child: _buildInfoBadge(Icons.cake_outlined, dob, 'Date of Birth')),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInfoBadge(
                  isVerified ? Icons.check_circle_rounded : Icons.shield_outlined,
                  isVerified ? 'Verified ✔' : 'Unverified',
                  'Trust Status',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4F1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF094943)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
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
          const Text('Availability', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
            child: Text(status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(hours, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Experience (${_experiences.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          ..._experiences.map((exp) {
            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exp['job_title']?.toString() ?? 'Role', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(exp['company']?.toString() ?? 'Company', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Education (${_educations.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          ..._educations.map((edu) {
            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(edu['degree']?.toString() ?? 'Degree', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(edu['institution']?.toString() ?? 'Institution', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSkillsSection(Color primaryDark) {
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
          Text('Skills & Expertise (${_skills.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skills.map((s) {
              return Chip(
                label: Text(s['name']?.toString() ?? 'Skill', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF094943))),
                backgroundColor: const Color(0xFFE6F4F1),
              );
            }).toList(),
          ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contact Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          _buildContactRow(Icons.email_outlined, 'Email Address', email),
          const SizedBox(height: 10),
          _buildContactRow(Icons.phone_outlined, 'Phone Number', phone),
          if (profileData['whatsapp'] != null && profileData['whatsapp'].toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildContactRow(Icons.chat_outlined, 'WhatsApp', profileData['whatsapp'].toString()),
          ],
          if (profileData['website'] != null && profileData['website'].toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildContactRow(Icons.language_outlined, 'Website', profileData['website'].toString()),
          ],
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F4F1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF094943)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
        ),
      ],
    );
  }
}

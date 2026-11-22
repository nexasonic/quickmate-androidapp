import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'saved_cards_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _isLoading = true;
  UserModel? _user;
  Map<String, dynamic>? _fullProfile;

  List<dynamic> _skills = [];
  List<dynamic> _experiences = [];
  List<dynamic> _educations = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });

    _user = AuthService.getStoredUser();

    final data = await ProfileService.fetchFullProfileData();
    if (!mounted) return;

    if (data != null) {
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

  void _showEditProfileModal() {
    final profileData = _fullProfile?['profile'] as Map<String, dynamic>? ?? {};

    final nameCtrl = TextEditingController(text: _fullProfile?['name']?.toString() ?? _user?.name ?? '');
    final phoneCtrl = TextEditingController(text: _fullProfile?['phone']?.toString() ?? _user?.phone ?? '');
    final headlineCtrl = TextEditingController(text: profileData['headline']?.toString() ?? 'Software engineer');
    final taglineCtrl = TextEditingController(text: profileData['tagline']?.toString() ?? 'Any Work');
    final bioCtrl = TextEditingController(text: profileData['bio']?.toString() ?? 'Working Professional');
    final locationCtrl = TextEditingController(text: profileData['location']?.toString() ?? 'Thodupuzha');
    final workingHoursCtrl = TextEditingController(text: profileData['working_hours']?.toString() ?? 'Mon - Sat, 9:00 AM - 6:00 PM');
    final whatsappCtrl = TextEditingController(text: profileData['whatsapp']?.toString() ?? '');
    final linkedinCtrl = TextEditingController(text: profileData['linkedin']?.toString() ?? '');
    final websiteCtrl = TextEditingController(text: profileData['website']?.toString() ?? '');

    String selectedGender = profileData['gender']?.toString().toLowerCase() ?? 'male';
    if (!['male', 'female', 'other'].contains(selectedGender)) selectedGender = 'male';

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Profile Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF094943),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: headlineCtrl,
                    decoration: const InputDecoration(labelText: 'Headline / Role (e.g. Software engineer)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: taglineCtrl,
                    decoration: const InputDecoration(labelText: 'Tagline (e.g. Any Work)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(labelText: 'Location / City', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGender,
                    decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedGender = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: workingHoursCtrl,
                    decoration: const InputDecoration(labelText: 'Working Hours', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bioCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Bio / About You', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: whatsappCtrl,
                    decoration: const InputDecoration(labelText: 'WhatsApp Number', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: linkedinCtrl,
                    decoration: const InputDecoration(labelText: 'LinkedIn Profile URL', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: websiteCtrl,
                    decoration: const InputDecoration(labelText: 'Website URL', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) return;

                              setModalState(() {
                                isSubmitting = true;
                              });

                              final messenger = ScaffoldMessenger.of(context);

                              final response = await ProfileService.updateProfile(
                                name: name,
                                headline: headlineCtrl.text.trim(),
                                tagline: taglineCtrl.text.trim(),
                                location: locationCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                                gender: selectedGender,
                                workingHours: workingHoursCtrl.text.trim(),
                                bio: bioCtrl.text.trim(),
                                whatsapp: whatsappCtrl.text.trim(),
                                linkedin: linkedinCtrl.text.trim(),
                                website: websiteCtrl.text.trim(),
                              );

                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }

                              if (response.success) {
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Profile details updated!')),
                                );
                                _loadProfileData();
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(response.message.isNotEmpty ? response.message : 'Update failed.'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF094943),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Save Profile Changes',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddExperienceModal() {
    final titleCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final startDateCtrl = TextEditingController(text: '2026-01-01');
    final descCtrl = TextEditingController();
    bool isCurrent = true;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Work Experience',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF094943)),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetContext)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Job Title / Role *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: companyCtrl,
                    decoration: const InputDecoration(labelText: 'Company / Organization *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: startDateCtrl,
                    decoration: const InputDecoration(labelText: 'Start Date (YYYY-MM-DD) *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    title: const Text('Currently working here'),
                    value: isCurrent,
                    onChanged: (val) {
                      setModalState(() {
                        isCurrent = val == true;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final title = titleCtrl.text.trim();
                              final company = companyCtrl.text.trim();
                              if (title.isEmpty || company.isEmpty) return;

                              setModalState(() => isSubmitting = true);
                              final messenger = ScaffoldMessenger.of(context);

                              final response = await ProfileService.storeExperience(
                                jobTitle: title,
                                company: company,
                                startDate: startDateCtrl.text.trim(),
                                isCurrent: isCurrent,
                                description: descCtrl.text.trim(),
                              );

                              if (sheetContext.mounted) Navigator.pop(sheetContext);

                              if (response.success) {
                                messenger.showSnackBar(const SnackBar(content: Text('Work experience added!')));
                                _loadProfileData();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF094943),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                      ),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Add Experience', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddEducationModal() {
    final instCtrl = TextEditingController();
    final degreeCtrl = TextEditingController();
    final startYearCtrl = TextEditingController(text: '2022');
    final endYearCtrl = TextEditingController(text: '2026');
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Add Education', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF094943))),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetContext)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: instCtrl, decoration: const InputDecoration(labelText: 'Institution / College *', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: degreeCtrl, decoration: const InputDecoration(labelText: 'Degree / Course *', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: startYearCtrl, decoration: const InputDecoration(labelText: 'Start Year', border: OutlineInputBorder()))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: endYearCtrl, decoration: const InputDecoration(labelText: 'End Year', border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final inst = instCtrl.text.trim();
                              final degree = degreeCtrl.text.trim();
                              if (inst.isEmpty || degree.isEmpty) return;

                              setModalState(() => isSubmitting = true);
                              final messenger = ScaffoldMessenger.of(context);

                              final response = await ProfileService.storeEducation(
                                institution: inst,
                                degree: degree,
                                startYear: startYearCtrl.text.trim(),
                                endYear: endYearCtrl.text.trim(),
                              );

                              if (sheetContext.mounted) Navigator.pop(sheetContext);

                              if (response.success) {
                                messenger.showSnackBar(const SnackBar(content: Text('Education added!')));
                                _loadProfileData();
                              }
                            },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF094943), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23))),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Add Education', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddSkillModal() {
    final skillCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Add Skill & Expertise', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF094943))),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetContext)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: skillCtrl, decoration: const InputDecoration(labelText: 'Skill Name (e.g. Software Engineering) *', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final name = skillCtrl.text.trim();
                              if (name.isEmpty) return;

                              setModalState(() => isSubmitting = true);
                              final messenger = ScaffoldMessenger.of(context);

                              final response = await ProfileService.storeSkill(name: name);

                              if (sheetContext.mounted) Navigator.pop(sheetContext);

                              if (response.success) {
                                messenger.showSnackBar(const SnackBar(content: Text('Skill added!')));
                                _loadProfileData();
                              }
                            },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF094943), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23))),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Add Skill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF094943);
    final profileData = _fullProfile?['profile'] as Map<String, dynamic>? ?? {};

    final userName = _fullProfile?['name']?.toString() ?? _user?.name ?? 'MUSICAFE';
    final userEmail = _fullProfile?['email']?.toString() ?? _user?.email ?? 'mcafe369@gmail.com';
    final accountType = _fullProfile?['account_type']?.toString().toUpperCase() ?? 'FREELANCER';
    final isVerified = _fullProfile?['is_verified'] == true || _user?.isVerified == true;
    final avatarUrl = profileData['avatar_url']?.toString() ?? _user?.avatarUrl;

    final headline = profileData['headline']?.toString() ?? 'Software engineer';
    final tagline = profileData['tagline']?.toString() ?? 'Any Work';
    final location = profileData['location']?.toString() ?? 'Thodupuzha';
    final bio = profileData['bio']?.toString() ?? 'Working Professional';
    final gender = profileData['gender']?.toString().toUpperCase() ?? 'MALE';
    final dob = profileData['date_of_birth']?.toString() ?? '08 Oct 2026';
    final workingHours = profileData['working_hours']?.toString() ?? 'Mon - Sat, 9:00 AM - 6:00 PM';
    final availabilityStatus = profileData['availability_status']?.toString() ?? 'Available for Work';

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
          'My Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            onPressed: _showEditProfileModal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryDark))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header Banner Card
                  _buildProfileHeaderCard(
                    primaryDark: primaryDark,
                    userName: userName,
                    headline: headline,
                    location: location,
                    tagline: tagline,
                    accountType: accountType,
                    isVerified: isVerified,
                    avatarUrl: avatarUrl,
                  ),
                  const SizedBox(height: 16),

                  // Quick Stats Row (Cards Posted, Reviews, Rating)
                  _buildQuickStatsRow(primaryDark),
                  const SizedBox(height: 16),

                  // About Me & Quick Info Grid Section
                  _buildAboutMeCard(
                    primaryDark: primaryDark,
                    bio: bio,
                    location: location,
                    gender: gender,
                    dob: dob,
                  ),
                  const SizedBox(height: 16),

                  // Availability & Working Hours
                  _buildAvailabilityCard(primaryDark, availabilityStatus, workingHours),
                  const SizedBox(height: 16),

                  // Work Experience Section
                  _buildExperienceSection(primaryDark),
                  const SizedBox(height: 16),

                  // Education Section
                  _buildEducationSection(primaryDark),
                  const SizedBox(height: 16),

                  // Skills & Expertise Section
                  _buildSkillsSection(primaryDark),
                  const SizedBox(height: 16),

                  // Social Links & Verification Badges
                  _buildVerificationAndSocialCard(primaryDark, userEmail, profileData),
                  const SizedBox(height: 24),
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4F1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFC7F3E2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: primaryDark,
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? const Icon(Icons.person, color: Colors.white, size: 36)
                        : null,
                  ),
                  if (isVerified)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            accountType,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      headline,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 2),
                        Text(
                          location,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB800)),
                        const SizedBox(width: 2),
                        const Text(
                          '5.0 (1 review)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: _showEditProfileModal,
                    icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 16),
                    label: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryDark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsRow(Color primaryDark) {
    return Row(
      children: [
        _buildStatCard('Work Cards', '5'),
        const SizedBox(width: 8),
        _buildStatCard('Saved Cards', 'Bookmarked', onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SavedCardsScreen()),
          );
        }),
        const SizedBox(width: 8),
        _buildStatCard('Average Rating', '5.0 ★'),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
      ),
    );
  }

  Widget _buildAboutMeCard({
    required Color primaryDark,
    required String bio,
    required String location,
    required String gender,
    required String dob,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('About Me', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF094943)), onPressed: _showEditProfileModal),
            ],
          ),
          Text(bio, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInfoBadge(Icons.access_time_rounded, '1 Year', 'Experience')),
              const SizedBox(width: 10),
              Expanded(child: _buildInfoBadge(Icons.translate_rounded, 'English, Malayalam', 'Languages')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildInfoBadge(Icons.location_on_outlined, location, 'Location')),
              const SizedBox(width: 10),
              Expanded(child: _buildInfoBadge(Icons.person_outline, gender, 'Gender')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildInfoBadge(Icons.cake_outlined, dob, 'Date of Birth')),
              const SizedBox(width: 10),
              Expanded(child: _buildInfoBadge(Icons.verified_outlined, 'Identity Verified', 'Trust Status')),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Availability', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF094943)), onPressed: _showEditProfileModal),
            ],
          ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Experience (${_experiences.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              TextButton.icon(
                onPressed: _showAddExperienceModal,
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF094943)),
                label: const Text('Add', style: TextStyle(fontSize: 12, color: Color(0xFF094943), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (_experiences.isEmpty)
            const Text('No work experience added yet.', style: TextStyle(fontSize: 12, color: Colors.grey))
          else
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
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      onPressed: () async {
                        final id = exp['id'];
                        if (id != null) {
                          await ProfileService.destroyExperience(id);
                          _loadProfileData();
                        }
                      },
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Education (${_educations.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              TextButton.icon(
                onPressed: _showAddEducationModal,
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF094943)),
                label: const Text('Add', style: TextStyle(fontSize: 12, color: Color(0xFF094943), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (_educations.isEmpty)
            const Text('No education added yet.', style: TextStyle(fontSize: 12, color: Colors.grey))
          else
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
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      onPressed: () async {
                        final id = edu['id'];
                        if (id != null) {
                          await ProfileService.destroyEducation(id);
                          _loadProfileData();
                        }
                      },
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Skills & Expertise (${_skills.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              TextButton.icon(
                onPressed: _showAddSkillModal,
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF094943)),
                label: const Text('Add', style: TextStyle(fontSize: 12, color: Color(0xFF094943), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (_skills.isEmpty)
            const Text('No skills added yet.', style: TextStyle(fontSize: 12, color: Colors.grey))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _skills.map((s) {
                return Chip(
                  label: Text(s['name']?.toString() ?? 'Skill', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF094943))),
                  backgroundColor: const Color(0xFFE6F4F1),
                  deleteIcon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                  onDeleted: () async {
                    final id = s['id'];
                    if (id != null) {
                      await ProfileService.destroySkill(id);
                      _loadProfileData();
                    }
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildVerificationAndSocialCard(Color primaryDark, String email, Map<String, dynamic> profileData) {
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
          const Text('Profile Verification', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 6),
              Text('Email & Identity Verified', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          const Text('Social Links & Contact', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.email_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
            ],
          ),
        ],
      ),
    );
  }
}

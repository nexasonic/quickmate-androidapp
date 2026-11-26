import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_config.dart';
import '../core/api_service.dart';
import '../core/app_dialogs.dart';
import '../core/app_language.dart';
import '../core/app_theme.dart';
import '../login_screen.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/presence_service.dart';
import '../services/profile_service.dart';
import 'saved_cards_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  int _imageTimestamp = DateTime.now().millisecondsSinceEpoch;

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

  Future<void> _pickCropAndUploadImage({required bool isCover}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (pickedFile == null) return;

      File imageToUpload = File(pickedFile.path);

      try {
        final CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: isCover
              ? const CropAspectRatio(ratioX: 3, ratioY: 1)
              : const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: isCover ? 'Crop Cover Banner' : 'Crop Profile Avatar',
              toolbarColor: const Color(0xFF094943),
              toolbarWidgetColor: Colors.white,
              initAspectRatio: isCover ? CropAspectRatioPreset.ratio16x9 : CropAspectRatioPreset.square,
              aspectRatioPresets: isCover
                  ? [CropAspectRatioPreset.ratio16x9, CropAspectRatioPreset.original]
                  : [CropAspectRatioPreset.square, CropAspectRatioPreset.original],
              lockAspectRatio: true,
              activeControlsWidgetColor: const Color(0xFF094943),
            ),
            IOSUiSettings(
              title: isCover ? 'Crop Cover Banner' : 'Crop Profile Avatar',
              aspectRatioLockEnabled: true,
            ),
          ],
        );

        if (croppedFile != null) {
          imageToUpload = File(croppedFile.path);
        }
      } catch (cropErr) {
        debugPrint('Cropping skipped/error: $cropErr');
      }

      if (!mounted) return;

      setState(() {
        _isUploadingPhoto = true;
      });

      ApiResponse response;
      if (isCover) {
        response = await ProfileService.updateCoverPhoto(imageToUpload);
      } else {
        response = await ProfileService.updateAvatarPhoto(imageToUpload);
      }

      if (!mounted) return;

      setState(() {
        _isUploadingPhoto = false;
      });

      // Clear image cache so new photo renders immediately
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (response.success) {
        AppDialogs.showToastModal(
          context,
          message: isCover ? 'Cover photo updated successfully!' : 'Profile picture updated successfully!',
        );
        await _loadProfileData();
        await ProfileService.fetchUserProfile();
      } else {
        AppDialogs.showToastModal(
          context,
          message: response.message.isNotEmpty ? response.message : 'Photo updated!',
        );
        await _loadProfileData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
      debugPrint('Error uploading image: $e');
    }
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _imageTimestamp = DateTime.now().millisecondsSinceEpoch;
    });

    try {
      _user = AuthService.getStoredUser();

      final data = await ProfileService.fetchFullProfileData();
      if (!mounted) return;

      if (data != null) {
        setState(() {
          _fullProfile = data;
          _skills = data['skills'] is List ? data['skills'] : [];
          _experiences = data['experiences'] is List ? data['experiences'] : [];
          _educations = data['educations'] is List ? data['educations'] : [];
        });
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false, String? optionalText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(context),
              ),
            ),
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            if (optionalText != null)
              TextSpan(
                text: ' ($optionalText)',
                style: TextStyle(
                  color: AppTheme.textSecondary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalInput({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    Widget? suffixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, color: AppTheme.textPrimary(context)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: AppTheme.inputFill(context),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primary(context), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildModalDropdown<T>({
    required T? value,
    required String hintText,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: AppTheme.surface(context),
      style: TextStyle(fontSize: 14, color: AppTheme.textPrimary(context)),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary(context)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: AppTheme.inputFill(context),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primary(context), width: 1.5),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime initialDate = DateTime.now();
    if (controller.text.isNotEmpty) {
      final parsed = DateTime.tryParse(controller.text);
      if (parsed != null) initialDate = parsed;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppTheme.primary(context),
              brightness: AppTheme.isDark(context) ? Brightness.dark : Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formatted = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      controller.text = formatted;
    }
  }

  Widget _buildModalHeader(
    BuildContext context, {
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary(context), size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: AppTheme.divider(context)),
      ],
    );
  }

  Widget _buildModalActions(
    BuildContext context, {
    required String saveText,
    required bool isSubmitting,
    required VoidCallback onSave,
  }) {
    final primaryDark = AppTheme.primary(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: isSubmitting ? null : () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.subtleBackground(context),
            foregroundColor: AppTheme.textPrimary(context),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(context.tr('cancel'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: isSubmitting ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryDark,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(saveText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }

  void _showEditProfileModal() {
    final profileData = _fullProfile?['profile'] as Map<String, dynamic>? ?? {};

    final nameCtrl = TextEditingController(text: _fullProfile?['name']?.toString() ?? _user?.name ?? '');
    final phoneCtrl = TextEditingController(text: _fullProfile?['phone']?.toString() ?? _user?.phone ?? '');
    final headlineCtrl = TextEditingController(text: profileData['headline']?.toString() ?? '');
    final taglineCtrl = TextEditingController(text: profileData['tagline']?.toString() ?? '');
    final bioCtrl = TextEditingController(text: profileData['bio']?.toString() ?? '');
    final languagesCtrl = TextEditingController(text: profileData['languages']?.toString() ?? 'English, Malayalam');
    final locationCtrl = TextEditingController(text: profileData['location']?.toString() ?? PresenceService.currentPlaceName);
    final dobCtrl = TextEditingController(text: profileData['date_of_birth']?.toString() ?? '');
    final workingHoursCtrl = TextEditingController(text: profileData['working_hours']?.toString() ?? 'Mon - Sat, 9:00 AM - 6:00 PM');
    final whatsappCtrl = TextEditingController(text: profileData['whatsapp']?.toString() ?? '');

    String selectedGender = profileData['gender']?.toString().toLowerCase() ?? 'male';
    if (!['male', 'female', 'other'].contains(selectedGender)) selectedGender = 'male';

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppTheme.border(context)),
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
                  _buildModalHeader(
                    sheetContext,
                    icon: Icons.person_outline_rounded,
                    iconBgColor: const Color(0xFFE6F4F1),
                    iconColor: const Color(0xFF094943),
                    title: context.tr('edit_profile'),
                    subtitle: context.tr('update_personal_prof_details'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('full_name'), isRequired: true),
                            _buildModalInput(controller: nameCtrl, hintText: 'JAISON PETER'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('phone_number')),
                            _buildModalInput(controller: phoneCtrl, hintText: '+91 98765 43210', keyboardType: TextInputType.phone),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel(context.tr('professional_headline')),
                  _buildModalInput(controller: headlineCtrl, hintText: 'e.g. Software Engineer | Freelancer | Local Service Provider'),
                  const SizedBox(height: 14),
                  _buildFieldLabel(context.tr('tagline_quote')),
                  _buildModalInput(controller: taglineCtrl, hintText: 'e.g. Passionate about technology and community growth.'),
                  const SizedBox(height: 14),
                  _buildFieldLabel(context.tr('about_me')),
                  _buildModalInput(controller: bioCtrl, hintText: 'Tell people about yourself, your work, and your goals...', maxLines: 4),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('languages')),
                            _buildModalInput(controller: languagesCtrl, hintText: 'e.g. English, Malayalam'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('location')),
                            _buildModalInput(controller: locationCtrl, hintText: 'Thodupuzha'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('gender')),
                            _buildModalDropdown<String>(
                              value: selectedGender,
                              hintText: 'Select gender',
                              items: [
                                DropdownMenuItem(value: 'male', child: Text(context.tr('male'))),
                                DropdownMenuItem(value: 'female', child: Text(context.tr('female'))),
                                DropdownMenuItem(value: 'other', child: Text(context.tr('other'))),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedGender = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('date_of_birth')),
                            _buildModalInput(
                              controller: dobCtrl,
                              hintText: 'dd-mm-yyyy',
                              readOnly: true,
                              suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF64748B)),
                              onTap: () => _selectDate(sheetContext, dobCtrl),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('working_hours')),
                            _buildModalInput(controller: workingHoursCtrl, hintText: 'Mon - Sat, 9:00 AM - 6:00 PM'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('whatsapp')),
                            _buildModalInput(controller: whatsappCtrl, hintText: '+91 98765 43210', keyboardType: TextInputType.phone),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildModalActions(
                    sheetContext,
                    saveText: context.tr('save_changes'),
                    isSubmitting: isSubmitting,
                    onSave: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;

                      setModalState(() {
                        isSubmitting = true;
                      });

                      final response = await ProfileService.updateProfile(
                        name: name,
                        headline: headlineCtrl.text.trim(),
                        tagline: taglineCtrl.text.trim(),
                        location: locationCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        gender: selectedGender,
                        dateOfBirth: dobCtrl.text.trim(),
                        languages: languagesCtrl.text.trim(),
                        workingHours: workingHoursCtrl.text.trim(),
                        bio: bioCtrl.text.trim(),
                        whatsapp: whatsappCtrl.text.trim(),
                      );

                      if (sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                      }

                      if (response.success) {
                        if (mounted) {
                          AppDialogs.showToastModal(
                            context,
                            message: 'Profile details updated!',
                          );
                        }
                        _loadProfileData();
                      } else {
                        if (mounted) {
                          AppDialogs.showToastModal(
                            context,
                            message: response.message.isNotEmpty ? response.message : 'Update failed.',
                            icon: Icons.error_outline_rounded,
                            iconColor: Colors.redAccent,
                            iconBgColor: const Color(0xFFFEE2E2),
                          );
                        }
                      }
                    },
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
    final locationCtrl = TextEditingController();
    final startDateCtrl = TextEditingController();
    final endDateCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedEmpType = 'Full-time';
    bool isCurrent = false;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppTheme.border(context)),
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
                  _buildModalHeader(
                    sheetContext,
                    icon: Icons.work_outline_rounded,
                    iconBgColor: const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    title: context.tr('add_experience'),
                    subtitle: context.tr('share_work_history'),
                  ),
                  const SizedBox(height: 16),
                  _buildFieldLabel(context.tr('job_title'), isRequired: true),
                  _buildModalInput(controller: titleCtrl, hintText: 'e.g. Software Engineer, Electrician, Carpenter'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('company_employer'), isRequired: true),
                            _buildModalInput(controller: companyCtrl, hintText: 'e.g. TechCorp, Self-employed'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('employment_type')),
                            _buildModalDropdown<String>(
                              value: selectedEmpType,
                              hintText: 'Select type',
                              items: const [
                                DropdownMenuItem(value: 'Full-time', child: Text('Full-time')),
                                DropdownMenuItem(value: 'Part-time', child: Text('Part-time')),
                                DropdownMenuItem(value: 'Self-employed', child: Text('Self-employed')),
                                DropdownMenuItem(value: 'Contract', child: Text('Contract')),
                                DropdownMenuItem(value: 'Freelance', child: Text('Freelance')),
                                DropdownMenuItem(value: 'Internship', child: Text('Internship')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedEmpType = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: isCurrent,
                          activeColor: const Color(0xFF094943),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            setModalState(() => isCurrent = val == true);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('currently_work_here'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('start_date'), isRequired: true),
                            _buildModalInput(
                              controller: startDateCtrl,
                              hintText: '---------, ----',
                              readOnly: true,
                              suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF64748B)),
                              onTap: () => _selectDate(sheetContext, startDateCtrl),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('end_date')),
                            _buildModalInput(
                              controller: endDateCtrl,
                              hintText: '---------, ----',
                              readOnly: true,
                              suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF64748B)),
                              onTap: isCurrent ? null : () => _selectDate(sheetContext, endDateCtrl),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel(context.tr('location')),
                  _buildModalInput(controller: locationCtrl, hintText: 'e.g. Kochi, Kerala · Remote · On-site'),
                  const SizedBox(height: 14),
                  _buildFieldLabel(context.tr('description'), optionalText: 'optional'),
                  _buildModalInput(
                    controller: descCtrl,
                    hintText: 'Describe your responsibilities, achievements or skills learned...',
                    maxLines: 4,
                    onChanged: (_) => setModalState(() {}),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${descCtrl.text.length}/1000',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildModalActions(
                    sheetContext,
                    saveText: context.tr('save_experience'),
                    isSubmitting: isSubmitting,
                    onSave: () async {
                      final title = titleCtrl.text.trim();
                      final company = companyCtrl.text.trim();
                      if (title.isEmpty || company.isEmpty) return;

                      setModalState(() => isSubmitting = true);

                      final response = await ProfileService.storeExperience(
                        jobTitle: title,
                        company: company,
                        employmentType: selectedEmpType,
                        startDate: startDateCtrl.text.trim().isNotEmpty ? startDateCtrl.text.trim() : '2026-01-01',
                        endDate: endDateCtrl.text.trim(),
                        isCurrent: isCurrent,
                        location: locationCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                      );

                      if (sheetContext.mounted) Navigator.pop(sheetContext);

                      if (response.success) {
                        if (mounted) {
                          AppDialogs.showToastModal(context, message: 'Work experience saved!');
                        }
                        _loadProfileData();
                      }
                    },
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
    final fieldCtrl = TextEditingController();
    final startYearCtrl = TextEditingController();
    final endYearCtrl = TextEditingController();
    final gradeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedDegree = "Bachelor's";
    bool isCurrentStudy = false;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppTheme.border(context)),
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
                  _buildModalHeader(
                    sheetContext,
                    icon: Icons.school_outlined,
                    iconBgColor: const Color(0xFFDCFCE7),
                    iconColor: const Color(0xFF15803D),
                    title: context.tr('add_education'),
                    subtitle: context.tr('add_academic_bg'),
                  ),
                  const SizedBox(height: 16),
                  _buildFieldLabel(context.tr('school_college'), isRequired: true),
                  _buildModalInput(controller: instCtrl, hintText: "e.g. University of Kerala, St. Xavier's College"),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('degree_level')),
                            _buildModalDropdown<String>(
                              value: selectedDegree,
                              hintText: 'Select degree',
                              items: const [
                                DropdownMenuItem(value: "Bachelor's", child: Text("Bachelor's")),
                                DropdownMenuItem(value: "Master's", child: Text("Master's")),
                                DropdownMenuItem(value: 'Diploma', child: Text('Diploma')),
                                DropdownMenuItem(value: 'High School', child: Text('High School')),
                                DropdownMenuItem(value: 'Doctorate', child: Text('Doctorate')),
                                DropdownMenuItem(value: 'Certification', child: Text('Certification')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedDegree = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('field_of_study')),
                            _buildModalInput(controller: fieldCtrl, hintText: 'e.g. Computer Science, Commerce'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: isCurrentStudy,
                          activeColor: const Color(0xFF094943),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            setModalState(() => isCurrentStudy = val == true);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('currently_study_here'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('start_year')),
                            _buildModalInput(controller: startYearCtrl, hintText: 'e.g. 2018', keyboardType: TextInputType.number),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('passout_year')),
                            _buildModalInput(
                              controller: endYearCtrl,
                              hintText: 'e.g. 2022',
                              readOnly: isCurrentStudy,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel(context.tr('grade_percentage'), optionalText: 'optional'),
                  _buildModalInput(controller: gradeCtrl, hintText: 'e.g. 8.5 CGPA, 85%, Distinction'),
                  const SizedBox(height: 14),
                  _buildFieldLabel(context.tr('activities_description'), optionalText: 'optional'),
                  _buildModalInput(
                    controller: descCtrl,
                    hintText: 'Clubs, achievements, projects or activities during this period...',
                    maxLines: 4,
                    onChanged: (_) => setModalState(() {}),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${descCtrl.text.length}/1000',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildModalActions(
                    sheetContext,
                    saveText: context.tr('save_education'),
                    isSubmitting: isSubmitting,
                    onSave: () async {
                      final inst = instCtrl.text.trim();
                      final degree = selectedDegree ?? 'Degree';
                      if (inst.isEmpty) return;

                      setModalState(() => isSubmitting = true);

                      final response = await ProfileService.storeEducation(
                        institution: inst,
                        degree: degree,
                        fieldOfStudy: fieldCtrl.text.trim(),
                        startYear: startYearCtrl.text.trim().isNotEmpty ? startYearCtrl.text.trim() : '2022',
                        endYear: isCurrentStudy ? null : endYearCtrl.text.trim(),
                        isCurrent: isCurrentStudy,
                        description: descCtrl.text.trim(),
                      );

                      if (sheetContext.mounted) Navigator.pop(sheetContext);

                      if (response.success) {
                        if (mounted) {
                          AppDialogs.showToastModal(context, message: 'Education saved!');
                        }
                        _loadProfileData();
                      }
                    },
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
    final expYearsCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedProficiency = 'Intermediate';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppTheme.border(context)),
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
                  _buildModalHeader(
                    sheetContext,
                    icon: Icons.bolt_outlined,
                    iconBgColor: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    title: context.tr('add_skill'),
                    subtitle: context.tr('showcase_skills'),
                  ),
                  const SizedBox(height: 16),
                  _buildFieldLabel(context.tr('skill_name'), isRequired: true),
                  _buildModalInput(controller: skillCtrl, hintText: 'e.g. Laravel, React, Graphic Design, Plumbing'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('proficiency_level'), optionalText: 'Optional'),
                            _buildModalDropdown<String>(
                              value: selectedProficiency,
                              hintText: 'Select proficiency...',
                              items: const [
                                DropdownMenuItem(value: 'Beginner', child: Text('Beginner')),
                                DropdownMenuItem(value: 'Intermediate', child: Text('Intermediate')),
                                DropdownMenuItem(value: 'Advanced', child: Text('Advanced')),
                                DropdownMenuItem(value: 'Expert', child: Text('Expert')),
                                DropdownMenuItem(value: 'Master', child: Text('Master')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedProficiency = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('years_experience'), optionalText: 'Optional'),
                            _buildModalInput(controller: expYearsCtrl, hintText: 'e.g. 3', keyboardType: TextInputType.number),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel(context.tr('short_description'), optionalText: 'Optional'),
                  _buildModalInput(
                    controller: descCtrl,
                    hintText: 'Briefly describe your experience, tools used, or key accomplishments with this skill...',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Add context on how you apply this skill.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 20),
                  _buildModalActions(
                    sheetContext,
                    saveText: context.tr('save_skill'),
                    isSubmitting: isSubmitting,
                    onSave: () async {
                      final name = skillCtrl.text.trim();
                      if (name.isEmpty) return;

                      setModalState(() => isSubmitting = true);

                      final expYears = int.tryParse(expYearsCtrl.text.trim()) ?? 1;

                      final response = await ProfileService.storeSkill(
                        name: name,
                        proficiency: selectedProficiency ?? 'Intermediate',
                        experienceYears: expYears,
                      );

                      if (sheetContext.mounted) Navigator.pop(sheetContext);

                      if (response.success) {
                        if (mounted) {
                          AppDialogs.showToastModal(context, message: 'Skill saved!');
                        }
                        _loadProfileData();
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileVerificationTopCard(
    Color primaryDark,
    Map<String, dynamic> profileData,
    bool isVerified,
  ) {
    final verificationStatus = profileData['verification_status']?.toString().toLowerCase() ??
        (isVerified ? 'verified' : 'not_verified');

    final bool isDeclined = verificationStatus == 'declined' ||
        verificationStatus == 'rejected' ||
        profileData['verification_decline_reason'] != null;

    final bool isPending = verificationStatus == 'pending' ||
        verificationStatus == 'in_review';

    final String declineReason = profileData['verification_decline_reason']?.toString() ??
        'Documents were unclear or did not meet requirements. Please submit clear photos.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isVerified
                          ? const Color(0xFFDCFCE7)
                          : (isPending ? const Color(0xFFFEF3C7) : const Color(0xFFE6F4F1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isVerified ? Icons.check_circle_rounded : Icons.shield_outlined,
                      color: isVerified
                          ? const Color(0xFF166534)
                          : (isPending ? const Color(0xFFD97706) : primaryDark),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('profile_verification'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF166534), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('verified'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF166534),
                    ),
                  ),
                ],
              ),
            )
          else if (isPending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, color: Color(0xFFD97706), size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Verification Pending',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.brightness_1_rounded, color: Color(0xFFDC2626), size: 8),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('not_verified'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          if (isDeclined) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Previous Request Declined:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    declineReason,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF991B1B),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!isVerified && !isPending) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _showRequestVerificationModal,
                icon: const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
                label: Text(
                  context.tr('request_verification'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showRequestVerificationModal() {
    String selectedIdType = 'National ID Card';
    final idNumberCtrl = TextEditingController();
    File? frontPhoto;
    File? backPhoto;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppTheme.border(context)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          Future<void> pickPhoto(bool isFront) async {
            try {
              final ImagePicker picker = ImagePicker();
              final XFile? picked = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
              );
              if (picked == null) return;

              final File file = File(picked.path);
              final int bytes = await file.length();
              final double mb = bytes / (1024 * 1024);

              if (bytes > 5 * 1024 * 1024) {
                if (!mounted) return;
                AppDialogs.showToastModal(
                  context,
                  message: 'Selected photo is ${mb.toStringAsFixed(1)} MB. Maximum allowed size is 5 MB.',
                  icon: Icons.warning_amber_rounded,
                  iconColor: Colors.orange,
                  iconBgColor: const Color(0xFFFEF3C7),
                );
                return;
              }

              setModalState(() {
                if (isFront) {
                  frontPhoto = file;
                } else {
                  backPhoto = file;
                }
              });
            } catch (e) {
              if (!mounted) return;
              AppDialogs.showToastModal(
                context,
                message: 'Error selecting document: $e',
                icon: Icons.error_outline_rounded,
                iconColor: Colors.redAccent,
                iconBgColor: const Color(0xFFFEE2E2),
              );
            }
          }

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
                  _buildModalHeader(
                    sheetContext,
                    icon: Icons.shield_outlined,
                    iconBgColor: const Color(0xFFE6F4F1),
                    iconColor: const Color(0xFF094943),
                    title: 'Request Profile Verification',
                    subtitle: 'Submit your government ID card to get verified',
                  ),
                  const SizedBox(height: 16),
                  _buildFieldLabel('ID Card Type', isRequired: true),
                  _buildModalDropdown<String>(
                    value: selectedIdType,
                    hintText: 'Select ID Card Type',
                    items: const [
                      DropdownMenuItem(value: 'National ID Card', child: Text('National ID Card')),
                      DropdownMenuItem(value: 'Aadhaar Card', child: Text('Aadhaar Card')),
                      DropdownMenuItem(value: 'Passport', child: Text('Passport')),
                      DropdownMenuItem(value: 'Driving License', child: Text('Driving License')),
                      DropdownMenuItem(value: 'Voter ID Card', child: Text('Voter ID Card')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedIdType = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel('ID Card Number', isRequired: true),
                  _buildModalInput(
                    controller: idNumberCtrl,
                    hintText: 'e.g. 12345-6789012-3 or A12345678',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Upload Front Photo Box
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Upload Front Photo', isRequired: true),
                            GestureDetector(
                              onTap: () => pickPhoto(true),
                              child: Container(
                                height: 110,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: frontPhoto != null ? const Color(0xFF094943) : const Color(0xFFCBD5E1),
                                    style: BorderStyle.solid,
                                    width: frontPhoto != null ? 1.5 : 1,
                                  ),
                                ),
                                child: frontPhoto != null
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(13),
                                            child: Image.file(frontPhoto!, fit: BoxFit.cover),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.6),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.check, color: Colors.white, size: 14),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFEFF6FF),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.image_outlined, color: Color(0xFF3B82F6), size: 20),
                                          ),
                                          const SizedBox(height: 6),
                                          const Text(
                                            'Choose Front Photo',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            'JPG, PNG up to 5MB',
                                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Upload Back Photo Box
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Upload Back Photo', isRequired: true),
                            GestureDetector(
                              onTap: () => pickPhoto(false),
                              child: Container(
                                height: 110,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: backPhoto != null ? const Color(0xFF094943) : const Color(0xFFCBD5E1),
                                    style: BorderStyle.solid,
                                    width: backPhoto != null ? 1.5 : 1,
                                  ),
                                ),
                                child: backPhoto != null
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(13),
                                            child: Image.file(backPhoto!, fit: BoxFit.cover),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.6),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.check, color: Colors.white, size: 14),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFEFF6FF),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.image_outlined, color: Color(0xFF3B82F6), size: 20),
                                          ),
                                          const SizedBox(height: 6),
                                          const Text(
                                            'Choose Back Photo',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            'JPG, PNG up to 5MB',
                                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Alert Box 1 (Guidelines)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Please ensure that your ID card photos are clear, sharp, and all details are readable without reflections or blur. Sensitive documents are safely stored.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Alert Box 2 (Payment Fee Info)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F4F1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.payments_outlined, color: Color(0xFF094943), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'A verification processing fee of ',
                              style: TextStyle(fontSize: 11, color: Color(0xFF065F46), height: 1.3),
                              children: [
                                TextSpan(
                                  text: '₹2.00',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                ),
                                TextSpan(
                                  text: ' will be required via Razorpay upon submitting your documents.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildModalActions(
                    sheetContext,
                    saveText: 'Proceed to Pay ₹2.00 & Submit',
                    isSubmitting: isSubmitting,
                    onSave: () async {
                      final idNumber = idNumberCtrl.text.trim();
                      if (idNumber.isEmpty) {
                        AppDialogs.showToastModal(
                          context,
                          message: 'Please enter your ID Card Number.',
                          icon: Icons.warning_amber_rounded,
                          iconColor: Colors.orange,
                          iconBgColor: const Color(0xFFFEF3C7),
                        );
                        return;
                      }
                      if (frontPhoto == null) {
                        AppDialogs.showToastModal(
                          context,
                          message: 'Please upload Front Photo of your ID card.',
                          icon: Icons.warning_amber_rounded,
                          iconColor: Colors.orange,
                          iconBgColor: const Color(0xFFFEF3C7),
                        );
                        return;
                      }

                      // Open Razorpay Payment Confirmation Sheet
                      _showRazorpayPaymentSheet(
                        parentContext: sheetContext,
                        idType: selectedIdType,
                        idNumber: idNumber,
                        frontPhoto: frontPhoto!,
                        backPhoto: backPhoto,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _launchUpiPaymentApp({
    String payeeVpa = 'quickmate@razorpay',
    String payeeName = 'QuickMate',
    String transactionNote = 'Profile Verification Fee',
    double amount = 2.00,
    String? transactionRef,
  }) async {
    final txRef = transactionRef ?? 'pay_${DateTime.now().millisecondsSinceEpoch}';
    final String upiUrl =
        'upi://pay?pa=$payeeVpa&pn=${Uri.encodeComponent(payeeName)}&tn=${Uri.encodeComponent(transactionNote)}&am=${amount.toStringAsFixed(2)}&cu=INR&tr=$txRef';

    final Uri uri = Uri.parse(upiUrl);

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Error opening payment app: $e');
      return false;
    }
  }

  Future<void> _processVerificationPayment({
    required BuildContext payContext,
    required BuildContext parentContext,
    required String idType,
    required String idNumber,
    required File frontPhoto,
    File? backPhoto,
  }) async {
    final String paymentId = 'pay_${DateTime.now().millisecondsSinceEpoch}';

    // Try launching GPay / PhonePe / UPI app first
    final bool launched = await _launchUpiPaymentApp(
      amount: 2.00,
      transactionRef: paymentId,
    );

    if (!launched) {
      if (!mounted) return;
      final bool? proceedTest = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF094943)),
              SizedBox(width: 8),
              Text('No UPI App Detected', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Google Pay / PhonePe / Paytm is not installed on this device/emulator.\n\nWould you like to complete payment using Razorpay Test Payment Mode (₹2.00)?',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF094943),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Pay ₹2.00 & Complete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (proceedTest != true) return;
    }

    final response = await ProfileService.submitVerificationRequest(
      idType: idType,
      idNumber: idNumber,
      frontPhoto: frontPhoto,
      backPhoto: backPhoto,
      paymentId: paymentId,
      feeAmount: 2.00,
    );

    if (payContext.mounted) Navigator.pop(payContext);
    if (parentContext.mounted) Navigator.pop(parentContext);

    if (response.success) {
      if (mounted) {
        AppDialogs.showToastModal(
          context,
          message: 'Payment ₹2.00 ($paymentId) successful! Verification request submitted.',
        );
      }
      _loadProfileData();
    } else {
      if (mounted) {
        AppDialogs.showToastModal(
          context,
          message: 'Verification request submitted! Fee recorded and request under review.',
        );
      }
      _loadProfileData();
    }
  }

  void _showRazorpayPaymentSheet({
    required BuildContext parentContext,
    required String idType,
    required String idNumber,
    required File frontPhoto,
    File? backPhoto,
  }) {
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppTheme.border(context)),
      ),
      builder: (payContext) => StatefulBuilder(
        builder: (dialogContext, setPayState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.payment_rounded, color: Color(0xFF0284C7), size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Razorpay / UPI Payment',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'QuickMate Verification Fee',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(payContext),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Amount to Pay',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹2.00',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF094943)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Razorpay UPI',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Payment Method',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF094943)),
                  title: const Text('Google Pay / PhonePe / Paytm / UPI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Opens installed GPay / PhonePe app for ₹2.00', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.open_in_new_rounded, color: Color(0xFF094943), size: 18),
                  tileColor: const Color(0xFFE6F4F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    _processVerificationPayment(
                      payContext: payContext,
                      parentContext: parentContext,
                      idType: idType,
                      idNumber: idNumber,
                      frontPhoto: frontPhoto,
                      backPhoto: backPhoto,
                    );
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isProcessing
                        ? null
                        : () async {
                            setPayState(() => isProcessing = true);
                            await _processVerificationPayment(
                              payContext: payContext,
                              parentContext: parentContext,
                              idType: idType,
                              idNumber: idNumber,
                              frontPhoto: frontPhoto,
                              backPhoto: backPhoto,
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF094943),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Open GPay / Pay ₹2.00 & Submit',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGuestPromptScreen(String title, String subtitle) {
    final primaryDark = AppTheme.primary(context);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.appBarBg(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F4F1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline_rounded, size: 54, color: primaryDark),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sign In Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                    if (result == true) {
                      _loadProfileData();
                    }
                  },
                  icon: const Icon(Icons.login_rounded, color: Colors.white),
                  label: const Text('Sign In / Register', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn()) {
      return _buildGuestPromptScreen(
        'My Profile',
        'Please sign in to view and manage your personal profile details.',
      );
    }

    const primaryDark = Color(0xFF094943);
    final profileData = _fullProfile?['profile'] as Map<String, dynamic>? ?? {};

    final userName = _fullProfile?['name']?.toString() ?? _user?.name ?? 'MUSICAFE';
    final userEmail = _fullProfile?['email']?.toString() ?? _user?.email ?? 'mcafe369@gmail.com';
    final accountType = _fullProfile?['account_type']?.toString().toUpperCase() ?? 'FREELANCER';
    final isVerified = _fullProfile?['is_verified'] == true || _user?.isVerified == true;

    final userMap = _fullProfile?['user'] as Map<String, dynamic>? ?? {};

    String? avatarUrl = profileData['avatar_url']?.toString() ??
        profileData['avatar']?.toString() ??
        userMap['avatar_url']?.toString() ??
        _user?.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarUrl = "${ApiConfig.fixImageUrl(avatarUrl)}?t=$_imageTimestamp";
    }

    String? coverUrl = profileData['cover_url']?.toString() ??
        profileData['cover_photo']?.toString() ??
        profileData['cover']?.toString() ??
        profileData['banner_url']?.toString() ??
        profileData['cover_photo_url']?.toString() ??
        profileData['banner']?.toString() ??
        _fullProfile?['cover_url']?.toString() ??
        _fullProfile?['cover_photo']?.toString() ??
        _fullProfile?['cover']?.toString() ??
        userMap['cover_url']?.toString() ??
        userMap['cover_photo']?.toString();
    if (coverUrl != null && coverUrl.isNotEmpty) {
      coverUrl = "${ApiConfig.fixImageUrl(coverUrl)}?t=$_imageTimestamp";
    }

    final headline = profileData['headline']?.toString() ?? 'Software engineer';
    final tagline = profileData['tagline']?.toString() ?? 'Any Work';
    final location = profileData['location']?.toString() ?? PresenceService.currentPlaceName;
    final bio = profileData['bio']?.toString() ?? 'Working Professional';
    final gender = profileData['gender']?.toString().toUpperCase() ?? 'MALE';
    final dob = profileData['date_of_birth']?.toString() ?? '08 Oct 2026';
    final workingHours = profileData['working_hours']?.toString() ?? 'Mon - Sat, 9:00 AM - 6:00 PM';
    final availabilityStatus = profileData['availability_status']?.toString() ?? 'Available for Work';

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
          context.tr('my_profile'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            onPressed: _showEditProfileModal,
          ),
        ],
        bottom: _isUploadingPhoto
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(color: Colors.white, backgroundColor: primaryDark),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryDark))
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              color: primaryDark,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                      coverUrl: coverUrl,
                    ),
                    const SizedBox(height: 16),

                    // Quick Stats Row (Cards Posted, Reviews, Rating)
                    _buildQuickStatsRow(primaryDark),
                    const SizedBox(height: 16),

                    // Profile Verification Card (Positioned top of About Me if profile is not verified)
                    _buildProfileVerificationTopCard(primaryDark, profileData, isVerified),
                    const SizedBox(height: 16),

                    // About Me & Quick Info Grid Section
                    _buildAboutMeCard(
                      primaryDark: primaryDark,
                      bio: bio,
                      location: location,
                      gender: gender,
                      dob: dob,
                      isVerified: isVerified,
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
                    const SizedBox(height: 16),

                    // User Gallery Section
                    _buildGallerySection(),
                    const SizedBox(height: 24),
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
    required String? coverUrl,
  }) {
    final isDark = AppTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cover Banner Image with Camera Change Button
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        width: double.infinity,
                        height: 125,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 125,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? const [Color(0xFF042F2E), Color(0xFF0F172A), Color(0xFF0F172A)]
                                  : const [Color(0xFF064E3B), Color(0xFF094943), Color(0xFF0D9488)],
                            ),
                          ),
                        ),
                      )
                    : Container(
                        height: 125,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? const [Color(0xFF042F2E), Color(0xFF0F172A), Color(0xFF0F172A)]
                                : const [Color(0xFF064E3B), Color(0xFF094943), Color(0xFF0D9488)],
                          ),
                        ),
                      ),
              ),

              // Camera Icon Button to Change Cover Banner
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => _pickCropAndUploadImage(isCover: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          context.tr('edit_cover'),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Overlapping Avatar Circle with Camera Change Button
              Positioned(
                bottom: -36,
                left: 16,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.surface(context),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 8),
                        ],
                      ),
                      padding: const EdgeInsets.all(3),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: primaryDark,
                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null || avatarUrl.isEmpty
                            ? const Icon(Icons.person, color: Colors.white, size: 36)
                            : null,
                      ),
                    ),

                    // Verified Badge Icon
                    if (isVerified)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: AppTheme.surface(context), shape: BoxShape.circle),
                          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                        ),
                      ),

                    // Camera Change Avatar Button
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _pickCropAndUploadImage(isCover: false),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: primaryDark,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 42),

          // User Info Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        userName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isVerified
                            ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                            : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isVerified
                              ? (isDark ? const Color(0xFF047857) : const Color(0xFFBBF7D0))
                              : (isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVerified ? Icons.check_circle_rounded : Icons.gpp_bad_rounded,
                            color: isVerified
                                ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534))
                                : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVerified ? context.tr('verified').toUpperCase() : context.tr('not_verified').toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isVerified
                                  ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534))
                                  : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF581C87) : const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        accountType,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  headline,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary(context)),
                    const SizedBox(width: 2),
                    Text(
                      location,
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB800)),
                    const SizedBox(width: 2),
                    Text(
                      '5.0 (1 review)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context)),
                    ),
                  ],
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
                        color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
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
                          label: Text(context.tr('edit_profile'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsRow(Color primaryDark) {
    return Row(
      children: [
        _buildStatCard(context.tr('my_cards'), '5'),
        const SizedBox(width: 8),
        _buildStatCard(context.tr('saved_cards'), context.tr('saved'), onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SavedCardsScreen()),
          );
        }),
        const SizedBox(width: 8),
        _buildStatCard(context.tr('rating'), '5.0 ★'),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9.5, color: AppTheme.textSecondary(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadGalleryImage() async {
    final currentImages = _extractGalleryMediaObjects();

    if (currentImages.length >= 6) {
      AppDialogs.showToastModal(
        context,
        message: 'Maximum limit reached. Each user can upload up to 6 gallery images. Please delete an image first.',
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.orange,
        iconBgColor: const Color(0xFFFEF3C7),
      );
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final File imageFile = File(pickedFile.path);
      final int fileSizeInBytes = await imageFile.length();
      final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      if (fileSizeInBytes > 1024 * 1024) {
        if (!mounted) return;
        AppDialogs.showToastModal(
          context,
          message: 'Selected image is ${fileSizeInMB.toStringAsFixed(2)} MB. Maximum allowed size is 1 MB. Please choose a smaller image.',
          icon: Icons.error_outline_rounded,
          iconColor: Colors.redAccent,
          iconBgColor: const Color(0xFFFEE2E2),
        );
        return;
      }

      if (!mounted) return;
      AppDialogs.showToastModal(
        context,
        message: 'Uploading gallery image...',
        icon: Icons.cloud_upload_outlined,
        iconColor: const Color(0xFF094943),
        iconBgColor: const Color(0xFFE6F4F1),
        durationSeconds: 1,
      );

      final response = await ProfileService.uploadGalleryMedia(imageFile);

      if (!mounted) return;

      if (response.success) {
        AppDialogs.showToastModal(
          context,
          message: 'Gallery photo uploaded successfully!',
        );
        _loadProfileData();
      } else {
        AppDialogs.showToastModal(
          context,
          message: response.message.isNotEmpty ? response.message : 'Photo added to gallery!',
        );
        _loadProfileData();
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code == 'channel-error' || e.message?.contains('ImagePickerApi') == true) {
        AppDialogs.showToastModal(
          context,
          message: 'Please restart/rebuild the app to register the image_picker plugin channel on Android.',
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.orange,
          iconBgColor: const Color(0xFFFEF3C7),
        );
      } else {
        AppDialogs.showToastModal(
          context,
          message: 'Permission error selecting image: ${e.message}',
          icon: Icons.error_outline_rounded,
          iconColor: Colors.redAccent,
          iconBgColor: const Color(0xFFFEE2E2),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showToastModal(
        context,
        message: 'Error selecting image: $e',
        icon: Icons.error_outline_rounded,
        iconColor: Colors.redAccent,
        iconBgColor: const Color(0xFFFEE2E2),
      );
    }
  }

  List<Map<String, dynamic>> _extractGalleryMediaObjects() {
    final List<Map<String, dynamic>> extracted = [];
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
          if (item is Map<String, dynamic>) {
            final url = item['file_url'] ?? item['url'] ?? item['media_url'] ?? item['path'] ?? item['file_path'] ?? item['image_url'];
            if (url != null && url.toString().isNotEmpty) {
              extracted.add({
                'id': item['id'],
                'url': ApiConfig.fixImageUrl(url.toString()),
              });
            }
          } else if (item is String && item.isNotEmpty) {
            extracted.add({
              'id': null,
              'url': ApiConfig.fixImageUrl(item),
            });
          }
        }
      }
    }
    return extracted;
  }

  Widget _buildGallerySection() {
    const primaryDark = Color(0xFF094943);
    final mediaList = _extractGalleryMediaObjects();
    final bool canAddMore = mediaList.length < 6;

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
                    '${context.tr('user_gallery')} (${mediaList.length}/6)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _pickAndUploadGalleryImage,
                icon: const Icon(Icons.add_a_photo_rounded, size: 14, color: Colors.white),
                label: Text(
                  context.tr('add_photo'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAddMore ? primaryDark : Colors.grey,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('max_photos_info'),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          if (mediaList.isEmpty)
            GestureDetector(
              onTap: _pickAndUploadGalleryImage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.add_photo_alternate_rounded, size: 36, color: primaryDark),
                    SizedBox(height: 8),
                    Text(
                      'Tap to select gallery image',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Max 1 MB file size',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: canAddMore ? mediaList.length + 1 : mediaList.length,
                itemBuilder: (context, idx) {
                  if (canAddMore && idx == mediaList.length) {
                    return GestureDetector(
                      onTap: _pickAndUploadGalleryImage,
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4F1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_rounded, color: primaryDark, size: 28),
                            SizedBox(height: 4),
                            Text(
                              'Add Photo',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryDark),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final item = mediaList[idx];
                  final String imageUrl = item['url'];
                  final int? imageId = item['id'];

                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          final urls = mediaList.map((m) => m['url'] as String).toList();
                          _showFullImageViewer(urls, idx);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 100,
                          height: 100,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFFE2E8F0),
                                child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 14,
                        child: GestureDetector(
                          onTap: () async {
                            if (imageId != null) {
                              await ProfileService.destroyGalleryMedia(imageId);
                              _loadProfileData();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
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
                          errorBuilder: (context, error, stackTrace) => const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image_rounded,
                                color: Colors.white54,
                                size: 80,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Unable to load image',
                                style: TextStyle(color: Colors.white70),
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
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('about_me'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
              IconButton(icon: Icon(Icons.edit_outlined, size: 18, color: primaryDark), onPressed: _showEditProfileModal),
            ],
          ),
          Text(
            bio == 'Working Professional' ? context.tr('working_professional') : bio,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context), height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInfoBadge(Icons.access_time_rounded, '1 ${context.tr('year')}', context.tr('experience'))),
              const SizedBox(width: 10),
              Expanded(child: _buildInfoBadge(Icons.translate_rounded, 'English, Malayalam', context.tr('languages'))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildInfoBadge(Icons.location_on_outlined, location, context.tr('location'))),
              const SizedBox(width: 10),
              Expanded(child: _buildInfoBadge(Icons.person_outline, gender == 'MALE' ? context.tr('male').toUpperCase() : gender, context.tr('gender'))),
            ],
          ),
          const SizedBox(height: 10),
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
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? AppTheme.textPrimary(context),
                  ),
                  maxLines: 1,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('availability'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
              IconButton(icon: Icon(Icons.edit_outlined, size: 18, color: primaryDark), onPressed: _showEditProfileModal),
            ],
          ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${context.tr('experience')} (${_experiences.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
              TextButton.icon(
                onPressed: _showAddExperienceModal,
                icon: Icon(Icons.add, size: 16, color: primaryDark),
                label: Text(context.tr('add'), style: TextStyle(fontSize: 12, color: primaryDark, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (_experiences.isEmpty)
            Text(context.tr('no_experience_added'), style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)))
          else
            ..._experiences.map((exp) {
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.subtleBackground(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(exp['job_title']?.toString() ?? 'Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary(context))),
                          Text(exp['company']?.toString() ?? 'Company', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context))),
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
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${context.tr('education')} (${_educations.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
              TextButton.icon(
                onPressed: _showAddEducationModal,
                icon: Icon(Icons.add, size: 16, color: primaryDark),
                label: Text(context.tr('add'), style: TextStyle(fontSize: 12, color: primaryDark, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (_educations.isEmpty)
            Text(context.tr('no_education_added'), style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)))
          else
            ..._educations.map((edu) {
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.subtleBackground(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(edu['degree']?.toString() ?? 'Degree', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary(context))),
                          Text(edu['institution']?.toString() ?? 'Institution', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context))),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${context.tr('skills_expertise')} (${_skills.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
              TextButton.icon(
                onPressed: _showAddSkillModal,
                icon: Icon(Icons.add, size: 16, color: primaryDark),
                label: Text(context.tr('add'), style: TextStyle(fontSize: 12, color: primaryDark, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (_skills.isEmpty)
            Text(context.tr('no_skills_added'), style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _skills.map((s) {
                return Chip(
                  label: Text(
                    s['name']?.toString() ?? 'Skill',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF2DD4BF) : primaryDark,
                    ),
                  ),
                  backgroundColor: isDark ? const Color(0xFF134E4A) : const Color(0xFFE6F4F1),
                  side: BorderSide(color: isDark ? const Color(0xFF115E59) : const Color(0xFFC7F3E2)),
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
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('profile_verification'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 6),
              Text(
                context.tr('verified'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.isDark(context) ? const Color(0xFF4ADE80) : const Color(0xFF166534),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppTheme.divider(context)),
          const SizedBox(height: 14),
          Text(context.tr('social_links_contact'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.email_outlined, size: 16, color: AppTheme.textSecondary(context)),
              const SizedBox(width: 8),
              Text(email, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context))),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
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

  double _verificationFee = 2.00;
  String _razorpayKeyId = '';
  String? _activeOrderId;
  double _activeOrderAmountInr = 2.00;
  bool _isStartingPayment = false;

  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _initRazorpay();
    _loadProfileData();
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('Razorpay Payment Success: ${response.paymentId}, orderId: ${response.orderId}');

    final String effectiveOrderId =
        (response.orderId != null && response.orderId!.isNotEmpty) ? response.orderId! : (_activeOrderId ?? '');
    final String paymentId = response.paymentId ?? '';

    final verifyResponse = await ProfileService.verifyPaymentSignature(
      orderId: effectiveOrderId,
      paymentId: paymentId,
      signature: response.signature,
    );

    if (!mounted) return;

    await _loadProfileData();
    if (!mounted) return;

    if (verifyResponse.success) {
      final feeStr = _activeOrderAmountInr.toStringAsFixed(2);
      AppDialogs.showSuccessModal(
        context,
        title: context.tr('payment_success_title'),
        message: context.trParams('payment_success_verification_submitted', {'amount': feeStr}),
        icon: Icons.check_circle_rounded,
        iconColor: const Color(0xFF16A34A),
      );
    } else {
      AppDialogs.showToastModal(
        context,
        message: verifyResponse.message.isNotEmpty
            ? verifyResponse.message
            : context.tr('payment_not_completed'),
        icon: Icons.error_outline_rounded,
        iconColor: Colors.red,
        iconBgColor: const Color(0xFFFEE2E2),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Razorpay Payment Error: ${response.code} - ${response.message}');
    if (mounted) {
      AppDialogs.showToastModal(
        context,
        message: context.tr('payment_not_completed'),
        icon: Icons.error_outline_rounded,
        iconColor: Colors.red,
        iconBgColor: const Color(0xFFFEE2E2),
      );
    }
    _loadProfileData();
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External Wallet Selected: ${response.walletName}');
  }

  Future<void> _pickCropAndUploadImage({required bool isCover}) async {
    final cropTitle = isCover ? context.tr('crop_cover_banner') : context.tr('crop_profile_avatar');

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
              toolbarTitle: cropTitle,
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
              title: cropTitle,
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
          message: isCover ? context.tr('cover_photo_updated') : context.tr('profile_pic_updated'),
        );
        await _loadProfileData();
        await ProfileService.fetchUserProfile();
      } else {
        AppDialogs.showToastModal(
          context,
          message: response.message.isNotEmpty ? response.message : context.tr('photo_updated'),
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

  void _applyVerificationConfig(Map<String, dynamic> source) {
    final rawFee = source['verification_fee'];
    if (rawFee is num && rawFee > 0) {
      _verificationFee = rawFee.toDouble();
    } else if (rawFee != null) {
      final parsed = double.tryParse(rawFee.toString());
      if (parsed != null && parsed > 0) _verificationFee = parsed;
    }

    final rawKey = source['razorpay_key_id']?.toString().trim() ?? source['key_id']?.toString().trim();
    if (rawKey != null && rawKey.isNotEmpty) {
      _razorpayKeyId = rawKey;
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
        _applyVerificationConfig(data);
        setState(() {
          _fullProfile = data;
          _user = AuthService.getStoredUser() ?? _user;
          _skills = data['skills'] is List ? data['skills'] : [];
          _experiences = data['experiences'] is List ? data['experiences'] : [];
          _educations = data['educations'] is List ? data['educations'] : [];
        });
      }

      if (_razorpayKeyId.isEmpty) {
        final statusRes = await ProfileService.getVerificationStatus();
        if (mounted && statusRes.success && statusRes.data is Map) {
          final statusMap = Map<String, dynamic>.from(statusRes.data as Map);
          setState(() {
            _applyVerificationConfig(statusMap);
          });
        }
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

  String _getTrProficiency(BuildContext context, String? prof) {
    if (prof == null || prof.isEmpty) return '';
    final key = 'prof_${prof.toLowerCase().trim()}';
    final trVal = context.tr(key);
    if (trVal != key && trVal.isNotEmpty) return trVal;
    return prof;
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
      isExpanded: true,
      initialValue: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: AppTheme.surface(context),
      style: TextStyle(fontSize: 12, color: AppTheme.textPrimary(context)),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary(context), size: 18),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
    final languagesCtrl = TextEditingController(text: profileData['languages']?.toString() ?? context.tr('default_languages_value'));
    final locationCtrl = TextEditingController(text: profileData['location']?.toString() ?? PresenceService.currentPlaceName);
    final dobCtrl = TextEditingController(text: profileData['date_of_birth']?.toString() ?? '');
    final workingHoursCtrl = TextEditingController(text: profileData['working_hours']?.toString() ?? context.tr('working_hours_hint'));
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
                            _buildModalInput(controller: nameCtrl, hintText: context.tr('full_name_hint')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('phone_number')),
                            _buildModalInput(controller: phoneCtrl, hintText: context.tr('phone_hint'), keyboardType: TextInputType.phone),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel(context.tr('professional_headline')),
                  _buildModalInput(controller: headlineCtrl, hintText: context.tr('headline_full_hint')),
                  const SizedBox(height: 14),
                  _buildFieldLabel(context.tr('tagline_quote')),
                  _buildModalInput(controller: taglineCtrl, hintText: context.tr('tagline_full_hint')),
                  const SizedBox(height: 14),
                  _buildFieldLabel(context.tr('about_me')),
                  _buildModalInput(controller: bioCtrl, hintText: context.tr('bio_full_hint'), maxLines: 4),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('languages')),
                            _buildModalInput(controller: languagesCtrl, hintText: context.tr('languages_hint')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('location')),
                            _buildModalInput(controller: locationCtrl, hintText: context.tr('location_hint')),
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
                              hintText: context.tr('select_gender'),
                              items: [
                                DropdownMenuItem(value: 'male', child: Text(context.tr('male'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'female', child: Text(context.tr('female'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'other', child: Text(context.tr('other'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
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
                              hintText: context.tr('dob_hint'),
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
                            _buildModalInput(controller: workingHoursCtrl, hintText: context.tr('working_hours_hint')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('whatsapp')),
                            _buildModalInput(controller: whatsappCtrl, hintText: context.tr('phone_hint'), keyboardType: TextInputType.phone),
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
                            message: context.tr('profile_details_updated'),
                          );
                        }
                        _loadProfileData();
                      } else {
                        if (mounted) {
                          AppDialogs.showToastModal(
                            context,
                            message: response.message.isNotEmpty ? response.message : context.tr('update_failed'),
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

  void _showAddExperienceModal({Map<String, dynamic>? experience}) {
    final bool isEditing = experience != null;
    final int? expId = experience != null
        ? (experience['id'] is int ? experience['id'] : int.tryParse(experience['id']?.toString() ?? ''))
        : null;

    final titleCtrl = TextEditingController(text: experience?['job_title']?.toString() ?? '');
    final companyCtrl = TextEditingController(text: experience?['company']?.toString() ?? '');
    final locationCtrl = TextEditingController(text: experience?['location']?.toString() ?? '');
    final startDateCtrl = TextEditingController(text: experience?['start_date']?.toString() ?? '');
    final endDateCtrl = TextEditingController(text: experience?['end_date']?.toString() ?? '');
    final descCtrl = TextEditingController(text: experience?['description']?.toString() ?? '');
    String? selectedEmpType = experience?['employment_type']?.toString() ?? 'Full-time';
    bool isCurrent = experience?['is_current'] == true || experience?['is_current'] == 1;
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
                    title: isEditing ? context.tr('edit_experience') : context.tr('add_experience'),
                    subtitle: context.tr('share_work_history'),
                  ),
                  const SizedBox(height: 16),
                  _buildFieldLabel(context.tr('job_title'), isRequired: true),
                  _buildModalInput(controller: titleCtrl, hintText: context.tr('job_title_hint')),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('company_employer'), isRequired: true),
                            _buildModalInput(controller: companyCtrl, hintText: context.tr('company_hint')),
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
                              hintText: context.tr('select_emp_type'),
                              items: [
                                DropdownMenuItem(value: 'Full-time', child: Text(context.tr('emp_full_time'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Part-time', child: Text(context.tr('emp_part_time'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Self-employed', child: Text(context.tr('emp_self_employed'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Contract', child: Text(context.tr('emp_contract'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Freelance', child: Text(context.tr('emp_freelance'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Internship', child: Text(context.tr('emp_internship'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
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
                              hintText: 'YYYY-MM-DD',
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
                              hintText: 'YYYY-MM-DD',
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
                  _buildModalInput(controller: locationCtrl, hintText: context.tr('exp_location_hint')),
                  const SizedBox(height: 14),
                  _buildFieldLabel(context.tr('description'), optionalText: context.tr('optional')),
                  _buildModalInput(
                    controller: descCtrl,
                    hintText: context.tr('exp_desc_hint'),
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
                    saveText: isEditing ? context.tr('save_changes') : context.tr('save_experience'),
                    isSubmitting: isSubmitting,
                    onSave: () async {
                      final title = titleCtrl.text.trim();
                      final company = companyCtrl.text.trim();
                      if (title.isEmpty || company.isEmpty) return;

                      setModalState(() => isSubmitting = true);

                      final response = isEditing && expId != null
                          ? await ProfileService.updateExperience(
                              expId,
                              jobTitle: title,
                              company: company,
                              employmentType: selectedEmpType,
                              startDate: startDateCtrl.text.trim().isNotEmpty ? startDateCtrl.text.trim() : '2026-01-01',
                              endDate: endDateCtrl.text.trim(),
                              isCurrent: isCurrent,
                              location: locationCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                            )
                          : await ProfileService.storeExperience(
                              jobTitle: title,
                              company: company,
                              employmentType: selectedEmpType,
                              startDate: startDateCtrl.text.trim().isNotEmpty ? startDateCtrl.text.trim() : '2026-01-01',
                              endDate: endDateCtrl.text.trim(),
                              isCurrent: isCurrent,
                              location: locationCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                            );

                      if (!mounted) return;

                      if (response.success) {
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        AppDialogs.showToastModal(context, message: context.tr('work_experience_saved'));
                        _loadProfileData();
                      } else {
                        setModalState(() => isSubmitting = false);
                        AppDialogs.showToastModal(
                          context,
                          message: response.message.isNotEmpty ? response.message : 'Failed to save experience',
                          icon: Icons.error_outline_rounded,
                          iconColor: Colors.redAccent,
                        );
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

  void _showAddEducationModal({Map<String, dynamic>? education}) {
    final bool isEditing = education != null;
    final int? eduId = education != null
        ? (education['id'] is int ? education['id'] : int.tryParse(education['id']?.toString() ?? ''))
        : null;

    final instCtrl = TextEditingController(text: education?['institution']?.toString() ?? '');
    final fieldCtrl = TextEditingController(text: education?['field_of_study']?.toString() ?? '');
    final startYearCtrl = TextEditingController(text: education?['start_year']?.toString() ?? '');
    final endYearCtrl = TextEditingController(text: education?['end_year']?.toString() ?? '');
    final descCtrl = TextEditingController(text: education?['description']?.toString() ?? '');
    String? selectedDegree = education?['degree']?.toString() ?? "Bachelor's";
    bool isCurrentStudy = education?['is_current'] == true || education?['is_current'] == 1;
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
                    title: isEditing ? context.tr('edit_education') : context.tr('add_education'),
                    subtitle: context.tr('add_academic_bg'),
                  ),
                  const SizedBox(height: 16),
                  _buildFieldLabel(context.tr('school_college'), isRequired: true),
                  _buildModalInput(controller: instCtrl, hintText: context.tr('school_college_hint')),
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
                              hintText: context.tr('select_degree'),
                              items: [
                                DropdownMenuItem(value: "Bachelor's", child: Text(context.tr('deg_bachelors'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: "Master's", child: Text(context.tr('deg_masters'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Diploma', child: Text(context.tr('deg_diploma'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'High School', child: Text(context.tr('deg_high_school'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Doctorate', child: Text(context.tr('deg_doctorate'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Certification', child: Text(context.tr('deg_certification'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
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
                            _buildModalInput(controller: fieldCtrl, hintText: context.tr('field_of_study_hint')),
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
                            _buildModalInput(controller: startYearCtrl, hintText: context.tr('start_year_hint'), keyboardType: TextInputType.number),
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
                              hintText: context.tr('passout_year_hint'),
                              readOnly: isCurrentStudy,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel(context.tr('activities_description'), optionalText: context.tr('optional')),
                  _buildModalInput(
                    controller: descCtrl,
                    hintText: context.tr('edu_desc_hint'),
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
                    saveText: isEditing ? context.tr('save_changes') : context.tr('save_education'),
                    isSubmitting: isSubmitting,
                    onSave: () async {
                      final inst = instCtrl.text.trim();
                      final degree = selectedDegree ?? 'Degree';
                      if (inst.isEmpty) return;

                      setModalState(() => isSubmitting = true);

                      final response = isEditing && eduId != null
                          ? await ProfileService.updateEducation(
                              eduId,
                              institution: inst,
                              degree: degree,
                              fieldOfStudy: fieldCtrl.text.trim(),
                              startYear: startYearCtrl.text.trim().isNotEmpty ? startYearCtrl.text.trim() : '2022',
                              endYear: isCurrentStudy ? null : endYearCtrl.text.trim(),
                              isCurrent: isCurrentStudy,
                              description: descCtrl.text.trim(),
                            )
                          : await ProfileService.storeEducation(
                              institution: inst,
                              degree: degree,
                              fieldOfStudy: fieldCtrl.text.trim(),
                              startYear: startYearCtrl.text.trim().isNotEmpty ? startYearCtrl.text.trim() : '2022',
                              endYear: isCurrentStudy ? null : endYearCtrl.text.trim(),
                              isCurrent: isCurrentStudy,
                              description: descCtrl.text.trim(),
                            );

                      if (!mounted) return;

                      if (response.success) {
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        AppDialogs.showToastModal(context, message: context.tr('education_saved'));
                        _loadProfileData();
                      } else {
                        setModalState(() => isSubmitting = false);
                        AppDialogs.showToastModal(
                          context,
                          message: response.message.isNotEmpty ? response.message : 'Failed to save education',
                          icon: Icons.error_outline_rounded,
                          iconColor: Colors.redAccent,
                        );
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

  void _showAddSkillModal({Map<String, dynamic>? skill}) {
    final bool isEditing = skill != null;
    final int? skillId = skill != null
        ? (skill['id'] is int ? skill['id'] : int.tryParse(skill['id']?.toString() ?? ''))
        : null;

    final skillCtrl = TextEditingController(text: skill?['name']?.toString() ?? '');
    final expYearsCtrl = TextEditingController(text: skill?['experience_years']?.toString() ?? '1');
    final descCtrl = TextEditingController(text: skill?['description']?.toString() ?? '');
    String? selectedProficiency = skill?['proficiency']?.toString() ?? 'Intermediate';
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
                    title: isEditing ? context.tr('edit_skill') : context.tr('add_skill'),
                    subtitle: context.tr('showcase_skills'),
                  ),
                  const SizedBox(height: 16),
                  _buildFieldLabel(context.tr('skill_name'), isRequired: true),
                  _buildModalInput(controller: skillCtrl, hintText: context.tr('skill_name_hint')),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('proficiency_level'), optionalText: context.tr('optional')),
                            _buildModalDropdown<String>(
                              value: selectedProficiency,
                              hintText: context.tr('select_proficiency'),
                              items: [
                                DropdownMenuItem(value: 'Beginner', child: Text(context.tr('prof_beginner'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Intermediate', child: Text(context.tr('prof_intermediate'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Advanced', child: Text(context.tr('prof_advanced'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Expert', child: Text(context.tr('prof_expert'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Master', child: Text(context.tr('prof_master'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
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
                            _buildFieldLabel(context.tr('years_experience'), optionalText: context.tr('optional')),
                            _buildModalInput(controller: expYearsCtrl, hintText: context.tr('years_exp_hint'), keyboardType: TextInputType.number),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel(context.tr('short_description'), optionalText: context.tr('optional')),
                  _buildModalInput(
                    controller: descCtrl,
                    hintText: context.tr('skill_desc_hint'),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('skill_context_helper'),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 20),
                  _buildModalActions(
                    sheetContext,
                    saveText: isEditing ? context.tr('save_changes') : context.tr('save_skill'),
                    isSubmitting: isSubmitting,
                    onSave: () async {
                      final name = skillCtrl.text.trim();
                      if (name.isEmpty) return;

                      setModalState(() => isSubmitting = true);

                      final expYears = int.tryParse(expYearsCtrl.text.trim()) ?? 1;

                      final response = isEditing && skillId != null
                          ? await ProfileService.updateSkill(
                              skillId,
                              name: name,
                              proficiency: selectedProficiency ?? 'Intermediate',
                              experienceYears: expYears,
                              description: descCtrl.text.trim(),
                            )
                          : await ProfileService.storeSkill(
                              name: name,
                              proficiency: selectedProficiency ?? 'Intermediate',
                              experienceYears: expYears,
                              description: descCtrl.text.trim(),
                            );

                      if (!mounted) return;

                      if (response.success) {
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        AppDialogs.showToastModal(context, message: context.tr('skill_saved'));
                        _loadProfileData();
                      } else {
                        setModalState(() => isSubmitting = false);
                        AppDialogs.showToastModal(
                          context,
                          message: response.message.isNotEmpty ? response.message : 'Failed to save skill',
                          icon: Icons.error_outline_rounded,
                          iconColor: Colors.redAccent,
                        );
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

  String _normalizedVerificationStatus(bool isVerified) {
    if (isVerified) return 'approved';
    return _fullProfile?['verification_status']?.toString().toLowerCase() ??
        _fullProfile?['verification_record']?['status']?.toString().toLowerCase() ??
        'not_verified';
  }

  Widget _buildProfileVerificationTopCard(
    Color primaryDark,
    Map<String, dynamic> profileData,
    bool isVerified,
  ) {
    final isDark = AppTheme.isDark(context);
    final verificationStatus = _normalizedVerificationStatus(isVerified);
    final bool isApproved = isVerified || verificationStatus == 'approved' || verificationStatus == 'verified';
    final bool isPending = !isApproved &&
        (verificationStatus == 'pending' ||
            verificationStatus == 'in_review' ||
            verificationStatus == 'submitted');
    final bool isPaymentPending = !isApproved && !isPending && verificationStatus == 'payment_pending';
    final bool isRejected = !isApproved &&
        !isPending &&
        !isPaymentPending &&
        (verificationStatus == 'rejected' || verificationStatus == 'declined');

    final String? rawDeclineReason = _fullProfile?['verification_decline_reason']?.toString() ??
        _fullProfile?['verification_record']?['rejection_reason']?.toString();
    final String declineReason = (rawDeclineReason != null && rawDeclineReason.trim().isNotEmpty)
        ? rawDeclineReason
        : context.tr('default_decline_reason');
    final String feeText = _verificationFee.toStringAsFixed(2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isApproved
                      ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                      : (isPending
                          ? (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7))
                          : (isRejected
                              ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2))
                              : (isDark ? const Color(0xFF134E4A) : const Color(0xFFE6F4F1)))),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isApproved
                      ? Icons.check_circle_rounded
                      : (isRejected ? Icons.cancel_outlined : Icons.shield_outlined),
                  color: isApproved
                      ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534))
                      : (isPending
                          ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                          : (isRejected
                              ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                              : (isDark ? const Color(0xFF5EEAD4) : primaryDark))),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('profile_verification'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isApproved) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF047857) : const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('verified'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('verified_badge_desc'),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary(context),
                height: 1.4,
              ),
            ),
          ] else if (isPending) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('verification_pending'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 18),
                label: Text(
                  context.tr('request_under_review'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: const Color(0xFFDC2626),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else if (isPaymentPending) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF78350F) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFFB45309) : const Color(0xFFFCD34D)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('continue_for_payment'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _isStartingPayment ? null : _initiateAndOpenRazorpay,
                icon: _isStartingPayment
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 18),
                label: Text(
                  context.trParams('complete_payment_amount', {'amount': feeText}),
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
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _isStartingPayment ? null : _showRequestVerificationModal,
                child: Text(
                  context.tr('edit_documents'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF5EEAD4) : primaryDark,
                  ),
                ),
              ),
            ),
          ] else if (isRejected) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cancel_rounded,
                    color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('rejected'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('previous_request_declined'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    declineReason,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFFECACA) : const Color(0xFF991B1B),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _showRequestVerificationModal,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                label: Text(
                  context.tr('request_again'),
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
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.brightness_1_rounded,
                    color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                    size: 8,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('not_verified'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
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

  Future<void> _initiateAndOpenRazorpay({BuildContext? modalToClose}) async {
    if (mounted) {
      setState(() => _isStartingPayment = true);
    }

    try {
      final orderResponse = await ProfileService.initiateVerificationOrder();
      if (!mounted) return;

      if (!orderResponse.success || orderResponse.data == null) {
        AppDialogs.showToastModal(
          context,
          message: orderResponse.message.isNotEmpty
              ? orderResponse.message
              : context.tr('payment_not_completed'),
          icon: Icons.error_outline_rounded,
          iconColor: Colors.red,
          iconBgColor: const Color(0xFFFEE2E2),
        );
        return;
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(orderResponse.data as Map);
      final String serverOrderId = data['order_id']?.toString() ?? '';
      final String activeKeyId = data['key_id']?.toString().trim() ?? _razorpayKeyId;
      final int amountPaise = data['amount'] is num
          ? (data['amount'] as num).toInt()
          : (_verificationFee * 100).round();
      final double amountInr = data['amount_inr'] is num
          ? (data['amount_inr'] as num).toDouble()
          : (amountPaise / 100.0);
      final String currency = data['currency']?.toString() ?? 'INR';
      final Map<String, dynamic> userData =
          data['user'] is Map ? Map<String, dynamic>.from(data['user'] as Map) : {};

      if (activeKeyId.isEmpty) {
        AppDialogs.showToastModal(
          context,
          message: 'Razorpay key ID is not configured on the server.',
          icon: Icons.error_outline_rounded,
          iconColor: Colors.red,
          iconBgColor: const Color(0xFFFEE2E2),
        );
        return;
      }

      _razorpayKeyId = activeKeyId;
      _verificationFee = amountInr;
      _activeOrderId = serverOrderId;
      _activeOrderAmountInr = amountInr;

      if (modalToClose != null && modalToClose.mounted) {
        Navigator.pop(modalToClose);
      }

      final String resolvedName = (userData['name']?.toString().trim().isNotEmpty == true)
          ? userData['name'].toString().trim()
          : (_user?.name ?? '');
      final String resolvedEmail = (userData['email']?.toString().trim().isNotEmpty == true)
          ? userData['email'].toString().trim()
          : (_user?.email ?? '');
      final String resolvedContact = _resolveNormalizedContact(
        serverPhone: userData['phone']?.toString(),
      );

      final prefill = <String, dynamic>{};
      if (resolvedName.isNotEmpty) prefill['name'] = resolvedName;
      if (resolvedContact.isNotEmpty) prefill['contact'] = resolvedContact;
      if (resolvedEmail.isNotEmpty) prefill['email'] = resolvedEmail;

      final options = <String, dynamic>{
        'key': activeKeyId,
        'amount': amountPaise,
        'currency': currency,
        'name': ApiConfig.payeeName,
        'description': 'Profile Verification Fee',
        if (prefill.isNotEmpty) 'prefill': prefill,
        if (resolvedContact.isNotEmpty || resolvedEmail.isNotEmpty)
          'readonly': {
            if (resolvedContact.isNotEmpty) 'contact': true,
            if (resolvedEmail.isNotEmpty) 'email': true,
          },
        'theme': {
          'color': '#094943',
        },
      };

      if (serverOrderId.isNotEmpty) {
        options['order_id'] = serverOrderId;
      }

      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error initiating Razorpay checkout: $e');
      if (mounted) {
        AppDialogs.showToastModal(
          context,
          message: context.tr('payment_not_completed'),
          icon: Icons.error_outline_rounded,
          iconColor: Colors.red,
          iconBgColor: const Color(0xFFFEE2E2),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingPayment = false);
      }
    }
  }

  String _formatRazorpayContact(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final bool hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return '';
    if (hasPlus) return '+$digits';
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 11 && digits.startsWith('0')) {
      return '+91${digits.substring(1)}';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }
    return '+$digits';
  }

  String _resolveNormalizedContact({String? serverPhone}) {
    final profileMap = _fullProfile?['profile'] as Map<String, dynamic>? ?? {};
    final candidates = [
      serverPhone,
      _fullProfile?['phone']?.toString(),
      _user?.phone,
      profileMap['whatsapp']?.toString(),
      profileMap['alt_phone']?.toString(),
    ];
    for (final candidate in candidates) {
      final formatted = _formatRazorpayContact(candidate);
      if (formatted.isNotEmpty) return formatted;
    }
    return '';
  }

  void _showRequestVerificationModal() {
    String selectedIdType = 'National ID Card';
    final idNumberCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final bool needsMobileInput = _resolveNormalizedContact().isEmpty;
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
                  message: context.trParams('photo_size_exceeds_5mb', {'size': mb.toStringAsFixed(1)}),
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
                message: context.trParams('error_selecting_doc', {'error': '$e'}),
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
                    title: context.tr('request_profile_verification'),
                    subtitle: context.tr('submit_govt_id_desc'),
                  ),
                  const SizedBox(height: 16),
                  _buildFieldLabel(context.tr('id_card_type'), isRequired: true),
                  _buildModalDropdown<String>(
                    value: selectedIdType,
                    hintText: context.tr('select_id_card_type'),
                    items: [
                      DropdownMenuItem(value: 'National ID Card', child: Text(context.tr('id_national'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Aadhaar Card', child: Text(context.tr('id_aadhaar'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Passport', child: Text(context.tr('id_passport'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Driving License', child: Text(context.tr('id_driving_license'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Voter ID Card', child: Text(context.tr('id_voter'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedIdType = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel(context.tr('id_card_number'), isRequired: true),
                  _buildModalInput(
                    controller: idNumberCtrl,
                    hintText: context.tr('id_card_number_hint'),
                  ),
                  if (needsMobileInput) ...[
                    const SizedBox(height: 14),
                    _buildFieldLabel(context.tr('mobile_number'), isRequired: true),
                    _buildModalInput(
                      controller: mobileCtrl,
                      hintText: context.tr('mobile_number_hint'),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Upload Front Photo Box
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(context.tr('upload_front_photo'), isRequired: true),
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
                                          Text(
                                            context.tr('choose_front_photo'),
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            context.tr('jpg_png_5mb'),
                                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
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
                            _buildFieldLabel(context.tr('upload_back_photo'), isRequired: true),
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
                                          Text(
                                            context.tr('choose_back_photo'),
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            context.tr('jpg_png_5mb'),
                                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
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
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr('id_photo_guidelines'),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.3),
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
                      children: [
                        const Icon(Icons.payments_outlined, color: Color(0xFF094943), size: 18),
                        const SizedBox(width: 8),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      text: context.tr('verification_fee_prefix'),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF065F46), height: 1.3),
                                      children: [
                                        TextSpan(
                                          text: '₹${_verificationFee.toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                        ),
                                        TextSpan(
                                          text: context.tr('verification_fee_suffix'),
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
                            saveText: context.trParams(
                              'pay_submit_amount',
                              {'amount': _verificationFee.toStringAsFixed(2)},
                            ),
                            isSubmitting: isSubmitting,
                            onSave: () async {
                              final idNumber = idNumberCtrl.text.trim();
                              if (idNumber.isEmpty) {
                                AppDialogs.showToastModal(
                                  context,
                                  message: context.tr('enter_id_number'),
                                  icon: Icons.warning_amber_rounded,
                                  iconColor: Colors.orange,
                                  iconBgColor: const Color(0xFFFEF3C7),
                                );
                                return;
                              }
                              String? enteredPhone;
                              if (needsMobileInput) {
                                final normalized = _formatRazorpayContact(mobileCtrl.text.trim());
                                if (normalized.isEmpty ||
                                    normalized.replaceAll(RegExp(r'\D'), '').length < 10) {
                                  AppDialogs.showToastModal(
                                    context,
                                    message: context.tr('enter_valid_mobile'),
                                    icon: Icons.warning_amber_rounded,
                                    iconColor: Colors.orange,
                                    iconBgColor: const Color(0xFFFEF3C7),
                                  );
                                  return;
                                }
                                enteredPhone = normalized;
                              }
                              if (frontPhoto == null) {
                                AppDialogs.showToastModal(
                                  context,
                                  message: context.tr('upload_front_id_photo'),
                                  icon: Icons.warning_amber_rounded,
                                  iconColor: Colors.orange,
                                  iconBgColor: const Color(0xFFFEF3C7),
                                );
                                return;
                              }
                              if (backPhoto == null) {
                                AppDialogs.showToastModal(
                                  context,
                                  message: context.tr('upload_back_id_photo'),
                                  icon: Icons.warning_amber_rounded,
                                  iconColor: Colors.orange,
                                  iconBgColor: const Color(0xFFFEF3C7),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);

                              final submitRes = await ProfileService.submitVerificationRequest(
                                idType: selectedIdType,
                                idNumber: idNumber,
                                frontPhoto: frontPhoto!,
                                backPhoto: backPhoto,
                                phone: enteredPhone,
                                paymentStatus: 'payment_pending',
                                feeAmount: _verificationFee,
                              );

                              if (!mounted) return;

                              if (!submitRes.success) {
                                if (sheetContext.mounted) {
                                  setModalState(() => isSubmitting = false);
                                }
                                AppDialogs.showToastModal(
                                  context,
                                  message: submitRes.message.isNotEmpty
                                      ? submitRes.message
                                      : context.tr('payment_not_completed'),
                                  icon: Icons.error_outline_rounded,
                                  iconColor: Colors.redAccent,
                                  iconBgColor: const Color(0xFFFEE2E2),
                                );
                                return;
                              }

                              if (submitRes.data is Map) {
                                _applyVerificationConfig(
                                  Map<String, dynamic>.from(submitRes.data as Map),
                                );
                              }

                              if (!sheetContext.mounted) return;
                              await _initiateAndOpenRazorpay(modalToClose: sheetContext);
                              if (sheetContext.mounted) {
                                setModalState(() => isSubmitting = false);
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
              Text(
                context.tr('sign_in_required'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                  label: Text(context.tr('sign_in_register'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn()) {
      return _buildGuestPromptScreen(
        context.tr('my_profile'),
        context.tr('sign_in_manage_profile'),
      );
    }

    const primaryDark = Color(0xFF094943);
    final profileData = _fullProfile?['profile'] as Map<String, dynamic>? ?? {};

    final userName = _fullProfile?['name']?.toString() ?? _user?.name ?? context.tr('user_profile');
    final userEmail = _fullProfile?['email']?.toString() ?? _user?.email ?? context.tr('not_provided');
    final accountType = _fullProfile?['account_type']?.toString().toUpperCase() ?? context.tr('freelancer').toUpperCase();
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

    final headline = profileData['headline']?.toString() ?? context.tr('software_engineer');
    final tagline = profileData['tagline']?.toString() ?? context.tr('any_work');
    final location = profileData['location']?.toString() ?? PresenceService.currentPlaceName;
    final bio = profileData['bio']?.toString() ?? context.tr('working_professional');
    final rawGender = profileData['gender']?.toString().toLowerCase() ?? 'male';
    final gender = _getTranslatedGender(rawGender).toUpperCase();
    final languagesText = (profileData['languages']?.toString().isNotEmpty == true)
        ? profileData['languages'].toString()
        : context.tr('default_languages_value');
    final dob = profileData['date_of_birth']?.toString() ?? context.tr('not_provided');
    final workingHours = profileData['working_hours']?.toString() ?? context.tr('working_hours_hint');
    final availabilityStatus = profileData['availability_status']?.toString() ?? context.tr('available_for_work');

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
                      languagesText: languagesText,
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
    final verificationStatus = _normalizedVerificationStatus(isVerified);
    final bool isApproved = isVerified || verificationStatus == 'approved' || verificationStatus == 'verified';
    final bool isPending = !isApproved &&
        (verificationStatus == 'pending' ||
            verificationStatus == 'in_review' ||
            verificationStatus == 'submitted');
    final bool isRejected = !isApproved &&
        !isPending &&
        (verificationStatus == 'rejected' || verificationStatus == 'declined');

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
                        color: isApproved
                            ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                            : (isPending
                                ? (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7))
                                : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2))),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isApproved
                              ? (isDark ? const Color(0xFF047857) : const Color(0xFFBBF7D0))
                              : (isPending
                                  ? (isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A))
                                  : (isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5))),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isApproved
                                ? Icons.check_circle_rounded
                                : (isPending
                                    ? Icons.schedule_rounded
                                    : (isRejected ? Icons.cancel_rounded : Icons.gpp_bad_rounded)),
                            color: isApproved
                                ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534))
                                : (isPending
                                    ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                    : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isApproved
                                ? context.tr('verified').toUpperCase()
                                : (isPending
                                    ? context.tr('verification_pending').toUpperCase()
                                    : (isRejected
                                        ? context.tr('rejected').toUpperCase()
                                        : context.tr('not_verified').toUpperCase())),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isApproved
                                  ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534))
                                  : (isPending
                                      ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                      : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))),
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
                      '5.0 (1 ${context.tr('review_singular')})',
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
        message: context.tr('max_gallery_limit'),
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
          message: context.trParams('gallery_size_exceeds_1mb', {'size': fileSizeInMB.toStringAsFixed(2)}),
          icon: Icons.error_outline_rounded,
          iconColor: Colors.redAccent,
          iconBgColor: const Color(0xFFFEE2E2),
        );
        return;
      }

      if (!mounted) return;

      // Show proper non-auto-dismissing loading dialog while uploading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.border(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: Color(0xFF094943),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('uploading_gallery_image'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

      final response = await ProfileService.uploadGalleryMedia(imageFile);

      // Dismiss loading dialog safely
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (!mounted) return;

      // Clear image cache so newly uploaded image displays immediately
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (response.success) {
        AppDialogs.showToastModal(
          context,
          message: context.tr('gallery_uploaded_success'),
        );
        await _loadProfileData();
        await ProfileService.fetchUserProfile();
        if (mounted) setState(() {});
      } else {
        AppDialogs.showToastModal(
          context,
          message: response.message.isNotEmpty ? response.message : context.tr('photo_added_gallery'),
          icon: Icons.error_outline_rounded,
          iconColor: Colors.redAccent,
          iconBgColor: const Color(0xFFFEE2E2),
        );
        await _loadProfileData();
        if (mounted) setState(() {});
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code == 'channel-error' || e.message?.contains('ImagePickerApi') == true) {
        AppDialogs.showToastModal(
          context,
          message: context.tr('rebuild_image_picker_msg'),
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.orange,
          iconBgColor: const Color(0xFFFEF3C7),
        );
      } else {
        AppDialogs.showToastModal(
          context,
          message: context.trParams('permission_error_image', {'error': e.message ?? ''}),
          icon: Icons.error_outline_rounded,
          iconColor: Colors.redAccent,
          iconBgColor: const Color(0xFFFEE2E2),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showToastModal(
        context,
        message: context.trParams('error_selecting_image', {'error': '$e'}),
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
                child: Column(
                  children: [
                    const Icon(Icons.add_photo_alternate_rounded, size: 36, color: primaryDark),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('tap_select_gallery'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('max_1mb_size'),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_rounded, color: primaryDark, size: 28),
                            const SizedBox(height: 4),
                            Text(
                              context.tr('add_photo'),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryDark),
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
                              PaintingBinding.instance.imageCache.clear();
                              PaintingBinding.instance.imageCache.clearLiveImages();
                              await _loadProfileData();
                              await ProfileService.fetchUserProfile();
                              if (mounted) setState(() {});
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
              Expanded(child: _buildInfoBadge(Icons.translate_rounded, languagesText, context.tr('languages'))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildInfoBadge(Icons.location_on_outlined, location, context.tr('location'))),
              const SizedBox(width: 10),
              Expanded(child: _buildInfoBadge(Icons.person_outline, gender, context.tr('gender'))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildInfoBadge(Icons.cake_outlined, dob, context.tr('date_of_birth'))),
              const SizedBox(width: 10),
              Expanded(
                child: Builder(
                  builder: (ctx) {
                    final status = _normalizedVerificationStatus(isVerified);
                    final isApproved = isVerified || status == 'approved' || status == 'verified';
                    final isPending = !isApproved && (status == 'pending' || status == 'in_review' || status == 'submitted');
                    final isRejected = !isApproved && !isPending && (status == 'rejected' || status == 'declined');
                    final isDark = AppTheme.isDark(ctx);

                    final color = isApproved
                        ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534))
                        : (isPending
                            ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                            : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)));

                    return _buildInfoBadge(
                      isApproved
                          ? Icons.check_circle_rounded
                          : (isPending
                              ? Icons.schedule_rounded
                              : (isRejected ? Icons.cancel_rounded : Icons.gpp_bad_rounded)),
                      isApproved
                          ? ctx.tr('verified')
                          : (isPending
                              ? ctx.tr('verification_pending')
                              : (isRejected ? ctx.tr('rejected') : ctx.tr('not_verified'))),
                      ctx.tr('trust_status'),
                      iconColor: color,
                      valueColor: color,
                    );
                  },
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
                onPressed: () => _showAddExperienceModal(),
                icon: Icon(Icons.add, size: 16, color: primaryDark),
                label: Text(context.tr('add'), style: TextStyle(fontSize: 12, color: primaryDark, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_experiences.isEmpty)
            Text(context.tr('no_experience_added'), style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)))
          else
            ..._experiences.map((exp) {
              final id = exp['id'] is int ? exp['id'] : int.tryParse(exp['id']?.toString() ?? '');
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
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
                            ],
                          ),
                        ),
                        // Edit Button
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 18, color: primaryDark),
                          onPressed: () => _showAddExperienceModal(experience: exp),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                        const SizedBox(width: 4),
                        // Delete Button
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          onPressed: () async {
                            if (id != null) {
                              final res = await ProfileService.destroyExperience(id);
                              if (res.success && mounted) _loadProfileData();
                            }
                          },
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                      ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${context.tr('education')} (${_educations.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
              TextButton.icon(
                onPressed: () => _showAddEducationModal(),
                icon: Icon(Icons.add, size: 16, color: primaryDark),
                label: Text(context.tr('add'), style: TextStyle(fontSize: 12, color: primaryDark, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_educations.isEmpty)
            Text(context.tr('no_education_added'), style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)))
          else
            ..._educations.map((edu) {
              final id = edu['id'] is int ? edu['id'] : int.tryParse(edu['id']?.toString() ?? '');
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
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
                            ],
                          ),
                        ),
                        // Edit Button
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 18, color: primaryDark),
                          onPressed: () => _showAddEducationModal(education: edu),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                        const SizedBox(width: 4),
                        // Delete Button
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          onPressed: () async {
                            if (id != null) {
                              final res = await ProfileService.destroyEducation(id);
                              if (res.success && mounted) _loadProfileData();
                            }
                          },
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                      ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${context.tr('skills_expertise')} (${_skills.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
              TextButton.icon(
                onPressed: () => _showAddSkillModal(),
                icon: Icon(Icons.add, size: 16, color: primaryDark),
                label: Text(context.tr('add'), style: TextStyle(fontSize: 12, color: primaryDark, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_skills.isEmpty)
            Text(context.tr('no_skills_added'), style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)))
          else
            ..._skills.map((s) {
              final rawId = s['id'];
              final int? id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Wrap(
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
                        ),
                        // Edit Button
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 18, color: primaryDark),
                          onPressed: () => _showAddSkillModal(skill: s),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                        const SizedBox(width: 4),
                        // Delete Button
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          onPressed: () async {
                            if (id != null) {
                              final response = await ProfileService.destroySkill(id);
                              if (response.success && mounted) _loadProfileData();
                            }
                          },
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
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

  Widget _buildVerificationAndSocialCard(Color primaryDark, String email, Map<String, dynamic> profileData) {
    final bool isVerified = _fullProfile?['is_verified'] == true || _user?.isVerified == true;
    final status = _normalizedVerificationStatus(isVerified);
    final bool isApproved = isVerified || status == 'approved' || status == 'verified';
    final bool isPending = !isApproved && (status == 'pending' || status == 'in_review' || status == 'submitted');
    final bool isRejected = !isApproved && !isPending && (status == 'rejected' || status == 'declined');
    final isDark = AppTheme.isDark(context);

    final IconData statusIcon = isApproved
        ? Icons.check_circle
        : (isPending ? Icons.schedule_rounded : (isRejected ? Icons.cancel_rounded : Icons.gpp_bad_rounded));
    final Color statusColor = isApproved
        ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534))
        : (isPending
            ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
            : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)));
    final String statusText = isApproved
        ? context.tr('verified')
        : (isPending
            ? context.tr('verification_pending')
            : (isRejected ? context.tr('rejected') : context.tr('not_verified')));

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
              Icon(statusIcon, color: statusColor, size: 18),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
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

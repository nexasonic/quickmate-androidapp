import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'core/api_service.dart';
import 'core/app_dialogs.dart';
import 'login_screen.dart';
import 'models/category_model.dart';
import 'models/live_work_card_model.dart';
import 'services/auth_service.dart';
import 'services/live_work_service.dart';
import 'services/my_live_work_service.dart';

class CardPhotoItem {
  final String? networkUrl;
  final File? localFile;
  bool isMain;

  CardPhotoItem({
    this.networkUrl,
    this.localFile,
    this.isMain = false,
  });

  bool get isNetwork => networkUrl != null && networkUrl!.isNotEmpty;
  bool get isLocal => localFile != null;
}

class MyCardsScreen extends StatefulWidget {
  const MyCardsScreen({super.key});

  @override
  State<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends State<MyCardsScreen> {
  int _selectedStatusTab = 0; // 0: All Status, 1: Active, 2: Paused, 3: Expired
  bool _isLoading = true;
  List<LiveWorkCardModel> _allCards = [];
  List<CategoryModel> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final cards = await MyLiveWorkService.fetchMyLiveWorkCards();
    final categories = await LiveWorkService.fetchCategories();

    if (!mounted) return;

    setState(() {
      _allCards = cards;
      _categories = categories;
      _isLoading = false;
    });
  }

  List<LiveWorkCardModel> get _filteredCards {
    if (_selectedStatusTab == 1) {
      return _allCards.where((c) => c.isActive && !c.isExpired).toList();
    } else if (_selectedStatusTab == 2) {
      return _allCards.where((c) => c.isPaused && !c.isExpired).toList();
    } else if (_selectedStatusTab == 3) {
      return _allCards.where((c) => c.isExpired).toList();
    }
    return _allCards;
  }

  int _countByTab(int tabIndex) {
    if (tabIndex == 0) return _allCards.length;
    if (tabIndex == 1) return _allCards.where((c) => c.isActive && !c.isExpired).length;
    if (tabIndex == 2) return _allCards.where((c) => c.isPaused && !c.isExpired).length;
    if (tabIndex == 3) return _allCards.where((c) => c.isExpired).length;
    return 0;
  }

  Future<void> _toggleStatus(LiveWorkCardModel card) async {
    final response = await MyLiveWorkService.toggleCardStatus(card.id, currentIsActive: card.isActive);
    if (!mounted) return;
    if (response.success) {
      AppDialogs.showToastModal(
        context,
        message: 'Status updated for "${card.title}"',
      );
      _loadData();
    } else {
      AppDialogs.showToastModal(
        context,
        message: response.message.isNotEmpty ? response.message : 'Failed to update status.',
        icon: Icons.error_outline_rounded,
        iconColor: Colors.redAccent,
        iconBgColor: const Color(0xFFFEE2E2),
      );
    }
  }

  Future<void> _repostOrUpdateCard(LiveWorkCardModel card) async {
    final response = await MyLiveWorkService.bumpCard(card.id);
    if (!mounted) return;
    if (response.success) {
      AppDialogs.showToastModal(
        context,
        message: 'Card updated & timer renewed for "${card.title}"!',
      );
      _loadData();
    } else {
      AppDialogs.showToastModal(
        context,
        message: response.message.isNotEmpty ? response.message : 'Card updated.',
      );
      _loadData();
    }
  }

  Future<void> _deleteCard(LiveWorkCardModel card) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Live Work Card'),
        content: Text('Are you sure you want to delete "${card.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final response = await MyLiveWorkService.deleteCard(card.id);
      if (!mounted) return;
      if (response.success) {
        AppDialogs.showToastModal(
          context,
          message: 'Card deleted successfully.',
        );
        _loadData();
      }
    }
  }

  String _formatBudgetTypeForApi(String display) {
    switch (display) {
      case 'Fixed Price':
        return 'fixed';
      case 'Per Hour':
        return 'per_hour';
      case 'Per Day':
        return 'per_day';
      case 'Negotiable':
      default:
        return 'negotiable';
    }
  }

  String _normalizeBudgetType(String? raw) {
    if (raw == null || raw.isEmpty) return 'Negotiable';
    final lower = raw.trim().toLowerCase();
    if (lower == 'fixed' || lower == 'fixed_price' || lower == 'fixed price') {
      return 'Fixed Price';
    } else if (lower == 'per_hour' || lower == 'hourly' || lower == 'per hour') {
      return 'Per Hour';
    } else if (lower == 'per_day' || lower == 'daily' || lower == 'per day') {
      return 'Per Day';
    } else if (lower == 'negotiable') {
      return 'Negotiable';
    }
    return 'Negotiable';
  }

  String _normalizeExpiryTime(String? raw) {
    if (raw == null || raw.isEmpty) return '24 hours (Default)';
    final lower = raw.trim().toLowerCase();
    if (lower.contains('12')) return '12 hours';
    if (lower.contains('24')) return '24 hours (Default)';
    if (lower.contains('48')) return '48 hours';
    if (lower.contains('7') || lower.contains('day')) return '7 days';
    return '24 hours (Default)';
  }

  void _showCardModal({LiveWorkCardModel? cardToEdit}) {
    final bool isEditing = cardToEdit != null;

    final titleController = TextEditingController(text: cardToEdit?.title ?? '');
    final locationController = TextEditingController(text: cardToEdit?.location ?? 'Thodupuzha');
    final descController = TextEditingController(text: cardToEdit?.description ?? '');
    final priceController = TextEditingController(
      text: cardToEdit?.price != null && cardToEdit!.price! > 0
          ? (cardToEdit.price! % 1 == 0 ? cardToEdit.price!.toInt().toString() : cardToEdit.price!.toString())
          : '',
    );
    final tagInputController = TextEditingController();

    int? selectedCategoryId;
    if (cardToEdit?.category?.id != null) {
      final match = _categories.where((c) => c.id == cardToEdit!.category!.id);
      if (match.isNotEmpty) {
        selectedCategoryId = match.first.id;
      }
    }
    if (selectedCategoryId == null && _categories.isNotEmpty) {
      selectedCategoryId = _categories.first.id;
    }

    String selectedExpiry = _normalizeExpiryTime(cardToEdit?.expiresAt);
    String selectedBudgetType = _normalizeBudgetType(cardToEdit?.priceType);

    final List<String> currentTags = List<String>.from(cardToEdit?.tags ?? []);
    final List<CardPhotoItem> modalPhotos = [];

    if (isEditing && cardToEdit != null) {
      final existingUrls = <String>[];
      if (cardToEdit.thumbnailUrl != null && cardToEdit.thumbnailUrl!.isNotEmpty) {
        existingUrls.add(cardToEdit.thumbnailUrl!);
      }
      for (final imgUrl in cardToEdit.images) {
        if (imgUrl.isNotEmpty && !existingUrls.contains(imgUrl)) {
          existingUrls.add(imgUrl);
        }
      }

      for (int i = 0; i < existingUrls.length && modalPhotos.length < 3; i++) {
        modalPhotos.add(CardPhotoItem(
          networkUrl: existingUrls[i],
          isMain: i == 0,
        ));
      }
    }

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          Future<void> pickPhoto() async {
            if (modalPhotos.length >= 3) {
              AppDialogs.showToastModal(
                context,
                message: 'Maximum 3 photos allowed per card.',
                icon: Icons.warning_amber_rounded,
                iconColor: Colors.orange,
                iconBgColor: const Color(0xFFFEF3C7),
              );
              return;
            }
            try {
              final ImagePicker picker = ImagePicker();
              final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
              if (picked != null) {
                setModalState(() {
                  final isFirst = modalPhotos.isEmpty;
                  modalPhotos.add(CardPhotoItem(
                    localFile: File(picked.path),
                    isMain: isFirst,
                  ));
                });
              }
            } catch (e) {
              debugPrint('Image pick error: $e');
            }
          }

          void addTagFromInput() {
            final t = tagInputController.text.trim().replaceAll(',', '');
            if (t.isNotEmpty && !currentTags.contains(t) && currentTags.length < 5) {
              setModalState(() {
                currentTags.add(t);
                tagInputController.clear();
              });
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
                  // Modal Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4F1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEditing ? Icons.edit_note_rounded : Icons.business_center_outlined,
                          color: const Color(0xFF094943),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Edit Live Work Card' : 'Create Live Work Card',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              isEditing
                                  ? (cardToEdit.title)
                                  : 'Fill in the details below to publish your card.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Task Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFieldLabel('TASK TITLE', isRequired: true),
                      Text(
                        '${titleController.text.length}/80',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  _buildModalInput(
                    controller: titleController,
                    hintText: 'e.g. Need a Plumber for kitchen leak repair',
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 14),

                  // Category & Location Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('CATEGORY', isRequired: true),
                            _buildModalDropdown<int>(
                              value: selectedCategoryId,
                              hintText: 'Select category',
                              items: _categories.map((c) {
                                return DropdownMenuItem<int>(value: c.id, child: Text(c.name));
                              }).toList(),
                              onChanged: (val) => setModalState(() => selectedCategoryId = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('LOCATION', isRequired: true),
                            _buildModalInput(
                              controller: locationController,
                              hintText: 'e.g. Kochi, Kerala',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Expiry Time & Budget Type Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('EXPIRY TIME', isRequired: true),
                            _buildModalDropdown<String>(
                              value: selectedExpiry,
                              hintText: 'Select expiry',
                              items: const [
                                DropdownMenuItem(value: '12 hours', child: Text('12 hours')),
                                DropdownMenuItem(value: '24 hours (Default)', child: Text('24 hours (Default)')),
                                DropdownMenuItem(value: '48 hours', child: Text('48 hours')),
                                DropdownMenuItem(value: '7 days', child: Text('7 days')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedExpiry = val);
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
                            _buildFieldLabel('BUDGET TYPE', isRequired: true),
                            _buildModalDropdown<String>(
                              value: selectedBudgetType,
                              hintText: 'Select budget type',
                              items: const [
                                DropdownMenuItem(value: 'Negotiable', child: Text('Negotiable')),
                                DropdownMenuItem(value: 'Fixed Price', child: Text('Fixed Price')),
                                DropdownMenuItem(value: 'Per Hour', child: Text('Per Hour')),
                                DropdownMenuItem(value: 'Per Day', child: Text('Per Day')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedBudgetType = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (selectedBudgetType != 'Negotiable') ...[
                    const SizedBox(height: 14),
                    _buildFieldLabel('PRICE / AMOUNT (INR)', isRequired: true),
                    _buildModalInput(
                      controller: priceController,
                      hintText: 'e.g. 500',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Describe the work
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFieldLabel('DESCRIBE THE WORK', isRequired: true),
                      Text(
                        '${descController.text.length}/250',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  _buildModalInput(
                    controller: descController,
                    hintText: 'Describe exactly what needs to be done. More details = better matches.',
                    maxLines: 4,
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 14),

                  // Tags Input Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFieldLabel('TAGS'),
                      Text(
                        '${currentTags.length}/5 tags',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  if (currentTags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: currentTags.map((tag) {
                          return Chip(
                            label: Text(tag, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF094943))),
                            backgroundColor: const Color(0xFFE6F4F1),
                            deleteIcon: const Icon(Icons.close, size: 14, color: Colors.grey),
                            onDeleted: () {
                              setModalState(() {
                                currentTags.remove(tag);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  TextField(
                    controller: tagInputController,
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (_) => addTagFromInput(),
                    decoration: InputDecoration(
                      hintText: 'Type a tag and press Enter (max 5)',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF094943)),
                        onPressed: addTagFromInput,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF094943), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Photos Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFieldLabel('PHOTOS'),
                      Text(
                        '${modalPhotos.length}/3 images',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...modalPhotos.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;

                          return Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 85,
                            height: 85,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: item.isLocal
                                      ? Image.file(item.localFile!, fit: BoxFit.cover)
                                      : Image.network(
                                          item.networkUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: const Color(0xFFE2E8F0),
                                            child: const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 24),
                                          ),
                                        ),
                                ),
                                // Main Badge / Set Main Button at Bottom
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      if (!item.isMain) {
                                        setModalState(() {
                                          for (int i = 0; i < modalPhotos.length; i++) {
                                            modalPhotos[i].isMain = (i == idx);
                                          }
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                      decoration: BoxDecoration(
                                        color: item.isMain
                                            ? const Color(0xFF094943)
                                            : Colors.black.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.isMain ? '★ Main' : 'Set Main',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: item.isMain ? FontWeight.bold : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Remove Image Button (Red × Top Right)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        final wasMain = modalPhotos[idx].isMain;
                                        modalPhotos.removeAt(idx);
                                        if (wasMain && modalPhotos.isNotEmpty) {
                                          modalPhotos[0].isMain = true;
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (modalPhotos.length < 3)
                          GestureDetector(
                            onTap: pickPhoto,
                            child: Container(
                              width: 85,
                              height: 85,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, color: Color(0xFF094943), size: 22),
                                  SizedBox(height: 4),
                                  Text(
                                    'Add Photo',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF094943)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ⓘ Tap Set Main to select the cover photo. Tap the red × to remove any photo.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 20),

                  // Modal Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(modalContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF334155),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final title = titleController.text.trim();
                                if (title.isEmpty) {
                                  AppDialogs.showToastModal(
                                    context,
                                    message: 'Please enter Task Title.',
                                    icon: Icons.warning_amber_rounded,
                                    iconColor: Colors.orange,
                                    iconBgColor: const Color(0xFFFEF3C7),
                                  );
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                });

                                final priceVal = double.tryParse(priceController.text.trim());

                                final List<File> filesToSend = [];
                                final mainLocal = modalPhotos.where((p) => p.isMain && p.isLocal);
                                if (mainLocal.isNotEmpty) {
                                  filesToSend.add(mainLocal.first.localFile!);
                                }
                                for (final p in modalPhotos) {
                                  if (p.isLocal && !p.isMain) {
                                    filesToSend.add(p.localFile!);
                                  }
                                }

                                ApiResponse response;
                                final apiPriceType = _formatBudgetTypeForApi(selectedBudgetType);

                                if (isEditing) {
                                  response = await MyLiveWorkService.updateLiveWorkCard(
                                    id: cardToEdit.id,
                                    title: title,
                                    categoryId: selectedCategoryId,
                                    description: descController.text.trim(),
                                    price: priceVal,
                                    priceType: apiPriceType,
                                    location: locationController.text.trim(),
                                    expiryTime: selectedExpiry,
                                    tags: currentTags,
                                    images: filesToSend.isNotEmpty ? filesToSend : null,
                                  );
                                } else {
                                  response = await MyLiveWorkService.createLiveWorkCard(
                                    title: title,
                                    categoryId: selectedCategoryId,
                                    description: descController.text.trim(),
                                    price: priceVal,
                                    priceType: apiPriceType,
                                    location: locationController.text.trim(),
                                    expiryTime: selectedExpiry,
                                    tags: currentTags,
                                    images: filesToSend.isNotEmpty ? filesToSend : null,
                                  );
                                }

                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }

                                if (response.success) {
                                  if (mounted) {
                                    AppDialogs.showToastModal(
                                      context,
                                      message: isEditing
                                          ? 'Live Work Card updated!'
                                          : 'Live Work Card published successfully!',
                                    );
                                  }
                                  _loadData();
                                } else {
                                  if (mounted) {
                                    AppDialogs.showToastModal(
                                      context,
                                      message: response.message.isNotEmpty
                                          ? response.message
                                          : (isEditing ? 'Update failed.' : 'Creation failed.'),
                                      icon: Icons.error_outline_rounded,
                                      iconColor: Colors.redAccent,
                                      iconBgColor: const Color(0xFFFEE2E2),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF094943),
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
                            : Row(
                                children: [
                                  Icon(isEditing ? Icons.check_rounded : Icons.publish_rounded, color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    isEditing ? 'Save Changes' : 'Publish Card',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
                letterSpacing: 0.5,
              ),
            ),
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
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
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF094943), width: 1.5),
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
      isExpanded: true,
      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 20),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF094943), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildGuestPromptScreen() {
    const primaryDark = Color(0xFF094943);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: primaryDark,
        elevation: 0,
        title: const Text('My Live Work Cards', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                child: const Icon(Icons.lock_outline_rounded, size: 54, color: primaryDark),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sign In Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please sign in to manage, edit, pause or post your live work cards.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
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
                      _loadData();
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
      return _buildGuestPromptScreen();
    }

    const primaryDark = Color(0xFF094943);
    final activeCount = _allCards.where((c) => c.isActive && !c.isExpired).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: Stack(
        children: [
          Container(
            height: 180,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF064E3B),
                  Color(0xFF094943),
                  Color(0xFF0D9488),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom App Bar Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'My Live Work Cards',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Manage all your live work listings in one place.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                        ),
                        onPressed: _loadData,
                      ),
                    ],
                  ),
                ),

                // Body Content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    color: primaryDark,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Banner
                          _buildHeroBannerCard(activeCount),
                          const SizedBox(height: 18),

                          // Status Filter Chips
                          _buildStatusFilterRow(),
                          const SizedBox(height: 18),

                          // Cards List
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(
                                child: CircularProgressIndicator(color: primaryDark),
                              ),
                            )
                          else if (_filteredCards.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(30),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                children: const [
                                  Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                                  SizedBox(height: 12),
                                  Text(
                                    'No Live Work cards found.',
                                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _filteredCards.length,
                              itemBuilder: (context, index) {
                                final card = _filteredCards[index];
                                return _buildWebStyleWorkCard(card);
                              },
                            ),
                          const SizedBox(height: 16),

                          Center(
                            child: Text(
                              'Showing ${_filteredCards.length} of ${_allCards.length} cards',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBannerCard(int activeCount) {
    const primaryDark = Color(0xFF094943);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: primaryDark,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Live Work Cards',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Create, edit, bump or pause your live work cards anytime.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatPill('${_allCards.length}', 'Total'),
              const SizedBox(width: 8),
              _buildStatPill('$activeCount', 'Active'),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => _showCardModal(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryDark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Create Live Work Card',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildStatPill(String count, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatusChip(0, 'All Status'),
          const SizedBox(width: 8),
          _buildStatusChip(1, 'Active'),
          const SizedBox(width: 8),
          _buildStatusChip(2, 'Paused'),
          const SizedBox(width: 8),
          _buildStatusChip(3, 'Expired'),
        ],
      ),
    );
  }

  Widget _buildStatusChip(int index, String label) {
    final bool isSelected = _selectedStatusTab == index;
    final count = _countByTab(index);
    const primaryDark = Color(0xFF094943);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatusTab = index;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryDark : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildWebStyleWorkCard(LiveWorkCardModel card) {
    const primaryDark = Color(0xFF094943);
    final coverImage = card.thumbnailUrl ?? (card.images.isNotEmpty ? card.images.first : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner / Cover Photo with Badges
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: coverImage != null && coverImage.isNotEmpty
                    ? Image.network(
                        coverImage,
                        width: double.infinity,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 160,
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 40),
                        ),
                      )
                    : Container(
                        height: 160,
                        color: const Color(0xFFE2E8F0),
                        child: const Icon(Icons.work_outline_rounded, color: Colors.grey, size: 40),
                      ),
              ),

              // Status Badge Top Left
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: card.isExpired
                        ? const Color(0xFFFEE2E2)
                        : (card.isPaused ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.brightness_1_rounded,
                        size: 8,
                        color: card.isExpired
                            ? const Color(0xFFDC2626)
                            : (card.isPaused ? const Color(0xFFD97706) : const Color(0xFF166534)),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        card.statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: card.isExpired
                              ? const Color(0xFFDC2626)
                              : (card.isPaused ? const Color(0xFFD97706) : const Color(0xFF166534)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Price Badge Top Right
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                    ],
                  ),
                  child: Text(
                    card.formattedPrice,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primaryDark,
                    ),
                  ),
                ),
              ),

              // Expiry Time Pill Bottom Left
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_rounded, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        card.formattedExpiresIn,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Category Badge Bottom Right
              if (card.category != null)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      card.category!.name,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Content Details Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (card.location != null && card.location!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 2),
                      Text(
                        card.location!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
                if (card.description != null && card.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    card.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3),
                  ),
                ],

                // Tags Chips Row
                if (card.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: card.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4F1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryDark),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Multiple Image Thumbnails Row
                if (card.images.length > 1) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 45,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: card.images.length,
                      itemBuilder: (context, i) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 45,
                          height: 45,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              card.images[i],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Views & Time Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.remove_red_eye_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          '${card.viewsCount}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          '${card.reviewsCount}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    Text(
                      card.formattedTimeAgo,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4 Action Buttons Row (Edit, Pause/Activate, Update/Repost, Delete)
                Row(
                  children: [
                    // 1. Edit
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton.icon(
                          onPressed: () => _showCardModal(cardToEdit: card),
                          icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF334155)),
                          label: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // 2. Pause / Activate
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton.icon(
                          onPressed: () => _toggleStatus(card),
                          icon: Icon(
                            card.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                            size: 14,
                            color: card.isActive ? const Color(0xFFD97706) : const Color(0xFF166534),
                          ),
                          label: Text(
                            card.isActive ? 'Pause' : 'Activate',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: card.isActive ? const Color(0xFFD97706) : const Color(0xFF166534),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: BorderSide(
                              color: card.isActive ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0),
                            ),
                            backgroundColor: card.isActive ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // 3. Update / Repost
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton.icon(
                          onPressed: () => _repostOrUpdateCard(card),
                          icon: const Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFF059669)),
                          label: Text(
                            card.isExpired ? 'Repost' : 'Update',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: const Color(0xFFECFDF5),
                            side: const BorderSide(color: Color(0xFFA7F3D0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // 4. Delete
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton.icon(
                          onPressed: () => _deleteCard(card),
                          icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                          label: const Text('Delete', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: const Color(0xFFFEF2F2),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'core/api_service.dart';
import 'core/app_dialogs.dart';
import 'core/app_language.dart';
import 'core/app_theme.dart';
import 'login_screen.dart';
import 'models/category_model.dart';
import 'models/live_work_card_model.dart';
import 'services/auth_service.dart';
import 'services/live_work_service.dart';
import 'services/my_live_work_service.dart';
import 'services/presence_service.dart';

class CardPhotoItem {
  final int? mediaId;
  final String? networkUrl;
  final File? localFile;
  bool isMain;

  CardPhotoItem({
    this.mediaId,
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
  State<MyCardsScreen> createState() => MyCardsScreenState();
}

class MyCardsScreenState extends State<MyCardsScreen> {
  int _selectedStatusTab = 0; // 0: All Status, 1: Active, 2: Paused, 3: Expired
  bool _isLoading = true;
  List<LiveWorkCardModel> _allCards = [];
  List<CategoryModel> _categories = [];

  Future<void> refresh() => _loadData();

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
        message: context.trParams('status_updated_for', {'title': card.title}),
      );
      _loadData();
    } else {
      AppDialogs.showToastModal(
        context,
        message: response.message.isNotEmpty ? response.message : context.tr('failed_update_status'),
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
        message: context.trParams('card_updated_renewed', {'title': card.title}),
      );
      _loadData();
    } else {
      AppDialogs.showToastModal(
        context,
        message: response.message.isNotEmpty ? response.message : context.tr('card_updated'),
      );
      _loadData();
    }
  }

  Future<void> _deleteCard(LiveWorkCardModel card) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(dialogContext.tr('delete_live_work_card')),
        content: Text(dialogContext.trParams('delete_card_confirm', {'title': card.title})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('delete'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          message: context.tr('card_deleted_success'),
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

    final List<int> removeImageIds = [];

    if (isEditing) {
      if (cardToEdit.rawMedias.isNotEmpty) {
        for (int i = 0; i < cardToEdit.rawMedias.length && modalPhotos.length < 3; i++) {
          final m = cardToEdit.rawMedias[i];
          final rawId = m['id'];
          final int? mediaId = rawId is int ? rawId : (rawId != null ? int.tryParse(rawId.toString()) : null);
          modalPhotos.add(CardPhotoItem(
            mediaId: mediaId,
            networkUrl: m['url']?.toString(),
            isMain: i == 0,
          ));
        }
      } else {
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
    }

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          Future<void> pickPhoto() async {
            if (modalPhotos.length >= 3) {
              AppDialogs.showToastModal(
                context,
                message: context.tr('max_3_photos'),
                icon: Icons.warning_amber_rounded,
                iconColor: Colors.orange,
                iconBgColor: const Color(0xFFFEF3C7),
              );
              return;
            }
            try {
              final ImagePicker picker = ImagePicker();
              final List<XFile> pickedList = await picker.pickMultiImage(imageQuality: 85);
              if (pickedList.isNotEmpty) {
                setModalState(() {
                  for (final file in pickedList) {
                    if (modalPhotos.length >= 3) break;
                    final isFirst = modalPhotos.isEmpty;
                    modalPhotos.add(CardPhotoItem(
                      localFile: File(file.path),
                      isMain: isFirst,
                    ));
                  }
                });
              } else {
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
                          color: AppTheme.isDark(context) ? const Color(0xFF134E4A) : const Color(0xFFE6F4F1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEditing ? Icons.edit_note_rounded : Icons.business_center_outlined,
                          color: AppTheme.primary(context),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? context.tr('edit_card') : context.tr('create_live_work'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                            Text(
                              isEditing
                                  ? (cardToEdit.title)
                                  : context.tr('fill_details_desc'),
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: AppTheme.divider(context)),
                  const SizedBox(height: 16),

                  // Task Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFieldLabel(context.tr('task_title'), isRequired: true),
                      Text(
                        '${titleController.text.length}/80',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  _buildModalInput(
                    controller: titleController,
                    hintText: context.tr('task_title_hint'),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 14),

                  // Category Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel(context.tr('category').toUpperCase(), isRequired: true),
                      _buildModalDropdown<int>(
                        value: selectedCategoryId,
                        hintText: context.tr('select_category'),
                        items: _categories.map((c) {
                          return DropdownMenuItem<int>(value: c.id, child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)));
                        }).toList(),
                        onChanged: (val) => setModalState(() => selectedCategoryId = val),
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
                            _buildFieldLabel(context.tr('expiry_time'), isRequired: true),
                            _buildModalDropdown<String>(
                              value: selectedExpiry,
                              hintText: context.tr('select_expiry'),
                              items: [
                                DropdownMenuItem(value: '12 hours', child: Text(context.tr('expiry_12_hours'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: '24 hours (Default)', child: Text(context.tr('expiry_24_hours_default'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: '48 hours', child: Text(context.tr('expiry_48_hours'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: '7 days', child: Text(context.tr('expiry_7_days'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
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
                            _buildFieldLabel(context.tr('budget_type'), isRequired: true),
                            _buildModalDropdown<String>(
                              value: selectedBudgetType,
                              hintText: context.tr('select_expiry'),
                              items: [
                                DropdownMenuItem(value: 'Negotiable', child: Text(context.tr('negotiable'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Fixed Price', child: Text(context.tr('fixed_price'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Per Hour', child: Text(context.tr('budget_per_hour'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Per Day', child: Text(context.tr('budget_per_day'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
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
                    _buildFieldLabel(context.tr('price_amount_inr'), isRequired: true),
                    _buildModalInput(
                      controller: priceController,
                      hintText: context.tr('price_hint_example'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Describe the work
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFieldLabel(context.tr('describe_work'), isRequired: true),
                      Text(
                        '${descController.text.length}/250',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  _buildModalInput(
                    controller: descController,
                    hintText: context.tr('describe_work_hint'),
                    maxLines: 4,
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 14),

                  // Tags Input Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFieldLabel(context.tr('tags')),
                      Text(
                        context.trParams('tags_count', {'count': '${currentTags.length}'}),
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
                    style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(context)),
                    onSubmitted: (_) => addTagFromInput(),
                    decoration: InputDecoration(
                      hintText: context.tr('tags_hint'),
                      hintStyle: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: AppTheme.inputFill(context),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary(context)),
                        onPressed: addTagFromInput,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.border(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.primary(context), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Photos Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFieldLabel(context.tr('photos')),
                      Text(
                        context.trParams('images_count', {'count': '${modalPhotos.length}'}),
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
                                        item.isMain ? context.tr('main_badge') : context.tr('set_main'),
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
                                        final removed = modalPhotos.removeAt(idx);
                                        if (removed.mediaId != null) {
                                          removeImageIds.add(removed.mediaId!);
                                        }
                                        if (removed.isMain && modalPhotos.isNotEmpty) {
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
                                color: AppTheme.subtleBackground(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border(context)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : AppTheme.primary(context),
                                    size: 22,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    context.tr('add_photo'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : AppTheme.primary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ⓘ ${context.tr('photo_instructions')}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                  ),
                  const SizedBox(height: 20),

                  // Modal Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(modalContext),
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
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final title = titleController.text.trim();
                                if (title.isEmpty) {
                                  AppDialogs.showToastModal(
                                    context,
                                    message: context.tr('enter_task_title'),
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
                                int? mainImageIdx;
                                int? mainImageId;

                                for (final p in modalPhotos) {
                                  if (p.isLocal) {
                                    filesToSend.add(p.localFile!);
                                    if (p.isMain) {
                                      mainImageIdx = filesToSend.length - 1;
                                    }
                                  } else if (p.isNetwork && p.isMain && p.mediaId != null) {
                                    mainImageId = p.mediaId;
                                  }
                                }

                                if (mainImageId == null && mainImageIdx == null && filesToSend.isNotEmpty) {
                                  mainImageIdx = 0;
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
                                    location: cardToEdit.location ?? PresenceService.currentPlaceName,
                                    expiryTime: selectedExpiry,
                                    tags: currentTags,
                                    images: filesToSend.isNotEmpty ? filesToSend : null,
                                    mainImageIdx: mainImageIdx,
                                    mainImageId: mainImageId,
                                    removeImageIds: removeImageIds.isNotEmpty ? removeImageIds : null,
                                  );
                                } else {
                                  response = await MyLiveWorkService.createLiveWorkCard(
                                    title: title,
                                    categoryId: selectedCategoryId,
                                    description: descController.text.trim(),
                                    price: priceVal,
                                    priceType: apiPriceType,
                                    location: PresenceService.currentPlaceName,
                                    expiryTime: selectedExpiry,
                                    tags: currentTags,
                                    images: filesToSend.isNotEmpty ? filesToSend : null,
                                    mainImageIdx: mainImageIdx,
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
                                          ? context.tr('card_updated_toast')
                                          : context.tr('card_published_toast'),
                                    );
                                  }
                                  _loadData();
                                } else {
                                  if (mounted) {
                                    AppDialogs.showToastModal(
                                      context,
                                      message: response.message.isNotEmpty
                                          ? response.message
                                          : (isEditing ? context.tr('update_failed') : context.tr('creation_failed')),
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
                                    isEditing ? context.tr('save_changes') : context.tr('publish_card'),
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
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary(context),
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
      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(context)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
      dropdownColor: AppTheme.surface(context),
      style: TextStyle(fontSize: 12, color: AppTheme.textPrimary(context)),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary(context), size: 20),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        filled: true,
        fillColor: AppTheme.inputFill(context),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF094943), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildGuestPromptScreen() {
    final primaryDark = AppTheme.primary(context);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.appBarBg(context),
        elevation: 0,
        title: Text(context.tr('my_live_work_cards'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: primaryDark,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - kToolbarHeight - MediaQuery.of(context).padding.top,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppTheme.isDark(context) ? const Color(0xFF134E4A) : const Color(0xFFE6F4F1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock_outline_rounded, size: 54, color: primaryDark),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.tr('sign_in_required'),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('sign_in_manage_cards'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context), height: 1.4),
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

    final primaryDark = AppTheme.primary(context);
    final isDark = AppTheme.isDark(context);
    final activeCount = _allCards.where((c) => c.isActive && !c.isExpired).length;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: Stack(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF042F2E),
                        const Color(0xFF0F172A),
                        const Color(0xFF0F172A),
                      ]
                    : [
                        const Color(0xFF064E3B),
                        const Color(0xFF094943),
                        const Color(0xFF0D9488),
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
                          children: [
                            Text(
                              context.tr('my_cards'),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              context.tr('manage_live_works_desc'),
                              style: const TextStyle(
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
                            Padding(
                              padding: const EdgeInsets.all(40),
                              child: Center(
                                child: CircularProgressIndicator(color: primaryDark),
                              ),
                            )
                          else if (_filteredCards.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(30),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppTheme.surface(context),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.border(context)),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.textSecondary(context)),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.tr('no_live_work_cards_found'),
                                    style: TextStyle(color: AppTheme.textSecondary(context), fontWeight: FontWeight.bold),
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
                              context.trParams('showing_cards_count', {
                                'shown': '${_filteredCards.length}',
                                'total': '${_allCards.length}',
                              }),
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
    final primaryDark = AppTheme.primary(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.05),
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
                  children: [
                    Text(
                      context.tr('my_cards'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('create_edit_cards_desc'),
                      style: const TextStyle(
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
              _buildStatPill('${_allCards.length}', context.tr('total')),
              const SizedBox(width: 8),
              _buildStatPill('$activeCount', context.tr('active')),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            context.tr('create_card'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
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
          _buildStatusChip(0, context.tr('all')),
          const SizedBox(width: 8),
          _buildStatusChip(1, context.tr('active')),
          const SizedBox(width: 8),
          _buildStatusChip(2, context.tr('paused')),
          const SizedBox(width: 8),
          _buildStatusChip(3, context.tr('expired')),
        ],
      ),
    );
  }

  Widget _buildStatusChip(int index, String label) {
    final bool isSelected = _selectedStatusTab == index;
    final count = _countByTab(index);
    final primaryDark = AppTheme.primary(context);

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
          color: isSelected ? primaryDark : AppTheme.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryDark : AppTheme.border(context),
          ),
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textPrimary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildWebStyleWorkCard(LiveWorkCardModel card) {
    final primaryDark = AppTheme.primary(context);
    final isDark = AppTheme.isDark(context);
    final coverImage = card.thumbnailUrl ?? (card.images.isNotEmpty ? card.images.first : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
                        card.getTrStatusLabel(context),
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
                    card.getTrFormattedPrice(context),
                    style: TextStyle(
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
                        card.getTrFormattedExpiresIn(context),
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
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryDark),
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
                      card.getTrFormattedTimeAgo(context),
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
                        child: OutlinedButton(
                          onPressed: () => _showCardModal(cardToEdit: card),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF334155)),
                                const SizedBox(width: 3),
                                Text(
                                  context.tr('edit'),
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // 2. Pause / Activate
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: () => _toggleStatus(card),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            side: BorderSide(
                              color: card.isActive ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0),
                            ),
                            backgroundColor: card.isActive ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  card.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                                  size: 13,
                                  color: card.isActive ? const Color(0xFFD97706) : const Color(0xFF166534),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  card.isActive ? context.tr('pause') : context.tr('active'),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: card.isActive ? const Color(0xFFD97706) : const Color(0xFF166534),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // 3. Update / Repost
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: () => _repostOrUpdateCard(card),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            backgroundColor: const Color(0xFFECFDF5),
                            side: const BorderSide(color: Color(0xFFA7F3D0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.arrow_upward_rounded, size: 13, color: Color(0xFF059669)),
                                const SizedBox(width: 3),
                                Text(
                                  card.isExpired ? context.tr('create_card') : context.tr('update'),
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // 4. Delete
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: () => _deleteCard(card),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            backgroundColor: const Color(0xFFFEF2F2),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.delete_outline_rounded, size: 13, color: Color(0xFFDC2626)),
                                const SizedBox(width: 3),
                                Text(
                                  context.tr('delete'),
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                ),
                              ],
                            ),
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

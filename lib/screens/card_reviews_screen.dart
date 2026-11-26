import 'package:flutter/material.dart';
import '../core/app_dialogs.dart';
import '../core/app_language.dart';
import '../core/app_theme.dart';
import '../login_screen.dart';
import '../models/live_work_card_model.dart';
import '../services/auth_service.dart';
import '../services/live_work_service.dart';

class CardReviewsScreen extends StatefulWidget {
  final int cardId;
  final int ownerUserId;
  final String cardTitle;
  final double averageRating;
  final List<CardReviewModel> reviews;

  const CardReviewsScreen({
    super.key,
    required this.cardId,
    required this.ownerUserId,
    required this.cardTitle,
    required this.averageRating,
    required this.reviews,
  });

  @override
  State<CardReviewsScreen> createState() => _CardReviewsScreenState();
}

class _CardReviewsScreenState extends State<CardReviewsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedFilterStar = 0; // 0: All, 5: 5-star, 4: 4-star, etc.
  late List<CardReviewModel> _localReviews;

  @override
  void initState() {
    super.initState();
    _localReviews = List.from(widget.reviews);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  CardReviewModel? get _existingUserReview {
    final currentUser = AuthService.getStoredUser();
    if (currentUser == null) return null;
    try {
      return _localReviews.firstWhere((r) =>
          r.reviewerName.toLowerCase() == currentUser.name.toLowerCase() ||
          (r.reviewerAvatar != null && r.reviewerAvatar == currentUser.avatarUrl));
    } catch (_) {
      return null;
    }
  }

  bool get _hasUserReviewed => _existingUserReview != null;

  List<CardReviewModel> get _filteredReviews {
    return _localReviews.where((r) {
      final matchesSearch = _searchQuery.isEmpty ||
          r.reviewerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.review.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStar = _selectedFilterStar == 0 || r.rating.round() == _selectedFilterStar;

      return matchesSearch && matchesStar;
    }).toList();
  }

  Map<int, int> get _starCounts {
    final counts = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _localReviews) {
      final star = r.rating.round().clamp(1, 5);
      counts[star] = (counts[star] ?? 0) + 1;
    }
    return counts;
  }

  double get _computedAverageRating {
    if (_localReviews.isNotEmpty) {
      final total = _localReviews.fold(0.0, (sum, r) => sum + r.rating);
      return double.parse((total / _localReviews.length).toStringAsFixed(1));
    }
    return widget.averageRating;
  }

  Future<void> _refreshReviews() async {
    if (!mounted) return;
    setState(() {});
  }

  void _showAddOrEditReviewDialog([CardReviewModel? targetReview]) async {
    if (!AuthService.isLoggedIn()) {
      AppDialogs.showToastModal(
        context,
        message: 'Please sign in to add or edit a review.',
        icon: Icons.lock_outline_rounded,
        iconColor: Colors.orange,
        iconBgColor: const Color(0xFFFEF3C7),
      );
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      if (result == true) {
        _refreshReviews();
      }
      return;
    }

    final existing = targetReview ?? _existingUserReview;
    double selectedRating = existing?.rating ?? 5.0;
    final reviewController = TextEditingController(text: existing?.review ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface(dialogContext),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppTheme.border(dialogContext)),
            ),
            title: Text(
              existing != null ? context.tr('edit_review') : context.tr('add_review'),
              style: TextStyle(color: AppTheme.textPrimary(dialogContext)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.tr('rate_your_experience'), style: TextStyle(color: AppTheme.textSecondary(dialogContext))),
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
                  style: TextStyle(color: AppTheme.textPrimary(dialogContext)),
                  decoration: InputDecoration(
                    hintText: context.tr('write_feedback_hint'),
                    hintStyle: TextStyle(color: AppTheme.textSecondary(dialogContext)),
                    filled: true,
                    fillColor: AppTheme.inputFill(dialogContext),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.border(dialogContext)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primary(dialogContext), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.tr('cancel'), style: TextStyle(color: AppTheme.textSecondary(dialogContext))),
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
                            message: 'Please enter a review text.',
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
                          ownerUserId: widget.ownerUserId,
                          cardId: existing?.cardId ?? widget.cardId,
                          cardTypeInt: existing?.cardType ?? 0,
                          rating: selectedRating,
                          review: text,
                        );

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);

                        if (response.success) {
                          final currentUser = AuthService.getStoredUser();
                          final newReviewModel = CardReviewModel(
                            id: existing?.id ?? DateTime.now().millisecondsSinceEpoch,
                            reviewerId: currentUser?.id,
                            rating: selectedRating,
                            review: text,
                            createdAt: 'Just now',
                            reviewerName: currentUser?.name ?? 'You',
                            reviewerAvatar: currentUser?.avatarUrl,
                            cardId: existing?.cardId ?? widget.cardId,
                            cardType: existing?.cardType,
                            cardTitle: existing?.cardTitle ?? widget.cardTitle,
                          );

                          setState(() {
                            _localReviews.removeWhere((r) =>
                                (existing != null && r.id == existing.id) ||
                                (r.cardId != null && existing?.cardId != null && r.cardId == existing?.cardId && r.reviewerName.toLowerCase() == (currentUser?.name ?? '').toLowerCase()));
                            _localReviews.insert(0, newReviewModel);
                          });

                          if (mounted) {
                            AppDialogs.showToastModal(
                              context,
                              message: existing != null
                                  ? 'Review updated successfully!'
                                  : 'Review submitted! Thank you.',
                            );
                          }
                        } else {
                          if (mounted) {
                            AppDialogs.showToastModal(
                              context,
                              message: response.message.isNotEmpty ? response.message : 'Failed to save review.',
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
                    : Text(existing != null ? context.tr('update_review') : context.tr('submit_review'),
                        style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF094943);
    final totalCount = _localReviews.length;
    final filteredList = _filteredReviews;
    final isEditing = _hasUserReviewed;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.appBarBg(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('reviews_ratings'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              widget.cardTitle,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.edit_note_rounded : Icons.rate_review_outlined, color: Colors.white),
            tooltip: isEditing ? 'Edit Review' : 'Add Review',
            onPressed: _showAddOrEditReviewDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshReviews,
        color: primaryDark,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rating Summary Card
            _buildRatingSummaryCard(totalCount),
            const SizedBox(height: 16),

            // Search Bar
            _buildSearchBar(),
            const SizedBox(height: 14),

            // Star Filter Chips
            _buildStarFilterRow(),
            const SizedBox(height: 16),

            // List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${context.tr('reviews')} (${filteredList.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Row(
                  children: [
                    if (_searchQuery.isNotEmpty || _selectedFilterStar > 0) ...[
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                            _selectedFilterStar = 0;
                          });
                        },
                        child: const Text(
                          'Reset',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    GestureDetector(
                      onTap: _showAddOrEditReviewDialog,
                      child: Text(
                        isEditing ? context.tr('edit_review') : '+ ${context.tr('add_review')}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Reviews List
            if (filteredList.isEmpty)
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
                    Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textSecondary(context)),
                    const SizedBox(height: 12),
                    Text(
                      'No reviews match your search.',
                      style: TextStyle(color: AppTheme.textSecondary(context), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  final review = filteredList[index];
                  return _buildReviewCardItem(review);
                },
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildRatingSummaryCard(int totalCount) {
    final primaryDark = AppTheme.primary(context);
    final counts = _starCounts;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          // Left: Big Rating Number & Stars
          Column(
            children: [
              Text(
                _computedAverageRating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: primaryDark,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < _computedAverageRating.round() ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFFFB800),
                    size: 18,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalCount ${context.tr('reviews')}',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
              ),
            ],
          ),
          const SizedBox(width: 20),
          SizedBox(height: 90, child: VerticalDivider(width: 1, color: AppTheme.divider(context))),
          const SizedBox(width: 16),

          // Right: Star Rating Distribution Progress Bars
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final count = counts[star] ?? 0;
                final pct = totalCount > 0 ? count / totalCount : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '$star',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFB800)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFF1F5F9),
                            color: primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 20,
                        child: Text(
                          '$count',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: AppTheme.textSecondary(context), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: AppTheme.textPrimary(context)),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              decoration: InputDecoration(
                hintText: context.tr('search_reviews_hint'),
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
              child: const Icon(Icons.close_rounded, color: Colors.grey, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildStarFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(0, context.tr('all_stars')),
          const SizedBox(width: 8),
          _buildFilterChip(5, '5 ★'),
          const SizedBox(width: 8),
          _buildFilterChip(4, '4 ★'),
          const SizedBox(width: 8),
          _buildFilterChip(3, '3 ★'),
          const SizedBox(width: 8),
          _buildFilterChip(2, '2 ★'),
          const SizedBox(width: 8),
          _buildFilterChip(1, '1 ★'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int star, String label) {
    final isSelected = _selectedFilterStar == star;
    final primaryDark = AppTheme.primary(context);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilterStar = star;
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryDark : AppTheme.surface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? primaryDark : AppTheme.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textPrimary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCardItem(CardReviewModel r) {
    final primaryDark = AppTheme.primary(context);
    final avatar = r.reviewerAvatar;
    final currentUser = AuthService.getStoredUser();
    final bool isMyReview = currentUser != null &&
        (r.reviewerId == currentUser.id ||
         r.reviewerName.toLowerCase() == currentUser.name.toLowerCase() ||
         (r.reviewerAvatar != null && r.reviewerAvatar == currentUser.avatarUrl));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: primaryDark,
                backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                child: avatar == null || avatar.isEmpty
                    ? const Icon(Icons.person, color: Colors.white, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.reviewerName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (sIdx) {
                          return Icon(
                            sIdx < r.rating ? Icons.star_rounded : Icons.star_border_rounded,
                            color: const Color(0xFFFFB800),
                            size: 14,
                          );
                        }),
                        const SizedBox(width: 6),
                        Text(
                          '${r.rating.toStringAsFixed(1)} ★',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isMyReview)
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 18, color: primaryDark),
                  tooltip: 'Edit Review',
                  onPressed: () => _showAddOrEditReviewDialog(r),
                )
              else if (r.createdAt != null)
                Text(
                  r.createdAt!,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                ),
            ],
          ),
          if (r.cardTitle != null && r.cardTitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.subtleBackground(context),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${context.tr('for')}: ${r.cardTitle}',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context), fontWeight: FontWeight.w500),
              ),
            ),
          ],
          if (r.review.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              r.review,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary(context),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

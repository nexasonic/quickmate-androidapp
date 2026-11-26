import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_detail_screen.dart';
import 'core/app_dialogs.dart';
import 'core/app_language.dart';
import 'core/app_theme.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'models/live_work_card_model.dart';
import 'screens/card_reviews_screen.dart';
import 'services/auth_service.dart';
import 'services/live_work_service.dart';
import 'services/presence_service.dart';
import 'user_public_profile_screen.dart';

class CardDetailScreen extends StatefulWidget {
  final LiveWorkCardModel card;
  final String cardType;

  const CardDetailScreen({
    super.key,
    required this.card,
    this.cardType = 'live-work',
  });

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  late LiveWorkCardModel _card;
  int _currentImageIndex = 0;
  bool _isAboutExpanded = true;
  final int _selectedNavIndex = 1; // Default to Discover active tab

  @override
  @override
  void initState() {
    super.initState();
    _card = widget.card;
    PresenceService.locationNotifier.addListener(_onLocationUpdated);
    _fetchFullDetails();
  }

  void _onLocationUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    PresenceService.locationNotifier.removeListener(_onLocationUpdated);
    super.dispose();
  }

  Future<void> _fetchFullDetails() async {
    final updatedCard = await LiveWorkService.fetchLiveWorkDetails(_card.id, cardType: widget.cardType);

    if (!mounted) return;

    if (updatedCard != null) {
      setState(() {
        _card = updatedCard;
      });
    }
  }

  CardReviewModel? get _existingUserReview {
    final currentUser = AuthService.getStoredUser();
    if (currentUser == null) return null;
    try {
      return _card.reviews.firstWhere((r) =>
          r.reviewerName.toLowerCase() == currentUser.name.toLowerCase() ||
          (r.reviewerAvatar != null && r.reviewerAvatar == currentUser.avatarUrl));
    } catch (_) {
      return null;
    }
  }

  bool get _hasUserReviewed => _existingUserReview != null;

  void _showAddReviewDialog() async {
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
        _fetchFullDetails();
      }
      return;
    }

    final existingReview = _existingUserReview;
    double selectedRating = existingReview?.rating ?? 5.0;
    final reviewController = TextEditingController(text: existingReview?.review ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(existingReview != null ? context.tr('edit_review') : context.tr('add_review')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.tr('rate_your_experience')),
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
                    hintText: context.tr('write_feedback_hint'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.tr('cancel')),
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

                        final ownerId = _card.user?.id;
                        if (ownerId == null) {
                          AppDialogs.showToastModal(
                            dialogContext,
                            message: 'Card owner information unavailable.',
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
                          ownerUserId: ownerId,
                          cardId: _card.id,
                          cardTypeInt: _resolveCardTypeInt(widget.cardType),
                          rating: selectedRating,
                          review: text,
                        );

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);

                        if (response.success) {
                          final currentUser = AuthService.getStoredUser();
                          final newReviewModel = CardReviewModel(
                            id: existingReview?.id ?? DateTime.now().millisecondsSinceEpoch,
                            rating: selectedRating,
                            review: text,
                            createdAt: 'Just now',
                            reviewerName: currentUser?.name ?? 'You',
                            reviewerAvatar: currentUser?.avatarUrl,
                          );

                          setState(() {
                            _card.reviews.removeWhere((r) =>
                                r.reviewerName.toLowerCase() == (currentUser?.name ?? '').toLowerCase() ||
                                (existingReview != null && r.id == existingReview.id));
                            _card.reviews.insert(0, newReviewModel);
                          });

                          if (mounted) {
                            AppDialogs.showToastModal(
                              context,
                              message: existingReview != null
                                  ? 'Review updated successfully!'
                                  : 'Review submitted! Thank you.',
                            );
                          }
                          _fetchFullDetails();
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
                    : Text(existingReview != null ? context.tr('update_review') : context.tr('submit_review'),
                        style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  int _resolveCardTypeInt(String type) {
    switch (type.replaceAll('_', '-').toLowerCase()) {
      case 'service':
        return 2;
      case 'job':
        return 3;
      case 'freelancer':
        return 4;
      case 'business':
        return 5;
      case 'live-work':
      case 'livework':
      default:
        return 1;
    }
  }

  Future<void> _toggleFavorite() async {
    if (!AuthService.isLoggedIn()) {
      AppDialogs.showLoginRequiredModal(
        context,
        message: 'Please sign in to save cards to favorites.',
      );
      return;
    }

    final bool newFavoriteState = !_card.isFavorite;

    setState(() {
      _card.isFavorite = newFavoriteState;
    });

    final int cardTypeInt = _resolveCardTypeInt(widget.cardType);
    final response = await LiveWorkService.toggleSavedCard(_card.id, cardType: cardTypeInt);

    if (!mounted) return;

    if (response.success) {
      AppDialogs.showSuccessModal(
        context,
        title: newFavoriteState ? 'Saved to Favorites' : 'Removed from Favorites',
        message: newFavoriteState
            ? 'This card has been added to your Saved Cards.'
            : 'This card was removed from your Saved Cards.',
        icon: newFavoriteState ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        iconColor: newFavoriteState ? Colors.redAccent : Colors.grey,
      );
    } else {
      setState(() {
        _card.isFavorite = !newFavoriteState;
      });
      AppDialogs.showSuccessModal(
        context,
        title: 'Error',
        message: response.message.isNotEmpty ? response.message : 'Failed to update favorites.',
        icon: Icons.error_outline_rounded,
        iconColor: Colors.redAccent,
      );
    }
  }

  Future<void> _openDirections() async {
    final String query;
    if (_card.latitude != null && _card.longitude != null) {
      query = '${_card.latitude},${_card.longitude}';
    } else {
      query = Uri.encodeComponent(_card.location ?? _card.user?.location ?? PresenceService.currentPlaceName);
    }

    final Uri googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(googleMapsUrl, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (!mounted) return;
      AppDialogs.showToastModal(
        context,
        message: 'Opening directions to ${_card.location ?? _card.user?.location ?? PresenceService.currentPlaceName}...',
      );
    }
  }

  void _handleNavTap(int index) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(initialIndex: index),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryDark = AppTheme.primary(context);
    final images = _card.images.isNotEmpty
        ? _card.images
        : (_card.thumbnailUrl != null ? [_card.thumbnailUrl!] : <String>[]);

    final owner = _card.user;

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
              context.tr('view_card'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              context.tr('live_work_card_details'),
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _card.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _card.isFavorite ? Colors.redAccent : Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: () {
              AppDialogs.showToastModal(
                context,
                message: 'Link copied to clipboard!',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchFullDetails,
        color: primaryDark,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image Card Container with Category & Title Overlay
            _buildHeroBanner(images),

            const SizedBox(height: 16),

            // Card Title & Status Badge Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _card.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _card.isActive
                        ? (AppTheme.isDark(context) ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                        : (AppTheme.isDark(context) ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _card.isActive
                              ? (AppTheme.isDark(context) ? const Color(0xFF4ADE80) : const Color(0xFF166534))
                              : (AppTheme.isDark(context) ? const Color(0xFFFDE68A) : const Color(0xFF92400E)),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _card.statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _card.isActive
                              ? (AppTheme.isDark(context) ? const Color(0xFF4ADE80) : const Color(0xFF166534))
                              : (AppTheme.isDark(context) ? const Color(0xFFFDE68A) : const Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Card Updated Time Pill Tag (Designed Badge Top of Review Count)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.isDark(context) ? const Color(0xFF134E4A) : const Color(0xFFE6F4F1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.isDark(context) ? const Color(0xFF115E59) : const Color(0xFFC7F3E2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 12,
                    color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${context.tr('updated')} ${_card.getTrFormattedTimeAgo(context)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle Row: Calculated Rating & Location Distance
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFB800)),
                const SizedBox(width: 4),
                Text(
                  '${_card.rating.toStringAsFixed(1)} (${_card.reviewsCount} ${context.tr('reviews')})',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary(context)),
                ),
                SizedBox(height: 12, child: VerticalDivider(width: 16, color: AppTheme.divider(context))),
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : const Color(0xFF094943),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${_card.location ?? _card.user?.location ?? PresenceService.currentPlaceName} • ${_card.getFormattedDistance(PresenceService.currentLatitude, PresenceService.currentLongitude)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : const Color(0xFF094943),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Live User Location "Where User Is" Card Box
            _buildUserWhereIsBox(),

            const SizedBox(height: 16),

            const SizedBox(height: 16),

            // Price & Service Type Box
            _buildPriceAndTypeBox(),

            const SizedBox(height: 16),

            // Add Review & Save to Favorites Row
            _buildReviewAndFavoriteRow(),

            const SizedBox(height: 16),

            // About This Work Collapsible Section
            _buildAboutSection(),

            const SizedBox(height: 16),

            // Service Provider Card
            if (owner != null) _buildProviderCard(context, owner),

            const SizedBox(height: 20),

            // Work Gallery Section
            _buildWorkGallerySection(images),

            const SizedBox(height: 20),

            // Card Reviews Section
            _buildReviewsSection(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    ),

      // Integrated Bottom Bar (Actions + Navigation Panel)
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sticky Action Bar (Chat Now & Get Directions)
          _buildChatAndDirectionsBar(context, owner),

          // Bottom Navigation Panel
          _buildBottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(List<String> images) {
    const primaryDark = Color(0xFF094943);

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: images.isNotEmpty
                ? PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (idx) {
                      setState(() {
                        _currentImageIndex = idx;
                      });
                    },
                    itemBuilder: (context, idx) {
                      return Image.network(
                        images[idx],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: primaryDark,
                          child: const Icon(Icons.work_outline, color: Colors.white, size: 60),
                        ),
                      );
                    },
                  )
                : Container(
                    color: primaryDark,
                    child: const Center(
                      child: Icon(Icons.work_outline, color: Colors.white, size: 60),
                    ),
                  ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car_rounded, color: primaryDark, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _card.category?.name ?? 'Driving',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (_card.user?.isOnline ?? _card.isActive)
                    ? const Color(0xFF10B981)
                    : const Color(0xFF334155).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    (_card.user?.isOnline ?? _card.isActive) ? 'Online' : _card.formattedLastSeen,
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
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _card.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFFFFE066),
                    height: 1.1,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(1, 2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (images.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (idx) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentImageIndex == idx ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentImageIndex == idx ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceAndTypeBox() {
    final primaryDark = AppTheme.primary(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.isDark(context) ? const Color(0xFF134E4A) : const Color(0xFFD0F2E5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('price_rate'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary(context),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _card.getTrFormattedPrice(context),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(height: 30, child: VerticalDivider(width: 20, color: AppTheme.divider(context))),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.isDark(context) ? const Color(0xFF075985) : const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.calendar_today_outlined,
              color: AppTheme.isDark(context) ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('service_type'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _card.category?.name ?? 'Driving',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
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

  Widget _buildChatAndDirectionsBar(BuildContext context, dynamic owner) {
    final primaryDark = AppTheme.primary(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(top: BorderSide(color: AppTheme.border(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (!AuthService.isLoggedIn()) {
                    AppDialogs.showToastModal(
                      context,
                      message: 'Please sign in to start a chat.',
                      icon: Icons.lock_outline_rounded,
                      iconColor: Colors.orange,
                      iconBgColor: const Color(0xFFFEF3C7),
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                    return;
                  }

                  if (owner == null) {
                    AppDialogs.showToastModal(
                      context,
                      message: 'Owner details unavailable.',
                      icon: Icons.warning_amber_rounded,
                      iconColor: Colors.orange,
                      iconBgColor: const Color(0xFFFEF3C7),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatDetailScreen(
                        targetUserId: owner.id,
                        card: _card,
                        chatData: {
                          'id': owner.id.toString(),
                          'name': owner.name,
                          'subtitle': _card.title,
                          'avatar': owner.avatarUrl ?? '',
                          'isOnline': owner.isOnline,
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
                label: Text(
                  context.tr('chat_now'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDark,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _openDirections,
                icon: Icon(Icons.location_on_outlined, color: primaryDark, size: 18),
                label: Text(
                  context.tr('get_directions'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryDark),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryDark, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isAboutExpanded = !_isAboutExpanded;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.isDark(context) ? const Color(0xFF075985) : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      color: AppTheme.isDark(context) ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('about_this_work'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        Text(
                          _card.description ?? 'Available in work',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isAboutExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary(context),
                  ),
                ],
              ),
            ),
          ),
          if (_isAboutExpanded && _card.description != null) ...[
            Divider(height: 1, color: AppTheme.divider(context)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _card.description!,
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary(context), height: 1.4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserWhereIsBox() {
    final primaryDark = AppTheme.primary(context);
    final userLocation = _card.location ?? _card.user?.location ?? PresenceService.currentPlaceName;
    final dist = _card.getFormattedDistance(PresenceService.currentLatitude, PresenceService.currentLongitude);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryDark,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.tr('user_whereabouts'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Live 30s Sync',
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$userLocation • $dist',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(BuildContext context, dynamic owner) {
    final primaryDark = AppTheme.primary(context);
    final double userRating = (owner != null && owner.rating != null && owner.rating > 0)
        ? (owner.rating as num).toDouble()
        : (_card.rating > 0 ? _card.rating : 5.0);
    final int userReviewsCount = (owner != null && owner.reviewsCount != null && owner.reviewsCount > 0)
        ? (owner.reviewsCount as num).toInt()
        : (_card.reviewsCount > 0 ? _card.reviewsCount : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('service_provider'),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSecondary(context)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: primaryDark,
                backgroundImage: owner.avatarUrl != null && owner.avatarUrl!.isNotEmpty
                    ? NetworkImage(owner.avatarUrl!)
                    : null,
                child: owner.avatarUrl == null || owner.avatarUrl!.isEmpty
                    ? const Icon(Icons.person, color: Colors.white, size: 24)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            owner.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (owner.isVerified == true) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFB800)),
                        const SizedBox(width: 3),
                        Text(
                          '${userRating.toStringAsFixed(1)} ($userReviewsCount ${userReviewsCount == 1 ? 'review' : 'reviews'})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.storefront_outlined, size: 12, color: AppTheme.textSecondary(context)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            owner.accountType != null ? owner.accountType!.toUpperCase() : 'MEMBER',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserPublicProfileScreen(user: owner),
                    ),
                  );
                },
                icon: Icon(
                  Icons.person_outline_rounded,
                  color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
                  size: 15,
                ),
                label: Text(
                  context.tr('view_profile'),
                  style: TextStyle(
                    color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.isDark(context) ? const Color(0xFF334155) : Colors.white,
                  elevation: 0,
                  side: BorderSide(
                    color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
        ),
      ],
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
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white54,
                            size: 80,
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

  Widget _buildWorkGallerySection(List<String> images) {
    final primaryDark = AppTheme.primary(context);

    final displayImages = images.isNotEmpty
        ? images
        : [
            'https://images.unsplash.com/photo-1581578731548-c64695cc6958?q=80&w=600',
            'https://images.unsplash.com/photo-1562259949-e8e7689d7828?q=80&w=600',
            'https://images.unsplash.com/photo-1538688525198-9b88f6f53126?q=80&w=600',
            'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?q=80&w=600',
            'https://images.unsplash.com/photo-1607613009820-a29f7bb81c04?q=80&w=600',
            'https://images.unsplash.com/photo-1584820927498-cfe5211fd8bf?q=80&w=600',
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.collections_outlined, color: primaryDark, size: 20),
                const SizedBox(width: 6),
                Text(
                  '${context.tr('work_gallery')} (${displayImages.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => _showFullImageViewer(displayImages, 0),
              child: Row(
                children: [
                  Text(
                    context.tr('view_all'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: displayImages.length > 5 ? 5 : displayImages.length,
            itemBuilder: (context, idx) {
              final bool isLastItem = idx == 4 && displayImages.length > 5;
              final extraCount = displayImages.length - 4;

              return GestureDetector(
                onTap: () => _showFullImageViewer(displayImages, idx),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 90,
                  height: 80,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          displayImages[idx],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[300]),
                        ),
                        if (isLastItem)
                          Container(
                            color: Colors.black.withValues(alpha: 0.6),
                            child: Center(
                              child: Text(
                                '+$extraCount\nMore',
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
    );
  }

  Widget _buildReviewAndFavoriteRow() {
    final primaryDark = AppTheme.primary(context);
    final isEditing = _hasUserReviewed;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _showAddReviewDialog,
              icon: Icon(
                isEditing ? Icons.edit_note_rounded : Icons.edit_outlined,
                color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
                size: 18,
              ),
              label: Text(
                isEditing ? context.tr('edit_review') : context.tr('add_review'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _toggleFavorite,
              icon: Icon(
                _card.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                _card.isFavorite ? context.tr('saved') : context.tr('save_to_favorites'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _card.isFavorite ? const Color(0xFFEF4444) : primaryDark,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    final primaryDark = AppTheme.primary(context);
    final reviews = _card.reviews;
    final displayReviews = reviews.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 22),
                const SizedBox(width: 4),
                Text(
                  '${context.tr('card_reviews')} (${_card.reviewsCount > reviews.length ? _card.reviewsCount : reviews.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
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
                        cardId: _card.id,
                        ownerUserId: _card.user?.id ?? 0,
                        cardTitle: _card.title,
                        averageRating: _card.rating,
                        reviews: _card.reviews,
                      ),
                    ),
                  );
                  _fetchFullDetails();
                },
                child: Row(
                  children: [
                    Text(
                      context.tr('view_all'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (reviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Column(
              children: [
                Icon(Icons.rate_review_outlined, color: AppTheme.textSecondary(context), size: 36),
                const SizedBox(height: 8),
                Text(
                  'No reviews yet for this card.',
                  style: TextStyle(color: AppTheme.textSecondary(context), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Be the first to share your experience!',
                  style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _showAddReviewDialog,
                  icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 16),
                  label: const Text('Add Review for Card', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: displayReviews.map((r) {
              final avatar = r.reviewerAvatar;
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(18),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  ...List.generate(5, (sIdx) {
                                    return Icon(
                                      sIdx < r.rating ? Icons.star_rounded : Icons.star_border_rounded,
                                      color: const Color(0xFFFFB800),
                                      size: 13,
                                    );
                                  }),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${r.rating.toStringAsFixed(1)} ★',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (r.createdAt != null && r.createdAt!.isNotEmpty)
                          Text(
                            r.createdAt!,
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                          ),
                      ],
                    ),
                    if (r.review.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        r.review,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary(context),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(top: BorderSide(color: AppTheme.border(context), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildNavItem(0, Icons.home_rounded, context.tr('home'))),
              Expanded(child: _buildNavItem(1, Icons.explore_rounded, context.tr('discover'), filledIcon: Icons.explore)),
              Expanded(child: _buildNavItem(2, Icons.grid_view_outlined, context.tr('my_cards'), filledIcon: Icons.grid_view_rounded)),
              Expanded(child: _buildNavItem(3, Icons.map_outlined, context.tr('map'), filledIcon: Icons.map_rounded)),
              Expanded(child: _buildNavItem(4, Icons.person_outline_rounded, context.tr('profile'), filledIcon: Icons.person_rounded)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {IconData? filledIcon}) {
    final bool isActive = _selectedNavIndex == index;
    final activeColor = AppTheme.primary(context);
    final inactiveColor = AppTheme.textSecondary(context);

    return InkWell(
      onTap: () => _handleNavTap(index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive && filledIcon != null)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  filledIcon,
                  size: 18,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                icon,
                size: 22,
                color: isActive ? activeColor : inactiveColor,
              ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? activeColor : inactiveColor,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

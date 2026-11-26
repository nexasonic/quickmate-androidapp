import 'package:flutter/material.dart';
import '../card_detail_screen.dart';
import '../chat_detail_screen.dart';
import '../core/api_config.dart';
import '../core/api_service.dart';
import '../core/app_dialogs.dart';
import '../core/app_language.dart';
import '../core/app_theme.dart';
import '../login_screen.dart';
import '../models/live_work_card_model.dart';
import '../services/auth_service.dart';
import '../services/live_work_service.dart';

class SavedCardsScreen extends StatefulWidget {
  const SavedCardsScreen({super.key});

  @override
  State<SavedCardsScreen> createState() => _SavedCardsScreenState();
}

class _SavedCardsScreenState extends State<SavedCardsScreen> {
  bool _isLoading = true;
  List<LiveWorkCardModel> _savedCards = [];

  @override
  void initState() {
    super.initState();
    _fetchSavedCards();
  }

  Future<void> _fetchSavedCards() async {
    setState(() {
      _isLoading = true;
    });

    final response = await ApiService.get(ApiConfig.savedCards);

    if (!mounted) return;

    if (response.success && response.data != null) {
      final List list = response.data is List ? response.data : (response.data['data'] ?? []);
      final parsedCards = list
          .map((item) => LiveWorkCardModel.fromJson(item as Map<String, dynamic>))
          .where((card) => card.isActive && !card.isExpired && !card.isPaused)
          .toList();

      setState(() {
        _savedCards = parsedCards;
        _isLoading = false;
      });
    } else {
      setState(() {
        _savedCards = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _removeBookmark(LiveWorkCardModel card) async {
    final response = await LiveWorkService.toggleSavedCard(card.id);
    if (!mounted) return;

    if (response.success) {
      AppDialogs.showToastModal(
        context,
        message: 'Removed "${card.title}" from saved cards.',
      );
      _fetchSavedCards();
    } else {
      AppDialogs.showToastModal(
        context,
        message: response.message.isNotEmpty ? response.message : 'Unable to remove card.',
        icon: Icons.error_outline_rounded,
        iconColor: Colors.redAccent,
      );
    }
  }

  Widget _buildGuestPromptScreen() {
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
        title: Text(context.tr('saved_cards'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Center(
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
                'Sign In Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context)),
              ),
              const SizedBox(height: 8),
              Text(
                'Please sign in to view and access your bookmarked live work cards.',
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
                      _fetchSavedCards();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('saved_cards'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '${_savedCards.length} ${context.tr('saved_cards')}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchSavedCards,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchSavedCards,
        color: primaryDark,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: primaryDark))
            : _savedCards.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _savedCards.length,
                    itemBuilder: (context, index) {
                      final card = _savedCards[index];
                      return _buildInformativeSavedCardItem(card);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final primaryDark = AppTheme.primary(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.isDark(context) ? const Color(0xFF134E4A) : const Color(0xFFE6F4F1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bookmark_border_rounded, size: 54, color: primaryDark),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('no_saved_cards'),
              style: TextStyle(color: AppTheme.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              'Bookmark live work listings you find interesting to easily view and contact providers anytime!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformativeSavedCardItem(LiveWorkCardModel card) {
    final primaryDark = AppTheme.primary(context);
    final isDark = AppTheme.isDark(context);
    final coverImage = card.thumbnailUrl ?? (card.images.isNotEmpty ? card.images.first : null);
    final owner = card.user;
    final String providerName = owner?.name ?? 'Service Provider';
    final String? providerAvatar = owner?.avatarUrl;
    final bool isProviderVerified = owner?.isVerified == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Image Thumbnail Container with Overlays
              SizedBox(
                width: 110,
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: coverImage != null && coverImage.isNotEmpty
                          ? Image.network(
                              coverImage,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: AppTheme.subtleBackground(context),
                                child: Icon(Icons.work_outline_rounded, color: AppTheme.textSecondary(context), size: 30),
                              ),
                            )
                          : Container(
                              color: AppTheme.subtleBackground(context),
                              child: Icon(Icons.work_outline_rounded, color: AppTheme.textSecondary(context), size: 30),
                            ),
                    ),

                    // Expiry Pill Top Left
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          card.formattedExpiresIn.replaceAll('Expires in ', ''),
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),

                    // Category Pill Bottom Left
                    if (card.category != null)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryDark.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            card.category!.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Right Content Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Provider Avatar & Name + Bookmark Remove Button Row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: primaryDark,
                          backgroundImage: providerAvatar != null && providerAvatar.isNotEmpty
                              ? NetworkImage(providerAvatar)
                              : null,
                          child: providerAvatar == null || providerAvatar.isEmpty
                              ? const Icon(Icons.person, color: Colors.white, size: 12)
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  providerName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isProviderVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 13),
                              ],
                            ],
                          ),
                        ),
                        // Remove Bookmark Button
                        GestureDetector(
                          onTap: () => _removeBookmark(card),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.bookmark_remove_rounded,
                              color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                              size: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Task Title
                    Text(
                      card.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Price Pill & Status Badge Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF134E4A) : const Color(0xFFE6F4F1),
                            borderRadius: BorderRadius.circular(8),
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
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: card.isExpired
                                ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2))
                                : (card.isPaused
                                    ? (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7))
                                    : (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            card.statusLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: card.isExpired
                                  ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                                  : (card.isPaused
                                      ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                      : (isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534))),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Location & Rating Row
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textSecondary(context)),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            card.getTrFormattedDistance(context),
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFB800)),
                        const SizedBox(width: 2),
                        Text(
                          card.rating > 0 ? card.rating.toStringAsFixed(1) : 'New',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: AppTheme.divider(context)),
          const SizedBox(height: 10),

          // Action Buttons Row (View Card & Chat Provider)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CardDetailScreen(card: card)),
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 15, color: Colors.white),
                    label: Text(
                      context.tr('view_card'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryDark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (!AuthService.isLoggedIn()) {
                        AppDialogs.showToastModal(
                          context,
                          message: 'Please sign in to start a chat with this provider.',
                          icon: Icons.lock_outline_rounded,
                          iconColor: Colors.orange,
                        );
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                        if (result == true) {
                          _fetchSavedCards();
                        }
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailScreen(
                            chatData: {
                              'name': providerName,
                              'avatarUrl': providerAvatar,
                            },
                            targetUserId: owner?.id,
                            card: card,
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.chat_bubble_outline_rounded, size: 15, color: primaryDark),
                    label: Text(
                      context.tr('chat_now'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryDark),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryDark, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
}

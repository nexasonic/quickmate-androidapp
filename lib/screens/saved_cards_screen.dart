import 'package:flutter/material.dart';
import '../card_detail_screen.dart';
import '../chat_detail_screen.dart';
import '../core/api_config.dart';
import '../core/api_service.dart';
import '../core/app_dialogs.dart';
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
      final parsedCards = list.map((item) => LiveWorkCardModel.fromJson(item as Map<String, dynamic>)).toList();

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
        iconBgColor: const Color(0xFFFEE2E2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF094943);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: primaryDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saved Cards',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '${_savedCards.length} bookmarked live work listing${_savedCards.length == 1 ? '' : 's'}',
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
            ? const Center(child: CircularProgressIndicator(color: primaryDark))
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFE6F4F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bookmark_border_rounded, size: 54, color: Color(0xFF094943)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No saved cards yet',
              style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 6),
            const Text(
              'Bookmark live work listings you find interesting to easily view and contact providers anytime!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformativeSavedCardItem(LiveWorkCardModel card) {
    const primaryDark = Color(0xFF094943);
    final coverImage = card.thumbnailUrl ?? (card.images.isNotEmpty ? card.images.first : null);
    final owner = card.user;
    final String providerName = owner?.name ?? 'Service Provider';
    final String? providerAvatar = owner?.avatarUrl;
    final bool isProviderVerified = owner?.isVerified == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                                color: const Color(0xFFE2E8F0),
                                child: const Icon(Icons.work_outline_rounded, color: Colors.grey, size: 30),
                              ),
                            )
                          : Container(
                              color: const Color(0xFFE2E8F0),
                              child: const Icon(Icons.work_outline_rounded, color: Colors.grey, size: 30),
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
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
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
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEE2E2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bookmark_remove_rounded, color: Color(0xFFDC2626), size: 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Task Title
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
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
                            color: const Color(0xFFE6F4F1),
                            borderRadius: BorderRadius.circular(8),
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
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: card.isExpired
                                ? const Color(0xFFFEE2E2)
                                : (card.isPaused ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            card.statusLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: card.isExpired
                                  ? const Color(0xFFDC2626)
                                  : (card.isPaused ? const Color(0xFFD97706) : const Color(0xFF166534)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Location & Rating Row
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            card.formattedDistance,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFB800)),
                        const SizedBox(width: 2),
                        Text(
                          card.rating > 0 ? card.rating.toStringAsFixed(1) : 'New',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
                    label: const Text(
                      'View Card',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
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
                    onPressed: () {
                      if (!AuthService.isLoggedIn()) {
                        AppDialogs.showToastModal(
                          context,
                          message: 'Please sign in to start a chat with this provider.',
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

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailScreen(
                            chatData: {
                              'name': providerName,
                              'avatarUrl': providerAvatar,
                            },
                            targetUserId: owner?.id,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: primaryDark),
                    label: const Text(
                      'Chat Provider',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryDark),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: primaryDark, width: 1.2),
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

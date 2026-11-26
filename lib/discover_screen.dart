import 'dart:async';
import 'package:flutter/material.dart';
import 'card_detail_screen.dart';
import 'chat_list_screen.dart';
import 'core/app_dialogs.dart';
import 'models/category_model.dart';
import 'models/live_work_card_model.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/live_work_service.dart';
import 'services/presence_service.dart';

class DiscoverScreen extends StatefulWidget {
  final CategoryModel? initialCategory;
  final String? initialSearch;

  const DiscoverScreen({
    super.key,
    this.initialCategory,
    this.initialSearch,
  });

  @override
  State<DiscoverScreen> createState() => DiscoverScreenState();
}

class DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  Future<void> refresh() => _fetchCards();

  CategoryModel? _selectedCategory;
  String _selectedSort = 'Nearest';
  bool _showSortBottomSheet = false;
  bool _isLoading = true;

  List<CategoryModel> _categories = [];
  List<LiveWorkCardModel> _cards = [];
  UserModel? _currentUser;

  final List<String> _sortOptions = [
    'Nearest',
    'Top Rated',
    'Price: Low to High',
    'Price: High to Low',
  ];

  @override
  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _searchController.text = widget.initialSearch!;
    }
    _currentUser = AuthService.getStoredUser();
    PresenceService.locationNotifier.addListener(_onLocationUpdated);
    _loadInitialData();
  }

  void _onLocationUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(DiscoverScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool shouldFetch = false;

    if (widget.initialCategory != oldWidget.initialCategory) {
      _selectedCategory = widget.initialCategory;
      shouldFetch = true;
    }

    if (widget.initialSearch != oldWidget.initialSearch) {
      final newSearch = widget.initialSearch ?? '';
      if (_searchController.text != newSearch) {
        _searchController.text = newSearch;
        _searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: _searchController.text.length),
        );
        shouldFetch = true;
      }
    }

    if (shouldFetch) {
      _fetchCards();
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        _fetchCards();
      }
    });
  }

  @override
  void dispose() {
    PresenceService.locationNotifier.removeListener(_onLocationUpdated);
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final fetchedCategories = await LiveWorkService.fetchCategories();
    if (!mounted) return;

    setState(() {
      _categories = fetchedCategories;
    });

    await _fetchCards();
  }

  Future<void> _fetchCards() async {
    setState(() {
      _isLoading = true;
    });

    String? backendSort;
    if (_selectedSort == 'Nearest') {
      backendSort = 'nearest';
    } else if (_selectedSort == 'Top Rated') {
      backendSort = 'rating';
    } else if (_selectedSort == 'Price: Low to High') {
      backendSort = 'price_low';
    } else if (_selectedSort == 'Price: High to Low') {
      backendSort = 'price_high';
    }

    final fetchedCards = await LiveWorkService.fetchLiveWorkCards(
      search: _searchController.text,
      categoryId: _selectedCategory?.id,
      sort: backendSort,
      lat: PresenceService.currentLatitude,
      lng: PresenceService.currentLongitude,
    );

    double getCardDistance(LiveWorkCardModel card) {
      if (card.distanceKm != null && card.distanceKm! > 0) {
        return card.distanceKm!;
      }
      final userLat = PresenceService.currentLatitude;
      final userLng = PresenceService.currentLongitude;
      if (card.latitude != null && card.longitude != null) {
        final calc = calculateDistanceKm(
          lat1: userLat,
          lon1: userLng,
          lat2: card.latitude,
          lon2: card.longitude,
        );
        if (calc != null) return calc;
      }
      return 999999.0;
    }

    fetchedCards.sort((a, b) {
      if (_selectedSort == 'Nearest') {
        final distA = getCardDistance(a);
        final distB = getCardDistance(b);
        final cmp = distA.compareTo(distB);
        if (cmp != 0) return cmp;
        return b.rating.compareTo(a.rating);
      } else if (_selectedSort == 'Top Rated') {
        final cmp = b.rating.compareTo(a.rating);
        if (cmp != 0) return cmp;
        final distA = getCardDistance(a);
        final distB = getCardDistance(b);
        return distA.compareTo(distB);
      } else if (_selectedSort == 'Price: Low to High') {
        final priceA = (a.price != null && a.price! > 0) ? a.price! : double.infinity;
        final priceB = (b.price != null && b.price! > 0) ? b.price! : double.infinity;
        final cmp = priceA.compareTo(priceB);
        if (cmp != 0) return cmp;
        final distA = getCardDistance(a);
        final distB = getCardDistance(b);
        return distA.compareTo(distB);
      } else if (_selectedSort == 'Price: High to Low') {
        final priceA = (a.price != null && a.price! > 0) ? a.price! : -1.0;
        final priceB = (b.price != null && b.price! > 0) ? b.price! : -1.0;
        final cmp = priceB.compareTo(priceA);
        if (cmp != 0) return cmp;
        final distA = getCardDistance(a);
        final distB = getCardDistance(b);
        return distA.compareTo(distB);
      }
      return 0;
    });

    if (!mounted) return;

    setState(() {
      _cards = fetchedCards;
      _isLoading = false;
    });
  }

  Future<void> _toggleBookmark(LiveWorkCardModel card) async {
    if (!AuthService.isLoggedIn()) {
      AppDialogs.showLoginRequiredModal(
        context,
        message: 'Please sign in to save cards to favorites.',
        onLoginSuccess: _fetchCards,
      );
      return;
    }

    final bool newFavoriteState = !card.isFavorite;

    setState(() {
      card.isFavorite = newFavoriteState;
    });

    final response = await LiveWorkService.toggleSavedCard(card.id);

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
        card.isFavorite = !newFavoriteState;
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

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF094943);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchCards,
              color: primaryDark,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(),
                    const SizedBox(height: 20),

                    // Search Bar
                    _buildSearchBar(),
                    const SizedBox(height: 16),

                    // Compact Scrollable Categories Row
                    _buildCategoriesScrollRow(),
                    const SizedBox(height: 14),

                    // Sort Filter Pill Row
                    _buildSortRow(),
                    const SizedBox(height: 20),

                    // Title Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedCategory != null
                              ? '${_selectedCategory!.name} Live Works'
                              : 'Recommended Live Works',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (_selectedCategory != null)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCategory = null;
                              });
                              _fetchCards();
                            },
                            child: const Text(
                              'Clear Filter',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Grid or Empty State
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(color: primaryDark),
                        ),
                      )
                    else if (_cards.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.work_off_outlined, size: 50, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'No Live Work cards match your criteria.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _cards.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.70,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemBuilder: (context, index) {
                          final item = _cards[index];
                          return GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CardDetailScreen(
                                    card: item,
                                    cardType: item.category?.type ?? 'live-work',
                                  ),
                                ),
                              );
                              _fetchCards();
                            },
                            child: _buildServiceCard(item),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Overlay when bottom sheet open
          if (_showSortBottomSheet)
            GestureDetector(
              onTap: () {
                setState(() {
                  _showSortBottomSheet = false;
                });
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ),

          if (_showSortBottomSheet)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildSortBottomSheet(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    const primaryDark = Color(0xFF094943);
    final avatarUrl = _currentUser?.avatarUrl;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Discover',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: primaryDark,
                height: 1.1,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Find active live work cards near you',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatListScreen()),
                );
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: primaryDark,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF334155),
                    size: 20,
                  ),
                  Positioned(
                    top: 8,
                    right: 9,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5252),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFA0A0),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: primaryDark,
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white, size: 18)
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: Color(0xFF94A3B8),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) {
                _debounceTimer?.cancel();
                _fetchCards();
              },
              onChanged: (val) {
                _onSearchChanged(val);
              },
              decoration: const InputDecoration(
                hintText: 'Search Live Work cards...',
                hintStyle: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _debounceTimer?.cancel();
                _searchController.clear();
                _fetchCards();
              },
              child: const Icon(Icons.close, color: Colors.grey, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoriesScrollRow() {
    const primaryDark = Color(0xFF094943);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categories',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // "All" Category Pill
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = null;
                  });
                  _fetchCards();
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _selectedCategory == null ? primaryDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedCategory == null ? primaryDark : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    'All',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _selectedCategory == null ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ),
              ),

              // Category List Pills
              ..._categories.map((cat) {
                final bool isSelected = _selectedCategory?.id == cat.id;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = isSelected ? null : cat;
                    });
                    _fetchCards();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? primaryDark : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      cat.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSortRow() {
    return Row(
      children: [
        _buildFilterPill(
          icon: Icons.swap_vert_rounded,
          label: 'Sort: $_selectedSort',
          hasDropdown: true,
          iconColor: const Color(0xFF094943),
          onTap: () {
            setState(() {
              _showSortBottomSheet = !_showSortBottomSheet;
            });
          },
        ),
      ],
    );
  }

  Widget _buildFilterPill({
    required IconData icon,
    required String label,
    required bool hasDropdown,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            if (hasDropdown) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: Color(0xFF64748B),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(LiveWorkCardModel item) {
    const primaryDark = Color(0xFF094943);
    final image = item.thumbnailUrl ?? (item.images.isNotEmpty ? item.images.first : null);
    final isOnline = item.user?.isOnline ?? item.isActive;
    final userName = item.user?.name ?? item.title;
    final distStr = item.getFormattedDistance(PresenceService.currentLatitude, PresenceService.currentLongitude);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Image with Badges
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: image != null && image.isNotEmpty
                    ? Image.network(
                        image,
                        height: 105,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 105,
                          color: Colors.grey[200],
                          child: const Icon(Icons.work_outline, color: Colors.grey),
                        ),
                      )
                    : Container(
                        height: 105,
                        color: Colors.grey[200],
                        child: const Icon(Icons.work_outline, color: Colors.grey),
                      ),
              ),

              // Top Left Online / Offline Tag
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFF10B981) : const Color(0xFF334155).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
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
                      const SizedBox(width: 4),
                      Text(
                        isOnline ? 'Online' : item.formattedLastSeen,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bookmark Heart on Top Right of Image
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _toggleBookmark(item),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Icon(
                      item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 16,
                      color: item.isFavorite ? Colors.red : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Body Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Worker Name + Verified Badge
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              userName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (item.user?.isVerified == true) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Rating & Reviews directly under User Name + Category Subtitle
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFB800)),
                          const SizedBox(width: 2),
                          Text(
                            '${item.rating}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            ' (${item.reviewsCount})',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '• ${item.category?.name ?? "Driving"}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Task Title Pill Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4F1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFC7F3E2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt_rounded, size: 12, color: primaryDark),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Card Updated Time Subtitle
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 10, color: Color(0xFF64748B)),
                          const SizedBox(width: 3),
                          Text(
                            item.formattedTimeAgo,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Location & Calculated Distance
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF094943)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${item.location ?? item.user?.location ?? PresenceService.currentPlaceName} • $distStr',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF094943),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Price Tag Pill Badge under Location
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (item.price == null || item.price == 0)
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (item.price == null || item.price == 0)
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFBBF7D0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (item.price == null || item.price == 0)
                                  ? Icons.handshake_outlined
                                  : Icons.payments_outlined,
                              size: 11,
                              color: (item.price == null || item.price == 0)
                                  ? const Color(0xFF92400E)
                                  : const Color(0xFF166534),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                item.formattedPrice,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: (item.price == null || item.price == 0)
                                      ? const Color(0xFF92400E)
                                      : const Color(0xFF166534),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBottomSheet() {
    const primaryDark = Color(0xFF094943);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sort By',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showSortBottomSheet = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Column(
                children: _sortOptions.map((option) {
                  final isSelected = _selectedSort == option;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedSort = option;
                        _showSortBottomSheet = false;
                      });
                      _fetchCards();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFC7F3E2).withValues(alpha: 0.4)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? primaryDark : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            option,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? primaryDark : const Color(0xFF1E293B),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: primaryDark,
                              size: 20,
                            )
                          else
                            const Icon(
                              Icons.radio_button_unchecked_rounded,
                              color: Color(0xFF94A3B8),
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

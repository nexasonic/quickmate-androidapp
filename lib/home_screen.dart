import 'package:flutter/material.dart';
import 'card_detail_screen.dart';
import 'core/app_dialogs.dart';
import 'discover_screen.dart';
import 'chat_list_screen.dart';
import 'map_view_screen.dart';
import 'profile_screen.dart';
import 'my_cards_screen.dart';
import 'models/category_model.dart';
import 'models/live_work_card_model.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/chat_notification_service.dart';
import 'services/live_work_service.dart';
import 'services/presence_service.dart';
import 'services/profile_service.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;
  UserModel? _currentUser;
  List<LiveWorkCardModel> _liveWorks = [];
  List<CategoryModel> _categories = [];
  CategoryModel? _selectedCategory;
  bool _isLoading = true;

  final TextEditingController _homeSearchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadData();
    PresenceService.startPeriodicPing();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ChatNotificationService.startListening(context);
      }
    });
  }

  @override
  void dispose() {
    _homeSearchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    setState(() {
      _searchQuery = _homeSearchController.text;
      _selectedIndex = 1; // Switch to Discover tab for search results
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    _currentUser = AuthService.getStoredUser();

    final homeData = await LiveWorkService.fetchHomeData();
    final profile = await ProfileService.fetchUserProfile();

    if (!mounted) return;

    setState(() {
      _currentUser = profile ?? _currentUser;
      _liveWorks = homeData['live_works'] as List<LiveWorkCardModel>? ?? [];
      _categories = homeData['categories'] as List<CategoryModel>? ?? [];
      _isLoading = false;
    });
  }

  List<LiveWorkCardModel> get _displayedLiveWorks {
    List<LiveWorkCardModel> list = _liveWorks;
    if (_selectedCategory != null) {
      list = list.where((c) => c.category?.id == _selectedCategory!.id).toList();
    }
    return list.take(6).toList(); // Show only nearest 6 cards max
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildOriginalHomeView(),
          DiscoverScreen(
            initialCategory: _selectedCategory,
            initialSearch: _searchQuery,
          ),
          const MyCardsScreen(),
          const MapViewScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Future<void> _toggleBookmark(LiveWorkCardModel card) async {
    if (!AuthService.isLoggedIn()) {
      AppDialogs.showLoginRequiredModal(
        context,
        message: 'Please sign in to save cards to favorites.',
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

  Widget _buildOriginalHomeView() {
    final userName = _currentUser?.name ?? 'Welcome Guest';
    final avatarUrl = _currentUser?.avatarUrl;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF094943),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: const [
                            Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              'Nearby Live Works',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Color(0xFF094943),
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            const Icon(Icons.notifications_none_outlined, color: Colors.black54),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: avatarUrl != null && avatarUrl.isNotEmpty
                            ? Image.network(
                                avatarUrl,
                                width: 45,
                                height: 45,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 45,
                                  height: 45,
                                  color: const Color(0xFF094943),
                                  child: const Icon(Icons.person, color: Colors.white),
                                ),
                              )
                            : Container(
                                width: 45,
                                height: 45,
                                color: const Color(0xFF094943),
                                child: const Icon(Icons.person, color: Colors.white),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 25),

              // Search Bar (Workable)
              Container(
                padding: const EdgeInsets.only(left: 16, right: 6, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _homeSearchController,
                        onChanged: (text) {
                          setState(() {});
                        },
                        onSubmitted: (_) => _performSearch(),
                        decoration: const InputDecoration(
                          hintText: 'Search Live Work cards...',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_homeSearchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _homeSearchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.clear, color: Colors.grey, size: 20),
                        ),
                      ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _performSearch,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF094943),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Search',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF094943),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LIVE WORK MARKET',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Explore real-time active services & work around you!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 15),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedIndex = 1;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                            child: const Text('Discover'),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.business_center_outlined, size: 70, color: Colors.white24),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Categories Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Popular Categories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedIndex = 1;
                      });
                    },
                    child: Row(
                      children: const [
                        Text('View All', style: TextStyle(color: Colors.grey)),
                        Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Horizontal Scrollable Workable Categories
              if (_categories.isNotEmpty)
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _categories.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final bool isAllSelected = _selectedCategory == null;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = null;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isAllSelected ? const Color(0xFF094943) : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isAllSelected ? const Color(0xFF094943) : Colors.black12,
                              ),
                            ),
                            child: Text(
                              'All',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isAllSelected ? Colors.white : const Color(0xFF094943),
                              ),
                            ),
                          ),
                        );
                      }

                      final cat = _categories[index - 1];
                      final bool isSelected = _selectedCategory?.id == cat.id;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = isSelected ? null : cat;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF094943) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF094943) : Colors.black12,
                            ),
                          ),
                          child: Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF094943),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 25),

              // Live Work Grid Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedCategory != null
                        ? 'Nearest ${_selectedCategory!.name} Cards'
                        : 'Nearest Live Works',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Service Cards Grid (Only 6 Cards)
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF094943)),
                  ),
                )
              else if (_displayedLiveWorks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(30),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.business_center_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'No Live Work cards available.',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _displayedLiveWorks.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemBuilder: (context, index) {
                    final item = _displayedLiveWorks[index];
                    return GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CardDetailScreen(card: item),
                          ),
                        );
                        _loadData();
                      },
                      child: _buildLiveWorkCard(item),
                    );
                  },
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveWorkCard(LiveWorkCardModel item) {
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
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Image with Online / Offline Badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: image != null && image.isNotEmpty
                    ? Image.network(
                        image,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 100,
                          color: Colors.grey[200],
                          child: const Icon(Icons.work_outline, color: Colors.grey),
                        ),
                      )
                    : Container(
                        height: 100,
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
                          const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF64748B)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${item.location ?? "Thodupuzha"} • $distStr',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
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

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.explore_rounded, 'Discover', filledIcon: Icons.explore),
              _buildNavItem(2, Icons.grid_view_outlined, 'My Cards', filledIcon: Icons.grid_view_rounded),
              _buildNavItem(3, Icons.map_outlined, 'Map', filledIcon: Icons.map_rounded),
              _buildNavItem(4, Icons.person_outline_rounded, 'Profile', filledIcon: Icons.person_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {IconData? filledIcon}) {
    final bool isActive = _selectedIndex == index;
    const activeColor = Color(0xFF094943);
    const inactiveColor = Color(0xFF64748B);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive && filledIcon != null)
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  filledIcon,
                  size: 20,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                icon,
                size: 24,
                color: isActive ? activeColor : inactiveColor,
              ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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

import 'package:flutter/material.dart';
import 'card_detail_screen.dart';
import 'core/app_dialogs.dart';
import 'core/app_language.dart';
import 'core/app_theme.dart';
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

  final GlobalKey<DiscoverScreenState> _discoverKey = GlobalKey<DiscoverScreenState>();
  final GlobalKey<MyCardsScreenState> _myCardsKey = GlobalKey<MyCardsScreenState>();
  final GlobalKey<MapViewScreenState> _mapKey = GlobalKey<MapViewScreenState>();
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey<ProfileScreenState>();

  final TextEditingController _homeSearchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadData();
    PresenceService.startPeriodicPing();
    PresenceService.locationNotifier.addListener(_onLocationUpdated);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ChatNotificationService.startListening(context);
      }
    });
  }

  void _onLocationUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    PresenceService.locationNotifier.removeListener(_onLocationUpdated);
    _homeSearchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    setState(() {
      _searchQuery = _homeSearchController.text;
      _selectedIndex = 1; // Switch to Discover tab for search results
    });
    _discoverKey.currentState?.refresh();
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        _loadData();
        break;
      case 1:
        _discoverKey.currentState?.refresh();
        break;
      case 2:
        _myCardsKey.currentState?.refresh();
        break;
      case 3:
        _mapKey.currentState?.refresh();
        break;
      case 4:
        _profileKey.currentState?.refresh();
        break;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    _currentUser = AuthService.getStoredUser();

    // Ensure device GPS location is fresh before querying home feed
    await PresenceService.pingServer();

    final homeData = await LiveWorkService.fetchHomeData(
      lat: PresenceService.currentLatitude,
      lng: PresenceService.currentLongitude,
    );
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
    List<LiveWorkCardModel> list = List.from(_liveWorks);
    if (_selectedCategory != null) {
      list = list.where((c) => c.category?.id == _selectedCategory!.id).toList();
    }
    list.sort((a, b) {
      final userLat = PresenceService.currentLatitude;
      final userLng = PresenceService.currentLongitude;

      double getDist(LiveWorkCardModel card) {
        if (card.distanceKm != null && card.distanceKm! > 0) return card.distanceKm!;
        if (card.latitude != null && card.longitude != null) {
          final d = calculateDistanceKm(lat1: userLat, lon1: userLng, lat2: card.latitude, lon2: card.longitude);
          if (d != null) return d;
        }
        return 999999.0;
      }

      return getDist(a).compareTo(getDist(b));
    });
    return list.take(6).toList(); // Show only nearest 6 cards max
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildOriginalHomeView(),
          DiscoverScreen(
            key: _discoverKey,
            initialCategory: _selectedCategory,
            initialSearch: _searchQuery,
          ),
          MyCardsScreen(key: _myCardsKey),
          MapViewScreen(key: _mapKey),
          ProfileScreen(key: _profileKey),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Future<void> _toggleBookmark(LiveWorkCardModel card) async {
    if (!AuthService.isLoggedIn()) {
      AppDialogs.showLoginRequiredModal(
        context,
        message: context.tr('sign_in_to_save_favorites'),
        onLoginSuccess: _loadData,
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
        title: newFavoriteState ? context.tr('saved_to_favorites') : context.tr('removed_from_favorites'),
        message: newFavoriteState
            ? context.tr('added_to_saved_cards')
            : context.tr('removed_from_saved_cards'),
        icon: newFavoriteState ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        iconColor: newFavoriteState ? Colors.redAccent : Colors.grey,
      );
    } else {
      setState(() {
        card.isFavorite = !newFavoriteState;
      });
      AppDialogs.showSuccessModal(
        context,
        title: context.tr('error'),
        message: response.message.isNotEmpty ? response.message : context.tr('failed_update_favorites'),
        icon: Icons.error_outline_rounded,
        iconColor: Colors.redAccent,
      );
    }
  }

  Widget _buildOriginalHomeView() {
    final primaryDark = AppTheme.primary(context);
    final userName = _currentUser?.name ?? context.tr('welcome_guest');
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
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textSecondary(context)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                context.tr('nearby_live_works'),
                                style: TextStyle(color: AppTheme.textSecondary(context)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.surface(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border(context)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.05),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: primaryDark,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.surface(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border(context)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.notifications_none_outlined, color: AppTheme.textPrimary(context), size: 20),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: avatarUrl != null && avatarUrl.isNotEmpty
                            ? Image.network(
                                avatarUrl,
                                width: 42,
                                height: 42,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 42,
                                  height: 42,
                                  color: primaryDark,
                                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                                ),
                              )
                            : Container(
                                width: 42,
                                height: 42,
                                color: primaryDark,
                                child: const Icon(Icons.person, color: Colors.white, size: 20),
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
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppTheme.border(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: AppTheme.textSecondary(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _homeSearchController,
                        style: TextStyle(color: AppTheme.textPrimary(context)),
                        onChanged: (text) {
                          setState(() {});
                        },
                        onSubmitted: (_) => _performSearch(),
                        decoration: InputDecoration(
                          hintText: context.tr('search_cards_placeholder'),
                          hintStyle: TextStyle(color: AppTheme.textSecondary(context), fontSize: 14),
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.clear, color: AppTheme.textSecondary(context), size: 20),
                        ),
                      ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _performSearch,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: primaryDark,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('search'),
                              style: const TextStyle(
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
                  color: AppTheme.isDark(context) ? const Color(0xFF042F2E) : const Color(0xFF094943),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('live_work_market'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('explore_realtime_services'),
                            style: const TextStyle(
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
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                            child: Text(
                              context.tr('discover'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
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
                  Text(
                    context.tr('popular_categories'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedIndex = 1;
                      });
                    },
                    child: Row(
                      children: [
                        Text(context.tr('view_all'), style: TextStyle(color: AppTheme.textSecondary(context))),
                        Icon(Icons.chevron_right, size: 16, color: AppTheme.textSecondary(context)),
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
                              color: isAllSelected ? primaryDark : AppTheme.surface(context),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isAllSelected ? primaryDark : AppTheme.border(context),
                              ),
                            ),
                            child: Text(
                              context.tr('all'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isAllSelected ? Colors.white : AppTheme.textPrimary(context),
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
                            color: isSelected ? primaryDark : AppTheme.surface(context),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? primaryDark : AppTheme.border(context),
                            ),
                          ),
                          child: Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppTheme.textPrimary(context),
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
                        ? '${context.tr('nearest')} ${_selectedCategory!.name}'
                        : context.tr('nearest_live_works'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Service Cards Grid (Only 6 Cards)
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: primaryDark),
                  ),
                )
              else if (_displayedLiveWorks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(30),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.business_center_outlined, size: 48, color: AppTheme.textSecondary(context)),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('no_live_work_cards'),
                        style: TextStyle(color: AppTheme.textSecondary(context), fontWeight: FontWeight.bold),
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
                    childAspectRatio: 0.62,
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
    final primaryDark = AppTheme.primary(context);
    final image = item.thumbnailUrl ?? (item.images.isNotEmpty ? item.images.first : null);
    final isOnline = item.user?.isOnline ?? item.isActive;
    final userName = item.user?.name ?? item.title;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppTheme.border(context)),
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
                        height: 88,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 88,
                          color: AppTheme.subtleBackground(context),
                          child: Icon(Icons.work_outline, color: AppTheme.textSecondary(context)),
                        ),
                      )
                    : Container(
                        height: 88,
                        color: AppTheme.subtleBackground(context),
                        child: Icon(Icons.work_outline, color: AppTheme.textSecondary(context)),
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
                        isOnline ? context.tr('online') : item.getTrFormattedLastSeen(context),
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
                      color: AppTheme.surface(context).withValues(alpha: 0.9),
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
                      color: item.isFavorite ? Colors.red : AppTheme.textPrimary(context),
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
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: AppTheme.textPrimary(context),
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            ' (${item.reviewsCount})',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '• ${item.category?.name ?? context.tr('driving')}',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary(context),
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
                          color: AppTheme.isDark(context) ? const Color(0xFF134E4A) : const Color(0xFFE6F4F1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.isDark(context) ? const Color(0xFF115E59) : const Color(0xFFC7F3E2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 12,
                              color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : primaryDark,
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
                          Icon(Icons.access_time_rounded, size: 10, color: AppTheme.textSecondary(context)),
                          const SizedBox(width: 3),
                          Text(
                            item.getTrFormattedTimeAgo(context),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Location & Calculated Distance
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : const Color(0xFF094943),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${item.location ?? item.user?.location ?? PresenceService.currentPlaceName} • ${item.getTrFormattedDistance(context, PresenceService.currentLatitude, PresenceService.currentLongitude)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                color: AppTheme.isDark(context) ? const Color(0xFF2DD4BF) : const Color(0xFF094943),
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
                              ? (AppTheme.isDark(context) ? const Color(0xFF78350F) : const Color(0xFFFEF3C7))
                              : (AppTheme.isDark(context) ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (item.price == null || item.price == 0)
                                ? (AppTheme.isDark(context) ? const Color(0xFF92400E) : const Color(0xFFFDE68A))
                                : (AppTheme.isDark(context) ? const Color(0xFF047857) : const Color(0xFFBBF7D0)),
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
                                  ? (AppTheme.isDark(context) ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
                                  : (AppTheme.isDark(context) ? const Color(0xFF86EFAC) : const Color(0xFF166534)),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                item.getTrFormattedPrice(context),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: (item.price == null || item.price == 0)
                                      ? (AppTheme.isDark(context) ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
                                      : (AppTheme.isDark(context) ? const Color(0xFF86EFAC) : const Color(0xFF166534)),
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
    final bool isActive = _selectedIndex == index;
    final activeColor = AppTheme.primary(context);
    final inactiveColor = AppTheme.textSecondary(context);

    return InkWell(
      onTap: () => _onTabSelected(index),
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

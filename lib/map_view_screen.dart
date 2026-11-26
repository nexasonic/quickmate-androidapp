import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'card_detail_screen.dart';
import 'chat_list_screen.dart';
import 'core/api_config.dart';
import 'core/api_service.dart';
import 'core/app_language.dart';
import 'core/app_theme.dart';
import 'models/live_work_card_model.dart';
import 'my_cards_screen.dart';
import 'services/auth_service.dart';
import 'services/live_work_service.dart';
import 'services/presence_service.dart';

class MapPinModel {
  final int id;
  final int? userId;
  final String type;
  final String title;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final dynamic price;
  final String currency;
  final String? thumbnailUrl;
  final String userName;
  final String? userAvatar;

  MapPinModel({
    required this.id,
    this.userId,
    required this.type,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.price,
    this.currency = 'INR',
    this.thumbnailUrl,
    required this.userName,
    this.userAvatar,
  });

  factory MapPinModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] as Map<String, dynamic>? ?? {};
    final profileMap = userMap['profile'] as Map<String, dynamic>? ?? (json['profile'] as Map<String, dynamic>? ?? {});
    final rawThumb = json['thumbnail_url']?.toString() ?? json['image']?.toString() ?? json['cover_image']?.toString();
    final rawAvatar = userMap['avatar_url']?.toString() ?? userMap['avatar']?.toString();

    final int? rawUserId = json['user_id'] is int
        ? json['user_id']
        : (userMap['id'] is int
            ? userMap['id']
            : int.tryParse(userMap['id']?.toString() ?? json['user_id']?.toString() ?? ''));

    double? parseCoord(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble() != 0 ? val.toDouble() : null;
      if (val is String) {
        final d = double.tryParse(val);
        return d != null && d != 0 ? d : null;
      }
      return null;
    }

    final lat = parseCoord(json['latitude']) ?? parseCoord(userMap['latitude']) ?? parseCoord(profileMap['latitude']) ?? PresenceService.currentLatitude;
    final lng = parseCoord(json['longitude']) ?? parseCoord(userMap['longitude']) ?? parseCoord(profileMap['longitude']) ?? PresenceService.currentLongitude;

    final double userLat = PresenceService.currentLatitude;
    final double userLng = PresenceService.currentLongitude;
    final double dist = json['distance_km'] != null && (json['distance_km'] as num).toDouble() > 0
        ? (json['distance_km'] as num).toDouble()
        : (calculateDistanceKm(lat1: userLat, lon1: userLng, lat2: lat, lon2: lng) ?? 0.0);

    final userName = userMap['name']?.toString() ?? 'User';

    // Intelligently extract real card/work title
    final rawTitle = json['title']?.toString() ??
        json['card_title']?.toString() ??
        json['work_title']?.toString() ??
        json['name']?.toString() ??
        json['category_name']?.toString() ??
        json['category']?['name']?.toString();

    String finalTitle = (rawTitle != null && rawTitle.isNotEmpty) ? rawTitle : 'Live Work Card';
    if (finalTitle.trim().toLowerCase() == userName.trim().toLowerCase()) {
      final categoryName = json['category_name']?.toString() ?? json['category']?['name']?.toString();
      if (categoryName != null && categoryName.isNotEmpty) {
        finalTitle = categoryName;
      } else {
        finalTitle = 'Live Work Card';
      }
    }

    return MapPinModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      userId: rawUserId,
      type: json['type']?.toString() ?? 'live_work',
      title: finalTitle,
      latitude: lat,
      longitude: lng,
      distanceKm: dist,
      price: json['price'] ?? json['price_amount'],
      currency: json['currency']?.toString() ?? 'INR',
      thumbnailUrl: rawThumb != null ? ApiConfig.fixImageUrl(rawThumb) : null,
      userName: userName,
      userAvatar: rawAvatar != null ? ApiConfig.fixImageUrl(rawAvatar) : null,
    );
  }

  factory MapPinModel.fromLiveWorkCard(LiveWorkCardModel card, double userLat, double userLng) {
    final double cardLat = (card.latitude != null && card.latitude != 0)
        ? card.latitude!
        : ((card.user?.latitude != null && card.user!.latitude != 0)
            ? card.user!.latitude!
            : PresenceService.currentLatitude);

    final double cardLng = (card.longitude != null && card.longitude != 0)
        ? card.longitude!
        : ((card.user?.longitude != null && card.user!.longitude != 0)
            ? card.user!.longitude!
            : PresenceService.currentLongitude);

    final double dist = calculateDistanceKm(lat1: userLat, lon1: userLng, lat2: cardLat, lon2: cardLng) ?? (card.distanceKm ?? 0.0);

    return MapPinModel(
      id: card.id,
      userId: card.user?.id,
      type: 'live_work',
      title: card.title.isNotEmpty ? card.title : (card.category?.name ?? 'Live Work Card'),
      latitude: cardLat,
      longitude: cardLng,
      distanceKm: dist,
      price: card.price != null && card.price! > 0 ? card.price : (card.priceType ?? 'Negotiable'),
      currency: card.currency,
      thumbnailUrl: card.thumbnailUrl ?? (card.images.isNotEmpty ? card.images.first : null),
      userName: card.user?.name ?? 'User',
      userAvatar: card.user?.avatarUrl,
    );
  }

  String get formattedPrice {
    if (price == null || price == 0) return 'Negotiable';
    if (price is String) return price.toString();
    if (price is num) {
      final pVal = (price as num) % 1 == 0 ? (price as num).toInt().toString() : (price as num).toStringAsFixed(2);
      return '$currency $pVal';
    }
    return '$currency $price';
  }

  String get formattedDistance {
    if (distanceKm > 0) {
      if (distanceKm < 1.0) {
        return '${(distanceKm * 1000).round()} m away';
      }
      return '${distanceKm.toStringAsFixed(1)} km away';
    }
    return 'Nearby';
  }
}

class UserMapPinGroup {
  final int? userId;
  final String userName;
  final String? userAvatar;
  final double latitude;
  final double longitude;
  final List<MapPinModel> cards;
  final bool isCurrentUser;

  UserMapPinGroup({
    this.userId,
    required this.userName,
    this.userAvatar,
    required this.latitude,
    required this.longitude,
    required this.cards,
    this.isCurrentUser = false,
  });

  MapPinModel? get primaryCard => cards.isNotEmpty ? cards.first : null;
  int get cardCount => cards.length;
}

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => MapViewScreenState();
}

class MapViewScreenState extends State<MapViewScreen> {
  final MapController _mapController = MapController();

  Future<void> refresh() => _fetchMapPins();

  bool _isLoading = true;
  List<MapPinModel> _pins = [];
  List<UserMapPinGroup> _userGroups = [];
  UserMapPinGroup? _selectedGroup;
  LatLng _centerLocation = const LatLng(9.8920, 76.7190); // Default location
  double _currentZoom = 13.5;

  @override
  void initState() {
    super.initState();
    PresenceService.locationNotifier.addListener(_onLocationUpdated);
    _fetchMapPins();
  }

  void _onLocationUpdated() {
    if (mounted) {
      setState(() {
        _centerLocation = LatLng(PresenceService.currentLatitude, PresenceService.currentLongitude);
      });
    }
  }

  @override
  void dispose() {
    PresenceService.locationNotifier.removeListener(_onLocationUpdated);
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchMapPins() async {
    setState(() {
      _isLoading = true;
    });

    final lat = PresenceService.currentLatitude;
    final lng = PresenceService.currentLongitude;
    _centerLocation = LatLng(lat, lng);

    // Fetch both full live work cards feed & map API response in parallel to retrieve ALL cards per user
    final results = await Future.wait([
      LiveWorkService.fetchLiveWorkCards(lat: lat, lng: lng),
      ApiService.get(
        '${ApiConfig.baseUrl}/map/cards?lat=$lat&lng=$lng&radius=500&type=live_work',
        withAuth: false,
      ),
    ]);

    if (!mounted) return;

    final List<LiveWorkCardModel> liveWorkCards = results[0] as List<LiveWorkCardModel>;
    final ApiResponse mapResponse = results[1] as ApiResponse;

    final Map<int, MapPinModel> allPinsMap = {};

    // 1. Process LiveWorkService cards (retrieves ALL active live work cards per user)
    for (final card in liveWorkCards) {
      final pin = MapPinModel.fromLiveWorkCard(card, lat, lng);
      allPinsMap[pin.id] = pin;
    }

    // 2. Process Map API pins (merge any additional pins or center location returned)
    if (mapResponse.success && mapResponse.data != null) {
      final data = mapResponse.data as Map<String, dynamic>;
      final List list = data['pins'] is List ? data['pins'] : [];
      for (final item in list) {
        final pin = MapPinModel.fromJson(item as Map<String, dynamic>);
        if (!allPinsMap.containsKey(pin.id)) {
          allPinsMap[pin.id] = pin;
        }
      }

      if (data['center'] != null && data['center'] is Map) {
        final centerLat = (data['center']['latitude'] as num?)?.toDouble();
        final centerLng = (data['center']['longitude'] as num?)?.toDouble();
        if (centerLat != null && centerLng != null && centerLat != 0) {
          _centerLocation = LatLng(centerLat, centerLng);
        }
      }
    }

    final parsedPins = allPinsMap.values.toList();

    // Group pins strictly per User (1 circle marker on map per user)
    final currentUser = AuthService.getStoredUser();
    final groupsMap = <String, UserMapPinGroup>{};

    for (final pin in parsedPins) {
      final isCurrentUser = currentUser != null &&
          ((pin.userId != null && pin.userId == currentUser.id) ||
           (pin.userName.toLowerCase() == currentUser.name.toLowerCase()));

      final displayName = isCurrentUser ? 'YOU' : pin.userName;
      final displayAvatar = isCurrentUser ? (currentUser.avatarUrl ?? pin.userAvatar) : pin.userAvatar;

      // Group ALL cards created by the same user under 1 user key
      final key = isCurrentUser
          ? 'you_group'
          : (pin.userId != null ? 'user_${pin.userId}' : 'user_${displayName.toLowerCase()}');

      if (!groupsMap.containsKey(key)) {
        groupsMap[key] = UserMapPinGroup(
          userId: isCurrentUser ? currentUser.id : pin.userId,
          userName: displayName,
          userAvatar: displayAvatar,
          latitude: pin.latitude,
          longitude: pin.longitude,
          cards: [pin],
          isCurrentUser: isCurrentUser,
        );
      } else {
        if (!groupsMap[key]!.cards.any((c) => c.id == pin.id)) {
          groupsMap[key]!.cards.add(pin);
        }
      }
    }

    // Ensure a "YOU" location circle marker is always present on the map (for both guest and logged in users)
    if (!groupsMap.containsKey('you_group')) {
      groupsMap['you_group'] = UserMapPinGroup(
        userId: currentUser?.id,
        userName: 'YOU',
        userAvatar: currentUser?.avatarUrl,
        latitude: PresenceService.currentLatitude,
        longitude: PresenceService.currentLongitude,
        cards: [],
        isCurrentUser: true,
      );
    }

    final groupsList = groupsMap.values.toList();

    setState(() {
      _pins = parsedPins;
      _userGroups = groupsList;

      // Auto-select YOU group if available, else first group
      if (_userGroups.isNotEmpty) {
        final youGroup = _userGroups.firstWhere(
          (g) => g.isCurrentUser || g.userName == 'YOU',
          orElse: () => _userGroups.first,
        );
        _selectedGroup = youGroup;
      }
      _isLoading = false;
    });

    _fitMapBounds();
  }

  void _zoomIn() {
    _currentZoom = (_currentZoom + 1.0).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _zoomOut() {
    _currentZoom = (_currentZoom - 1.0).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _recenter() {
    _mapController.move(_centerLocation, 14.0);
  }

  void _fitMapBounds() {
    if (_userGroups.isEmpty) return;

    final points = [_centerLocation, ..._userGroups.map((g) => LatLng(g.latitude, g.longitude))];
    final bounds = LatLngBounds.fromPoints(points);

    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    } catch (_) {}
  }

  void _navigateToCardDetail(MapPinModel pin) {
    final liveWorkCard = LiveWorkCardModel(
      id: pin.id,
      title: pin.title,
      latitude: pin.latitude,
      longitude: pin.longitude,
      distanceKm: pin.distanceKm,
      thumbnailUrl: pin.thumbnailUrl,
      images: pin.thumbnailUrl != null ? [pin.thumbnailUrl!] : [],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CardDetailScreen(
          card: liveWorkCard,
          cardType: pin.type,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryDark = AppTheme.primary(context);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchMapPins,
          color: primaryDark,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
              child: Column(
                children: [
                  // Top App Bar Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('map_view'),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary(context),
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Real-time live worker radar',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            // Top Chat Icon Button
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
                                  color: AppTheme.surface(context),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
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
                            // Refresh Button
                            GestureDetector(
                              onTap: _fetchMapPins,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.refresh_rounded,
                                  color: primaryDark,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Real Interactive OpenStreetMap Canvas
                  Expanded(
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator(color: primaryDark))
                        : Stack(
                            children: [
                              FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _centerLocation,
                                  initialZoom: _currentZoom,
                                  minZoom: 3.0,
                                  maxZoom: 18.0,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.nexasonic.quickmate',
                                  ),

                                  // Single Circle Marker Per User
                                  MarkerLayer(
                                    markers: _userGroups.map((group) {
                                      final isYou = group.isCurrentUser || group.userName == 'YOU';
                                      final isSelected = _selectedGroup?.userName == group.userName &&
                                          _selectedGroup?.latitude == group.latitude;
                                      final avatar = group.userAvatar ?? (group.cards.isNotEmpty ? group.primaryCard?.thumbnailUrl : null);

                                      return Marker(
                                        point: LatLng(group.latitude, group.longitude),
                                        width: 85,
                                        height: 85,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedGroup = group;
                                            });
                                          },
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  AnimatedContainer(
                                                    duration: const Duration(milliseconds: 200),
                                                    padding: const EdgeInsets.all(2.5),
                                                    decoration: BoxDecoration(
                                                      color: isYou
                                                          ? const Color(0xFF094943)
                                                          : (isSelected ? const Color(0xFF10B981) : primaryDark),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: isYou ? const Color(0xFF10B981) : Colors.white,
                                                        width: isYou ? 2.5 : 1.5,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: isYou
                                                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                                              : Colors.black.withValues(alpha: 0.25),
                                                          blurRadius: isYou ? 12 : 8,
                                                          offset: const Offset(0, 3),
                                                        ),
                                                      ],
                                                    ),
                                                    child: CircleAvatar(
                                                      radius: isSelected ? 22 : 18,
                                                      backgroundColor: const Color(0xFF064E3B),
                                                      backgroundImage: avatar != null && avatar.isNotEmpty
                                                          ? NetworkImage(avatar)
                                                          : null,
                                                      child: avatar == null || avatar.isEmpty
                                                          ? Text(
                                                              isYou
                                                                  ? 'YOU'
                                                                  : (group.userName.isNotEmpty
                                                                      ? group.userName.substring(0, 1).toUpperCase()
                                                                      : 'U'),
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            )
                                                          : null,
                                                    ),
                                                  ),

                                                  // Card Count Badge Tag on Circle Pin
                                                  if (group.cardCount > 0)
                                                    Positioned(
                                                      top: -4,
                                                      right: -4,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF10B981),
                                                          borderRadius: BorderRadius.circular(10),
                                                          border: Border.all(color: Colors.white, width: 1.5),
                                                        ),
                                                        child: Text(
                                                          group.cardCount.toString().padLeft(2, '0'),
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isYou
                                                      ? const Color(0xFF094943)
                                                      : (isSelected ? primaryDark : Colors.white),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: isYou ? Border.all(color: const Color(0xFF10B981), width: 1) : null,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.1),
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  isYou
                                                      ? (group.cardCount > 0 ? 'YOU (${group.cardCount})' : 'YOU')
                                                      : group.userName,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: isYou || isSelected ? Colors.white : primaryDark,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),

                              // Top Left: Live Workers Radar Badge
                              Positioned(
                                top: 14,
                                left: 14,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.circle, color: Color(0xFF10B981), size: 10),
                                      const SizedBox(width: 8),
                                      Text(
                                        context.tr('live_workers_radar'),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Top Right: Map Action Buttons (Center + Fit)
                              Positioned(
                                top: 14,
                                right: 14,
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: _recenter,
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.1),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: Icon(Icons.my_location_rounded, color: primaryDark, size: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _fitMapBounds,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.1),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.aspect_ratio_rounded, color: primaryDark, size: 18),
                                            const SizedBox(width: 4),
                                            Text(
                                              context.tr('fit'),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: primaryDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Bottom Right: Zoom Controls (+ / -)
                              Positioned(
                                right: 14,
                                bottom: _selectedGroup != null ? 180 : 70,
                                child: Column(
                                  children: [
                                    GestureDetector(
                                      onTap: _zoomIn,
                                      child: Container(
                                        width: 42,
                                        height: 42,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black12, blurRadius: 6),
                                          ],
                                        ),
                                        child: const Icon(Icons.add, color: Color(0xFF0F172A), size: 22),
                                      ),
                                    ),
                                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                    GestureDetector(
                                      onTap: _zoomOut,
                                      child: Container(
                                        width: 42,
                                        height: 42,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black12, blurRadius: 6),
                                          ],
                                        ),
                                        child: const Icon(Icons.remove, color: Color(0xFF0F172A), size: 22),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Bottom Left: Location Radius Badge
                              Positioned(
                                left: 14,
                                bottom: _selectedGroup != null ? 180 : 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.push_pin_rounded, color: Colors.pinkAccent, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${PresenceService.currentPlaceName} ${context.tr('radius')}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_pins.length} ${context.tr('cards_available_nearby')}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Selected User Group Cards Sheet at Bottom
                              if (_selectedGroup != null)
                                Positioned(
                                  left: 14,
                                  right: 14,
                                  bottom: 14,
                                  child: _buildSelectedGroupCards(_selectedGroup!),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedGroupCards(UserMapPinGroup group) {
    final primaryDark = AppTheme.primary(context);
    final isYou = group.isCurrentUser || group.userName == 'YOU';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.4 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with User Info & Card Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: primaryDark,
                    backgroundImage: group.userAvatar != null && group.userAvatar!.isNotEmpty
                        ? NetworkImage(group.userAvatar!)
                        : null,
                    child: group.userAvatar == null || group.userAvatar!.isEmpty
                        ? Text(
                            isYou ? 'Y' : (group.userName.isNotEmpty ? group.userName[0].toUpperCase() : 'U'),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isYou
                                ? '${context.tr('you')} (${group.cardCount} ${context.tr('cards')})'
                                : '${group.userName} (${group.cardCount} ${context.tr('cards')})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (isYou) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                context.tr('your_location'),
                                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isYou
                            ? '${context.tr('live_location')}: ${PresenceService.currentPlaceName}'
                            : '${group.latitude.toStringAsFixed(4)}, ${group.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedGroup = null;
                  });
                },
                child: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cards List or Empty Notice for "YOU"
          if (group.cards.isEmpty && isYou)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4F1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC7F3E2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: primaryDark, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('no_cards_posted_map'),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MyCardsScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryDark,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      '+ ${context.tr('create_card')}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: group.cards.length,
                separatorBuilder: (context, index) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final pin = group.cards[index];
                  return _buildSingleCardItem(pin);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSingleCardItem(MapPinModel pin) {
    const primaryDark = Color(0xFF094943);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: pin.thumbnailUrl != null && pin.thumbnailUrl!.isNotEmpty
                ? Image.network(
                    pin.thumbnailUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 56,
                      height: 56,
                      color: const Color(0xFFE6F4F1),
                      child: const Icon(Icons.work_outline_rounded, color: primaryDark, size: 24),
                    ),
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: const Color(0xFFE6F4F1),
                    child: const Icon(Icons.work_outline_rounded, color: primaryDark, size: 24),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pin.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.near_me_outlined, size: 12, color: primaryDark),
                    const SizedBox(width: 4),
                    Text(
                      pin.formattedDistance,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: primaryDark,
                      ),
                    ),
                    if (pin.price != null && pin.price != 0) ...[
                      const Text(' • ', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      Text(
                        pin.formattedPrice,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _navigateToCardDetail(pin),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDark,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'View',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

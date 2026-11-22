import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'card_detail_screen.dart';
import 'chat_list_screen.dart';
import 'core/api_config.dart';
import 'core/api_service.dart';
import 'models/live_work_card_model.dart';
import 'services/auth_service.dart';
import 'services/presence_service.dart';

class MapPinModel {
  final int id;
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
    final rawThumb = json['thumbnail_url']?.toString();
    final rawAvatar = userMap['avatar_url']?.toString();

    final latRaw = json['latitude'];
    final lngRaw = json['longitude'];
    final lat = latRaw != null && latRaw != 0 ? (latRaw as num).toDouble() : 9.8920;
    final lng = lngRaw != null && lngRaw != 0 ? (lngRaw as num).toDouble() : 76.7190;

    return MapPinModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      type: json['type']?.toString() ?? 'live_work',
      title: json['title']?.toString() ?? 'Live Work Card',
      latitude: lat,
      longitude: lng,
      distanceKm: json['distance_km'] != null ? (json['distance_km'] as num).toDouble() : 0.0,
      price: json['price'],
      currency: json['currency']?.toString() ?? 'INR',
      thumbnailUrl: rawThumb != null ? ApiConfig.fixImageUrl(rawThumb) : null,
      userName: userMap['name']?.toString() ?? 'User',
      userAvatar: rawAvatar != null ? ApiConfig.fixImageUrl(rawAvatar) : null,
    );
  }

  String get formattedPrice {
    if (price == null) return 'Price on Request';
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
  final String userName;
  final String? userAvatar;
  final double latitude;
  final double longitude;
  final List<MapPinModel> cards;

  UserMapPinGroup({
    required this.userName,
    this.userAvatar,
    required this.latitude,
    required this.longitude,
    required this.cards,
  });

  MapPinModel get primaryCard => cards.first;
  int get cardCount => cards.length;
}

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final MapController _mapController = MapController();

  bool _isLoading = true;
  List<MapPinModel> _pins = [];
  List<UserMapPinGroup> _userGroups = [];
  UserMapPinGroup? _selectedGroup;
  LatLng _centerLocation = const LatLng(9.8920, 76.7190); // Thodupuzha Kerala
  double _currentZoom = 13.5;

  @override
  void initState() {
    super.initState();
    _fetchMapPins();
  }

  Future<void> _fetchMapPins() async {
    setState(() {
      _isLoading = true;
    });

    final lat = PresenceService.currentLatitude;
    final lng = PresenceService.currentLongitude;
    _centerLocation = LatLng(lat, lng);

    final response = await ApiService.get(
      '${ApiConfig.baseUrl}/map/cards?lat=$lat&lng=$lng&radius=500&type=live_work',
      withAuth: false,
    );

    if (!mounted) return;

    if (response.success && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final List list = data['pins'] is List ? data['pins'] : [];
      final parsedPins = list.map((e) => MapPinModel.fromJson(e as Map<String, dynamic>)).toList();

      if (data['center'] != null && data['center'] is Map) {
        final centerLat = (data['center']['latitude'] as num?)?.toDouble();
        final centerLng = (data['center']['longitude'] as num?)?.toDouble();
        if (centerLat != null && centerLng != null && centerLat != 0) {
          _centerLocation = LatLng(centerLat, centerLng);
        }
      }

      // Group pins by User/Location
      final groupsMap = <String, UserMapPinGroup>{};
      for (final pin in parsedPins) {
        final key = '${pin.userName.toLowerCase()}_${pin.latitude.toStringAsFixed(3)}_${pin.longitude.toStringAsFixed(3)}';
        if (!groupsMap.containsKey(key)) {
          groupsMap[key] = UserMapPinGroup(
            userName: pin.userName,
            userAvatar: pin.userAvatar,
            latitude: pin.latitude,
            longitude: pin.longitude,
            cards: [pin],
          );
        } else {
          groupsMap[key]!.cards.add(pin);
        }
      }

      final groupsList = groupsMap.values.toList();

      setState(() {
        _pins = parsedPins;
        _userGroups = groupsList;
        if (_userGroups.isNotEmpty) {
          _selectedGroup = _userGroups.first;
        }
        _isLoading = false;
      });

      _fitMapBounds();
    } else {
      setState(() {
        _pins = [];
        _userGroups = [];
        _isLoading = false;
      });
    }
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
    const primaryDark = Color(0xFF094943);
    final user = AuthService.getStoredUser();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Map View',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: primaryDark,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Real-time live worker radar',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
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
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
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
                          child: const Icon(
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
                  ? const Center(child: CircularProgressIndicator(color: primaryDark))
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
                            // OpenStreetMap Real Tile Layer
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.nexasonic.quickmate',
                            ),

                            // Real Map Pins Markers
                            MarkerLayer(
                              markers: [
                                // "YOU" User Location Marker
                                Marker(
                                  point: _centerLocation,
                                  width: 70,
                                  height: 70,
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: primaryDark,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.2),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: CircleAvatar(
                                          radius: 18,
                                          backgroundColor: Colors.teal,
                                          backgroundImage: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                                              ? NetworkImage(user.avatarUrl!)
                                              : null,
                                          child: user?.avatarUrl == null || user!.avatarUrl!.isEmpty
                                              ? Text(
                                                  user?.name.substring(0, 1).toUpperCase() ?? 'U',
                                                  style: const TextStyle(
                                                      color: Colors.white, fontWeight: FontWeight.bold),
                                                )
                                              : null,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: primaryDark,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          'YOU',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // User Group Markers (Single Circle Logo Per User)
                                ..._userGroups.map((group) {
                                  final isSelected = _selectedGroup?.userName == group.userName &&
                                      _selectedGroup?.latitude == group.latitude;

                                  final avatar = group.userAvatar ?? group.primaryCard.thumbnailUrl;

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
                                                  color: isSelected ? const Color(0xFF10B981) : primaryDark,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.25),
                                                      blurRadius: 10,
                                                      offset: const Offset(0, 3),
                                                    ),
                                                  ],
                                                ),
                                                child: CircleAvatar(
                                                  radius: isSelected ? 22 : 18,
                                                  backgroundColor: Colors.white,
                                                  backgroundImage: avatar != null && avatar.isNotEmpty
                                                      ? NetworkImage(avatar)
                                                      : null,
                                                  child: avatar == null || avatar.isEmpty
                                                      ? Icon(
                                                          Icons.person_rounded,
                                                          color: primaryDark,
                                                          size: isSelected ? 20 : 16,
                                                        )
                                                      : null,
                                                ),
                                              ),

                                              // Card Count Badge Tag on Circle
                                              if (group.cardCount > 1)
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
                                                      '${group.cardCount}',
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
                                              color: isSelected ? primaryDark : Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.1),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              group.cardCount > 1 ? '${group.userName} (${group.cardCount})' : group.primaryCard.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? Colors.white : primaryDark,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
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
                              children: const [
                                Icon(Icons.circle, color: Color(0xFF10B981), size: 10),
                                SizedBox(width: 8),
                                Text(
                                  'Live Workers Radar',
                                  style: TextStyle(
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
                                  child: const Icon(Icons.my_location_rounded, color: primaryDark, size: 20),
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
                                    children: const [
                                      Icon(Icons.aspect_ratio_rounded, color: primaryDark, size: 18),
                                      SizedBox(width: 4),
                                      Text(
                                        'Fit',
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
                          bottom: _selectedGroup != null ? 140 : 70,
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
                          bottom: _selectedGroup != null ? 140 : 16,
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
                                  children: const [
                                    Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                                    SizedBox(width: 6),
                                    Icon(Icons.push_pin_rounded, color: Colors.pinkAccent, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Thodupuzha Radius',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_pins.length} ${_pins.length == 1 ? 'card' : 'cards'} available nearby',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Selected User Group Cards Collection Sheet at Bottom
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
    );
  }

  Widget _buildSelectedGroupCards(UserMapPinGroup group) {
    const primaryDark = Color(0xFF094943);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with User Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: primaryDark,
                    backgroundImage: group.userAvatar != null && group.userAvatar!.isNotEmpty
                        ? NetworkImage(group.userAvatar!)
                        : null,
                    child: group.userAvatar == null || group.userAvatar!.isEmpty
                        ? const Icon(Icons.person, color: Colors.white, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${group.userName} (${group.cardCount} ${group.cardCount == 1 ? 'Card' : 'Cards'})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedGroup = null;
                  });
                },
                child: const Icon(Icons.close_rounded, color: Colors.grey, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Cards List
          if (group.cards.length == 1)
            _buildSingleCardItem(group.primaryCard)
          else
            SizedBox(
              height: 85,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: group.cards.length,
                itemBuilder: (context, index) {
                  final pin = group.cards[index];
                  return Container(
                    width: 260,
                    margin: const EdgeInsets.only(right: 10),
                    child: _buildSingleCardItem(pin),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSingleCardItem(MapPinModel pin) {
    const primaryDark = Color(0xFF094943);

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: pin.thumbnailUrl != null && pin.thumbnailUrl!.isNotEmpty
              ? Image.network(
                  pin.thumbnailUrl!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 60,
                    height: 60,
                    color: primaryDark,
                    child: const Icon(Icons.work_outline, color: Colors.white),
                  ),
                )
              : Container(
                  width: 60,
                  height: 60,
                  color: primaryDark,
                  child: const Icon(Icons.work_outline, color: Colors.white),
                ),
        ),
        const SizedBox(width: 10),
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
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.near_me_outlined, size: 12, color: Color(0xFF094943)),
                  const SizedBox(width: 4),
                  Text(
                    pin.formattedDistance,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF094943),
                    ),
                  ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
    );
  }
}

import 'package:flutter/material.dart';
import '../card_detail_screen.dart';
import '../core/api_config.dart';
import '../core/api_service.dart';
import '../models/live_work_card_model.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "${card.title}" from saved cards.')),
      );
      _fetchSavedCards();
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
        title: const Text(
          'Saved Cards',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                      return _buildSavedCardItem(card);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.bookmark_border_rounded, size: 60, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No saved cards yet.',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 4),
          Text(
            'Bookmark cards to view them quickly anytime!',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedCardItem(LiveWorkCardModel card) {
    const primaryDark = Color(0xFF094943);
    final image = card.thumbnailUrl ?? (card.images.isNotEmpty ? card.images.first : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: image != null && image.isNotEmpty
                ? Image.network(
                    image,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 70,
                      height: 70,
                      color: primaryDark,
                      child: const Icon(Icons.work_outline, color: Colors.white),
                    ),
                  )
                : Container(
                    width: 70,
                    height: 70,
                    color: primaryDark,
                    child: const Icon(Icons.work_outline, color: Colors.white),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Text(
                  card.category?.name ?? 'Live Work',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Text(
                  card.formattedPrice,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primaryDark,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_remove_rounded, color: Colors.redAccent),
            onPressed: () => _removeBookmark(card),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CardDetailScreen(card: card)),
              );
            },
          ),
        ],
      ),
    );
  }
}

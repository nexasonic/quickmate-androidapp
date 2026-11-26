import 'dart:async';
import 'package:flutter/material.dart';
import 'chat_detail_screen.dart';
import 'core/app_language.dart';
import 'core/app_theme.dart';
import 'login_screen.dart';
import 'models/chat_model.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _isLoading = true;
  List<ConversationModel> _conversations = [];
  bool _isLoggedIn = false;
  Timer? _refreshTimer;

  String _formatLastMessage(String? body, BuildContext context) {
    if (body == null || body.isEmpty) return context.tr('no_messages_yet');
    if (body.contains('Referenced Live Work:')) {
      final workTitle = body.replaceFirst('Referenced Live Work:', '').trim();
      return '${context.tr('referenced_live_work')}: $workTitle';
    }
    return body;
  }

  @override
  void initState() {
    super.initState();
    _loadConversations();

    // Start 3-second periodic polling timer for real-time conversation list updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollConversations();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollConversations() async {
    if (!AuthService.isLoggedIn() || !mounted) return;

    final convos = await ChatService.fetchConversations();
    if (!mounted) return;

    if (convos.isNotEmpty) {
      setState(() {
        _conversations = convos;
      });
    }
  }

  Future<void> _loadConversations() async {
    _isLoggedIn = AuthService.isLoggedIn();
    if (!_isLoggedIn) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _conversations = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final convos = await ChatService.fetchConversations();

    if (!mounted) return;

    setState(() {
      _conversations = convos;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryDark = AppTheme.primary(context);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('chat'),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('chat_with_providers'),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary(context),
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: primaryDark, size: 26),
                    onPressed: _loadConversations,
                  ),
                ],
              ),
            ),

            // Chat Items List or Guest State
            Expanded(
              child: !_isLoggedIn
                  ? _buildGuestView()
                  : RefreshIndicator(
                      onRefresh: _loadConversations,
                      color: primaryDark,
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(color: primaryDark),
                            )
                          : _conversations.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  itemCount: _conversations.length,
                                  itemBuilder: (context, index) {
                                    final convo = _conversations[index];
                                    return _buildChatItem(convo);
                                  },
                                ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestView() {
    final primaryDark = AppTheme.primary(context);

    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.isDark(context) ? const Color(0xFF134E4A) : primaryDark.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 60, color: primaryDark),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr('sign_in_to_chat_title'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context)),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('sign_in_to_chat_desc'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: Text(
                context.tr('sign_in_now'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 50, color: AppTheme.textSecondary(context)),
          const SizedBox(height: 12),
          Text(
            context.tr('no_conversations_yet'),
            style: TextStyle(color: AppTheme.textSecondary(context), fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('start_chat_from_card'),
            style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatLastSeen(ConversationModel convo, BuildContext context) {
    if (convo.isOnline) {
      return context.tr('online');
    }

    final rawLastSeen = convo.lastSeen;
    if (rawLastSeen == null || rawLastSeen.isEmpty) {
      return context.tr('offline');
    }

    final lower = rawLastSeen.toLowerCase().trim();

    if (lower == 'online' || lower == 'online now') {
      return context.tr('online');
    }

    if (lower == 'offline') {
      return context.tr('offline');
    }

    if (lower.contains('just now')) {
      return context.tr('just_now');
    }

    // Match numbers in string (e.g., "25 seconds ago", "5 minutes ago", "2 hours ago", "3 days ago")
    final match = RegExp(r'(\d+)\s*([a-zA-Z]+)').firstMatch(lower);
    if (match != null) {
      final numStr = match.group(1) ?? '';
      final unitStr = match.group(2) ?? '';

      if (unitStr.startsWith('sec')) {
        return context.tr('just_now');
      } else if (unitStr.startsWith('min')) {
        return '$numStr ${context.tr('mins_ago')}';
      } else if (unitStr.startsWith('hour') || unitStr == 'h') {
        return '$numStr ${context.tr('hours_ago')}';
      } else if (unitStr.startsWith('day') || unitStr == 'd') {
        return '$numStr ${context.tr('days_ago')}';
      } else if (unitStr.startsWith('month') || unitStr == 'mo') {
        return '$numStr ${context.tr('months_ago')}';
      }
    }

    return rawLastSeen;
  }

  Widget _buildChatItem(ConversationModel convo) {
    final primaryDark = AppTheme.primary(context);
    final avatar = convo.otherUserAvatar;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              conversationId: convo.id,
              targetUserId: convo.otherUserId,
              chatData: {
                'id': convo.otherUserId.toString(),
                'name': convo.otherUserName,
                'avatar': convo.otherUserAvatar ?? '',
                'isOnline': convo.isOnline,
              },
            ),
          ),
        );
        _loadConversations();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.03),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Row(
          children: [
            // Avatar with Online Indicator Dot
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: primaryDark,
                  backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar == null || avatar.isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 26)
                      : null,
                ),
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: convo.isOnline ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.surface(context), width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Name & Last Message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    convo.otherUserName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatLastMessage(convo.lastMessageBody, context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: convo.unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                      color: convo.unreadCount > 0 ? primaryDark : AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Last Seen Badge & Unread Count Badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: convo.isOnline
                        ? (AppTheme.isDark(context) ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                        : (AppTheme.isDark(context) ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: convo.isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatLastSeen(convo, context),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: convo.isOnline
                              ? (AppTheme.isDark(context) ? const Color(0xFF4ADE80) : const Color(0xFF166534))
                              : AppTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (convo.unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: primaryDark,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${convo.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

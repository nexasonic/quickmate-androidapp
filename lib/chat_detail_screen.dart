import 'dart:async';
import 'package:flutter/material.dart';
import 'card_detail_screen.dart';
import 'core/api_config.dart';
import 'core/api_service.dart';
import 'core/app_dialogs.dart';
import 'login_screen.dart';
import 'models/chat_model.dart';
import 'models/live_work_card_model.dart';
import 'services/auth_service.dart';
import 'services/chat_notification_service.dart';
import 'services/chat_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> chatData;
  final int? conversationId;
  final int? targetUserId;
  final LiveWorkCardModel? card;

  const ChatDetailScreen({
    super.key,
    required this.chatData,
    this.conversationId,
    this.targetUserId,
    this.card,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int? _conversationId;
  LiveWorkCardModel? _referencedCard;
  List<ChatMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  Timer? _pollingTimer;
  bool _isUserOnline = false;
  String? _lastSeenText;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _referencedCard = widget.card;
    _isUserOnline = widget.chatData['isOnline'] == true || widget.chatData['is_online'] == true;
    _lastSeenText = widget.chatData['last_seen']?.toString() ?? widget.chatData['lastSeen']?.toString();

    // Register active conversation ID & target user ID to suppress notifications for current open chat
    ChatNotificationService.activeConversationId = widget.conversationId;
    ChatNotificationService.activeTargetUserId = widget.targetUserId;

    _initAndLoadMessages();

    // Start 3-second periodic polling timer for new incoming messages & read ticks
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollNewMessages();
    });
  }

  @override
  void dispose() {
    if (ChatNotificationService.activeConversationId == _conversationId) {
      ChatNotificationService.activeConversationId = null;
    }
    if (ChatNotificationService.activeTargetUserId == widget.targetUserId) {
      ChatNotificationService.activeTargetUserId = null;
    }

    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pollNewMessages() async {
    if (_conversationId == null || !mounted) return;

    _fetchTargetUserStatus();

    final newMessages = await ChatService.fetchMessages(_conversationId!);
    if (!mounted) return;

    if (newMessages.isNotEmpty) {
      bool hasChanges = newMessages.length != _messages.length;
      if (!hasChanges) {
        for (int i = 0; i < newMessages.length; i++) {
          if (newMessages[i].id != _messages[i].id ||
              newMessages[i].readAt != _messages[i].readAt) {
            hasChanges = true;
            break;
          }
        }
      }

      if (hasChanges) {
        setState(() {
          _messages = newMessages;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _initAndLoadMessages() async {
    setState(() {
      _isLoading = true;
    });

    _fetchTargetUserStatus();

    // If conversationId is not passed, start or retrieve conversation using targetUserId
    if (_conversationId == null && widget.targetUserId != null) {
      _conversationId = await ChatService.startConversation(
        widget.targetUserId!,
        cardType: 'live_work',
        cardId: widget.card?.id,
      );
    } else if (_conversationId == null && widget.chatData['id'] != null) {
      final parsedId = int.tryParse(widget.chatData['id'].toString());
      if (parsedId != null) {
        _conversationId = await ChatService.startConversation(
          parsedId,
          cardType: 'live_work',
          cardId: widget.card?.id,
        );
      }
    }

    if (_conversationId != null) {
      ChatNotificationService.activeConversationId = _conversationId;
      final fetchedMessages = await ChatService.fetchMessages(_conversationId!);
      if (!mounted) return;
      setState(() {
        _messages = fetchedMessages;
        _isLoading = false;
      });
      _scrollToBottom();
    } else {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        Future.delayed(const Duration(milliseconds: 150), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (_conversationId == null && widget.targetUserId != null) {
      _conversationId = await ChatService.startConversation(widget.targetUserId!);
    }

    if (!mounted) return;

    if (_conversationId == null) {
      AppDialogs.showToastModal(
        context,
        message: 'Unable to start conversation.',
        icon: Icons.error_outline_rounded,
        iconColor: Colors.redAccent,
        iconBgColor: const Color(0xFFFEE2E2),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    _messageController.clear();

    final newMsg = await ChatService.sendMessage(_conversationId!, text);

    if (!mounted) return;

    setState(() {
      _isSending = false;
      if (newMsg != null) {
        _messages.add(newMsg);
      }
    });

    _scrollToBottom();
  }

  Future<void> _fetchTargetUserStatus() async {
    if (widget.targetUserId == null) return;

    try {
      final response = await ApiService.get('${ApiConfig.baseUrl}/users/${widget.targetUserId}/profile');
      if (response.success && response.data != null && mounted) {
        final profile = response.data['profile'] as Map<String, dynamic>? ?? {};
        final isOnline = profile['is_online'] == true || response.data['is_online'] == true;
        final lastSeen = profile['last_seen_human']?.toString() ??
            profile['last_seen']?.toString() ??
            response.data['last_seen_human']?.toString();

        setState(() {
          _isUserOnline = isOnline;
          if (lastSeen != null && lastSeen.isNotEmpty) {
            _lastSeenText = lastSeen;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching target user status: $e');
    }
  }

  String get _formattedSubtitle {
    if (_isUserOnline) return 'Online';
    if (_lastSeenText != null && _lastSeenText!.isNotEmpty) {
      if (_lastSeenText!.toLowerCase().contains('last seen')) {
        return _lastSeenText!;
      }
      return 'Last seen $_lastSeenText';
    }
    return 'Offline';
  }

  Widget _buildGuestPromptScreen() {
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
        title: const Text('Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F4F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline_rounded, size: 54, color: primaryDark),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sign In Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please sign in to start a direct message conversation with service providers.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
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
                      _initAndLoadMessages();
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

    const primaryDark = Color(0xFF094943);
    final avatar = widget.chatData['avatar']?.toString();
    final name = widget.chatData['name']?.toString() ?? 'Chat';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: Color(0xFF0F172A),
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: primaryDark,
                  backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar == null || avatar.isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 20)
                      : null,
                ),
                if (_isUserOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Row(
                    children: [
                      if (_isUserOnline) ...[
                        const Icon(Icons.brightness_1_rounded, color: Color(0xFF10B981), size: 8),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        _formattedSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _isUserOnline ? FontWeight.bold : FontWeight.normal,
                          color: _isUserOnline ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF0F172A),
            ),
            onPressed: _initAndLoadMessages,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _initAndLoadMessages,
        color: primaryDark,
        child: Column(
          children: [
            // Message List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: primaryDark),
                    )
                  : _messages.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.65,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey),
                                const SizedBox(height: 10),
                                Text(
                                  'Say hello to $name!',
                                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            return _buildMessageBubble(msg);
                          },
                        ),
            ),

            // Message Input Field Bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkCardBubble(Map<String, dynamic>? meta) {
    const primaryDark = Color(0xFF094943);
    final title = meta?['title']?.toString() ?? 'Work Card';
    final subtitle = meta?['subtitle']?.toString() ?? '';
    final badge = meta?['badge']?.toString() ?? 'Live Work';
    final budget = meta?['budget']?.toString();
    final location = meta?['location']?.toString();
    final description = meta?['description']?.toString();
    final schedule = meta?['schedule']?.toString();
    final tags = meta?['tags'] is List ? (meta!['tags'] as List).map((e) => e.toString()).toList() : <String>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4F1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.code_rounded, color: primaryDark, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (location != null && location.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 2),
                    Text(location, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              if (schedule != null && schedule.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 2),
                    Text(schedule, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              if (budget != null && budget.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.payments_outlined, size: 12, color: primaryDark),
                    const SizedBox(width: 2),
                    Text(
                      budget,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryDark),
                    ),
                  ],
                ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.3),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: tags.map((t) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    t,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: OutlinedButton.icon(
              onPressed: () {
                if (_referencedCard != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CardDetailScreen(card: _referencedCard!)),
                  );
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 14, color: primaryDark),
              label: const Text(
                'View Live Work',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryDark),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: primaryDark, width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg) {
    final bool isMe = msg.isFromMe;
    const sentBg = Color(0xFFDCFCE7);
    const receivedBg = Colors.white;

    final bool isWorkCard = msg.type == 'work_card' || (msg.meta != null && msg.meta!['title'] != null);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? sentBg : receivedBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWorkCard) ...[
              _buildWorkCardBubble(msg.meta),
              const SizedBox(height: 6),
            ],

            if (msg.attachmentUrl != null && msg.attachmentUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  msg.attachmentUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                ),
              ),
              const SizedBox(height: 6),
            ],

            if (msg.body.isNotEmpty && !isWorkCard)
              Text(
                msg.body,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                  height: 1.35,
                ),
              ),
            const SizedBox(height: 4),

            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Spacer(),
                if (msg.createdAtHuman != null)
                  Text(
                    msg.createdAtHuman!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                    ),
                  ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all_rounded,
                    size: 15,
                    color: msg.isRead ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    const primaryDark = Color(0xFF094943);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _messageController,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: primaryDark,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

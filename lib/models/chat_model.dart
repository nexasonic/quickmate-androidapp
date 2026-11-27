import '../core/api_config.dart';
import '../core/app_language.dart';

class ConversationModel {
  final int id;
  final int otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final bool isOnline;
  final String? lastSeen;
  final String? lastMessageBody;
  final bool isLastMessageFromMe;
  final String? lastMessageTime;
  final int unreadCount;

  ConversationModel({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.isOnline = false,
    this.lastSeen,
    this.lastMessageBody,
    this.isLastMessageFromMe = false,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final otherUser = json['other_user'] as Map<String, dynamic>? ?? {};
    final lastMsg = json['last_message'] as Map<String, dynamic>?;

    final rawAvatar = otherUser['avatar_url']?.toString();

    return ConversationModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      otherUserId: otherUser['id'] is int ? otherUser['id'] : int.tryParse(otherUser['id']?.toString() ?? '0') ?? 0,
      otherUserName: otherUser['name'] ?? AppLanguage.trCode('user_fallback'),
      otherUserAvatar: rawAvatar != null ? ApiConfig.fixImageUrl(rawAvatar) : null,
      isOnline: otherUser['is_online'] == true || otherUser['is_online'] == 1,
      lastSeen: otherUser['last_seen'],
      lastMessageBody: lastMsg?['body'],
      isLastMessageFromMe: lastMsg?['is_from_me'] == true,
      lastMessageTime: lastMsg?['created_at'],
      unreadCount: json['unread_count'] is int ? json['unread_count'] : int.tryParse(json['unread_count']?.toString() ?? '0') ?? 0,
    );
  }
}

class ChatMessageModel {
  final int id;
  final int conversationId;
  final int senderId;
  final bool isFromMe;
  final String body;
  final String type;
  final String? attachmentUrl;
  final Map<String, dynamic>? meta;
  final String? readAt;
  final String? createdAt;
  final String? createdAtHuman;

  ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.isFromMe,
    required this.body,
    this.type = 'text',
    this.attachmentUrl,
    this.meta,
    this.readAt,
    this.createdAt,
    this.createdAtHuman,
  });

  bool get isRead => readAt != null && readAt!.isNotEmpty;

  static String? formatCreatedAtHuman(String? rawHuman, String? rawCreatedAt, {DateTime? now}) {
    final human = rawHuman?.trim();
    if (human != null && human.isNotEmpty && DateTime.tryParse(human) == null) {
      return human;
    }

    final timestamp = (rawCreatedAt != null && rawCreatedAt.trim().isNotEmpty) ? rawCreatedAt.trim() : human;
    if (timestamp == null || timestamp.isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(timestamp);
    if (parsed == null) {
      return null;
    }

    final localDt = parsed.toLocal();
    final diff = (now ?? DateTime.now()).difference(localDt);

    if (diff.isNegative || diff.inSeconds < 60) {
      return AppLanguage.trCode('just_now');
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} ${AppLanguage.trCode('mins_ago')}';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} ${AppLanguage.trCode('hours_ago')}';
    } else if (diff.inDays < 30) {
      return '${diff.inDays} ${AppLanguage.trCode('days_ago')}';
    } else {
      return '${(diff.inDays / 30).floor()} ${AppLanguage.trCode('months_ago')}';
    }
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final rawAttachment = json['attachment_url']?.toString();
    final rawMeta = json['meta'] is Map<String, dynamic> ? json['meta'] as Map<String, dynamic> : null;
    final rawCreatedAt = json['created_at']?.toString();
    final rawCreatedAtHuman = json['created_at_human']?.toString();

    return ChatMessageModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      conversationId: json['conversation_id'] is int ? json['conversation_id'] : int.tryParse(json['conversation_id']?.toString() ?? '0') ?? 0,
      senderId: json['sender_id'] is int ? json['sender_id'] : int.tryParse(json['sender_id']?.toString() ?? '0') ?? 0,
      isFromMe: json['is_from_me'] == true,
      body: json['body'] ?? '',
      type: json['type'] ?? 'text',
      attachmentUrl: rawAttachment != null ? ApiConfig.fixImageUrl(rawAttachment) : null,
      meta: rawMeta,
      readAt: json['read_at']?.toString(),
      createdAt: rawCreatedAt,
      createdAtHuman: formatCreatedAtHuman(rawCreatedAtHuman, rawCreatedAt),
    );
  }
}

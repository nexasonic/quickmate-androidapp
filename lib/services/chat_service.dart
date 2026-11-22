import '../core/api_config.dart';
import '../core/api_service.dart';
import '../models/chat_model.dart';

class ChatService {
  /// Fetch all active conversations for the authenticated user.
  static Future<List<ConversationModel>> fetchConversations() async {
    final response = await ApiService.get(ApiConfig.conversations);

    if (response.success && response.data != null) {
      final List list = response.data is List ? response.data : [];
      return list.map((item) => ConversationModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Start or retrieve an existing conversation with a target user ID.
  static Future<int?> startConversation(int targetUserId) async {
    final response = await ApiService.post(
      ApiConfig.conversations,
      body: {
        'user_id': targetUserId,
      },
    );

    if (response.success && response.data != null) {
      final map = response.data as Map<String, dynamic>;
      final convoId = map['conversation_id'];
      if (convoId is int) return convoId;
      if (convoId != null) return int.tryParse(convoId.toString());
    }
    return null;
  }

  /// Fetch messages for a specific conversation ID.
  static Future<List<ChatMessageModel>> fetchMessages(int conversationId) async {
    final response = await ApiService.get(ApiConfig.conversationMessages(conversationId));

    if (response.success && response.data != null) {
      final List list = response.data is List ? response.data : (response.data['data'] ?? []);
      final messages = list.map((item) => ChatMessageModel.fromJson(item as Map<String, dynamic>)).toList();
      // Reverse if API returns newest first so newest is at the bottom
      return messages.reversed.toList();
    }
    return [];
  }

  /// Send a message in a conversation.
  static Future<ChatMessageModel?> sendMessage(int conversationId, String text) async {
    final response = await ApiService.post(
      ApiConfig.sendMessage(conversationId),
      body: {
        'body': text,
      },
    );

    if (response.success && response.data != null) {
      return ChatMessageModel.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  }

  /// Get total count of unread messages.
  static Future<int> fetchUnreadCount() async {
    final response = await ApiService.get(ApiConfig.unreadChatCount);
    if (response.success && response.data != null) {
      return response.data['unread_count'] as int? ?? 0;
    }
    return 0;
  }
}

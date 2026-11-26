import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../chat_detail_screen.dart';
import '../core/app_language.dart';
import '../core/storage_service.dart';
import '../models/chat_model.dart';
import 'auth_service.dart';
import 'chat_service.dart';

class ChatNotificationService {
  static Timer? _notificationTimer;
  static final Map<int, String> _lastKnownMessageIds = {};
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // Active chat session tracking to avoid notifying for the current open chat screen
  static int? activeConversationId;
  static int? activeTargetUserId;

  /// Initialize native system notification channel for Android/iOS
  static Future<void> initialize(BuildContext context) async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && response.payload!.isNotEmpty && context.mounted) {
          final parts = response.payload!.split('|');
          if (parts.length >= 3) {
            final convoId = int.tryParse(parts[0]);
            final otherUserId = int.tryParse(parts[1]);
            final name = parts[2];

            if (convoId != null && otherUserId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatDetailScreen(
                    conversationId: convoId,
                    targetUserId: otherUserId,
                    chatData: {
                      'id': otherUserId.toString(),
                      'name': name,
                      'subtitle': AppLanguage.trCode('live_work_chat'),
                    },
                  ),
                ),
              );
            }
          }
        }
      },
    );

    // Create high-importance Android Notification Channel with Sound & Vibration
    final androidChannel = AndroidNotificationChannel(
      'quickmate_chat_channel',
      AppLanguage.trCode('chat_notif_channel_name'),
      description: AppLanguage.trCode('chat_notif_channel_desc'),
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(androidChannel);
      await androidPlugin.requestNotificationsPermission();
    }

    _isInitialized = true;
  }

  /// Start background polling for new incoming chat messages
  static void startListening(BuildContext context) {
    initialize(context);
    _notificationTimer?.cancel();

    _notificationTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!AuthService.isLoggedIn()) return;
      if (!StorageService.getNotifMessages()) return;

      final conversations = await ChatService.fetchConversations();
      if (!context.mounted) return;

      for (final convo in conversations) {
        if (convo.unreadCount > 0 && convo.lastMessageBody != null) {
          // Check if user is currently viewing THIS conversation in ChatDetailScreen
          final bool isCurrentlyViewingThisChat =
              (activeConversationId != null && activeConversationId == convo.id) ||
              (activeTargetUserId != null && activeTargetUserId == convo.otherUserId);

          // DO NOT show system notification if the user is ALREADY viewing this chat!
          if (isCurrentlyViewingThisChat) {
            continue;
          }

          final lastIdKey = convo.id;
          final lastMsg = convo.lastMessageBody!;

          if (_lastKnownMessageIds[lastIdKey] != lastMsg) {
            _lastKnownMessageIds[lastIdKey] = lastMsg;

            // Trigger System Notification in Top Status Bar with Sound!
            _showSystemNotification(
              conversation: convo,
            );
          }
        }
      }
    });
  }

  /// Stop periodic listening
  static void stopListening() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
  }

  /// Display native System Notification in Android top notification panel
  static Future<void> _showSystemNotification({
    required ConversationModel conversation,
  }) async {
    if (!StorageService.getNotifMessages()) return;

    final androidDetails = AndroidNotificationDetails(
      'quickmate_chat_channel',
      AppLanguage.trCode('chat_notif_channel_name'),
      channelDescription: AppLanguage.trCode('chat_notif_channel_desc'),
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = '${conversation.id}|${conversation.otherUserId}|${conversation.otherUserName}';

    await _localNotificationsPlugin.show(
      conversation.id,
      conversation.otherUserName,
      conversation.lastMessageBody ?? AppLanguage.trCode('new_message_received'),
      notificationDetails,
      payload: payload,
    );
  }
}

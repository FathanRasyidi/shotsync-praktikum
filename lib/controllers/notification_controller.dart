import 'package:get/get.dart';
import 'package:danielshotsync/config/supabase_config.dart';
import 'package:danielshotsync/models/chat_message.dart';
import 'package:danielshotsync/screens/main/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationController extends GetxController {
  var unreadMessageCount = 0.obs;
  var currentUserId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadCurrentUser();
  }

  Future<void> loadCurrentUser() async {
    final userData = await LoginController.getUserData();
    currentUserId.value = userData['user_id'] ?? '';
    if (currentUserId.value.isNotEmpty) {
      await fetchUnreadMessages();
      _subscribeToMessages();
    }
  }

  Future<void> fetchUnreadMessages() async {
    if (currentUserId.value.isEmpty) return;

    try {
      // Get all messages where user is NOT in read_by array and not the sender
      final response = await SupabaseConfig.client
          .from('project_messages')
          .select()
          .neq('sender_id', currentUserId.value); // Not sent by me

      final messages = (response as List)
          .map((json) => ChatMessage.fromJson(json, currentUserId.value))
          .toList();

      // Count messages not read by current user
      final unreadCount = messages
          .where((msg) => !msg.isReadBy(currentUserId.value))
          .length;

      unreadMessageCount.value = unreadCount;
    } catch (e) {
      // Silently fail
    }
  }

  void _subscribeToMessages() {
    SupabaseConfig.client
        .channel('all_project_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'project_messages',
          callback: (payload) {
            final newData = payload.newRecord;
            final senderId = newData['sender_id'] as String?;

            // If message is not from me, increment unread count
            if (senderId != null && senderId != currentUserId.value) {
              unreadMessageCount.value++;
            }
          },
        )
        .subscribe();
  }

  Future<void> markProjectMessagesAsRead(String projectId) async {
    if (currentUserId.value.isEmpty) return;

    try {
      // Get all unread messages in this project
      final response = await SupabaseConfig.client
          .from('project_messages')
          .select()
          .eq('project_id', projectId)
          .neq('sender_id', currentUserId.value);

      final messages = (response as List)
          .map((json) => ChatMessage.fromJson(json, currentUserId.value))
          .toList();

      // Mark each unread message as read
      for (var message in messages) {
        if (!message.isReadBy(currentUserId.value)) {
          final updatedReadBy = [...message.readBy, currentUserId.value];

          await SupabaseConfig.client
              .from('project_messages')
              .update({'read_by': updatedReadBy})
              .eq('id', message.id);

          // Decrement unread count
          if (unreadMessageCount.value > 0) {
            unreadMessageCount.value--;
          }
        }
      }
    } catch (e) {
      // Silently fail
    }
  }
}

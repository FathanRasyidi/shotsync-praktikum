import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:danielshotsync/config/supabase_config.dart';
import 'package:danielshotsync/screens/main/ai_chat_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_tab.dart';
import 'projects_tab.dart';
import 'notes_tab.dart';
import 'profile_tab.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:danielshotsync/main.dart';
import 'package:danielshotsync/screens/main/login.dart';
import 'package:danielshotsync/screens/main/notifications_page.dart';

// Controller untuk HomePage
class HomeController extends GetxController {
  var selectedIndex = 0.obs;
  RealtimeChannel? _notificationChannel;
  Timer? _pendingTaskTimer;
  var unreadCount = 0.obs;

  final List<String> menuTitles = [
    'Dashboard',
    'Projects',
    'AI Assistant',
    'Notes',
    'Profile',
  ];

  @override
  void onInit() {
    super.onInit();
    _listenToMyNotifications();
    _fetchUnreadCount();
    _schedulePendingTaskReminder();
  }

  @override
  void onClose() {
    _notificationChannel?.unsubscribe();
    _pendingTaskTimer?.cancel();
    super.onClose();
  }

  void _schedulePendingTaskReminder() {
    _pendingTaskTimer = Timer(const Duration(seconds: 10), () {
      _runPendingTaskCheck();
    });
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final userData = await LoginController.getUserData();
      final String? myUserId = userData['user_id'];

      if (myUserId == null || myUserId.isEmpty) {
        unreadCount.value = 0;
        return;
      }

      final response = await SupabaseConfig.client
          .from('notifications')
          .select('id')
          .eq('user_id_penerima', myUserId)
          .eq('is_read', false);

      unreadCount.value = (response as List).length;
    } catch (e) {
      unreadCount.value = 0;
    }
  }

  Future<void> _listenToMyNotifications() async {
    try {
      final userData = await LoginController.getUserData();
      final String? myUserId = userData['user_id'];

      if (myUserId == null || myUserId.isEmpty) return;

      _notificationChannel = SupabaseConfig.client
          .channel('notifications:$myUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id_penerima',
              value: myUserId,
            ),
            callback: (payload) {
              try {
                final newRecord = payload.newRecord;
                final String message =
                    newRecord['message']?.toString() ?? 'You have a new update';

                _showLocalNotification(
                  title: 'Task Update!',
                  message: message,
                  channelId: 'task_completed_channel',
                  channelName: 'Task Updates',
                  channelDescription: 'Notifications when tasks are completed',
                );

                _fetchUnreadCount();
              } catch (e) {
                // Handle error silently
              }
            },
          )
          .subscribe();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _runPendingTaskCheck() async {
    try {
      final userData = await LoginController.getUserData();
      final String? myUserId = userData['user_id'];

      if (myUserId == null || myUserId.isEmpty) return;

      final response = await SupabaseConfig.client
          .from('tasks')
          .select('title, status')
          .eq('assigned_to', myUserId)
          .neq('status', 'completed');

      final List<dynamic> pendingTasks = response as List;

      if (pendingTasks.isEmpty) return;

      String message;
      if (pendingTasks.length == 1) {
        message = 'You have 1 pending task: "${pendingTasks.first['title']}"';
      } else {
        message = 'You have ${pendingTasks.length} pending tasks to complete.';
      }

      await _showLocalNotification(
        title: 'Task Reminder',
        message: message,
        channelId: 'pending_task_reminder',
        channelName: 'Pending Task Reminders',
        channelDescription: 'Reminders for incomplete tasks',
      );
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String message,
    required String channelId,
    required String channelName,
    String? channelDescription,
  }) async {
    try {
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription ?? channelName,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@drawable/ic_notification',
            color: const Color(0xFF00D9FF),
          );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      final int notificationId = channelId == 'pending_task_reminder'
          ? 999
          : DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        message,
        platformDetails,
      );
    } catch (e) {
      // Handle error silently
    }
  }

  void changeTab(int index) {
    selectedIndex.value = index;
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.put(HomeController());

    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F1828),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        toolbarHeight: 70,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF00D9FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.movie_filter_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ShotSync',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Film Production',
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
                    Obx(() {
            final hasUnread = controller.unreadCount.value > 0;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none, color: Colors.white),
                  onPressed: () async {
                    await Get.to(() => NotificationsPage());
                    // Refresh badge setelah kembali dari halaman notifikasi
                    controller._fetchUnreadCount();
                  },
                ),
                if (hasUnread)
                  Positioned(
                    right: 10,
                    top: 12,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16), // Space below AppBar
                Expanded(
                  child: Container(
                    color: const Color(0xFF0F1828),
                    child: Obx(
                      () => HeroMode(
                        enabled: false,
                        child: IndexedStack(
                          index: controller.selectedIndex.value,
                          children: const [
                            DashboardTab(),
                            ProjectsTab(),
                            AIChatPage(),
                            NotesTab(),
                            ProfileTab(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Obx(
        () => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF152033),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildNavItem(
                      icon: Icons.dashboard_outlined,
                      label: 'Dashboard',
                      index: 0,
                      controller: controller,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: _buildNavItem(
                      icon: Icons.folder_outlined,
                      label: 'Projects',
                      index: 1,
                      controller: controller,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: _buildNavItem(
                      icon: Icons.auto_awesome,
                      label: 'AI',
                      index: 2,
                      controller: controller,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: _buildNavItem(
                      icon: Icons.note_outlined,
                      label: 'Notes',
                      index: 3,
                      controller: controller,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: _buildNavItem(
                      icon: Icons.person_outline,
                      label: 'Profile',
                      index: 4,
                      controller: controller,
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

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required HomeController controller,
  }) {
    final isSelected = controller.selectedIndex.value == index;

    return GestureDetector(
      onTap: () => controller.changeTab(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF00D9FF), Color(0xFF2196F3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF8B8B8B),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                height: 1.1,
                color: isSelected ? Colors.white : const Color(0xFF8B8B8B),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

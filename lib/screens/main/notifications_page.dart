import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:danielshotsync/screens/main/login.dart';
import 'package:danielshotsync/config/supabase_config.dart';

class NotificationsController extends GetxController {
  var notifications = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;
  String userId = '';

  @override
  void onInit() {
    super.onInit();
    initializeDateFormatting('id_ID', null).then((_) {
      loadNotifications();
    });
  }

  Future<void> loadNotifications() async {
    isLoading.value = true;
    final userData = await LoginController.getUserData();
    userId = userData['user_id'] ?? '';
    if (userId.isEmpty) {
      notifications.value = [];
      isLoading.value = false;
      return;
    }
    final response = await SupabaseConfig.client
        .from('notifications')
        .select()
        .eq('user_id_penerima', userId)
        .order('created_at', ascending: false);
    notifications.value = List<Map<String, dynamic>>.from(response);
    isLoading.value = false;
  }

  Future<void> deleteNotification(int index) async {
    final notif = notifications[index];
    final notifId = notif['id'];
    notifications.removeAt(index);
    try {
      await SupabaseConfig.client
          .from('notifications')
          .delete()
          .eq('id', notifId);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete notification: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> markAsRead(int index) async {
    final notif = notifications[index];
    if (notif['is_read'] == true) return;
    await SupabaseConfig.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notif['id']);
    notifications[index]['is_read'] = true;
    notifications.refresh();
  }
}

class NotificationsPage extends StatelessWidget {
  NotificationsPage({super.key});
  final NotificationsController controller = Get.put(NotificationsController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1828),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Obx(
        () => controller.isLoading.value
            ? const Center(child: CircularProgressIndicator())
            : controller.notifications.isEmpty
            ? RefreshIndicator(
                onRefresh: controller.loadNotifications,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.notifications_off_outlined,
                            color: Color(0xFF8B8B8B),
                            size: 64,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No notifications available.',
                            style: TextStyle(
                              color: Color(0xFF8B8B8B),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: controller.loadNotifications,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  itemCount: controller.notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final notif = controller.notifications[i];
                    final isRead = notif['is_read'] == true;
                    final createdAt =
                        DateTime.tryParse(notif['created_at'] ?? '') ??
                        DateTime.now();
                    return Dismissible(
                      key: ValueKey(notif['id']),
                      direction: DismissDirection.startToEnd,
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        color: Colors.transparent, // Tidak ada background merah
                        child: const Icon(Icons.delete, color: Colors.red),
                      ),
                      onDismissed: (direction) async {
                        await controller.deleteNotification(i);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isRead
                              ? const Color(0xFF19233A)
                              : const Color(0xFF2196F3).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isRead
                                ? Colors.transparent
                                : const Color(0xFF2196F3),
                            width: isRead ? 0.5 : 1.2,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Icon(
                            isRead
                                ? Icons.notifications_none
                                : Icons.notifications_active,
                            color: isRead
                                ? Colors.white54
                                : const Color(0xFF00D9FF),
                            size: 28,
                          ),
                          title: Text(
                            notif['title'] ?? '-',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: isRead
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          subtitle:
                              notif['message'] != null &&
                                  notif['message'].toString().isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    notif['message'],
                                    style: const TextStyle(
                                      color: Color(0xFF8B8B8B),
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : null,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Builder(
                                builder: (context) {
                                  final wib = createdAt.toUtc().add(
                                    const Duration(hours: 7),
                                  );
                                  final nowWib = DateTime.now().toUtc().add(
                                    const Duration(hours: 7),
                                  );
                                  final isToday =
                                      wib.year == nowWib.year &&
                                      wib.month == nowWib.month &&
                                      wib.day == nowWib.day;
                                  final isYesterday =
                                      wib.year == nowWib.year &&
                                      wib.month == nowWib.month &&
                                      wib.day == nowWib.day - 1;
                                  String dateLabel;
                                  if (isToday) {
                                    dateLabel = 'Today';
                                  } else if (isYesterday) {
                                    dateLabel = 'Yesterday';
                                  } else {
                                    dateLabel = DateFormat(
                                      'dd MMM yyyy',
                                      'id_ID',
                                    ).format(wib);
                                  }
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${DateFormat('HH:mm', 'id_ID').format(wib)} WIB',
                                        style: const TextStyle(
                                          color: Color(0xFF8B8B8B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        dateLabel,
                                        style: const TextStyle(
                                          color: Color(0xFF8B8B8B),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                          onTap: () async {
                            await controller.markAsRead(i);
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../models/chat_message.dart';
import '../../models/project.dart';
import '../../models/user.dart' as app_user;
import '../../controllers/notification_controller.dart';
import '../../widgets/profile_avatar.dart';

/// Controller untuk Chat Page - ngatur semua logic chat di project
class ChatController extends GetxController {
  final String projectId; // ID project yang lagi dibuka
  var messages =
      <ChatMessage>[].obs; // List semua pesan, pake .obs biar reactive
  var isLoading = false.obs; // Buat tampilan loading
  var currentUserId = ''.obs; // ID user yang lagi login
  var currentUserName = ''.obs; // Nama user yang lagi login
  var project = Rx<Project?>(null); // Project info
  var users = <app_user.User>[].obs; // List semua user
  final TextEditingController messageController =
      TextEditingController(); // Controller buat input text
  RealtimeChannel? _messageChannel; // Channel buat realtime message (websocket)

  ChatController(this.projectId);

  @override
  void onInit() {
    super.onInit();
    _initializeUser(); // Pas controller dibuat, langsung load data user
  }

  @override
  void onReady() {
    super.onReady();
    // Pas halaman udah siap, langsung mark semua pesan jadi "sudah dibaca"
    _markMessagesAsRead();
  }

  @override
  void onClose() {
    messageController.dispose(); // Bersihin text controller biar ga memory leak
    _messageChannel?.unsubscribe(); // Unsubscribe dari realtime channel
    super.onClose();
  }

  /// Tandain semua pesan di project ini jadi "sudah dibaca"
  /// Ini yang bikin badge merah hilang pas kita buka chat
  Future<void> _markMessagesAsRead() async {
    if (currentUserId.value.isEmpty) return; // Kalo user ID kosong, skip aja

    try {
      // Cari NotificationController yang udah ada
      final notifController = Get.find<NotificationController>();
      await notifController.markProjectMessagesAsRead(projectId);
    } catch (e) {
      // Kalo belum ada NotificationController, bikin yang baru
      try {
        final notifController = Get.put(NotificationController());
        await notifController.markProjectMessagesAsRead(projectId);
      } catch (e2) {
        // Kalo gagal juga, diemin aja ga papa (silently fail)
      }
    }
  }

  /// Load data user yang lagi login dari SharedPreferences (storage lokal)
  Future<void> _initializeUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Ambil user ID dan nama dari storage
      currentUserId.value = prefs.getString('user_id') ?? '';
      currentUserName.value = prefs.getString('user_name') ?? 'Unknown User';

      // Kalo user ID ada, langsung load pesan dan subscribe realtime
      if (currentUserId.value.isNotEmpty) {
        await Future.wait([
          loadMessages(), // Load semua pesan dari database
          _fetchProjectDetail(), // Load project detail
          _fetchUsers(), // Load semua user
        ]);
        _subscribeToMessages(); // Mulai dengerin pesan baru secara realtime
      }
    } catch (e) {
      print('Error initializing user: $e');
      Get.snackbar(
        'Error',
        'Failed to load user data',
        backgroundColor: const Color(0xFF152033),
        colorText: Colors.white,
      );
    }
  }

  /// Fetch project detail
  Future<void> _fetchProjectDetail() async {
    try {
      final response = await SupabaseConfig.client
          .from('projects')
          .select()
          .eq('id', projectId)
          .single();

      project.value = Project.fromJson(response);
    } catch (e) {
      print('Error fetching project: $e');
    }
  }

  /// Fetch all users
  Future<void> _fetchUsers() async {
    try {
      final response = await SupabaseConfig.client.from('users').select();

      users.value = (response as List)
          .map((json) => app_user.User.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching users: $e');
    }
  }

  /// Get user by ID
  app_user.User? getUserById(String userId) {
    try {
      return users.firstWhere((user) => user.id == userId);
    } catch (e) {
      return null;
    }
  }

  /// Load semua pesan chat dari database Supabase
  Future<void> loadMessages() async {
    isLoading.value = true; // Tampilkan loading indicator

    try {
      // Query ke database: ambil semua pesan di project ini
      final response = await SupabaseConfig.client
          .from('project_messages') // Dari tabel project_messages
          .select() // Ambil semua kolom
          .eq('project_id', projectId) // Filter: hanya pesan di project ini
          .order('created_at', ascending: true); // Urut dari lama ke baru

      // Convert JSON jadi object ChatMessage
      messages.value = (response as List)
          .map((json) => ChatMessage.fromJson(json, currentUserId.value))
          .toList();
    } catch (e) {
      print('Error loading messages: $e');
      Get.snackbar(
        'Error',
        'Failed to load messages: $e',
        backgroundColor: const Color(0xFF152033),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false; // Matiin loading
    }
  }

  /// Subscribe ke realtime messages - ini yang bikin pesan langsung muncul tanpa refresh
  /// Pake Supabase Realtime (WebSocket)
  void _subscribeToMessages() {
    _messageChannel = SupabaseConfig.client
        .channel(
          'project_messages:$projectId',
        ) // Buat channel khusus project ini
        .onPostgresChanges(
          event:
              PostgresChangeEvent.insert, // Dengerin event INSERT (pesan baru)
          schema: 'public',
          table: 'project_messages', // Dari tabel project_messages
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'project_id',
            value: projectId, // Hanya pesan di project ini aja
          ),
          callback: (payload) {
            // Pas ada pesan baru, langsung tambahin ke list
            final newMessage = ChatMessage.fromJson(
              payload.newRecord, // Data pesan baru dari database
              currentUserId.value,
            );
            messages.add(newMessage); // Tambahin ke list, otomatis muncul di UI
          },
        )
        .subscribe(); // Mulai dengerin
  }

  /// Kirim pesan baru ke database
  Future<void> sendMessage() async {
    if (messageController.text.trim().isEmpty)
      return; // Kalo kosong, jangan kirim

    final messageText = messageController.text.trim(); // Ambil text dari input
    messageController.clear(); // Kosongin input box

    try {
      // Insert pesan baru ke database
      await SupabaseConfig.client.from('project_messages').insert({
        'project_id': projectId, // Project mana
        'sender_id': currentUserId.value, // Siapa yang kirim
        'sender_name': currentUserName.value, // Nama pengirim
        'message': messageText, // Isi pesannya
        'created_at': DateTime.now().toIso8601String(),
        // read_by otomatis jadi array kosong
      });
      // Setelah insert, realtime subscription bakal dapet notif
      // dan pesan otomatis muncul di semua user yang buka chat ini
    } catch (e) {
      print('Error sending message: $e');
      Get.snackbar(
        'Error',
        'Failed to send message: $e',
        backgroundColor: const Color(0xFF152033),
        colorText: Colors.white,
      );
    }
  }
}

/// Halaman Chat untuk Project
class ChatPage extends StatelessWidget {
  final String projectId;
  final String projectName;

  const ChatPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ChatController(projectId));
    final dateFormat = DateFormat('HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFF0F1828),
      appBar: AppBar(
        backgroundColor: const Color(0xFF152033),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              projectName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              'Project Chat',
              style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 12),
            ),
          ],
        ),
        actions: [
          Obx(() {
            // Show staff list button only when project is loaded
            if (controller.project.value == null) {
              return const SizedBox.shrink();
            }

            return IconButton(
              icon: const Icon(Icons.people_outline, color: Colors.white),
              tooltip: 'Project Staff',
              onPressed: () {
                _showStaffBottomSheet(context, controller);
              },
            );
          }),
        ],
      ),
      body: Column(
        children: [
          // Chat Messages List - Area buat nampilin semua pesan
          Expanded(
            child: Obx(() {
              // Kalo lagi loading, tampilkan loading indicator
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
                );
              }

              // Kalo belum ada pesan, tampilkan empty state
              if (controller.messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start the conversation!',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Kalo ada pesan, tampilkan dalam list
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                reverse: true, // Reverse biar pesan terbaru di bawah
                itemCount: controller.messages.length,
                itemBuilder: (context, index) {
                  // Balik lagi listnya biar urutan bener
                  final message = controller.messages.reversed.toList()[index];
                  return _buildMessageBubble(message, dateFormat);
                },
              );
            }),
          ),

          // Message Input - Area buat ngetik dan kirim pesan
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF152033),
              border: Border(
                top: BorderSide(color: Color(0xFF1E2A3A), width: 1),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Text field buat ngetik pesan
                  Expanded(
                    child: TextField(
                      controller: controller.messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type a message...', // Placeholder
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F1828),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null, // Bisa multiline
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) =>
                          controller.sendMessage(), // Enter = kirim
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tombol Send dengan gradient biru
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF00D9FF), Color(0xFF2196F3)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: controller.sendMessage, // Klik = kirim
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build bubble pesan - tampilan chat bubble kayak di WhatsApp
  Widget _buildMessageBubble(ChatMessage message, DateFormat dateFormat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        // Kalo pesan dari gue, taruh di kanan. Kalo dari orang lain, di kiri
        mainAxisAlignment: message.isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar pengirim (kalo bukan pesan gue)
          if (!message.isMe) ...[
            ProfileAvatar(
              userId: message.senderId,
              userName: message.senderName,
              radius: 16,
              backgroundColor: const Color(0xFF00D9FF),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!message.isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      message.senderName,
                      style: const TextStyle(
                        color: Color(0xFF8B8B8B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: message.isMe
                        ? const Color(0xFF00D9FF)
                        : const Color(0xFF152033),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: message.isMe
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: message.isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    message.message,
                    style: TextStyle(
                      color: message.isMe ? Colors.white : Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Text(
                    dateFormat.format(message.timestamp),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (message.isMe) ...[
            const SizedBox(width: 8),
            ProfileAvatar(
              userId: message.senderId,
              userName: message.senderName,
              radius: 16,
              backgroundColor: const Color(0xFF2196F3),
            ),
          ],
        ],
      ),
    );
  }

  // Show staff list in bottom sheet
  void _showStaffBottomSheet(BuildContext context, ChatController controller) {
    final project = controller.project.value;
    if (project == null) return;

    final allStaffIds = <String>{
      project.createdBy, // Owner
      ...project.projectAdministrator, // Administrators
      ...project.staff, // Staff
    }.toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF152033),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF8B8B8B).withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.people,
                    color: Color(0xFF00D9FF),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Project Staff',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D9FF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${allStaffIds.length} ${allStaffIds.length == 1 ? 'Person' : 'People'}',
                      style: const TextStyle(
                        color: Color(0xFF00D9FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              color: Color(0xFF1F2937),
              height: 1,
              thickness: 1,
            ),
            // Staff list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: allStaffIds.length,
                separatorBuilder: (context, index) => const Divider(
                  color: Color(0xFF1F2937),
                  height: 1,
                  thickness: 1,
                  indent: 68,
                ),
                itemBuilder: (context, index) {
                  final userId = allStaffIds[index];
                  final user = controller.getUserById(userId);
                  final userName = user?.fullName ?? 'Unknown';
                  final isOwner = userId == project.createdBy;
                  final isAdmin = project.projectAdministrator.contains(userId);

                  String roleLabel = '';
                  Color roleColor = const Color(0xFF8B8B8B);
                  Color avatarColor = const Color(0xFF2196F3);

                  if (isOwner) {
                    roleLabel = 'Owner';
                    roleColor = const Color(0xFFFFD700);
                    avatarColor = const Color(0xFFFFD700);
                  } else if (isAdmin) {
                    roleLabel = 'Administrator';
                    roleColor = const Color(0xFF00D9FF);
                    avatarColor = const Color(0xFF00D9FF);
                  } else {
                    roleLabel = 'Staff';
                    roleColor = const Color(0xFF8B8B8B);
                    avatarColor = const Color(0xFF2196F3);
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        ProfileAvatar(
                          userId: userId,
                          userName: userName,
                          radius: 22,
                          backgroundColor: avatarColor,
                        ),
                        const SizedBox(width: 16),
                        // User info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                roleLabel,
                                style: TextStyle(
                                  color: roleColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


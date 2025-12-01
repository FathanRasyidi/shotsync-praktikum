import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:danielshotsync/config/supabase_config.dart';
import 'package:danielshotsync/models/task.dart';
import 'package:danielshotsync/screens/main/login.dart';
import 'package:danielshotsync/models/equipment.dart';
import 'package:danielshotsync/models/user.dart';
import 'package:danielshotsync/models/scene.dart';
import 'package:danielshotsync/models/project.dart';
import 'package:danielshotsync/screens/Operation/edit_scene.dart';
import 'package:danielshotsync/widgets/map_location_viewer.dart';

// Controller buat handle logic Tasks Tab
class TasksController extends GetxController {
  final String sceneId;

  var tasks = <Task>[].obs;
  var equipments = <Equipment>[].obs;
  var users = <User>[].obs;
  var scene = Rx<Scene?>(null);
  var project = Rx<Project?>(null);
  var userRole = ''.obs;
  var currentUserId = ''.obs;
  var isLoading = true.obs;

  // Currency conversion variables
  var selectedCurrency = 'IDR'.obs;
  var exchangeRates = <String, double>{}.obs;
  var isLoadingRates = false.obs;

  // Available currencies
  final availableCurrencies = [
    {'code': 'IDR', 'name': 'Indonesian Rupiah', 'symbol': 'Rp'},
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'GBP', 'name': 'British Pound', 'symbol': '£'},
    {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
    {'code': 'SGD', 'name': 'Singapore Dollar', 'symbol': 'S\$'},
    {'code': 'MYR', 'name': 'Malaysian Ringgit', 'symbol': 'RM'},
  ];

  // Timezone conversion variables
  var selectedTimezone = 'WIB'.obs;

  // Available timezones
  final availableTimezones = [
    {'code': 'WIB', 'name': 'Western Indonesian Time', 'offset': 'UTC+7'},
    {'code': 'WITA', 'name': 'Central Indonesian Time', 'offset': 'UTC+8'},
    {'code': 'WIT', 'name': 'Eastern Indonesian Time', 'offset': 'UTC+9'},
    {'code': 'London', 'name': 'London Time', 'offset': 'UTC+0'},
    {'code': 'Tokyo', 'name': 'Tokyo Time', 'offset': 'UTC+9'},
  ];

  TasksController({required this.sceneId});

  @override
  void onInit() {
    super.onInit();
    _loadUserData();
    _fetchExchangeRates(); // Fetch exchange rates on init
  }

  /// Load user data dari SharedPreferences
  /// Ambil user_role & user_id untuk permission checking
  Future<void> _loadUserData() async {
    try {
      final userData = await LoginController.getUserData();
      userRole.value = userData['user_role'] ?? '';
      currentUserId.value = userData['user_id'] ?? '';

      // Load scene detail
      await _fetchSceneDetail();

      await Future.wait([_fetchTasks(), _fetchEquipments(), _fetchUsers()]);
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Error',
        'Failed to load data. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Fetch scene detail by sceneId
  /// juga fetch project info setelah dapat scene data
  Future<void> _fetchSceneDetail() async {
    try {
      final response = await SupabaseConfig.client
          .from('scenes')
          .select()
          .eq('id', sceneId)
          .single();

      scene.value = Scene.fromJson(response);

      // Fetch project info after getting scene
      if (scene.value != null) {
        await _fetchProjectDetail(scene.value!.projectId);
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to fetch scene. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Fetch project detail by projectId
  Future<void> _fetchProjectDetail(String projectId) async {
    try {
      final response = await SupabaseConfig.client
          .from('projects')
          .select()
          .eq('id', projectId)
          .single();

      project.value = Project.fromJson(response);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to fetch project. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Fetch tasks untuk scene tertentu
  Future<void> _fetchTasks() async {
    isLoading.value = true;
    try {
      final response = await SupabaseConfig.client
          .from('tasks')
          .select()
          .eq('scene_id', sceneId)
          .order('due_date', ascending: true);

      tasks.value = (response as List)
          .map((json) => Task.fromJson(json))
          .toList();
    } catch (e) {
      tasks.value = [];
      Get.snackbar(
        'Error',
        'Failed to fetch tasks. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Fetch equipment untuk scene tertentu
  Future<void> _fetchEquipments() async {
    try {
      final response = await SupabaseConfig.client
          .from('equipment')
          .select()
          .eq('scene_id', sceneId);

      equipments.value = (response as List)
          .map((json) => Equipment.fromJson(json))
          .toList();
    } catch (e) {
      equipments.value = [];
      Get.snackbar(
        'Error',
        'Failed to fetch equipment. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Fetch all users buat mapping task assignee
  Future<void> _fetchUsers() async {
    try {
      final response = await SupabaseConfig.client.from('users').select();

      users.value = (response as List)
          .map((json) => User.fromJson(json))
          .toList();
    } catch (e) {
      users.value = [];
      Get.snackbar(
        'Error',
        'Failed to fetch users. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Update task status (pending, in-progress, completed)
  Future<void> updateTaskStatus(Task task, String newStatus) async {
    try {
      await SupabaseConfig.client
          .from('tasks')
          .update({'status': newStatus})
          .eq('id', task.id);

      //untuk notifikasi
      if (newStatus == 'completed' && project.value != null) {
        final String projectOwnerId = project.value!.createdBy;

        final userData = await LoginController.getUserData();
        final String taskCompleterName = userData['user_name'] ?? 'Staff';
        final String notificationMessage =
            'Task "${task.title}" has been completed by $taskCompleterName.';

        await SupabaseConfig.client.from('notifications').insert({
          'user_id_penerima': projectOwnerId,
          'title': 'Task Completed',
          'message': notificationMessage,
          'created_at': DateTime.now()
              .subtract(const Duration(hours: 7))
              .toIso8601String(),
          'is_read': false,
        });
      }

      // Update local state
      final index = tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        tasks[index] = Task(
          id: task.id,
          sceneId: task.sceneId,
          title: task.title,
          description: task.description,
          assignedTo: task.assignedTo,
          status: newStatus,
          dueDate: task.dueDate,
        );
        tasks.refresh();
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update task status',
        duration: Duration(seconds: 1),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Get user object by userId
  User? getUserById(String? userId) {
    if (userId == null) return null;
    try {
      return users.firstWhere((user) => user.id == userId);
    } catch (e) {
      return null;
    }
  }

  /// Check apakah current user adalah project administrator
  bool get isProjectAdministrator {
    return project.value != null &&
        currentUserId.value.isNotEmpty &&
        project.value!.projectAdministrator.contains(currentUserId.value);
  }

  /// Check apakah current user adalah project owner
  bool get isProjectOwner {
    return project.value != null &&
        currentUserId.value.isNotEmpty &&
        project.value!.createdBy == currentUserId.value;
  }

  /// Check apakah current user memiliki akses owner (owner atau administrator)
  bool get hasOwnerAccess {
    return isProjectOwner || isProjectAdministrator;
  }

  /// Update scene status (pending, on progress, completed)
  Future<void> updateSceneStatus(String newStatus) async {
    try {
      // Update scene status
      await SupabaseConfig.client
          .from('scenes')
          .update({'status': newStatus})
          .eq('id', sceneId);

      // Reload scene detail
      await _fetchSceneDetail();

      // Update project status based on all scenes
      await updateProjectStatus();

      Get.snackbar(
        'Success',
        'Scene status updated successfully',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update status',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Update project status berdasarkan progress scene
  Future<void> updateProjectStatus() async {
    if (project.value == null) return;

    try {
      // Get all scenes in this project
      final scenesResponse = await SupabaseConfig.client
          .from('scenes')
          .select()
          .eq('project_id', project.value!.id);

      final scenes = scenesResponse as List;
      final totalScenes = scenes.length;

      if (totalScenes == 0) return;

      final completedScenes = scenes
          .where((s) => s['status'] == 'completed')
          .length;
      final progress = (completedScenes / totalScenes * 100).round();

      // Determine status based on progress
      String projectStatus;
      if (progress == 0) {
        projectStatus = 'Pending';
      } else if (progress < 100) {
        projectStatus = 'On Progress';
      } else {
        projectStatus = 'Completed';
      }

      // Update project status to database
      await SupabaseConfig.client
          .from('projects')
          .update({
            'status': projectStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', project.value!.id);

      // Reload project detail
      await _fetchProjectDetail(project.value!.id);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update project status. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Get page title for scene detail
  String get pageTitle {
    if (scene.value != null) {
      return 'Scene ${scene.value!.sceneNumber} Detail';
    }
    return 'Scene Detail';
  }

  /// Get empty message
  String get emptyMessage {
    return 'No tasks for this scene yet';
  }

  /// Calculate total equipment cost
  /// Sum dari (price * quantity) semua equipment
  double get totalEquipmentCost {
    return equipments.fold<double>(
      0.0,
      (sum, eq) => sum + eq.price * eq.quantity,
    );
  }

  /// Fetch ExchangeRate API
  Future<void> _fetchExchangeRates() async {
    isLoadingRates.value = true;
    try {
      final response = await http.get(
        Uri.parse(
          'https://v6.exchangerate-api.com/v6/362c3f066adf570219a16344/latest/IDR',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['result'] == 'success') {
          final rates = data['conversion_rates'] as Map<String, dynamic>;

          // Convert to Map<String, double>
          exchangeRates.value = rates.map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to fetch exchange rates. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoadingRates.value = false;
    }
  }

  /// Convert amount from IDR to selected currency
  double convertCurrency(double amountInIDR) {
    if (selectedCurrency.value == 'IDR') {
      return amountInIDR;
    }

    final rate = exchangeRates[selectedCurrency.value];
    if (rate == null) {
      return amountInIDR;
    }

    return amountInIDR * rate;
  }

  /// Get currency symbol for selected currency
  String get currencySymbol {
    final currency = availableCurrencies.firstWhere(
      (c) => c['code'] == selectedCurrency.value,
      orElse: () => availableCurrencies[0],
    );
    return currency['symbol'] as String;
  }

  /// Format currency with intl NumberFormat
  String formatCurrency(double amount) {
    final convertedAmount = convertCurrency(amount);

    // Determine decimal digits based on currency
    int decimalDigits = 0;
    if (selectedCurrency.value == 'IDR' || selectedCurrency.value == 'JPY') {
      decimalDigits = 0; // No decimals for IDR and JPY
    } else {
      decimalDigits = 2; // 2 decimals for USD, EUR, etc.
    }

    final formatter = NumberFormat.currency(
      symbol: '',
      decimalDigits: decimalDigits,
      locale: 'en_US',
    );

    return '$currencySymbol ${formatter.format(convertedAmount)}';
  }

  /// Change selected currency
  void changeCurrency(String currencyCode) {
    selectedCurrency.value = currencyCode;
  }

  /// Input datetime diasumsikan sudah dalam WIB (UTC+7) dari database
  /// Database menyimpan dalam UTC, di-load sebagai WIB (+7 jam)
  DateTime convertToTimezone(DateTime dateTime) {
    // dateTime sudah dalam WIB (UTC+7)
    // Hitung offset target timezone dari UTC
    int targetOffsetFromUTC;

    switch (selectedTimezone.value) {
      case 'WIB':
        targetOffsetFromUTC = 7; // UTC+7
        break;
      case 'WITA':
        targetOffsetFromUTC = 8; // UTC+8
        break;
      case 'WIT':
        targetOffsetFromUTC = 9; // UTC+9
        break;
      case 'London':
        targetOffsetFromUTC = 0; // UTC+0 (GMT)
        break;
      case 'Tokyo':
        targetOffsetFromUTC = 9; // UTC+9 (JST)
        break;
      default:
        targetOffsetFromUTC = 7; // Default: WIB
    }

    // 1. Konversi dari WIB ke UTC (kurangi 7 jam)
    final utcDateTime = dateTime.subtract(const Duration(hours: 7));
    // 2. Konversi dari UTC ke target timezone
    final targetDateTime = utcDateTime.add(
      Duration(hours: targetOffsetFromUTC),
    );

    return targetDateTime;
  }

  /// Format datetime
  String formatDateTimeWithTimezone(DateTime dateTime) {
    final convertedTime = convertToTimezone(dateTime);

    final dateStr =
        '${convertedTime.day.toString().padLeft(2, '0')}-'
        '${convertedTime.month.toString().padLeft(2, '0')}-'
        '${convertedTime.year}';

    final timeStr =
        '${convertedTime.hour.toString().padLeft(2, '0')}:'
        '${convertedTime.minute.toString().padLeft(2, '0')}';

    return '$dateStr • $timeStr ${selectedTimezone.value}';
  }

  /// Change selected timezone
  void changeTimezone(String timezoneCode) {
    selectedTimezone.value = timezoneCode;
  }

  /// Delete scene (owner only)
  Future<void> deleteScene() async {
    try {
      // Confirm deletion dengan UI modern
      final sceneTitle = scene.value?.title ?? 'this scene';
      final confirm = await Get.dialog<bool>(
        AlertDialog(
          backgroundColor: const Color(0xFF152033),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1F2937), width: 1),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_outlined, color: Color(0xFFFF5252), size: 28),
              SizedBox(width: 12),
              Text(
                'Delete Scene',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
              children: [
                const TextSpan(text: 'Are you sure you want to delete '),
                TextSpan(
                  text: '"$sceneTitle"',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const TextSpan(
                  text:
                      ' ?\nAll tasks and equipment in this scene will also be deleted. This action cannot be undone.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8B8B8B),
              ),
              child: const Text('Cancel'),
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ElevatedButton(
                onPressed: () => Get.back(result: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      isLoading.value = true;

      // Delete scene (cascade delete will handle tasks and equipment)
      await SupabaseConfig.client
          .from('scenes')
          .delete()
          .eq('id', scene.value!.id);

      Get.back(result: true); // Return to previous screen

      Get.snackbar(
        'Success',
        'Scene successfully deleted',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      isLoading.value = false;

      Get.snackbar(
        'Error',
        'Failed to delete scene. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}

class TasksTab extends StatelessWidget {
  final String sceneId;

  const TasksTab({super.key, required this.sceneId});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(TasksController(sceneId: sceneId), tag: sceneId);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1828),
      appBar: AppBar(
        backgroundColor: const Color(0xFF152033),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Obx(
          () => Text(
            controller.pageTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          Obx(() {
            // Check if user is project owner or administrator
            final hasAccess = controller.hasOwnerAccess;

            if (hasAccess) {
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                color: const Color(0xFF152033),
                onSelected: (value) async {
                  if (value == 'edit') {
                    // Navigate to Edit Scene
                    final result = await Get.to(
                      () => EditScenePage(scene: controller.scene.value!),
                    );

                    // Refresh if edited
                    if (result == true) {
                      controller._fetchSceneDetail();
                      controller._fetchTasks();
                      controller._fetchEquipments();
                    }
                  } else if (value == 'delete') {
                    // Delete scene
                    await controller.deleteScene();
                  } else if (value == 'status_waiting') {
                    await controller.updateSceneStatus('pending');
                  } else if (value == 'status_on_progress') {
                    await controller.updateSceneStatus('on progress');
                  } else if (value == 'status_completed') {
                    await controller.updateSceneStatus('completed');
                  }
                },
                itemBuilder: (context) => [
                  // Section: Update Status (compact)
                  const PopupMenuItem(
                    enabled: false,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 12,
                        right: 12,
                        top: 4,
                        bottom: 2,
                      ),
                      child: Text(
                        'Update Status',
                        style: TextStyle(
                          color: Color(0xFF8B8B8B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'status_waiting',
                    height: 36,
                    enabled: controller.scene.value?.status != 'pending',
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: controller.scene.value?.status == 'pending'
                              ? Color(0xFF4A5568)
                              : Color(0xFFFF9800),
                          size: 16,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Pending',
                          style: TextStyle(
                            color: controller.scene.value?.status == 'pending'
                                ? Color(0xFF4A5568)
                                : Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'status_on_progress',
                    height: 36,
                    enabled: controller.scene.value?.status != 'on progress',
                    child: Row(
                      children: [
                        Icon(
                          Icons.play_circle,
                          color: controller.scene.value?.status == 'on progress'
                              ? Color(0xFF4A5568)
                              : Color(0xFF2196F3),
                          size: 16,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'On Progress',
                          style: TextStyle(
                            color:
                                controller.scene.value?.status == 'on progress'
                                ? Color(0xFF4A5568)
                                : Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'status_completed',
                    height: 36,
                    enabled: controller.scene.value?.status != 'completed',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: controller.scene.value?.status == 'completed'
                              ? Color(0xFF4A5568)
                              : Color(0xFF4CAF50),
                          size: 16,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Completed',
                          style: TextStyle(
                            color: controller.scene.value?.status == 'completed'
                                ? Color(0xFF4A5568)
                                : Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    enabled: false,
                    child: Divider(color: Color(0xFF1F2937), height: 1),
                  ),
                  // Section: Actions
                  const PopupMenuItem(
                    value: 'edit',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Color(0xFF00D9FF), size: 18),
                        SizedBox(width: 10),
                        Text(
                          'Edit Scene',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Color(0xFFFF5252), size: 18),
                        SizedBox(width: 10),
                        Text(
                          'Delete Scene',
                          style: TextStyle(
                            color: Color(0xFFFF5252),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            } else {
              // Non-owner: show refresh button
              return IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  controller._fetchSceneDetail();
                  controller._fetchTasks();
                  controller._fetchEquipments();
                },
              );
            }
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFF00D9FF),
          backgroundColor: const Color(0xFF152033),
          onRefresh: () async {
            await controller._fetchTasks();
            await controller._fetchEquipments();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Project Info
                if (controller.project.value != null)
                  _buildProjectInfo(controller),

                // Scene Info
                if (controller.scene.value != null) _buildSceneInfo(controller),

                // Equipment Section
                if (controller.equipments.isNotEmpty)
                  _buildEquipmentSection(controller),

                // Tasks List
                _buildTasksList(controller),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildProjectInfo(TasksController controller) {
    final project = controller.project.value!;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF152033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00D9FF).withOpacity(0.3),
                  const Color(0xFF2196F3).withOpacity(0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.movie_outlined,
              color: Color(0xFF00D9FF),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Project',
                  style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  project.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (project.description != null &&
                    project.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    project.description!,
                    style: const TextStyle(
                      color: Color(0xFF8B8B8B),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: Color(0xFF8B8B8B),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatDate(project.startDate)} - ${_formatDate(project.endDate)}',
                style: const TextStyle(color: Color(0xFF8B8B8B), fontSize: 11),
                textAlign: TextAlign.end,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  Widget _buildSceneInfo(TasksController controller) {
    final scene = controller.scene.value!;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D9FF).withOpacity(0.2),
            const Color(0xFF2196F3).withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Scene Number + Title + Task Count
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    scene.sceneNumber.toString(),
                    style: const TextStyle(
                      color: Color(0xFF00D9FF),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scene.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (scene.description != null &&
                        scene.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          Get.bottomSheet(
                            isScrollControlled: true,
                            Container(
                              constraints: BoxConstraints(
                                maxHeight: Get.height * 0.8,
                              ),
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFF152033),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment
                                    .start, //text align disini
                                children: [
                                  Center(
                                    child: Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4A5568),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        color: Color(0xFF00D9FF),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Scene Description',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(
                                    color: Color(0xFF4A5568),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 16),
                                  Flexible(
                                    child: SingleChildScrollView(
                                      child: Text(
                                        scene.description!,
                                        style: const TextStyle(
                                          color: Color(0xFFCCCCCC),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D9FF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF00D9FF).withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Color(0xFF00D9FF),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'View Description',
                                style: TextStyle(
                                  color: Color(0xFF00D9FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Obx(
                () => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D9FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${controller.tasks.length} Tasks',
                    style: const TextStyle(
                      color: Color(0xFF00D9FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF1F2937), height: 1),
          const SizedBox(height: 12),

          // Scheduled DateTime Section
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: Color(0xFF00D9FF)),
              const SizedBox(width: 8),
              Expanded(
                child: const Text(
                  'Scheduled Time:',
                  style: TextStyle(
                    color: Color(0xFF8B8B8B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Timezone Selector
          Obx(
            () => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF00D9FF).withOpacity(0.3),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: controller.selectedTimezone.value,
                  dropdownColor: const Color(0xFF152033),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xFF00D9FF),
                    size: 20,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  isExpanded: true,
                  isDense: true,
                  items: controller.availableTimezones.map((tz) {
                    return DropdownMenuItem<String>(
                      value: tz['code'] as String,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.public,
                            size: 14,
                            color: Color(0xFF00D9FF),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${tz['code']} (${tz['offset']})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      controller.changeTimezone(newValue);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Display Converted Time
          Obx(
            () => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00D9FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF00D9FF).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 20,
                    color: Color(0xFF00D9FF),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.formatDateTimeWithTimezone(
                            scene.scheduledDate,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Shooting time in ${controller.selectedTimezone.value}',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Location Map Section (Readonly, Clickable)
          if (scene.latitude != null && scene.longitude != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF1F2937), height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: Color(0xFF00D9FF),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    scene.locationName ?? 'Location',
                    style: const TextStyle(
                      color: Color(0xFF8B8B8B),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                // Open full map view (readonly)
                Get.to(
                  () => MapLocationViewer(
                    sceneLocation: LatLng(scene.latitude!, scene.longitude!),
                    locationName: scene.locationName,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00D9FF).withOpacity(0.3),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(
                          scene.latitude!,
                          scene.longitude!,
                        ),
                        initialZoom: 15.0,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none, // Readonly
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.shotsync.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(scene.latitude!, scene.longitude!),
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Overlay to indicate clickable
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D9FF).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in, size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Tap to view',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEquipmentSection(TasksController controller) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF152033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 20,
                  color: Color(0xFF00D9FF),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Equipment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Obx(
                  () => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D9FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${controller.equipments.length} item',
                      style: const TextStyle(
                        color: Color(0xFF00D9FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1F2937), height: 1),
          Obx(
            () => ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.equipments.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: Color(0xFF1F2937), height: 1),
              itemBuilder: (context, index) {
                final equipment = controller.equipments[index];
                return _buildEquipmentItem(equipment, controller);
              },
            ),
          ),
          const Divider(color: Color(0xFF1F2937), height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Obx(
              () => Column(
                children: [
                  // Currency Selector Row
                  Row(
                    children: [
                      const Icon(
                        Icons.currency_exchange,
                        size: 16,
                        color: Color(0xFF8B8B8B),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Currency:',
                        style: TextStyle(
                          color: Color(0xFF8B8B8B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF00D9FF).withOpacity(0.3),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: controller.selectedCurrency.value,
                              dropdownColor: const Color(0xFF152033),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Color(0xFF00D9FF),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              isExpanded: true,
                              items: controller.availableCurrencies.map((
                                currency,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: currency['code'] as String,
                                  child: Row(
                                    children: [
                                      Text(
                                        currency['symbol'] as String,
                                        style: const TextStyle(
                                          color: Color(0xFF00D9FF),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          '${currency['code']} - ${currency['name']}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: controller.isLoadingRates.value
                                  ? null
                                  : (String? newValue) {
                                      if (newValue != null) {
                                        controller.changeCurrency(newValue);
                                      }
                                    },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Total Cost Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Cost',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (controller.isLoadingRates.value)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF00D9FF),
                          ),
                        )
                      else
                        Flexible(
                          child: Text(
                            controller.formatCurrency(
                              controller.totalEquipmentCost,
                            ),
                            style: const TextStyle(
                              color: Color(0xFF4CAF50),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                    ],
                  ),
                  // Exchange rate info (if not IDR)
                  if (controller.selectedCurrency.value != 'IDR' &&
                      controller.exchangeRates.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 12,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '1 IDR = ${controller.exchangeRates[controller.selectedCurrency.value]?.toStringAsFixed(6) ?? "N/A"} ${controller.selectedCurrency.value}',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentItem(Equipment equipment, TasksController controller) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF00D9FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getCategoryIcon(equipment.category),
              size: 24,
              color: const Color(0xFF00D9FF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  equipment.equipmentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (equipment.category != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D9FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          equipment.category!,
                          style: const TextStyle(
                            color: Color(0xFF00D9FF),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      'Qty: ${equipment.quantity}',
                      style: const TextStyle(
                        color: Color(0xFF8B8B8B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Unit Price
                Obx(
                  () => Text(
                    '${controller.formatCurrency(equipment.price)} / item',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Trailing: Total Price
          Obx(
            () => Text(
              controller.formatCurrency(equipment.price * equipment.quantity),
              style: const TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    return Icons.category;
  }

  Widget _buildTasksList(TasksController controller) {
    return Obx(() {
      if (controller.tasks.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.task_outlined,
                  size: 80,
                  color: const Color(0xFF8B8B8B).withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No tasks yet',
                  style: TextStyle(
                    color: Color(0xFF8B8B8B),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  controller.emptyMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF4A5568),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    size: 18,
                    color: Color(0xFF00D9FF),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Task List',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ...controller.tasks.map(
              (task) => _TaskCard(task: task, controller: controller),
            ),
          ],
        ),
      );
    });
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final TasksController controller;

  const _TaskCard({required this.task, required this.controller});

  @override
  Widget build(BuildContext context) {
    final assignedUser = controller.getUserById(task.assignedTo);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF152033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (task.isOverdue && task.status != 'completed')
              ? const Color(0xFFFF5252)
              : const Color(0xFF1F2937),
          width: (task.isOverdue && task.status != 'completed') ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _StatusBadge(task: task),
              ],
            ),
            if (task.description != null && task.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.description!,
                style: const TextStyle(color: Color(0xFF8B8B8B), fontSize: 14),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: (task.isOverdue && task.status != 'completed')
                      ? const Color(0xFFFF5252)
                      : const Color(0xFF00D9FF),
                ),
                const SizedBox(width: 6),
                Text(
                  task.dueDateText,
                  style: TextStyle(
                    color: (task.isOverdue && task.status != 'completed')
                        ? const Color(0xFFFF5252)
                        : const Color(0xFF8B8B8B),
                    fontSize: 13,
                  ),
                ),
                if (task.isOverdue && task.status != 'completed') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5252).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'OVERDUE',
                      style: TextStyle(
                        color: Color(0xFFFF5252),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (assignedUser != null) ...[
                  const Icon(Icons.person, size: 16, color: Color(0xFF00D9FF)),
                  const SizedBox(width: 6),
                  Text(
                    assignedUser.fullName,
                    style: const TextStyle(
                      color: Color(0xFF8B8B8B),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _ProgressSelector(task: task, controller: controller),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Task task;

  const _StatusBadge({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: task.statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: task.statusColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(task.statusIcon, size: 14, color: task.statusColor),
          const SizedBox(width: 4),
          Text(
            task.statusText,
            style: TextStyle(
              color: task.statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSelector extends StatelessWidget {
  final Task task;
  final TasksController controller;

  const _ProgressSelector({required this.task, required this.controller});

  @override
  Widget build(BuildContext context) {
    // Cek apakah current user adalah yang ditugaskan
    final isAssignedUser = task.assignedTo == controller.currentUserId.value;

    // Jika bukan user yang ditugaskan, tampilkan pesan read-only
    if (!isAssignedUser) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 16, color: Color(0xFF6B7280)),
            const SizedBox(width: 8),
            const Text(
              'Only task owner can change status',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    // Jika user yang ditugaskan, tampilkan tombol ubah status
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Change Status',
          style: TextStyle(
            color: Color(0xFF8B8B8B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _StatusButton(
              label: 'Pending',
              icon: Icons.pending_outlined,
              isSelected: task.status == 'pending',
              color: const Color(0xFFFF9800),
              onTap: () => controller.updateTaskStatus(task, 'pending'),
            ),
            const SizedBox(width: 8),
            _StatusButton(
              label: 'In Progress',
              icon: Icons.autorenew,
              isSelected: task.status == 'in-progress',
              color: const Color(0xFF2196F3),
              onTap: () => controller.updateTaskStatus(task, 'in-progress'),
            ),
            const SizedBox(width: 8),
            _StatusButton(
              label: 'Completed',
              icon: Icons.check_circle_outline,
              isSelected: task.status == 'completed',
              color: const Color(0xFF4CAF50),
              onTap: () => controller.updateTaskStatus(task, 'completed'),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.2)
                : const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : const Color(0xFF1F2937),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? color : const Color(0xFF4A5568),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : const Color(0xFF4A5568),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

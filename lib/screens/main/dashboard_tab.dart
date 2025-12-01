import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:danielshotsync/config/supabase_config.dart';
import 'package:danielshotsync/models/task.dart';
import 'package:danielshotsync/models/project.dart';
import 'package:danielshotsync/models/scene.dart';
import 'package:danielshotsync/models/equipment.dart';
import 'package:danielshotsync/screens/main/login.dart';
import 'package:danielshotsync/screens/main/tasks_tab.dart';
import 'package:danielshotsync/screens/main/detail/project_detail.dart';
import 'package:intl/intl.dart';

// Search result item model
class SearchResultItem {
  final String type; // 'project', 'scene', 'equipment', 'task'
  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final dynamic data; // Original object (Project, Scene, Equipment, atau Task)

  SearchResultItem({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.data,
  });
}

class DashboardController extends GetxController {
  var tasks = <Task>[].obs;
  var projects = <Project>[].obs;
  var scenes = <Scene>[].obs;
  var equipment = <Equipment>[].obs;
  var currentUserId = ''.obs;
  var isLoading = true.obs;

  var totalProjects = 0.obs;
  var totalScenes = 0.obs;
  var pendingTasks = 0.obs;
  var totalNotes = 0.obs;

  // Search functionality
  var searchQuery = ''.obs;
  var searchResults = <SearchResultItem>[].obs;
  var isSearching = false.obs;
  final searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    loadDashboardData();

    // Listen to search query changes
    ever(searchQuery, (_) => performSearch());
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  /// Comprehensive search across projects, scenes, equipment, and tasks
  void performSearch() {
    if (searchQuery.value.isEmpty) {
      searchResults.clear();
      isSearching.value = false;
      return;
    }

    isSearching.value = true;
    final query = searchQuery.value.toLowerCase();
    final results = <SearchResultItem>[];

    // Search Projects
    for (var project in projects) {
      if (project.title.toLowerCase().contains(query) ||
          (project.description?.toLowerCase().contains(query) ?? false)) {
        results.add(
          SearchResultItem(
            type: 'project',
            id: project.id,
            title: project.title,
            subtitle: project.description,
            icon: Icons.folder_outlined,
            color: const Color(0xFF00D9FF),
            data: project,
          ),
        );
      }
    }

    // Search Scenes
    for (var scene in scenes) {
      if (scene.title.toLowerCase().contains(query) ||
          (scene.description?.toLowerCase().contains(query) ?? false) ||
          (scene.locationName?.toLowerCase().contains(query) ?? false)) {
        results.add(
          SearchResultItem(
            type: 'scene',
            id: scene.id,
            title: 'Scene ${scene.sceneNumber}: ${scene.title}',
            subtitle: scene.locationName ?? scene.description,
            icon: Icons.movie_outlined,
            color: const Color(0xFF2196F3),
            data: scene,
          ),
        );
      }
    }

    // Search Equipment
    for (var equip in equipment) {
      if (equip.equipmentName.toLowerCase().contains(query) ||
          (equip.category?.toLowerCase().contains(query) ?? false)) {
        results.add(
          SearchResultItem(
            type: 'equipment',
            id: equip.id,
            title: equip.equipmentName,
            subtitle:
                '${equip.category ?? "Equipment"} • Qty: ${equip.quantity}',
            icon: Icons.construction_outlined,
            color: const Color(0xFF2196F3), // Changed to blue
            data: equip,
          ),
        );
      }
    }

    // Search Tasks
    for (var task in tasks) {
      if (task.title.toLowerCase().contains(query) ||
          (task.description?.toLowerCase().contains(query) ?? false)) {
        results.add(
          SearchResultItem(
            type: 'task',
            id: task.id,
            title: task.title,
            subtitle:
                task.description ??
                'Due: ${DateFormat("dd MMM yyyy").format(task.dueDate)}',
            icon: Icons.assignment,
            color: const Color(0xFF2196F3), // Changed to blue
            data: task,
          ),
        );
      }
    }

    searchResults.value = results;
  }

  /// Clear search and reset to normal dashboard view
  void clearSearch() {
    searchQuery.value = '';
    searchController.clear();
    searchResults.clear();
    isSearching.value = false;
  }

  Future<void> loadDashboardData() async {
    isLoading.value = true;
    try {
      final userData = await LoginController.getUserData();
      currentUserId.value = userData['user_id'] ?? '';

      await Future.wait([fetchProjects(), fetchMyTasks()]);

      // Fetch scenes and equipment after projects are loaded
      await fetchScenes();
      await fetchEquipment();
      await fetchStatistics();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load dashboard. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchProjects() async {
    try {
      final response = await SupabaseConfig.client
          .from('projects')
          .select()
          .order('updated_at', ascending: false);

      final allProjects = (response as List)
          .map((json) => Project.fromJson(json))
          .toList();

      // Filter: user ada di staff array ATAU user adalah owner
      projects.value = allProjects.where((project) {
        final isStaff = project.staff.contains(currentUserId.value);
        final isOwner = project.createdBy == currentUserId.value;
        return isStaff || isOwner;
      }).toList();

      totalProjects.value = projects.length;
    } catch (e) {
      projects.value = [];
    }
  }

  Future<void> fetchMyTasks() async {
    try {
      final response = await SupabaseConfig.client
          .from('tasks')
          .select()
          .eq('assigned_to', currentUserId.value)
          .order('due_date', ascending: true);

      final allTasks = (response as List)
          .map((json) => Task.fromJson(json))
          .toList();

      // Sort: Incomplete tasks first (by due_date), then completed tasks (by due_date)
      allTasks.sort((a, b) {
        final aCompleted = a.status == 'completed';
        final bCompleted = b.status == 'completed';

        // If one is completed and the other is not, incomplete comes first
        if (aCompleted != bCompleted) {
          return aCompleted ? 1 : -1;
        }

        // If both are same status, sort by due date (nearest first)
        return a.dueDate.compareTo(b.dueDate);
      });

      tasks.value = allTasks;
    } catch (e) {
      tasks.value = [];
    }
  }

  Future<void> fetchScenes() async {
    try {
      final projectIds = projects.map((p) => p.id).toList();

      if (projectIds.isEmpty) {
        scenes.value = [];
        return;
      }

      final response = await SupabaseConfig.client
          .from('scenes')
          .select()
          .inFilter('project_id', projectIds)
          .order('scene_number', ascending: true);

      scenes.value = (response as List)
          .map((json) => Scene.fromJson(json))
          .toList();
    } catch (e) {
      scenes.value = [];
    }
  }

  Future<void> fetchEquipment() async {
    try {
      final sceneIds = scenes.map((s) => s.id).toList();

      if (sceneIds.isEmpty) {
        equipment.value = [];
        return;
      }

      final response = await SupabaseConfig.client
          .from('equipment')
          .select()
          .inFilter('scene_id', sceneIds);

      equipment.value = (response as List)
          .map((json) => Equipment.fromJson(json))
          .toList();
    } catch (e) {
      equipment.value = [];
    }
  }

  Future<void> fetchStatistics() async {
    try {
      // Count total scenes dari project yang user ikuti
      final projectIds = projects.map((p) => p.id).toList();

      if (projectIds.isNotEmpty) {
        final scenesResponse = await SupabaseConfig.client
            .from('scenes')
            .select()
            .inFilter('project_id', projectIds);
        totalScenes.value = (scenesResponse as List).length;
      } else {
        totalScenes.value = 0;
      }

      // Count pending tasks (assigned to current user, not completed)
      final myTasksResponse = await SupabaseConfig.client
          .from('tasks')
          .select()
          .eq('assigned_to', currentUserId.value);

      final myTasks = (myTasksResponse as List);
      pendingTasks.value = myTasks
          .where((task) => task['status'] != 'completed')
          .length;

      // Count total notes dari current user (Hive)
      try {
        final box = await Hive.openBox('notes');
        var noteCount = 0;
        for (var key in box.keys) {
          final data = box.get(key) as Map;
          if (data['userId'] == currentUserId.value) {
            noteCount++;
          }
        }
        totalNotes.value = noteCount;
      } catch (e) {
        totalNotes.value = 0;
      }
    } catch (e) {
      // Statistics fetch error - silently fail
    }
  }
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DashboardController());

    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
        );
      }

      return RefreshIndicator(
        color: const Color(0xFF00D9FF),
        backgroundColor: const Color(0xFF152033),
        onRefresh: () => controller.loadDashboardData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar - Di atas sebelum Statistic
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF152033),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: TextField(
                  controller: controller.searchController,
                  onChanged: (value) => controller.searchQuery.value = value,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search projects, scenes, equipment, tasks...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF8B8B8B),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF00D9FF),
                      size: 22,
                    ),
                    suffixIcon: Obx(
                      () => controller.searchQuery.value.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Color(0xFF8B8B8B),
                              ),
                              onPressed: () => controller.clearSearch(),
                            )
                          : const SizedBox.shrink(),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Show search results if searching, otherwise show normal dashboard
              Obx(() {
                if (controller.isSearching.value) {
                  return _buildSearchResults(controller);
                }

                return _buildDashboardContent(controller);
              }),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSearchResults(DashboardController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Search Results',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Obx(
              () => Text(
                '${controller.searchResults.length} results',
                style: const TextStyle(fontSize: 14, color: Color(0xFF8B8B8B)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Obx(() {
          if (controller.searchResults.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: const Color(0xFF8B8B8B).withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No results found for "${controller.searchQuery.value}"',
                      style: const TextStyle(
                        color: Color(0xFF8B8B8B),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: controller.searchResults
                .map((result) => _buildSearchResultCard(result))
                .toList(),
          );
        }),
      ],
    );
  }

  Widget _buildSearchResultCard(SearchResultItem result) {
    return InkWell(
      onTap: () {
        // Navigate based on type
        if (result.type == 'project') {
          final project = result.data as Project;
          Get.to(() => ProjectDetailPage(project: project));
        } else if (result.type == 'scene') {
          final scene = result.data as Scene;
          Get.to(() => TasksTab(sceneId: scene.id));
        } else if (result.type == 'equipment') {
          final equip = result.data as Equipment;
          Get.to(() => TasksTab(sceneId: equip.sceneId));
        } else if (result.type == 'task') {
          final task = result.data as Task;
          Get.to(() => TasksTab(sceneId: task.sceneId));
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF152033),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1F2937)),
        ),
        child: Row(
          children: [
            // Icon with colored background
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: result.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: result.color.withOpacity(0.3)),
              ),
              child: Icon(result.icon, color: result.color, size: 24),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: result.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          result.type.toUpperCase(),
                          style: TextStyle(
                            color: result.color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (result.subtitle != null &&
                      result.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      result.subtitle!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8B8B8B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Color(0xFF8B8B8B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(DashboardController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistic',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        // Stats Cards
        Row(
          children: [
            Expanded(
              child: Obx(
                () => _buildStatCard(
                  'Active Projects',
                  controller.totalProjects.value.toString(),
                  Icons.folder_outlined,
                  const Color(0xFF00D9FF),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Obx(
                () => _buildStatCard(
                  'Total Scenes',
                  controller.totalScenes.value.toString(),
                  Icons.movie_outlined,
                  const Color(0xFF2196F3),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Obx(
                () => _buildStatCard(
                  'Pending Tasks',
                  controller.pendingTasks.value.toString(),
                  Icons.task_outlined,
                  const Color(0xFFFF9800),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Obx(
                () => _buildStatCard(
                  'My Notes',
                  controller.totalNotes.value.toString(),
                  Icons.note_outlined,
                  const Color(0xFF4CAF50),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // My Tasks (sorted by nearest deadline)
        const Text(
          'My Tasks',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Obx(() {
          if (controller.tasks.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.task_outlined,
                      size: 64,
                      color: const Color(0xFF8B8B8B).withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Belum ada tugas',
                      style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }

          // Show only first 5 tasks
          final displayTasks = controller.tasks.take(5).toList();

          return Column(
            children: displayTasks.map((task) => _buildTaskCard(task)).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF152033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8B8B8B)),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return InkWell(
      onTap: () {
        // Navigate to Scene Detail (Tasks Tab with sceneId)
        Get.to(() => TasksTab(sceneId: task.sceneId));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Leading Icon - Gradient Box dengan Static Assignment Icon (seperti Projects Tab)
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00D9FF).withOpacity(0.3),
                    const Color(0xFF2196F3).withOpacity(0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00D9FF).withOpacity(0.3),
                ),
              ),
              child: const Icon(
                Icons.assignment,
                color: Color(0xFF00D9FF),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: task.statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: task.statusColor.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              task.statusIcon,
                              size: 14,
                              color: task.statusColor,
                            ),
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
                      ),
                    ],
                  ),
                  if (task.description != null &&
                      task.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      task.description!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8B8B8B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                        dateFormat.format(task.dueDate),
                        style: TextStyle(
                          fontSize: 13,
                          color: (task.isOverdue && task.status != 'completed')
                              ? const Color(0xFFFF5252)
                              : const Color(0xFF8B8B8B),
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
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Color(0xFF8B8B8B),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

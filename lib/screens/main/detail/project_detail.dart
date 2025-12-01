import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:danielshotsync/screens/main/scenes_tab.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/project.dart';
import '../../../config/supabase_config.dart';
import '../../Operation/edit_project.dart';
import '../login.dart';
import '../chat_page.dart';

/// Controller buat handle logic Project Detail Page
class ProjectDetailController extends GetxController {
  var project = Rx<Project?>(null); // Project data yang ditampilkan
  var isLoading = false.obs;
  var currentUserId = ''.obs; // ID user yang lagi login
  var unreadMessageCount = 0.obs; // Jumlah pesan yang belum dibaca
  final String projectId; // ID project yang mau ditampilkan

  ProjectDetailController(this.projectId);

  @override
  void onInit() {
    super.onInit();
    loadCurrentUser();
    loadProjectDetail();
    loadUnreadMessageCount();
  }

  /// Load user ID dari SharedPreferences
  /// Dipake buat cek apakah user ini owner project atau bukan
  Future<void> loadCurrentUser() async {
    final userData = await LoginController.getUserData();
    currentUserId.value = userData['user_id'] ?? '';
  }

  /// Getter buat cek apakah user yang login adalah owner project
  /// Owner bisa edit & delete project
  bool get isProjectOwner {
    final createdBy = project.value?.createdBy;
    final userId = currentUserId.value;

    return createdBy != null && userId.isNotEmpty && createdBy == userId;
  }

  /// Getter buat cek apakah user memiliki full access (owner atau administrator)
  /// Administrator juga bisa edit project dan add scene
  bool get hasFullAccess {
    if (project.value == null || currentUserId.value.isEmpty) return false;
    return project.value!.hasFullAccess(currentUserId.value);
  }

  /// Load project detail dari database
  /// Sekalian fetch statistik scenes-nya
  Future<void> loadProjectDetail() async {
    isLoading.value = true;
    try {
      final response = await SupabaseConfig.client
          .from('projects')
          .select('*, project_administrator')
          .eq('id', projectId)
          .single();

      project.value = Project.fromJson(response);

      // Debug: Print loaded project data
      print('DEBUG ProjectDetail - Project loaded: ${project.value?.title}');
      print('DEBUG ProjectDetail - Owner: ${project.value?.createdBy}');
      print(
        'DEBUG ProjectDetail - Administrators: ${project.value?.projectAdministrator}',
      );

      // Fetch scene statistics
      await _fetchSceneStatistics();

      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      print('DEBUG ProjectDetail - Error loading project: $e');
      Get.snackbar(
        'Error',
        'Failed to load project. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Fetch & hitung statistik scenes untuk project ini
  Future<void> _fetchSceneStatistics() async {
    try {
      // Fetch all scenes for this project
      final response = await SupabaseConfig.client
          .from('scenes')
          .select()
          .eq('project_id', projectId);

      final scenes = response as List;
      final totalScenes = scenes.length;
      final completedScenes = scenes
          .where((scene) => scene['status'] == 'completed')
          .length;

      // Update project with statistics
      if (project.value != null) {
        project.value = Project(
          id: project.value!.id,
          title: project.value!.title,
          description: project.value!.description,
          startDate: project.value!.startDate,
          endDate: project.value!.endDate,
          createdBy: project.value!.createdBy,
          staff: project.value!.staff, // 🔧 Preserve staff data
          projectAdministrator: project
              .value!
              .projectAdministrator, // 🔧 Preserve administrator data!
          updatedAt: project.value!.updatedAt,
          totalScenes: totalScenes,
          completedScenes: completedScenes,
          status: project.value!.status,
          link: project.value!.link,
        );

        // Debug: Verify projectAdministrator is preserved
        print('DEBUG _fetchSceneStatistics - Updated project.value');
        print(
          'DEBUG _fetchSceneStatistics - projectAdministrator: ${project.value!.projectAdministrator}',
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to fetch statistics. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Public method untuk refresh statistik
  /// Bisa dipanggil dari luar kalo ada perubahan pada scenes
  Future<void> refreshStatistics() async {
    await _fetchSceneStatistics();
  }

  /// Load unread message count untuk project ini
  Future<void> loadUnreadMessageCount() async {
    if (currentUserId.value.isEmpty) {
      unreadMessageCount.value = 0;
      return;
    }

    try {
      // Get all messages in this project
      final response = await SupabaseConfig.client
          .from('project_messages')
          .select()
          .eq('project_id', projectId)
          .neq('sender_id', currentUserId.value); // Exclude own messages

      final messages = response as List;
      int unreadCount = 0;

      // Count messages where current user is NOT in read_by array
      for (var msg in messages) {
        final readBy = msg['read_by'];
        List<String> readByList = [];
        if (readBy != null && readBy is List) {
          readByList = readBy.map((e) => e.toString()).toList();
        }

        // If current user is not in read_by list, it's unread
        if (!readByList.contains(currentUserId.value)) {
          unreadCount++;
        }
      }

      unreadMessageCount.value = unreadCount;
    } catch (e) {
      // Silently fail - not critical
      print('Error loading unread message count: $e');
      unreadMessageCount.value = 0;
    }
  }

  /// Delete project dari database
  /// Cuma owner yang bisa delete
  Future<void> deleteProject() async {
    try {
      await SupabaseConfig.client.from('projects').delete().eq('id', projectId);

      Get.back();
      Get.snackbar(
        'Success',
        'Project successfully deleted',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete project. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Dialog konfirmasi delete project
  /// Warning ke user bahwa action ini permanent
  void showDeleteConfirmation() {
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF152033),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFF9800),
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Project?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Project "${project.value?.title}" will be permanently deleted. This action cannot be undone.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8B8B8B), fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1F2937)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF8B8B8B)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        deleteProject();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5252),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
            ],
          ),
        ),
      ),
    );
  }
}

// Halaman detail project
class ProjectDetailPage extends StatelessWidget {
  final Project project;

  const ProjectDetailPage({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProjectDetailController(project.id));
    final dateFormat = DateFormat('dd MMM yyyy');
    final dateFormatShort = DateFormat('dd-MM-yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFF0F1828),
      body: Obx(() {
        final currentProject = controller.project.value ?? project;

        return RefreshIndicator(
          color: const Color(0xFF00D9FF),
          backgroundColor: const Color(0xFF152033),
          onRefresh: () async {
            await controller.loadProjectDetail();
            await controller.loadUnreadMessageCount();
          },
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: const Color(0xFF152033),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Get.back(),
                ),
                actions: [
                  // Ikon pesan
                  IconButton(
                    icon: const Icon(
                      Icons.message_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      await Get.to(
                        () => ChatPage(
                          projectId: currentProject.id,
                          projectName: currentProject.title,
                        ),
                      );
                    },
                  ),
                  Obx(() {
                    if (!controller.hasFullAccess) {
                      return const SizedBox.shrink();
                    }
                    return PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      color: const Color(0xFF152033),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit,
                                color: Color(0xFF00D9FF),
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Edit Project',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete,
                                color: Color(0xFFFF5252),
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Delete Project',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == 'delete') {
                          controller.showDeleteConfirmation();
                        } else if (value == 'edit') {
                          await controller.loadProjectDetail();

                          // Wait a bit for state to update
                          await Future.delayed(Duration(milliseconds: 100));

                          final freshProject = controller.project.value;
                          if (freshProject == null) {
                            Get.snackbar(
                              'Error',
                              'Failed to load project data',
                            );
                            return;
                          }

                          // Create a NEW instance to ensure data is fresh
                          final projectToEdit = Project(
                            id: freshProject.id,
                            title: freshProject.title,
                            description: freshProject.description,
                            startDate: freshProject.startDate,
                            endDate: freshProject.endDate,
                            createdBy: freshProject.createdBy,
                            staff: List<String>.from(freshProject.staff),
                            projectAdministrator: List<String>.from(
                              freshProject.projectAdministrator,
                            ),
                            updatedAt: freshProject.updatedAt,
                            status: freshProject.status,
                            link: freshProject.link,
                            totalScenes: freshProject.totalScenes,
                            completedScenes: freshProject.completedScenes,
                          );

                          print(
                            'DEBUG ProjectDetail - projectToEdit.projectAdministrator: ${projectToEdit.projectAdministrator}',
                          );

                          final result = await Get.to(
                            () => EditProjectPage(project: projectToEdit),
                          );
                          if (result == true) {
                            // Reload project detail setelah edit
                            print(
                              'DEBUG ProjectDetail - Reloading project after edit...',
                            );
                            await controller.loadProjectDetail();
                            print(
                              'DEBUG ProjectDetail - Project reloaded: ${controller.project.value?.title}',
                            );
                            print(
                              'DEBUG ProjectDetail - New administrators: ${controller.project.value?.projectAdministrator}',
                            );
                          }
                        }
                      },
                    );
                  }),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00D9FF).withOpacity(0.3),
                          const Color(0xFF2196F3).withOpacity(0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.movie_outlined,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              currentProject.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      if (currentProject.description != null &&
                          currentProject.description!.isNotEmpty) ...[
                        const Text(
                          'Description',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentProject.description!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      // Statistics Cards
                      const Text(
                        'Statistics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.video_library_outlined,
                              label: 'Total Scenes',
                              value: currentProject.totalScenes.toString(),
                              color: const Color(0xFF2196F3),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.check_circle_outline,
                              label: 'Completed',
                              value: currentProject.completedScenes.toString(),
                              color: const Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.pending_outlined,
                              label: 'Remaining',
                              value:
                                  (currentProject.totalScenes -
                                          currentProject.completedScenes)
                                      .toString(),
                              color: const Color(0xFFFF9800),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.trending_up,
                              label: 'Progress',
                              value:
                                  '${currentProject.progress.toStringAsFixed(0)}%',
                              color: const Color(0xFF00D9FF),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Progress Bar with Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Work Progress',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: currentProject.statusColor.withOpacity(
                                0.2,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: currentProject.statusColor.withOpacity(
                                  0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: currentProject.statusColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  currentProject.status,
                                  style: TextStyle(
                                    color: currentProject.statusColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF152033),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1F2937)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${currentProject.completedScenes} / ${currentProject.totalScenes} Scenes',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${currentProject.progress.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: currentProject.statusColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: currentProject.progress / 100,
                                backgroundColor: const Color(0xFF1F2937),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  currentProject.statusColor,
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Project Info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Project Information',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (currentProject.updatedAt != null)
                            Text(
                              'Updated: ${dateFormat.format(currentProject.updatedAt!)}',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF152033),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1F2937)),
                        ),
                        child: Column(
                          children: [
                            Obx(
                              () =>
                                  controller.project.value?.link.isNotEmpty ??
                                      false
                                  ? _buildInfoRow(
                                      icon: Icons.link,
                                      label: 'Important Link',
                                      value: controller.project.value!.link,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            _buildInfoRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Start Date',
                              value: dateFormatShort.format(
                                currentProject.startDate,
                              ),
                            ),
                            _buildInfoRow(
                              icon: Icons.event_outlined,
                              label: 'End Date',
                              value: dateFormatShort.format(
                                currentProject.endDate,
                              ),
                              isLast: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Get.to(ScenesTab(projectId: project.id));
                          },
                          icon: const Icon(Icons.video_library),
                          label: const Text('View Scenes'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00D9FF),
                            side: const BorderSide(color: Color(0xFF00D9FF)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  /// Widget buat statistic card
  /// Dipakai di section Statistics (4 cards: Total, Completed, Remaining, Progress)
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF152033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF8B8B8B), fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Widget buat info row di section Project Information
  /// Format: Icon - Label - Value (date)
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFF1F2937))),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00D9FF), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8B8B8B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                if (label == 'Important Link')
                  GestureDetector(
                    onLongPress: () {
                      Clipboard.setData(ClipboardData(text: value));
                    },
                    onTap: () {
                      String url = value;
                      if (!url.startsWith('http://') &&
                          !url.startsWith('https://')) {
                        url = 'https://$url';
                      }
                      launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: Color(0xFF00D9FF),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

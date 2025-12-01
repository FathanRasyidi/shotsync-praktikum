import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:danielshotsync/models/project.dart';
import 'package:danielshotsync/config/supabase_config.dart';
import 'login.dart';
import '../Operation/add_project.dart';
import 'detail/project_detail.dart';

/// Controller buat handle logic Projects Tab
class ProjectsController extends GetxController {
  var projects = <Project>[].obs; // List projects yang diikuti user
  var isLoading = true.obs;
  var userRole = ''.obs; // Role user buat show/hide FAB
  var userId = ''.obs; // User ID yang sedang login

  @override
  void onInit() {
    super.onInit();
    _loadUserData();
    loadProjects();
  }

  /// Load user data (role & ID) yang lagi login
  /// Dipake buat filter projects & nentuin boleh add project atau ngga
  Future<void> _loadUserData() async {
    final userData = await LoginController.getUserData();
    userRole.value = userData['user_role'] ?? '';
    userId.value = userData['user_id'] ?? '';
  }

  /// Fetch projects yang diikuti user
  Future<void> loadProjects() async {
    isLoading.value = true;

    try {
      // Fetch semua projects dulu
      final response = await SupabaseConfig.client
          .from('projects')
          .select('*, project_administrator')
          .order('updated_at', ascending: false);

      final allProjects = (response as List)
          .map((json) => Project.fromJson(json))
          .toList();

      // Debug: Print first project's administrator data
      if (allProjects.isNotEmpty) {
        print('DEBUG ProjectsTab - First project: ${allProjects[0].title}');
        print(
          'DEBUG ProjectsTab - Administrators: ${allProjects[0].projectAdministrator}',
        );
      }

      // Filter: user harus ada di staff array ATAU user adalah owner (created_by) ATAU user adalah administrator
      final projectList = allProjects.where((project) {
        final isStaff = project.staff.contains(userId.value);
        final isOwner = project.createdBy == userId.value;
        final isAdmin = project.projectAdministrator.contains(userId.value);
        return isStaff || isOwner || isAdmin;
      }).toList();

      // Hitung statistik scenes untuk setiap project
      for (var project in projectList) {
        try {
          // Fetch scenes per project
          final scenesResponse = await SupabaseConfig.client
              .from('scenes')
              .select()
              .eq('project_id', project.id);

          final scenes = scenesResponse as List;
          project.totalScenes = scenes.length;

          // Count completed scenes
          project.completedScenes = scenes
              .where(
                (s) => (s['status'] as String?)?.toLowerCase() == 'completed',
              )
              .length;
        } catch (e) {
          project.totalScenes = 0;
          project.completedScenes = 0;
        }
      }

      projects.value = projectList;
      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Error',
        'Failed to load project list: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}

/// Tab untuk daftar Projects
class ProjectsTab extends StatelessWidget {
  const ProjectsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProjectsController());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Obx(
        () => controller.isLoading.value
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
              )
            : RefreshIndicator(
                onRefresh: controller.loadProjects,
                color: const Color(0xFF00D9FF),
                backgroundColor: const Color(0xFF152033),
                child: controller.projects.isEmpty
                    ? ListView(
                        // Wrap in ListView agar RefreshIndicator bisa bekerja
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height - 200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.movie_creation_outlined,
                                    size: 80,
                                    color: const Color(
                                      0xFF8B8B8B,
                                    ).withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No projects yet',
                                    style: TextStyle(
                                      color: Color(0xFF8B8B8B),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Pull down to refresh',
                                    style: TextStyle(
                                      color: Color(0xFF4A5568),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: controller.projects.length,
                        itemBuilder: (context, index) {
                          final project = controller.projects[index];
                          return Card(
                            color: const Color(0xFF152033),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: Color(0xFF1F2937),
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF00D9FF).withOpacity(0.2),
                                      const Color(0xFF2196F3).withOpacity(0.2),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.movie_outlined,
                                  color: Color(0xFF00D9FF),
                                  size: 28,
                                ),
                              ),
                              title: Text(
                                project.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  if (project.description != null &&
                                      project.description!.isNotEmpty)
                                    Text(
                                      project.description!,
                                      style: const TextStyle(
                                        color: Color(0xFF8B8B8B),
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // Status badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: project.statusColor
                                              .withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          project.status,
                                          style: TextStyle(
                                            color: project.statusColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Scene count
                                      Icon(
                                        Icons.video_library_outlined,
                                        size: 14,
                                        color: const Color(0xFF8B8B8B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${project.completedScenes}/${project.totalScenes} Scenes',
                                        style: const TextStyle(
                                          color: Color(0xFF8B8B8B),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Spacer(),
                                      // Progress percentage
                                      Text(
                                        '${project.progress.round()}%',
                                        style: TextStyle(
                                          color: project.statusColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (project.totalScenes > 0) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: project.progress / 100,
                                        backgroundColor: const Color(
                                          0xFF1F2937,
                                        ),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              project.statusColor,
                                            ),
                                        minHeight: 4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                color: Color(0xFF8B8B8B),
                                size: 16,
                              ),
                              onTap: () async {
                                await Get.to(
                                  () => ProjectDetailPage(project: project),
                                );
                                controller
                                    .loadProjects(); // Reload setelah kembali dari detail
                              },
                            ),
                          );
                        },
                      ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Get.to(() => const AddProjectPage());
          controller.loadProjects(); // Reload setelah add project
        },
        backgroundColor: const Color(0xFF2196F3),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

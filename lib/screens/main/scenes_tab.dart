import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:danielshotsync/models/scene.dart';
import 'package:danielshotsync/config/supabase_config.dart';
import 'package:danielshotsync/screens/main/login.dart';
import 'package:danielshotsync/screens/Operation/add_scene.dart';
import 'package:danielshotsync/screens/main/tasks_tab.dart';

/// Controller buat handle logic Scenes Tab
class ScenesController extends GetxController {
  final String projectId; // ID project yang mau ditampilkan scenes-nya
  var scenes = <Scene>[].obs; // List semua scenes
  var isLoading = true.obs;
  var userId = ''.obs; // User ID yang sedang login
  var projectOwnerId = ''.obs; // Owner/Creator ID dari project
  var projectAdministrators = <String>[].obs; // List of administrator IDs
  var projectTitle = ''.obs; // Title project buat AppBar

  ScenesController({required this.projectId});

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
    _loadProjectInfo();
    loadScenes();
  }

  /// Load user ID yang lagi login
  Future<void> _loadUserId() async {
    final userData = await LoginController.getUserData();
    userId.value = userData['user_id'] ?? '';
  }

  /// Load project info  buat ditampilkan di AppBar
  Future<void> _loadProjectInfo() async {
    try {
      final response = await SupabaseConfig.client
          .from('projects')
          .select('title, created_by, project_administrator')
          .eq('id', projectId)
          .single();

      projectTitle.value = response['title'] as String? ?? 'Project';
      projectOwnerId.value = response['created_by'] as String? ?? '';
      projectAdministrators.value = List<String>.from(
        response['project_administrator'] as List? ?? [],
      );
    } catch (e) {
      // Error loading project info - silently fail
    }
  }

  /// Check apakah user adalah owner/creator project
  bool get isProjectOwner => userId.value == projectOwnerId.value;

  /// Check apakah user memiliki full access (owner atau administrator)
  bool get hasFullAccess =>
      isProjectOwner || projectAdministrators.contains(userId.value);

  /// Fetch semua scenes untuk project ini
  Future<void> loadScenes() async {
    isLoading.value = true;

    try {
      final response = await SupabaseConfig.client
          .from('scenes')
          .select()
          .eq('project_id', projectId)
          .order('scene_number', ascending: true);

      scenes.value = (response as List)
          .map((json) => Scene.fromJson(json))
          .toList();
      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Error',
        'Failed to load scene list: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}

// Tab untuk Scenes
class ScenesTab extends StatelessWidget {
  final String projectId;

  const ScenesTab({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      ScenesController(projectId: projectId),
      tag: projectId, // Tag untuk multiple instances
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F1828),
      appBar: AppBar(
        title: Obx(
          () => Text(
            controller.projectTitle.value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF00D9FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF152033),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Obx(
        () => controller.isLoading.value
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
              )
            : RefreshIndicator(
                onRefresh: controller.loadScenes,
                color: const Color(0xFF00D9FF),
                backgroundColor: const Color(0xFF152033),
                child: controller.scenes.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height - 200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.video_library_outlined,
                                    size: 80,
                                    color: const Color(
                                      0xFF8B8B8B,
                                    ).withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No scenes yet',
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: controller.scenes.length,
                        itemBuilder: (context, index) {
                          final scene = controller.scenes[index];
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
                                vertical: 12,
                              ),
                              leading: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      scene.statusColor.withOpacity(0.3),
                                      scene.statusColor.withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Scene',
                                      style: TextStyle(
                                        color: scene.statusColor.withOpacity(
                                          0.7,
                                        ),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      scene.sceneNumber.toString(),
                                      style: TextStyle(
                                        color: scene.statusColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              title: Text(
                                scene.title,
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
                                  // if (scene.description != null &&
                                  //     scene.description!.isNotEmpty)
                                  //   Text(
                                  //     scene.description!,
                                  //     style: const TextStyle(
                                  //       color: Color(0xFF8B8B8B),
                                  //       fontSize: 13,
                                  //     ),
                                  //     maxLines: 1,
                                  //     overflow: TextOverflow.ellipsis,
                                  //   ),
                                  // const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: scene.statusColor.withOpacity(
                                            0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          scene.statusText == 'on-progress'
                                              ? 'On Progress'
                                              : scene.statusText,
                                          style: TextStyle(
                                            color: scene.statusColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (scene.locationName != null) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 14,
                                          color: const Color(0xFF8B8B8B),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            scene.locationName!,
                                            style: const TextStyle(
                                              color: Color(0xFF8B8B8B),
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.event_outlined,
                                        size: 14,
                                        color: const Color(0xFF8B8B8B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${scene.scheduledDateTimeText} (WIB)",
                                        style: const TextStyle(
                                          color: Color(0xFF8B8B8B),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                color: Color(0xFF8B8B8B),
                                size: 16,
                              ),
                              onTap: () {
                                // Navigate ke Tasks Tab dengan sceneId
                                Get.to(() => TasksTab(sceneId: scene.id));
                              },
                            ),
                          );
                        },
                      ),
              ),
      ),
      floatingActionButton: Obx(
        () =>
            // FAB cuma muncul kalo user adalah owner/creator project atau administrator
            controller.hasFullAccess
            ? FloatingActionButton(
                onPressed: () async {
                  await Get.to(() => AddScenePage(projectId: projectId));
                  controller.loadScenes(); // Reload setelah add scene
                },
                backgroundColor: const Color(0xFF2196F3),
                child: const Icon(Icons.add, color: Colors.white),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

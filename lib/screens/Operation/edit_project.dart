import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/supabase_config.dart';
import '../../models/project.dart';
import '../../models/user.dart';
import '../../widgets/profile_avatar.dart';

/// Controller buat handle logic Edit Project
class EditProjectController extends GetxController {
  final Project project; // Project yang mau di-edit

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final linkController = TextEditingController();

  var startDate = Rx<DateTime?>(null);
  var endDate = Rx<DateTime?>(null);
  var isLoading = false.obs;
  var isLoadingUsers = true.obs;

  var users = <User>[].obs; // List semua users
  var selectedStaff = <String>[].obs; // List user IDs yang dipilih jadi staff
  var selectedAdministrators =
      <String>[].obs; // List user IDs yang dipilih jadi administrator

  EditProjectController(this.project);

  @override
  void onInit() {
    super.onInit();
    // Load existing project data ke form
    titleController.text = project.title;
    descriptionController.text = project.description ?? '';
    linkController.text = project.link;
    startDate.value = project.startDate;
    endDate.value = project.endDate;

    // Load existing staff - convert dari project.staff ke selectedStaff using assignAll
    selectedStaff.assignAll(project.staff);

    // Debug: Print RAW project data before loading administrators
    print('========================================');
    print('DEBUG Edit Project - Opening: ${project.title}');
    print('DEBUG Edit Project - Project ID: ${project.id}');
    print('DEBUG Edit Project - Project owner: ${project.createdBy}');
    print(
      'DEBUG Edit Project - RAW project.projectAdministrator: ${project.projectAdministrator}',
    );
    print(
      'DEBUG Edit Project - RAW project.projectAdministrator type: ${project.projectAdministrator.runtimeType}',
    );
    print(
      'DEBUG Edit Project - Is empty? ${project.projectAdministrator.isEmpty}',
    );

    // Clear first, then load existing administrators using assignAll for RxList
    selectedAdministrators.clear();
    selectedAdministrators.assignAll(project.projectAdministrator);

    // Debug: Print loaded data
    print(
      'DEBUG Edit Project - Loaded administrators: ${selectedAdministrators.length}',
    );
    print('DEBUG Edit Project - Administrator IDs: $selectedAdministrators');

    // Verify each admin
    for (var i = 0; i < selectedAdministrators.length; i++) {
      print('  [$i] ${selectedAdministrators[i]}');
    }
    print('========================================');

    // Load users AFTER setting administrators
    loadUsers().then((_) {
      // Force refresh after users loaded
      print('DEBUG Edit Project - Users loaded, forcing refresh...');
      selectedAdministrators.refresh();
      print(
        'DEBUG Edit Project - After refresh: ${selectedAdministrators.length} administrators',
      );
    });
  }

  /// Fetch semua users
  Future<void> loadUsers() async {
    isLoadingUsers.value = true;
    try {
      final usersResponse = await SupabaseConfig.client.from('users').select();

      var userList = (usersResponse as List)
          .map((json) => User.fromJson(json))
          .toList();

      // Sort users: Owner first, then selected staff, then others
      userList.sort((a, b) {
        final aIsOwner = a.id == project.createdBy;
        final bIsOwner = b.id == project.createdBy;
        final aIsSelected = selectedStaff.contains(a.id);
        final bIsSelected = selectedStaff.contains(b.id);

        // Owner always first
        if (aIsOwner && !bIsOwner) return -1;
        if (!aIsOwner && bIsOwner) return 1;

        // Then selected staff
        if (aIsSelected && !bIsSelected) return -1;
        if (!aIsSelected && bIsSelected) return 1;

        // Then alphabetical by name
        return a.fullName.compareTo(b.fullName);
      });

      users.value = userList;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load users. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoadingUsers.value = false;
    }
  }

  /// Owner ga bisa di-uncheck (checkbox disabled)
  void toggleStaff(String userId) {
    if (selectedStaff.contains(userId)) {
      selectedStaff.remove(userId);
      // Auto-remove dari administrator jika di-uncheck dari staff
      if (selectedAdministrators.contains(userId)) {
        selectedAdministrators.remove(userId);
      }
    } else {
      selectedStaff.add(userId);
    }

    // Re-sort users after toggle
    final userList = users.toList();
    userList.sort((a, b) {
      final aIsOwner = a.id == project.createdBy;
      final bIsOwner = b.id == project.createdBy;
      final aIsSelected = selectedStaff.contains(a.id);
      final bIsSelected = selectedStaff.contains(b.id);

      // Owner always first
      if (aIsOwner && !bIsOwner) return -1;
      if (!aIsOwner && bIsOwner) return 1;

      // Then selected staff
      if (aIsSelected && !bIsSelected) return -1;
      if (!aIsSelected && bIsSelected) return 1;

      // Then alphabetical by name
      return a.fullName.compareTo(b.fullName);
    });

    users.value = userList;
  }

  /// Toggle administrator
  /// Owner otomatis jadi administrator dan ga bisa di-remove
  void toggleAdministrator(String userId) {
    if (userId == project.createdBy) return; // Owner ga bisa di-remove

    if (selectedAdministrators.contains(userId)) {
      selectedAdministrators.remove(userId);
      print('DEBUG toggleAdministrator - Removed: $userId');
    } else {
      selectedAdministrators.add(userId);
      print('DEBUG toggleAdministrator - Added: $userId');
    }

    print(
      'DEBUG toggleAdministrator - Current admins: ${selectedAdministrators.length}',
    );
    print('DEBUG toggleAdministrator - Admin IDs: $selectedAdministrators');
  }

  /// Update project data ke database
  Future<void> updateProject() async {
    if (titleController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Project title must be filled!',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    isLoading.value = true;

    try {
      // Gunakan selectedStaff langsung (owner sudah ada di dalamnya, tidak perlu ditambahkan lagi)
      final staffList = [...selectedStaff];

      // Pastikan owner ada di administrator list
      final administratorList = [...selectedAdministrators];
      if (!administratorList.contains(project.createdBy)) {
        administratorList.insert(0, project.createdBy);
      }

      final projectData = {
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        'start_date': startDate.value != null
            ? '${startDate.value!.year}-${startDate.value!.month.toString().padLeft(2, '0')}-${startDate.value!.day.toString().padLeft(2, '0')}'
            : null,
        'end_date': endDate.value != null
            ? '${endDate.value!.year}-${endDate.value!.month.toString().padLeft(2, '0')}-${endDate.value!.day.toString().padLeft(2, '0')}'
            : null,
        'staff': staffList, // Array of user IDs
        'project_administrator':
            administratorList, // Array of administrator user IDs
        'updated_at': DateTime.now().toIso8601String(),
        'link': linkController.text.trim().isEmpty
            ? null
            : linkController.text.trim(),
      };

      await SupabaseConfig.client
          .from('projects')
          .update(projectData)
          .eq('id', project.id);

      // Debug: Print what was saved
      print('DEBUG Edit Project - Saved administrators: $administratorList');
      print('DEBUG Edit Project - Staff count: ${staffList.length}');

      Get.back(result: true); // Return true buat trigger reload
      Get.snackbar(
        'Success',
        'Project successfully updated!',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update project: $e',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Delete project dari database
  Future<void> deleteProject() async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: const Color(0xFF152033),
        title: const Text(
          'Delete Confirmation',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this project? This action cannot be undone.',
          style: TextStyle(color: Color(0xFF8B8B8B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF8B8B8B)),
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      isLoading.value = true;
      try {
        await SupabaseConfig.client
            .from('projects')
            .delete()
            .eq('id', project.id);

        Get.back(result: true); // Close edit page
        Get.back(); // Close detail page
        Get.snackbar(
          'Success',
          'Project successfully deleted!',
          duration: Duration(seconds: 1, milliseconds: 500),
          backgroundColor: const Color(0xFF4CAF50),
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to delete project: $e',
          duration: Duration(seconds: 1, milliseconds: 500),
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } finally {
        isLoading.value = false;
      }
    }
  }

  /// Show DatePicker buat pilih tanggal mulai
  Future<void> selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startDate.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00D9FF),
              onPrimary: Colors.white,
              surface: Color(0xFF152033),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF152033),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      startDate.value = picked;
    }
  }

  /// Show DatePicker buat pilih tanggal selesai
  /// firstDate otomatis adjust ke startDate kalo udah dipilih
  Future<void> selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: endDate.value ?? startDate.value ?? DateTime.now(),
      firstDate: startDate.value ?? DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00D9FF),
              onPrimary: Colors.white,
              surface: Color(0xFF152033),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF152033),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      endDate.value = picked;
    }
  }

  @override
  void onClose() {
    titleController.dispose();
    descriptionController.dispose();
    super.onClose();
  }
}

/// UI Page buat edit project
class EditProjectPage extends StatelessWidget {
  final Project project;

  const EditProjectPage({super.key, required this.project});

  Future<String?> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditProjectController(project));
    final dateFormat = DateFormat('dd MMM yyyy');

    return FutureBuilder<String?>(
      future: _getCurrentUserId(),
      builder: (context, snapshot) {
        final currentUserId = snapshot.data;
        
        return Scaffold(
          backgroundColor: const Color(0xFF0F1828),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Edit Project',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Project Title',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter project title',
                hintStyle: const TextStyle(color: Color(0xFF4A5568)),
                filled: true,
                fillColor: const Color(0xFF152033),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1F2937)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1F2937)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF00D9FF),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Description',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.descriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Enter project description (optional)',
                hintStyle: const TextStyle(color: Color(0xFF4A5568)),
                filled: true,
                fillColor: const Color(0xFF152033),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1F2937)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1F2937)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF00D9FF),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Important Link',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.linkController,
              maxLines: null,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter important link (optional)',
                hintStyle: const TextStyle(color: Color(0xFF4A5568)),
                filled: true,
                fillColor: const Color(0xFF152033),
                prefixIcon: const Icon(Icons.link, color: Color(0xFF00D9FF)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1F2937)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1F2937)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF00D9FF),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'Start Date',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => InkWell(
                onTap: () => controller.selectStartDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152033),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Color(0xFF00D9FF),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        controller.startDate.value == null
                            ? 'Select start date'
                            : dateFormat.format(controller.startDate.value!),
                        style: TextStyle(
                          color: controller.startDate.value == null
                              ? const Color(0xFF4A5568)
                              : Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'End Date',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => InkWell(
                onTap: () => controller.selectEndDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152033),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Color(0xFF00D9FF),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        controller.endDate.value == null
                            ? 'Select end date'
                            : dateFormat.format(controller.endDate.value!),
                        style: TextStyle(
                          color: controller.endDate.value == null
                              ? const Color(0xFF4A5568)
                              : Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Project Staff',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select team members who will work on this project (Owner is automatically added)',
              style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 12),
            ),
            const SizedBox(height: 12),
            Obx(() {
              if (controller.isLoadingUsers.value) {
                return Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152033),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
                  ),
                );
              }

              if (controller.users.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152033),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: const Center(
                    child: Text(
                      'No users available',
                      style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 14),
                    ),
                  ),
                );
              }

              return Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: const Color(0xFF152033),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: Column(
                  children: [
                    // Header dengan count
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFF1F2937)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select Staff',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Obx(
                            () => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00D9FF).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${controller.selectedStaff.length}',
                                style: const TextStyle(
                                  color: Color(0xFF00D9FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // List of users
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: controller.users.length,
                        itemBuilder: (context, index) {
                          final user = controller.users[index];
                          return Obx(() {
                            final isSelected = controller.selectedStaff
                                .contains(user.id);
                            final isOwner =
                                user.id == controller.project.createdBy;
                            final isAdmin = controller.selectedAdministrators
                                .contains(user.id);

                            return ListTile(
                              dense: true,
                              leading: ProfileAvatar(
                                userId: user.id,
                                userName: user.fullName,
                                radius: 20,
                                backgroundColor: const Color(0xFF2196F3),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user.fullName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (isOwner)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF00D9FF,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Owner',
                                        style: TextStyle(
                                          color: Color(0xFF00D9FF),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  if (isAdmin && !isOwner)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFF9800,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Admin',
                                        style: TextStyle(
                                          color: Color(0xFFFF9800),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                user.role,
                                style: const TextStyle(
                                  color: Color(0xFF8B8B8B),
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: (isOwner || isAdmin)
                                    ? null
                                    : (value) {
                                        controller.toggleStaff(user.id);
                                      },
                                activeColor: const Color(0xFF00D9FF),
                                checkColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              onTap: (isOwner || isAdmin)
                                  ? null
                                  : () {
                                      controller.toggleStaff(user.id);
                                    },
                            );
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            // Project Administrator Section - Only visible to Owner
            if (currentUserId != null && controller.project.createdBy == currentUserId) ...[
              const Text(
                'Project Administrator',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Administrators have full access like owner (Owner is automatically added)',
                style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 12),
              ),
              const SizedBox(height: 12),
              Obx(() {
              if (controller.isLoadingUsers.value) {
                return Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152033),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
                  ),
                );
              }

              if (controller.users.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152033),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: const Center(
                    child: Text(
                      'No users available',
                      style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 14),
                    ),
                  ),
                );
              }

              // Filter: hanya tampilkan user yang sudah dipilih sebagai staff
              final staffUsers = controller.users
                  .where((user) => controller.selectedStaff.contains(user.id))
                  .toList();

              if (staffUsers.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152033),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: const Center(
                    child: Text(
                      'Please select staff first',
                      style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 14),
                    ),
                  ),
                );
              }

              return Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: const Color(0xFF152033),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: Column(
                  children: [
                    // Header dengan count
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFF1F2937)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select Administrators',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Obx(
                            () => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9800).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${controller.selectedAdministrators.length}',
                                style: const TextStyle(
                                  color: Color(0xFFFF9800),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // List of users (hanya staff yang sudah dipilih)
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: staffUsers.length,
                        itemBuilder: (context, index) {
                          final user = staffUsers[index];
                          return Obx(() {
                            final isSelected = controller.selectedAdministrators
                                .contains(user.id);
                            final isOwner =
                                user.id == controller.project.createdBy;

                            // Debug: Print checkbox state for each user
                            if (index == 0) {
                              print(
                                '\n--- Rendering Administrator Checkboxes ---',
                              );
                              print('Total users: ${controller.users.length}');
                              print(
                                'Selected administrators count: ${controller.selectedAdministrators.length}',
                              );
                              print(
                                'Selected administrators IDs: ${controller.selectedAdministrators}',
                              );
                            }

                            // Debug individual check
                            final containsCheck = controller
                                .selectedAdministrators
                                .contains(user.id);
                            final userId = user.id;
                            final userName = user.fullName;

                            if (containsCheck) {
                              print(
                                '✅ User ${userName}: SELECTED (${userId.substring(0, 8)}...)',
                              );
                            } else {
                              // Check if similar UUID exists (might be type mismatch)
                              final manualCheck = controller
                                  .selectedAdministrators
                                  .any((id) => id == userId);
                              print(
                                '❌ User ${userName}: NOT selected (${userId.substring(0, 8)}...) manualCheck=$manualCheck',
                              );
                            }

                            return ListTile(
                              dense: true,
                              leading: ProfileAvatar(
                                userId: user.id,
                                userName: user.fullName,
                                radius: 20,
                                backgroundColor: const Color(0xFF2196F3),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user.fullName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (isOwner)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFF9800,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Owner',
                                        style: TextStyle(
                                          color: Color(0xFFFF9800),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                user.role,
                                style: const TextStyle(
                                  color: Color(0xFF8B8B8B),
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: isOwner
                                    ? null
                                    : (value) {
                                        controller.toggleAdministrator(user.id);
                                      },
                                activeColor: const Color(0xFFFF9800),
                                checkColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              onTap: isOwner
                                  ? null
                                  : () {
                                      controller.toggleAdministrator(user.id);
                                    },
                            );
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
            ],
            const SizedBox(height: 32),
            Obx(
              () => SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: controller.isLoading.value
                      ? null
                      : () => controller.updateProject(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    disabledBackgroundColor: const Color(0xFF1F2937),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: controller.isLoading.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
        );
      },
    );
  }
}

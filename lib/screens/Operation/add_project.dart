import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../config/supabase_config.dart';
import '../../models/user.dart';
import '../main/login.dart';
import '../../widgets/profile_avatar.dart';

/// Controller buat handle logic Add Project
class AddProjectController extends GetxController {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final linkController = TextEditingController();

  var startDate = Rx<DateTime?>(null);
  var endDate = Rx<DateTime?>(null);
  var isLoading = false.obs;
  var isLoadingUsers = true.obs;

  var users = <User>[].obs; // List semua user dari database
  var selectedStaff = <String>[].obs; // List user IDs yang dipilih jadi staff
  var selectedAdministrators =
      <String>[].obs; // List user IDs yang dipilih jadi administrator
  var currentUserId = ''.obs; // ID user yang lagi login (owner project)

  @override
  void onInit() {
    super.onInit();
    _loadCurrentUser();
    loadUsers();
  }

  /// Load data user yang lagi login
  Future<void> _loadCurrentUser() async {
    try {
      final userData = await LoginController.getUserData();
      currentUserId.value = userData['user_id'] as String;

      // Auto-select current user as staff and administrator
      if (currentUserId.value.isNotEmpty) {
        if (!selectedStaff.contains(currentUserId.value)) {
          selectedStaff.add(currentUserId.value);
        }
        if (!selectedAdministrators.contains(currentUserId.value)) {
          selectedAdministrators.add(currentUserId.value);
        }
      }
    } catch (e) {
      // Error loading current user - silently fail
    }
  }

  /// Fetch semua user dari database buat pilihan staff
  Future<void> loadUsers() async {
    isLoadingUsers.value = true;
    try {
      final usersResponse = await SupabaseConfig.client
          .from('users')
          .select()
          .order('full_name', ascending: true);

      users.value = (usersResponse as List)
          .map((json) => User.fromJson(json))
          .toList();
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

  /// pemilihan staff
  /// Kecuali owner, dia ga bisa di-uncheck
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
  }

  /// Toggle administrator
  /// Owner otomatis jadi administrator dan ga bisa di-uncheck
  void toggleAdministrator(String userId) {
    if (userId == currentUserId.value) return; // Owner ga bisa di-remove

    if (selectedAdministrators.contains(userId)) {
      selectedAdministrators.remove(userId);
    } else {
      selectedAdministrators.add(userId);
    }
  }

  /// Simpan project ke database
  Future<void> saveProject() async {
    if (titleController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Project Title must be filled!',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    isLoading.value = true;

    try {
      final userData = await LoginController.getUserData();
      final userId = userData['user_id'] as String;

      // Pastikan owner ada di staff list dan administrator list
      final staffList = [...selectedStaff];
      if (!staffList.contains(userId)) {
        staffList.insert(0, userId); // Tambahkan owner di posisi pertama
      }

      final administratorList = [...selectedAdministrators];
      if (!administratorList.contains(userId)) {
        administratorList.insert(0, userId); // Owner otomatis jadi admin
      }

      final projectData = {
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        'start_date': startDate.value?.toIso8601String(),
        'end_date': endDate.value?.toIso8601String(),
        'created_by': userId,
        'staff': staffList, // Array of user IDs
        'project_administrator':
            administratorList, // Array of administrator user IDs
        'link': linkController.text.trim().isEmpty
            ? null
            : linkController.text.trim(),
      };
      // Debug: Print data before save
      print('DEBUG Add Project - Saving administrators: $administratorList');
      print('DEBUG Add Project - Saving staff: $staffList');

      try {
        await SupabaseConfig.client.from('projects').insert(projectData);

        print('DEBUG Add Project - Save SUCCESS!');
      } catch (e) {
        print('DEBUG Add Project - Save ERROR: $e');
        // If error contains "column" or "does not exist", show helpful message
        if (e.toString().contains('column') ||
            e.toString().contains('does not exist')) {
          Get.snackbar(
            'Database Error',
            'Column project_administrator not found! Please run SQL migration first.',
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          rethrow;
        }
        rethrow;
      }

      Get.back(result: true);
      Get.snackbar(
        'Success',
        'Project successfully added!',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to add project: $e',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Show DatePicker buat pilih tanggal mulai
  /// Theme: Dark mode dengan accent cyan
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

/// UI Page buat nambah project baru
class AddProjectPage extends StatelessWidget {
  const AddProjectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AddProjectController());
    final dateFormat = DateFormat('dd MMM yyyy');

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
          'Add New Project',
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
                hintText: 'Insert Project Title',
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
              maxLines: null,
              controller: controller.linkController,
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
                            final isCurrentUser =
                                user.id == controller.currentUserId.value;

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
                                  if (isCurrentUser)
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
                                        'You',
                                        style: TextStyle(
                                          color: Color(0xFF00D9FF),
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
                                onChanged: isCurrentUser
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
                              onTap: isCurrentUser
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
            // Project Administrator Section
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
                            final isCurrentUser =
                                user.id == controller.currentUserId.value;

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
                                  if (isCurrentUser)
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
                                onChanged: isCurrentUser
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
                              onTap: isCurrentUser
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
            const SizedBox(height: 32),
            Obx(
              () => SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: controller.isLoading.value
                      ? null
                      : () => controller.saveProject(),
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
                          'Save Project',
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
  }
}

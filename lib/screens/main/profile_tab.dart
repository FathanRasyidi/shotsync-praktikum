import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:danielshotsync/screens/main/login.dart';
import 'package:danielshotsync/config/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:danielshotsync/utils/biometric_helper.dart';

class ProfileController extends GetxController {
  var userName = 'Loading...'.obs;
  var userRole = 'Loading...'.obs;
  var userEmail = ''.obs;
  var userId = ''.obs;
  var profilePhotoPath = Rx<String?>(null);
  var isLoading = false.obs;
  var isBiometricEnabled = false.obs;
  var isBiometricAvailable = false.obs;

  final ImagePicker _picker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    loadUserData();
    checkBiometricStatus();
  }

  Future<void> checkBiometricStatus() async {
    isBiometricAvailable.value = await BiometricHelper.isBiometricAvailable();
    isBiometricEnabled.value = await BiometricHelper.isBiometricEnabled();
  }

  Future<void> toggleBiometric(bool value) async {
    // Check biometric capability first
    final available = await BiometricHelper.getAvailableBiometrics();

    if (available.isEmpty) {
      Get.snackbar(
        'Biometric Not Supported',
        'Your device does not support biometric authentication.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    if (value) {
      // Enable biometric - need to authenticate first
      final authenticated = await BiometricHelper.authenticate(
        reason: 'Authenticate to enable biometric lock',
      );
      if (authenticated) {
        await BiometricHelper.setBiometricEnabled(true);
        isBiometricEnabled.value = true;
      }
      // Error snackbar is already shown in BiometricHelper.authenticate()
    } else {
      // Disable biometric - need to authenticate before disabling
      final authenticated = await BiometricHelper.authenticate(
        reason: 'Authenticate to disable biometric lock',
      );
      if (authenticated) {
        await BiometricHelper.setBiometricEnabled(false);
        isBiometricEnabled.value = false;
      }
    }
  }

  Future<void> loadUserData() async {
    final userData = await LoginController.getUserData();

    userId.value = userData['user_id'] ?? '';
    userName.value = userData['user_name'] ?? 'User';
    userRole.value = userData['user_role'] ?? 'Crew';
    userEmail.value = userData['user_email'] ?? '';

    if (userId.value.isNotEmpty) {
      await loadProfilePhoto();
    }
  }

  Future<void> loadProfilePhoto() async {
    final response = await SupabaseConfig.client
        .from('users')
        .select('picture')
        .eq('id', userId.value)
        .maybeSingle();

    if (response == null || response['picture'] == null) {
      profilePhotoPath.value = null;
      return;
    }

    final fileName = response['picture'] as String;
    final appDir = await getApplicationDocumentsDirectory();
    final localFile = File('${appDir.path}/$fileName');

    if (await localFile.exists()) {
      profilePhotoPath.value = localFile.path;
    } else {
      profilePhotoPath.value = null;
    }
  }

  Future<void> uploadPhoto(ImageSource source) async {
    try {
      final image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image == null) return;

      isLoading.value = true;

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_${userId.value}.jpg';
      final localFile = File('${appDir.path}/$fileName');

      await File(image.path).copy(localFile.path);

      await SupabaseConfig.client
          .from('users')
          .update({'picture': fileName})
          .eq('id', userId.value);

      profilePhotoPath.value = localFile.path;

      Get.snackbar(
        'Success',
        'Photo uploaded successfully',
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to upload photo: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> removeProfilePhoto() async {
    isLoading.value = true;

    if (profilePhotoPath.value != null) {
      final file = File(profilePhotoPath.value!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await SupabaseConfig.client
        .from('users')
        .update({'picture': null})
        .eq('id', userId.value);

    profilePhotoPath.value = null;
    isLoading.value = false;

    Get.snackbar(
      'Success',
      'Photo deleted successfully',
      backgroundColor: const Color(0xFF4CAF50),
      colorText: Colors.white,
    );
  }

  void showPhotoOptions() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF152033),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF8B8B8B).withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Profile Photo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF00D9FF)),
              title: const Text(
                'Take Photo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Get.back();
                uploadPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF00D9FF),
              ),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Get.back();
                uploadPhoto(ImageSource.gallery);
              },
            ),
            if (profilePhotoPath.value != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Color(0xFFFF5252)),
                title: const Text(
                  'Delete Photo',
                  style: TextStyle(color: Color(0xFFFF5252)),
                ),
                onTap: () {
                  Get.back();
                  removeProfilePhoto();
                },
              ),
            ListTile(
              leading: const Icon(Icons.close, color: Color(0xFF8B8B8B)),
              title: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF8B8B8B)),
              ),
              onTap: () => Get.back(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class RolePickerController extends GetxController {
  var selectedRole = ''.obs;
  var isLoading = false.obs;
  final List<String> roleOptions = [
    'Producer',
    'Director',
    'Camera Operator',
    'Editor',
    'Lighting',
    'Property Manager',
    'Actor',
    'Script Supervisor',
  ];
  String userId = '';

  void setInitial(String currentRole, String id) {
    selectedRole.value = currentRole;
    userId = id;
  }

  Future<void> updateRole() async {
    if (selectedRole.value.isEmpty) return;
    isLoading.value = true;
    try {
      await SupabaseConfig.client
          .from('users')
          .update({'role': selectedRole.value})
          .eq('id', userId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', selectedRole.value);
      Get.back();
      Get.snackbar(
        'Success',
        'Role updated',
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Update gagal: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
}

void showRolePickerSheet(
  String currentRole,
  String userId, {
  VoidCallback? onRoleChanged,
}) {
  final controller = Get.put(RolePickerController());
  controller.setInitial(currentRole, userId);
  Get.bottomSheet(
    isScrollControlled: true,
    Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1828),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF8B8B8B).withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Change Role',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Obx(
            () => Column(
              children: controller.roleOptions.map((role) {
                final isSelected = controller.selectedRole.value == role;
                return GestureDetector(
                  onTap: () => controller.selectedRole.value = role,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2196F3).withOpacity(0.15)
                          : const Color(0xFF152033),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2196F3)
                            : const Color(0xFF1F2937),
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.badge_outlined,
                        color: isSelected
                            ? const Color(0xFF00D9FF)
                            : const Color(0xFF4A5568),
                      ),
                      title: Text(
                        role,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Color(0xFF00D9FF))
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Get.back(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1F2937)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF8B8B8B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00D9FF), Color(0xFF2196F3)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : () async {
                            await controller.updateRole();
                            if (onRoleChanged != null) onRoleChanged();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: controller.isLoading.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  ).then((_) {
    Get.delete<RolePickerController>();
  });
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProfileController());

    void handleRoleChanged() {
      showRolePickerSheet(
        controller.userRole.value,
        controller.userId.value,
        onRoleChanged: () async {
          await controller.loadUserData();
        },
      );
    }

    return Obx(
      () => controller.isLoading.value
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  // Profile Photo Section
                  Stack(
                    children: [
                      Obx(() {
                        final photoPath = controller.profilePhotoPath.value;
                        return Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: photoPath == null
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF00D9FF),
                                      Color(0xFF2196F3),
                                    ],
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(60),
                            border: Border.all(
                              color: const Color(0xFF00D9FF),
                              width: 3,
                            ),
                            image: photoPath != null
                                ? DecorationImage(
                                    image: FileImage(File(photoPath)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: photoPath == null
                              ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.white,
                                )
                              : null,
                        );
                      }),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: controller.showPhotoOptions,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D9FF),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF0F1828),
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Name Section
                  Text(
                    controller.userName.value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00D9FF).withOpacity(0.2),
                          const Color(0xFF2196F3).withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00D9FF).withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      controller.userRole.value,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF00D9FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Email info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.email_outlined,
                        size: 16,
                        color: Color(0xFF8B8B8B),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          controller.userEmail.value,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8B8B8B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Biometric Toggle Card
                  Obx(() {
                    if (!controller.isBiometricAvailable.value) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF152033),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1F2937)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Biometrics',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                          Switch(
                            value: controller.isBiometricEnabled.value,
                            onChanged: (value) {
                              controller.toggleBiometric(value);
                            },
                            activeColor: const Color(0xFF00D9FF),
                            activeTrackColor: const Color(
                              0xFF00D9FF,
                            ).withOpacity(0.5),
                          ),
                        ],
                      ),
                    );
                  }),

                  // Change Role Button
                  GestureDetector(
                    onTap: handleRoleChanged,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF152033),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1F2937)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'Change Role',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Logout Button
                  _buildLogoutButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: () {
          Get.dialog(
            Dialog(
              backgroundColor: const Color(0xFF152033),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout,
                        color: Color(0xFFFF5252),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Are you sure you want to logout?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 14),
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
                              style: TextStyle(
                                color: Color(0xFF8B8B8B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await LoginController.logout();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5252),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Logout',
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
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Logout',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

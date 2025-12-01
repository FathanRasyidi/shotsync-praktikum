import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:danielshotsync/screens/main/login.dart';
import '../../config/supabase_config.dart';

// Controller untuk Register
class RegisterController extends GetxController {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();

  var selectedRole = Rx<String?>(null);
  var isPasswordVisible = false.obs;
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

  // Register function
  Future<void> register() async {
    // Validasi input
    if (nameController.text.trim().isEmpty || 
        emailController.text.trim().isEmpty || 
        passwordController.text.trim().isEmpty || 
        selectedRole.value == null) {
      Get.snackbar('Error', 'Nama, email, password, dan role harus diisi!',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    // Validasi email format
    if (!GetUtils.isEmail(emailController.text.trim())) {
      Get.snackbar('Error', 'Format email tidak valid!',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    // Validasi password minimal 6 karakter
    if (passwordController.text.length < 6) {
      Get.snackbar('Error', 'Password minimal 6 karakter!',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    isLoading.value = true;

    try {
      // Hash password dengan bcrypt
      final passwordHash = BCrypt.hashpw(passwordController.text, BCrypt.gensalt());

      // Insert user baru ke database
      await SupabaseConfig.client
          .from('users')
          .insert({
            'email': emailController.text.trim(),
            'password_hash': passwordHash,
            'full_name': nameController.text.trim(),
            'phone': phoneController.text.isNotEmpty ? phoneController.text.trim() : null,
            'role': selectedRole.value,
          });

      Get.snackbar('Success', 'Registrasi berhasil! Silakan login.',
          backgroundColor: Colors.green, colorText: Colors.white);

      // Clear text fields
      nameController.clear();
      emailController.clear();
      passwordController.clear();
      phoneController.clear();
      selectedRole.value = null;
      Get.off(() => const LoginPage());
      
    } catch (e) {
      Get.snackbar('Error', 'Registrasi gagal: ${e.toString()}',
          backgroundColor: Colors.red, colorText: Colors.white);
    }

    isLoading.value = false;
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    super.onClose();
  }
}

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final RegisterController controller = Get.put(RegisterController());

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F1828),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // Logo dengan gradasi
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D9FF), Color(0xFF2196F3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.movie_filter_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Join ShotSync Team',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8B8B8B),
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Full Name field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Full Name',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8B8B8B),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF152033),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF1F2937),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: controller.nameController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Enter your full name',
                            hintStyle: TextStyle(
                              color: Color(0xFF4A5568),
                              fontSize: 15,
                            ),
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: Color(0xFF4A5568),
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Email field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8B8B8B),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF152033),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF1F2937),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: controller.emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Enter your email',
                            hintStyle: TextStyle(
                              color: Color(0xFF4A5568),
                              fontSize: 15,
                            ),
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: Color(0xFF4A5568),
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Phone field (optional)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phone (Optional)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8B8B8B),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF152033),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF1F2937),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: controller.phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Enter phone number',
                            hintStyle: TextStyle(
                              color: Color(0xFF4A5568),
                              fontSize: 15,
                            ),
                            prefixIcon: Icon(
                              Icons.phone_outlined,
                              color: Color(0xFF4A5568),
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Role field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Role',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8B8B8B),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Obx(() => Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF152033),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF1F2937),
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: controller.selectedRole.value,
                            hint: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    color: Color(0xFF4A5568),
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Pilih role Anda',
                                    style: TextStyle(
                                      color: Color(0xFF4A5568),
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            isExpanded: true,
                            dropdownColor: const Color(0xFF152033),
                            icon: const Padding(
                              padding: EdgeInsets.only(right: 16),
                              child: Icon(
                                Icons.arrow_drop_down,
                                color: Color(0xFF4A5568),
                              ),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            items: controller.roleOptions.map((role) {
                              return DropdownMenuItem<String>(
                                value: role,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.badge_outlined,
                                        color: Color(0xFF00D9FF),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(role),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              controller.selectedRole.value = value;
                            },
                          ),
                        ),
                      )),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Password field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8B8B8B),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Obx(() => Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF152033),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF1F2937),
                                width: 1,
                              ),
                            ),
                            child: TextField(
                              controller: controller.passwordController,
                              obscureText: !controller.isPasswordVisible.value,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter password (min. 6 characters)',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF4A5568),
                                  fontSize: 15,
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Color(0xFF4A5568),
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    controller.isPasswordVisible.value
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: const Color(0xFF4A5568),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    controller.isPasswordVisible.value =
                                        !controller.isPasswordVisible.value;
                                  },
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          )),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Register button dengan gradasi
                  Obx(() => Container(
                        width: double.infinity,
                        height: 52,
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
                              : controller.register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: controller.isLoading.value
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Register',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      )),

                  const SizedBox(height: 24),

                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Already have an account? ",
                        style: TextStyle(
                          color: Color(0xFF8B8B8B),
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Get.back();
                        },
                        child: const Text(
                          'Login here',
                          style: TextStyle(
                            color: Color(0xFF2196F3),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
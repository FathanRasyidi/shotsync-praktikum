import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../config/supabase_config.dart';

/// Shared controller untuk manage foto profil user
/// Digunakan di semua halaman (profile, chat, ai chat)
class ProfileAvatarController extends GetxController {
  var profilePhotoPath = Rx<String?>(null);
  final String userId;

  ProfileAvatarController(this.userId);

  @override
  void onInit() {
    super.onInit();
    if (userId.isNotEmpty) {
      loadProfilePhoto();
    }
  }

  Future<void> loadProfilePhoto() async {
    try {
      final response = await SupabaseConfig.client
          .from('users')
          .select('picture')
          .eq('id', userId)
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
    } catch (e) {
      profilePhotoPath.value = null;
    }
  }

  /// Refresh foto profil (dipanggil setelah upload foto baru)
  Future<void> refresh() async {
    await loadProfilePhoto();
  }
}

/// Widget avatar yang konsisten di semua halaman
/// Menampilkan foto profil user atau initial jika tidak ada foto
class ProfileAvatar extends StatelessWidget {
  final String userId;
  final String userName;
  final double radius;
  final Color? backgroundColor;
  final bool showBorder;

  const ProfileAvatar({
    super.key,
    required this.userId,
    required this.userName,
    this.radius = 20,
    this.backgroundColor,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    // Use existing controller if available, otherwise create new one
    final controller = Get.isRegistered<ProfileAvatarController>(tag: userId)
        ? Get.find<ProfileAvatarController>(tag: userId)
        : Get.put(ProfileAvatarController(userId), tag: userId);

    return Obx(() {
      final photoPath = controller.profilePhotoPath.value;

      if (photoPath != null && File(photoPath).existsSync()) {
        // Ada foto profil - tampilkan foto
        return Container(
          decoration: showBorder
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: backgroundColor ?? const Color(0xFF00D9FF),
                    width: 2,
                  ),
                )
              : null,
          child: CircleAvatar(
            radius: radius,
            backgroundColor: Colors.transparent,
            backgroundImage: FileImage(File(photoPath)),
          ),
        );
      } else {
        // Tidak ada foto - tampilkan initial
        return Container(
          decoration: showBorder
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: backgroundColor ?? const Color(0xFF00D9FF),
                    width: 2,
                  ),
                )
              : null,
          child: CircleAvatar(
            radius: radius,
            backgroundColor: backgroundColor ?? const Color(0xFF00D9FF),
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.7,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    });
  }
}

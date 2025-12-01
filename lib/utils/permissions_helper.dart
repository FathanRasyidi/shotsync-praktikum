import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper class untuk handle permissions di runtime
/// Just-in-time permissions: hanya request saat fitur akan digunakan
/// 
/// Usage:
/// - Storage/Photos: Saat user ingin upload foto profil (profile_tab.dart)
/// - Location: Saat user membuka map location picker/viewer (map_location_picker.dart, map_location_viewer.dart)
/// - Microphone: Saat user ingin record video (jika ada fitur video recording)
/// 
/// Permission TIDAK diminta di awal aplikasi, tapi saat fitur akan digunakan
class PermissionsHelper {

  /// Request storage permission (photos & videos dari galeri)
  /// Dipanggil saat user ingin:
  /// - Upload foto profil
  /// - Pilih foto/video dari galeri
  static Future<bool> requestStoragePermission() async {
    // Android 13+ menggunakan permission berbeda
    if (await _isAndroid13OrAbove()) {
      var statusImages = await Permission.photos.status;
      var statusVideos = await Permission.videos.status;
      
      if (statusImages.isGranted && statusVideos.isGranted) {
        return true;
      }
      
      if (statusImages.isDenied || statusVideos.isDenied) {
        Map<Permission, PermissionStatus> statuses = await [
          Permission.photos,
          Permission.videos,
        ].request();
        
        return statuses[Permission.photos]!.isGranted && 
               statuses[Permission.videos]!.isGranted;
      }
      
      if (statusImages.isPermanentlyDenied || statusVideos.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      
      return false;
    } else {
      // Android 12 and below
      var status = await Permission.storage.status;
      
      if (status.isGranted) {
        return true;
      }
      
      if (status.isDenied) {
        status = await Permission.storage.request();
      }
      
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      
      return status.isGranted;
    }
  }

  /// Request location permission
  /// Dipanggil saat user ingin:
  /// - Menggunakan "Use my location" di map picker
  /// - Melihat jarak ke lokasi scene di map viewer
  /// 
  /// Note: Geolocator sudah handle permission request internally,
  /// method ini sebagai wrapper jika diperlukan manual request
  static Future<bool> requestLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
    }
    
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    
    return status.isGranted;
  }

  /// Request microphone permission (untuk video recording)
  static Future<bool> requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }
    
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    
    return status.isGranted;
  }

  /// Check if Android version is 13 or above
  static Future<bool> _isAndroid13OrAbove() async {
    // Simple check - permission_handler sudah handle ini internally
    var status = await Permission.photos.status;
    return status != PermissionStatus.denied || 
           await Permission.videos.status != PermissionStatus.denied;
  }

  /// Show dialog to explain why permission is needed
  static Future<void> showPermissionDialog(
    BuildContext context,
    String permissionName,
    String reason,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF152033),
        title: Text(
          '$permissionName Permission Required',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          reason,
          style: const TextStyle(color: Color(0xFF8B8B8B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF8B8B8B)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
            ),
            child: const Text(
              'Open Settings',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

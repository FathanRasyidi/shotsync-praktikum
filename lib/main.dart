import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:danielshotsync/screens/main/login.dart';
import 'package:danielshotsync/screens/main/home.dart';
import 'config/supabase_config.dart';
import 'package:danielshotsync/utils/permissions_helper.dart';
import 'package:danielshotsync/utils/biometric_helper.dart';
import 'package:danielshotsync/utils/database_verification.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:danielshotsync/models/note.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  await Hive.initFlutter();
  Hive.registerAdapter(NoteAdapter());

  await SupabaseConfig.initialize();

  // Verify database schema
  print('\n🔍 Checking database schema...\n');
  await DatabaseVerification.checkProjectAdministratorColumn();

  runApp(const MyApp());
  await PermissionsHelper.requestStoragePermission();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'ShotSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const SplashScreen(),
    );
  }
}

// GetX Controller untuk SplashScreen
class SplashController extends GetxController {
  final isAuthenticating = false.obs;

  @override
  void onInit() {
    super.onInit();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 1));
    final isLoggedIn = await LoginController.isLoggedIn();
    if (isLoggedIn) {
      final isBiometricEnabled = await BiometricHelper.isBiometricEnabled();
      if (isBiometricEnabled) {
        _authenticate();
      } else {
        Get.offAll(() => const HomePage());
      }
    } else {
      Get.offAll(() => const LoginPage());
    }
  }

  Future<void> _authenticate() async {
    if (isAuthenticating.value) return;
    isAuthenticating.value = true;
    final authenticated = await BiometricHelper.authenticate();
    if (authenticated) {
      Get.offAll(() => const HomePage());
    } else {
      isAuthenticating.value = false;
      await LoginController.logout();
      Get.snackbar(
        'Authentication Failed',
        'Please Login Again',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}

// SplashScreen
class SplashScreen extends GetView<SplashController> {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Inisialisasi controller
    Get.put(SplashController());

    return Scaffold(
      backgroundColor: const Color(0xFF0F1828),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D9FF), Color(0xFF2196F3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.movie_filter_rounded,
                size: 70,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'ShotSync',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Film Production Management',
              style: TextStyle(fontSize: 14, color: Color(0xFF8B8B8B)),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D9FF)),
            ),
          ],
        ),
      ),
    );
  }
}

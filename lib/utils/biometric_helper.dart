import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class BiometricHelper {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> authenticate({
    String reason = 'Please authenticate to access ShotSync',
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      final availableBiometrics = await getAvailableBiometrics();
      if (availableBiometrics.isEmpty) return false;

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable ||
          e.code == auth_error.notEnrolled ||
          e.code == auth_error.lockedOut ||
          e.code == auth_error.permanentlyLockedOut ||
          e.code == auth_error.passcodeNotSet) {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
  }

  static Future<void> testBiometric() async {
    await _auth.isDeviceSupported();
    await _auth.canCheckBiometrics;
    await _auth.getAvailableBiometrics();
    await isBiometricAvailable();
    await isBiometricEnabled();
  }

  static Future<void> showBiometricSetupDialog() async {
    await testBiometric();
    final isAvailable = await isBiometricAvailable();
    if (!isAvailable) return;
    final biometrics = await getAvailableBiometrics();
    if (biometrics.isEmpty) return;

    await authenticate(reason: 'Authenticate to enable biometric lock');
    await setBiometricEnabled(true);
  }
}

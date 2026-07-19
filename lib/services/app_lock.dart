// Biometric app lock — Face ID / fingerprint gate on app open.
// Web fallback: no-op (never blocks). Enable via Settings.

import 'dart:async';

import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLock {
  static const _key = 'app_lock_enabled';
  static final _auth = LocalAuthentication();

  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, v);
  }

  static Future<bool> canUseBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final available = await _auth.canCheckBiometrics;
      return available;
    } catch (_) {
      return false;
    }
  }

  /// Prompts biometric. Returns true if authenticated or lock disabled.
  static Future<bool> unlock() async {
    if (!await isEnabled()) return true;
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock SyncNote',
        biometricOnly: false, // allow device PIN as fallback
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}

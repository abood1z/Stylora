import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// خدمة المصادقة البيومترية (البصمة/الوجه)
class BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // مفاتيح التخزين الآمن
  static const String _keyEmail = 'biometric_email';
  static const String _keyPassword = 'biometric_password';
  static const String _keyEnabled = 'biometric_enabled';

  /// التحقق مما إذا كان الجهاز يدعم البصمة وتوجد بصمات مسجلة
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Biometric Error: $e');
      return false;
    }
  }

  /// تنفيذ عملية التحقق من البصمة
  Future<bool> authenticate({String reason = 'يرجى لمس البصمة لتسجيل الدخول'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Authentication Error: $e');
      return false;
    }
  }

  /// ربط حساب المستخدم بالبصمة (حفظ البيانات مشفرة)
  Future<void> linkAccount(String email, String password) async {
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyPassword, value: password);
    await _storage.write(key: _keyEnabled, value: 'true');
  }

  /// إلغاء ربط البصمة
  Future<void> unlinkAccount() async {
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyPassword);
    await _storage.write(key: _keyEnabled, value: 'false');
  }

  /// الحصول على بيانات الدخول المحفوظة بعد نجاح البصمة
  Future<Map<String, String>?> getSavedCredentials() async {
    final isEnabled = await _storage.read(key: _keyEnabled);
    if (isEnabled != 'true') return null;

    final email = await _storage.read(key: _keyEmail);
    final password = await _storage.read(key: _keyPassword);

    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  /// التحقق مما إذا كانت الميزة مفعلة لهذا الحساب
  Future<bool> isLinked() async {
    final isEnabled = await _storage.read(key: _keyEnabled);
    return isEnabled == 'true';
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

// فئة التحكم في المصادقة الحيوية (Biometric Notifier)
// تسمح للمستخدم بتأمين التطبيق باستخدام البصمة أو الوجه
class BiometricNotifier extends StateNotifier<bool> {
  final LocalAuthentication _auth = LocalAuthentication();
  BiometricNotifier() : super(false);

  // تفعيل أو تعطيل خيار البصمة
  void toggle(bool value) {
    state = value;
  }

  // تنفيذ عملية المصادقة الفعلية (Authentication)
  Future<bool> authenticate() async {
    try {
      // التحقق من دعم الجهاز للمصادقة الحيوية (البصمة/الوجه)
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) return false;

      // طلب المصادقة من المستخدم
      return await _auth.authenticate(
        localizedReason: 'يرجى المصادقة للوصول إلى Stylora',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }
}

// المزود لحالة التفعيل والمصادقة الحيوية
final biometricEnabledProvider = StateNotifierProvider<BiometricNotifier, bool>((ref) {
  return BiometricNotifier();
});

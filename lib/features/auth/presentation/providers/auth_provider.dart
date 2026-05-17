import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

// المزود الرئيسي لحالة المصادقة (Stream)
// يراقب هذا المزود حالة المستخدم (مسجل دخول أم لا) بشكل آني من Firebase
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// المزود لحالة الضيف (Guest Provider)
// يسمح بالتنقل في التطبيق دون تسجيل دخول رسمي
final isGuestProvider = StateProvider<bool>((ref) => false);

// المزود لحالة التحقق بخطوتين (2FA Verification Status)
// يحدد ما إذا كان المستخدم قد أتم الخطوة الثانية من تسجيل الدخول
final otpVerifiedProvider = StateProvider<bool>((ref) => false);

// المزود للعمليات (تسجيل الخروج وغيره)
// يتعامل مع الحالات غير المتزامنة (Loading, Error, Data) أثناء تسجيل الخروج
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier();
});

// فئة التحكم في المصادقة (Auth Notifier)
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  // تنفيذ عملية تسجيل الخروج
  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await FirebaseAuth.instance.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

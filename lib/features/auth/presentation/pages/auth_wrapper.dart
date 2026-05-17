import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../home/presentation/pages/home_screen.dart';
import 'login_screen.dart';

// غلاف المصادقة (Auth Wrapper)
// هذه الودجت هي المسؤولة عن تحديد الشاشة الأولى للمستخدم بناءً على حالة تسجيل الدخول
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // استخدام StreamBuilder لمراقبة تغييرات حالة المصادقة من Firebase بشكل مباشر
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // عرض مؤشر تحميل أثناء التحقق من حالة المستخدم
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // إذا وجد مستخدم مسجل دخول
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;

          // تحديث إعدادات المستخدم المحفوظة سحابياً بعد استقرار الواجهة
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ref.read(settingsProvider.notifier).loadRemoteSettings(user.uid);
            }
          });

          // التوجه للشاشة الرئيسية
          return const HomeScreen();
        } else {
          // إذا لم يسجل المستخدم دخوله بعد، التوجه لشاشة تسجيل الدخول
          return const LoginScreen();
        }
      },
    );
  }
}

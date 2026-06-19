import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SeedAdminButton extends StatelessWidget {
  const SeedAdminButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        try {
          final auth = FirebaseAuth.instance;
          final firestore = FirebaseFirestore.instance;

          // 1. محاولة حذف حساب الأدمن القديم الأول (admin@stylora.com) إن وُجد
          try {
            final oldCred1 = await auth.signInWithEmailAndPassword(
              email: 'admin@stylora.com',
              password: 'adminPassword123!',
            );
            final uid1 = oldCred1.user?.uid;
            await oldCred1.user?.delete();
            if (uid1 != null) {
              await firestore.collection('users').doc(uid1).delete();
            }
            debugPrint('Old admin1 account deleted successfully.');
          } catch (e) {
            debugPrint('No old admin1 account found or delete bypassed: $e');
          }

          // 2. محاولة حذف حساب الأدمن القديم الثاني (admin2@stylora.com) إن وُجد
          try {
            final oldCred2 = await auth.signInWithEmailAndPassword(
              email: 'admin2@stylora.com',
              password: 'StyloraAdmin2026!',
            );
            final uid2 = oldCred2.user?.uid;
            await oldCred2.user?.delete();
            if (uid2 != null) {
              await firestore.collection('users').doc(uid2).delete();
            }
            debugPrint('Old admin2 account deleted successfully.');
          } catch (e) {
            debugPrint('No old admin2 account found or delete bypassed: $e');
          }

          // 3. إنشاء حساب الأدمن الجديد الثالث (admin3@stylora.com)
          const newEmail = 'admin3@stylora.com';
          const newPassword = 'StyloraAdmin2026!';

          UserCredential? cred;
          try {
            cred = await auth.createUserWithEmailAndPassword(
              email: newEmail,
              password: newPassword,
            );
          } catch (e) {
            // إذا كان الحساب موجوداً بالفعل، نسجل الدخول لجلب المعرف
            debugPrint('User creation warning (might exist): $e');
            cred = await auth.signInWithEmailAndPassword(
              email: newEmail,
              password: newPassword,
            );
          }

          if (cred.user != null) {
            await firestore.collection('users').doc(cred.user!.uid).set({
              'email': newEmail,
              'role': 'admin',
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            // إعداد التكوين الافتراضي للتطبيق
            await firestore.collection('app_config').doc('update_info').set({
              'latest_version': '1.0.0',
              'min_version': '1.0.0',
              'update_url': 'https://example.com',
            }, SetOptions(merge: true));

            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'تم حذف الحسابات القديمة وإنشاء حساب الإدارة الجديد بنجاح.\nسجل دخول بـ: admin3@stylora.com',
                ),
              ),
            );
          }
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      },
      child: const Text('Seed Admin Account'),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

// خدمة المصادقة (Authentication Service)
// تتعامل هذه الخدمة مع Firebase Auth لتسجيل الدخول وإنشاء الحسابات
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // الحصول على المستخدم الحالي المسجل
  User? get currentUser => _auth.currentUser;

  // تدفق (Stream) لمراقبة تغييرات حالة تسجيل الدخول (دخول/خروج)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // تسجيل الدخول باستخدام البريد الإلكتروني وكلمة المرور
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('AuthService: signInWithEmailAndPassword error: $e');
      rethrow;
    }
  }

  // إنشاء حساب جديد بالبريد الإلكتروني وكلمة المرور
  Future<UserCredential> signUpWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('AuthService: signUpWithEmailAndPassword error: $e');
      rethrow;
    }
  }

  // تسجيل الخروج من كافة الخدمات
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut(); // الخروج من جوجل أيضاً إذا كان مستخدماً
    } catch (e) {
      debugPrint('AuthService: signOut error: $e');
      rethrow;
    }
  }

  // إرسال بريد لإعادة تعيين كلمة المرور
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('AuthService: sendPasswordResetEmail error: $e');
      rethrow;
    }
  }

  // تسجيل الدخول باستخدام Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // المستخدم ألغى العملية

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('AuthService: signInWithGoogle error: $e');
      rethrow;
    }
  }


}

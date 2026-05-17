import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// تعريف الأدوار المتاحة للمستخدمين (مستخدم عادي أو تاجر)
enum UserRole { user, trader }

// كلاس إدارة الحالة الخاص بالمصادقة (Auth)
class AuthProvider extends ChangeNotifier {
  // مراجع لخدمات Firebase للمصادقة وقاعدة البيانات Firestore
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // متغيرات خاصة لتخزين حالة المستخدم وبياناته الشخصية
  bool _isLoggedIn = false;
  UserRole _role = UserRole.user;
  String? _gender;
  DateTime? _birthDate;
  double? _height;
  double? _weight;
  String? _skinColor;

  // دوال الحصول على البيانات (Getters) للوصول الآمن للمتغيرات من الواجهة
  bool get isLoggedIn => _isLoggedIn;
  UserRole get role => _role;
  String? get gender => _gender;
  DateTime? get birthDate => _birthDate;
  double? get height => _height;
  double? get weight => _weight;
  String? get skinColor => _skinColor;

  // منشئ الكلاس (Constructor) الذي يستمع لتغييرات حالة المصادقة
  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _isLoggedIn = true;
        // إذا كان المستخدم مسجل دخول، قم بتحميل بياناته من Firestore
        _loadUserData(user.uid);
      } else {
        _isLoggedIn = false;
        // إشعار الواجهات بتغيير الحالة (تسجيل خروج)
        notifyListeners();
      }
    });
  }

  // تحميل بيانات المستخدم من قاعدة البيانات
  Future<void> _loadUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      // تحويل البيانات من Firestore إلى متغيرات في الكود
      _role = data['role'] == 'trader' ? UserRole.trader : UserRole.user;
      _gender = data['gender'];
      _height = data['height']?.toDouble();
      _weight = data['weight']?.toDouble();
      _skinColor = data['skinColor'];
      if (data['birthDate'] != null) {
        _birthDate = (data['birthDate'] as Timestamp).toDate();
      }
      // إشعار المستمعين لإعادة بناء الواجهات بالبيانات الجديدة
      notifyListeners();
    }
  }

  // دالة تسجيل الدخول بالبريد الإلكتروني وكلمة المرور
  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      // إعادة إلقاء الخطأ للتعامل معه في الواجهة الأمامية
      rethrow;
    }
  }

  // دالة إنشاء حساب جديد وتحديد دور المستخدم
  Future<void> signUp(String email, String password, UserRole role) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      // إنشاء مستند جديد للمستخدم في Firestore
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'email': email,
        'role': role == UserRole.trader ? 'trader' : 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _role = role;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // دالة حفظ وتحديث بيانات الملف الشخصي (Profile)
  Future<void> saveProfile({
    required String gender,
    required DateTime birthDate,
    required double height,
    required double weight,
    required String skinColor,
  }) async {
    final user = _auth.currentUser;
    if (user != null) {
      // تحديث البيانات في Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'gender': gender,
        'birthDate': birthDate,
        'height': height,
        'weight': weight,
        'skinColor': skinColor,
      });
      // تحديث المتغيرات المحلية في الكود
      _gender = gender;
      _birthDate = birthDate;
      _height = height;
      _weight = weight;
      _skinColor = skinColor;
      notifyListeners();
    }
  }

  // دالة تسجيل الخروج من الحساب
  void logout() async {
    await _auth.signOut();
  }
}

// كلاس إدارة الحالة للتنقل داخل التطبيق (Navigation)
class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0; // الفهرس الحالي لـ BottomNavigationBar
  int get currentIndex => _currentIndex;

  // تغيير الفهرس الحالي وتحديث الواجهات
  void setIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }
}

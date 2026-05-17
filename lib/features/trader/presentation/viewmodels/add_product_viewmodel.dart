import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/ai_automation_service.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/services/service_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/providers/settings_provider.dart';

// نموذج العرض لإضافة المنتجات (Add Product View Model)
// يقوم بالتنسيق بين خدمات الرفع، الذكاء الاصطناعي، وواجهة المستخدم
class AddProductViewModel extends ChangeNotifier {
  final AIAutomationService _aiService; // خدمة أتمتة الذكاء الاصطناعي
  final User? _user; // بيانات المستخدم الحالي (التاجر)
  final Map<String, dynamic>? _userData; // بيانات المتجر الإضافية

  bool isUploading = false; // حالة الرفع الحالية
  String? errorMessage; // رسالة الخطأ في حال الفشل

  AddProductViewModel(this._aiService, this._user, this._userData);

  // منطق رفع المنتج بالكامل
  Future<bool> uploadProduct(File image, double price, String description, String season) async {
    if (_user == null) {
      errorMessage = "المستخدم غير مسجل الدخول";
      return false;
    }

    isUploading = true;
    errorMessage = null;
    notifyListeners(); // إشعار الواجهة ببدء التحميل

    try {
      // 1. رفع الصورة إلى Cloudinary للحصول على رابط ثابت
      final imageUrl = await CloudinaryService.uploadImage(image);
      if (imageUrl == null) throw Exception('فشل رفع الصورة إلى التخزين السحابي');

      // 2. المعالجة بالذكاء الاصطناعي وحفظ البيانات في Firestore
      // تقوم هذه الدالة بتصنيف المنتج (الفئة، اللون) آلياً
      await _aiService.processAndUploadProduct(
        imageFile: image,
        imageUrl: imageUrl,
        price: price,
        storeName: _userData?['storeName'] ?? _userData?['name'] ?? 'متجر عام',
        storeID: _user.uid,
        isAvailable: true,
        season: season,
        description: description,
        country: _userData?['country'],
      );

      isUploading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      isUploading = false;
      notifyListeners(); // إشعار الواجهة بالفشل وتحديث الحالة
      return false;
    }
  }
}

// موفر الحالة لنموذج إضافة المنتجات
final addProductViewModelProvider = ChangeNotifierProvider.autoDispose<AddProductViewModel>((ref) {
  return AddProductViewModel(
    AIAutomationService(), // إنشاء مثيل جديد لخدمة الأتمتة
    ref.watch(authServiceProvider).currentUser,
    ref.watch(settingsProvider).userData,
  );
});

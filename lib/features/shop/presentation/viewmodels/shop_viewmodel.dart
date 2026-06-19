import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../core/models/product_model.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/providers/settings_provider.dart';

// نموذج عرض المتجر (Shop View Model)
// يدير تدفق البيانات للمنتجات المتاحة في المتجر من قاعدة البيانات
class ShopViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService; // خدمة التعامل مع Firestore
  final User? _currentUser;
  final Map<String, dynamic>? _userData;

  ShopViewModel(this._firestoreService, this._currentUser, this._userData);

  // عرض تدفق (Stream) للمنتجات المتاحة للتحديث اللحظي في الواجهة (مع الفلترة حسب الموقع)
  Stream<List<ProductModel>> get availableProductsStream {
    final role = _userData?['role'] ?? 'user';
    final userCountry = _userData?['country'];

    // التاجر يرى بضاعته فقط في متجره الخاص (My Products)
    if ((role == 'merchant' || role == 'trader') && _currentUser != null) {
      return _firestoreService.watchTraderProducts(_currentUser.uid);
    }
    // المستخدم العادي يرى بضاعة المتاجر جميعها
    return _firestoreService.watchAvailableProducts();
  }
}

// موفر الحالة لنموذج عرض المتجر
final shopViewModelProvider = ChangeNotifierProvider.autoDispose<ShopViewModel>((ref) {
  return ShopViewModel(
    ref.watch(firestoreServiceProvider),
    ref.watch(authServiceProvider).currentUser,
    ref.watch(settingsProvider).userData,
  );
});

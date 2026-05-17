import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../core/models/product_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

// نموذج العرض للوحة تحكم التاجر (Trader Dashboard View Model)
// يدير تدفق البيانات والمقاييس الخاصة بالمتجر في الوقت الفعلي
class TraderDashboardViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService; // خدمة التعامل مع قاعدة البيانات
  final User? _user; // بيانات المستخدم الحالي (التاجر)

  TraderDashboardViewModel(this._firestoreService, this._user);

  // الحصول على تدفق مباشر لمنتجات التاجر لعرضها في المخزون
  Stream<List<ProductModel>> get traderProductsStream {
    if (_user == null) return Stream.value([]);
    return _firestoreService.watchTraderProducts(_user.uid);
  }

  // جلب إحصائيات المتجر (المبيعات، المشاهدات، إلخ)
  // ملاحظة: حالياً يتم استخدام بيانات وهمية (Placeholder) لحين تطبيق تجميعات البيانات في Firestore
  Future<Map<String, dynamic>> fetchStoreStats() async {
    return {
      'totalSales': '0 SR',
      'productViews': '0',
      'activeListings': '0',
    };
  }
}

// موفر الحالة لنموذج لوحة تحكم التاجر
final traderDashboardViewModelProvider = ChangeNotifierProvider.autoDispose<TraderDashboardViewModel>((ref) {
  return TraderDashboardViewModel(
    ref.watch(firestoreServiceProvider),
    ref.watch(authServiceProvider).currentUser,
  );
});

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../core/models/closet_item_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

// نموذج عرض الخزانة (Closet ViewModel)
// يدير حالة وعمليات الخزانة الرقمية للمستخدم، بما في ذلك التصفية والحذف الذكي
class ClosetViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final User? _user;

  String? selectedCategory; // الفئة المختارة (Tops, Bottoms, Shoes) - null تعني الكل
  String selectedColor = 'الكل'; // اللون المختار للتصفية
  String sortOrder = 'الأحدث'; // ترتيب العرض

  // تصنيفات ملابس علوية (Tops) بناءً على مخرجات نموذج الذكاء الاصطناعي
  final List<String> _tops = ['Blazer', 'Blouse', 'Cardigan', 'Coat', 'Crop', 'Dress', 'Halter', 'Henley', 'Hoodie', 'Jacket', 'Jersey', 'Jumpsuit', 'Kimono', 'Parka', 'Poncho', 'Romper', 'Sweater', 'Tank', 'Tee', 'Top', 'Turtleneck'];
  // تصنيفات ملابس سفلية (Bottoms)
  final List<String> _bottoms = ['Capris', 'Chinos', 'Culottes', 'Cutoffs', 'Jeans', 'Joggers', 'Leggings', 'Pants', 'Shorts', 'Skirt', 'Trunks'];
  // تصنيفات أحذية (Shoes) وغيرها
  final List<String> _shoes = ['Others'];

  ClosetViewModel(this._firestoreService, this._user);

  // تغيير الفئة المختارة وتحديث الواجهة
  void filterByCategory(String? category) {
    selectedCategory = category;
    notifyListeners();
  }

  // عملية الحذف الذكي (Smart Deletion)
  // تقوم بحذف قطعة الملابس وحذف أي تنسيقات (Outfits) كانت تعتمد عليها لمنع الأخطاء
  Future<void> deleteItem(String id) async {
    try {
      // 1. حذف القطعة من الخزانة في Firestore
      await _firestoreService.deleteClosetItem(id);
      
      // 2. البحث عن التنسيقات التي تحتوي على هذه القطعة وحذفها آلياً
      final outfitsSnapshot = await _firestoreService.getOutfitsContainingItem(id);
      for (var doc in outfitsSnapshot.docs) {
        await doc.reference.delete();
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error in smart deleting item: $e');
    }
  }

  // تيار البيانات (Stream) لمراقبة الخزانة بشكل حي وتطبيق التصفية والترتيب برمجياً
  Stream<List<ClosetItemModel>> get userClosetStream {
    if (_user == null) return Stream.value([]);
    
    return _firestoreService.watchUserCloset(_user.uid).map((items) {
      var filtered = List<ClosetItemModel>.from(items);

      // تطبيق التصفية حسب الفئة المختارة
      if (selectedCategory != null) {
        if (selectedCategory == 'top') {
          filtered = filtered.where((item) => _tops.contains(item.category)).toList();
        } else if (selectedCategory == 'bottom') {
          filtered = filtered.where((item) => _bottoms.contains(item.category)).toList();
        } else if (selectedCategory == 'shoes') {
          filtered = filtered.where((item) => _shoes.contains(item.category)).toList();
        }
      }

      // الترتيب حسب التاريخ (الأحدث أولاً) لتسهيل العثور على المشتريات الجديدة
      filtered.sort((a, b) {
        final aDate = a.timestamp ?? DateTime(2000);
        final bDate = b.timestamp ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      return filtered;
    });
  }
}

// المزود الخاص بنموذج عرض الخزانة
final closetViewModelProvider = ChangeNotifierProvider.autoDispose<ClosetViewModel>((ref) {
  return ClosetViewModel(
    ref.watch(firestoreServiceProvider),
    ref.watch(authServiceProvider).currentUser,
  );
});

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/closet_item_model.dart';
import '../models/outfit_model.dart';

// نموذج بيانات لمنتجات المتجر المستخدمة في التنسيقات المقترحة (Store Product Model)
class StoreProductModel {
  final String id;
  final String name;
  final String imageUrl;
  final double price;
  final String category;
  final String color;
  final String storeUrl;

  StoreProductModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.category,
    required this.color,
    required this.storeUrl,
  });

  factory StoreProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoreProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      category: data['category'] ?? '',
      color: data['color'] ?? '',
      storeUrl: data['storeUrl'] ?? '',
    );
  }
}

// خدمة توليد التنسيقات (Outfit Generator Service)
// تعتبر هذه الخدمة "العقل المدبر" لعمليات التنسيق التلقائي، حيث تستخدم معايير جمالية لتنسيق الألوان والقطع
class OutfitGeneratorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // قاموس تناسق الألوان (Color Harmony Dictionary)
  // يمثل مصفوفة من القواعد الجمالية التي تحدد "الألوان المتوافقة" لكل لون أساسي لضمان طقم متناسق بصرياً
  final Map<String, List<String>> _colorHarmony = {
    'blue': ['beige', 'brown', 'black', 'white', 'grey', 'khaki', 'navy'],
    'red': ['black', 'white', 'blue', 'navy', 'grey'],
    'black': [
      'white',
      'grey',
      'blue',
      'red',
      'beige',
      'brown',
      'black',
      'green',
      'yellow',
    ],
    'white': [
      'black',
      'blue',
      'grey',
      'brown',
      'red',
      'green',
      'navy',
      'white',
      'pink',
      'purple',
    ],
    'green': ['brown', 'beige', 'black', 'white', 'navy', 'grey'],
    'yellow': ['black', 'white', 'grey', 'blue', 'navy'],
    'brown': ['beige', 'white', 'green', 'blue', 'black', 'khaki'],
    'grey': ['black', 'white', 'blue', 'red', 'pink', 'navy', 'black'],
    'pink': ['white', 'black', 'grey', 'blue', 'navy'],
    'orange': ['black', 'white', 'blue', 'brown', 'navy'],
    'purple': ['white', 'black', 'grey', 'blue'],
    'silver': ['black', 'white', 'blue', 'navy'],
  };

  // تصنيفات القطع (Apparel Categorization) لتحديد أدوار الملابس في الطقم
  final List<String> _tops = [
    'blazer',
    'coat',
    'denim_jacket',
    'hoodie',
    'jacket',
    'polo',
    'shirt',
    'shirt2',
    'sweater',
    't_shirt',
    'track_jacket',
    'dress',
  ];
  final List<String> _bottoms = ['trousers', 'shorts', 'jeans', 'rok'];
  final List<String> _shoes = ['shoes', 'boots', 'sneakers'];

  /// توليد "تنسيق ذكي" (Smart Outfit) من خزانة المستخدم فور إضافة قطعة جديدة
  Future<OutfitModel?> generateSmartOutfit(ClosetItemModel newItem) async {
    try {
      final uid = newItem.userID;
      final category = newItem.category.toLowerCase();
      final color = newItem.color.toLowerCase();

      // جلب ملابس المستخدم المتوفرة من نفس الموسم (صيغ، شتاء) لضمان منطقية الطقم
      final snapshot = await _firestore
          .collection('User_Closet')
          .where('userID', isEqualTo: uid)
          .where('season', isEqualTo: newItem.season)
          .get();

      List<ClosetItemModel> closetItems = snapshot.docs
          .map((doc) => ClosetItemModel.fromFirestore(doc))
          .where((item) => item.id != newItem.id)
          .toList();

      ClosetItemModel? top;
      ClosetItemModel? bottom;
      ClosetItemModel? shoe;

      // 1. تحديد مكان القطعة الجديدة في الطقم (علوي، سفلي، أو حذاء)
      if (_tops.contains(category)) {
        top = newItem;
      } else if (_bottoms.contains(category))
        bottom = newItem;
      else if (_shoes.contains(category))
        shoe = newItem;

      // 2. تحديد مجموعة الألوان التي ستتماشى مع هذه القطعة
      List<String> harmoniousColors =
          _colorHarmony[color] ?? ['black', 'white', 'blue'];

      // 3. البحث عن "المتممات" المفقودة من داخل الخزانة (تنسيق داخلي)
      top ??= _findMatch(closetItems, _tops, harmoniousColors);
      bottom ??= _findMatch(closetItems, _bottoms, harmoniousColors);
      shoe ??= _findMatch(closetItems, _shoes, harmoniousColors);

      // تجميع القطع التي تم العثور عليها وحفظ الطقم إذا تكونت قطعتان على الأقل
      List<ClosetItemModel> finalItems = [
        if (top != null) top,
        if (bottom != null) bottom,
        if (shoe != null) shoe,
      ];

      if (finalItems.length >= 2) {
        final outfit = OutfitModel(
          id: '',
          userID: uid,
          name: 'تنسيق ${newItem.season == 'Summer' ? 'صيفي' : 'شتوي'} متكامل',
          itemIds: finalItems.map((e) => e.id).toList(),
          itemImageUrls: finalItems.map((e) => e.imageUrl).toList(),
          createdAt: DateTime.now(),
        );

        // تخزين التنسيق المولد في قاعدة البيانات لتسهيل عرضه لمستقبلاً
        final docRef = await _firestore
            .collection('outfits')
            .add(outfit.toMap());
        return outfit.copyWith(id: docRef.id);
      }
    } catch (e) {
      debugPrint('Error generating triple smart outfit: $e');
    }
    return null;
  }

  // خوارزمية البحث عن تطابق (Matching Logic):
  // تبدأ بالبحث عن قطعة تطابق (الفئة + اللون المتناسق) معاً، وإذا لم تجد، تكتفي بمطابقة الفئة لضمان تكوين الطقم
  ClosetItemModel? _findMatch(
    List<ClosetItemModel> items,
    List<String> categories,
    List<String> colors,
  ) {
    try {
      // الأولوية الأولى: تطابق تام للفئة ولون متناسق جمالياً
      return items.firstWhere(
        (item) =>
            categories.contains(item.category.toLowerCase()) &&
            colors.contains(item.color.toLowerCase()),
        orElse: () => items.firstWhere(
          (item) => categories.contains(
            item.category.toLowerCase(),
          ), // الأولوية الثانية: أي قطعة من نفس الفئة المطلوبة
          orElse: () => throw Exception('Not found'),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// اقتراح قطع من المتجر (Store Matches) تكمل القطعة المرفوعة حديثاً
  Future<List<StoreProductModel>> generateStoreMatches(
    ClosetItemModel newItem,
  ) async {
    try {
      final category = newItem.category.toLowerCase();
      final color = newItem.color.toLowerCase();
      final season = newItem.season;

      // تحديد ما نود اقتراحه (إذا أضاف المستخدم قميصاً، نقترح بنطالاً، والعكس صحيح)
      bool isTop = _tops.contains(category);
      List<String> targetCategories = isTop ? _bottoms : _tops;
      List<String> harmoniousColors =
          _colorHarmony[color] ?? ['black', 'white'];

      // جلب المنتجات المتاحة في المتجر والتي تتبع نفس الموسم ولديها ألوان متناسقة مع القطعة الحالية
      final snapshot = await _firestore
          .collection('Products')
          .where('status', isEqualTo: 'active')
          .where('isAvailable', isEqualTo: true) // جلب المنتجات غير المباعة فقط
          .where('season', isEqualTo: season)
          .where('color', whereIn: harmoniousColors.take(10).toList())
          .get();

      if (snapshot.docs.isEmpty) return [];

      // تصفية النتائج بناءً على الفئة المستهدفة (علوي أو سفلي)
      return snapshot.docs
          .map((doc) => StoreProductModel.fromFirestore(doc))
          .where((p) => targetCategories.contains(p.category.toLowerCase()))
          .toList();
    } catch (e) {
      debugPrint('Error generating store matches: $e');
      return [];
    }
  }

  // بث مباشر لمراقبة كافة التنسيقات المولدة للمستخدم وترتيبها زمنياً
  Stream<List<OutfitModel>> watchUserOutfits(String uid) {
    return _firestore
        .collection('outfits')
        .where('userID', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => OutfitModel.fromFirestore(doc))
              .toList();
          // عرض الأطقم المضافة حديثاً في أعلى القائمة
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }
}

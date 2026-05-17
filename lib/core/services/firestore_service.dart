import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../models/closet_item_model.dart';

// خدمة الربط المركزية مع قاعدة بيانات Firebase Firestore (Firestore Service)
// توفر هذه الفئة جميع العمليات اللازمة لإدارة بيانات المنتجات، الخزانة الرقمية، وحسابات المستخدمين
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // مراجع لمجموعات البيانات (Collections) لسهولة الوصول إليها في الاستعلامات
  CollectionReference get _usersCollection => _db.collection('users');
  CollectionReference get _storesCollection => _db.collection('shop_stores');
  CollectionReference get _looksCollection => _db.collection('daily_looks');
  CollectionReference get _productsCollection => _db.collection('Products');
  CollectionReference get _closetCollection => _db.collection('User_Closet');

  // --- قسم إدارة منتجات المتاجر (Store Products) ---
  
  // مراقبة المنتجات المتاحة حالياً في المتجر العام مع دعم الفلترة حسب الدولة
  Stream<List<ProductModel>> watchAvailableProducts({String? country}) {
    Query query = _productsCollection.where('isAvailable', isEqualTo: true);
    
    if (country != null && country.isNotEmpty) {
      query = query.where('country', isEqualTo: country);
    }
    
    return query.snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList());
  }

  // إضافة منتج جديد بواسطة التاجر ليتم عرضه في المتجر
  Future<void> addProduct(ProductModel product) async {
    await _productsCollection.add(product.toMap());
  }

  // مراقبة قائمة منتجات تاجر محدد مع ترتيبها من الأحدث للأقدم
  Stream<List<ProductModel>> watchTraderProducts(String storeID) {
    return _productsCollection
        .where('storeID', isEqualTo: storeID)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList());
  }

  // --- قسم الخزانة الرقمية للمستخدم (User Digital Closet) ---
  
  // مراقبة محتويات خزانة المستخدم مع دعم الفلترة المتقدمة (الفئة، اللون، الموسم)
  Stream<List<ClosetItemModel>> watchUserCloset(String uid, {String? category, String? color, String? season}) {
    Query query = _closetCollection.where('userID', isEqualTo: uid);
    
    // فلترة اختيارية بناءً على المعاملات الممررة
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    if (color != null && color.isNotEmpty) {
      query = query.where('color', isEqualTo: color);
    }
    if (season != null && season.isNotEmpty) {
      query = query.where('season', isEqualTo: season);
    }

    return query.snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => ClosetItemModel.fromFirestore(doc)).toList());
  }

  // حفظ قطعة ملابس جديدة للخزانة تم تحليلها بواسطة الذكاء الاصطناعي
  Future<void> addClosetItem(ClosetItemModel item) async {
    await _closetCollection.add(item.toMap());
  }

  // حذف قطعة من الخزانة (مثلاً عند التخلص منها أو بيعها)
  Future<void> deleteClosetItem(String docId) async {
    await _closetCollection.doc(docId).delete();
  }

  // --- إدارة بيانات وحسابات المستخدمين (User Management) ---

  // حفظ أو تحديث بيانات المستخدم الأساسية عند التسجيل أو تسجيل الدخول
  Future<void> saveUserData(User user, {String? name, Map<String, dynamic>? additionalData}) async {
    try {
      final docRef = _usersCollection.doc(user.uid);
      final docSnapshot = await docRef.get();

      final data = {
        'email': user.email,
        'lastSeen': FieldValue.serverTimestamp(),
        ...?additionalData,
      };

      if (name != null) data['name'] = name;

      // في حال كان المستخدم جديداً، نقوم بتهيئة الإعدادات الافتراضية
      if (!docSnapshot.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
        data['language'] = data['language'] ?? 'ar';
        data['theme'] = data['theme'] ?? 'light';
        data['notifications'] = data['notifications'] ?? true;
        data['biometric'] = data['biometric'] ?? false;
        data['role'] = data['role'] ?? 'user';
        data['isProfileComplete'] = data['isProfileComplete'] ?? false;
        await docRef.set(data);
      } else {
        // تحديث البيانات الحالية مع الحفاظ على الحقول الأخرى (Merge)
        await docRef.set(data, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('FirestoreService: saveUserData error: $e');
      rethrow;
    }
  }

  // مراقبة التغييرات في ملف المستخدم لبروفايل تفاعلي
  Stream<DocumentSnapshot> watchUserData(String uid) {
    return _usersCollection.doc(uid).snapshots();
  }

  // جلب بيانات المستخدم لمرة واحدة (يستخدم غالباً في مهام الإدارة)
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('FirestoreService: getUserData error: $e');
      rethrow;
    }
  }

  // تحديث إعدادات مخصصة (مثل تفعيل البصمة أو وضع الداكن)
  Future<void> updateSettings(String uid, Map<String, dynamic> settings) async {
    try {
      await _usersCollection.doc(uid).set(settings, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreService: updateSettings error: $e');
      rethrow;
    }
  }

  // --- التفاعلات الفرعية والإضافات ---

  // مراقبة قائمة "المفضلة" أو ممتلكات الخزانة بنظام المجموعات الفرعية
  Stream<List<Map<String, dynamic>>> watchWardrobe(String uid) {
    return _usersCollection
        .doc(uid)
        .collection('wardrobe')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  // مراقبة المتاجر الشريكة (المحلات المسجلة في التطبيق)
  Stream<List<Map<String, dynamic>>> watchShopStores() {
    return _storesCollection.snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}).toList());
  }

  // مراقبة الإطلالات اليومية المنسقة بواسطة الذكاء الاصطناعي
  Stream<List<Map<String, dynamic>>> watchDailyLooks() {
    return _looksCollection.snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}).toList());
  }

  // استرجاع كافة التنسيقات التي تعتمد على قطعة معينة (لأغراض الحذف المتتالي)
  Future<QuerySnapshot> getOutfitsContainingItem(String itemId) async {
    return await _db.collection('outfits')
        .where('itemIds', arrayContains: itemId)
        .get();
  }

  // --- محرك البحث المطور (Advanced Search Engine) ---

  // وظيفة بحث شاملة تبحث في المتجر وخزانة المستخدم في آن واحد مع دعم الترجمة للعربية
  Future<Map<String, List<dynamic>>> searchStoreAndCloset(String uid, String searchKey) async {
    final lowerKey = searchKey.toLowerCase().trim();
    if (lowerKey.isEmpty) return {'store': [], 'closet': []};

    // خريطة لربط الكلمات العربية بتصنيفات النماذج (لجعل البحث يفهم لغة المستخدم)
    final Map<String, List<String>> arabicMapping = {
      'تيشرت': ['t_shirt', 'polo'],
      'قميص': ['shirt', 'shirt2', 'polo'],
      'بنطلون': ['jeans', 'trousers', 'shorts'],
      'جينز': ['jeans'],
      'جاكيت': ['jacket', 'denim_jacket', 'track_jacket', 'blazer'],
      'حذاء': ['shoes'],
      'فستان': ['dress'],
      'هودي': ['hoodie'],
      'سويتر': ['sweater'],
      'تنورة': ['rok'],
      'شورت': ['shorts'],
    };

    List<String> searchTerms = [lowerKey];
    for (var entry in arabicMapping.entries) {
      if (lowerKey.contains(entry.key) || entry.key.contains(lowerKey)) {
        searchTerms.addAll(entry.value); // إضافة المكافئات الإنجليزية لمحرك البحث
      }
    }
    
    // إزالة المصطلحات المكررة
    searchTerms = searchTerms.toSet().toList();

    // 1. استعلام البحث في المتجر العام (مع مراعاة الدولة)
    Query storeQuery = _productsCollection;
    
    // محرك البحث يجب أن يعرض فقط منتجات دولة المستخدم
    final userData = await getUserData(uid);
    final userCountry = userData?['country'];
    if (userCountry != null) {
      storeQuery = storeQuery.where('country', isEqualTo: userCountry);
    }

    final storeSnapshot = await storeQuery.get();
    final storeResults = storeSnapshot.docs
        .map((doc) => ProductModel.fromFirestore(doc))
        .where((p) => 
            searchTerms.any((term) => 
              p.category.toLowerCase().contains(term) || 
              p.color.toLowerCase().contains(term) ||
              p.storeName.toLowerCase().contains(term)
            ))
        .toList();

    // 2. استعلام البحث في خزانة المستخدم الخاصة
    final closetSnapshot = await _closetCollection.where('userID', isEqualTo: uid).get();
    final closetResults = closetSnapshot.docs
        .map((doc) => ClosetItemModel.fromFirestore(doc))
        .where((c) => 
            searchTerms.any((term) => 
              c.category.toLowerCase().contains(term) || 
              c.color.toLowerCase().contains(term)
            ))
        .toList();

    return {
      'store': storeResults,
      'closet': closetResults,
    };
  }
}

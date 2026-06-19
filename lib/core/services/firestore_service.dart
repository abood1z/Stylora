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
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs;
          // Sort docs in memory by the 'timestamp' field inside doc data to avoid requiring a composite index
          final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
          sortedDocs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>?;
            final bData = b.data() as Map<String, dynamic>?;
            final aTime = aData?['timestamp'] as Timestamp?;
            final bTime = bData?['timestamp'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
          return sortedDocs.map((doc) => ProductModel.fromFirestore(doc)).toList();
        });
  }

  // حذف منتج خاص بالتاجر
  Future<void> deleteTraderProduct(String productId) async {
    await _productsCollection.doc(productId).delete();
  }

  // تحديث بيانات منتج
  Future<void> updateTraderProduct(String productId, Map<String, dynamic> data) async {
    await _productsCollection.doc(productId).update(data);
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
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  // مراقبة المتاجر الحقيقية (المستخدمين بصلاحية تاجر)
  Stream<List<Map<String, dynamic>>> watchShopStores() {
    return _usersCollection
        .where('role', whereIn: ['merchant', 'trader'])
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id}).toList());
  }

  // مراقبة الإطلالات اليومية المنسقة بواسطة الذكاء الاصطناعي
  Stream<List<Map<String, dynamic>>> watchDailyLooks() {
    return _looksCollection.snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id}).toList());
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
    final isAll = lowerKey.isEmpty || lowerKey == 'all' || lowerKey == 'الكل';

    // 1. استعلام البحث في المتجر العام (مع مراعاة الدولة)
    Query storeQuery = _productsCollection;
    
    // محرك البحث يجب أن يعرض فقط منتجات دولة المستخدم
    final userData = await getUserData(uid);
    final userCountry = userData?['country'];
    if (userCountry != null) {
      storeQuery = storeQuery.where('country', isEqualTo: userCountry);
    }

    final storeSnapshot = await storeQuery.get();
    var storeResults = storeSnapshot.docs
        .map((doc) => ProductModel.fromFirestore(doc))
        .toList();

    // 2. استعلام البحث في خزانة المستخدم الخاصة
    final closetSnapshot = await _closetCollection.where('userID', isEqualTo: uid).get();
    var closetResults = closetSnapshot.docs
        .map((doc) => ClosetItemModel.fromFirestore(doc))
        .toList();

    if (isAll) {
      return {
        'store': storeResults,
        'closet': closetResults,
      };
    }

    // خريطة لربط الكلمات وتوسيع نطاق البحث لتشمل الأنماط والمواسم
    final Map<String, List<String>> keywordExpansion = {
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
      'casual': ['t_shirt', 'jeans', 'shorts', 'polo'],
      'كاجوال': ['t_shirt', 'jeans', 'shorts', 'polo'],
      'formal': ['blazer', 'trousers', 'shirt', 'coat'],
      'رسمي': ['blazer', 'trousers', 'shirt', 'coat'],
      'sporty': ['track_jacket', 'hoodie', 'shorts', 'sneakers'],
      'رياضي': ['track_jacket', 'hoodie', 'shorts', 'sneakers'],
      'evening': ['dress', 'blazer'],
      'سهرة': ['dress', 'blazer'],
      'autumn': ['coat', 'hoodie', 'sweater', 'jacket', 'winter'],
      'خريفي': ['coat', 'hoodie', 'sweater', 'jacket', 'winter'],
    };

    List<String> searchTerms = [lowerKey];
    for (var entry in keywordExpansion.entries) {
      if (lowerKey.contains(entry.key) || entry.key.contains(lowerKey)) {
        searchTerms.addAll(entry.value);
      }
    }
    
    searchTerms = searchTerms.toSet().toList();

    storeResults = storeResults
        .where((p) => 
            searchTerms.any((term) => 
              p.category.toLowerCase().contains(term) || 
              p.color.toLowerCase().contains(term) ||
              p.storeName.toLowerCase().contains(term)
            ))
        .toList();

    closetResults = closetResults
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

  // --- قسم إدارة الطلبات الحقيقية (Real Orders Management) ---

  // إنشاء طلب جديد في Firestore
  Future<void> createOrder(Map<String, dynamic> orderData) async {
    await _db.collection('orders').add(orderData);
  }

  // مراقبة الطلبات التي قام بها المشتري مرتبة تنازلياً حسب الوقت
  Stream<List<Map<String, dynamic>>> watchBuyerOrders(String buyerId) {
    return _db
        .collection('orders')
        .where('buyerId', isEqualTo: buyerId)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
      docs.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
      return docs;
    });
  }

  // مراقبة الطلبات المستلمة بواسطة المتجر (التاجر) مرتبة تنازلياً حسب الوقت
  Stream<List<Map<String, dynamic>>> watchSellerOrders(String storeID) {
    return _db
        .collection('orders')
        .where('storeID', isEqualTo: storeID)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
      docs.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
      return docs;
    });
  }

  // تحديث حالة الطلب (مثلاً للاكتمال بواسطة التاجر)
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await _db.collection('orders').doc(orderId).update({'status': newStatus});
  }

  // --- قسم لوحة تحكم الإدارة (Admin Dashboard Control) ---

  // 1. مراقبة جميع المستخدمين
  Stream<List<Map<String, dynamic>>> watchAllUsers() {
    return _usersCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id}).toList();
    });
  }

  // تغيير دور المستخدم
  Future<void> updateUserRole(String uid, String newRole) async {
    await _usersCollection.doc(uid).update({'role': newRole});
  }

  // حذف بيانات المستخدم
  Future<void> deleteUserData(String uid) async {
    await _usersCollection.doc(uid).delete();
  }

  // 2. مراقبة جميع المنتجات في المنصة
  Stream<List<ProductModel>> watchAllProducts() {
    return _productsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();
    });
  }

  // حذف أي منتج من المنصة
  Future<void> deleteGlobalProduct(String productId) async {
    await _productsCollection.doc(productId).delete();
  }

  // 3. مراقبة جميع الطلبات في المنصة
  Stream<List<Map<String, dynamic>>> watchAllOrders() {
    return _db.collection('orders').orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    });
  }

  // حذف أي طلب
  Future<void> deleteOrder(String orderId) async {
    await _db.collection('orders').doc(orderId).delete();
  }

  // --- الميزات الجديدة للوحة التحكم (Vendors, Content, Analytics) ---

  // حظر أو فك حظر متجر (مستخدم حقيقي)
  Future<void> updateStoreStatus(String storeId, bool isBlocked) async {
    await _usersCollection.doc(storeId).set({'isBlocked': isBlocked}, SetOptions(merge: true));
  }

  // إضافة قصة أناقة جديدة
  Future<void> addDailyLook(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await _looksCollection.add(data);
  }

  // حذف قصة أناقة
  Future<void> deleteDailyLook(String id) async {
    await _looksCollection.doc(id).delete();
  }

  // تسجيل استخدام تجربة الملابس الافتراضية
  Future<void> logVirtualTryOn(String uid) async {
    await _db.collection('virtual_tryon_logs').add({
      'userId': uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // جلب عدد مرات استخدام تجربة الملابس
  Future<int> getVirtualTryOnCount() async {
    final snapshot = await _db.collection('virtual_tryon_logs').count().get();
    return snapshot.count ?? 0;
  }

  // جلب جميع قطع الخزانة للإحصائيات
  Future<List<ClosetItemModel>> getAllClosetItems() async {
    final snapshot = await _closetCollection.get();
    return snapshot.docs.map((doc) => ClosetItemModel.fromFirestore(doc)).toList();
  }
}


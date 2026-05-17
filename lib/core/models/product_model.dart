import 'package:cloud_firestore/cloud_firestore.dart';

// نموذج يمثل منتجاً معروضاً للبيع في المتجر (يستخدمه التجار والمتبضعون)
class ProductModel {
  final String id; // المعرف الفريد للمنتج
  final String imageUrl; // رابط صورة المنتج
  final double price; // سعر المنتج
  final String storeName; // اسم المتجر العارض للمنتج
  final String storeID; // معرف المتجر (ID التاجر)
  final bool isAvailable; // حالة التوفر (متاح أو نفدت الكمية)
  final String category; // تصنيف المنتج (قميص، فستان، الخ...)
  final String color; // لون المنتج
  final String season; // الموسم المناسب للقطعة
  final String description; // وصف المنتج
  final String? country; // الدولة التي يتوفر فيها المنتج (دولة التاجر)

  ProductModel({
    required this.id,
    required this.imageUrl,
    required this.price,
    required this.storeName,
    required this.storeID,
    required this.isAvailable,
    required this.category,
    required this.color,
    required this.season,
    required this.description,
    this.country,
  });

  // تحويل البيانات من مستند Firestore إلى كائن ProductModel
  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      imageUrl: data['imageUrl'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      storeName: data['storeName'] ?? '',
      storeID: data['storeID'] ?? '',
      isAvailable: data['isAvailable'] ?? false,
      category: data['category'] ?? '',
      color: data['color'] ?? '',
      season: data['season'] ?? 'summer',
      description: data['description'] ?? '',
      country: data['country'],
    );
  }

  // تحويل الكائن إلى Map للتخزين في قاعدة البيانات Firestore
  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'price': price,
      'storeName': storeName,
      'storeID': storeID,
      'isAvailable': isAvailable,
      'category': category,
      'color': color,
      'season': season,
      'description': description,
      'country': country,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}

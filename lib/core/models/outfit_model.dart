import 'package:cloud_firestore/cloud_firestore.dart';

// نموذج يمثل تنسيق ملابس (Outfit) يتكون من عدة قطع
class OutfitModel {
  final String id; // المعرف الفريد للتنسيق
  final String userID; // معرف المستخدم صاحب التنسيق
  final String name; // اسم التنسيق (مثل: ملابس العمل، خروجة مسائية)
  final List<String> itemIds; // قائمة بمعرفات قطع الملابس المكونة للتنسيق
  final List<String>
  itemImageUrls; // قائمة بروابط صور القطع المكونة للتنسيق للتمثيل السريع
  final DateTime createdAt; // تاريخ إنشاء التنسيق

  OutfitModel({
    required this.id,
    required this.userID,
    this.name = 'newOutfit',
    required this.itemIds,
    required this.itemImageUrls,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // دالة لنسخ الكائن مع إمكانية تعديل بعض الحقول (تستخدم لتحديث الحالة)
  OutfitModel copyWith({
    String? id,
    String? userID,
    String? name,
    List<String>? itemIds,
    List<String>? itemImageUrls,
    DateTime? createdAt,
  }) {
    return OutfitModel(
      id: id ?? this.id,
      userID: userID ?? this.userID,
      name: name ?? this.name,
      itemIds: itemIds ?? this.itemIds,
      itemImageUrls: itemImageUrls ?? this.itemImageUrls,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // تحويل البيانات من Firestore إلى كائن OutfitModel
  factory OutfitModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return OutfitModel(
      id: doc.id,
      userID: data['userID'] ?? '',
      name: data['name'] ?? 'newOutfit',
      itemIds: List<String>.from(data['itemIds'] ?? []),
      itemImageUrls: List<String>.from(data['itemImageUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // تحويل الكائن إلى Map للتخزين في Firestore
  Map<String, dynamic> toMap() {
    return {
      'userID': userID,
      'name': name,
      'itemIds': itemIds,
      'itemImageUrls': itemImageUrls,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

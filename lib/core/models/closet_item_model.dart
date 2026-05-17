import 'package:cloud_firestore/cloud_firestore.dart';

// نموذج يمثل قطعة ملابس موجودة في خزانة المستخدم الرقمية
class ClosetItemModel {
  final String id; // المعرف الفريد للقطعة
  final String userID; // معرف المستخدم صاحب القطعة
  final String imageUrl; // رابط صورة القطعة (مخزنة على Cloudinary أو Firebase)
  final String category; // تصنيف القطعة (مثل: قميص، بنطال، فستان)
  final String color; // لون القطعة المستخرج بواسطة الذكاء الاصطناعي
  final String season; // الموسم المناسب (صيف 'summer' أو شتاء 'winter')
  final DateTime? timestamp; // وقت إضافة القطعة

  ClosetItemModel({
    required this.id,
    required this.userID,
    required this.imageUrl,
    required this.category,
    required this.color,
    required this.season,
    this.timestamp,
  });

  // دالة لتحويل البيانات القادمة من Firebase Firestore إلى كائن (Object) من نوع ClosetItemModel
  factory ClosetItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['timestamp'] as Timestamp?;
    return ClosetItemModel(
      id: doc.id,
      userID: data['userID'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      category: data['category'] ?? '',
      color: data['color'] ?? '',
      season: data['season'] ?? 'summer',
      timestamp: ts?.toDate(),
    );
  }

  // دالة لتحويل كائن ClosetItemModel إلى Map لإرساله وتخزينه في Firestore
  Map<String, dynamic> toMap() {
    return {
      'userID': userID,
      'imageUrl': imageUrl,
      'category': category,
      'color': color,
      'season': season,
      'timestamp': FieldValue.serverTimestamp(), // استخدام وقت الخادم لضمان الدقة
    };
  }
}

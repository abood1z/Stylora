import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final String type; // e.g., 'order', 'system', 'weather'
  final DateTime createdAt;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> data) {
    return NotificationModel(
      id: id,
      titleAr: data['titleAr'] ?? '',
      titleEn: data['titleEn'] ?? '',
      bodyAr: data['bodyAr'] ?? '',
      bodyEn: data['bodyEn'] ?? '',
      type: data['type'] ?? 'system',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titleAr': titleAr,
      'titleEn': titleEn,
      'bodyAr': bodyAr,
      'bodyEn': bodyEn,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': isRead,
    };
  }
}

import 'dart:io';
import 'ai_model_service.dart';
import 'firestore_service.dart';
import '../models/product_model.dart';
import '../models/closet_item_model.dart';

// خدمة الأتمتة المعتمدة على الذكاء الاصطناعي (AI Automation Service)
// تقوم هذه الخدمة بربط خدمات الذكاء الاصطناعي بخدمات قاعدة البيانات لتسهيل عملية الرفع
class AIAutomationService {
  final AIModelService _aiModelService = AIModelService();
  final FirestoreService _firestoreService = FirestoreService();

  /// معالجة ورفع منتج جديد بواسطة المتجر
  /// تقوم بتحليل الصورة تلقائياً لاستخراج الصنف واللون قبل الحفظ
  Future<void> processAndUploadProduct({
    required File imageFile,
    required String imageUrl,
    required double price,
    required String storeName,
    required String storeID,
    required bool isAvailable,
    required String season,
    required String description,
    String? country,
  }) async {
    // 1. استخراج الفئة واللون باستخدام نموذج الذكاء الاصطناعي (نأخذ أول قطعة مكتشفة)
    final analysisList = await _aiModelService.analyzeImage(imageFile);
    final analysis = analysisList.isNotEmpty ? analysisList.first : {};
    final category = (analysis['category'] as String?) ?? 'unknown';
    final color = (analysis['color'] as String?) ?? 'unknown';

    // 2. إنشاء كائن المنتج مع البيانات المستخرجة والوصف
    final product = ProductModel(
      id: '', // سيتم توليده تلقائياً بواسطة Firestore
      imageUrl: imageUrl,
      price: price,
      storeName: storeName,
      storeID: storeID,
      isAvailable: isAvailable,
      category: category,
      color: color,
      season: season,
      description: description,
      country: country,
    );

    // 3. الحفظ في قاعدة البيانات
    await _firestoreService.addProduct(product);
  }

  /// معالجة ورفع قطعة ملابس جديدة لخزانة المستخدم
  /// تغني المستخدم عن إدخال بيانات القطعة يدوياً
  Future<void> processAndUploadClosetItem({
    required File imageFile,
    required String imageUrl,
    required String userID,
    required String season,
  }) async {
    // 1. استخراج الفئة واللون باستخدام الذكاء الاصطناعي (نأخذ أول قطعة مكتشفة)
    final analysisList = await _aiModelService.analyzeImage(imageFile);
    final analysis = analysisList.isNotEmpty ? analysisList.first : {};
    final category = (analysis['category'] as String?) ?? 'unknown';
    final color = (analysis['color'] as String?) ?? 'unknown';

    // 2. إنشاء كائن قطعة الخزانة
    final item = ClosetItemModel(
      id: '', // سيتم توليده بواسطة Firestore
      userID: userID,
      imageUrl: imageUrl,
      category: category,
      color: color,
      season: season,
    );

    // 3. الحفظ في قاعدة بيانات المستخدم
    await _firestoreService.addClosetItem(item);
  }
}

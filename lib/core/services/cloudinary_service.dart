import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// خدمة Cloudinary لرفع الصور واستضافتها سحابياً لتطبيق Stylora
class CloudinaryService {
  // إعداد بيانات الحساب (Cloud Name و Upload Preset)
  static final _cloudinary = CloudinaryPublic(
    'dr1kljeod', // اسم السحابة الخاص بك
    'stylora_preset', // الإعداد المسبق للرفع غير الموقع (Unsigned)
    cache: false,
  );

  /// رفع صورة باستخدام ملف (File) - يستخدم للصور المختارة من معرض الصور أو الملتقطة بالكاميرا
  static Future<String?> uploadImage(File file, {String? folder}) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Image,
          folder: folder ?? 'stylora_uploads', // تحديد المجلد داخل Cloudinary
        ),
      );

      debugPrint('🚀 Stylora Upload Success: ${response.secureUrl}');
      return response.secureUrl; // إرجاع رابط HTTPS الآمن للصورة
    } catch (e) {
      debugPrint('❌ CloudinaryService: uploadImage error: $e');
      return null;
    }
  }

  /// رفع صورة باستخدام بيانات البايتات (Bytes) - يستخدم للصور المعالجة برمجياً أو في الويب
  static Future<String?> uploadImageBytes(
    Uint8List bytes, {
    String? folder,
    String? filename,
  }) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromByteData(
          ByteData.view(bytes.buffer), // تحويل مصفوفة البايتات إلى نوع متوافق
          resourceType: CloudinaryResourceType.Image,
          folder: folder ?? 'stylora_profiles',
          identifier:
              filename ?? 'img_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );

      debugPrint('🚀 Stylora Bytes Upload Success: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      debugPrint('❌ CloudinaryService: uploadImageBytes error: $e');
      return null;
    }
  }

  /// طلب حذف صورة من السحاب (ملاحظة: يتطلب عادةً إعدادات أمنية إضافية مثل Admin API)
  static Future<void> deleteImage(String imageUrl) async {
    try {
      // توضيح للمستخدم بأن الحذف يحتاج إلى Proxy أو وظائف خادم (Functions) لأسباب أمنية في النسخ الإنتاجية
      debugPrint('ℹ️ CloudinaryService: Deletion requested for $imageUrl (Requires Admin API/Proxy)');
    } catch (e) {
      debugPrint('❌ CloudinaryService: deleteImage error: $e');
    }
  }
}

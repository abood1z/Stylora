import 'package:flutter/material.dart';

// كلاس يحتوي على جميع الألوان المستخدمة في التطبيق للحفاظ على تناسق التصميم
class AppColors {
  // منشئ خاص لمنع إنشاء نسخة من الكلاس (Private constructor)
  AppColors._();

  // اللوحة الأساسية (Primary palette)
  static const Color primary = Color(0xFF1E1E1E); // اللون الأساسي (أسود غامق)
  static const Color primaryLight = Color(0xFF454545); // لون أساسي فاتح
  static const Color accent = Color(0xFFD4AF37); // لون ذهبي هادئ للتصاميم الأنيقة

  // ألوان الخلفية والأسطح (Background & Surface)
  static const Color background = Color(0xFFFAFAFA); // لون خلفية التطبيق
  static const Color surface = Colors.white; // لون أسطح البطاقات والحاويات
  
  // ألوان النصوص (Text colors)
  static const Color textPrimary = Color(0xFF1E1E1E); // لون النص الرئيسي
  static const Color textSecondary = Color(0xFF757575); // لون النص الثانوي (رمادي)
  static const Color textDisabled = Color(0xFFBDBDBD); // لون النص المعطل
  static const Color textInverse = Colors.white; // لون النص المعكوس (على خلفيات غامقة)

  // الألوان الدلالية للحالات (Status/Semantic colors)
  static const Color success = Color(0xFF4CAF50); // لون النجاح (أخضر)
  static const Color error = Color(0xFFE53935); // لون الخطأ (أحمر)
  static const Color warning = Color(0xFFFFA000); // لون التحذير (برتقالي)
  static const Color info = Color(0xFF2196F3); // لون المعلومات (أزرق)

  // ألوان الحدود والفواصل (Borders & Dividers)
  static const Color border = Color(0xFFE0E0E0); // لون الحدود
  static const Color divider = Color(0xFFEEEEEE); // لون الفواصل
}

import 'package:flutter/material.dart';

// إضافات برمجية (Extension) لتسهيل الوصول إلى خصائص الـ BuildContext
extension ContextExt on BuildContext {
  // اختصارات لمظهر التطبيق (Theme)
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => theme.textTheme;
  ColorScheme get colorScheme => theme.colorScheme;
  
  // التحقق مما إذا كان النمط الداكن مفغلاً
  bool get isDarkMode => theme.brightness == Brightness.dark;

  // اختصارات لأبعاد الشاشة (MediaQuery)
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => mediaQuery.size;
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;
  EdgeInsets get padding => mediaQuery.padding;
  
  // اختصارات للتنقل بين الصفحات (Navigation)
  void popWidget<T>([T? result]) => Navigator.of(this).pop(result);
  
  Future<T?> pushWidget<T>(Widget widget) => 
      Navigator.of(this).push(MaterialPageRoute(builder: (_) => widget));

  Future<T?> pushReplacementWidget<T, TO>(Widget widget) => 
      Navigator.of(this).pushReplacement(MaterialPageRoute(builder: (_) => widget));

  // أداة مساعدة لإظهار رسائل التنبيه (SnackBar) بتصميم عصري
  void showSnackBar(String message, {bool isError = false}) {
    // مسح أي رسائل سابقة
    ScaffoldMessenger.of(this).clearSnackBars();
    
    // إظهار الرسالة الجديدة
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(
          message, 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        // تغيير اللون بناءً على نوع الرسالة (خطأ أم نجاح)
        backgroundColor: isError ? colorScheme.error : colorScheme.primary,
        behavior: SnackBarBehavior.floating, // لجعل الرسالة عائمة
        elevation: 10,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

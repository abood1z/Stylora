// كلاس يحتوي على جميع النصوص الثابتة (Strings) المستخدمة في التطبيق
class AppStrings {
  // منشئ خاص لمنع إنشاء نسخة من الكلاس
  AppStrings._();

  static const String appName = 'AI Outfit Stylist'; // اسم التطبيق
  
  // نصوص المصادقة (Auth)
  static const String login = 'Login'; // تسجيل الدخول
  static const String signup = 'Sign Up'; // إنشاء حساب
  static const String continueAsGuest = 'Continue as Guest'; // المتابعة كضيف
  static const String email = 'Email'; // البريد الإلكتروني
  static const String password = 'Password'; // كلمة المرور
  static const String confirmPassword = 'Confirm Password'; // تأكيد كلمة المرور

  // نصوص الصفحة الرئيسية (Home)
  static const String home = 'Home'; // الرئيسية
  static const String dailyLook = 'Daily Look'; // المظهر اليومي
  static const String scanClothes = 'Scan Clothes'; // مسح الملابس بالكاميرا
  static const String possibleOutfits = 'Possible Outfits'; // التنسيقات الممكنة

  // نصوص التنقل (Navigation)
  static const String myMatching = 'My Matching'; // تنسيقاتي
  static const String shop = 'Shop'; // المتجر
  static const String profile = 'Profile'; // الملف الشخصي

  // نصوص الكاميرا (Camera)
  static const String processing = 'Processing AI Analysis...'; // جاري معالجة تحليل الذكاء الاصطناعي...
  static const String analysisResult = 'Analysis Result'; // نتيجة التحليل
  
  // نصوص الأخطاء (Errors)
  static const String genericError = 'Something went wrong. Please try again.'; // حدث خطأ ما، يرجى المحاولة لاحقاً.
}

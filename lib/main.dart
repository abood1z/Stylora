import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/notification_service.dart';
import 'core/services/ai_model_service.dart';

// نقطة البداية للتطبيق
void main() async {
  // التأكد من تهيئة Flutter bindings قبل استدعاء أي كود غير متزامن
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة نظام الترجمة (Localization)
  await EasyLocalization.ensureInitialized();
  
  // الحصول على نسخة من SharedPreferences لتخزين البيانات المحلية (مثل الإعدادات)
  final prefs = await SharedPreferences.getInstance();
  
  // محاولة تهيئة Firebase وخدمة الإشعارات والذكاء الاصطناعي في الخلفية لزيادة السرعة
  try {
    // تهيئة خدمات Google Firebase (أساسي للبداية)
    await Firebase.initializeApp();
    
    // تشغيل بقية الخدمات في الخلفية دون انتظار لكي يفتح التطبيق فوراً
    Future.microtask(() async {
      // تهيئة آلية دفع الإشعارات
      NotificationService.initialize();
      
      // تحميل نماذج الذكاء الاصطناعي مسبقاً (Pre-loading) لكي تكون جاهزة فوراً
      AIModelService().loadModels();
      
      // تأجيل تنظيف الروابط المكسورة لـ 10 ثواني بعد التشغيل لضمان سرعة فائقة
      Future.delayed(const Duration(seconds: 10), () => _cleanBrokenImageLinks());
    });
  } catch (e) {
    debugPrint('Background initialization warning: $e');
  }

  // تشغيل التطبيق مع تغليفه بـ EasyLocalization و ProviderScope
  runApp(
    EasyLocalization(
      // قائمة باللغات المدعومة في التطبيق (الإنجليزية، العربية، الفرنسية، الخ...)
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('fr'),
        Locale('tr'),
        Locale('es'),
        Locale('de'),
        Locale('it'),
        Locale('pt'),
        Locale('ru'),
        Locale('ja'),
        Locale('zh'),
        Locale('ko'),
      ],
      // مسار ملفات الترجمة في مجلد الأصول (assets)
      path: 'assets/translations',
      // اللغة الافتراضية في حال عدم توفر لغة المستخدم
      fallbackLocale: const Locale('en'),
      // ProviderScope يسمح باستخدام Riverpod لإدارة الحالة في جميع أنحاء التطبيق
      child: ProviderScope(
        overrides: [
          // تجاوز قيمة sharedPreferencesProvider بالقيمة التي قمنا بتهيئتها
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const StyloraApp(),
      ),
    ),
  );
}

// الكلاس الرئيسي للتطبيق StyloraApp
class StyloraApp extends ConsumerWidget {
  const StyloraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // الحصول على نظام التوجيه (Router) من الـ provider
    final router = ref.watch(routerProvider);
    
    // مراقبة حالة الـ themeMode (فاتح/داكن) لمنع إعادة بناء التطبيق بالكامل عند تغيير بيانات أخرى
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));

    // إعداد واجهة التطبيق باستخدام MaterialApp.router لدعم GoRouter
    return MaterialApp.router(
      debugShowCheckedModeBanner: false, // إخفاء علامة النسخة التجريبية
      title: 'Stylora AI', // عنوان المشروع
      
      // إعدادات السمات (المظهر الفاتح والداكن)
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      
      // ربط إعدادات التوجيه
      routerConfig: router,
      
      // إعدادات الترجمة واللغات
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}


// وظيفة ذكية لتنظيف وتصحيح روابط الصور المكسورة في Firestore
Future<void> _cleanBrokenImageLinks() async {
  try {
    final db = FirebaseFirestore.instance;
    final collections = ['Products', 'User_Closet', 'daily_looks', 'outfits'];
    
    // روابط Unsplash جديدة ومضمونة
    final validImages = [
      'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=500',
      'https://images.unsplash.com/photo-1539109132304-372873aee81b?w=500',
      'https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=500',
      'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=500',
    ];

    for (var collection in collections) {
      final snapshot = await db.collection(collection).get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        String? url;
        
        // التحقق من الحقل المحتمل للرابط
        if (data.containsKey('imageUrl')) url = data['imageUrl'] as String?;
        if (data.containsKey('itemImageUrls')) {
            // معالجة قائمة الروابط في التنسيقات
            final List<dynamic> urls = data['itemImageUrls'] as List<dynamic>;
            bool needsFix = urls.any((u) => u.toString().contains('unsplash.com/photo-1550616140') || u.toString().contains('unsplash.com/photo-1594938298'));
            if (needsFix) {
               await doc.reference.update({
                 'itemImageUrls': urls.map((u) => validImages[doc.id.length % validImages.length]).toList(),
               });
            }
            continue;
        }

        // إذا كان الرابط مكسوراً (بناءً على التقارير السابقة)
        if (url != null && (url.contains('unsplash.com/photo-1550616140') || url.contains('unsplash.com/photo-1594938298'))) {
          await doc.reference.update({
            'imageUrl': validImages[doc.id.length % validImages.length],
          });
          debugPrint('✅ Fixed broken image in $collection: ${doc.id}');
        }
      }
    }
  } catch (e) {
    debugPrint('Error cleaning image links: $e');
  }
}

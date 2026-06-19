import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/app_update_service.dart';

// شاشة الترحيب (Splash Screen)
// تظهر عند تشغيل التطبيق لأول مرة لعرض الشعار والبدء في تهيئة الجلسة
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation; // متحكم في شفافية العناصر
  late Animation<double> _scaleAnimation;   // متحكم في حجم الشعار

  @override
  void initState() {
    super.initState();
    // إعداد وحدة التحكم في الحركة لمدة ثانيتين
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // تأثير الظهور التدريجي (Fade In)
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    // تأثير التكبير المرن (Scale In) لإعطاء حيوية للشعار
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)),
    );

    // بدء الحركة ثم فحص التحديثات قبل الانتقال
    _controller.forward().then((_) async {
      // 1. فحص وجود تحديثات (إلزامية أو اختيارية) من Firestore
      final isForceUpdate = await AppUpdateService().checkForUpdate(context);
      
      // 2. إذا لم يكن هناك تحديث إجباري يمنع الاستخدام، ننتقل للشاشة الرئيسية (أو يوجهنا الموجه التلقائي لتسجيل الدخول)
      if (!isForceUpdate && mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            context.go('/home');
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose(); // تنظيف الذاكرة بإغلاق متحكم الحركة
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // خلفية بتدرج لوني يعكس هوية التطبيق
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              Color(0xFF4F46E5), // Indigo عميق
              Color(0xFF4338CA), // أغمق درجات الـ Indigo للعمق البصري
            ],
          ),
        ),
        child: Stack(
          children: [
            // دوائر خلفية خفيفة لتعزيز العمق الجمالي
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // أيقونة التطبيق داخل حاوية بيضاء مميزة
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(36),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              size: 64,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 32),
                          // اسم التطبيق بخط مميز ومسافات واسعة بين الحروف
                          Text(
                            'STYLORA',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 8,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // نص توضيحي لهوية التطبيق (نظام أزياء ذكي)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'AI INTELLIGENT FASHION',
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// مسار مخصص للانتقال بين الصفحات بتأثير التلاشي (Fade)
class FadePageRoute extends PageRouteBuilder {
  final Widget child;
  FadePageRoute({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        );
}

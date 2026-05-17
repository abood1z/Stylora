import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_textfield.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../core/providers/settings_provider.dart';
import '../providers/auth_provider.dart';

// واجهة تسجيل الدخول (Login Screen)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  // وحدات التحكم لحقول النص
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false; // حالة التحميل أثناء تسجيل الدخول
  bool _obscurePassword = true; // حالة إخفاء/إظهار كلمة المرور
  bool _isBiometricLinked = false; // هل المستخدم قام بربط حسابه بالبصمة؟

  // متغيرات الأنيميشن (التأثيرات الحركية)
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _checkBiometricLink();

    // تهيئة ممر الأنيميشن لمدة 1.2 ثانية
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // تأثير الظهور التدريجي (Fade)
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // تأثير الانزلاق للأعلى (Slide)
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _animController.forward(); // بدء الأنيميشن
  }

  // التحقق مما إذا كان هذا الجهاز لديه حساب مربوط بالبصمة
  Future<void> _checkBiometricLink() async {
    final linked = await ref.read(biometricAuthServiceProvider).isLinked();
    if (mounted) {
      setState(() => _isBiometricLinked = linked);
      // إذا كان مربوطاً، ابدأ المصادقة تلقائياً بعد قليل لضمان جاهزية الشاشة
      if (linked) {
        Future.delayed(
          const Duration(milliseconds: 500),
          () => _loginWithBiometrics(),
        );
      }
    }
  }

  // تنفيذ تسجيل الدخول بالبصمة
  Future<void> _loginWithBiometrics() async {
    final authService = ref.read(biometricAuthServiceProvider);

    // 1. التحقق من البصمة
    final authenticated = await authService.authenticate();
    if (!authenticated) return;

    // 2. الحصول على البيانات المخزنة
    final creds = await authService.getSavedCredentials();
    if (creds == null) {
      if (mounted) context.showSnackBar('biometricNotAvailable'.tr());
      return;
    }

    // 3. تسجيل الدخول الذكي بناءً على نوع الحساب
    try {
      setState(() => _isLoading = true);

      if (creds['password'] == 'GOOGLE_AUTH_CREDENTIAL') {
        // إذا كان مستخدم جوجل، نستخدم طريقة جوجل للدخول
        await ref.read(authServiceProvider).signInWithGoogle();
      } else {
        // لمستخدمي البريد والرمز السري
        await ref
            .read(authServiceProvider)
            .signInWithEmailAndPassword(creds['email']!, creds['password']!);
      }

      if (mounted) {
        ref.read(isGuestProvider.notifier).state = false;
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('invalidCredentials'.tr(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // دالة تسجيل الدخول باستخدام البريد وكلمة المرور
  Future<void> _login() async {
    HapticFeedback.mediumImpact(); // اهتزاز بسيط عند الضغط
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      setState(() => _isLoading = true);

      await ref
          .read(authServiceProvider)
          .signInWithEmailAndPassword(email, password);

      ref.read(isGuestProvider.notifier).state = false;

      if (mounted) {
        context.go('/home'); // الانتقال للصفحة الرئيسية
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact(); // اهتزاز قوي عند الخطأ
        context.showSnackBar('invalidCredentials'.tr(), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // الدخول كضيف (Guest)
  Future<void> _loginAsGuest() async {
    HapticFeedback.lightImpact();
    ref.read(isGuestProvider.notifier).state = true;
    context.go('/home');
  }

  // تسجيل الدخول باستخدام Google
  Future<void> _loginWithGoogle() async {
    HapticFeedback.mediumImpact();
    try {
      setState(() => _isLoading = true);
      final userCredential = await ref
          .read(authServiceProvider)
          .signInWithGoogle();
      if (userCredential?.user != null && mounted) {
        // حفظ بيانات المستخدم في Firestore
        await ref
            .read(firestoreServiceProvider)
            .saveUserData(userCredential!.user!);

        if (mounted) {
          // تحديث الإعدادات للتأكد من اكتمال الملف الشخصي
          ref
              .read(settingsProvider.notifier)
              .loadRemoteSettings(userCredential.user!.uid);
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        context.showSnackBar('googleSignupFailed'.tr(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset:
          false, // منع تغيير حجم الشاشة عند ظهور لوحة المفاتيح
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          // تدرج لوني للخلفية يجمع بين هوية التطبيق
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colorScheme.primary.withValues(alpha: 0.05),
              context.colorScheme.surface,
              context.colorScheme.secondary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 16),
                            Text(
                              'Stylora',
                              style: context.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: context.colorScheme.primary,
                                fontSize: constraints.maxHeight < 600 ? 28 : 36,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // بطاقة مدخلات تسجيل الدخول (Glassmorphism design)
                            GlassCard(
                              padding: const EdgeInsets.all(24),
                              borderRadius: 32,
                              child: Column(
                                children: [
                                  Text(
                                    'welcomeBack'.tr(),
                                    style: context.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 24),
                                  // حقول الإدخال المخصصة
                                  CustomTextField(
                                    label: 'email'.tr(),
                                    hint: 'user@example.com',
                                    controller: _emailController,
                                    prefixIcon: Icons.email_outlined,
                                  ),
                                  const SizedBox(height: 16),
                                  CustomTextField(
                                    label: 'password'.tr(),
                                    hint: '••••••••',
                                    controller: _passwordController,
                                    isPassword: true,
                                    obscureText: _obscurePassword,
                                    prefixIcon: Icons.lock_outline_rounded,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: context.colorScheme.onSurface
                                            .withValues(alpha: 0.4),
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // خيار نسيت كلمة المرور
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {},
                                      child: Text(
                                        'forgotPassword'.tr(),
                                        style: TextStyle(
                                          color: context.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // أزرار العمليات
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CustomButton(
                                          onPressed: _login,
                                          text: 'login'.tr(),
                                          isLoading: _isLoading,
                                        ),
                                      ),
                                      if (_isBiometricLinked) ...[
                                        const SizedBox(width: 12),
                                        _biometricButton(),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  CustomButton(
                                    onPressed: _loginAsGuest,
                                    text: 'continueAsGuest'.tr(),
                                    isOutlined: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // طرق تسجيل دخول بديلة
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    'orContinueWith'.tr(),
                                    style: context.textTheme.bodySmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _socialButton(
                                  icon: Icons.g_mobiledata_rounded,
                                  onPressed: _loginWithGoogle,
                                ),
                                const SizedBox(width: 20),
                                _socialButton(
                                  icon: Icons.apple_rounded,
                                  onPressed: () {},
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // الانتقال لإنشاء حساب جديد
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('noAccount'.tr()),
                                TextButton(
                                  onPressed: () => context.push('/signup'),
                                  child: Text(
                                    'signup'.tr(),
                                    style: TextStyle(
                                      color: context.colorScheme.primary,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // كائن زر البصمة
  Widget _biometricButton() {
    return GlassCard(
      borderRadius: 16,
      opacity: 0.1,
      child: InkWell(
        onTap: _loginWithBiometrics,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          height: 54,
          width: 54,
          child: Icon(
            Icons.fingerprint_rounded,
            color: context.colorScheme.primary,
            size: 30,
          ),
        ),
      ),
    );
  }

  // كائن زر التواصل الاجتماعي (Google, Apple)
  Widget _socialButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GlassCard(
      borderRadius: 16,
      opacity: 0.05,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 32),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

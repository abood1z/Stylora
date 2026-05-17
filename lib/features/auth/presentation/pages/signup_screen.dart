import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_textfield.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../core/providers/settings_provider.dart';

// شاشة إنشاء حساب جديد (Signup Screen)
// تتيح للمستخدمين الجدد الانضمام للتطبيق بصفتهم (عملاء) أو (تجار)
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> with SingleTickerProviderStateMixin {
  // المتحكمات في حقول الإدخال النصية
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();

  // متغيرات إدارة الحالة المحلية للواجهة
  bool _isLoading = false; // حالة التحميل أثناء طلب الـ API
  bool _obscurePassword = true; // إخفاء/إظهار كلمة المرور
  bool _obscureConfirmPassword = true;

  // مؤشرات التحقق من قوة كلمة المرور
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;

  String _selectedRole = 'user'; // الدور المحدد: 'user' للعميل أو 'merchant' للتاجر
  Color _selectedSkinTone = const Color(0xFFFFDBAC); // لون البشرة الافتراضي للبدلة الرقمية

  // قائمة خيارات ألوان البشرة المتاحة
  final List<Color> _skinTones = [
    const Color(0xFFFFDBAC),
    const Color(0xFFF1C27D),
    const Color(0xFFE0AC69),
    const Color(0xFFC68642),
    const Color(0xFF8D5524),
  ];

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // إعداد التوجيهات الحركية (Animations) عند فتح الشاشة
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0.0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animController.forward();
  }

  // تحديث حالة التحقق من كلمة المرور أثناء الكتابة
  void _updateValidation(String value) {
    setState(() {
      _hasMinLength = value.length >= 8;
      _hasUppercase = value.contains(RegExp(r'[A-Z]'));
      _hasNumber = value.contains(RegExp(r'[0-9]'));
    });
  }

  // التحقق من استيفاء كلمة المرور للمعايير الأمنية
  bool _isPasswordValid(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    return true;
  }

  // التحقق من صحة كافة المدخلات قبل بدء عملية التسجيل
  bool _validateInputs() {
    if (_nameController.text.trim().isEmpty) {
      context.showSnackBar('requiredField'.tr(), isError: true);
      return false;
    }
    if (_emailController.text.trim().isEmpty) {
      context.showSnackBar('enterEmail'.tr(), isError: true);
      return false;
    }

    // التحقق من القياسات البدنية فقط إذا كان المستخدم عادياً
    if (_selectedRole == 'user') {
      if (_heightController.text.isEmpty || double.tryParse(_heightController.text) == null) {
        context.showSnackBar('invalidHeight'.tr(), isError: true);
        return false;
      }
      if (_weightController.text.isEmpty || double.tryParse(_weightController.text) == null) {
        context.showSnackBar('invalidWeight'.tr(), isError: true);
        return false;
      }
      if (_ageController.text.isEmpty || int.tryParse(_ageController.text) == null) {
        context.showSnackBar('requiredField'.tr(), isError: true);
        return false;
      }
    }

    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (!_isPasswordValid(password)) {
      context.showSnackBar('passwordRequirements'.tr(), isError: true);
      return false;
    }
    if (password != confirmPassword) {
      context.showSnackBar('passwordsDoNotMatch'.tr(), isError: true);
      return false;
    }
    return true;
  }

  /// تنفيذ عملية إنشاء الحساب (Manual Signup)
  Future<void> _signup() async {
    HapticFeedback.mediumImpact();
    if (!_validateInputs()) {
      HapticFeedback.heavyImpact();
      return;
    }

    try {
      setState(() => _isLoading = true);
      final languageCode = context.locale.languageCode;
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final authService = ref.read(authServiceProvider);
      final firestoreService = ref.read(firestoreServiceProvider);

      // 1. إنشاء الحساب في Firebase Auth
      final userCredential = await authService.signUpWithEmailAndPassword(email, password);

      if (userCredential.user != null) {
        // تجهيز البيانات الإضافية بناءً على نوع المستخدم
        final Map<String, dynamic> additionalData = {
          'language': languageCode,
          'role': _selectedRole,
          'isProfileComplete': true,
        };

        if (_selectedRole == 'user') {
          additionalData.addAll({
            'height': double.tryParse(_heightController.text),
            'weight': double.tryParse(_weightController.text),
            'age': int.tryParse(_ageController.text),
            'skinColor': '#${_selectedSkinTone.toARGB32().toRadixString(16).substring(2)}',
          });
        }

        // 2. حفظ بيانات المستخدم الإضافية في Firestore
        await firestoreService.saveUserData(
          userCredential.user!,
          name: _nameController.text.trim(),
          additionalData: additionalData,
        );
      }

      if (mounted) context.go('/home');
    } on FirebaseAuthException catch (e) {
      String message = 'signupFailed'.tr();
      if (e.code == 'email-already-in-use') message = 'emailAlreadyInUse'.tr();
      if (mounted) context.showSnackBar(message, isError: true);
    } catch (e) {
      if (mounted) context.showSnackBar('signupFailed'.tr(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// تسجيل الحساب باستخدام حساب Google
  Future<void> _signupWithGoogle() async {
    try {
      setState(() => _isLoading = true);
      final userCredential = await ref.read(authServiceProvider).signInWithGoogle();
      if (userCredential?.user != null && mounted) {
        // عند التسجيل بجوجل، نحفظ البيانات الأساسية ونعتبر الملف غير مكتمل لحين إدخال القياسات
        await ref.read(firestoreServiceProvider).saveUserData(
          userCredential!.user!,
          additionalData: {'language': context.locale.languageCode},
        );
        if (mounted) {
            // تحديث الإعدادات للكشف عن نقص بيانات الملف الشخصي (Profile Incomplete)
            ref.read(settingsProvider.notifier).loadRemoteSettings(userCredential.user!.uid);
            context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) context.showSnackBar('googleSignupFailed'.tr(), isError: true);
    } finally {
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToLogin() {
    HapticFeedback.lightImpact();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.colorScheme.onSurface),
          onPressed: _navigateToLogin,
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
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
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 16),
                            Hero(tag: 'logo', child: Icon(Icons.auto_awesome_rounded, size: constraints.maxHeight < 700 ? 32 : 48, color: context.colorScheme.primary)),
                            const SizedBox(height: 8),
                            Text('signup'.tr(), style: context.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: GlassCard(
                                padding: const EdgeInsets.all(20),
                                borderRadius: 32,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CustomTextField(label: 'enterName'.tr(), hint: 'John Doe', controller: _nameController, prefixIcon: Icons.person_outline),
                                    const SizedBox(height: 12),
                                    CustomTextField(label: 'email'.tr(), hint: 'user@example.com', controller: _emailController, prefixIcon: Icons.email_outlined),
                                    const SizedBox(height: 16),
                                    _buildRoleSelector(),
                                    if (_selectedRole == 'user') ...[
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(child: CustomTextField(label: 'heightLabel'.tr(), hint: '175', controller: _heightController, prefixIcon: Icons.height, keyboardType: TextInputType.number)),
                                          const SizedBox(width: 12),
                                          Expanded(child: CustomTextField(label: 'weightLabel'.tr(), hint: '70', controller: _weightController, prefixIcon: Icons.monitor_weight_outlined, keyboardType: TextInputType.number)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      CustomTextField(label: 'age'.tr(), hint: '25', controller: _ageController, prefixIcon: Icons.calendar_today_outlined, keyboardType: TextInputType.number),
                                      const SizedBox(height: 16),
                                      _buildSkinTonePicker(),
                                    ],
                                    const SizedBox(height: 24),
                                    const Divider(),
                                    const SizedBox(height: 24),
                                    CustomTextField(
                                      label: 'password'.tr(),
                                      hint: '••••••••',
                                      controller: _passwordController,
                                      isPassword: true,
                                      obscureText: _obscurePassword,
                                      prefixIcon: Icons.lock_outline_rounded,
                                      onChanged: _updateValidation,
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: context.colorScheme.onSurface.withValues(alpha: 0.4)),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Column(
                                      children: [
                                        _buildRequirementItem('min8Chars'.tr(), _hasMinLength),
                                        _buildRequirementItem('oneUppercase'.tr(), _hasUppercase),
                                        _buildRequirementItem('oneNumber'.tr(), _hasNumber),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    CustomTextField(
                                      label: 'confirmPassword'.tr(),
                                      hint: '••••••••',
                                      controller: _confirmPasswordController,
                                      isPassword: true,
                                      obscureText: _obscureConfirmPassword,
                                      prefixIcon: Icons.check_circle_outline_rounded,
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: context.colorScheme.onSurface.withValues(alpha: 0.4)),
                                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    CustomButton(onPressed: _signup, text: 'signup'.tr(), isLoading: _isLoading),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('orContinueWith'.tr(), style: context.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold))),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Center(child: _socialButton(icon: Icons.g_mobiledata_rounded, onPressed: _signupWithGoogle)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('alreadyHaveAccount'.tr()),
                                TextButton(
                                  onPressed: _navigateToLogin,
                                  child: Text('login'.tr(), style: TextStyle(color: context.colorScheme.primary, fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
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

  // واجهة اختيار لون البشرة (Skin Tone Picker)
  // يستخدم لتخصيص محاكي تجربة الملابس (Avatar) لاحقاً
  Widget _buildSkinTonePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('skinToneLabel'.tr(), style: context.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _skinTones.map((color) {
            final isSelected = _selectedSkinTone == color;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedSkinTone = color);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle,
                  border: Border.all(color: isSelected ? context.colorScheme.primary : Colors.transparent, width: 3),
                  boxShadow: isSelected ? [BoxShadow(color: context.colorScheme.primary.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 2)] : [],
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // واجهة اختيار نوع الحساب (عميل/تاجر)
  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('roleLabel'.tr(), style: context.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildRoleCard('user', 'roleUser'.tr(), Icons.person_outline)),
            const SizedBox(width: 16),
            Expanded(child: _buildRoleCard('merchant', 'roleMerchant'.tr(), Icons.storefront_outlined)),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleCard(String role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedRole = role);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? context.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? context.colorScheme.primary : context.colorScheme.onSurface.withValues(alpha: 0.1), width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? context.colorScheme.primary : context.colorScheme.onSurface),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? context.colorScheme.primary : context.colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 14, color: isMet ? Colors.green : context.colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: isMet ? FontWeight.bold : FontWeight.normal, color: isMet ? Colors.green : context.colorScheme.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _socialButton({required IconData icon, required VoidCallback onPressed}) {
    return GlassCard(
      borderRadius: 16, opacity: 0.05,
      child: InkWell(
        onTap: () { HapticFeedback.mediumImpact(); onPressed(); },
        borderRadius: BorderRadius.circular(16),
        child: Container(padding: const EdgeInsets.all(12), child: Icon(icon, size: 32)),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }
}

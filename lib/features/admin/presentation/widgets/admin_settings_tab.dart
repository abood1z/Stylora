import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_textfield.dart';
import '../viewmodels/admin_viewmodel.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminSettingsTab extends ConsumerStatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  ConsumerState<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends ConsumerState<AdminSettingsTab> {
  final _latestVersionController = TextEditingController();
  final _minVersionController = TextEditingController();
  final _updateUrlController = TextEditingController();
  
  // حقول بيانات الحساب
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoadingAuthUpdate = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = FirebaseAuth.instance.currentUser?.email ?? '';
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final configState = ref.read(appConfigProvider);
      if (configState is AsyncData && configState.value != null) {
        _populateFields(configState.value!);
      }
    });
  }

  void _populateFields(AppConfigModel config) {
    _latestVersionController.text = config.latestVersion;
    _minVersionController.text = config.minVersion;
    _updateUrlController.text = config.updateUrl;
  }

  @override
  void dispose() {
    _latestVersionController.dispose();
    _minVersionController.dispose();
    _updateUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    final newConfig = AppConfigModel(
      latestVersion: _latestVersionController.text.trim(),
      minVersion: _minVersionController.text.trim(),
      updateUrl: _updateUrlController.text.trim(),
    );

    await ref.read(appConfigProvider.notifier).updateConfig(newConfig);
    if (mounted) {
      context.showSnackBar(context.locale.languageCode == 'ar' ? 'تم تحديث إعدادات التطبيق بنجاح' : 'App config updated successfully');
    }
  }

  Future<void> _updateAdminCredentials() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    setState(() => _isLoadingAuthUpdate = true);
    
    try {
      final newEmail = _emailController.text.trim();
      final newPassword = _passwordController.text;
      final isAr = context.locale.languageCode == 'ar';
      
      bool updated = false;

      // تحديث الإيميل إذا تم تغييره
      if (newEmail.isNotEmpty && newEmail != user.email) {
        await user.verifyBeforeUpdateEmail(newEmail); // Firebase V10+ requires verifyBeforeUpdateEmail instead of updateEmail directly in some setups, but updateEmail works if no email enumeration protection is on.
        // Or simply user.updateEmail(newEmail);
        // Using verifyBeforeUpdateEmail is safer but sends a link. Let's just use updateEmail for simplicity in admin.
        // Wait, updateEmail is deprecated in firebase_auth 4.11.0+. We must use verifyBeforeUpdateEmail, OR if we want direct update without verification we can't do it directly from client easily unless it's a test mode. 
        // We will use updatePassword. For email, we will just try verifyBeforeUpdateEmail to avoid compiler warnings.
        await user.verifyBeforeUpdateEmail(newEmail);
        if (mounted) context.showSnackBar(isAr ? 'تم إرسال رابط تأكيد للبريد الجديد لتحديثه' : 'Verification link sent to new email');
        updated = true;
      }
      
      // تحديث الباسورد
      if (newPassword.isNotEmpty) {
        await user.updatePassword(newPassword);
        _passwordController.clear();
        updated = true;
        if (mounted) context.showSnackBar(isAr ? 'تم تغيير كلمة المرور بنجاح' : 'Password updated successfully');
      }

      if (!updated && mounted) {
        context.showSnackBar(isAr ? 'لم يتم إدخال تغييرات' : 'No changes entered');
      }
      
    } on FirebaseAuthException catch (e) {
      final isAr = context.locale.languageCode == 'ar';
      String msg = isAr ? 'حدث خطأ' : 'An error occurred';
      if (e.code == 'requires-recent-login') {
        msg = isAr ? 'لأسباب أمنية، يرجى تسجيل الخروج والدخول مجدداً لتغيير بياناتك' : 'For security reasons, please re-login to change credentials';
      } else {
        msg = '${isAr ? 'خطأ' : 'Error'}: ${e.message}';
      }
      if (mounted) context.showSnackBar(msg);
    } catch (e) {
      if (mounted) context.showSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAuthUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';
    final configState = ref.watch(appConfigProvider);

    ref.listen<AsyncValue<AppConfigModel?>>(appConfigProvider, (prev, next) {
      if (next is AsyncData && next.value != null) {
        if (_latestVersionController.text.isEmpty) {
          _populateFields(next.value!);
        }
      }
    });

    return configState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (config) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassCard(
                borderRadius: 24,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security_rounded, color: context.colorScheme.primary, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isAr ? 'معلومات حساب الإدارة' : 'Admin Credentials',
                            style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isAr ? 'البريد الإلكتروني للإدمن' : 'Admin Email',
                      style: context.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _emailController,
                      label: isAr ? 'البريد' : 'Email',
                      hint: 'admin@stylora.com',
                      prefixIcon: Icons.email_rounded,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isAr ? 'تغيير كلمة المرور' : 'Change Password',
                      style: context.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _passwordController,
                      label: isAr ? 'كلمة المرور الجديدة' : 'New Password',
                      hint: '********',
                      prefixIcon: Icons.lock_rounded,
                      isPassword: true,
                    ),
                    const SizedBox(height: 32),
                    _isLoadingAuthUpdate 
                        ? const Center(child: CircularProgressIndicator())
                        : CustomButton(
                            text: isAr ? 'تحديث بيانات الدخول' : 'Update Credentials',
                            onPressed: _updateAdminCredentials,
                            color: Colors.orange,
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GlassCard(
                borderRadius: 24,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.system_update_rounded, color: context.colorScheme.primary, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isAr ? 'إدارة إصدارات التطبيق' : 'App Version Management',
                            style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isAr ? 'الإصدار الحالي (الأحدث)' : 'Latest Version',
                      style: context.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _latestVersionController,
                      label: isAr ? 'رقم الإصدار' : 'Version Number',
                      hint: 'e.g., 1.0.5',
                      prefixIcon: Icons.verified_rounded,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isAr ? 'الحد الأدنى للإصدار (إجباري)' : 'Minimum Version (Force Update)',
                      style: context.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _minVersionController,
                      label: isAr ? 'رقم الإصدار' : 'Version Number',
                      hint: 'e.g., 1.0.0',
                      prefixIcon: Icons.security_rounded,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isAr ? 'رابط تحديث التطبيق' : 'Update URL (App/Play Store)',
                      style: context.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _updateUrlController,
                      label: isAr ? 'الرابط' : 'URL',
                      hint: 'https://...',
                      prefixIcon: Icons.link_rounded,
                    ),
                    const SizedBox(height: 32),
                    CustomButton(
                      text: isAr ? 'حفظ إعدادات التطبيق' : 'Save Config',
                      onPressed: _saveConfig,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

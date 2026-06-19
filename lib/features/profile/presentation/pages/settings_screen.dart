import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../shared/widgets/custom_textfield.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../core/services/notification_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';

// شاشة الإعدادات (Settings Screen)
// توفر واجهة للتحكم في الحساب، الإشعارات، اللغة، والمظهر (الثيم)
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    // مراقبة حالة الإعدادات من الـ Provider
    final settings = ref.watch(settingsProvider);
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null; // تحديد ما إذا كان المستخدم زائراً
    final isGoogleUser =
        user != null &&
        user.providerData.any((p) => p.providerId == 'google.com');

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // شريط علوي متفاعل يختفي عند التمرير
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: context.colorScheme.surface,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'settings'.tr(),
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: context.colorScheme.onSurface,
                ),
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),

                // --- قسم الحساب والخصوصية ---
                // يظهر فقط للمستخدمين المسجلين (غير الزوار)
                _buildSectionHeader(context, 'account'.tr()),
                const SizedBox(height: 12),
                GlassCard(
                  borderRadius: 24,
                  child: Column(
                    children: [
                      if (!isGuest) ...[
                        if (!isGoogleUser) ...[
                          _buildTile(
                            context,
                            Icons.lock_outline,
                            'changePassword'.tr(),
                            onTap: () => _showChangePasswordDialog(context),
                          ),
                          _buildDivider(),
                        ],
                        _buildTile(
                          context,
                          Icons.fingerprint_rounded,
                          'biometricLogin'.tr(),
                          trailing: Switch.adaptive(
                            value: settings.biometricEnabled,
                            onChanged: (val) {
                              if (val) {
                                _showBiometricLinkDialog(context);
                              } else {
                                ref
                                    .read(settingsProvider.notifier)
                                    .setBiometric(false);
                                ref
                                    .read(biometricAuthServiceProvider)
                                    .unlinkAccount();
                              }
                            },
                          ),
                        ),
                        _buildDivider(),
                        _buildTile(
                          context,
                          Icons.security_rounded,
                          'twoFactorAuth'.tr(),
                          trailing: Switch.adaptive(
                            value: settings.is2FAEnabled,
                            onChanged: (val) {
                              if (val) {
                                _showTwoFactorSetupDialog(context);
                              } else {
                                ref
                                    .read(settingsProvider.notifier)
                                    .set2FA(false, method: null);
                                ref.read(twoFactorServiceProvider).disable();
                                context.showSnackBar('twoFactorDisabled'.tr());
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // --- مركز الإشعارات التفصيلي ---
                _buildSectionHeader(context, 'notifications'.tr()),
                const SizedBox(height: 12),
                // التحقق من حالة إشعارات النظام (خارج التطبيق) وتنبيه المستخدم إذا كانت معطلة
                FutureBuilder<bool>(
                  future: NotificationService.isSystemNotificationEnabled(),
                  builder: (context, snapshot) {
                    final isSystemOn = snapshot.data ?? true;
                    if (!isSystemOn) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          borderRadius: 16,
                          child: ListTile(
                            leading: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                            ),
                            title: Text(
                              'systemNotificationsOff'.tr(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'tapToEnable'.tr(),
                              style: const TextStyle(fontSize: 11),
                            ),
                            onTap: () =>
                                NotificationService.openSystemSettings(), // فتح إعدادات الهاتف
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                // التحكم في أنواع الإشعارات المختلفة داخل التطبيق
                GlassCard(
                  borderRadius: 24,
                  child: Column(
                    children: [
                      _buildTile(
                        context,
                        Icons.notifications_none_rounded,
                        'pushNotifications'.tr(),
                        trailing: Switch.adaptive(
                          activeColor: context.colorScheme.primary,
                          value: settings.notificationsEnabled,
                          onChanged: (val) => ref
                              .read(settingsProvider.notifier)
                              .setNotifications(val),
                        ),
                      ),
                      _buildDivider(),
                      _buildTile(
                        context,
                        Icons.receipt_long_outlined,
                        'transactionalNotifs'.tr(),
                        trailing: Switch.adaptive(
                          value: settings.transactionalNotifs,
                          onChanged: (val) => ref
                              .read(settingsProvider.notifier)
                              .setTransactionalNotifs(val),
                        ),
                      ),
                      _buildDivider(),
                      _buildTile(
                        context,
                        Icons.shopping_bag_outlined,
                        'storeNotifs'.tr(),
                        trailing: Switch.adaptive(
                          value: settings.storeNotifs,
                          onChanged: (val) => ref
                              .read(settingsProvider.notifier)
                              .setStoreNotifs(val),
                        ),
                      ),
                      _buildDivider(),
                      _buildTile(
                        context,
                        Icons.auto_awesome_outlined,
                        'smartEngagement'.tr(),
                        trailing: Switch.adaptive(
                          value: settings.smartEngagement,
                          onChanged: (val) => ref
                              .read(settingsProvider.notifier)
                              .setSmartEngagement(val),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // --- إعدادات اللغات والثيم ---
                _buildSectionHeader(context, 'appSettings'.tr()),
                const SizedBox(height: 12),
                GlassCard(
                  borderRadius: 24,
                  child: Column(
                    children: [
                      // تغيير لغة التطبيق بشكل لحظي
                      _buildTile(
                        context,
                        Icons.language_rounded,
                        'language'.tr(),
                        trailing: DropdownButton<String>(
                          value: context.locale.languageCode,
                          underline: const SizedBox(),
                          dropdownColor: context.colorScheme.surface,
                          items: [
                            DropdownMenuItem(
                              value: 'ar',
                              child: Text(
                                'العربية',
                                style: TextStyle(
                                  color: context.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'en',
                              child: Text(
                                'English',
                                style: TextStyle(
                                  color: context.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (lang) {
                            if (lang != null) {
                              context.setLocale(
                                Locale(lang),
                              ); // تحديث لغة الواجهة
                              ref
                                  .read(settingsProvider.notifier)
                                  .setLanguage(
                                    lang,
                                  ); // حفظ التفضيل في الإعدادات
                            }
                          },
                        ),
                      ),
                      _buildDivider(),
                      // التبديل بين المظهر الفاتح والداكن
                      _buildTile(
                        context,
                        settings.themeMode == ThemeMode.dark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        'darkMode'.tr(),
                        trailing: Switch.adaptive(
                          value: settings.themeMode == ThemeMode.dark,
                          onChanged: (val) => ref
                              .read(settingsProvider.notifier)
                              .setThemeMode(
                                val ? ThemeMode.dark : ThemeMode.light,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // --- تسجيل الخروج ---
                _buildSectionHeader(context, 'logoutSection'.tr()),
                const SizedBox(height: 12),
                GlassCard(
                  borderRadius: 24,
                  child: _buildTile(
                    context,
                    Icons.logout_rounded,
                    'logout'.tr(),
                    iconColor: Colors.redAccent,
                    onTap: () async {
                      // استدعاء دالة تسجيل الخروج من AuthProvider وإعادة التوجيه لصفحة الدخول
                      await ref.read(authProvider.notifier).logout();
                      if (mounted) context.go('/login');
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // عرض إصدار التطبيق (App Version)
                Center(
                  child: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Column(
                          children: [
                            Text(
                              'Stylora v${snapshot.data!.version}',
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Build ${snapshot.data!.buildNumber}',
                              style: context.textTheme.labelSmall?.copyWith(
                                color: context.colorScheme.onSurface.withValues(
                                  alpha: 0.2,
                                ),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // بناء ترويسة الأقسام بتصميم موحد
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: context.textTheme.labelLarge?.copyWith(
          color: context.colorScheme.primary.withValues(alpha: 0.8),
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDivider() => Divider(
    height: 1,
    indent: 56,
    endIndent: 20,
    color: Colors.grey.withValues(alpha: 0.05),
  );

  // بناء عنصر القائمة (Tile) باستخدام الودجت الموحد (ListTile)
  Widget _buildTile(
    BuildContext context,
    IconData icon,
    String title, {
    void Function()? onTap,
    Widget? trailing,
    Color? iconColor,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? context.colorScheme.primary).withValues(
            alpha: 0.1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: iconColor ?? context.colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: context.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.colorScheme.onSurface,
        ),
      ),
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: context.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  // حوار اختيار وسيلة التحقق بخطوتين
  void _show2FAMethodSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        borderRadius: 32,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'choose2FAMethod'.tr(),
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _build2FAMethodTile(
                context,
                Icons.phonelink_lock_rounded,
                'authenticatorApp'.tr(),
                'twoFactorAuthDesc'.tr(),
                () {
                  Navigator.pop(context);
                  _showTwoFactorSetupDialog(context);
                },
              ),
              const SizedBox(height: 12),
              _build2FAMethodTile(
                context,
                Icons.sms_rounded,
                'smsText'.tr(),
                'smsMethodDesc'.tr(),
                () {
                  Navigator.pop(context);
                  _showPhone2FASetupDialog(context, 'sms');
                },
              ),
              const SizedBox(height: 12),
              _build2FAMethodTile(
                context,
                Icons.message_rounded,
                'whatsappMessage'.tr(),
                'whatsappMethodDesc'.tr(),
                () {
                  Navigator.pop(context);
                  _showPhone2FASetupDialog(context, 'whatsapp');
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build2FAMethodTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: context.colorScheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: context.textTheme.labelSmall),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }

  // حوار إعداد التحقق عبر الهاتف (SMS / WhatsApp)
  Future<void> _showPhone2FASetupDialog(
    BuildContext context,
    String method,
  ) async {
    final phoneService = ref.read(phoneAuthServiceProvider);
    final phoneController = TextEditingController(
      text: '+962',
    ); // Default to Jordan country code
    final codeController = TextEditingController();

    bool isCodeSent = false;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text(
            method == 'sms' ? 'smsText'.tr() : 'whatsappMessage'.tr(),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isCodeSent) ...[
                Text(
                  'enterPhoneFor2FA'.tr(),
                  style: context.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'phoneNumber'.tr(),
                  hint: '+966...',
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                ),
              ] else ...[
                Text('enterTOTPCode'.tr(), style: context.textTheme.bodySmall),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'verify'.tr(),
                  hint: '000000',
                  controller: codeController,
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
            CustomButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final phone = phoneController.text.trim();
                      if (phone.isEmpty) return;

                      setDialogState(() => isLoading = true);

                      if (!isCodeSent) {
                        // إرسال الكود
                        if (method == 'sms') {
                          await phoneService.sendSMSCode(
                            phoneNumber: phone,
                            onCodeSent: (id) =>
                                setDialogState(() => isCodeSent = true),
                            onError: (e) =>
                                context.showSnackBar(e, isError: true),
                          );
                        } else {
                          await phoneService.sendWhatsAppCode(
                            phoneNumber: phone,
                            onCodeSent: (code) =>
                                setDialogState(() => isCodeSent = true),
                          );
                        }
                      } else {
                        // التحقق من الكود
                        final isValid = method == 'sms'
                            ? await phoneService.verifySMS(codeController.text)
                            : phoneService.verifyMockCode(codeController.text);

                        if (isValid) {
                          await ref
                              .read(settingsProvider.notifier)
                              .set2FA(true, method: method, phoneNumber: phone);
                          if (mounted) {
                            Navigator.pop(context);
                            context.showSnackBar('phoneVerified'.tr());
                          }
                        } else {
                          if (mounted) {
                            context.showSnackBar(
                              'invalidTOTPCode'.tr(),
                              isError: true,
                            );
                          }
                        }
                      }

                      setDialogState(() => isLoading = false);
                    },
              text: !isCodeSent ? 'sendCode'.tr() : 'verify'.tr(),
              isLoading: isLoading,
              width: 120,
            ),
          ],
        ),
      ),
    );
  }

  // حوار إعداد التحقق بخطوتين (Authenticator App Setup)
  Future<void> _showTwoFactorSetupDialog(BuildContext context) async {
    final tfaService = ref.read(twoFactorServiceProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. توليد المفتاح السري ورابط الـ QR
    final secret = tfaService.generateSecret();
    final qrUri = tfaService.getAuthenticatorUri(
      email: user.email!,
      secret: secret,
    );

    if (!mounted) return;

    final codeController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text('setupTwoFactor'.tr(), textAlign: TextAlign.center),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'scanQRCode'.tr(),
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),

                // عرض الـ QR Code لكي يتم مسحه
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: qrUri,
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  '${'manualKey'.tr()}:',
                  style: context.textTheme.labelSmall,
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: secret));
                    context.showSnackBar('copied'.tr());
                  },
                  child: Text(
                    secret,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                CustomTextField(
                  label: 'enterTOTPCode'.tr(),
                  hint: '000000',
                  controller: codeController,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
            CustomButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      if (codeController.text.length != 6) return;

                      setDialogState(() => isVerifying = true);

                      // التحقق من صحة الكود المدخل أولاً قبل الحفظ
                      final isValid = tfaService.verifyCode(
                        secret,
                        codeController.text,
                      );

                      if (isValid) {
                        // إذا كان صحيحاً، نحفظ المفتاح ونفعل الميزة
                        await tfaService.saveSecret(secret);
                        await ref.read(settingsProvider.notifier).set2FA(true);
                        if (mounted) {
                          Navigator.pop(context);
                          context.showSnackBar('twoFactorEnabled'.tr());
                        }
                      } else {
                        if (mounted) {
                          context.showSnackBar(
                            'invalidTOTPCode'.tr(),
                            isError: true,
                          );
                        }
                      }

                      setDialogState(() => isVerifying = false);
                    },
              text: 'verify'.tr(),
              isLoading: isVerifying,
              width: 120,
            ),
          ],
        ),
      ),
    );
  }

  // حوار ربط الحساب بالبصمة لتسجيل الدخول السريع
  Future<void> _showBiometricLinkDialog(BuildContext context) async {
    final bioService = ref.read(biometricAuthServiceProvider);

    // 1. التحقق من دعم الجهاز
    final isAvailable = await bioService.isBiometricAvailable();
    if (!isAvailable) {
      if (mounted) {
        context.showSnackBar('biometricNotAvailable'.tr(), isError: true);
      }
      return;
    }

    // التحقق مما إذا كانت البصمة مربوطة بحساب آخر مسبقاً
    final linkedEmail = await bioService.getLinkedEmail();
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (email == null) return;

    if (linkedEmail != null && linkedEmail.toLowerCase().trim() != email.toLowerCase().trim()) {
      if (!context.mounted) return;
      
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: context.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text(
            context.locale.languageCode == 'ar' 
                ? 'البصمة مستخدمة بالفعل' 
                : 'Biometric Already Linked',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            context.locale.languageCode == 'ar'
                ? 'البصمة على هذا الجهاز مرتبطة بالفعل بحساب آخر:\n($linkedEmail)\n\nلا يمكنك ربط هذه البصمة بأكثر من حساب واحد على هذا الجهاز.'
                : 'Biometrics on this device are already linked to another account:\n($linkedEmail)\n\nYou cannot link this biometric to more than one account on this device.',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                context.locale.languageCode == 'ar' ? 'موافق' : 'OK',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // 2. طلب بصمة الإصبع أولاً كخطوة تأكيدية ابتدائية
    final initialAuth = await bioService.authenticate(
      reason: 'biometricSetupHint'.tr(),
    );
    if (!initialAuth) return;

    if (!mounted) return;

    // التحقق إذا كان المستخدم مسجلاً عبر جوجل (ليس لديه كلمة سر في Firebase Auth)
    final isGoogleUser = user!.providerData.any(
      (p) => p.providerId == 'google.com',
    );

    if (isGoogleUser) {
      // إذا كان مستخدم جوجل، نربط البصمة مباشرة بـ "علامة جوجل" بدلاً من كلمة السر اليدوية
      try {
        await bioService.linkAccount(email, 'GOOGLE_AUTH_CREDENTIAL');
        ref.read(settingsProvider.notifier).setBiometric(true);
        if (mounted) context.showSnackBar('biometricLinkedSuccessfully'.tr());
        return;
      } catch (e) {
        if (mounted) {
          context.showSnackBar('errorSavingProfile'.tr(), isError: true);
        }
        return;
      }
    }

    // 3. لمستخدمي البريد التقليدي: طلب كلمة المرور لمرة واحدة
    final passwordController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          // ...
          backgroundColor: context.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Column(
            children: [
              Icon(
                Icons.verified_user_rounded,
                size: 48,
                color: context.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text('linkWithBiometrics'.tr(), textAlign: TextAlign.center),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'lockCredentialsHint'.tr(),
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              CustomTextField(
                label: 'password'.tr(),
                hint: '••••••••',
                controller: passwordController,
                isPassword: true,
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
            CustomButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      if (passwordController.text.length < 6) return;

                      setDialogState(() => isVerifying = true);

                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        final email = user?.email;
                        if (email == null) throw Exception('No user');

                        // التحقق من صحة كلمة المرور عبر Firebase
                        await FirebaseAuth.instance.signInWithEmailAndPassword(
                          email: email,
                          password: passwordController.text,
                        );

                        // حفظ البيانات مشفرة وربطها بالبصمة
                        await bioService.linkAccount(
                          email,
                          passwordController.text,
                        );

                        if (mounted) {
                          ref
                              .read(settingsProvider.notifier)
                              .setBiometric(true);
                          Navigator.pop(context);
                          context.showSnackBar(
                            'biometricLinkedSuccessfully'.tr(),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          context.showSnackBar(
                            'invalidCredentials'.tr(),
                            isError: true,
                          );
                        }
                      } finally {
                        setDialogState(() => isVerifying = false);
                      }
                    },
              text: 'activateNow'.tr(),
              isLoading: isVerifying,
              width: 140,
            ),
          ],
        ),
      ),
    );
  }

  // حوار تغيير كلمة المرور للمستخدم
  void _showChangePasswordDialog(BuildContext context) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('changePassword'.tr()),
        content: TextField(
          controller: passwordController,
          decoration: InputDecoration(hintText: 'newPassword'.tr()),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              if (passwordController.text.isNotEmpty) {
                try {
                  // تحديث كلمة المرور في Firebase Auth
                  await FirebaseAuth.instance.currentUser?.updatePassword(
                    passwordController.text,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('passwordUpdated'.tr())),
                    );
                  }
                } catch (e) {
                  // طلب إعادة المصادقة إذا انتهت جلسة المستخدم أو كانت العملية حساسة
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('reauthRequired'.tr())),
                    );
                  }
                }
              }
            },
            child: Text('update'.tr()),
          ),
        ],
      ),
    );
  }
}

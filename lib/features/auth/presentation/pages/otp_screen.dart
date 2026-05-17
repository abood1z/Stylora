import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../providers/auth_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/service_providers.dart';

/// شاشة التحقق بخطوتين (OTP Verification)
class OTPScreen extends ConsumerStatefulWidget {
  final String email;
  final String? method; // totp, sms, whatsapp (جعلناه اختيارياً لضمان الأمن البرمجي)
  final bool isProfileSetup; // هل هي للتحقق عند الإعداد؟

  const OTPScreen({
    super.key, 
    required this.email, 
    this.method,
    this.isProfileSetup = false
  });

  @override
  ConsumerState<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends ConsumerState<OTPScreen> {
  // وسيلة التحقق المحمية من القيم الفارغة
  String get _safeMethod => widget.method ?? 'totp';

  // 6 وحدات لستة أرقام
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  int _timerSeconds = 60;
  Timer? _timer;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    
    // إذا كانت الوسيلة هاتف أو واتساب، نرسل الكود فوراً عند فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_safeMethod == 'sms' || _safeMethod == 'whatsapp') {
        _sendPhoneVerification();
      }
    });
  }

  Future<void> _sendPhoneVerification() async {
    final phoneService = ref.read(phoneAuthServiceProvider);
    final userData = ref.read(settingsProvider).userData;
    final phone = userData?['phoneNumber'] ?? '';
    
    if (phone.isEmpty) return;

    if (_safeMethod == 'sms') {
      await phoneService.sendSMSCode(
        phoneNumber: phone, 
        onCodeSent: (_) => context.showSnackBar('otpResent'.tr()), 
        onError: (e) => context.showSnackBar(e, isError: true)
      );
    } else {
      await phoneService.sendWhatsAppCode(
        phoneNumber: phone, 
        onCodeSent: (_) => context.showSnackBar('otpResent'.tr())
      );
    }
  }

  void _startTimer() {
    _timerSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds == 0) {
        timer.cancel();
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  // التحقق من الكود
  Future<void> _verifyCode() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 6) return;

    setState(() => _isVerifying = true);
    HapticFeedback.mediumImpact();

    // محاكاة عملية التحقق (في بيئة الإنتاج يتم ربطها بخدمة API)
    await Future.delayed(const Duration(seconds: 1));

    final tfaService = ref.read(twoFactorServiceProvider);
    final phoneService = ref.read(phoneAuthServiceProvider);
    final secret = await tfaService.getSecret();
    
    bool isValid = false;
    if (_safeMethod == 'totp' && secret != null) {
      isValid = tfaService.verifyCode(secret, code);
    } else if (_safeMethod == 'sms') {
      isValid = await phoneService.verifySMS(code);
    } else if (_safeMethod == 'whatsapp') {
      isValid = phoneService.verifyMockCode(code);
    } else {
      // إذا لم يوجد مفتاح (للتطوير فقط)، نسمح بالكود 123456
      isValid = code == "123456";
    }

    if (isValid) {
      ref.read(otpVerifiedProvider.notifier).state = true;
      setState(() => _isVerifying = false);
      if (mounted) {
        context.showSnackBar('verifiedSuccessfully'.tr());
        context.go('/home');
      }
    } else {
      setState(() => _isVerifying = false);
      HapticFeedback.heavyImpact();
      if (mounted) {
        context.showSnackBar('invalidOTP'.tr(), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // لضمان تحرك المحتوى عند ظهور الكيبورد
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colorScheme.surface,
              context.colorScheme.primary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView( // الحل لمشكلة الـ Overflow
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 60),
                Icon(Icons.security_rounded, size: 80, color: context.colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  (_safeMethod == 'sms') ? 'smsText'.tr() : (_safeMethod == 'whatsapp' ? 'whatsappMessage'.tr() : 'authenticatorApp'.tr()),
                  style: context.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Text(
                  (_safeMethod == 'totp') 
                    ? 'twoFactorAuthDesc'.tr() 
                    : 'otpSentTo'.tr(args: [ref.watch(settingsProvider).phoneNumber ?? '...']),
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium?.copyWith(color: context.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 50),
                
                // حقول إدخال الأرقام الستة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) => _buildOTPBox(index)),
                ),
                
                const SizedBox(height: 50),
                
                CustomButton(
                  onPressed: _verifyCode, 
                  text: 'verify'.tr(),
                  isLoading: _isVerifying,
                ),
                
                const SizedBox(height: 24),
                
                // إعادة إرسال الكود
                TextButton(
                  onPressed: _timerSeconds == 0 ? () {
                    _startTimer();
                    _sendPhoneVerification(); // إعادة الإرسال الحقيقي
                  } : null,
                  child: Text(
                    _timerSeconds > 0 
                      ? 'resendIn'.tr(args: [_timerSeconds.toString()]) 
                      : 'resendOTP'.tr(),
                    style: TextStyle(
                      color: _timerSeconds == 0 ? context.colorScheme.primary : Colors.grey,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
                const SizedBox(height: 40), // مساحة إضافية في الأسفل للتمرير
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ودجت المربع المنفرد للرقم مع دعم اللصق الذكي
  Widget _buildOTPBox(int index) {
    return SizedBox(
      width: 45,
      height: 60,
      child: GlassCard(
        borderRadius: 12,
        opacity: 0.05,
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 6, // نسمح بـ 6 أحرف مؤقتاً لدعم "اللصق"
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(counterText: "", border: InputBorder.none),
          onChanged: (value) {
            // منطق "اللصق": إذا كان النص أطول من حرف واحد، نقوم بتوزيعه
            if (value.length > 1) {
              final pastedValue = value.replaceAll(RegExp(r'\D'), ''); // استخراج الأرقام فقط
              for (var i = 0; i < pastedValue.length && i < 6; i++) {
                _controllers[i].text = pastedValue[i];
              }
              // نقل التركيز لآخر مربع
              final lastFocus = pastedValue.length < 6 ? pastedValue.length : 5;
              _focusNodes[lastFocus].requestFocus();
              
              if (pastedValue.length >= 6) _verifyCode(); // التحقق التلقائي عند اكتمال اللصق
              return;
            }

            // المنطق العادي: الانتقال للمربع التالي/السابق
            if (value.isNotEmpty && index < 5) {
              _focusNodes[index + 1].requestFocus();
            } else if (value.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
            
            if (index == 5 && value.isNotEmpty) {
              _verifyCode();
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}

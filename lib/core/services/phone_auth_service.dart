import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// خدمة التحقق عبر الهاتف (SMS & WhatsApp)
class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  String? _mockCode;

  // إرسال الكود عبر SMS (باستخدام Firebase)
  Future<void> sendSMSCode({
    required String phoneNumber,
    required Function(String code) onCodeSent,
    required Function(String error) onError,
  }) async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      // في وضع التطوير على الويندوز، نستخدم كود وهمي لأن Firebase Phone Auth يحتاج أندرويد/iOS
      _mockCode = (100000 + Random().nextInt(900000)).toString();
      debugPrint('MOCK SMS CODE FOR $phoneNumber: $_mockCode');
      onCodeSent(_mockCode!);
      return;
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.currentUser?.linkWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Error sending SMS');
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  // إرسال الكود عبر WhatsApp (محاكاة احترافية)
  Future<void> sendWhatsAppCode({
    required String phoneNumber,
    required Function(String code) onCodeSent,
  }) async {
    // توليد كود عشوائي
    final code = (100000 + Random().nextInt(900000)).toString();
    _mockCode = code;
    
    // في التطبيق الحقيقي، يتم استدعاء API خارجي (مثل Twilio) لإرسال الرسالة
    // هنا سنقوم بفتح واتساب "لمحاكاة" وصول الرسالة (لغرض العرض التقني)
    final message = 'Your Stylora 2FA code is: $code';
    final url = 'https://wa.me/${phoneNumber.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}';
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
    
    onCodeSent(code);
  }

  // التحقق من الكود المدخل
  bool verifyMockCode(String input) {
    return input == _mockCode;
  }

  // التحقق من كود SMS الحقيقي (Firebase)
  Future<bool> verifySMS(String smsCode) async {
    if (_verificationId == null) return verifyMockCode(smsCode);
    
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      await _auth.currentUser?.linkWithCredential(credential);
      return true;
    } catch (e) {
      return false;
    }
  }
}

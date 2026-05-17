import 'dart:math';
import 'package:otp/otp.dart';
import 'package:base32/base32.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:typed_data';

/// خدمة التحقق بخطوتين (Two-Factor Authentication Service)
/// تستخدم مكتبة otp المتوافقة مع Null Safety
class TwoFactorService {
  final _storage = const FlutterSecureStorage();
  
  // توليد مفتاح سري عشوائي (Secret Key) متوافق مع Authenticator
  String generateSecret() {
    final random = Random.secure();
    final values = Uint8List.fromList(List<int>.generate(20, (i) => random.nextInt(256)));
    // تحويل القيم إلى Base32 كما هو مطلوب لـ Google Authenticator
    return base32.encode(values);
  }

  // توليد رابط الـ QR (URI) الذي يتم مسحه بتطبيق Google Authenticator
  String getAuthenticatorUri({
    required String email,
    required String secret,
    String issuer = 'Stylora',
  }) {
    return 'otpauth://totp/$issuer:$email?secret=$secret&issuer=$issuer';
  }

  // التحقق من أن الكود المكون من 6 أرقام صحيح وصادر من التطبيق في اللحظة الحالة
  bool verifyCode(String secret, String code) {
    // توليد الكود الحالي بناءً على المفتاح السري والوقت الحالي
    final expectedCode = OTP.generateTOTPCodeString(
      secret, 
      DateTime.now().millisecondsSinceEpoch,
      algorithm: Algorithm.SHA1,
      isGoogle: true
    );
    
    // للتعامل مع فرق التوقيت البسيط، نتحقق أيضاً من الكود السابق واللاحق (Window of 1)
    final prevCode = OTP.generateTOTPCodeString(
      secret, 
      DateTime.now().millisecondsSinceEpoch - 30000,
      algorithm: Algorithm.SHA1,
      isGoogle: true
    );
    
    final nextCode = OTP.generateTOTPCodeString(
      secret, 
      DateTime.now().millisecondsSinceEpoch + 30000,
      algorithm: Algorithm.SHA1,
      isGoogle: true
    );

    return code == expectedCode || code == prevCode || code == nextCode;
  }

  // حفظ المفتاح السري في الذاكرة المشفرة للهاتف
  Future<void> saveSecret(String secret) async {
    await _storage.write(key: 'two_factor_secret', value: secret);
  }

  // استرجاع المفتاح السري (لعملية التحقق لاحقاً)
  Future<String?> getSecret() async {
    return await _storage.read(key: 'two_factor_secret');
  }

  // إزالة التفعيل
  Future<void> disable() async {
    await _storage.delete(key: 'two_factor_secret');
  }
}

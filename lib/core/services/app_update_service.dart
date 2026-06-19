import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
class AppUpdateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // فحص ما إذا كان هناك تحديث متوفر (يرجع 'true' إذا كان التحديث إجبارياً لمنع التنقل)
  Future<bool> checkForUpdate(BuildContext context) async {
    try {
      // الحصول على النسخة الحالية ديناميكياً من نظام التشغيل
      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;
      debugPrint('🔍 Current App Version: $currentVersion');

      // جلب بيانات التحديث من Firestore (مجموعة app_config -> وثيقة update_info)
      final doc = await _firestore.collection('app_config').doc('update_info').get();
      
      if (!doc.exists) return false;

      final data = doc.data()!;
      final minVersion = data['min_version'] as String; // أقل نسخة مسموح بها للاستمرار
      final latestVersion = data['latest_version'] as String; // أحدث نسخة متوفرة في المتجر
      final updateUrl = data['update_url'] as String; // رابط التحديث (App Store / Play Store)

      // منطق التحقق من النسخ
      if (_isVersionLower(currentVersion, minVersion)) {
        // تحديث إجباري (Force Update): المستخدم لا يستطيع تجاوز الشاشة
        if (context.mounted) {
          _showUpdateDialog(context, updateUrl, isForce: true);
          return true; // إيقاف التنقل في الخلفية
        }
      } else if (_isVersionLower(currentVersion, latestVersion)) {
        // تحديث اختياري (Optional Update): يمكن للمستخدم التجاهل والاستمرار
        final prefs = await SharedPreferences.getInstance();
        final lastShown = prefs.getInt('optional_update_last_shown') ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        
        if (now - lastShown >= 24 * 60 * 60 * 1000) {
          if (context.mounted) {
            _showUpdateDialog(context, updateUrl, isForce: false);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
    return false;
  }

  // خوارزمية مقارنة إصدارات التطبيق (تتعامل مع التنسيق X.Y.Z)
  bool _isVersionLower(String current, String target) {
    try {
      List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> targetParts = target.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < targetParts.length; i++) {
          if (i >= currentParts.length || currentParts[i] < targetParts[i]) {
              return true;
          } else if (currentParts[i] > targetParts[i]) {
              return false;
          }
      }
    } catch (e) {
      debugPrint('Version parsing error: $e');
    }
    return false;
  }

  // بناء حوار التحديث بتصميم Premium وألوان متناسقة
  void _showUpdateDialog(BuildContext context, String url, {required bool isForce}) {
    showDialog(
      context: context,
      barrierDismissible: false, // منع الإغلاق بالنقر خارجاً سواء كان إجبارياً أو اختيارياً
      builder: (context) => PopScope(
        canPop: !isForce,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          backgroundColor: Theme.of(context).colorScheme.surface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // أيقونة توضيحية حسب نوع التحديث
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isForce ? Colors.red.withAlpha(25) : Colors.blue.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isForce ? Icons.system_update_alt_rounded : Icons.rocket_launch_rounded,
                  size: 50,
                  color: isForce ? Colors.red : Colors.blue,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isForce ? 'forceUpdateAvailable'.tr() : 'optionalUpdateAvailable'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                isForce 
                  ? 'forceUpdateDesc'.tr()
                  : 'optionalUpdateDesc'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(fontSize: 13, height: 1.5, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                  ),
                  onPressed: () => _launchURL(url),
                  child: Text(
                    'updateNow'.tr(),
                    style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              if (!isForce) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('optional_update_last_shown', DateTime.now().millisecondsSinceEpoch);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(
                    'later'.tr(),
                    style: GoogleFonts.tajawal(color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // فتح رابط المتجر خارج التطبيق
  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

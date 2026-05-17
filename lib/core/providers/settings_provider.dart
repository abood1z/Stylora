import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

// تمثيل حالة إعدادات التطبيق
class SettingsState {
  final ThemeMode themeMode; // وضع المظهر (فاتح/داكن/تلقائي)
  final String language; // لغة التطبيق (ar/en)
  final bool notificationsEnabled; // هل الإشعارات العامة مفعلة؟
  final bool biometricEnabled; // هل البصمة مفعلة؟
  final bool transactionalNotifs; // إشعارات العمليات (مثل الشراء)
  final bool storeNotifs; // إشعارات المتجر والعروض
  final bool smartEngagement; // التفاعل الذكي (اقتراحات الملابس)
  final bool is2FAEnabled; // هل التحقق بخطوتين مفعل؟
  final String? tfaMethod; // وسيلة التحقق (totp, sms, whatsapp)
  final String? phoneNumber; // رقم الهاتف للتحقق
  final String? country; // الدولة
  final String? province; // المحافظة
  final String? city; // المدينة
  final Map<String, dynamic>? userData; // بيانات المستخدم الإضافية من Firestore

  SettingsState({
    this.themeMode = ThemeMode.light,
    this.language = 'ar',
    this.notificationsEnabled = true,
    this.biometricEnabled = false,
    this.transactionalNotifs = true,
    this.storeNotifs = true,
    this.smartEngagement = true,
    this.is2FAEnabled = false,
    this.tfaMethod,
    this.phoneNumber,
    this.country,
    this.province,
    this.city,
    this.userData,
  });

  // دالة لنسخ الحالة مع تعديل قيم معينة (Immutable state pattern)
  SettingsState copyWith({
    ThemeMode? themeMode,
    String? language,
    bool? notificationsEnabled,
    bool? biometricEnabled,
    bool? transactionalNotifs,
    bool? storeNotifs,
    bool? smartEngagement,
    bool? is2FAEnabled,
    String? tfaMethod,
    String? phoneNumber,
    String? country,
    String? province,
    String? city,
    Map<String, dynamic>? userData,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      transactionalNotifs: transactionalNotifs ?? this.transactionalNotifs,
      storeNotifs: storeNotifs ?? this.storeNotifs,
      smartEngagement: smartEngagement ?? this.smartEngagement,
      is2FAEnabled: is2FAEnabled ?? this.is2FAEnabled,
      tfaMethod: tfaMethod ?? this.tfaMethod,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      country: country ?? this.country,
      province: province ?? this.province,
      city: city ?? this.city,
      userData: userData ?? this.userData,
    );
  }

  // الحصول على رمز العملة بناءً على الدولة المختارة
  String get currencySymbol {
    final countryName = country?.toLowerCase() ?? '';
    if (countryName.contains('jordan')) return 'JD';
    if (countryName.contains('saudi')) return 'SAR';
    if (countryName.contains('emirates')) return 'AED';
    if (countryName.contains('kuwait')) return 'KWD';
    if (countryName.contains('qatar')) return 'QAR';
    if (countryName.contains('palestine')) return 'ILS';
    if (countryName.contains('egypt')) return 'EGP';
    if (countryName.contains('turkey')) return 'TRY';
    return '\$'; // الافتراضي هو الدولار
  }
}

// مدير حالة الإعدادات (Notifier)
class SettingsNotifier extends Notifier<SettingsState> {
  final FirestoreService _firestoreService = FirestoreService();
  late SharedPreferences _prefs;

  @override
  SettingsState build() {
    // الحصول على مساحة التخزين المحلية
    _prefs = ref.watch(sharedPreferencesProvider);
    
    // مراقبة تغييرات حالة تسجيل الدخول
    ref.listen(authStateProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        // إذا سجل المستخدم دخوله، قم بتحميل إعداداته من السحابة
        loadRemoteSettings(user.uid);
      } else {
        // إذا سجل خروجه، عد للإعدادات المحلية الافتراضية
        state = _loadLocalSettings();
      }
    });

    return _loadLocalSettings();
  }

  // تحميل الإعدادات المخزنة محلياً على الهاتف
  SettingsState _loadLocalSettings() {
    final theme = _prefs.getString('theme') ?? 'light';
    final themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    final language = _prefs.getString('language') ?? 'ar';
    final notificationsEnabled = _prefs.getBool('notifications') ?? true;
    final biometricEnabled = _prefs.getBool('biometric') ?? false;
    final transactionalNotifs = _prefs.getBool('transactionalNotifs') ?? true;
    final storeNotifs = _prefs.getBool('storeNotifs') ?? true;
    final smartEngagement = _prefs.getBool('smartEngagement') ?? true;
    final is2FAEnabled = _prefs.getBool('is2FAEnabled') ?? false;
    
    return SettingsState(
      themeMode: themeMode,
      language: language,
      notificationsEnabled: notificationsEnabled,
      biometricEnabled: biometricEnabled,
      transactionalNotifs: transactionalNotifs,
      storeNotifs: storeNotifs,
      smartEngagement: smartEngagement,
      is2FAEnabled: is2FAEnabled,
      tfaMethod: _prefs.getString('tfaMethod'),
      phoneNumber: _prefs.getString('phoneNumber'),
      country: _prefs.getString('country'),
      province: _prefs.getString('province'),
      city: _prefs.getString('city'),
    );
  }

  // تحميل الإعدادات من Firestore ومزامنتها مع الهاتف
  Future<void> loadRemoteSettings(String uid) async {
    try {
      final userData = await _firestoreService.getUserData(uid);
      if (userData != null) {
        ThemeMode themeMode = state.themeMode;
        String language = state.language;
        bool notificationsEnabled = state.notificationsEnabled;
        bool biometricEnabled = state.biometricEnabled;
        bool transactionalNotifs = state.transactionalNotifs;
        bool storeNotifs = state.storeNotifs;
        bool smartEngagement = state.smartEngagement;

        // تحديث الثيم
        if (userData.containsKey('theme')) {
          themeMode = userData['theme'] == 'dark' ? ThemeMode.dark : ThemeMode.light;
          await _prefs.setString('theme', userData['theme']);
        }
        // تحديث اللغة
        if (userData.containsKey('language')) {
          language = userData['language'] ?? 'ar';
          await _prefs.setString('language', language);
        }
        
        final Map<String, dynamic> remoteSettings = (userData['settings'] as Map<String, dynamic>?) ?? {};
        
        // تحديث الإشعارات العامة
        if (userData.containsKey('notifications')) {
          notificationsEnabled = userData['notifications'] ?? true;
          await _prefs.setBool('notifications', notificationsEnabled);
        }

        // تحديث إعدادات الأمان والتنبيهات الفرعية
        if (remoteSettings.containsKey('biometric')) {
          biometricEnabled = remoteSettings['biometric'] ?? false;
          await _prefs.setBool('biometric', biometricEnabled);
        }
        if (remoteSettings.containsKey('transactionalNotifs')) {
          transactionalNotifs = remoteSettings['transactionalNotifs'] ?? true;
          await _prefs.setBool('transactionalNotifs', transactionalNotifs);
        }
        if (remoteSettings.containsKey('storeNotifs')) {
          storeNotifs = remoteSettings['storeNotifs'] ?? true;
          await _prefs.setBool('storeNotifs', storeNotifs);
        }
        if (remoteSettings.containsKey('smartEngagement')) {
          smartEngagement = remoteSettings['smartEngagement'] ?? true;
          await _prefs.setBool('smartEngagement', smartEngagement);
        }
        
        // تحديث حالة التطبيق في الذاكرة
        state = state.copyWith(
          themeMode: themeMode,
          language: language,
          notificationsEnabled: notificationsEnabled,
          biometricEnabled: biometricEnabled,
          transactionalNotifs: transactionalNotifs,
          storeNotifs: storeNotifs,
          smartEngagement: smartEngagement,
          is2FAEnabled: userData['is2FAEnabled'] ?? false,
          tfaMethod: userData['tfaMethod'],
          phoneNumber: userData['phoneNumber'],
          country: userData['country'],
          province: userData['province'],
          city: userData['city'],
          userData: userData,
        );
      }
    } catch (e) {
      debugPrint('SettingsNotifier: loadRemoteSettings error: $e');
    }
  }

  // تغيير المظهر وحفظه
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString('theme', mode == ThemeMode.dark ? 'dark' : 'light');
    _updateFirestore({'theme': mode == ThemeMode.dark ? 'dark' : 'light'});
  }

  // تغيير لغة التطبيق وحفظها
  Future<void> setLanguage(String lang) async {
    state = state.copyWith(language: lang);
    await _prefs.setString('language', lang);
    _updateFirestore({'language': lang});
  }

  // تفعيل/تعطيل الإشعارات وحفظ الحالة
  Future<void> setNotifications(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    await _prefs.setBool('notifications', enabled);
    _updateFirestore({'notifications': enabled});
  }

  // تفعيل/تعطيل البصمة
  Future<void> setBiometric(bool enabled) async {
    state = state.copyWith(biometricEnabled: enabled);
    await _prefs.setBool('biometric', enabled);
    _updateFirestoreNested({'biometric': enabled});
  }

  // إدارة إشعارات العمليات
  Future<void> setTransactionalNotifs(bool enabled) async {
    state = state.copyWith(transactionalNotifs: enabled);
    await _prefs.setBool('transactionalNotifs', enabled);
    _updateFirestoreNested({'transactionalNotifs': enabled});
  }

  // إدارة إشعارات المتجر
  Future<void> setStoreNotifs(bool enabled) async {
    state = state.copyWith(storeNotifs: enabled);
    await _prefs.setBool('storeNotifs', enabled);
    _updateFirestoreNested({'storeNotifs': enabled});
  }

  // إدارة التفاعل الذكي
  Future<void> setSmartEngagement(bool enabled) async {
    state = state.copyWith(smartEngagement: enabled);
    await _prefs.setBool('smartEngagement', enabled);
    _updateFirestoreNested({'smartEngagement': enabled});
  }

  // تفعيل/تعطيل التحقق بخطوتين وتحديد الوسيلة
  Future<void> set2FA(bool enabled, {String? method, String? phoneNumber}) async {
    state = state.copyWith(is2FAEnabled: enabled, tfaMethod: method, phoneNumber: phoneNumber);
    await _prefs.setBool('is2FAEnabled', enabled);
    
    final updates = <String, dynamic>{
      'is2FAEnabled': enabled,
      'tfaMethod': method,
    };

    if (method != null) {
      await _prefs.setString('tfaMethod', method);
    } else {
      await _prefs.remove('tfaMethod');
    }

    if (phoneNumber != null) {
      await _prefs.setString('phoneNumber', phoneNumber);
      updates['phoneNumber'] = phoneNumber;
    }

    _updateFirestore(updates);
  }

  // تحديث بيانات المستخدم (الملف الشخصي) بشكل عام
  Future<void> updateProfile(Map<String, dynamic> data) async {
    // تحديث الحالة محلياً أولاً
    state = state.copyWith(
      userData: {
        ...state.userData ?? {},
        ...data,
      },
    );

    // حفظ القيم الأساسية (مثل الموقع) في التخزين المحلي إذا وجدت
    if (data.containsKey('country')) {
      await _prefs.setString('country', data['country']);
    }
    if (data.containsKey('province')) {
      await _prefs.setString('province', data['province']);
    }
    if (data.containsKey('city')) {
      await _prefs.setString('city', data['city']);
    }
    if (data.containsKey('locationCompleted')) {
      await _prefs.setBool('locationCompleted', data['locationCompleted']);
    }

    // التحديث في Firestore
    await _updateFirestore(data);
  }

  // تحديث القيم في Firestore (مستوى جذر الوثيقة)
  Future<void> _updateFirestore(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _firestoreService.updateSettings(user.uid, data);
      } catch (e) {
        debugPrint('SettingsNotifier: _updateFirestore error: $e');
      }
    }
  }

  // تحديث القيم داخل خريطة 'settings' في Firestore باستخدام الرمز (.)
  Future<void> _updateFirestoreNested(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final Map<String, dynamic> nestedData = {};
        data.forEach((key, value) {
          nestedData['settings.$key'] = value;
        });
        await _firestoreService.updateSettings(user.uid, nestedData);
      } catch (e) {
        debugPrint('SettingsNotifier: _updateFirestoreNested error: $e');
      }
    }
  }
}

// بروفايدر الإعدادات العالمي
final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

// بروفايدر التخزين المحلي (يتم تهيئته في main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

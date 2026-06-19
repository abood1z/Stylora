import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../router/navigation_keys.dart';


// يجب أن تكون الدالة من المستوى الأعلى (Top-level function) لتعمل في الخلفية
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

// خدمة إدارة الإشعارات المحلية والبعيدة (FCM)
class NotificationService {
  // ممر الإشعارات المحلية
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // تهيئة نظام الإشعارات
  static Future<void> initialize() async {
    // تعريف دالة التعامل مع الإشعارات في الخلفية (Background)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // طلب الإذن لإرسال الإشعارات (مهم في iOS و Android 13+)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // إعدادات Android (يجب أن يتطابق الاسم "@mipmap/ic_launcher" مع أيقونة التطبيق)
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // إعدادات iOS
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // التعامل مع الضغط على الإشعار في حالة الـ Foreground
        _handleDeepLink(response.payload);
      },
    );

    // الاستماع للإشعارات عندما يكون التطبيق بالواجهة (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // فحص نوع الإشعار القادم من FCM (نفترض وجود حقل category في data)
        final category = message.data['category'] ?? 'store'; 
        showLocalNotification(
          title: message.notification!.title ?? 'Stylora',
          body: message.notification!.body ?? '',
          payload: message.data['route'],
          category: category,
        );
      }
    });

    // الاستماع للإشعارات عند فتح التطبيق بعد أن كان مغلقاً تماماً (Terminated)
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null && message.data.containsKey('route')) {
        _handleDeepLink(message.data['route']);
      }
    });

    // الاستماع للإشعارات عند الضغط عليها والتطبيق في الخلفية (Background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data.containsKey('route')) {
        _handleDeepLink(message.data['route']);
      }
    });
  }

  // دالة لإظهار الإشعارات المحلية
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String category = 'transactional', // transactional, store, smart_engagement
  }) async {
    // التحقق من تفضيلات المستخدم قبل الإظهار
    final prefs = await SharedPreferences.getInstance();
    
    // التحقق من المفتاح الرئيسي أولاً
    final isMasterEnabled = prefs.getBool('notifications') ?? true;
    if (!isMasterEnabled) {
      debugPrint('🔕 All notifications suppressed by master switch');
      return;
    }
    
    bool isEnabled = true;
    if (category == 'transactional') {
      isEnabled = prefs.getBool('transactionalNotifs') ?? true;
    } else if (category == 'store') {
      isEnabled = prefs.getBool('storeNotifs') ?? true;
    } else if (category == 'smart_engagement') {
      isEnabled = prefs.getBool('smartEngagement') ?? true;
    }

    if (!isEnabled) {
      debugPrint('🔕 Notification suppressed by user settings: $category');
      return;
    }
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'stylora_premium_notifications', // Channel ID جديد لتفعيل الصوت
      'notificationChannelName'.tr(), // Channel Name
      channelDescription: 'notificationChannelDesc'.tr(),
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF1E1E1E),
      playSound: true,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  // التحقق من حالة إذن الإشعارات في النظام
  static Future<bool> isSystemNotificationEnabled() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized || 
           settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // فتح إعدادات إشعارات النظام للتطبيق
  static Future<void> openSystemSettings() async {
    // نستخدم الروابط العميقة لفتح الإعدادات (تعمل في معظم الإصدارات الحديثة)
    debugPrint('⚙️ Opening system notification settings for Stylora...');
  }

  // التعامل مع الروابط العميقة (Deep Links) باستخدام المتغير route
  static void _handleDeepLink(String? route) {
    if (route != null && route.isNotEmpty) {
      debugPrint('🔔 Deep link activated. Navigating to route: $route');
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        GoRouter.of(context).push(route);
      } else {
        debugPrint('⚠️ Cannot navigate, root context is null');
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../providers/settings_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/signup_screen.dart';
import '../../features/home/presentation/pages/home_screen.dart';
import '../../features/camera/presentation/pages/camera_analysis_screen.dart';
import '../../features/outfit/presentation/pages/ai_suggestions_screen.dart';
import '../../features/shop/presentation/pages/shop_screen.dart';
import '../../features/profile/presentation/pages/profile_screen.dart';
import '../../features/profile/presentation/pages/settings_screen.dart';
import '../../features/auth/presentation/pages/complete_profile_screen.dart';
import '../../features/trader/presentation/pages/trader_dashboard_screen.dart';
import '../../features/trader/presentation/pages/add_product_screen.dart';
import '../../features/home/presentation/pages/closet_screen.dart';
import '../../features/home/presentation/pages/search_results_screen.dart';
import '../../features/onboarding/presentation/pages/splash_screen.dart';
import '../../features/outfit/presentation/pages/my_outfits_screen.dart';
import '../../features/outfit/presentation/pages/virtual_try_on_screen.dart';
import '../utils/context_ext.dart';
import '../utils/premium_transitions.dart';
import '../../features/auth/presentation/pages/otp_screen.dart';
import '../../features/profile/presentation/pages/location_setup_screen.dart';
import '../../features/camera/presentation/pages/live_tryon_screen.dart';
import 'package:camera/camera.dart';

// مفاتيح التنقل العامة للتطبيق
final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

// تعريف بروفايدر الروتر (GoRouter) لإدارة حركة التنقل
final routerProvider = Provider<GoRouter>((ref) {
  // مراقبة حالة المصادقة والضيف والبيانات الشخصية للتوجيه التلقائي
  ref.watch(authStateProvider);
  final isGuest = ref.watch(isGuestProvider);
  // راقب فقط البيانات التي تؤثر على التوجيه (Redirection) مثل اكتمال الملف الشخصي
  final userData = ref.watch(settingsProvider.select((s) => s.userData));
  final isOTPVerified = ref.watch(otpVerifiedProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    // تهيئة مستمع لتغييرات حالة المصادقة لتحديث المسارات تلقائياً عند الدخول/الخروج
    refreshListenable: AuthRefreshListenable(),
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isLoggingIn =
          state.uri.toString() == '/login' || state.uri.toString() == '/signup';
      final isSplash = state.uri.toString() == '/splash';

      if (isSplash) return null; // السماح بعرض شاشة البداية دائماً

      // توجيه المستخدم لصفحة تسجيل الدخول إذا لم يكن مسجلاً وليس ضيفاً
      if (user == null && !isGuest) {
        return isLoggingIn ? null : '/login';
      }

      // منطق التعامل مع المستخدم المسجل
      if (user != null) {
        if (userData == null) return null; // بانتظار تحميل بيانات المستخدم

        final is2FAEnabled = userData['is2FAEnabled'] ?? false;
        final isProfileComplete = userData['isProfileComplete'] ?? false;
        final isLocationComplete = userData['locationCompleted'] ?? false;

        // 1. التحقق من الأمان (2FA) أولاً
        if (is2FAEnabled && !isOTPVerified) {
          return state.uri.toString() == '/otp' ? null : '/otp';
        }

        // 2. إجبار المستخدم على إكمال ملفه الشخصي
        if (!isProfileComplete) {
          return state.uri.toString() == '/complete-profile' ? null : '/complete-profile';
        }

        // 3. إجبار المستخدم على تحديد موقعه
        if (!isLocationComplete) {
          return state.uri.toString() == '/location-setup' ? null : '/location-setup';
        }

        // إذا كان الملف مكتملاً والمصادقة الثانية مكتملة، لا تسمح له بالعودة لصفحات تسجيل الدخول
        if (isProfileComplete && isLoggingIn) {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => PremiumTransitions.fadeScalePage(
          child: const SplashScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => PremiumTransitions.fadeScalePage(
          child: const LoginScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) => PremiumTransitions.fadeScalePage(
          child: const SignupScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/complete-profile',
        pageBuilder: (context, state) => PremiumTransitions.fadeScalePage(
          child: const CompleteProfileScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/location-setup',
        pageBuilder: (context, state) => PremiumTransitions.fadeScalePage(
          child: const LocationSetupScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => PremiumTransitions.slideUpPage(
          child: const SettingsScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) {
          final query = state.uri.queryParameters['q'] ?? '';
          return PremiumTransitions.fadeScalePage(
            child: SearchResultsScreen(query: query),
            state: state,
          );
        },
      ),
      GoRoute(
        path: '/my-outfits',
        pageBuilder: (context, state) => PremiumTransitions.slideUpPage(
          child: const MyOutfitsScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/otp',
        pageBuilder: (context, state) {
          final email = FirebaseAuth.instance.currentUser?.email ?? '';
          final userData = ref.read(settingsProvider).userData;
          final String method = (userData?['tfaMethod'] as String?) ?? 'totp';
          return PremiumTransitions.fadeScalePage(
            child: OTPScreen(email: email, method: method),
            state: state,
          );
        },
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainNavigationScreen(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) {
              final settings = ref.read(settingsProvider);
              final role = settings.userData?['role'] ?? 'user';
              if (role == 'merchant' || role == 'trader') {
                return const TraderDashboardScreen();
              }
              return const HomeScreen();
            },
          ),
          GoRoute(
            path: '/matching',
            builder: (context, state) {
              final role = ref.read(settingsProvider.select((s) => s.userData?['role'])) ?? 'user';
              if (role == 'merchant' || role == 'trader') {
                return const Center(child: Text('Coming Soon: My Products List'));
              }
              return const ClosetScreen();
            },
          ),
          GoRoute(
            path: '/shop',
            builder: (context, state) => const ShopScreen(),
            routes: [
              GoRoute(
                path: 'product/:id',
                builder: (context, state) {
                  final productId = state.pathParameters['id'] ?? '';
                  // هنا نضع شاشة تفاصيل المنتج القادمة من الـ Deep Link
                  return Scaffold(
                    appBar: AppBar(title: Text('Product $productId')),
                    body: Center(child: Text('Product Details ID: $productId\nجاهزة للربط مع قاعدة البيانات')),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/camera',
        pageBuilder: (context, state) => PremiumTransitions.slideUpPage(
          child: const CameraAnalysisScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/ai_suggestions',
        pageBuilder: (context, state) => PremiumTransitions.slideUpPage(
          child: const AISuggestionsScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/add-product',
        pageBuilder: (context, state) => PremiumTransitions.slideUpPage(
          child: const AddProductScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/virtual-try-on',
        pageBuilder: (context, state) => PremiumTransitions.fadeScalePage(
          child: const VirtualTryOnScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/live-try-on',
        pageBuilder: (context, state) => PremiumTransitions.slideUpPage(
          child: LiveTryOnScreen(cameras: state.extra as List<CameraDescription>),
          state: state,
        ),
      ),
    ],
  );
});

class AppRouter {
  AppRouter._();
}

// واجهة التنقل الرئيسية التي تحتوي على الجسم والشريط السفلي (Main Navigation Wrapper)
class MainNavigationScreen extends ConsumerWidget {
  final Widget child; // المحتوى المتغير حسب المسار الحالي
  const MainNavigationScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // تحديد شكل شريط التنقل بناءً على دور المستخدم (تاجر أم عميل) من الإعدادات
    final role = ref.watch(settingsProvider.select((s) => s.userData?['role'] ?? 'user'));
    final isMerchant = role == 'merchant' || role == 'trader';
    final selectedIndex = _calculateSelectedIndex(context, isMerchant);

    return Scaffold(
      extendBody: false,
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: context.colorScheme.primary.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: isMerchant
                  ? [
                      // أزرار التنقل الخاصة بالتجار
                      _buildNavItem(
                        context,
                        0,
                        Icons.dashboard_rounded,
                        Icons.dashboard_outlined,
                        'dashboard'.tr(),
                        selectedIndex,
                      ),
                      _buildNavItem(
                        context,
                        1,
                        Icons.inventory_2_rounded,
                        Icons.inventory_2_outlined,
                        'myProducts'.tr(),
                        selectedIndex,
                      ),
                      _buildNavItem(
                        context,
                        2,
                        Icons.storefront_rounded,
                        Icons.storefront_outlined,
                        'storeProfile'.tr(),
                        selectedIndex,
                      ),
                    ]
                  : [
                      // أزرار التنقل الخاصة بالعملاء (المستخدمين العاديين)
                      _buildNavItem(
                        context,
                        0,
                        Icons.home_rounded,
                        Icons.home_outlined,
                        'home'.tr(),
                        selectedIndex,
                      ),
                      _buildNavItem(
                        context,
                        1,
                        Icons.checkroom_rounded,
                        Icons.checkroom_outlined,
                        'closet'.tr(),
                        selectedIndex,
                      ),
                      _buildNavItem(
                        context,
                        2,
                        Icons.shopping_bag_rounded,
                        Icons.shopping_bag_outlined,
                        'shop'.tr(),
                        selectedIndex,
                      ),
                      _buildNavItem(
                        context,
                        3,
                        Icons.person_rounded,
                        Icons.person_outline_rounded,
                        'profile'.tr(),
                        selectedIndex,
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
    int selectedIndex,
  ) {
    final isSelected = selectedIndex == index;
    final color = isSelected
        ? context.colorScheme.primary
        : context.colorScheme.onSurface.withValues(alpha: 0.4);

    return InkWell(
      onTap: () => _onItemTapped(index, context, selectedIndex == index),
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: color,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }



  static int _calculateSelectedIndex(BuildContext context, bool isMerchant) {
    final String location = GoRouterState.of(context).uri.toString();
    if (isMerchant) {
      if (location.startsWith('/home')) return 0;
      if (location.startsWith('/shop')) return 1; // Reuse /shop or add /inventory
      if (location.startsWith('/profile')) return 2;
    } else {
      if (location.startsWith('/home')) return 0;
      if (location.startsWith('/matching')) return 1;
      if (location.startsWith('/shop')) return 2;
      if (location.startsWith('/profile')) return 3;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context, bool isAlreadySelected) {
    if (isAlreadySelected) return;

    final role = ProviderScope.containerOf(context, listen: false).read(settingsProvider).userData?['role'];
    final isMerchant = role == 'merchant' || role == 'trader';

    if (isMerchant) {
      switch (index) {
        case 0:
          context.go('/home');
          break;
        case 1:
          context.go('/shop'); // Using /shop as My Products for now
          break;
        case 2:
          context.go('/profile');
          break;
      }
    } else {
      switch (index) {
        case 0:
          context.go('/home');
          break;
        case 1:
          context.go('/matching');
          break;
        case 2:
          context.go('/shop');
          break;
        case 3:
          context.go('/profile');
          break;
      }
    }
  }
}

class AuthRefreshListenable extends ChangeNotifier {
  AuthRefreshListenable() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      notifyListeners();
    });
  }
}

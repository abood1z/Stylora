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
import '../../features/trader/presentation/pages/edit_product_screen.dart';
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
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/shop/presentation/pages/product_details_screen.dart';
import '../../features/shop/presentation/pages/cart_screen.dart';
import '../../features/shop/presentation/pages/checkout_screen.dart';
import '../../features/profile/presentation/pages/order_history_screen.dart';
import '../../features/admin/presentation/pages/admin_dashboard_screen.dart';
import 'navigation_keys.dart';

class RouterRefreshListenable extends ChangeNotifier {
  final Ref _ref;
  final List<ProviderSubscription> _subscriptions = [];
  bool _isDisposed = false;

  bool isGuest = false;
  Map<String, dynamic>? userData;
  bool isOTPVerified = false;

  RouterRefreshListenable(this._ref) {
    isGuest = _ref.read(isGuestProvider);
    userData = _ref.read(settingsProvider).userData;
    isOTPVerified = _ref.read(otpVerifiedProvider);

    _subscriptions.add(_ref.listen<AsyncValue<User?>>(authStateProvider, (_, __) => _onChanged()));
    _subscriptions.add(_ref.listen<bool>(isGuestProvider, (_, next) {
      isGuest = next;
      _onChanged();
    }));
    _subscriptions.add(_ref.listen<Map<String, dynamic>?>(
      settingsProvider.select((s) => s.userData),
      (_, next) {
        userData = next;
        _onChanged();
      },
    ));
    _subscriptions.add(_ref.listen<bool>(otpVerifiedProvider, (_, next) {
      isOTPVerified = next;
      _onChanged();
    }));
  }

  void _onChanged() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (final sub in _subscriptions) {
      sub.close();
    }
    super.dispose();
  }
}

// تعريف بروفايدر الروتر (GoRouter) لإدارة حركة التنقل
final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = RouterRefreshListenable(ref);
  ref.onDispose(() => refreshListenable.dispose());

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isLoggingIn =
          state.uri.toString() == '/login' || state.uri.toString() == '/signup';
      final isSplash = state.uri.toString() == '/splash';

      if (isSplash) return null; // السماح بعرض شاشة البداية دائماً

      final isGuest = refreshListenable.isGuest;
      final userData = refreshListenable.userData;
      final isOTPVerified = refreshListenable.isOTPVerified;

      // توجيه المستخدم لصفحة تسجيل الدخول إذا لم يكن مسجلاً وليس ضيفاً
      if (user == null && !isGuest) {
        return isLoggingIn ? null : '/login';
      }

      // منطق التعامل مع المستخدم المسجل
      if (user != null) {
        if (userData == null) return null; // بانتظار تحميل بيانات المستخدم

        final role = userData['role'] ?? 'user';
        if (role == 'admin') {
          final currentPath = state.uri.toString();
          if (currentPath != '/admin') {
            return '/admin';
          }
          return null;
        }

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
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return MainNavigationScreen(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) {
              final settings = ref.watch(settingsProvider);
              final user = FirebaseAuth.instance.currentUser;
              final isGuest = ref.watch(isGuestProvider);
              if (user != null && settings.userData == null && !isGuest) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
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
              final settings = ref.watch(settingsProvider);
              final user = FirebaseAuth.instance.currentUser;
              final isGuest = ref.watch(isGuestProvider);
              if (user != null && settings.userData == null && !isGuest) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final role = settings.userData?['role'] ?? 'user';
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
                  final extra = state.extra;

                  if (extra is Map<String, dynamic>) {
                    return ProductDetailsScreen(product: extra);
                  }

                  // جلب بيانات المنتج من Firestore إذا لم يكن ممرراً في الـ extra
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('Products').doc(productId).get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                        return Scaffold(
                          appBar: AppBar(title: Text('error'.tr())),
                          body: Center(child: Text('productNotFoundOrError'.tr())),
                        );
                      }

                      final doc = snapshot.data!;
                      final data = doc.data() as Map<String, dynamic>;
                      data['id'] = doc.id;

                      return ProductDetailsScreen(product: data);
                    },
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
        path: '/edit-product',
        pageBuilder: (context, state) {
          final productMap = state.extra as Map<String, dynamic>;
          return PremiumTransitions.slideUpPage(
            child: EditProductScreen(productMap: productMap),
            state: state,
          );
        },
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
      GoRoute(
        path: '/cart',
        pageBuilder: (context, state) => PremiumTransitions.slideUpPage(
          child: const CartScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/checkout',
        pageBuilder: (context, state) => PremiumTransitions.slideUpPage(
          child: const CheckoutScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/order-history',
        pageBuilder: (context, state) => PremiumTransitions.slideUpPage(
          child: const OrderHistoryScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/admin',
        pageBuilder: (context, state) => PremiumTransitions.fadeScalePage(
          child: const AdminDashboardScreen(),
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
    final settings = ref.watch(settingsProvider);
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = ref.watch(isGuestProvider);

    if (user != null && settings.userData == null && !isGuest) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // تحديد شكل شريط التنقل بناءً على دور المستخدم (تاجر أم عميل) من الإعدادات
    final role = settings.userData?['role'] ?? 'user';
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
    try {
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
    } catch (_) {
      // Safeguard against assertion errors during router state transitions
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



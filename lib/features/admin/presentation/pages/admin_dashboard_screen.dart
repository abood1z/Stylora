import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/context_ext.dart';
import '../widgets/admin_users_tab.dart';
import '../widgets/admin_products_tab.dart';
import '../widgets/admin_orders_tab.dart';
import '../widgets/admin_settings_tab.dart';
import '../widgets/admin_vendors_tab.dart';
import '../widgets/admin_analytics_tab.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = context.locale.languageCode == 'ar';

    final navItems = [
      {'icon': Icons.analytics_rounded, 'title': isAr ? 'الإحصائيات' : 'Analytics', 'widget': const AdminAnalyticsTab()},
      {'icon': Icons.people_rounded, 'title': isAr ? 'المستخدمين' : 'Users', 'widget': const AdminUsersTab()},
      {'icon': Icons.shopping_bag_rounded, 'title': isAr ? 'المنتجات' : 'Products', 'widget': const AdminProductsTab()},
      {'icon': Icons.receipt_long_rounded, 'title': isAr ? 'الطلبات' : 'Orders', 'widget': const AdminOrdersTab()},
      {'icon': Icons.storefront_rounded, 'title': isAr ? 'المتاجر' : 'Vendors', 'widget': const AdminVendorsTab()},
      {'icon': Icons.settings_rounded, 'title': isAr ? 'إعدادات التطبيق' : 'App Settings', 'widget': const AdminSettingsTab()},
    ];

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          isAr ? 'لوحة القيادة (Admin)' : 'Command Center',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.language_rounded),
            onPressed: () async {
              if (isAr) {
                await context.setLocale(const Locale('en'));
              } else {
                await context.setLocale(const Locale('ar'));
              }
            },
            tooltip: isAr ? 'تغيير اللغة' : 'Change Language',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go('/login');
            },
            tooltip: isAr ? 'تسجيل الخروج' : 'Logout',
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        itemCount: navItems.length,
        itemBuilder: (context, index) {
          final item = navItems[index];
          return _buildGridItem(
            context,
            item['icon'] as IconData,
            item['title'] as String,
            item['widget'] as Widget,
          );
        },
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, IconData icon, String title, Widget targetWidget) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminSubScreen(title: title, child: targetWidget),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colorScheme.primary.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: context.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// واجهة غلاف فرعية لعرض التبويبات بشكل منفصل
class AdminSubScreen extends StatelessWidget {
  final String title;
  final Widget child;

  const AdminSubScreen({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: child,
    );
  }
}

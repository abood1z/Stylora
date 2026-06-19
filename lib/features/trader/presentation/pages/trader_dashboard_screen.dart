import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/data_providers.dart';

class TraderDashboardScreen extends ConsumerWidget {
  const TraderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(sellerOrdersProvider);
    final productsAsync = ref.watch(traderProductsProvider);
    final currency = ref.watch(settingsProvider).currencySymbol;

    final totalSalesStr = ordersAsync.maybeWhen(
      data: (orders) {
        final total = orders.fold<double>(0.0, (acc, order) => acc + (order['price'] as num? ?? 0.0).toDouble());
        return '${total.toStringAsFixed(2)} $currency';
      },
      orElse: () => '... $currency',
    );

    final activeProductsStr = productsAsync.maybeWhen(
      data: (products) => products.length.toString(),
      orElse: () => '...',
    );

    final activeOrdersStr = ordersAsync.maybeWhen(
      data: (orders) => orders.where((o) => o['status'] != 'completed').length.toString(),
      orElse: () => '...',
    );

    return Scaffold(
      body: Container(
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
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(24.0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // عنوان لوحة التحكم
                      Text(
                        'dashboard'.tr(),
                        style: context.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, color: context.colorScheme.onSurface),
                      ),
                      Text(
                        'welcomeBackStore'.tr(), 
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // شبكة الإحصائيات الرئيسية
                      _buildStatsGrid(context, totalSalesStr, activeProductsStr, activeOrdersStr),
                      const SizedBox(height: 32),
                      // قسم النشاطات الأخيرة
                      _buildRecentActivity(context, ordersAsync),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // بناء شبكة من بطاقات الإحصائيات
  Widget _buildStatsGrid(BuildContext context, String totalSales, String activeProducts, String activeOrders) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard(context, 'totalSales'.tr(), totalSales, Icons.payments_rounded, Colors.green, onTap: () => context.push('/order-history')),
        _buildStatCard(context, 'activeListings'.tr(), activeProducts, Icons.inventory_2_rounded, Colors.orange, onTap: () => context.push('/matching')),
        _buildStatCard(context, 'activeOrders'.tr(), activeOrders, Icons.shopping_bag_rounded, Colors.blue, onTap: () => context.push('/order-history')),
        _buildStatCard(context, 'storeNotifs'.tr(), activeOrders, Icons.notifications_active_rounded, Colors.purple, onTap: () => context.showSnackBar('comingSoon'.tr())),
      ],
    );
  }

  // بناء بطاقة إحصائية واحدة بتصميم زجاجي
  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: context.colorScheme.onSurface)),
              const SizedBox(height: 4),
              Text(label, style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.8),
              )),
            ],
          ),
        ],
      ),
      ),
    );
  }

  // بناء قسم يعرض النشاطات الأخيرة
  Widget _buildRecentActivity(BuildContext context, AsyncValue<List<Map<String, dynamic>>> ordersAsync) {
    final isAr = context.locale.languageCode == 'ar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'recentActivity'.tr(),
          style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: context.colorScheme.onSurface),
        ),
        const SizedBox(height: 16),
        GlassCard(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          child: ordersAsync.when(
            data: (orders) {
              if (orders.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      isAr ? 'لا توجد طلبات مستلمة بعد' : 'No orders received yet',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                );
              }
              final recent = orders.take(3).toList();
              return Column(
                children: [
                  for (int i = 0; i < recent.length; i++) ...[
                    if (i > 0) const Divider(height: 24),
                    _activityItem(
                      context,
                      isAr
                          ? 'تم استلام طلب جديد لـ "${recent[i]['productName']}"'
                          : 'New order received for "${recent[i]['productName']}"',
                      _formatTimestamp(recent[i]['createdAt'] as Timestamp?, isAr),
                      Icons.shopping_bag_rounded,
                    ),
                  ]
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  // بناء عنصر واحد في قائمة النشاطات
  Widget _activityItem(BuildContext context, String title, String time, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: context.colorScheme.onSurface)),
              const SizedBox(height: 2),
              Text(time, style: context.textTheme.labelSmall?.copyWith(color: context.colorScheme.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(Timestamp? timestamp, bool isAr) {
    if (timestamp == null) return isAr ? 'الآن' : 'just now';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return isAr ? 'الآن' : 'just now';
    if (diff.inMinutes < 60) return isAr ? 'منذ ${diff.inMinutes} دقيقة' : '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return isAr ? 'منذ ${diff.inHours} ساعة' : '${diff.inHours}h ago';
    return isAr ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d ago';
  }
}

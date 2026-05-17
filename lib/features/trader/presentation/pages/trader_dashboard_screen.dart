import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/utils/context_ext.dart';
import 'package:go_router/go_router.dart';

// شاشة لوحة تحكم التاجر (Trader Dashboard Screen)
// تعرض ملخصاً لأداء المتجر، المبيعات، والنشاطات الأخيرة
class TraderDashboardScreen extends ConsumerWidget {
  const TraderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-product'),
        backgroundColor: context.colorScheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('إضافة منتج'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
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
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(24.0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // عنوان لوحة التحكم
                      Text(
                        'لوحة التحكم'.tr(),
                        style: context.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'مرحباً بك مجدداً في متجرك'.tr(), 
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // شبكة الإحصائيات الرئيسية
                      _buildStatsGrid(context),
                      const SizedBox(height: 32),
                      // قسم النشاطات الأخيرة
                      _buildRecentActivity(context),
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

  // بناء شبكة من بطاقات الإحصائيات (المبيعات، المشاهدات، إلخ)
  Widget _buildStatsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard(context, 'إجمالي المبيعات'.tr(), '1,234 SR', Icons.payments_rounded, Colors.green),
        _buildStatCard(context, 'مشاهدات المنتجات'.tr(), '5.2k', Icons.visibility_rounded, Colors.blue),
        _buildStatCard(context, 'المنتجات النشطة'.tr(), '24', Icons.inventory_2_rounded, Colors.orange),
        _buildStatCard(context, 'تنبيهات النشاط'.tr(), '12', Icons.notifications_active_rounded, Colors.purple),
      ],
    );
  }

  // بناء بطاقة إحصائية واحدة بتصميم زجاجي
  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // أيقونة الإحصائية مع خلفية ملونة شفافة
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
              Text(value, style: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              Text(label, style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
              )),
            ],
          ),
        ],
      ),
    );
  }

  // بناء قسم يعرض النشاطات الأخيرة (مثل الطلبات أو الرسائل)
  Widget _buildRecentActivity(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'النشاطات الأخيرة'.tr(),
          style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GlassCard(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _activityItem(context, 'تم استلام طلب جديد #1234', 'منذ دقيقتين', Icons.shopping_bag_rounded),
              const Divider(height: 24),
              _activityItem(context, 'تم تحديث مخزون "فستان صيفي"', 'منذ ساعة', Icons.sync_rounded),
              const Divider(height: 24),
              _activityItem(context, 'رسالة جديدة من مستخدم', 'منذ 3 ساعات', Icons.chat_bubble_rounded),
            ],
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(time, style: context.textTheme.labelSmall?.copyWith(color: context.colorScheme.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        ),
      ],
    );
  }
}

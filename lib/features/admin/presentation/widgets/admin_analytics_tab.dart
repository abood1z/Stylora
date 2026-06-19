import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/utils/context_ext.dart';
import '../viewmodels/admin_viewmodel.dart';

class AdminAnalyticsTab extends ConsumerWidget {
  const AdminAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(adminAnalyticsProvider);
    final isAr = context.locale.languageCode == 'ar';

    return RefreshIndicator(
      onRefresh: () async {
        return ref.refresh(adminAnalyticsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            isAr ? 'إحصائيات الذكاء الاصطناعي' : 'AI Analytics',
            style: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          analyticsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (analytics) {
              final sortedCategories = analytics.categoryCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final sortedColors = analytics.colorCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatCard(
                    context,
                    title: isAr ? 'إجمالي استخدام التجربة الافتراضية' : 'Total Virtual Try-Ons',
                    value: analytics.totalVirtualTryOns.toString(),
                    icon: Icons.checkroom_rounded,
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isAr ? 'القطع الأكثر تواجداً في الخزائن' : 'Top Closet Categories',
                    style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (sortedCategories.isEmpty)
                    Text(isAr ? 'لا توجد بيانات' : 'No data available'),
                  ...sortedCategories.take(5).map((e) => _buildBar(context, e.key.tr(), e.value, sortedCategories.first.value)),
                  const SizedBox(height: 24),
                  Text(
                    isAr ? 'الألوان الأكثر تواجداً في الخزائن' : 'Top Closet Colors',
                    style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (sortedColors.isEmpty)
                    Text(isAr ? 'لا توجد بيانات' : 'No data available'),
                  ...sortedColors.take(5).map((e) => _buildBar(context, e.key.tr(), e.value, sortedColors.first.value)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: context.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(BuildContext context, String label, int count, int maxCount) {
    final double percentage = maxCount > 0 ? count / maxCount : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('$count', style: TextStyle(color: context.colorScheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: context.colorScheme.surfaceContainerHighest,
            color: context.colorScheme.primary,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

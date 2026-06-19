import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/data_providers.dart';
import '../../../../core/services/service_providers.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(settingsProvider.select((s) => s.userData?['role'] ?? 'user'));
    final isMerchant = role == 'merchant' || role == 'trader';
    final isAr = context.locale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          isMerchant ? (isAr ? 'طلبات المتجر' : 'Store Orders') : 'orderHistory'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colorScheme.surface,
              context.colorScheme.primary.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: _OrdersList(isSellerMode: isMerchant),
      ),
    );
  }
}

class _OrdersList extends ConsumerWidget {
  final bool isSellerMode;

  const _OrdersList({required this.isSellerMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(isSellerMode ? sellerOrdersProvider : buyerOrdersProvider);
    final currencySymbol = ref.watch(settingsProvider).currencySymbol;
    final isAr = context.locale.languageCode == 'ar';

    return ordersAsync.when(
      data: (orders) {
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 64,
                  color: context.colorScheme.onSurface.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  isAr ? 'لا توجد طلبات هنا بعد' : 'No orders found here yet',
                  style: context.textTheme.titleMedium?.copyWith(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          physics: const BouncingScrollPhysics(),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildOrderCard(context, ref, order, currencySymbol, isAr);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> order,
    String currencySymbol,
    bool isAr,
  ) {
    final status = order['status'] ?? 'pending';
    final isPending = status == 'pending';
    final createdAt = order['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt.toDate())
        : (isAr ? 'الآن' : 'Just now');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المنتج
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: order['imageUrl'] ?? 'https://via.placeholder.com/150',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[200]),
                errorWidget: (context, url, err) => Container(color: Colors.grey[200]),
              ),
            ),
            const SizedBox(width: 16),
            // تفاصيل الطلب
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          order['productName'] ?? 'Product',
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusChip(context, status, isAr),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSellerMode
                        ? '${isAr ? "المشتري" : "Buyer"}: ${order['buyerName']}'
                        : '${isAr ? "البائع" : "Seller"}: ${order['storeName']}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${order['price']} $currencySymbol',
                        style: context.textTheme.titleMedium?.copyWith(
                          color: context.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      // زر إكمال الطلب (يظهر فقط للبائع للطلبات المعلقة)
                      if (isSellerMode && isPending)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => _completeOrder(context, ref, order['id'] ?? '', order['productName'] ?? '', isAr),
                          child: Text(
                            isAr ? 'إكمال الطلب' : 'Complete Order',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status, bool isAr) {
    final isCompleted = status == 'completed';
    final text = isCompleted
        ? (isAr ? 'مكتمل' : 'Completed')
        : (isAr ? 'قيد الانتظار' : 'Pending');
    final color = isCompleted ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _completeOrder(
    BuildContext context,
    WidgetRef ref,
    String orderDocId,
    String productName,
    bool isAr,
  ) async {
    try {
      await ref.read(firestoreServiceProvider).updateOrderStatus(orderDocId, 'completed');
      if (context.mounted) {
        context.showSnackBar(
          isAr
              ? 'تم إكمال الطلب لـ "$productName" بنجاح!'
              : 'Order for "$productName" was marked completed successfully!',
        );
      }
    } catch (e) {
      if (context.mounted) {
        context.showSnackBar(
          isAr ? 'خطأ أثناء تحديث الطلب: $e' : 'Error updating order: $e',
          isError: true,
        );
      }
    }
  }
}

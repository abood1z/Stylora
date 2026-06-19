import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/services/service_providers.dart';
import '../viewmodels/admin_viewmodel.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminOrdersTab extends ConsumerWidget {
  const AdminOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(adminOrdersProvider);
    final isAr = context.locale.languageCode == 'ar';

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (orders) {
        if (orders.isEmpty) {
          return Center(
            child: Text(isAr ? 'لا توجد طلبات' : 'No orders found'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final status = order['status'] ?? 'pending';
            final createdAt = order['createdAt'] as Timestamp?;
            final timeString = createdAt != null
                ? timeago.format(createdAt.toDate(), locale: isAr ? 'ar' : 'en')
                : '';

            Color statusColor;
            switch (status) {
              case 'completed':
                statusColor = Colors.green;
                break;
              case 'cancelled':
                statusColor = Colors.red;
                break;
              case 'processing':
                statusColor = Colors.orange;
                break;
              default:
                statusColor = Colors.blue;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.2),
                  child: Icon(Icons.receipt_long_rounded, color: statusColor),
                ),
                title: Text(
                  '${isAr ? 'طلب' : 'Order'} #${order['orderId']?.toString().substring(0, 12) ?? ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${order['price']} JOD • $status',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${isAr ? 'المنتج:' : 'Product:'} ${order['productName']}',
                        ),
                        Text(
                          '${isAr ? 'المشتري:' : 'Buyer:'} ${order['buyerName']}',
                        ),
                        Text(
                          '${isAr ? 'المتجر:' : 'Store:'} ${order['storeName']}',
                        ),
                        if (timeString.isNotEmpty)
                          Text(
                            '${isAr ? 'الوقت:' : 'Time:'} $timeString',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: () async {
                                await ref
                                    .read(firestoreServiceProvider)
                                    .updateOrderStatus(
                                      order['id'],
                                      'completed',
                                    );
                              },
                              child: Text(
                                isAr ? 'إكمال' : 'Complete',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () async {
                                await ref
                                    .read(firestoreServiceProvider)
                                    .updateOrderStatus(
                                      order['id'],
                                      'cancelled',
                                    );
                              },
                              child: Text(
                                isAr ? 'إلغاء' : 'Cancel',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(
                                      isAr ? 'حذف الطلب' : 'Delete Order',
                                    ),
                                    content: Text(
                                      isAr
                                          ? 'هل أنت متأكد من حذف هذا الطلب نهائياً؟'
                                          : 'Are you sure you want to delete this order?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(isAr ? 'تراجع' : 'Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text(
                                          isAr ? 'حذف' : 'Delete',
                                          style: const TextStyle(
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref
                                      .read(firestoreServiceProvider)
                                      .deleteOrder(order['id']);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/utils/context_ext.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

class ShopProductsScreen extends ConsumerWidget {
  const ShopProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserUid = ref.watch(authServiceProvider).currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text('myProducts'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: StreamBuilder<List<ProductModel>>(
        // real-time updates for store items
        stream: ref.watch(firestoreServiceProvider).watchTraderProducts(currentUserUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return Center(child: Text('noProductsAvailable'.tr()));
          }

          final currencySymbol = ref.watch(settingsProvider).currencySymbol;
          final isMerchant = ref.watch(settingsProvider).userData?['role'] == 'merchant';
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductItem(context, ref, product, currencySymbol, isMerchant);
            },
          );
        },
      ),
    );
  }

  Widget _buildProductItem(BuildContext context, WidgetRef ref, ProductModel product, String currency, bool isMerchant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: product.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[200]),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.category,
                    style: context.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    product.storeName,
                    style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${product.price} $currency',
                    style: context.textTheme.titleMedium?.copyWith(
                      color: context.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                if (isMerchant)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final productMap = {'id': product.id, ...product.toMap()};
                        // ignore: use_build_context_synchronously
                        context.push('/edit-product', extra: productMap);
                      } else if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('تأكيد الحذف'),
                            content: const Text('هل أنت متأكد من رغبتك بحذف هذا المنتج؟'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('إلغاء'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('حذف', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(firestoreServiceProvider).deleteTraderProduct(product.id);
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('تعديل'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('حذف', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                Chip(
                   backgroundColor: context.colorScheme.primary.withValues(alpha: 0.1),
                   label: Text(product.color, style: const TextStyle(fontSize: 10)),
                ),
                if (!isMerchant)
                  const Icon(Icons.shopping_cart_outlined, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

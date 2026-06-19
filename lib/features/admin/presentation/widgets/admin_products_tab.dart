import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/services/service_providers.dart';
import '../viewmodels/admin_viewmodel.dart';

class AdminProductsTab extends ConsumerWidget {
  const AdminProductsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(adminProductsProvider);
    final isAr = context.locale.languageCode == 'ar';

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (products) {
        if (products.isEmpty) {
          return Center(child: Text(isAr ? 'لا يوجد منتجات' : 'No products found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: product.imageUrl.isNotEmpty
                        ? DecorationImage(image: CachedNetworkImageProvider(product.imageUrl), fit: BoxFit.cover)
                        : null,
                    color: Colors.grey.withOpacity(0.2),
                  ),
                  child: product.imageUrl.isEmpty ? const Icon(Icons.image_not_supported_rounded) : null,
                ),
                title: Text(product.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isAr ? 'المتجر: ${product.storeName}' : 'Store: ${product.storeName}'),
                    Text('${product.price} \$', style: TextStyle(color: context.colorScheme.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(isAr ? 'حذف المنتج' : 'Delete Product'),
                        content: Text(isAr ? 'هل أنت متأكد من حذف هذا المنتج نهائياً من المنصة؟' : 'Are you sure you want to permanently delete this product?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true), 
                            child: Text(isAr ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(firestoreServiceProvider).deleteGlobalProduct(product.id);
                      if (context.mounted) {
                        context.showSnackBar(isAr ? 'تم حذف المنتج' : 'Product deleted');
                      }
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

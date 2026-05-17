import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/utils/context_ext.dart';
import '../viewmodels/shop_viewmodel.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/providers/settings_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

// شاشة المتجر الذكي (Smart Shop Screen)
// تعرض قائمة بالمنتجات المتاحة من جميع المتاجر مع تحديثات لحظية وتصنيف ذكي
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // نمط MVVM: قراءة نموذج العرض (ViewModel)
    final viewModel = ref.watch(shopViewModelProvider);
    // الحصول على رمز العملة من الإعدادات
    final currencySymbol = ref.watch(settingsProvider).currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: Text('المتجر الذكي'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // أيقونة سلة التسوق (اختيارية)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GlassCard(
              borderRadius: 12,
              opacity: 0.1,
              child: IconButton(
                icon: const Icon(Icons.shopping_bag_outlined),
                onPressed: () {},
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              context.colorScheme.primary.withValues(alpha: 0.1),
              context.colorScheme.surface,
            ],
          ),
        ),
        // استخدام StreamBuilder للحصول على تحديثات لحظية للمنتجات
        child: StreamBuilder<List<ProductModel>>(
          stream: viewModel.availableProductsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('خطأ: ${snapshot.error}'));
            }
            final products = snapshot.data ?? [];
            if (products.isEmpty) {
              return Center(child: Text('لا توجد منتجات متاحة حالياً'.tr()));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return _buildProductItem(context, product, currencySymbol);
              },
            );
          },
        ),
      ),
    );
  }

  // بناء عنصر منتج واحد في القائمة
  Widget _buildProductItem(BuildContext context, ProductModel product, String currency) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // صورة المنتج مع تحميل ذكي (CachedNetworkImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: product.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[200]),
                errorWidget: (context, url, err) => Container(color: Colors.grey[300], child: const Icon(Icons.image)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم الفئة التابع لها المنتج
                  Text(
                    product.category.tr(),
                    style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  // اسم المتجر الموفر للمنتج (مع عرض الدولة بشكل خفي أو تلميحي)
                  Text(
                    '${product.storeName} (${product.country ?? ""})',
                    style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 8),
                  // سعر المنتج بالعملة المحلية
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
            // عرض لون المنتج المصنف بالذكاء الاصطناعي
            Column(
              children: [
                Chip(
                   backgroundColor: context.colorScheme.primary.withValues(alpha: 0.1),
                   label: Text(product.color.toLowerCase().tr(), style: const TextStyle(fontSize: 10)),
                ),
                const Icon(Icons.shopping_cart_outlined, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

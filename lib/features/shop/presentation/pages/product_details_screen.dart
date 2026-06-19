import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../core/providers/cart_provider.dart';
import '../../../../core/models/cart_item_model.dart';

class ProductDetailsScreen extends ConsumerWidget {
  final Map<String, dynamic> product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencySymbol = ref.watch(settingsProvider).currencySymbol;
    final isAr = context.locale.languageCode == 'ar';
    final user = ref.watch(authServiceProvider).currentUser;
    final cartItems = ref.watch(cartProvider);
    final isMerchant =
        ref.watch(settingsProvider).userData?['role'] == 'merchant';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GlassCard(
            borderRadius: 12,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => context.popWidget(),
            ),
          ),
        ),
        actions: [
          if (!isMerchant)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: () => context.push('/cart'),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const GlassCard(
                      borderRadius: 12,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.shopping_cart_outlined),
                      ),
                    ),
                    if (cartItems.isNotEmpty)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${cartItems.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Hero(
              tag: 'product_${product['id']}',
              child: CachedNetworkImage(
                imageUrl:
                    product['imageUrl'] ?? 'https://via.placeholder.com/500',
                height: 500,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -40),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                decoration: BoxDecoration(
                  color: context.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['brand']?.toUpperCase() ?? 'BRAND',
                                style: context.textTheme.labelLarge?.copyWith(
                                  color: context.colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                product['name'] ??
                                    product['category'] ??
                                    'Product Name',
                                style: context.textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${product['price']} $currencySymbol',
                          style: context.textTheme.headlineSmall?.copyWith(
                            color: context.colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GlassCard(
                      borderRadius: 16,
                      color: Colors.green.withValues(alpha: 0.05),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                product['matchReason'] ??
                                    (isAr
                                        ? 'يتطابق مع ملابسك المفضلة بشكل رائع.'
                                        : 'Matches your favorite items beautifully.'),
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      isAr ? 'الوصف' : 'Description',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      product['description']?.toString().isNotEmpty == true
                          ? product['description']
                          : (isAr
                                ? 'هذه القطعة الفاخرة تجمع بشكل مثالي بين الأناقة والراحة. تم اختيارها بعناية بواسطة خبير التنسيق الذكي للارتقاء بأسلوبك اليومي بلمسة راقية.'
                                : 'This premium item is a perfect blend of style and comfort. Handpicked by AI Outfitters to elevate your daily style with a sophisticated touch.'),
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        height: 1.6,
                      ),
                    ),
                    if (!isMerchant) ...[
                      const SizedBox(height: 48),
                      CustomButton(
                        onPressed: () {
                          if (user == null) {
                            context.showSnackBar(
                              isAr
                                  ? 'يرجى تسجيل الدخول أولاً'
                                  : 'Please login first',
                              isError: true,
                            );
                            return;
                          }

                          final sellerId = product['storeID'] ?? '';
                          if (sellerId == user.uid) {
                            context.showSnackBar(
                              isAr
                                  ? 'لا يمكنك شراء منتجك الخاص'
                                  : 'You cannot purchase your own product',
                              isError: true,
                            );
                            return;
                          }

                          final item = CartItemModel(
                            id: product['id'] ?? '',
                            name:
                                product['name'] ??
                                product['category'] ??
                                'Product',
                            imageUrl: product['imageUrl'] ?? '',
                            price: (product['price'] ?? 0.0).toDouble(),
                            storeID: sellerId,
                            storeName: product['storeName'] ?? 'Store',
                            quantity: 1,
                          );

                          ref.read(cartProvider.notifier).addToCart(item);
                          context.showSnackBar(
                            isAr ? 'تمت الإضافة إلى السلة' : 'Added to Cart',
                          );
                        },
                        text: isAr ? 'أضف إلى السلة' : 'Add to Cart',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

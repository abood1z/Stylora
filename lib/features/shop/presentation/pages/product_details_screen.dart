import 'package:flutter/material.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../shared/widgets/custom_button.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: GlassCard(
              borderRadius: 12,
              child: IconButton(
                icon: const Icon(Icons.favorite_border_rounded, size: 20),
                onPressed: () {},
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
                imageUrl: product['imageUrl'] ?? 'https://via.placeholder.com/500',
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
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
                              product['name'] ?? 'Product Name',
                              style: context.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        Text(
                          '\$${product['price']}',
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
                            const Icon(Icons.auto_awesome_rounded, color: Colors.green, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                product['matchReason'] ?? 'Matches your favorite items beautifully.',
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
                      'Description', 
                      style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This premium item is a perfect blend of style and comfort. Handpicked by AI Outfitters to elevate your daily style with a sophisticated touch.',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 48),
                    CustomButton(
                      onPressed: () {
                        context.showSnackBar('Successfully added to cart!');
                      },
                      text: 'Add to Cart',
                    ),
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

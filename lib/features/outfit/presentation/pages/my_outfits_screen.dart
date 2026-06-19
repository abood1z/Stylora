import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/models/outfit_model.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/utils/context_ext.dart';

class MyOutfitsScreen extends ConsumerWidget {
  const MyOutfitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    final outfitService = ref.watch(outfitGeneratorServiceProvider);

    if (user == null) {
      return Scaffold(body: Center(child: Text('pleaseLoginFirst'.tr())));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('myOutfits'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<OutfitModel>>(
        stream: outfitService.watchUserOutfits(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final outfits = snapshot.data ?? [];
          
          if (outfits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 80, color: context.colorScheme.primary.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text('noOutfitsYet'.tr(), style: context.textTheme.labelLarge),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: outfits.length,
            itemBuilder: (context, index) {
              final outfit = outfits[index];
              return _buildOutfitCard(context, outfit);
            },
          );
        },
      ),
    );
  }

  Widget _buildOutfitCard(BuildContext context, OutfitModel outfit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  outfit.name.tr(),
                  style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  DateFormat('yyyy/MM/dd').format(outfit.createdAt),
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: outfit.itemImageUrls.length,
                itemBuilder: (context, idx) {
                  return Container(
                    width: 110,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colorScheme.primary.withValues(alpha: 0.1)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: outfit.itemImageUrls[idx],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[200]),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    // مسح التنسيق منطق مستقبلي
                  },
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  label: Text('delete'.tr(), style: const TextStyle(color: Colors.redAccent)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

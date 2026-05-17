import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/utils/context_ext.dart';
import '../viewmodels/closet_viewmodel.dart';
import '../../../../core/models/closet_item_model.dart';
import '../../../../core/models/outfit_model.dart';
import '../../../../core/services/service_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

// واجهة خزانة الملابس (Closet Management Screen)
class ClosetScreen extends ConsumerStatefulWidget {
  const ClosetScreen({super.key});

  @override
  ConsumerState<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends ConsumerState<ClosetScreen> {
  int _activeTab = 0; // التبويب النشط (0 للملابس، 1 للتنسيقات)

  @override
  Widget build(BuildContext context) {
    // مراقبة موديل الحالة والخدمات
    final viewModel = ref.watch(closetViewModelProvider);
    final user = ref.watch(authStateProvider).value;
    final outfitService = ref.watch(outfitGeneratorServiceProvider);

    // التأكد من تسجيل دخول المستخدم قبل عرض المحتوى
    if (user == null) {
      return Scaffold(body: Center(child: Text('Please login first'.tr())));
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _buildTabToggle(context), // بناء زر التبديل بين الملابس والتنسيقات
        actions: [
          IconButton(
            onPressed: () => context.push('/virtual-try-on'),
            icon: Icon(Icons.accessibility_new_rounded, color: context.colorScheme.primary),
            tooltip: 'Virtual Try-On',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        width: double.infinity,
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
        child: Column(
          children: [
            if (_activeTab == 0) ...[
              // عرض محتوى الملابس
              _buildFiltersBar(context, viewModel),
              const SizedBox(height: 8),
              Expanded(child: _buildClothesGrid(context, viewModel)),
            ] else ...[
              // عرض محتوى التنسيقات
              const SizedBox(height: 16),
              Expanded(child: _buildOutfitsList(context, user.uid, outfitService)),
            ],
          ],
        ),
      ),
      // زر المسح الذكي للملابس بالكاميرا
      floatingActionButton: _activeTab == 0 ? FloatingActionButton.extended(
        heroTag: 'closet_scan_fab',
        onPressed: () {
          GoRouter.of(context).push('/ai_suggestions');
        },
        icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
        label: Text(
          'scanClothes'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white),
        ),
        backgroundColor: context.colorScheme.primary,
        elevation: 8,
      ) : null,
    );
  }

  // بناء أزرار التبديل العلوية (Tab Toggle)
  Widget _buildTabToggle(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          _toggleButton(context, index: 0, label: 'ملابسي'.tr(), icon: Icons.checkroom_rounded),
          _toggleButton(context, index: 1, label: 'تنسيقاتي'.tr(), icon: Icons.auto_awesome_rounded),
        ],
      ),
    );
  }

  // الزر الفردي المستخدم داخل شريط التبديل
  Widget _toggleButton(BuildContext context, {required int index, required String label, required IconData icon}) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? context.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            boxShadow: isSelected ? [
              BoxShadow(color: context.colorScheme.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))
            ] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : context.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : context.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // بناء واجهة عرض الملابس كشبكة (Grid)
  Widget _buildClothesGrid(BuildContext context, ClosetViewModel viewModel) {
    return StreamBuilder<List<ClosetItemModel>>(
      stream: viewModel.userClosetStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(child: Text('لا يوجد ملابس بهذه المواصفات'.tr()));
        }
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildItemCard(context, items[index], viewModel),
        );
      },
    );
  }

  // بناء قائمة التنسيقات (Outfits List)
  Widget _buildOutfitsList(BuildContext context, String uid, var outfitService) {
    return StreamBuilder<List<OutfitModel>>(
      stream: outfitService.watchUserOutfits(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final outfits = snapshot.data ?? [];
        if (outfits.isEmpty) {
          return Center(child: Text('لا توجد تنسيقات بعد'.tr()));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: outfits.length,
          itemBuilder: (context, index) => _buildOutfitCard(context, outfits[index]),
        );
      },
    );
  }

  // بناء بطاقة العرض لكل طقم من الملابس
  Widget _buildOutfitCard(BuildContext context, OutfitModel outfit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(outfit.name.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.blue),
              ],
            ),
            const SizedBox(height: 16),
            // عرض صور القطع المكونة للطقم بشكل أفقي
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: outfit.itemImageUrls.length,
                itemBuilder: (context, idx) {
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colorScheme.primary.withValues(alpha: 0.1)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(imageUrl: outfit.itemImageUrls[idx], fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // بناء بطاقة القطعة الفردية في الخزانة مع خيار الحذف
  Widget _buildItemCard(BuildContext context, ClosetItemModel item, ClosetViewModel viewModel) {
     return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[100]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.category.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(item.color.tr(), style: TextStyle(color: context.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  onPressed: () => _showDeleteDialog(context, item, viewModel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // إظهار نافذة تأكيد الحذف لقطع الملابس
  void _showDeleteDialog(BuildContext context, ClosetItemModel item, ClosetViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف من الخزانة'.tr()),
        content: Text('هل أنت متأكد من حذف هذه القطعة؟'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('الغاء'.tr())),
          TextButton(
            onPressed: () {
              viewModel.deleteItem(item.id);
              Navigator.pop(context);
            },
            child: Text('حذف'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // شريط الفلاتر (الأصناف) العلوية
  Widget _buildFiltersBar(BuildContext context, ClosetViewModel viewModel) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _filterChip(context, 'الكل', viewModel.selectedCategory == null, () => viewModel.filterByCategory(null)),
          const SizedBox(width: 8),
          _filterChip(context, 'علوي', viewModel.selectedCategory == 'top', () => viewModel.filterByCategory('top')),
          const SizedBox(width: 8),
          _filterChip(context, 'سفلي', viewModel.selectedCategory == 'bottom', () => viewModel.filterByCategory('bottom')),
          const SizedBox(width: 8),
          _filterChip(context, 'أحذية', viewModel.selectedCategory == 'shoes', () => viewModel.filterByCategory('shoes')),
        ],
      ),
    );
  }

  // كائن الفلتر الفردي (Chip)
  Widget _filterChip(BuildContext context, String label, bool isSelected, VoidCallback onTap) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label.tr()),
      backgroundColor: isSelected ? context.colorScheme.primary : context.colorScheme.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : context.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
    );
  }
}

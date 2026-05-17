import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/utils/context_ext.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/models/closet_item_model.dart';
import 'package:google_fonts/google_fonts.dart';

// شاشة نتائج البحث (Search Results Screen)
// تعرض نتائج البحث مقسمة إلى تبويبين: المتجر (Store) والخزانة الخاصة (Closet)
class SearchResultsScreen extends ConsumerStatefulWidget {
  final String query; // نص البحث المرسل من الشاشة السابقة
  const SearchResultsScreen({super.key, required this.query});

  @override
  ConsumerState<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController = TextEditingController(text: widget.query);
    // تحديث الحالة عند تغيير نص البحث لإعادة تشغيل الـ FutureBuilder
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // الحصول على معرف المستخدم واستدعاء دالة البحث من FirestoreService
    final uid = ref.watch(authServiceProvider).currentUser?.uid ?? '';
    final searchFuture = ref.watch(firestoreServiceProvider).searchStoreAndCloset(uid, _searchController.text);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              context.colorScheme.surface,
              context.colorScheme.primary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context), // شريط البحث العلوي
              _buildTabBar(context), // التبويبات (متجر / خزانة)
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<Map<String, List<dynamic>>>(
                  future: searchFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'خطأ: ${snapshot.error}',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      );
                    }
                    
                    // استخراج النتائج لكل قسم
                    final storeResults = snapshot.data?['store'] as List<ProductModel>? ?? [];
                    final closetResults = snapshot.data?['closet'] as List<ClosetItemModel>? ?? [];

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildResultsGrid(context, storeResults, isStore: true),
                        _buildResultsGrid(context, closetResults, isStore: false),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // بناء رأس الصفحة مع حقل البحث
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Hero(
              tag: 'search_bar',
              child: GlassCard(
                borderRadius: 20,
                opacity: 0.08,
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'searchHint'.tr(),
                    hintStyle: TextStyle(color: context.colorScheme.onSurface.withValues(alpha: 0.3)),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search_rounded, color: context.colorScheme.primary),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onSubmitted: (v) {
                    if (v.isNotEmpty) setState(() {});
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // بناء شريط التبويبات
  Widget _buildTabBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TabBar(
        controller: _tabController,
        indicatorColor: context.colorScheme.primary,
        indicatorWeight: 3,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: context.colorScheme.primary,
        unselectedLabelColor: context.colorScheme.onSurface.withValues(alpha: 0.4),
        labelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w900, fontSize: 16),
        unselectedLabelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w500, fontSize: 15),
        tabs: [
          Tab(text: 'store'.tr()),
          Tab(text: 'closet'.tr()),
        ],
      ),
    );
  }

  // بناء شبكة عرض النتائج (Store or Closet Grid)
  Widget _buildResultsGrid(BuildContext context, List<dynamic> items, {required bool isStore}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded, 
              size: 80, 
              color: context.colorScheme.onSurface.withValues(alpha: 0.05)
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد نتائج بحث'.tr(), 
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold, 
                fontSize: 18,
                color: context.colorScheme.onSurface.withValues(alpha: 0.3)
              )
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final String imageUrl = isStore ? (item as ProductModel).imageUrl : (item as ClosetItemModel).imageUrl;
        final String title = isStore ? (item as ProductModel).category.tr() : (item as ClosetItemModel).category.tr();
        final String subtitle = isStore ? '${(item as ProductModel).price} \$' : (item as ClosetItemModel).color.tr();
        final String season = isStore ? (item as ProductModel).season : (item as ClosetItemModel).season;

        return GlassCard(
          borderRadius: 24,
          opacity: 0.04,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    // عرض صورة المنتج/القطعة
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.white12),
                        ),
                      ),
                    ),
                    // علامة الموسم (صيفي/شتوي)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          season == 'summer' ? 'صيفي' : 'شتوي',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title, 
                      style: GoogleFonts.tajawal(fontWeight: FontWeight.w900, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isStore ? context.colorScheme.primary : context.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

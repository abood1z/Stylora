import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:camera/camera.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/glass_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../core/services/data_providers.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/models/closet_item_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// واجهة الصفحة الرئيسية للتطبيق (Home Screen)
// تعرض ملخصاً لنشاط المستخدم، اقتراحات الذكاء الاصطناعي، والبحث الذكي
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: CustomScrollView(
        // فيزياء التمرير المرنة لجعل الواجهة أكثر حيوية
        physics: const BouncingScrollPhysics(),
        slivers: [
          // شريط التطبيق العلوي المتفاعل (SliverAppBar)
          SliverAppBar(
            expandedHeight: 120, // الارتفاع عند التمدد الكامل
            floating: true, // يظهر بمجرد البدء بالتمرير لأسفل
            pinned: true, // يبقى الجزء العلوي ثابتاً (العنوان والأيقونات) عند التمرير
            backgroundColor: context.colorScheme.surface.withValues(alpha: 0.8),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              title: Text(
                'STYLORA',
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: context.colorScheme.primary,
                ),
              ),
              centerTitle: false,
            ),
            actions: [
              // زر الإشعارات بتصميم زجاجي عصري
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: GlassCard(
                  borderRadius: 12,
                  opacity: 0.1,
                  child: IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: () {},
                  ),
                ),
              ),
            ],
          ),
          // محتوى الصفحة الرئيسي المكون من أقسام متعددة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // شريط البحث المطور الذي يدعم الاقتراحات اللحظية
                  _buildSearchBar(context, ref),
                  const SizedBox(height: 32),
                  
                  // بطاقة رؤى الذكاء الاصطناعي (تظهر للعملاء فقط لتخصيص التجربة)
                  if (ref.read(settingsProvider).userData?['role'] != 'merchant') ...[
                    _buildAIInsightsCard(context),
                    const SizedBox(height: 32),
                  ],
                  
                  // قسم الإطلالات اليومية الموصى بها
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'dailyLook'.tr().toUpperCase(),
                        style: context.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'viewAll'.tr(),
                          style: TextStyle(
                            color: context.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // عرض قائمة الإطلالات باستخدام Riverpod للتعامل مع الحالات (بيانات/تحميل/خطأ)
                  ref.watch(dailyLooksProvider).when(
                        data: (looks) => _buildDailyLookList(context, looks),
                        loading: () => _buildDailyLookList(context, []), // العرض الأولي باستخدام Skeleton loading
                        error: (e, st) => Center(child: Text('خطأ في تحميل المظاهر: $e')),
                      ),
                  const SizedBox(height: 100), // مساحة أضافية لضمان عدم تداخل المحتوى مع شريط التنقل السفلي
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // بناء شريط البحث باستخدام SearchAnchor لتوفير تجربة بحث متقدمة
  Widget _buildSearchBar(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'discover'.tr().toUpperCase(),
          style: context.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: context.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),
        Hero(
          tag: 'search_bar',
          child: SearchAnchor(
            builder: (context, controller) {
              return GlassCard(
                borderRadius: 24,
                opacity: 0.05,
                child: InkWell(
                  onTap: () => controller.openView(), // فتح واجهة البحث الكاملة
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: context.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'searchHint'.tr(),
                            style: TextStyle(color: context.colorScheme.onSurface.withValues(alpha: 0.3)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // أيقونة التصفية المخصصة
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.tune_rounded, size: 18, color: context.colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            searchController: SearchController(),
            viewBackgroundColor: context.colorScheme.surface,
            viewElevation: 0,
            // منشئ الاقتراحات - يقوم بالبحث المتزامن في Firestore
            suggestionsBuilder: (context, controller) async {
              if (controller.text.isEmpty) return [];
              
              final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
              // استعلام مزدوج للبحث في "المتجر" و "الخزانة الرقمية" للمستخدم في نفس الوقت
              final results = await ref.read(firestoreServiceProvider).searchStoreAndCloset(uid, controller.text);
              final storeResults = results['store'] as List<ProductModel>;
              final closetResults = results['closet'] as List<ClosetItemModel>;

              return [
                // عرض نتائج الخزانة أولاً لتشجيع المستخدم على استغلال ملابسه الحالية
                if (closetResults.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('yourCloset'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ...closetResults.map((item) => ListTile(
                        leading: CircleAvatar(backgroundImage: CachedNetworkImageProvider(item.imageUrl)),
                        title: Text(item.category.tr()),
                        subtitle: Text(item.color.tr()),
                        onTap: () => context.push('/search?q=${controller.text}'),
                      )),
                ],
                // عرض نتائج المتجر لاقتراح قطع تكميلية للشرء
                if (storeResults.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('shopLabel'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ...storeResults.map((item) => ListTile(
                        leading: CircleAvatar(backgroundImage: CachedNetworkImageProvider(item.imageUrl)),
                        title: Text(item.category.tr()),
                        subtitle: Text('${item.price} \$'),
                        onTap: () => context.push('/search?q=${controller.text}'),
                      )),
                ],
              ];
            },
          ),
        ),
      ],
    );
  }

  // بطاقة رؤى الذكاء الاصطناعي (AI Insights) بتصميم زجاجي جذاب
  Widget _buildAIInsightsCard(BuildContext context) {
    return GlassCard(
      borderRadius: 32,
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: context.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'smartRecommendations'.tr(),
                  style: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'smartRecommendationsDesc'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final cameras = await availableCameras();
                  if (context.mounted) {
                    context.push('/live-try-on', extra: cameras);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colorScheme.primary,
                  foregroundColor: context.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.videocam_rounded),
                label: Text('liveTryOnNow'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // بناء قائمة الإطلالات اليومية مع دعم التحميل المتدرج وعرض درجات التوافق
  Widget _buildDailyLookList(BuildContext context, List<Map<String, dynamic>> looks) {
    if (looks.isEmpty) {
      // إظهار نماذج تحميل وهمية (Shimmer) كـ Placeholder لضمان استمرارية تجربة المستخدم
      return Column(
        children: List.generate(3, (index) => const Padding(
          padding: EdgeInsets.only(bottom: 24),
          child: ShimmerLoading(height: 380, width: double.infinity),
        )),
      );
    }

    return ListView.builder(
      shrinkWrap: true, // مهم جداً لاستخدام ListView داخل CustomScrollView
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(), // لتمكين التمرير من خلال الـ CustomScrollView الأب
      itemCount: looks.length,
      itemBuilder: (context, index) {
        final look = looks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: GlassCard(
            borderRadius: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // صورة الإطلالة مع درجة التوافق المحسوبة ذكياً
                Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: look['imageUrl'],
                      height: 300,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const ShimmerLoading(
                        height: 300,
                        width: double.infinity,
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 300,
                        color: context.colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.broken_image_rounded, color: context.colorScheme.primary, size: 40),
                      ),
                    ),
                    // مؤشر درجة التوافق (Match Score) في الزاوية
                    Positioned(
                      top: 16,
                      right: 16,
                      child: GlassCard(
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${look['matchScore']}%',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // البيانات الوصفية للإطلالة والتفاعلات الاجتماعية
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              look['title'],
                              style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'outfitDescription'.tr(),
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // زر الإعجاب لحفظ الإطلالات المفضلة
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.favorite_border_rounded),
                        color: context.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

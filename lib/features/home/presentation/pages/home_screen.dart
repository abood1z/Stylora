import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../core/services/data_providers.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/models/closet_item_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/weather_service.dart';
import '../../../../core/providers/notification_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../shared/widgets/custom_button.dart';

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
            floating: true,
            pinned: false, // يختفي عند التمرير لأسفل لزيادة مساحة الشاشة
            backgroundColor: context.colorScheme.surface.withValues(alpha: 0.9),
            elevation: 0,
            title: Text(
              'Stylora',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: context.colorScheme.primary,
                letterSpacing: 1.2,
                fontSize: 24,
              ),
            ),
            actions: [
              // زر الإشعارات بتصميم زجاجي عصري
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GlassCard(
                  borderRadius: 12,
                  opacity: 0.1,
                  child: IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: () {
                      _showNotificationsSheet(context);
                    },
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(80),
              child: Padding(
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 16.0),
                child: _buildSearchBar(context, ref),
              ),
            ),
          ),
          // محتوى الصفحة الرئيسي المكون من أقسام متعددة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3. تنسيق اليوم حسب الطقس (Weather suggestion widget)
                  _buildWeatherWidget(context, ref),
                  const SizedBox(height: 24),

                  // 4. لوحة تحليلات الخزانة الرقمية (Closet Analytics)
                  _buildClosetAnalytics(context, ref),
                  const SizedBox(height: 24),

                  // 7. شبكة أكمل إطلالتك (Complete Your Look)
                  _buildShoppableGrid(context, ref),

                  const SizedBox(
                    height: 100,
                  ), // مساحة إضافية لضمان عدم تداخل المحتوى مع شريط التنقل السفلي
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
    return Hero(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: context.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'searchHint'.tr(),
                        style: TextStyle(
                          color: context.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // أيقونة التصفية المخصصة
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: context.colorScheme.primary,
                      ),
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
          final results = await ref
              .read(firestoreServiceProvider)
              .searchStoreAndCloset(uid, controller.text);
          final storeResults = results['store'] as List<ProductModel>;
          final closetResults = results['closet'] as List<ClosetItemModel>;

          return [
            // عرض نتائج الخزانة أولاً لتشجيع المستخدم على استغلال ملابسه الحالية
            if (closetResults.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'yourCloset'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...closetResults.map(
                (item) => ListTile(
                  leading: CircleAvatar(
                    backgroundImage: CachedNetworkImageProvider(
                      item.imageUrl,
                    ),
                  ),
                  title: Text(item.category.tr()),
                  subtitle: Text(item.color.tr()),
                  onTap: () => context.push('/search?q=${controller.text}'),
                ),
              ),
            ],
            // عرض نتائج المتجر لاقتراح قطع تكميلية للشرء
            if (storeResults.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'shopLabel'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...storeResults.map(
                (item) => ListTile(
                  leading: CircleAvatar(
                    backgroundImage: CachedNetworkImageProvider(
                      item.imageUrl,
                    ),
                  ),
                  title: Text(item.category.tr()),
                  subtitle: Text('${item.price} \$'),
                  onTap: () => context.push('/search?q=${controller.text}'),
                ),
              ),
            ],
          ];
        },
      ),
    );
  }

  // بناء ودجت الطقس وتنسيق اليوم
  Widget _buildWeatherWidget(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    final city = settings.city ?? 'riyadh'.tr();
    final country = settings.country ?? 'saudiArabia'.tr();

    final weatherAsync = ref.watch(weatherProvider(city));
    final closetAsync = ref.watch(userFullClosetProvider);

    return weatherAsync.when(
      loading: () => const ShimmerLoading(height: 180, width: double.infinity),
      error: (err, stack) => _buildWeatherContent(
        context,
        ref,
        city,
        country,
        _getFallbackWeather(city, EasyLocalization.of(context)?.currentLocale?.languageCode == 'ar'),
        closetAsync.value ?? [],
      ),
      data: (weatherInfo) => _buildWeatherContent(
        context,
        ref,
        city,
        country,
        weatherInfo,
        closetAsync.value ?? [],
      ),
    );
  }

  Widget _buildWeatherContent(
    BuildContext context,
    WidgetRef ref,
    String city,
    String country,
    WeatherInfo weather,
    List<ClosetItemModel> closetItems,
  ) {
    final isAr =
        EasyLocalization.of(context)?.currentLocale?.languageCode == 'ar';
    final temp = weather.temp;
    final weatherCondition = weather.conditionKey.tr();
    final weatherIcon = weather.icon;

    String weatherRecommendation = '';

    final seed = ref.watch(weatherRecommendationSeedProvider);
    final recommendedItems = _getRecommendedItemsFromCloset(closetItems, temp, seed);
    final recItem1 = recommendedItems[0];
    final recItem2 = recommendedItems[1];

    if (temp > 30) {
      weatherRecommendation = 'weatherRecommendationHot'.tr();
    } else if (temp < 18) {
      weatherRecommendation = 'weatherRecommendationCold'.tr();
    } else {
      weatherRecommendation = 'weatherRecommendationMild'.tr();
    }

    if (closetItems.isEmpty) {
      weatherRecommendation += 'weatherRecommendationNoItems'.tr();
    } else if (recItem1 == null && recItem2 == null) {
      weatherRecommendation += 'weatherRecommendationNoSuitable'.tr();
    }

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(weatherIcon, color: Colors.amber, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'todayWeatherOutfit'.tr(),
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'weatherDetailsFormat'.tr(args: [city, country, weatherCondition, temp.toString()]),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // زر التحديث لتغيير الاقتراحات
              IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: context.colorScheme.primary,
                  size: 20,
                ),
                onPressed: () {
                  Future.delayed(const Duration(milliseconds: 150), () {
                    ref.invalidate(weatherProvider(city)); // تحديث الحرارة
                  });
                  ref.read(weatherRecommendationSeedProvider.notifier).state++; // تحديث الملابس
                },
                tooltip: 'refreshOutfit'.tr(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            weatherRecommendation,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurface,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          // عرض القطع المقترحة فقط في حال وجودها
          if (recItem1 != null || recItem2 != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (recItem1 != null) _buildSimpleItemAvatar(recItem1.imageUrl, recItem1.category.tr()),
                if (recItem1 != null && recItem2 != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Icon(
                      Icons.add_rounded,
                      color: context.colorScheme.onSurface.withValues(alpha: 0.3),
                      size: 20,
                    ),
                  ),
                if (recItem2 != null) _buildSimpleItemAvatar(recItem2.imageUrl, recItem2.category.tr()),
              ],
            ),
            const SizedBox(height: 16),
          ],
          // 🚀 زر تجربة الإطلالة الافتراضية الآن (تم توحيده وتصميمه باستخدام CustomButton المشترك ليتناسق بالكامل مع باقي الأزرار)
          CustomButton(
            onPressed: () {
              context.push('/virtual-try-on');
            },
            text: 'tryVirtualOutfitNow'.tr(),
            icon: Icons.checkroom_rounded,
          ),
        ],
      ),
    );
  }

  List<ClosetItemModel?> _getRecommendedItemsFromCloset(
    List<ClosetItemModel> closetItems,
    int temp,
    int seed,
  ) {
    if (closetItems.isEmpty) return [null, null];

    ClosetItemModel? top;
    ClosetItemModel? bottom;

    final daySeed = DateTime.now().year * 1000 + DateTime.now().month * 100 + DateTime.now().day + seed;
    final rand = math.Random(daySeed);
    final items = closetItems.toList()..shuffle(rand);

    if (temp > 30) {
      for (var item in items) {
        final cat = item.category.toLowerCase();
        if (top == null && (cat.contains('top') || cat.contains('shirt') || cat.contains('polo') || cat.contains('علوي') || cat.contains('قميص') || cat.contains('تي شيرت') || cat.contains('تيشرت'))) {
          top = item;
        }
        if (bottom == null && (cat.contains('short') || cat.contains('skirt') || cat.contains('سفلي') || cat.contains('شورت') || cat.contains('تنورة'))) {
          bottom = item;
        }
      }
    } else if (temp < 18) {
      for (var item in items) {
        final cat = item.category.toLowerCase();
        if (top == null && (cat.contains('jacket') || cat.contains('hoodie') || cat.contains('coat') || cat.contains('sweater') || cat.contains('معطف') || cat.contains('جاكيت') || cat.contains('سويتر') || cat.contains('هودي'))) {
          top = item;
        }
        if (bottom == null && (cat.contains('pant') || cat.contains('jean') || cat.contains('trouser') || cat.contains('جينز') || cat.contains('بنطال'))) {
          bottom = item;
        }
      }
    } else {
      for (var item in items) {
        final cat = item.category.toLowerCase();
        if (top == null && (cat.contains('shirt') || cat.contains('blazer') || cat.contains('jacket') || cat.contains('top') || cat.contains('علوي') || cat.contains('قميص') || cat.contains('جاكيت'))) {
          top = item;
        }
        if (bottom == null && (cat.contains('pant') || cat.contains('jean') || cat.contains('trouser') || cat.contains('جينز') || cat.contains('بنطال'))) {
          bottom = item;
        }
      }
    }

    return [top, bottom];
  }

  WeatherInfo _getFallbackWeather(String city, bool isAr) {
    final cityLower = city.toLowerCase();
    int temp = 24;
    String conditionKey = 'mild';
    IconData icon = Icons.wb_cloudy_rounded;

    if (cityLower.contains('riyadh') ||
        cityLower.contains('رياض') ||
        cityLower.contains('dubai') ||
        cityLower.contains('دبي') ||
        cityLower.contains('cairo') ||
        cityLower.contains('قاهرة') ||
        cityLower.contains('jeddah') ||
        cityLower.contains('جدة')) {
      temp = 36;
      conditionKey = 'sunnyHot';
      icon = Icons.wb_sunny_rounded;
    } else if (cityLower.contains('london') ||
        cityLower.contains('لندن') ||
        cityLower.contains('paris') ||
        cityLower.contains('باريس') ||
        cityLower.contains('moscow') ||
        cityLower.contains('موسكو')) {
      temp = 14;
      conditionKey = 'chillyRainy';
      icon = Icons.thunderstorm_rounded;
    } else {
      temp = 24;
      conditionKey = 'partlyCloudy';
      icon = Icons.cloud_queue_rounded;
    }

    return WeatherInfo(
      temp: temp,
      conditionKey: conditionKey,
      icon: icon,
    );
  }

  Widget _buildSimpleItemAvatar(String imageUrl, String label) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
            image: DecorationImage(
              image: CachedNetworkImageProvider(imageUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isAr =
            EasyLocalization.of(context)?.currentLocale?.languageCode == 'ar';
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'notifications'.tr(),
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final notificationsAsync = ref.watch(
                      userNotificationsProvider,
                    );

                    return notificationsAsync.when(
                      data: (notifications) {
                        if (notifications.isEmpty) {
                          return Center(
                            child: Text(
                              'noNotificationsYet'.tr(),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final note = notifications[index];
                            IconData icon;
                            Color color;

                            switch (note.type) {
                              case 'order':
                                icon = Icons.local_shipping_outlined;
                                color = Colors.green;
                                break;
                              case 'system':
                                icon = Icons.info_outline_rounded;
                                color = Colors.blue;
                                break;
                              case 'weather':
                                icon = Icons.wb_sunny_outlined;
                                color = Colors.amber;
                                break;
                              default:
                                icon = Icons.notifications_active_outlined;
                                color = context.colorScheme.primary;
                            }

                            return _buildNotificationTile(
                              context,
                              isAr ? note.titleAr : note.titleEn,
                              isAr ? note.bodyAr : note.bodyEn,
                              icon,
                              color,
                              timeago.format(
                                note.createdAt,
                                locale: isAr ? 'ar' : 'en',
                              ),
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err')),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    String title,
    String body,
    IconData icon,
    Color color,
    String time,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(body, style: context.textTheme.bodySmall),
      trailing: Text(
        time,
        style: context.textTheme.labelSmall?.copyWith(color: Colors.grey),
      ),
      onTap: () {},
    );
  }

  // بناء لوحة تحليلات الخزانة الرقمية
  Widget _buildClosetAnalytics(BuildContext context, WidgetRef ref) {
    final isAr =
        EasyLocalization.of(context)?.currentLocale?.languageCode == 'ar';
    final closetAsync = ref.watch(userFullClosetProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'closetAnalytics'.tr().toUpperCase(),
          style: context.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: context.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),
        closetAsync.when(
          data: (items) {
            final totalItems = items.length;
            final usagePercent = totalItems == 0
                ? 0
                : (25 + (totalItems * 3) % 40);

            // حساب الألوان الأكثر تكراراً
            final colorCounts = <String, int>{};
            for (var item in items) {
              final color = item.color.toLowerCase().trim();
              if (color.isNotEmpty) {
                colorCounts[color] = (colorCounts[color] ?? 0) + 1;
              }
            }
            final sortedColors = colorCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final topColors = sortedColors.take(3).map((e) => e.key).toList();

            // حساب الفئة الأكثر تكراراً
            final categoryCounts = <String, int>{};
            for (var item in items) {
              final cat = item.category;
              if (cat.isNotEmpty) {
                categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
              }
            }
            final sortedCategories = categoryCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final topCategoryName = sortedCategories.isNotEmpty
                ? sortedCategories.first.key.tr()
                : 'none'.tr();

            // تحديد نصيحة مخصصة
            String aiTip = '';
            if (totalItems == 0) {
              aiTip = 'closetEmptyTip'.tr();
            } else {
              final recommendedItem = items[totalItems % items.length];
              final catName = recommendedItem.category.tr();
              final colorName = recommendedItem.color.tr();
              aiTip = 'closetAiTipFormat'.tr(args: [colorName, catName]);
            }

            return GlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      // مؤشر دائري لنسبة الاستخدام
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 70,
                            height: 70,
                            child: CircularProgressIndicator(
                              value: usagePercent / 100.0,
                              strokeWidth: 8,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                ref.context.colorScheme.primary,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$usagePercent%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'used'.tr(),
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      // معلومات الألوان والفئات الأكثر ارتداءً
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'thisMonthsWardrobe'.tr(),
                              style: context.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'favoriteColorsCloset'.tr(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (topColors.isEmpty) ...[
                                  _buildColorIndicator(Colors.black),
                                  const SizedBox(width: 6),
                                  _buildColorIndicator(Colors.blue),
                                  const SizedBox(width: 6),
                                  _buildColorIndicator(
                                    Colors.white,
                                    hasBorder: true,
                                  ),
                                ] else ...[
                                  ...topColors.map(
                                    (colorStr) => Padding(
                                      padding: const EdgeInsets.only(left: 6.0),
                                      child: _buildColorIndicator(
                                        _mapStringToColor(colorStr),
                                        hasBorder:
                                            colorStr.toLowerCase().contains(
                                              'white',
                                            ) ||
                                            colorStr.toLowerCase().contains(
                                              'white'.tr(),
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'topCategoryLabel'.tr(args: [topCategoryName]),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 12),
                  // نصيحة الذكاء الاصطناعي
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: context.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          aiTip,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () =>
              const ShimmerLoading(height: 180, width: double.infinity),
          error: (e, st) => Center(
            child: Text(
              isAr ? 'خطأ في تحميل التحليلات' : 'Error loading analytics',
            ),
          ),
        ),
      ],
    );
  }

  // تحويل اسم اللون النصي إلى كائن Color
  Color _mapStringToColor(String colorName) {
    final name = colorName.toLowerCase().trim();
    if (name.contains('أسود') || name.contains('black')) return Colors.black;
    if (name.contains('أبيض') || name.contains('white')) return Colors.white;
    if (name.contains('أزرق') || name.contains('blue')) return Colors.blue;
    if (name.contains('رمادي') ||
        name.contains('grey') ||
        name.contains('gray')) {
      return Colors.grey;
    }
    if (name.contains('أحمر') || name.contains('red')) return Colors.red;
    if (name.contains('أخضر') || name.contains('green')) return Colors.green;
    if (name.contains('أصفر') || name.contains('yellow')) return Colors.yellow;
    if (name.contains('بني') || name.contains('brown')) return Colors.brown;
    if (name.contains('وردي') || name.contains('pink')) return Colors.pink;
    if (name.contains('برتقالي') || name.contains('orange')) {
      return Colors.orange;
    }
    if (name.contains('بنفسجي') || name.contains('purple')) {
      return Colors.purple;
    }
    return Colors.blueGrey;
  }

  Widget _buildColorIndicator(Color color, {bool hasBorder = false}) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: hasBorder ? Border.all(color: Colors.white30, width: 1) : null,
      ),
    );
  }

  // شبكة أكمل إطلالتك
  Widget _buildShoppableGrid(BuildContext context, WidgetRef ref) {
    final isAr =
        EasyLocalization.of(context)?.currentLocale?.languageCode == 'ar';
    final productsAsync = ref.watch(productsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              (isAr ? 'أكمل إطلالتك' : 'Complete Your Look').toUpperCase(),
              style: context.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: context.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            TextButton(
              onPressed: () {
                context.go('/shop');
              },
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
        const SizedBox(height: 8),
        productsAsync.when(
          data: (products) {
            // نأخذ أول 4 منتجات لعرضها في شبكة 2x2
            final displayProducts = products.take(4).toList();

            if (displayProducts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    isAr
                        ? 'لا توجد قطع مقترحة حالياً'
                        : 'No recommendations available',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 245,
              ),
              itemCount: displayProducts.length,
              itemBuilder: (context, index) {
                final product = displayProducts[index];

                // حساب نسبة توافق وهمية بناءً على المعرف للحفاظ على التناسق البصري
                final matchScore = 90 + (product.id.hashCode % 9);

                return GlassCard(
                  borderRadius: 20,
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // صورة المنتج مع نسبة التوافق
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: product.imageUrl,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  const ShimmerLoading(
                                    height: 140,
                                    width: double.infinity,
                                  ),
                              errorWidget: (context, url, error) => Container(
                                height: 140,
                                color:
                                    context.colorScheme.surfaceContainerHighest,
                                child: const Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.flash_on_rounded,
                                    color: Colors.amber,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$matchScore%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // تفاصيل المنتج
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.category.tr(),
                              style: context.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              product.storeName,
                              style: TextStyle(
                                fontSize: 9,
                                color: context.colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${product.price} \$',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: context.colorScheme.primary,
                                    fontSize: 13,
                                  ),
                                ),
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: context.colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      Icons.add_shopping_cart_rounded,
                                      size: 14,
                                      color: context.colorScheme.primary,
                                    ),
                                    onPressed: () {
                                      // إضافة للمشتريات
                                    },
                                  ),
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) =>
              Center(child: Text('خطأ في تحميل المنتجات المقترحة: $e')),
        ),
      ],
    );
  }
}

// نافذة عرض قصص الأناقة التفاعلية بتصميم إنستجرام
class StoryViewerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;

  const StoryViewerDialog({
    super.key,
    required this.stories,
    required this.initialIndex,
  });

  @override
  State<StoryViewerDialog> createState() => _StoryViewerDialogState();
}

class _StoryViewerDialogState extends State<StoryViewerDialog>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animController.reset();
        if (_currentIndex + 1 < widget.stories.length) {
          setState(() {
            _currentIndex++;
          });
          _pageController.animateToPage(
            _currentIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          _animController.forward();
        } else {
          Navigator.of(context).pop();
        }
      }
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    final double width = MediaQuery.of(context).size.width;
    final double dx = details.globalPosition.dx;

    if (dx < width / 3) {
      // الضغط في الثلث الأيسر للرجوع للقصة السابقة
      if (_currentIndex > 0) {
        _animController.reset();
        setState(() {
          _currentIndex--;
        });
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _animController.forward();
      }
    } else {
      // الضغط في الجانب الأيمن للانتقال للقصة التالية
      _animController.reset();
      if (_currentIndex + 1 < widget.stories.length) {
        setState(() {
          _currentIndex++;
        });
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _animController.forward();
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  String _getStoryTitleKey(String title) {
    final t = title.toLowerCase().replaceAll(' ', '');
    if (t.contains('casualfriday') || t.contains('عطلةالجمعة')) return 'storyTitle_casualFriday';
    if (t.contains('officesetup') || t.contains('أناقةالعمل')) return 'storyTitle_officeSetup';
    if (t.contains('weekendvibe') || t.contains('أجواءالعطف') || t.contains('أجواءالعطلة')) return 'storyTitle_weekendVibe';
    if (t.contains('casual') || t.contains('كاجوال')) return 'storyTitle_casual';
    if (t.contains('formal') || t.contains('رسمي')) return 'storyTitle_formal';
    if (t.contains('sporty') || t.contains('رياضي')) return 'storyTitle_sporty';
    if (t.contains('evening') || t.contains('سهرة')) return 'storyTitle_evening';
    if (t.contains('autumn') || t.contains('خريفي')) return 'storyTitle_autumn';
    return title;
  }

  String _getStoryTipKey(String title) {
    final t = title.toLowerCase().replaceAll(' ', '');
    if (t.contains('casualfriday') || t.contains('عطلةالجمعة')) return 'storyTip_casualFriday';
    if (t.contains('officesetup') || t.contains('أناقةالعمل')) return 'storyTip_officeSetup';
    if (t.contains('weekendvibe') || t.contains('أجواءالعطف') || t.contains('أجواءالعطلة')) return 'storyTip_weekendVibe';
    if (t.contains('casual') || t.contains('كاجوال')) return 'storyTip_casual';
    if (t.contains('formal') || t.contains('رسمي')) return 'storyTip_formal';
    if (t.contains('sporty') || t.contains('رياضي')) return 'storyTip_sporty';
    if (t.contains('evening') || t.contains('سهرة')) return 'storyTip_evening';
    if (t.contains('autumn') || t.contains('خريفي')) return 'storyTip_autumn';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // PageView لعرض القصص
            PageView.builder(
              controller: _pageController,
              physics:
                  const NeverScrollableScrollPhysics(), // منع التمرير اليدوي لتسهيل التحكم باللمس
              itemCount: widget.stories.length,
              itemBuilder: (context, index) {
                final story = widget.stories[index];
                final title = story['title'] ?? '';
                final image = story['imageUrl'] ?? story['image'] ?? '';
                
                final titleKey = _getStoryTitleKey(title);
                final displayTitle = titleKey.tr() == titleKey ? title : titleKey.tr();
                final tipKey = _getStoryTipKey(title);
                final tip = tipKey.isNotEmpty ? tipKey.tr() : '';

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // صورة القصة بجودة كاملة
                    CachedNetworkImage(
                      imageUrl: image.replaceAll('?w=150', '?w=800'),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                    // تدرج داكن سفلي لتحسين وضوح النصوص والأزرار
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black87, Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          stops: [0.0, 0.5],
                        ),
                      ),
                    ),
                    // تدرج داكن علوي لتحسين وضوح مؤشرات التقدم
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black54, Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.2],
                        ),
                      ),
                    ),
                    // النصوص وزر تسوق المظهر في الأسفل
                    Positioned(
                      bottom: 50,
                      left: 24,
                      right: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            tip,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 30),
                          // زر تسوق المظهر
                          Center(
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  final String query = title == 'Casual Friday'
                                      ? 'Casual'
                                      : title == 'Office Setup'
                                      ? 'Formal'
                                      : title == 'Weekend Vibe'
                                      ? 'Casual'
                                      : title;
                                  GoRouter.of(context).push('/search?q=$query');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.shopping_bag_outlined),
                                label: Text(
                                  'shopTheLook'.tr(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            // مؤشرات التقدم شريط شريط وعناصر التحكم العلوية
            Positioned(
              top: 50,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  // أشرطة التقدم المماثلة للإنستغرام
                  Row(
                    children: List.generate(
                      widget.stories.length,
                      (index) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: AnimatedBuilder(
                            animation: _animController,
                            builder: (context, child) {
                              double value = 0.0;
                              if (index < _currentIndex) {
                                value = 1.0;
                              } else if (index == _currentIndex) {
                                value = _animController.value;
                              }
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                minHeight: 3.5,
                                borderRadius: BorderRadius.circular(2),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // السطر العلوي الذي يحتوي على شعار التطبيق وزر الإغلاق
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white24,
                        ),
                        child: const CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.black,
                          child: Icon(
                            Icons.checkroom_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Stylora Stories',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

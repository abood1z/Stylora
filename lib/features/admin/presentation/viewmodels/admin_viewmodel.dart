import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../core/models/product_model.dart';

// Model for App Config
class AppConfigModel {
  final String latestVersion;
  final String minVersion;
  final String updateUrl;

  AppConfigModel({
    required this.latestVersion,
    required this.minVersion,
    required this.updateUrl,
  });

  factory AppConfigModel.fromMap(Map<String, dynamic> data) {
    return AppConfigModel(
      latestVersion: data['latest_version'] ?? '1.0.0',
      minVersion: data['min_version'] ?? '1.0.0',
      updateUrl: data['update_url'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latest_version': latestVersion,
      'min_version': minVersion,
      'update_url': updateUrl,
    };
  }
}

// Provider
final appConfigProvider =
    StateNotifierProvider<AdminViewModel, AsyncValue<AppConfigModel?>>((ref) {
      return AdminViewModel();
    });

class AdminViewModel extends StateNotifier<AsyncValue<AppConfigModel?>> {
  AdminViewModel() : super(const AsyncValue.loading()) {
    fetchConfig();
  }

  Future<void> fetchConfig() async {
    try {
      state = const AsyncValue.loading();
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('update_info')
          .get();
      if (doc.exists && doc.data() != null) {
        state = AsyncValue.data(AppConfigModel.fromMap(doc.data()!));
      } else {
        // Default config if none exists
        state = AsyncValue.data(
          AppConfigModel(
            latestVersion: '1.0.0',
            minVersion: '1.0.0',
            updateUrl: 'https://example.com/update',
          ),
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateConfig(AppConfigModel newConfig) async {
    try {
      state = const AsyncValue.loading();
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('update_info')
          .set(newConfig.toMap(), SetOptions(merge: true));
      state = AsyncValue.data(newConfig);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// Admin Stream Providers for Full Control Dashboard
final adminUsersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).watchAllUsers();
});

final adminProductsProvider = StreamProvider<List<ProductModel>>((ref) {
  return ref.watch(firestoreServiceProvider).watchAllProducts();
});

final adminOrdersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).watchAllOrders();
});

final adminStoresProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).watchShopStores();
});

final adminDailyLooksProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return ref.watch(firestoreServiceProvider).watchDailyLooks();
});

class AdminAnalyticsModel {
  final int totalVirtualTryOns;
  final Map<String, int> categoryCounts;
  final Map<String, int> colorCounts;

  AdminAnalyticsModel({
    required this.totalVirtualTryOns,
    required this.categoryCounts,
    required this.colorCounts,
  });
}

final adminAnalyticsProvider = FutureProvider<AdminAnalyticsModel>((ref) async {
  final firestore = ref.watch(firestoreServiceProvider);
  final tryOnCount = await firestore.getVirtualTryOnCount();
  final allClosetItems = await firestore.getAllClosetItems();

  final categoryCounts = <String, int>{};
  final colorCounts = <String, int>{};

  for (var item in allClosetItems) {
    if (item.category.isNotEmpty) {
      categoryCounts[item.category] = (categoryCounts[item.category] ?? 0) + 1;
    }
    if (item.color.isNotEmpty) {
      colorCounts[item.color] = (colorCounts[item.color] ?? 0) + 1;
    }
  }

  return AdminAnalyticsModel(
    totalVirtualTryOns: tryOnCount,
    categoryCounts: categoryCounts,
    colorCounts: colorCounts,
  );
});

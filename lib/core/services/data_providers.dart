import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'service_providers.dart';
import '../models/product_model.dart';
import '../models/closet_item_model.dart';

final productsProvider = StreamProvider.autoDispose<List<ProductModel>>((ref) {
  return ref.watch(firestoreServiceProvider).watchAvailableProducts();
});

final closetFilterCategoryProvider = StateProvider<String?>((ref) => null);
final closetFilterColorProvider = StateProvider<String?>((ref) => null);

final userClosetProvider = StreamProvider.autoDispose<List<ClosetItemModel>>((ref) {
  final user = ref.watch(authServiceProvider).currentUser;
  if (user == null) return Stream.value([]);
  
  final category = ref.watch(closetFilterCategoryProvider);
  final color = ref.watch(closetFilterColorProvider);

  return ref.watch(firestoreServiceProvider).watchUserCloset(user.uid, category: category, color: color);
});

final shopSearchQueryProvider = StateProvider<String>((ref) => '');

final wardrobeProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authServiceProvider).currentUser;
  if (user == null) return Stream.value([]);
  
  return ref.watch(firestoreServiceProvider).watchWardrobe(user.uid);
});

final shopStoresProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).watchShopStores();
});

final filteredShopStoresProvider = Provider.autoDispose<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final query = ref.watch(shopSearchQueryProvider).toLowerCase();
  final storesAsync = ref.watch(shopStoresProvider);

  return storesAsync.whenData((stores) {
    if (query.isEmpty) return stores;

    return stores.where((store) {
      final name = (store['name'] as String).toLowerCase();
      final products = (store['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      final matchesName = name.contains(query);
      final matchesProduct = products.any((p) => p['name'].toString().toLowerCase().contains(query));
      
      return matchesName || matchesProduct;
    }).toList();
  });
});

final dailyLooksProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).watchDailyLooks();
});

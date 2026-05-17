import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/dummy_data.dart';
import 'package:flutter/foundation.dart';

class FirebaseSeeder {
  static Future<void> seedInitialData() async {
    final db = FirebaseFirestore.instance;

    // 1. Seed Shop Stores & Products
    final storesSnapshot = await db.collection('shop_stores').get();
    if (storesSnapshot.docs.isEmpty) {
      debugPrint('Seeding shop_stores...');
      for (var store in DummyData.shopStores) {
        await db.collection('shop_stores').add(store);
      }
    }

    // 2. Seed Products
    final productsSnapshot = await db.collection('Products').get();
    if (productsSnapshot.docs.isEmpty) {
      debugPrint('Seeding Products...');
      for (var store in DummyData.shopStores) {
        final products = store['products'] as List<Map<String, dynamic>>;
        for (var p in products) {
          await db.collection('Products').add({
            ...p,
            'storeName': store['name'],
            'storeID': store['id'],
            'isAvailable': true,
          });
        }
      }
    }

    // 3. Seed Daily Looks
    final looksSnapshot = await db.collection('daily_looks').get();
    if (looksSnapshot.docs.isEmpty) {
      debugPrint('Seeding daily_looks...');
      for (var look in DummyData.dailyLooks) {
        await db.collection('daily_looks').add(look);
      }
    }
    
    debugPrint('Firebase Seeding completed.');
  }
}

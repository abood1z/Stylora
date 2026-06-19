import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item_model.dart';
import 'settings_provider.dart';

class CartNotifier extends StateNotifier<List<CartItemModel>> {
  final SharedPreferences _prefs;
  static const _cartKey = 'cart_items_data';

  CartNotifier(this._prefs) : super([]) {
    _loadCart();
  }

  void _loadCart() {
    final cartString = _prefs.getString(_cartKey);
    if (cartString != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(cartString);
        state = decodedList
            .map((map) => CartItemModel.fromMap(map as Map<String, dynamic>))
            .toList();
      } catch (e) {
        state = [];
      }
    }
  }

  void _saveCart(List<CartItemModel> currentCart) {
    final encodedList = jsonEncode(
      currentCart.map((item) => item.toMap()).toList(),
    );
    _prefs.setString(_cartKey, encodedList);
  }

  void addToCart(CartItemModel item) {
    List<CartItemModel> updatedList;
    final existingIndex = state.indexWhere((element) => element.id == item.id);
    if (existingIndex >= 0) {
      updatedList = [...state];
      updatedList[existingIndex] = CartItemModel(
        id: item.id,
        name: item.name,
        imageUrl: item.imageUrl,
        price: item.price,
        storeID: item.storeID,
        storeName: item.storeName,
        quantity: updatedList[existingIndex].quantity + 1,
      );
    } else {
      updatedList = [...state, item];
    }
    state = updatedList;
    _saveCart(updatedList);
  }

  void removeFromCart(String id) {
    final updatedList = state.where((item) => item.id != id).toList();
    state = updatedList;
    _saveCart(updatedList);
  }

  void updateQuantity(String id, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromCart(id);
      return;
    }
    final updatedList = [...state];
    final index = updatedList.indexWhere((element) => element.id == id);
    if (index >= 0) {
      updatedList[index] = CartItemModel(
        id: updatedList[index].id,
        name: updatedList[index].name,
        imageUrl: updatedList[index].imageUrl,
        price: updatedList[index].price,
        storeID: updatedList[index].storeID,
        storeName: updatedList[index].storeName,
        quantity: newQuantity,
      );
      state = updatedList;
      _saveCart(updatedList);
    }
  }

  void clearCart() {
    state = [];
    _prefs.remove(_cartKey);
  }

  double get subtotal {
    return state.fold(0.0, (sum, item) => sum + item.totalPrice);
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItemModel>>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CartNotifier(prefs);
});

final cartSubtotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider.notifier).subtotal;
});

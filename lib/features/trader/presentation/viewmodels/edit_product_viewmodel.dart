import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/service_providers.dart';

class EditProductViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService;

  bool _isUpdating = false;
  bool get isUpdating => _isUpdating;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  EditProductViewModel(this._firestoreService);

  Future<bool> updateProduct(
    String productId,
    double price,
    String description,
    String season,
    bool isAvailable,
    String title,
  ) async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final dataToUpdate = {
        'price': price,
        'description': description,
        'season': season,
        'isAvailable': isAvailable,
        'category': title, // In ProductModel, 'category' is usually used for title in this app's logic or vice versa. We'll update both or just category based on what was there. Let's see AddProductScreen.
      };

      await _firestoreService.updateTraderProduct(productId, dataToUpdate);

      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isUpdating = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}

final editProductViewModelProvider = ChangeNotifierProvider.autoDispose<EditProductViewModel>((ref) {
  return EditProductViewModel(ref.watch(firestoreServiceProvider));
});

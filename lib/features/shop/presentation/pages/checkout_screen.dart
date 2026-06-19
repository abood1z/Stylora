import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/providers/cart_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../core/services/notification_service.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _selectedPaymentMethod = 'cod';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final currencySymbol = ref.watch(settingsProvider).currencySymbol;
    final isAr = context.locale.languageCode == 'ar';

    if (cartItems.isEmpty && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/shop');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr ? 'إتمام الطلب' : 'Checkout',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  isAr ? 'طريقة الدفع' : 'Payment Method',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildPaymentOption(
                  'cod',
                  isAr ? 'الدفع عند الاستلام' : 'Cash on Delivery',
                  Icons.money_rounded,
                ),

                const SizedBox(height: 32),
                Text(
                  isAr ? 'ملخص الطلب' : 'Order Summary',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...cartItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity}x ${item.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${item.totalPrice} $currencySymbol',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isAr ? 'الإجمالي الكلي:' : 'Total:',
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$subtotal $currencySymbol',
                      style: context.textTheme.titleLarge?.copyWith(
                        color: context.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: context.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _placeOrder,
                    child: Text(
                      isAr ? 'تأكيد الطلب' : 'Confirm Order',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPaymentOption(String value, String title, IconData icon) {
    return RadioListTile<String>(
      value: value,
      groupValue: _selectedPaymentMethod,
      onChanged: (val) {
        if (val != null) setState(() => _selectedPaymentMethod = val);
      },
      title: Row(
        children: [Icon(icon), const SizedBox(width: 12), Text(title)],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: _selectedPaymentMethod == value
          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
          : null,
    );
  }

  Future<void> _placeOrder() async {
    final user = ref.read(authServiceProvider).currentUser;
    final isAr = context.locale.languageCode == 'ar';

    if (user == null) {
      context.showSnackBar(
        isAr ? 'يرجى تسجيل الدخول أولاً' : 'Please login first',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cartItems = ref.read(cartProvider);
      final firestoreService = ref.read(firestoreServiceProvider);

      for (var item in cartItems) {
        final orderId =
            'ORD_${DateTime.now().millisecondsSinceEpoch}_${item.id}';
        final orderMap = {
          'orderId': orderId,
          'productId': item.id,
          'productName': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'totalPrice': item.totalPrice,
          'buyerId': user.uid,
          'buyerName': user.displayName ?? user.email ?? 'Buyer',
          'storeID': item.storeID,
          'storeName': item.storeName,
          'imageUrl': item.imageUrl,
          'status': 'pending',
          'paymentMethod': _selectedPaymentMethod,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await firestoreService.createOrder(orderMap);

        // Notify Seller
        if (item.storeID.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(item.storeID)
              .collection('notifications')
              .add({
                'titleAr': 'طلب جديد!',
                'titleEn': 'New Order!',
                'bodyAr': 'لقد تلقيت طلباً جديداً لمنتج "${item.name}".',
                'bodyEn': 'You have received a new order for "${item.name}".',
                'type': 'order',
                'createdAt': FieldValue.serverTimestamp(),
                'isRead': false,
              });
        }
      }

      // Notify Buyer
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add({
            'titleAr': 'تم إرسال الطلب بنجاح!',
            'titleEn': 'Order Placed Successfully!',
            'bodyAr': 'تم تسجيل طلبك لعدد ${cartItems.length} منتجات بنجاح.',
            'bodyEn':
                'Your order for ${cartItems.length} products has been successfully recorded.',
            'type': 'order',
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });

      NotificationService.showLocalNotification(
        title: isAr ? 'تم إرسال الطلب!' : 'Order Placed!',
        body: isAr
            ? 'تم تسجيل طلبك بنجاح.'
            : 'Your order has been successfully recorded.',
        payload: '/order-history',
        category: 'transactional',
      );

      ref.read(cartProvider.notifier).clearCart();

      if (mounted) {
        context.showSnackBar(
          isAr ? 'تم تأكيد طلبك بنجاح!' : 'Order confirmed successfully!',
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(isAr ? 'حدث خطأ: $e' : 'Error: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }
}

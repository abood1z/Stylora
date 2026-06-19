import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/services/service_providers.dart';
import '../viewmodels/admin_viewmodel.dart';

class AdminVendorsTab extends ConsumerWidget {
  const AdminVendorsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(adminStoresProvider);
    final isAr = context.locale.languageCode == 'ar';

    return storesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (stores) {
        if (stores.isEmpty) {
          return Center(
            child: Text(isAr ? 'لا يوجد متاجر' : 'No vendors found'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stores.length,
          itemBuilder: (context, index) {
            final store = stores[index];
            final storeId = store['id'] ?? '';
            final storeName = store['storeName'] ?? store['name'] ?? 'Unknown';
            final isBlocked = store['isBlocked'] ?? false;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: context.colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: context.colorScheme.primary,
                  ),
                ),
                title: Text(
                  storeName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('ID: $storeId'),
                trailing: Switch(
                  value: !isBlocked,
                  activeThumbColor: Colors.green,
                  inactiveThumbColor: Colors.red,
                  onChanged: (val) async {
                    await ref
                        .read(firestoreServiceProvider)
                        .updateStoreStatus(storeId, !val);
                    if (context.mounted) {
                      context.showSnackBar(
                        isAr ? 'تم تحديث حالة المتجر' : 'Store status updated',
                      );
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

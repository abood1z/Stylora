import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/services/service_providers.dart';
import '../viewmodels/admin_viewmodel.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUsersTab extends ConsumerWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersProvider);
    final isAr = context.locale.languageCode == 'ar';

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (users) {
        if (users.isEmpty) {
          return Center(child: Text(isAr ? 'لا يوجد مستخدمين' : 'No users found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final role = user['role'] ?? 'user';
            final createdAt = user['createdAt'] as Timestamp?;
            final timeString = createdAt != null 
                ? timeago.format(createdAt.toDate(), locale: isAr ? 'ar' : 'en')
                : '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: role == 'admin' ? Colors.red.withOpacity(0.2) : (role == 'seller' ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.2)),
                  child: Icon(
                    role == 'admin' ? Icons.admin_panel_settings_rounded : (role == 'seller' ? Icons.storefront_rounded : Icons.person_rounded),
                    color: role == 'admin' ? Colors.red : (role == 'seller' ? Colors.green : Colors.blue),
                  ),
                ),
                title: Text(user['name'] ?? user['email'] ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['email'] ?? ''),
                    if (timeString.isNotEmpty) Text(isAr ? 'انضم منذ: $timeString' : 'Joined: $timeString', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (action) async {
                    if (action == 'make_seller') {
                      await ref.read(firestoreServiceProvider).updateUserRole(user['id'], 'seller');
                      context.showSnackBar(isAr ? 'تمت الترقية إلى تاجر' : 'Promoted to Seller');
                    } else if (action == 'make_user') {
                      await ref.read(firestoreServiceProvider).updateUserRole(user['id'], 'user');
                      context.showSnackBar(isAr ? 'تم التحويل إلى مستخدم عادي' : 'Demoted to User');
                    } else if (action == 'make_admin') {
                      await ref.read(firestoreServiceProvider).updateUserRole(user['id'], 'admin');
                      context.showSnackBar(isAr ? 'تمت الترقية إلى مدير' : 'Promoted to Admin');
                    } else if (action == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(isAr ? 'تأكيد الحذف' : 'Confirm Deletion'),
                          content: Text(isAr ? 'هل أنت متأكد من حذف هذا المستخدم وبياناته نهائياً؟' : 'Are you sure you want to permanently delete this user?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true), 
                              child: Text(isAr ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(firestoreServiceProvider).deleteUserData(user['id']);
                        context.showSnackBar(isAr ? 'تم حذف المستخدم' : 'User Deleted');
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    if (role != 'seller') PopupMenuItem(value: 'make_seller', child: Text(isAr ? 'ترقية إلى تاجر' : 'Make Seller')),
                    if (role != 'user') PopupMenuItem(value: 'make_user', child: Text(isAr ? 'تحويل لمستخدم' : 'Make User')),
                    if (role != 'admin') PopupMenuItem(value: 'make_admin', child: Text(isAr ? 'ترقية إلى مدير' : 'Make Admin')),
                    PopupMenuItem(value: 'delete', child: Text(isAr ? 'حذف المستخدم' : 'Delete User', style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

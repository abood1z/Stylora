import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/services/service_providers.dart';
import '../viewmodels/admin_viewmodel.dart';

class AdminContentTab extends ConsumerWidget {
  const AdminContentTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyLooksAsync = ref.watch(adminDailyLooksProvider);
    final isAr = context.locale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStoryDialog(context, ref, isAr),
        icon: const Icon(Icons.add_rounded),
        label: Text(isAr ? 'إضافة قصة' : 'Add Story'),
      ),
      body: dailyLooksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (looks) {
          if (looks.isEmpty) {
            return Center(
              child: Text(
                isAr ? 'لا توجد قصص أناقة' : 'No style stories found',
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: looks.length,
            itemBuilder: (context, index) {
              final look = looks[index];
              final id = look['id'];
              final title = look['title'] ?? 'Untitled';
              final imageUrl = look['imageUrl'] ?? look['image'] ?? '';

              return Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      )
                    else
                      Container(color: Colors.grey.withOpacity(0.2)),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete_rounded,
                          color: Colors.red,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.8),
                        ),
                        onPressed: () async {
                          try {
                            await ref
                                .read(firestoreServiceProvider)
                                .deleteDailyLook(id as String);
                            if (context.mounted) {
                              context.showSnackBar(
                                isAr
                                    ? 'تم الحذف بنجاح'
                                    : 'Deleted successfully',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              context.showSnackBar(
                                isAr ? 'حدث خطأ: $e' : 'Error: $e',
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddStoryDialog(BuildContext context, WidgetRef ref, bool isAr) {
    final titleController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAr ? 'قصة أناقة جديدة' : 'New Style Story'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: isAr ? 'العنوان' : 'Title',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                labelText: isAr ? 'رابط الصورة' : 'Image URL',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty &&
                  urlController.text.isNotEmpty) {
                await ref.read(firestoreServiceProvider).addDailyLook({
                  'title': titleController.text,
                  'imageUrl': urlController.text,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  context.showSnackBar(
                    isAr ? 'تمت الإضافة بنجاح' : 'Added successfully',
                  );
                }
              }
            },
            child: Text(isAr ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
  }
}

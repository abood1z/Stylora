import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/services/service_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// شاشة الملف الشخصي (Profile Screen)
// تعرض بيانات المستخدم، إحصائياته (أو بيانات المتجر للتاجر)، وتسمح بتعديل الصورة والإعدادات
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUpdatingPhoto = false; // حالة تحديث الصورة

  // تحديث صورة الملف الشخصي باستخدام Cloudinary
  Future<void> _updateProfilePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image != null) {
      setState(() => _isUpdatingPhoto = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        // 1. الحصول على الرابط القديم لحذفه لاحقاً
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final oldPhotoUrl = doc.data()?['photoURL'] as String?;

        // 2. رفع الصورة الجديدة إلى Cloudinary
        final newUrl = await CloudinaryService.uploadImage(File(image.path), folder: 'profiles/${user.uid}');
        
        if (newUrl != null) {
          // 3. حذف الصورة القديمة لتوفير المساحة
          if (oldPhotoUrl != null) {
            await CloudinaryService.deleteImage(oldPhotoUrl);
          }

          // 4. تحديث رابط الصورة في Firestore
          await ref.read(firestoreServiceProvider).updateSettings(user.uid, {'photoURL': newUrl});
          
          if (mounted) {
            context.showSnackBar('profilePhotoUpdated'.tr());
          }
        }
      } catch (e) {
        if (mounted) context.showSnackBar('errorUpdatingPhoto'.tr(), isError: true);
      } finally {
        if (mounted) setState(() => _isUpdatingPhoto = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null; // هل المستخدم يتصفح كضيف؟

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // شريط علوي مرن (SliverAppBar) بتأثيرات بصرية جذابة
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: context.colorScheme.surface.withValues(alpha: 0.8),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.blurBackground, StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.colorScheme.primary.withValues(alpha: 0.2),
                          context.colorScheme.surface,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        if (isGuest)
                          _buildGuestHeader(context)
                        else
                          _buildUserHeader(context, user),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // زر الإعدادات
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: GlassCard(
                  borderRadius: 12,
                  opacity: 0.1,
                  child: IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.push('/settings'),
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // قسم البيانات الشخصية (يظهر فقط للمسجلين)
                  if (!isGuest) ...[
                    _buildSectionHeader('personalDetails'.tr()),
                    const SizedBox(height: 12),
                    _buildDetailsCard(context, user),
                    const SizedBox(height: 24),
                  ],
                  // قائمة خيارات الحساب والتحكم
                  _buildSectionHeader('account'.tr()),
                  const SizedBox(height: 12),
                  GlassCard(
                    borderRadius: 32,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        if (!isGuest) ...[
                          _buildProfileItem(
                            context,
                            Icons.edit_rounded,
                            'editProfile'.tr(),
                            onTap: () => context.push('/complete-profile'),
                          ),
                          _buildProfileItem(
                            context,
                            Icons.history_rounded,
                            'orderHistory'.tr(),
                            onTap: () => context.showSnackBar('comingSoon'.tr()),
                          ),
                          _buildProfileItem(
                            context,
                            Icons.favorite_border_rounded,
                            'wishlist'.tr(),
                            onTap: () => context.showSnackBar('comingSoon'.tr()),
                          ),
                        ] else ...[
                          _buildProfileItem(
                            context,
                            Icons.login_rounded,
                            '${'login'.tr()} / ${'signup'.tr()}',
                            onTap: () => context.go('/login'),
                          ),
                        ],
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        _buildProfileItem(
                          context,
                          Icons.settings_rounded,
                          'settings'.tr(),
                          onTap: () => context.push('/settings'),
                        ),
                        if (!isGuest) ...[
                          const Divider(height: 1, indent: 20, endIndent: 20),
                          _buildProfileItem(
                            context,
                            Icons.logout_rounded,
                            'logout'.tr(),
                            color: context.colorScheme.error,
                            onTap: () async {
                              await FirebaseAuth.instance.signOut();
                              ref.read(isGuestProvider.notifier).state = false;
                              if (context.mounted) {
                                context.go('/login');
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 100), // مساحة إضافية للتنقل السفلي
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // بناء عنوان القسم
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  // بطاقة تفاصيل المستخدم (تختلف حسب الدور: تاجر أو عميل)
  Widget _buildDetailsCard(BuildContext context, User user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        
        final isMerchant = data['role'] == 'merchant' || data['role'] == 'trader';

        return GlassCard(
          borderRadius: 32,
          padding: const EdgeInsets.all(24),
          child: isMerchant
              ? Column(
                  // عرض بيانات المتجر للتاجر
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'storeName'.tr(),
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      data['storeName'] ?? '--',
                      style: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Text(
                      'storeDescription'.tr(),
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      data['storeDescription'] ?? '--',
                      style: context.textTheme.bodyMedium,
                    ),
                  ],
                )
              : Column(
                  // عرض بيانات العميل (الطول، الوزن، العمر)
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDetailMetric(context, 'height'.tr(), '${data['height'] ?? '--'}', 'cm', Icons.height_rounded),
                        _buildMetricDivider(),
                        _buildDetailMetric(context, 'weight'.tr(), '${data['weight'] ?? '--'}', 'kg', Icons.monitor_weight_outlined),
                        _buildMetricDivider(),
                        _buildDetailMetric(context, 'age'.tr(), '${data['age'] ?? '--'}', 'yr', Icons.cake_outlined),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoRow(Icons.face_rounded, 'gender'.tr(), data['gender']?.toString().tr() ?? '--'),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('skinTone'.tr(), style: context.textTheme.labelMedium?.copyWith(color: context.colorScheme.onSurface.withValues(alpha: 0.5))),
                              const SizedBox(width: 8),
                              // عرض لون البشرة المختار
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: data['skinColor'] != null ? Color(int.parse(data['skinColor'].replaceAll('#', '0xFF'))) : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: context.colorScheme.onSurface.withValues(alpha: 0.1)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                       children: [
                         Expanded(child: _buildInfoRow(Icons.public_rounded, 'country'.tr(), data['country'] ?? '--')),
                         Expanded(child: _buildInfoRow(Icons.location_city_rounded, 'city'.tr(), data['city'] ?? '--')),
                       ]
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildMetricDivider() {
    return Container(height: 40, width: 1, color: context.colorScheme.onSurface.withValues(alpha: 0.1));
  }

  // بناء وحدة قياس واحدة (Metric) في الملف الشخصي
  Widget _buildDetailMetric(BuildContext context, String label, String value, String unit, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: context.colorScheme.primary.withValues(alpha: 0.5)),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(text: value, style: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const TextSpan(text: ' '),
              TextSpan(text: unit, style: context.textTheme.labelSmall?.copyWith(color: context.colorScheme.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        ),
        Text(label, style: context.textTheme.labelSmall?.copyWith(color: context.colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.colorScheme.primary.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.textTheme.labelSmall?.copyWith(color: context.colorScheme.onSurface.withValues(alpha: 0.5))),
              Text(
                value, 
                style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // واجهة الملف الشخصي للضيف
  Widget _buildGuestHeader(BuildContext context) {
    return Column(
      children: [
        GlassCard(
          borderRadius: 50,
          padding: const EdgeInsets.all(4),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: context.colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(Icons.person_rounded, size: 50, color: context.colorScheme.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'guestUser'.tr(),
          style: context.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(
          'enjoyExploring'.tr(),
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  // واجهة المحتوى للمستخدم المسجل (الاسم والبريد والصورة)
  Widget _buildUserHeader(BuildContext context, User user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final name = data?['name'] ?? user.email?.split('@')[0] ?? 'User';
        final email = data?['email'] ?? user.email ?? '';

        return Column(
          children: [
            Stack(
              children: [
                GlassCard(
                  borderRadius: 60,
                  padding: const EdgeInsets.all(4),
                  child: CircleAvatar(
                    radius: 54,
                    backgroundColor: context.colorScheme.primary.withValues(alpha: 0.1),
                    backgroundImage: NetworkImage(data?['photoURL'] ?? 'https://www.w3schools.com/howto/img_avatar.png'),
                    child: _isUpdatingPhoto ? const CircularProgressIndicator() : null,
                  ),
                ),
                // زر الكاميرا لتغيير الصورة
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isUpdatingPhoto ? null : _updateProfilePhoto,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: context.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(
              email,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        );
      },
    );
  }

  // بناء عنصر واحد في قائمة الخيارات
  Widget _buildProfileItem(
    BuildContext context,
    IconData icon,
    String title, {
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? context.colorScheme.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color ?? context.colorScheme.primary, size: 20),
      ),
      title: Text(
        title,
        style: context.textTheme.bodyLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: context.colorScheme.onSurface.withValues(alpha: 0.3)),
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/models/outfit_model.dart';
import '../../../../core/services/outfit_generator_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

// شاشة التنسيقات الذكية (Matching Screen)
// تعرض قائمة بالتنسيقات التي اقترحها النظام بناءً على قطع ملابس المستخدم
class MatchingScreen extends StatelessWidget {
  const MatchingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'تنسيقاتي الذكية', 
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.w900, 
            color: context.colorScheme.onSurface,
            fontSize: 22,
          )
        ),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          // استخدام StreamBuilder لمراقبة التغييرات في التنسيقات فور حدوثها
          : StreamBuilder<List<OutfitModel>>(
              stream: OutfitGeneratorService().watchUserOutfits(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final outfits = snapshot.data ?? [];

                if (outfits.isEmpty) {
                  return _buildEmptyState(context); // عرض حالة "لا توجد بيانات"
                }

                // عرض التنسيقات في شبكة ثنائية الأعمدة
                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 20,
                    childAspectRatio: 0.6,
                  ),
                  itemCount: outfits.length,
                  itemBuilder: (context, index) {
                    final outfit = outfits[index];
                    return _buildOutfitCard(context, outfit);
                  },
                );
              },
            ),
    );
  }

  // بناء واجهة في حال عدم وجود تنسيقات
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 80, color: context.colorScheme.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          Text(
            'لا توجد تنسيقات بعد',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }

  // بناء بطاقة التنسيق التي تظهر القطع المتوافقة (علوي وسفلي)
  Widget _buildOutfitCard(BuildContext context, OutfitModel outfit) {
    // التحقق من وجود صورتين على الأقل لتكوين طقم متكامل
    final hasEnoughItems = outfit.itemImageUrls.length >= 2;
    
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (hasEnoughItems) ...[
            // عرض القطعة الأولى (مثلاً القميص)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: outfit.itemImageUrls[0],
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
            const Icon(Icons.add_rounded, size: 16, color: Colors.grey),
            // عرض القطعة الثانية (مثلاً البنطال)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: outfit.itemImageUrls[1],
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
          ] else
            const Expanded(child: Center(child: Icon(Icons.broken_image_outlined))),
          
          const SizedBox(height: 8),
          // عرض تاريخ إنشاء التنسيق
          Text(
            _formatDate(outfit.createdAt),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // تنسيق التاريخ للشكل المقروء (يوم/شهر/سنة)
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

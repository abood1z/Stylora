import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../core/services/ai_model_service.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/models/closet_item_model.dart';
import '../../../../core/services/notification_service.dart';

// شاشة تحليل الكاميرا (Camera Analysis Screen)
// تتيح للمستخدم تصوير قطعة ملابس ليقوم الذكاء الاصطناعي بتحليل لونها ونوعها تلقائياً
class CameraAnalysisScreen extends StatefulWidget {
  const CameraAnalysisScreen({super.key});

  @override
  State<CameraAnalysisScreen> createState() => _CameraAnalysisScreenState();
}

class _CameraAnalysisScreenState extends State<CameraAnalysisScreen> {
  final AIModelService _aiService = AIModelService();
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();
  
  File? _selectedImage; 
  bool _isProcessing = false; 
  List<Map<String, dynamic>> _detectedItems = [];
  final Map<int, bool> _isSavingMap = {}; // تتبع حالة الحفظ لكل قطعة

  @override
  void initState() {
    super.initState();
    _aiService.loadModels();
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    setState(() {
      _selectedImage = File(image.path);
      _detectedItems = []; 
      _isSavingMap.clear();
      _isProcessing = true;
    });

    try {
      final results = await _aiService.analyzeImage(_selectedImage!);
      if (mounted) {
        setState(() {
          _detectedItems = results;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('خطأ في التحليل: $e', isError: true);
        setState(() => _isProcessing = false);
      }
    }
  }

  // حفظ القطعة في الخزانة الرقمية
  Future<void> _saveToCloset(int index, Map<String, dynamic> item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.showSnackBar('يجب تسجيل الدخول أولاً', isError: true);
      return;
    }

    setState(() => _isSavingMap[index] = true);

    try {
      // 1. رفع الصورة المفرغة لـ Cloudinary
      final Uint8List bytes = item['imageBytes'];
      final imageUrl = await CloudinaryService.uploadImageBytes(
        bytes,
        folder: 'user_closet/${user.uid}',
        filename: 'item_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (imageUrl == null) throw Exception('فشل رفع الصورة');

      // 2. الحفظ في Firestore
      final closetItem = ClosetItemModel(
        id: '',
        userID: user.uid,
        imageUrl: imageUrl,
        category: item['category'],
        color: item['color'],
        season: 'summer', // يمكن تحسينه لاحقاً لاكتشاف الموسم
      );

      await _firestoreService.addClosetItem(closetItem);

      if (mounted) {
        context.showSnackBar('تمت إضافة ${item['category']} لخزانتك بنجاح! ✨');
        // إرسال إشعار
        await NotificationService.showLocalNotification(
          title: 'قطعة جديدة في خزانتك! ✨',
          body: 'تم إضافة ${item['category']} بنجاح بلونه المميز.',
        );
      }
    } catch (e) {
      if (mounted) context.showSnackBar('فشل الحفظ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingMap[index] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'تحليل الملابس المتعدد', 
          style: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedImage != null && _detectedItems.isEmpty && !_isProcessing)
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  image: DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover),
                ),
              ),
            
            const SizedBox(height: 16),
            
            if (_isProcessing) _buildProcessingState(),
            
            if (_detectedItems.isNotEmpty && !_isProcessing) ...[
              Text(
                'تم العثور على ${_detectedItems.length} قطع:',
                style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // استخدام indexed map للمرور على العناصر
              ...Iterable<int>.generate(_detectedItems.length).map((index) => _buildItemResult(index, _detectedItems[index])),
            ],

            if (_selectedImage == null && !_isProcessing) _buildEmptyState(),
            
            const SizedBox(height: 24),
            if (!_isProcessing) ...[
              CustomButton(
                onPressed: () => _pickAndAnalyze(ImageSource.camera),
                text: 'التقاط صورة كاملة',
              ),
              const SizedBox(height: 12),
              CustomButton(
                onPressed: () => _pickAndAnalyze(ImageSource.gallery),
                text: 'اختيار من المعرض',
                isOutlined: true,
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildItemResult(int index, Map<String, dynamic> item) {
    final Uint8List? bytes = item['imageBytes'];
    final bool isSaving = _isSavingMap[index] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (bytes != null)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: context.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['category'].toString().toUpperCase(),
                    style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: context.colorScheme.primary),
                  ),
                  const SizedBox(height: 4),
                  _buildSmallInfoRow(Icons.palette_outlined, 'اللون: ${item['color']}'),
                  if (item['sleeve'] != null)
                    _buildSmallInfoRow(Icons.straighten_rounded, 'الكم: ${item['sleeve']}'),
                ],
              ),
            ),
            isSaving 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  onPressed: () => _saveToCloset(index, item),
                  icon: Icon(Icons.add_circle_outline_rounded, color: context.colorScheme.primary),
                )
          ],
        ),
      ),
    );
  }

  Widget _buildSmallInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: context.colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Text(text, style: context.textTheme.bodySmall),
      ],
    );
  }

  // الواجهة المعروضة قبل اختيار أي صورة
  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.camera_alt_outlined,
          size: 80,
          color: context.colorScheme.primary.withValues(alpha: 0.2),
        ),
        const SizedBox(height: 16),
        Text(
          'وجّه الكاميرا نحو قطعة الملابس',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurface.withValues(alpha: 0.4),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // الواجهة المعروضة أثناء تحليل الصورة بالذكاء الاصطناعي
  Widget _buildProcessingState() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: GlassCard(
        borderRadius: 24,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const CircularProgressIndicator(strokeWidth: 3),
              const SizedBox(height: 20),
              Text(
                'الذكاء الاصطناعي يحلل القماش...',
                style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'يتم تحديد اللون وفئة الملابس تلقائياً',
                style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

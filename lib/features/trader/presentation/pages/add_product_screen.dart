import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_textfield.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/utils/context_ext.dart';
import '../viewmodels/add_product_viewmodel.dart';

// شاشة إضافة منتج جديد (Add Product Screen)
// تتيح للتاجر رفع صورة للمنتج وإدخال بياناته (السعر، الوصف، الموسم) ليتم تصنيفه آلياً
class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _titleController = TextEditingController(); // المتحكم في اسم المنتج
  final _priceController = TextEditingController(); // المتحكم في سعر المنتج
  final _descriptionController = TextEditingController(); // المتحكم في وصف المنتج
  
  String _selectedSeason = 'summer'; // الموسم الافتراضي (صيفي)
  File? _selectedImage; // ملف الصورة المختارة من المعرض

  // اختيار صورة من معرض الصور بالجهاز
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // حفظ المنتج وإرسال البيانات للـ ViewModel
  Future<void> _saveProduct(AddProductViewModel viewModel) async {
    if (_selectedImage == null) {
      context.showSnackBar('يرجى اختيار صورة للمنتج'.tr());
      return;
    }
    if (_priceController.text.isEmpty) {
      context.showSnackBar('يرجى إدخال سعر المنتج'.tr());
      return;
    }

    final price = double.tryParse(_priceController.text) ?? 0.0;
    
    // استدعاء دالة الرفع من ViewModel (نمط MVVM)
    final success = await viewModel.uploadProduct(
      _selectedImage!,
      price,
      _descriptionController.text,
      _selectedSeason,
    );

    if (success && mounted) {
      context.showSnackBar('تم إضافة المنتج بنجاح مع التصنيف الآلي!'.tr());
      Navigator.pop(context); // العودة للشاشة السابقة بعد النجاح
    } else if (!success && mounted) {
      context.showSnackBar('خطأ: ${viewModel.errorMessage}'.tr(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // مراقبة الـ ViewModel لمعرفة حالة الرفع والرسائل
    final viewModel = ref.watch(addProductViewModelProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('إضافة منتج جديد'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colorScheme.surface,
              context.colorScheme.primary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildImagePicker(), // أداة اختيار الصورة
                const SizedBox(height: 24),
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  borderRadius: 32,
                  child: Column(
                    children: [
                      CustomTextField(
                        label: 'productTitle'.tr(),
                        hint: 'أدخل اسم المنتج'.tr(),
                        controller: _titleController,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'productPrice'.tr(),
                        hint: '0.00',
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'productDescription'.tr(),
                        hint: 'اصف منتجك هنا...'.tr(),
                        controller: _descriptionController,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      _buildSeasonSelector(), // أداة اختيار الموسم
                      const SizedBox(height: 32),
                      viewModel.isUploading 
                        ? const CircularProgressIndicator()
                        : CustomButton(
                            onPressed: () => _saveProduct(viewModel),
                            text: 'حفظ المنتج'.tr(),
                            icon: Icons.check_rounded,
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // بناء اختيار الموسم (صيفي/شتوي) بتصميم تفاعلي
  Widget _buildSeasonSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'التصنيف الموسمي'.tr(),
          style: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: context.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSeasonOption('summer', Icons.sunny, Colors.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSeasonOption('winter', Icons.ac_unit_rounded, Colors.blue),
            ),
          ],
        ),
      ],
    );
  }

  // خيار موسمي واحد
  Widget _buildSeasonOption(String value, IconData icon, Color activeColor) {
    final isSelected = _selectedSeason == value;
    return InkWell(
      onTap: () => setState(() => _selectedSeason = value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? activeColor : context.colorScheme.outline.withValues(alpha: 0.2),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? activeColor : context.colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 4),
            Text(
              value.tr(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? activeColor : context.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ودجت اختيار الصورة ومعاينتها
  Widget _buildImagePicker() {
    return InkWell(
      onTap: _pickImage,
      child: GlassCard(
        height: 200,
        width: double.infinity,
        borderRadius: 32,
        child: _selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.file(_selectedImage!, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_rounded, size: 48, color: context.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text('رفع صورة المنتج'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }
}

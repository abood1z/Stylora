import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_textfield.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/utils/context_ext.dart';
import '../viewmodels/edit_product_viewmodel.dart';

class EditProductScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> productMap;

  const EditProductScreen({super.key, required this.productMap});

  @override
  ConsumerState<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends ConsumerState<EditProductScreen> {
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late String _selectedSeason;
  late bool _isAvailable;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.productMap['price']?.toString() ?? '0.0',
    );
    _descriptionController = TextEditingController(
      text: widget.productMap['description'] ?? '',
    );
    _selectedSeason = widget.productMap['season'] ?? 'summer';
    _isAvailable = widget.productMap['isAvailable'] ?? true;

    _priceController.addListener(() {
      if (_priceController.text.startsWith('.')) {
        _priceController.text = '0${_priceController.text}';
        _priceController.selection = TextSelection.fromPosition(
          TextPosition(offset: _priceController.text.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateProduct(EditProductViewModel viewModel) async {
    if (_priceController.text.isEmpty) {
      context.showSnackBar('pleaseFillAllFields'.tr());
      return;
    }

    final price = double.tryParse(_priceController.text) ?? 0.0;

    final success = await viewModel.updateProduct(
      widget.productMap['id'],
      price,
      _descriptionController.text,
      _selectedSeason,
      _isAvailable,
      widget.productMap['category'] ?? '',
    );

    if (success && mounted) {
      context.showSnackBar('productUpdatedSuccess'.tr());
      Navigator.pop(context);
    } else if (!success && mounted) {
      context.showSnackBar(
        "${'error'.tr()}: ${viewModel.errorMessage?.tr() ?? ''}",
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(editProductViewModelProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'editProduct'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
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
                _buildImagePreview(),
                const SizedBox(height: 24),
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  borderRadius: 32,
                  child: Column(
                    children: [
                      CustomTextField(
                        label: 'productPrice'.tr(),
                        hint: '0.00',
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'productDescription'.tr(),
                        hint: 'describeProductHere'.tr(),
                        controller: _descriptionController,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      _buildAvailabilityToggle(),
                      const SizedBox(height: 16),
                      _buildSeasonSelector(),
                      const SizedBox(height: 32),
                      viewModel.isUpdating
                          ? const CircularProgressIndicator()
                          : CustomButton(
                              onPressed: () => _updateProduct(viewModel),
                              text: 'saveChanges'.tr(),
                              icon: Icons.save_rounded,
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

  Widget _buildAvailabilityToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'inStock'.tr(),
          style: context.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Switch(
          value: _isAvailable,
          onChanged: (val) {
            setState(() {
              _isAvailable = val;
            });
          },
          activeThumbColor: context.colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildSeasonSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'seasonalCategory'.tr(),
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
              child: _buildSeasonOption(
                'winter',
                Icons.ac_unit_rounded,
                Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeasonOption(String value, IconData icon, Color activeColor) {
    final isSelected = _selectedSeason == value;
    return InkWell(
      onTap: () => setState(() => _selectedSeason = value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? activeColor
                : context.colorScheme.outline.withValues(alpha: 0.2),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? activeColor
                  : context.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 4),
            Text(
              value.tr(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? activeColor
                    : context.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    final imageUrl = widget.productMap['imageUrl'] ?? '';
    return GlassCard(
      height: 200,
      width: double.infinity,
      borderRadius: 32,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              const Center(child: CircularProgressIndicator()),
          errorWidget: (context, url, err) =>
              const Icon(Icons.image_not_supported, size: 48),
        ),
      ),
    );
  }
}

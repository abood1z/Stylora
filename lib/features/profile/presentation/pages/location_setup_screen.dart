import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../core/providers/settings_provider.dart';

class LocationSetupScreen extends ConsumerStatefulWidget {
  const LocationSetupScreen({super.key});

  @override
  ConsumerState<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends ConsumerState<LocationSetupScreen> {
  String? _country;
  String? _state;
  String? _city;
  bool _isLoading = false;

  Future<void> _saveLocation() async {
    if (_country == null || _state == null) {
      context.showSnackBar('pleaseFillAllFields'.tr(), isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(settingsProvider.notifier).updateProfile({
        'country': _country,
        'province': _state,
        'city': _city,
        'locationCompleted': true,
      });

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) context.showSnackBar('errorSavingProfile'.tr(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colorScheme.surface,
              context.colorScheme.primary.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_rounded, size: 80, color: Colors.orangeAccent),
                  const SizedBox(height: 24),
                  Text(
                    'locationSetup'.tr(),
                    style: context.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'locationSetupDesc'.tr(),
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyMedium?.copyWith(color: context.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 40),
                  
                  GlassCard(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CSCPickerPlus(
                          layout: Layout.vertical,
                          onCountryChanged: (value) {
                            setState(() => _country = value);
                          },
                          onStateChanged: (value) {
                            setState(() => _state = value);
                          },
                          onCityChanged: (value) {
                            setState(() => _city = value);
                          },
                          // التنسيقات الجمالية لتناسب Style التطبيق
                          dropdownDecoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: context.colorScheme.surface.withValues(alpha: 0.5),
                              border: Border.all(color: context.colorScheme.primary.withValues(alpha: 0.2))),
                          disabledDropdownDecoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey.withValues(alpha: 0.1),
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.2))),
                          selectedItemStyle: context.textTheme.bodyLarge?.copyWith(color: context.colorScheme.onSurface, fontWeight: FontWeight.w600),
                          dropdownHeadingStyle: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          dropdownItemStyle: context.textTheme.bodyMedium,
                          searchBarRadius: 10.0,
                        ),
                        const SizedBox(height: 32),
                        CustomButton(
                          onPressed: _saveLocation,
                          text: 'saveAndContinue'.tr(),
                          isLoading: _isLoading,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

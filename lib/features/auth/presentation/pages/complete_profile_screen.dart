import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_textfield.dart';
import '../../../../core/services/service_providers.dart';

// شاشة إكمال الملف الشخصي (Complete Profile Screen)
// تُعرض للمستخدمين الذين سجلوا عبر طرق خارجية (مثل جوجل) لنقص بياناتهم الأساسية
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  // المتحكمات في حقول الإدخال
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();
  final _nameController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _storeDescriptionController = TextEditingController();
  
  String _selectedRole = 'user'; // الدور: عميل أو تاجر
  String? _selectedGender; // الجنس مجبر على الاختيار
  Color? _selectedSkinTone; // لون البشرة مجبر على الاختيار
  bool _isLoading = false; // حالة التحميل

  // متغيرات الموقع الجغرافي
  String? _country;
  String? _state;
  String? _city;

  final List<Color> _skinTones = [
    const Color(0xFFFFDBAC),
    const Color(0xFFF1C27D),
    const Color(0xFFE0AC69),
    const Color(0xFF8D5524),
    const Color(0xFF3C2012),
  ];

  @override
  void initState() {
    super.initState();
    // تحميل أي بيانات موجودة مسبقاً عند فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentData();
    });
  }

  // تحميل البيانات الحالية من البروفايدر لتعبئة الحقول تلقائياً
  void _loadCurrentData() {
    final userData = ref.read(settingsProvider).userData;
    if (userData != null) {
      setState(() {
        _selectedRole = userData['role'] ?? 'user';
        _nameController.text = userData['name'] ?? '';
        
        // تعبئة البيانات بناءً على نوع المستخدم
        if (_selectedRole == 'merchant' || _selectedRole == 'trader') {
          _storeNameController.text = userData['storeName'] ?? '';
          _storeDescriptionController.text = userData['storeDescription'] ?? '';
        } else {
          _heightController.text = userData['height']?.toString() ?? '';
          _weightController.text = userData['weight']?.toString() ?? '';
          _ageController.text = userData['age']?.toString() ?? '';
          _selectedGender = userData['gender'];
          _country = userData['country'];
          _state = userData['province'];
          _city = userData['city'];
          if (userData['skinColor'] != null) {
            try {
              _selectedSkinTone = Color(int.parse(userData['skinColor'].replaceAll('#', '0xFF')));
            } catch (e) {
              debugPrint('Error parsing skin color: $e');
            }
          }
        }
      });
    }
  }

  // حفظ التغييرات وتحديث الملف الشخصي في Firestore
  Future<void> _saveProfile() async {
    if (_selectedRole == 'user' && _nameController.text.isEmpty) {
      context.showSnackBar('pleaseFillAllFields'.tr(), isError: true);
      return;
    }

    // التحقق من الحقول الإلزامية حسب الدور (إجبار العميل على إدخال العمر والطول والوزن والجنس ولون البشرة)
    if (_selectedRole == 'user') {
      if (_heightController.text.isEmpty || 
          _weightController.text.isEmpty || 
          _ageController.text.isEmpty || 
          _selectedGender == null || 
          _selectedSkinTone == null) {
        context.showSnackBar('pleaseFillAllFields'.tr(), isError: true);
        return;
      }
    } else {
      if (_storeNameController.text.isEmpty || _storeDescriptionController.text.isEmpty) {
        context.showSnackBar('pleaseFillAllFields'.tr(), isError: true);
        return;
      }
    }

    try {
      setState(() => _isLoading = true);
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user != null) {
        final Map<String, dynamic> userData = {
          'name': _selectedRole == 'merchant' ? _storeNameController.text : _nameController.text,
          'role': _selectedRole,
          'isProfileComplete': true,
        };

        // تجميع البيانات الإضافية للعميل
        if (_selectedRole == 'user') {
          userData.addAll({
            'height': double.tryParse(_heightController.text) ?? 0.0,
            'weight': double.tryParse(_weightController.text) ?? 0.0,
            'age': int.tryParse(_ageController.text) ?? 0,
            'gender': _selectedGender,
            'skinColor': '#${_selectedSkinTone!.toARGB32().toRadixString(16).substring(2)}',
          });
        } else {
          // تجميع البيانات الإضافية للتاجر
          userData.addAll({
            'storeName': _storeNameController.text,
            'storeDescription': _storeDescriptionController.text,
          });
        }

        // إضافة الموقع الجغرافي
        if (_country != null) userData['country'] = _country;
        if (_state != null) {
          userData['province'] = _state;
          userData['city'] = _state; // Use state (Governorate/City) as the city
        }
        userData['locationCompleted'] = _country != null && _state != null;

        // تحديث البيانات في Firestore
        await ref.read(firestoreServiceProvider).updateSettings(user.uid, userData);
        
        // إعادة تحميل الإعدادات لتحديث حالة التطبيق عالمياً
        await ref.read(settingsProvider.notifier).loadRemoteSettings(user.uid);
        
        if (mounted) {
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('CompleteProfileScreen: _saveProfile error: $e');
        context.showSnackBar('errorSavingProfile'.tr(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: context.canPop() ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ) : null,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colorScheme.primary.withValues(alpha: 0.05),
              context.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'completeProfile'.tr(),
                  style: context.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  'personalizeExperience'.tr(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 32),
                
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  borderRadius: 32,
                  child: Column(
                    children: [
                      // إظهار اختيار الدور فقط إذا لم يكن قد تم اختياره مسبقاً من قبل
                      if (!(ref.read(settingsProvider).userData?['isProfileComplete'] ?? false)) ...[
                        _buildRoleToggle(),
                        const SizedBox(height: 24),
                      ],
                      if (_selectedRole == 'user') ...[
                        CustomTextField(
                          label: 'enterName'.tr(),
                          hint: 'John Doe',
                          controller: _nameController,
                        ),
                        const SizedBox(height: 16),
                        // حقول العميل الخاص بالقياسات
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                label: 'height'.tr(),
                                hint: 'cm',
                                controller: _heightController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                label: 'weight'.tr(),
                                hint: 'kg',
                                controller: _weightController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                label: 'age'.tr(),
                                hint: 'yr',
                                controller: _ageController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(child: _buildGenderPicker()),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSkinTonePicker(),
                      ] else ...[
                        // حقول التاجر الخاصة بالمتجر
                        CustomTextField(
                          label: 'storeName'.tr(),
                          hint: 'My Awesome Store',
                          controller: _storeNameController,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: 'storeDescription'.tr(),
                          hint: 'Describe your store...',
                          controller: _storeDescriptionController,
                          maxLines: 3,
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      // حقل اختيار الموقع الجغرافي (الدولة، الولاية، المدينة)
                      CSCPickerPlus(
                        layout: Layout.vertical,
                        showCities: false,
                        stateDropdownLabel: context.locale.languageCode == 'ar' ? 'المدينة' : 'City',
                        countryDropdownLabel: context.locale.languageCode == 'ar' ? 'الدولة' : 'Country',
                        countryStateLanguage: context.locale.languageCode == 'ar' ? CountryStateLanguage.arabic : CountryStateLanguage.englishOrNative,
                        onCountryChanged: (value) => setState(() => _country = value),
                        onStateChanged: (value) => setState(() => _state = value),
                        onCityChanged: (value) {}, // Ignored since showCities is false
                        currentCountry: _country,
                        currentState: _state,
                        currentCity: _city,
                        dropdownDecoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: context.colorScheme.surface,
                            border: Border.all(color: context.colorScheme.onSurface.withValues(alpha: 0.1))),
                        disabledDropdownDecoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.grey.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
                        selectedItemStyle: context.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: context.colorScheme.onSurface),
                        dropdownHeadingStyle: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: context.colorScheme.onSurface),
                        searchBarRadius: 10.0,
                      ),
                      const SizedBox(height: 32),
                      const SizedBox(height: 32),
                      CustomButton(
                        onPressed: _saveProfile,
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
    );
  }

  // واجهة التبديل بين نوع الحساب
  Widget _buildRoleToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('iAmA'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            _roleButton('user', Icons.person_rounded, 'userRole'.tr()),
            const SizedBox(width: 12),
            _roleButton('merchant', Icons.storefront_rounded, 'merchantRole'.tr()),
          ],
        ),
      ],
    );
  }

  // زر اختيار الدور بتأثير حركي
  Widget _roleButton(String role, IconData icon, String label) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? context.colorScheme.primary : context.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? context.colorScheme.primary : context.colorScheme.onSurface.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : context.colorScheme.primary),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : context.colorScheme.onSurface, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // اختيار الجنس
  Widget _buildGenderPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('gender'.tr(), style: context.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _selectedGender == null && _nameController.text.isNotEmpty 
                  ? context.colorScheme.error 
                  : context.colorScheme.onSurface.withValues(alpha: 0.1)
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGender,
              dropdownColor: context.colorScheme.surface,
              style: context.textTheme.bodyLarge?.copyWith(color: context.colorScheme.onSurface),
              hint: Text('gender'.tr(), style: TextStyle(color: context.colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 14)),
              isExpanded: true,
              items: [
                DropdownMenuItem(value: 'male', child: Text('male'.tr())),
                DropdownMenuItem(value: 'female', child: Text('female'.tr())),
              ],
              onChanged: (val) => setState(() => _selectedGender = val),
            ),
          ),
        ),
      ],
    );
  }

  // اختيار لون البشرة
  Widget _buildSkinTonePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('skinTone'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _skinTones.map((color) {
            final isSelected = _selectedSkinTone == color;
            return InkWell(
              onTap: () => setState(() => _selectedSkinTone = color),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: isSelected ? context.colorScheme.primary : Colors.transparent, width: 3),
                  boxShadow: isSelected ? [BoxShadow(color: context.colorScheme.primary.withValues(alpha: 0.3), blurRadius: 8)] : [],
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

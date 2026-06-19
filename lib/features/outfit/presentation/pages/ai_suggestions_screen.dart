import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/cloudinary_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/models/closet_item_model.dart';
import '../../../../core/models/outfit_model.dart';
import '../../../../core/services/outfit_generator_service.dart';
import '../../../../core/services/ai_model_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

// شاشة اقتراحات الذكاء الاصطناعي (AI Suggestions Screen)
// تقوم بتحليل صور الملابس واستخراج النوع واللون ثم اقتراح تنسيقات مناسبة من الخزانة أو المتجر
class AISuggestionsScreen extends StatefulWidget {
  const AISuggestionsScreen({super.key});

  @override
  State<AISuggestionsScreen> createState() => _AISuggestionsScreenState();
}

class _AISuggestionsScreenState extends State<AISuggestionsScreen> {
  File? _image; // ملف الصورة الأساسية
  List<File> _selectedFiles = []; // قائمة الملفات المختارة للمعالجة
  bool _isLoading = false;
  bool _isModelsLoaded = false;
  String _predictedColor = '';
  String _predictedType = '';
  String? _predictedSleeve;
  String _selectedSeason = 'summer';
  bool _showConfirmButton = false;
  Uint8List? _processedImageBytes;
  Uint8List? _maskOverlayBytes;

  // خيارات التنسيق التي يمكن للمستخدم اختيارها وتعديلها
  final List<Map<String, String>> _matchingOptions = [
    {'id': 'trousers'},
    {'id': 'shoes'},
    {'id': 'jacket'},
    {'id': 'shirt'},
    {'id': 'hat'},
  ];
  final Set<String> _selectedMatchingGroups = {};

  // ثوابت الألوان للتصميم الداكن الفاخر
  static const Color kDeepCharcoal = Color(0xFF121212);
  static const Color kDarkSlateGrey = Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    _initModels(); // تحميل النماذج عند بدء الشاشة
  }

  // تحميل نماذج الذكاء الاصطناعي والكشف عن الموسم الحالي
  Future<void> _initModels() async {
    _detectCurrentSeason(); // تحديد الموسم تلقائياً
    try {
      await AIModelService()
          .loadModels(); // الاعتماد على الخدمة المركزية الموحدة
      if (mounted) {
        setState(() {
          _isModelsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading models: $e');
      if (mounted) {
        context.showSnackBar(
          'failedToLoadAIModels'.tr(args: [e.toString()]),
          isError: true,
        );
      }
    }
  }

  // تحديد الموسم تلقائياً بناءً على تاريخ اليوم
  void _detectCurrentSeason() {
    final month = DateTime.now().month;
    // الأشهر من 4 إلى 9 تعتبر صيفية، ومن 10 إلى 3 تعتبر شتوية
    if (month >= 4 && month <= 9) {
      _selectedSeason = 'summer';
    } else {
      _selectedSeason = 'winter';
    }
  }

  // طلب صلاحيات الوصول للصور بشكل احترافي
  Future<bool> _requestPermission() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) return true;
    if (mounted) {
      context.showSnackBar(
        'نحتاج لصلاحية الوصول للصور لاختيار ملابسك 📸',
        isError: true,
      );
    }
    return false;
  }

  // اختيار الصور باستخدام wechat_assets_picker بإعدادات فائقة السرعة
  Future<void> _pickAssets() async {
    final hasPermission = await _requestPermission();
    if (!hasPermission) return;
    if (!mounted) return;

    final List<AssetEntity>? result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 10, // السماح باختيار حتى 10 قطع
        requestType: RequestType.image,
        gridCount: 4, // مثل واتساب
        pageSize: 80, // Lazy Loading
        textDelegate: const ArabicAssetPickerTextDelegate(),
        pickerTheme: AssetPicker.themeData(context.colorScheme.primary),
      ),
    );

    if (result != null && result.isNotEmpty) {
      final List<File> files = [];
      for (final asset in result) {
        final file = await asset.file;
        if (file != null) files.add(file);
      }

      setState(() {
        _selectedFiles = files;
        _image = files.first; // نستخدم الأولى كصورة أساسية للعرض
        _detectedItems = [];
        _showConfirmButton = false;
        _processedImageBytes = null;
        _maskOverlayBytes = null;
      });
    }
  }

  // اختيار من الكاميرا
  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() {
        _selectedFiles = [file];
        _image = file;
        _detectedItems = [];
        _showConfirmButton = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      await _pickFromCamera();
    } else {
      await _pickAssets();
    }
  }

  List<Map<String, dynamic>> _detectedItems = []; // قائمة القطع المكتشفة
  int _selectedItemIndex = 0; // القطعة المختارة حالياً

  // تشغيل الاستدلال على كافة الصور المختارة
  Future<void> _runInference() async {
    if (_selectedFiles.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final aiService = AIModelService();
      final List<Map<String, dynamic>> allResults = [];

      for (final file in _selectedFiles) {
        final results = await aiService.analyzeImage(file);
        allResults.addAll(results);
      }

      // توليد صورة الـ Mask Overlay لأول صورة كمثال (أو دمجها)
      Uint8List? overlayBytes;
      if (allResults.isNotEmpty) {
        try {
          final originalImg = img.decodeImage(
            _selectedFiles.first.readAsBytesSync(),
          );
          if (originalImg != null) {
            final overlayImg = aiService.generateMaskOverlay(
              originalImg,
              allResults,
            );
            overlayBytes = Uint8List.fromList(img.encodePng(overlayImg));
          }
        } catch (e) {
          debugPrint('Error generating overlay: $e');
        }
      }

      setState(() {
        _detectedItems = allResults;
        _maskOverlayBytes = overlayBytes;
        if (_detectedItems.isNotEmpty) {
          _updateSelectedData(0);
        }
        _showConfirmButton = true;
      });
    } catch (e) {
      debugPrint('Error running multi-image inference: $e');
      if (mounted) {
        context.showSnackBar('حدث خطأ أثناء تحليل الصور', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateSelectedData(int index) {
    if (index >= _detectedItems.length) return;
    final item = _detectedItems[index];
    setState(() {
      _selectedItemIndex = index;
      // كود تشخيصي للتأكد من نوع البيانات ومنع الانهيار
      final colorData = item['color'];
      final categoryData = item['category'];

      if (colorData is Future) {
        debugPrint(
          'CRITICAL: color is still a Future! This means the build is STALE.',
        );
        _predictedColor = 'جاري التحميل...';
      } else {
        _predictedColor = (colorData as String?) ?? 'غير معروف';
      }

      if (categoryData is Future) {
        debugPrint('CRITICAL: category is still a Future!');
        _predictedType = 'جاري التحميل...';
      } else {
        _predictedType = (categoryData as String?) ?? 'غير معروف';
      }

      _predictedSleeve = item['sleeve'] as String?;
      _processedImageBytes = item['imageBytes'] as Uint8List?;

      // تحديد خيارات التنسيق التلقائية بناءً على نوع القطعة المكتشفة
      _selectedMatchingGroups.clear();
      final cat = _predictedType.toLowerCase();

      final tops = [
        'top',
        'dress',
        'outerwear',
        'blazer',
        'coat',
        'denim_jacket',
        'hoodie',
        'jacket',
        'polo',
        'shirt',
        'shirt2',
        'sweater',
        't_shirt',
        'track_jacket',
      ];
      final bottoms = ['pants', 'shorts', 'skirt', 'rok', 'trousers', 'jeans'];
      final shoes = ['shoes', 'boots', 'sneakers', 'heels', 'sandals'];

      if (tops.contains(cat)) {
        _selectedMatchingGroups.addAll(['trousers', 'shoes']);
      } else if (bottoms.contains(cat)) {
        _selectedMatchingGroups.addAll(['shirt', 'shoes']);
      } else if (shoes.contains(cat)) {
        _selectedMatchingGroups.addAll(['trousers', 'shirt']);
      } else {
        _selectedMatchingGroups.addAll(['trousers', 'shoes']);
      }
    });
  }

  // التعامل مع عملية التأكيد والرفع بناءً على خيار المستخدم
  Future<void> _handleConfirm({required bool showSuggestions}) async {
    if (_image == null) return;

    setState(() => _isLoading = true);
    try {
      await _uploadToCloudinary(
        showSuggestions: showSuggestions,
      ); // الرفع السحابي ثم الحفظ في Firestore
      if (mounted) {
        context.showSnackBar('تمت الإضافة بنجاح ✨');
        setState(() {
          _showConfirmButton = false;
        });
      }
    } catch (e) {
      if (mounted) context.showSnackBar('خطأ في الرفع: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // رفع الصورة لـ Cloudinary وحفظ البيانات المكتشفة في مجموعات Firestore
  Future<void> _uploadToCloudinary({required bool showSuggestions}) async {
    if (_image == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. الرفع لـ Cloudinary للحصول على رابط الصورة (نرفع الصورة المفرغة إذا وجدت)
    String? imageUrl;
    if (_processedImageBytes != null) {
      // تحويل الـ Bytes لملف مؤقت للرفع
      final tempFile = File('${Directory.systemTemp.path}/cropped_item.png');
      await tempFile.writeAsBytes(_processedImageBytes!);
      imageUrl = await CloudinaryService.uploadImage(
        tempFile,
        folder: 'closet_items/${user.uid}',
      );
    } else {
      imageUrl = await CloudinaryService.uploadImage(
        _image!,
        folder: 'ai_suggestions/${user.uid}',
      );
    }

    if (imageUrl == null) throw Exception('Upload failed');

    // 2. الحفظ في سجل الاقتراحات
    await FirebaseFirestore.instance.collection('ai_suggestions').add({
      'userId': user.uid,
      'imageUrl': imageUrl,
      'predictedColor': _predictedColor,
      'predictedType': _predictedType,
      'predictedSleeve': _predictedSleeve,
      'season': _selectedSeason,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 3. الإضافة للخزانة الرقمية للمستخدم (User_Closet)
    final docRef = await FirebaseFirestore.instance
        .collection('User_Closet')
        .add({
          'userID': user.uid,
          'imageUrl': imageUrl,
          'category': _predictedType,
          'sleeve': _predictedSleeve,
          'color': _predictedColor,
          'season': _selectedSeason,
          'timestamp': FieldValue.serverTimestamp(),
        });

    // تحويل البيانات لنموذج ClosetItemModel لاستخدامه في محرك التنسيق
    final newItem = ClosetItemModel(
      id: docRef.id,
      userID: user.uid,
      imageUrl: imageUrl,
      category: _predictedType,
      color: _predictedColor,
      season: _selectedSeason,
    );

    // 4. توليد تنسيق ذكي وتنسيق مقترح من المتاجر (فقط إذا طلب المستخدم ذلك)
    if (showSuggestions) {
      final targetGroups = _selectedMatchingGroups.toList();
      final outfit = await OutfitGeneratorService().generateSmartOutfit(
        newItem,
        targetGroups: targetGroups,
      );
      final storeMatches = await OutfitGeneratorService().generateStoreMatches(
        newItem,
        targetGroups: targetGroups,
      );

      if (mounted) {
        _showSuccessDialog(
          context,
          newItem,
          outfit,
          storeMatches,
        ); // إظهار النتائج للمستخدم
      }
    }

    // إرسال إشعار محلي بالنجاح
    await NotificationService.showLocalNotification(
      title: 'greatAdditionCloset'.tr(),
      body: 'addedSuccessfullyWithColor'.tr(
        args: [_predictedType.tr(), _getColorNameInArabic(_predictedColor)],
      ),
      payload: '/matching',
    );
  }

  // إظهار حوار النجاح مع تبويبات للتنسيق من الخزانة أو المتاجر
  void _showSuccessDialog(
    BuildContext context,
    ClosetItemModel item,
    OutfitModel? outfit,
    List<StoreProductModel> storeMatches,
  ) {
    int selectedTab = 0; // 0 للخزانة، 1 للمتجر

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: context.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 50,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'successfullyAdded'.tr(),
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // شريط التبديل بين الخزانة والمتجر داخل الحوار
                  Container(
                    decoration: BoxDecoration(
                      color: context.colorScheme.primary.withValues(
                        alpha: 0.05,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        _dialogTab(
                          context,
                          'myWardrobe'.tr(),
                          selectedTab == 0,
                          () => setDialogState(() => selectedTab = 0),
                        ),
                        _dialogTab(
                          context,
                          'shopMatching'.tr(),
                          selectedTab == 1,
                          () => setDialogState(() => selectedTab = 1),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // عرض النتائج بناءً على التبويب المختار
                  if (selectedTab == 0) ...[
                    if (outfit != null) ...[
                      _buildMatchSection(
                        context,
                        'smartSuggestionNewItem'.tr(),
                        outfit.itemImageUrls,
                      ),
                    ] else
                      _buildEmptyMatch(context, 'noMatchingItemsCloset'.tr()),
                  ] else ...[
                    if (storeMatches.isNotEmpty) ...[
                      // عرض جميع المنتجات المتاحة في المتاجر المتوافقة مع القطعة
                      ...storeMatches
                          .take(5)
                          .map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildStoreMatch(context, p),
                            ),
                          ),
                    ] else
                      _buildEmptyMatch(context, 'noMatchingItemsShops'.tr()),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.pop(context); // إغلاق الحوار
                        Navigator.pop(context); // العودة للشاشة الرئيسية
                      },
                      child: Text(
                        'greatThanks'.tr(),
                        style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ودجت لتبويب داخل الحوار
  Widget _dialogTab(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? context.colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : context.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  // عرض قسم التنسيقات (صور مصفوفة أفقياً)
  Widget _buildMatchSection(
    BuildContext context,
    String title,
    List<String> images,
  ) {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.tajawal(
            fontSize: 13,
            color: context.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: images
              .map(
                (url) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      height: 70,
                      width: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // عرض تنسيق مقترح من المتجر مع تفاصيل المنتج وزر للشراء مع نسبة تناسق وهمية للتوضيح
  Widget _buildStoreMatch(BuildContext context, StoreProductModel product) {
    // محاكاة لنسبة التناسق بناءً على اللون (تصميمي فقط لمواكبة متطلب العميل)
    final matchScore = (90 + (product.name.length % 10));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            border: Border.all(
              color: context.colorScheme.primary.withValues(alpha: 0.1),
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      height: 60,
                      width: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '%$matchScore',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '${product.price} ر.س',
                      style: TextStyle(
                        color: context.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.shopping_cart_checkout_rounded,
                  color: Colors.blueAccent,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('جاري الانتقال للمتجر: ${product.name}'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyMatch(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.tajawal(fontSize: 12, color: Colors.grey),
      ),
    );
  }

  // الحصول على اسم اللون المترجم للعرض
  String _getColorNameInArabic(String name) {
    final key = name.toLowerCase().trim();
    if (key == 'teal') return 'turquoise'.tr();
    return key.tr() == key ? 'distinctive'.tr() : key.tr();
  }

  // الحصول على كائن Color من اسم اللون النصي للمعالجة في الواجهة
  Color _getColorFromName(String name) {
    switch (name.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'yellow':
        return Colors.yellow;
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'grey':
        return Colors.grey;
      case 'brown':
        return Colors.brown;
      case 'pink':
        return Colors.pink;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'silver':
        return const Color(0xFFC0C0C0);
      case 'navy':
        return const Color(0xFF000080);
      case 'beige':
        return const Color(0xFFF5F5DC);
      case 'maroon':
        return const Color(0xFF800000);
      case 'olive':
        return const Color(0xFF808000);
      case 'teal':
        return const Color(0xFF008080);
      case 'cream':
        return const Color(0xFFFFFDD0);
      case 'gold':
        return const Color(0xFFFFD700);
      case 'khaki':
        return const Color(0xFFF0E68C);
      default:
        return Colors.white10;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: kDeepCharcoal,
        textTheme: GoogleFonts.tajawalTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Colors.white70,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'outfitSuggestions'.tr(),
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kDeepCharcoal, Color(0xFF0A0A0A)],
            ),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                _buildSelectionPreview(), // شريط معاينة الصور المختارة
                const SizedBox(height: 20),
                _buildImageSection(), // عرض الصورة المختارة
                if (_detectedItems.isNotEmpty && !_isLoading) ...[
                  const SizedBox(height: 24),
                  _buildDetectedItemsList(),
                ],
                const SizedBox(height: 40),
                if (_isLoading)
                  _buildLoadingState() // حالة التحميل والتحليل
                else ...[
                  if (!_isModelsLoaded)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white30),
                    )
                  else ...[
                    _buildActionButtons(), // أزرار التقاط/اختيار الصورة
                    const SizedBox(height: 32),
                    if (_predictedColor.isNotEmpty)
                      _buildResultsSection(), // عرض الفئة واللون المكتشفين
                  ],
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // بناء قسم عرض الصورة بتصميم زجاجي وظلال عميقة مع دعم الـ Mask Overlay
  Widget _buildImageSection() {
    return Hero(
      tag: 'ai_suggestion_img',
      child: Container(
        height: 420,
        width: double.infinity,
        decoration: BoxDecoration(
          color: kDarkSlateGrey,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.02),
              blurRadius: 0,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: _processedImageBytes != null
              ? Container(
                  color: context.colorScheme.surface.withValues(
                    alpha: 0.05,
                  ), // خلفية خفيفة للشفافية
                  child: Stack(
                    children: [
                      Center(
                        child: Image.memory(
                          _processedImageBytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Positioned(
                        top: 20,
                        right: 20,
                        child: _buildBadge('selectedPiece'.tr()),
                      ),
                    ],
                  ),
                )
              : (_maskOverlayBytes != null
                    ? Stack(
                        children: [
                          Image.memory(
                            _maskOverlayBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                          Positioned(
                            top: 20,
                            right: 20,
                            child: _buildBadge('clothingAnalyzed'.tr()),
                          ),
                        ],
                      )
                    : (_image != null
                          ? Image.file(_image!, fit: BoxFit.cover)
                          : _buildEmptyStateContent())),
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        style: GoogleFonts.tajawal(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyStateContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.document_scanner_outlined,
          size: 64,
          color: Colors.white.withValues(alpha: 0.1),
        ),
        const SizedBox(height: 24),
        Text(
          'captureClothes'.tr(),
          style: GoogleFonts.tajawal(
            color: Colors.white38,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildGlassButton(
            'camera'.tr(),
            Icons.camera_outlined,
            () => _pickImage(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildGlassButton(
            'gallery'.tr(),
            Icons.image_outlined,
            () => _pickImage(ImageSource.gallery),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassButton(String title, IconData icon, VoidCallback onTap) {
    return GlassCard(
      borderRadius: 24,
      opacity: 0.05,
      blur: 20,
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.1),
        width: 0.5,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, size: 28, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // بناء قسم نتائج التحليل مع الرسوم المتحركة
  Widget _buildResultsSection() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4.0, bottom: 16),
            child: Text(
              'analysisResults'.tr(),
              style: GoogleFonts.tajawal(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GlassCard(
            borderRadius: 30,
            opacity: 0.03,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildAnalysisRow(
                  'predictedColorLabel'.tr(),
                  _predictedColor.toLowerCase().tr(),
                  isColor: true,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: Colors.white12, height: 1),
                ),
                _buildAnalysisRow(
                  'predictedTypeLabel'.tr(),
                  _predictedType.tr(),
                ),
                if (_predictedSleeve != null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: Colors.white12, height: 1),
                  ),
                  _buildAnalysisRow(
                    'predictedSleeveLabel'.tr(),
                    _predictedSleeve!.tr(),
                  ),
                ],
              ],
            ),
          ),
          if (_showConfirmButton) ...[
            const SizedBox(height: 24),
            _buildMatchingPreferencesSection(),
            const SizedBox(height: 24),
            _buildChoiceButtons(), // عرض خياري التنسيق أو الحفظ فقط
          ],
        ],
      ),
    );
  }

  // بناء قسم تفضيلات التنسيق (Chips لاختيار القطع المراد تلبيقها)
  Widget _buildMatchingPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4.0, bottom: 12),
          child: Text(
            'matchSuggestionInstructions'.tr(),
            style: GoogleFonts.tajawal(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        GlassCard(
          borderRadius: 24,
          opacity: 0.03,
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _matchingOptions.map((opt) {
              final isSelected = _selectedMatchingGroups.contains(opt['id']);
              final label = 'matching_${opt['id']}'.tr();
              return FilterChip(
                label: Text(label),
                selected: isSelected,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                selectedColor: context.colorScheme.primary,
                labelStyle: GoogleFonts.tajawal(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected
                        ? context.colorScheme.primary
                        : Colors.white10,
                    width: 1,
                  ),
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedMatchingGroups.add(opt['id']!);
                    } else {
                      _selectedMatchingGroups.remove(opt['id']!);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // بناء أزرار الخيارات بعد التحليل (تنسيق أو حفظ فقط)
  Widget _buildChoiceButtons() {
    return Column(
      children: [
        _buildAnimatedChoice(
          title: 'showMatchingOptions'.tr(),
          description: 'showMatchingOptionsDesc'.tr(),
          icon: Icons.auto_awesome_rounded,
          onTap: () => _handleConfirm(showSuggestions: true),
          isPrimary: true,
        ),
        const SizedBox(height: 16),
        _buildAnimatedChoice(
          title: 'savePhotoOnly'.tr(),
          description: 'savePhotoOnlyDesc'.tr(),
          icon: Icons.save_alt_rounded,
          onTap: () => _handleConfirm(showSuggestions: false),
          isPrimary: false,
        ),
      ],
    );
  }

  // ودجت زر اختيار مخصص مع تأثيرات بصرية فاخرة
  Widget _buildAnimatedChoice({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: isPrimary
            ? LinearGradient(
                colors: [
                  context.colorScheme.primary,
                  context.colorScheme.primary.withValues(alpha: 0.8),
                ],
              )
            : null,
        color: !isPrimary ? Colors.white.withValues(alpha: 0.05) : null,
        border: !isPrimary
            ? Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1)
            : null,
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: context.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? Colors.white.withValues(alpha: 0.2)
                        : context.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isPrimary
                        ? Colors.white
                        : context.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.bold,
                          color: isPrimary
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        description,
                        style: GoogleFonts.tajawal(
                          color: isPrimary ? Colors.white70 : Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isPrimary ? Colors.white54 : Colors.white24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisRow(String title, String value, {bool isColor = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.tajawal(color: Colors.white38, fontSize: 14),
        ),
        Row(
          children: [
            if (isColor) ...[
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _getColorFromName(_predictedColor),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              value,
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return GlassCard(
      borderRadius: 30,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          const CircularProgressIndicator(
            color: Colors.white24,
            strokeWidth: 2,
          ),
          const SizedBox(height: 24),
          Text(
            'extractingStyleMagic'.tr(),
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // بناء قائمة القطع المكتشفة للتنقل بينها
  Widget _buildDetectedItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'selectItemForAnalysis'.tr(),
            style: GoogleFonts.tajawal(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _detectedItems.length,
            itemBuilder: (context, index) {
              final item = _detectedItems[index];
              final bool isSelected = _selectedItemIndex == index;
              final Uint8List bytes = item['imageBytes'];

              return GestureDetector(
                onTap: () => _updateSelectedData(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(left: 12),
                  width: 90,
                  decoration: BoxDecoration(
                    color: kDarkSlateGrey,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? context.colorScheme.primary
                          : Colors.white.withValues(alpha: 0.05),
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: context.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 10,
                            ),
                          ]
                        : [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      children: [
                        Center(
                          child: Image.memory(
                            bytes,
                            fit: BoxFit.contain,
                            height: 70,
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: context.colorScheme.primary,
                              child: const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // بناء شريط معاينة الصور المختارة قبل المعالجة
  Widget _buildSelectionPreview() {
    if (_selectedFiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'selectedPhotosCount'.tr(args: [_selectedFiles.length.toString()]),
            style: GoogleFonts.tajawal(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _selectedFiles.length,
            itemBuilder: (context, index) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10, width: 1),
                      image: DecorationImage(
                        image: FileImage(_selectedFiles[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFiles.removeAt(index);
                          if (_selectedFiles.isEmpty) {
                            _image = null;
                            _detectedItems = [];
                            _showConfirmButton = false;
                          } else {
                            _image = _selectedFiles.first;
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (!_showConfirmButton && !_isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _runInference,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  'clothingAnalysisStarted'.tr(),
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 10,
                  shadowColor: context.colorScheme.primary.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

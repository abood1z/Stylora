import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../core/services/data_providers.dart';
import '../../../../core/services/ai_tryon_service.dart';
import '../../../../core/models/closet_item_model.dart';
import '../../../../core/widgets/full_screen_image_viewer.dart';

class TryOnColor {
  final String id;
  final String nameAr;
  final String nameEn;
  final Color color;

  const TryOnColor({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.color,
  });
}

const List<TryOnColor> _allColors = [
  TryOnColor(id: 'black', nameAr: 'أسود', nameEn: 'Black', color: Colors.black),
  TryOnColor(id: 'white', nameAr: 'أبيض', nameEn: 'White', color: Colors.white),
  TryOnColor(id: 'grey', nameAr: 'رمادي', nameEn: 'Grey', color: Colors.grey),
  TryOnColor(id: 'navy', nameAr: 'كحلي', nameEn: 'Navy Blue', color: Color(0xFF000080)),
  TryOnColor(id: 'blue', nameAr: 'أزرق', nameEn: 'Blue', color: Colors.blue),
  TryOnColor(id: 'sky_blue', nameAr: 'سماوي / أزرق فاتح', nameEn: 'Sky Blue', color: Colors.lightBlue),
  TryOnColor(id: 'royal_blue', nameAr: 'أزرق ملكي', nameEn: 'Royal Blue', color: Color(0xFF4169E1)),
  TryOnColor(id: 'midnight_blue', nameAr: 'كحلي داكن جداً', nameEn: 'Midnight Blue', color: Color(0xFF191970)),
  TryOnColor(id: 'teal', nameAr: 'تركواز / أزرق مخضر', nameEn: 'Teal', color: Color(0xFF008080)),
  TryOnColor(id: 'turquoise', nameAr: 'تركواز فاتح', nameEn: 'Turquoise', color: Color(0xFF40E0D0)),
  TryOnColor(id: 'cyan', nameAr: 'سماوي', nameEn: 'Cyan', color: Colors.cyan),
  TryOnColor(id: 'aquamarine', nameAr: 'أكوامارين', nameEn: 'Aquamarine', color: Color(0xFF7FFFD4)),
  TryOnColor(id: 'green', nameAr: 'أخضر', nameEn: 'Green', color: Colors.green),
  TryOnColor(id: 'dark_green', nameAr: 'أخضر داكن', nameEn: 'Dark Green', color: Color(0xFF006400)),
  TryOnColor(id: 'forest_green', nameAr: 'أخضر الغابة', nameEn: 'Forest Green', color: Color(0xFF228B22)),
  TryOnColor(id: 'lime', nameAr: 'أخضر ليموني', nameEn: 'Lime', color: Color(0xFF00FF00)),
  TryOnColor(id: 'olive', nameAr: 'زيتوني', nameEn: 'Olive', color: Color(0xFF808000)),
  TryOnColor(id: 'mint', nameAr: 'نعناعي', nameEn: 'Mint Green', color: Color(0xFF98FF98)),
  TryOnColor(id: 'beige', nameAr: 'بيج', nameEn: 'Beige', color: Color(0xFFF5F5DC)),
  TryOnColor(id: 'cream', nameAr: 'كريمي', nameEn: 'Cream', color: Color(0xFFFFFDD0)),
  TryOnColor(id: 'ivory', nameAr: 'عاجي', nameEn: 'Ivory', color: Color(0xFFFFFFF0)),
  TryOnColor(id: 'khaki', nameAr: 'كاكي', nameEn: 'Khaki', color: Color(0xFFF0E68C)),
  TryOnColor(id: 'mustard', nameAr: 'خردلي', nameEn: 'Mustard', color: Color(0xFFFFDB58)),
  TryOnColor(id: 'yellow', nameAr: 'أصفر', nameEn: 'Yellow', color: Colors.yellow),
  TryOnColor(id: 'gold', nameAr: 'ذهبي', nameEn: 'Gold', color: Color(0xFFFFD700)),
  TryOnColor(id: 'orange', nameAr: 'برتقالي', nameEn: 'Orange', color: Colors.orange),
  TryOnColor(id: 'coral', nameAr: 'مرجاني', nameEn: 'Coral', color: Color(0xFFFF7F50)),
  TryOnColor(id: 'salmon', nameAr: 'سلموني', nameEn: 'Salmon', color: Color(0xFFFA8072)),
  TryOnColor(id: 'red', nameAr: 'أحمر', nameEn: 'Red', color: Colors.red),
  TryOnColor(id: 'dark_red', nameAr: 'أحمر داكن', nameEn: 'Dark Red', color: Color(0xFF8B0000)),
  TryOnColor(id: 'maroon', nameAr: 'عنابي', nameEn: 'Maroon', color: Color(0xFF800000)),
  TryOnColor(id: 'burgundy', nameAr: 'برغندي', nameEn: 'Burgundy', color: Color(0xFF800020)),
  TryOnColor(id: 'pink', nameAr: 'وردي', nameEn: 'Pink', color: Colors.pink),
  TryOnColor(id: 'hot_pink', nameAr: 'وردي فاقع', nameEn: 'Hot Pink', color: Color(0xFFFF69B4)),
  TryOnColor(id: 'light_pink', nameAr: 'وردي فاتح', nameEn: 'Light Pink', color: Color(0xFFFFB6C1)),
  TryOnColor(id: 'purple', nameAr: 'بنفسجي', nameEn: 'Purple', color: Colors.purple),
  TryOnColor(id: 'lavender', nameAr: 'خزامى / لافندر', nameEn: 'Lavender', color: Color(0xFFE6E6FA)),
  TryOnColor(id: 'violet', nameAr: 'بنفسجي فاتح', nameEn: 'Violet', color: Color(0xFFEE82EE)),
  TryOnColor(id: 'mauve', nameAr: 'موف', nameEn: 'Mauve', color: Color(0xFFE0B0FF)),
  TryOnColor(id: 'plum', nameAr: 'خوخي داكن', nameEn: 'Plum', color: Color(0xFFDDA0DD)),
  TryOnColor(id: 'brown', nameAr: 'بني', nameEn: 'Brown', color: Colors.brown),
  TryOnColor(id: 'chocolate', nameAr: 'شوكولاتة', nameEn: 'Chocolate', color: Color(0xFFD2691E)),
  TryOnColor(id: 'coffee', nameAr: 'قهوة', nameEn: 'Coffee Brown', color: Color(0xFF6F4E37)),
  TryOnColor(id: 'tan', nameAr: 'برونزي فاتح', nameEn: 'Tan', color: Color(0xFFD2B48C)),
  TryOnColor(id: 'sand', nameAr: 'رملي', nameEn: 'Sand', color: Color(0xFFC2B280)),
  TryOnColor(id: 'bronze', nameAr: 'برونزي', nameEn: 'Bronze', color: Color(0xFFCD7F32)),
  TryOnColor(id: 'silver', nameAr: 'فضي', nameEn: 'Silver', color: Color(0xFFC0C0C0)),
  TryOnColor(id: 'charcoal', nameAr: 'فحمي', nameEn: 'Charcoal', color: Color(0xFF36454F)),
  TryOnColor(id: 'off_white', nameAr: 'أوف وايت', nameEn: 'Off-White', color: Color(0xFFFAF9F6)),
  TryOnColor(id: 'peach', nameAr: 'خوخي', nameEn: 'Peach', color: Color(0xFFFFDAB9)),
  TryOnColor(id: 'apricot', nameAr: 'مشمشي', nameEn: 'Apricot', color: Color(0xFFFBCEB1)),
  TryOnColor(id: 'amber', nameAr: 'كهرماني', nameEn: 'Amber', color: Color(0xFFFFBF00)),
  TryOnColor(id: 'emerald', nameAr: 'زمردي', nameEn: 'Emerald Green', color: Color(0xFF50C878)),
  TryOnColor(id: 'sapphire', nameAr: 'ياقوت أزرق', nameEn: 'Sapphire Blue', color: Color(0xFF0F52BA)),
  TryOnColor(id: 'ruby', nameAr: 'ياقوتي أحمر', nameEn: 'Ruby Red', color: Color(0xFFE0115F)),
  TryOnColor(id: 'fuchsia', nameAr: 'فوشيا', nameEn: 'Fuchsia', color: Color(0xFFFF00FF)),
  TryOnColor(id: 'khaki_dark', nameAr: 'كاكي داكن', nameEn: 'Dark Khaki', color: Color(0xFFBDB76B)),
  TryOnColor(id: 'steel_blue', nameAr: 'أزرق فولاذي', nameEn: 'Steel Blue', color: Color(0xFF4682B4)),
  TryOnColor(id: 'powder_blue', nameAr: 'أزرق بودرة', nameEn: 'Powder Blue', color: Color(0xFFB0E0E6)),
  TryOnColor(id: 'olive_drab', nameAr: 'زيتوني داكن', nameEn: 'Olive Drab', color: Color(0xFF6B8E23)),
  TryOnColor(id: 'sea_green', nameAr: 'أخضر بحري', nameEn: 'Sea Green', color: Color(0xFF2E8B57)),
  TryOnColor(id: 'spring_green', nameAr: 'أخضر ربيعي', nameEn: 'Spring Green', color: Color(0xFF00FF7F)),
  TryOnColor(id: 'lemon_chiffon', nameAr: 'ليموني باهت', nameEn: 'Lemon Chiffon', color: Color(0xFFFFFACD)),
  TryOnColor(id: 'moccasin', nameAr: 'موكاسين', nameEn: 'Moccasin', color: Color(0xFFFFE4B5)),
  TryOnColor(id: 'lavender_blush', nameAr: 'وردي خفيف خزامى', nameEn: 'Lavender Blush', color: Color(0xFFFFF0F5)),
  TryOnColor(id: 'misty_rose', nameAr: 'وردي ضبابي', nameEn: 'Misty Rose', color: Color(0xFFFFE4E1)),
  TryOnColor(id: 'cadet_blue', nameAr: 'أزرق كاديت', nameEn: 'Cadet Blue', color: Color(0xFF5F9EA0)),
  TryOnColor(id: 'dodger_blue', nameAr: 'أزرق دودجر', nameEn: 'Dodger Blue', color: Color(0xFF1E90FF)),
  TryOnColor(id: 'indigo', nameAr: 'نيلي', nameEn: 'Indigo', color: Color(0xFF4B0082)),
  TryOnColor(id: 'lime_green', nameAr: 'أخضر ليموني زاهي', nameEn: 'Lime Green', color: Color(0xFF32CD32)),
  TryOnColor(id: 'pale_green', nameAr: 'أخضر باهت', nameEn: 'Pale Green', color: Color(0xFF98FB98)),
  TryOnColor(id: 'light_cyan', nameAr: 'سماوي فاتح جداً', nameEn: 'Light Cyan', color: Color(0xFFE0FFFF)),
];

class VirtualTryOnScreen extends ConsumerStatefulWidget {
  const VirtualTryOnScreen({super.key});

  @override
  ConsumerState<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends ConsumerState<VirtualTryOnScreen> {
  // إعدادات الاتصال
  bool _useLocalServer = true; // القيمة الافتراضية تشغيل محلي
  String _replicateToken = "";
  String _localServerUrl = "https://subpar-eel-badness.ngrok-free.dev/tryon";

  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _localServerController = TextEditingController();

  // خيارات الصور البشرية (عارضون افتراضيون)
  final List<Map<String, String>> _defaultModels = [
    {
      "name": "Model Female 1",
      "url":
          "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600&auto=format&fit=crop",
    },
    {
      "name": "Model Male 1",
      "url":
          "https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=600&auto=format&fit=crop",
    },
    {
      "name": "Model Female 2",
      "url":
          "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=600&auto=format&fit=crop",
    },
  ];

  // البيانات المحددة
  dynamic _selectedPerson; // File (مرفوعة) أو String (رابط URL لعارض افتراضي)
  dynamic _selectedGarment; // File (مرفوعة) أو ClosetItemModel (من الخزانة)

  String _selectedCategoryDetail = "top";
  String _selectedColorDetail = "white";
  String _selectedSleeveDetail = "short_sleeve";
  String _searchQuery = "";

  final List<Map<String, String>> _categoriesDetail = [
    {"id": "top", "nameAr": "ملابس علوية / تيشرت", "nameEn": "Top / Tee"},
    {"id": "outerwear", "nameAr": "ملابس خارجية / جاكيت", "nameEn": "Outerwear / Jacket"},
    {"id": "dress", "nameAr": "فستان", "nameEn": "Dress"},
    {"id": "pants", "nameAr": "بنطال", "nameEn": "Pants / Trousers"},
    {"id": "shorts", "nameAr": "شورت", "nameEn": "Shorts"},
    {"id": "skirt", "nameAr": "تنورة", "nameEn": "Skirt"},
    {"id": "sling", "nameAr": "حمالات / كتف مكشوف", "nameEn": "Sling / Strapless"},
    {"id": "heels", "nameAr": "كعب عالي (غير مدعوم بالكامل)", "nameEn": "Heels (Not fully supported)"},
    {"id": "sandals", "nameAr": "صندل (غير مدعوم بالكامل)", "nameEn": "Sandals (Not fully supported)"},
    {"id": "sneakers", "nameAr": "حذاء رياضي (غير مدعوم بالكامل)", "nameEn": "Sneakers (Not fully supported)"},
  ];

  final List<Map<String, String>> _sleevesDetail = [
    {"id": "long_sleeve", "nameAr": "أكمام طويلة", "nameEn": "Long Sleeve"},
    {"id": "short_sleeve", "nameAr": "أكمام قصيرة", "nameEn": "Short Sleeve"},
    {"id": "sleeveless", "nameAr": "بدون أكمام", "nameEn": "Sleeveless"},
  ];

  void _updateGeneratedDescription() {
    final color = _selectedColorDetail;
    final sleeve = _selectedSleeveDetail.replaceAll('_', ' ');
    final category = _selectedCategoryDetail;
    _descriptionController.text = "$color $sleeve $category";
  }

  String _getColorNameArabicOrEnglish(String colorId, bool isAr) {
    final match = _allColors.firstWhere(
      (c) => c.id == colorId.toLowerCase(),
      orElse: () => TryOnColor(id: colorId, nameAr: colorId, nameEn: colorId, color: Colors.transparent),
    );
    return isAr ? match.nameAr : match.nameEn;
  }

  Color _getColorFromName(String name) {
    final match = _allColors.firstWhere(
      (c) => c.id == name.toLowerCase().trim(),
      orElse: () => const TryOnColor(id: 'transparent', nameAr: 'شفاف', nameEn: 'Transparent', color: Colors.transparent),
    );
    return match.color;
  }

  final TextEditingController _descriptionController = TextEditingController(
    text: "white short sleeve top",
  );

  bool _isGenerating = false;
  String _loadingMessage = "";

  // النتائج المولدة
  String? _resultImageUrl; // للوضع السحابي
  Uint8List? _resultImageBytes; // للوضع المحلي

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _localServerController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // تحميل الإعدادات المحفوظة
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useLocalServer = prefs.getBool("tryon_use_local") ?? true;
      _replicateToken = prefs.getString("replicate_token") ?? "";
      const defaultUrl = "https://subpar-eel-badness.ngrok-free.dev/tryon";
      final savedUrl = prefs.getString("tryon_local_url") ?? "";
      _localServerUrl =
          (savedUrl.isEmpty ||
              savedUrl == "http://localhost:8001/tryon" ||
              savedUrl == "http://10.0.2.2:8001/tryon")
          ? defaultUrl
          : savedUrl;

      _tokenController.text = _replicateToken;
      _localServerController.text = _localServerUrl;
    });
  }

  // حفظ الإعدادات
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("tryon_use_local", _useLocalServer);
    await prefs.setString("replicate_token", _tokenController.text.trim());
    await prefs.setString(
      "tryon_local_url",
      _localServerController.text.trim(),
    );

    setState(() {
      _replicateToken = _tokenController.text.trim();
      _localServerUrl = _localServerController.text.trim();
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('saveSuccess'.tr())));
    }
  }

  // اختيار صورة الشخص (كاميرا أو معرض)
  Future<void> _pickPersonImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      // التحقق من أن الصورة تحتوي على شخص واحد فقط
      try {
        final inputImage = InputImage.fromFilePath(pickedFile.path);
        final poseDetector = PoseDetector(options: PoseDetectorOptions());
        final poses = await poseDetector.processImage(inputImage);
        poseDetector.close();

        if (poses.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("هذا ليس بشري! يرجى تصوير شخص لتجربة الملابس.", style: TextStyle(fontWeight: FontWeight.bold)), 
                backgroundColor: Colors.redAccent
              ),
            );
          }
          return;
        } else if (poses.length > 1) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("يرجى تصوير شخص واحد فقط لتجربة الملابس.", style: TextStyle(fontWeight: FontWeight.bold)), 
                backgroundColor: Colors.orangeAccent
              ),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint("Pose detection error: $e");
      }

      setState(() {
        _selectedPerson = File(pickedFile.path);
      });
    }
  }

  // اختيار صورة القطعة (كاميرا أو معرض)
  Future<void> _pickGarmentImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedGarment = File(pickedFile.path);
      });
    }
  }

  // تشغيل عملية القياس الافتراضي
  Future<void> _startTryOn() async {
    if (!_useLocalServer && _replicateToken.isEmpty) {
      _showSettingsDialog();
      return;
    }

    if (_selectedPerson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("selectPersonFirst".tr())),
      );
      return;
    }

    if (_selectedGarment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("selectGarmentFirst".tr())),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _loadingMessage = 'pleaseWait'.tr();
      _resultImageUrl = null;
      _resultImageBytes = null;
    });

    try {
      final tryonService = AITryOnService();

      // تحديد نوع المدخل لقطعة الملابس
      dynamic garmentArg;
      if (_selectedGarment is File) {
        garmentArg = _selectedGarment;
      } else if (_selectedGarment is ClosetItemModel) {
        garmentArg = (_selectedGarment as ClosetItemModel).imageUrl;
      }

      // تحديد نوع المدخل للشخص
      dynamic personArg = _selectedPerson;

      // تحديد الفئة المتوافقة مع سيرفر الـ VTON
      final String vtonCategory;
      final catDetail = _selectedCategoryDetail.toLowerCase();
      if (catDetail.contains("pants") ||
          catDetail.contains("shorts") ||
          catDetail.contains("skirt")) {
        vtonCategory = "lower_body";
      } else if (catDetail.contains("dress")) {
        vtonCategory = "dress";
      } else {
        vtonCategory = "upper_body";
      }

      setState(() {
        _loadingMessage = "generating".tr();
      });

      if (_useLocalServer) {
        // 1. التشغيل المحلي ببث مباشر للخطوات (WebSocket)
        final stream = tryonService.runLocalTryOnStream(
          humanImage: personArg,
          garmentImage: garmentArg,
          category: vtonCategory,
          description: _descriptionController.text,
          localServerUrl: _localServerUrl,
        );

        await for (final frameBytes in stream) {
          setState(() {
            _resultImageBytes = frameBytes;
            _loadingMessage = "localTryOnProgressStep".tr();
          });
        }

        if (_resultImageBytes == null) {
          throw Exception("Failed to generate image from local server.");
        }
      } else {
        // 2. التشغيل السحابي (Replicate API)
        final result = await tryonService.runVirtualTryOn(
          humanImage: personArg,
          garmentImage: garmentArg,
          category: vtonCategory,
          description: _descriptionController.text,
          replicateToken: _replicateToken,
        );

        if (result != null) {
          setState(() {
            _resultImageUrl = result;
          });
        } else {
          throw Exception("Failed to generate image from cloud API.");
        }
      }

      // تسجيل استخدام تجربة القياس في Firestore
      final user = ref.read(authServiceProvider).currentUser;
      if (user != null) {
        ref.read(firestoreServiceProvider).logVirtualTryOn(user.uid);
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF16213E),
            title: Text(
              "connectionError".tr(),
              style: const TextStyle(color: Colors.white),
            ),
            content: Text(
              _useLocalServer
                  ? "localServerConnectionError".tr(args: [_localServerUrl, e.toString()])
                  : "cloudTryOnError".tr(args: [e.toString()]),
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "ok".tr(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  // حفظ النتيجة في الخزانة
  Future<void> _saveResultToCloset() async {
    if (_resultImageUrl == null && _resultImageBytes == null) return;

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('pleaseLoginFirst'.tr())));
      return;
    }

    setState(() {
      _isGenerating = true;
      _loadingMessage = "savingToCloset".tr();
    });

    try {
      String? finalUrl = _resultImageUrl;

      // إذا كانت النتيجة محلية كبايتات، نرفعها لـ Cloudinary أولاً للحصول على رابط إنترنت دائم
      if (finalUrl == null && _resultImageBytes != null) {
        finalUrl = await AITryOnService().uploadResultBytes(_resultImageBytes!);
      }

      if (finalUrl == null || finalUrl.isEmpty) {
        throw Exception(
          "Failed to obtain a valid image URL for database saving.",
        );
      }

      final newItem = ClosetItemModel(
        id: "",
        userID: user.uid,
        imageUrl: finalUrl,
        category: "tryon", // تصنيف خاص بالقياسات الافتراضية
        color: "multi",
        season: "summer",
      );

      await ref.read(firestoreServiceProvider).addClosetItem(newItem);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('saveSuccess'.tr())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("saveFailed".tr(args: [e.toString()]))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  // حفظ الصورة الناتجة في معرض صور الهاتف (Gallery)
  Future<void> _saveResultToPhone() async {
    final targetData = _resultImageBytes ?? _resultImageUrl;
    if (targetData == null) return;

    setState(() {
      _isGenerating = true;
      _loadingMessage = "savingImage".tr();
    });

    try {
      Uint8List? bytes;
      if (targetData is Uint8List) {
        bytes = targetData;
      } else if (targetData is String) {
        final res = await http.get(Uri.parse(targetData));
        if (res.statusCode == 200) {
          bytes = res.bodyBytes;
        }
      }

      if (bytes != null) {
        await Gal.putImageBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('saveSuccess'.tr())));
        }
      } else {
        throw Exception("Failed to download image data.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("saveFailedToPhone".tr(args: [e.toString()]))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'virtualTryOn'.tr(),
          style: GoogleFonts.tajawal(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white),
            onPressed: _showSettingsDialog,
            tooltip: 'modelSettings'.tr(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // واجهة النتيجة إذا كانت متوفرة
                    if (_resultImageUrl != null ||
                        _resultImageBytes != null) ...[
                      _buildResultView(),
                    ] else ...[
                      // واجهة الإعداد والمدخلات
                      _buildInputsView(isAr),
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // شاشة التحميل المعتمة
            if (_isGenerating && _resultImageBytes == null)
              Container(
                color: Colors.black.withValues(alpha: 0.75),
                child: Center(
                  child: GlassCard(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(30),
                    opacity: 0.1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 24),
                        Text(
                          _loadingMessage,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.tajawal(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _useLocalServer
                              ? "يتم التشغيل على كرت الشاشة لجهازك محلياً"
                              : "قد تستغرق العملية السحابية 15-20 ثانية",
                          style: GoogleFonts.tajawal(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // بناء قسم المدخلات
  Widget _buildInputsView(bool isAr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          'virtualTryOnDesc'.tr(),
          style: GoogleFonts.tajawal(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        // بطاقات الاختيار جنباً إلى جنب
        Row(
          children: [
            // صورة الشخص
            Expanded(
              child: Column(
                children: [
                  Text(
                    'selectPerson'.tr(),
                    style: GoogleFonts.tajawal(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _showPersonPickerSheet,
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _selectedPerson == null
                              ? _buildEmptyPlaceholder(Icons.person_add_rounded)
                              : _selectedPerson is File
                              ? Image.file(
                                  _selectedPerson as File,
                                  fit: BoxFit.cover,
                                )
                              : CachedNetworkImage(
                                  imageUrl: _selectedPerson as String,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // صورة القطعة
            Expanded(
              child: Column(
                children: [
                  Text(
                    'selectGarment'.tr(),
                    style: GoogleFonts.tajawal(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _showGarmentPickerSheet,
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _selectedGarment == null
                              ? _buildEmptyPlaceholder(Icons.checkroom_rounded)
                              : _selectedGarment is File
                              ? Image.file(
                                  _selectedGarment as File,
                                  fit: BoxFit.cover,
                                )
                              : CachedNetworkImage(
                                  imageUrl:
                                      (_selectedGarment as ClosetItemModel)
                                          .imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 30),

        // إعدادات الموديل والتصنيف
        GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.all(16),
          opacity: 0.05,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'modelSettings'.tr(),
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  // مؤشر نوع السيرفر
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _useLocalServer
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _useLocalServer ? "سحابي " : "سحابي ",
                      style: TextStyle(
                        color: _useLocalServer
                            ? Colors.greenAccent
                            : Colors.lightBlueAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 20),

              // تصنيف قطعة الملابس
              Text(
                'garmentCategory'.tr(),
                style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 13),
              ),
              DropdownButton<String>(
                value: _selectedCategoryDetail,
                dropdownColor: const Color(0xFF16213E),
                style: GoogleFonts.tajawal(color: Colors.white, fontSize: 14),
                underline: Container(height: 1, color: Colors.white30),
                isExpanded: true,
                onChanged: (String? val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategoryDetail = val;
                      _updateGeneratedDescription();
                    });
                  }
                },
                items: _categoriesDetail.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat['id'],
                    child: Text(isAr ? cat['nameAr']! : cat['nameEn']!),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // لون قطعة الملابس
              Text(
                isAr ? 'لون القطعة' : 'Garment Color',
                style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _showColorSearchSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      // Swatch
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _getColorFromName(_selectedColorDetail),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white30),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _getColorNameArabicOrEnglish(_selectedColorDetail, isAr),
                          style: GoogleFonts.tajawal(color: Colors.white, fontSize: 14),
                        ),
                      ),
                      const Icon(Icons.search, color: Colors.white70, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // طول الأكمام
              Text(
                isAr ? 'طول الأكمام' : 'Sleeve Length',
                style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 13),
              ),
              DropdownButton<String>(
                value: _selectedSleeveDetail,
                dropdownColor: const Color(0xFF16213E),
                style: GoogleFonts.tajawal(color: Colors.white, fontSize: 14),
                underline: Container(height: 1, color: Colors.white30),
                isExpanded: true,
                onChanged: (String? val) {
                  if (val != null) {
                    setState(() {
                      _selectedSleeveDetail = val;
                      _updateGeneratedDescription();
                    });
                  }
                },
                items: _sleevesDetail.map((slv) {
                  return DropdownMenuItem<String>(
                    value: slv['id'],
                    child: Text(isAr ? slv['nameAr']! : slv['nameEn']!),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              if (["heels", "sandals", "sneakers"].contains(_selectedCategoryDetail.toLowerCase()))
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isAr
                              ? 'تنبيه: الأحذية غير مدعومة بالكامل للتركيب على الملابس، سيتم إرسالها كجزء علوي افتراضياً.'
                              : 'Note: Shoes are not fully supported for try-on. Mapped as upper body by default.',
                          style: GoogleFonts.tajawal(color: Colors.amberAccent, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),

            ],
          ),
        ),

        const SizedBox(height: 30),

        // زر البدء
        InkWell(
          onTap: _startTryOn,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  context.colorScheme.primary,
                  context.colorScheme.primary.withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'tryOnNow'.tr(),
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // بناء شاشة النتيجة الناجحة
  Widget _buildResultView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        GlassCard(
          borderRadius: 24,
          padding: const EdgeInsets.all(16),
          opacity: 0.05,
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => FullScreenImageViewer(
                        imageUrl: _resultImageUrl,
                        imageBytes: _resultImageBytes,
                        category: _selectedCategoryDetail,
                      ),
                    ),
                  );
                },
                child: Hero(
                  tag: _resultImageUrl ?? _resultImageBytes.hashCode.toString(),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _resultImageBytes != null
                        ? Image.memory(_resultImageBytes!, fit: BoxFit.cover)
                        : CachedNetworkImage(
                            imageUrl: _resultImageUrl!,
                            placeholder: (context, url) => const Center(
                              child: Padding(
                                padding: EdgeInsets.all(50.0),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // أزرار الحفظ أو التجربة مجدداً
        _isGenerating
            ? GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                opacity: 0.05,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _loadingMessage,
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(
                      color: Colors.teal,
                      backgroundColor: Colors.white10,
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _resultImageUrl = null;
                              _resultImageBytes = null;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Colors.white30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            'tryAnother'.tr(),
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveResultToCloset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(
                            Icons.cloud_upload_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            'saveToCloset'.tr(),
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveResultToPhone,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        'saveToPhone'.tr(),
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  // نائب فارغ لعدم وجود صورة
  Widget _buildEmptyPlaceholder(IconData icon) {
    return Container(
      color: Colors.white.withValues(alpha: 0.03),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            Text(
              "اضغط للاختيار",
              style: GoogleFonts.tajawal(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // قائمة اختيار صورة الشخص السفلى
  void _showPersonPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'selectPerson'.tr(),
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                // العارضين الافتراضيين
                Text(
                  'defaultModels'.tr(),
                  style: GoogleFonts.tajawal(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _defaultModels.length,
                    itemBuilder: (context, index) {
                      final model = _defaultModels[index];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPerson = model['url'];
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedPerson == model['url']
                                  ? context.colorScheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: model['url']!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(color: Colors.white24, height: 30),
                // رفع صورة مخصصة
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    'uploadPhoto'.tr(),
                    style: GoogleFonts.tajawal(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPersonImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    context.locale.languageCode == 'ar'
                        ? 'التقاط صورة'
                        : 'Take Photo',
                    style: GoogleFonts.tajawal(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPersonImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // قائمة اختيار قطعة الملابس السفلى
  void _showGarmentPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'selectGarment'.tr(),
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // الخزانة الرقمية للمستخدم
                    Text(
                      'myCloset'.tr(),
                      style: GoogleFonts.tajawal(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, child) {
                          final closetAsync = ref.watch(userFullClosetProvider);
                          return closetAsync.when(
                            data: (items) {
                              if (items.isEmpty) {
                                return Center(
                                  child: Text(
                                    "لا توجد قطع في خزانتك الرقمية بعد",
                                    style: GoogleFonts.tajawal(
                                      color: Colors.white38,
                                    ),
                                  ),
                                );
                              }
                              return GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                    ),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final isSelected =
                                      (_selectedGarment is ClosetItemModel) &&
                                      (_selectedGarment as ClosetItemModel)
                                              .id ==
                                          item.id;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedGarment = item;
                                        // تحديث الفئة بشكل ذكي
                                        final catLower = item.category.toLowerCase();
                                        if (_categoriesDetail.any((c) => c['id'] == catLower)) {
                                          _selectedCategoryDetail = catLower;
                                        } else {
                                          if (catLower.contains("top") ||
                                              catLower.contains("shirt") ||
                                              catLower.contains("hoodie") ||
                                              catLower.contains("jacket") ||
                                              catLower.contains("outerwear") ||
                                              catLower.contains("tee")) {
                                            _selectedCategoryDetail = "top";
                                          } else if (catLower.contains("pants") ||
                                              catLower.contains("shorts") ||
                                              catLower.contains("skirt") ||
                                              catLower.contains("trousers") ||
                                              catLower.contains("jeans") ||
                                              catLower.contains("joggers")) {
                                            _selectedCategoryDetail = "pants";
                                          } else if (catLower.contains("dress")) {
                                            _selectedCategoryDetail = "dress";
                                          } else {
                                            _selectedCategoryDetail = "top";
                                          }
                                        }

                                        // تحديث اللون بشكل ذكي
                                        final colorLower = item.color.toLowerCase();
                                        if (_allColors.any((c) => c.id == colorLower)) {
                                          _selectedColorDetail = colorLower;
                                        } else {
                                          _selectedColorDetail = "white"; // default if not found
                                        }

                                        // تحديث الأكمام بشكل ذكي
                                        final sleeveLower = item.sleeve?.toLowerCase() ?? "short_sleeve";
                                        if (_sleevesDetail.any((s) => s['id'] == sleeveLower)) {
                                          _selectedSleeveDetail = sleeveLower;
                                        } else {
                                          _selectedSleeveDetail = "short_sleeve";
                                        }

                                        _updateGeneratedDescription();
                                      });
                                      Navigator.pop(context);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? context.colorScheme.primary
                                              : Colors.white24,
                                          width: isSelected ? 3 : 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: CachedNetworkImage(
                                          imageUrl: item.imageUrl,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (e, s) =>
                                Center(child: Text("خطأ في التحميل: $e")),
                          );
                        },
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 20),
                    // خيار الرفع الخارجي
                    ListTile(
                      leading: const Icon(
                        Icons.photo_library_rounded,
                        color: Colors.white,
                      ),
                      title: Text(
                        'uploadPhoto'.tr(),
                        style: GoogleFonts.tajawal(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _pickGarmentImage(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // مربع حوار الإعدادات للربط
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF16213E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                'modelSettings'.tr(),
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // تبديل نوع التشغيل
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "طريقة التشغيل:",
                          style: GoogleFonts.tajawal(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        Switch(
                          value: _useLocalServer,
                          activeThumbColor: context.colorScheme.primary,
                          onChanged: (val) {
                            setDialogState(() {
                              _useLocalServer = val;
                            });
                          },
                        ),
                      ],
                    ),
                    Text(
                      _useLocalServer
                          ? "محلي (توليد مجاني بدون مفتاح API)"
                          : "سحابي (يتطلب مفتاح Replicate API)",
                      style: GoogleFonts.tajawal(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_useLocalServer) ...[
                      // رابط السيرفر المحلي
                      Text(
                        "رابط السيرفر المحلي (FastAPI):",
                        style: GoogleFonts.tajawal(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _localServerController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: (!kIsWeb && Platform.isAndroid)
                              ? "http://10.0.2.2:8001/tryon"
                              : "http://localhost:8001/tryon",
                          hintStyle: const TextStyle(color: Colors.white30),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "ملاحظة: إذا كنت تستخدم المحاكي (Emulator)، استخدم العنوان http://10.0.2.2:8001/tryon",
                        style: GoogleFonts.tajawal(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ] else ...[
                      // توكن ريبليكيت
                      Text(
                        'replicateToken'.tr(),
                        style: GoogleFonts.tajawal(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _tokenController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          hintText: "r8_...",
                          hintStyle: TextStyle(color: Colors.white30),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'cancel'.tr(),
                    style: GoogleFonts.tajawal(color: Colors.white60),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _useLocalServer = _useLocalServer;
                    });
                    _saveSettings();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colorScheme.primary,
                  ),
                  child: Text(
                    'save'.tr(),
                    style: GoogleFonts.tajawal(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showColorSearchSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'اختر لوناً / Select Color',
                          style: GoogleFonts.tajawal(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Search bar
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن لون... / Search color...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _buildColorListGrid(_searchQuery),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorListGrid(String query) {
    final filteredColors = _allColors.where((c) {
      final q = query.toLowerCase();
      return c.nameAr.toLowerCase().contains(q) ||
             c.nameEn.toLowerCase().contains(q) ||
             c.id.toLowerCase().contains(q);
    }).toList();

    if (filteredColors.isEmpty) {
      return Center(
        child: Text(
          'لا توجد نتائج تطابق بحثك',
          style: GoogleFonts.tajawal(color: Colors.white38),
        ),
      );
    }

    final isAr = context.locale.languageCode == 'ar';

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: filteredColors.length,
      itemBuilder: (context, index) {
        final item = filteredColors[index];
        final isSelected = _selectedColorDetail == item.id;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedColorDetail = item.id;
              _updateGeneratedDescription();
            });
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? context.colorScheme.primary.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? context.colorScheme.primary : Colors.white12,
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Color Swatch Circle
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item.color == Colors.white ? Colors.black26 : Colors.white30,
                      width: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isAr ? item.nameAr : item.nameEn,
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.nameEn,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: context.colorScheme.primary,
                    size: 16,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart';

// خدمة معالجة الصور باستخدام الذكاء الاصطناعي (AI)
class AIModelService {
  // نمط السينجلتون (Singleton) لضمان وجود نسخة واحدة فقط من الخدمة
  static final AIModelService _instance = AIModelService._internal();
  factory AIModelService() => _instance;
  AIModelService._internal();

  // مراجع لمترجمات نماذج TFLite
  Interpreter? _categoryInterpreter;
  Interpreter? _sleeveInterpreter;
  Interpreter? _segmentationInterpreter;

  // التحقق مما إذا كانت النماذج محملة في الذاكرة
  bool get isLoaded =>
      _categoryInterpreter != null && 
      _sleeveInterpreter != null &&
      _segmentationInterpreter != null;

  // قائمة تسميات فئات الملابس التي يتعرف عليها النموذج
  // قائمة تسميات فئات الملابس التي يتعرف عليها النموذج الجديد
  final List<String> _categoryLabels = [
    'Heels', 'Sandals', 'Sneakers', 'dress', 'outerwear', 
    'pants', 'shorts', 'skirt', 'sling', 'top'
  ];

  // قائمة تسميات أنواع الأكمام
  final List<String> _sleeveLabels = [
    'long_sleeve', 'short_sleeve', 'sleeveless'
  ];

  // تحميل النماذج من ملفات الأصول (Assets)
  Future<void> loadModels() async {
    if (isLoaded) return;
    try {
      _categoryInterpreter = await Interpreter.fromAsset(
        'assets/models/category_model.tflite',
      );
      _sleeveInterpreter = await Interpreter.fromAsset(
        'assets/models/sleeve_model.tflite',
      );
      _segmentationInterpreter = await Interpreter.fromAsset(
        'assets/models/yolo11m-seg.tflite',
      );
      debugPrint('AI Models loaded successfully (Category, Sleeve & Segmentation)');
    } catch (e) {
      debugPrint('Error loading AI models: $e');
    }
  }

  // تحليل الصورة لاستخراج كل قطع الملابس المكتشفة
  Future<List<Map<String, dynamic>>> analyzeImage(File imageFile) async {
    if (!isLoaded) await loadModels();
    if (!isLoaded) return [];

    try {
      // 1. اكتشاف كافة القطع وقصها بشكل منفصل
      List<Map<String, dynamic>> detectedItems = await _detectAndCropAllItems(imageFile);
      debugPrint('Segmentation found ${detectedItems.length} items.');
      
      // إذا لم يكتشف موديل القص أي شيء، نستخدم الصورة الكاملة كحل بديل (Fallback)
      if (detectedItems.isEmpty) {
        debugPrint('No items detected by segmentation. Falling back to full image analysis...');
        final bytes = await imageFile.readAsBytes();
        final fullImg = img.decodeImage(bytes);
        if (fullImg != null) {
          detectedItems.add({
            'image': fullImg,
            'rect': {'left': 0.0, 'top': 0.0, 'right': 1.0, 'bottom': 1.0},
          });
        } else {
          debugPrint('FAILED to decode full image for fallback!');
        }
      }

      final List<Map<String, dynamic>> results = [];

      for (var item in detectedItems) {
        final croppedImage = item['image'] as img.Image;
        
        // 2. معالجة الصورة لتناسب مدخلات نماذج التصنيف والألوان
        final inputImage = await _processImageFromMemory(croppedImage);

        // 3. استخراج اللون
        final color = await _extractDominantColor(croppedImage);
        debugPrint('Detected Color: $color');

        // 4. التنبؤ بالفئة (Category) باستخدام المقاس الصحيح للموديل (300x300)
        int modelW = 300;
        int modelH = 300;
        try {
          final details = _categoryInterpreter!.getInputTensors();
          if (details.isNotEmpty) {
            modelW = details[0].shape[1];
            modelH = details[0].shape[2];
          }
        } catch (e) {
           debugPrint('Error getting model shape: $e');
        }
        
        final categoryInput = await _processImageFromMemory(croppedImage, width: modelW, height: modelH);
        final categoryOutput = List.filled(1 * _categoryLabels.length, 0.0)
            .reshape([1, _categoryLabels.length]);
        
        _categoryInterpreter!.run(categoryInput, categoryOutput);
        debugPrint('Raw Category Output: ${categoryOutput[0]}');
        
        final categoryIdx = _getBestIdx(categoryOutput[0]);
        final category = _categoryLabels[categoryIdx];
        debugPrint('Predicted Category: $category');

        // 5. التنبؤ بنوع الكم (Sleeve)
        String? sleeve;
        if (['dress', 'outerwear', 'top'].contains(category.toLowerCase())) {
          final sleeveOutput = List.filled(1 * _sleeveLabels.length, 0.0)
              .reshape([1, _sleeveLabels.length]);
          
          final sleeveInput = await _processImageFromMemory(croppedImage, width: modelW, height: modelH);
          _sleeveInterpreter!.run(sleeveInput, sleeveOutput);
          final sleeveIdx = _getBestIdx(sleeveOutput[0]);
          sleeve = _sleeveLabels[sleeveIdx];
          debugPrint('Predicted Sleeve: $sleeve');
        }

        // 6. تحويل الصورة إلى PNG للرفع
        final Uint8List imageBytes = Uint8List.fromList(img.encodePng(croppedImage));

        results.add({
          'color': color, 
          'category': category,
          'sleeve': sleeve,
          'image': croppedImage, 
          'imageBytes': imageBytes, 
          'rect': item['rect'],
        });
      }

      return results;
    } catch (e) {
      debugPrint('Error during multi-image analysis: $e');
      return [];
    }
  }

  // وظيفة اكتشاف وقص كافة العناصر المكتشفة باستخدام YOLOv11-seg (محسنة ومستقرة)
  Future<List<Map<String, dynamic>>> _detectAndCropAllItems(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    
    // 1. فك تشفير وتجهيز الصورة في الخلفية (هذا هو الجزء الأبطأ)
    final prepData = await compute(_prepareSegmentationInput, imageBytes);
    final img.Image originalImage = prepData['originalImage'];
    final List<dynamic> input = prepData['input'];

    final outputs = {
      0: List.filled(1 * 116 * 8400, 0.0).reshape([1, 116, 8400]),
      1: List.filled(1 * 160 * 160 * 32, 0.0).reshape([1, 160, 160, 32]),
    };

    // 2. تشغيل الموديل
    _segmentationInterpreter!.runForMultipleInputs([input], outputs);

    final List<dynamic> detections = outputs[0] as List<dynamic>;
    final List<dynamic> protos = outputs[1] as List<dynamic>;
    final List<Map<String, dynamic>> results = [];

    // 3. معالجة النتائج في المسار الرئيسي لضمان الاستقرار مع استخدام تحسينات السرعة
    for (int i = 0; i < 8400; i++) {
        double maxConf = 0.0;
        for (int c = 4; c < 84; c++) {
            if (detections[0][c][i] > maxConf) maxConf = detections[0][c][i];
        }
        
        final double w_norm = detections[0][2][i];
        final double h_norm = detections[0][3][i];
        final double area_ratio = w_norm * h_norm;

        if (maxConf > 0.15 && area_ratio > 0.01) { // خفضنا حد الثقة قليلاً لضمان عدم الضياع
            final double bx1 = detections[0][0][i] - detections[0][2][i] / 2;
            final double by1 = detections[0][1][i] - detections[0][3][i] / 2;
            final double bx2 = detections[0][0][i] + detections[0][2][i] / 2;
            final double by2 = detections[0][1][i] + detections[0][3][i] / 2;

            // إحداثيات القناع مع إضافة هامش بسيط (Padding) لمنع قص الأطراف كالأكمام
            final double mPad = (bx2 - bx1) * 0.10;
            final double mx1 = (bx1 - mPad) * 160;
            final double my1 = (by1 - mPad) * 160;
            final double mx2 = (bx2 + mPad) * 160;
            final double my2 = (by2 + mPad) * 160;

            final List<double> maskWeights = [];
            for (int j = 84; j < 116; j++) maskWeights.add(detections[0][j][i]);

            // حساب القناع بشكل أسرع وأكثر شمولية (Threshold 0.3)
            final mask160 = List.generate(160, (y) => List.generate(160, (x) {
                if (x < mx1 || x > mx2 || y < my1 || y > my2) return 0.0;
                double val = 0.0;
                for (int m = 0; m < 32; m++) val += maskWeights[m] * protos[0][y][x][m];
                return 1.0 / (1.0 + math.exp(-val));
            }));

            int rx1 = ((bx1 - (bx2-bx1)*0.15) * originalImage.width).toInt().clamp(0, originalImage.width - 1);
            int ry1 = ((by1 - (by2-by1)*0.15) * originalImage.height).toInt().clamp(0, originalImage.height - 1);
            int rx2 = ((bx2 + (bx2-bx1)*0.15) * originalImage.width).toInt().clamp(0, originalImage.width - 1);
            int ry2 = ((by2 + (by2-by1)*0.15) * originalImage.height).toInt().clamp(0, originalImage.height - 1);
            
            int actualW = rx2 - rx1;
            int actualH = ry2 - ry1;
            if (actualW <= 5 || actualH <= 5) continue;

            final itemImage = img.Image(width: actualW, height: actualH, numChannels: 4);
            bool hasContent = false;
            
            for (int y = 0; y < actualH; y++) {
              for (int x = 0; x < actualW; x++) {
                int origX = rx1 + x;
                int origY = ry1 + y;
                int mx = (origX * 160 / originalImage.width).floor().clamp(0, 159);
                int my = (origY * 160 / originalImage.height).floor().clamp(0, 159);
                
                // تقليل الحد لضمان تغطية كاملة للقطعة (0.3 بدلاً من 0.5)
                if (mask160[my][mx] > 0.3) {
                  final pixel = originalImage.getPixel(origX, origY);
                  itemImage.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, 255);
                  hasContent = true;
                } else {
                  itemImage.setPixelRgba(x, y, 0, 0, 0, 0); 
                }
              }
            }

            if (hasContent) {
              results.add({
                'image': itemImage, 
                'confidence': maxConf, 
                'area': area_ratio,
                'rect': {'left': bx1, 'top': by1, 'right': bx2, 'bottom': by2}
              });
            }
            if (results.length >= 5) break;
        }
    }

    final List<Map<String, dynamic>> finalResults = [];
    results.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));
    for (var res in results) {
      bool shouldKeep = true;
      for (var kept in finalResults) {
        if (_calculateIoU(res['rect'], kept['rect']) > 0.4) { 
          shouldKeep = false;
          break;
        }
      }
      if (shouldKeep) finalResults.add(res);
      if (finalResults.length >= 8) break;
    }
    return finalResults;
  }

  // نسخة ثابتة من حساب IoU لاستخدامها داخل Isolate
  static double _calculateIoUStatic(Map<String, double> r1, Map<String, double> r2) {
    double x1 = math.max(r1['left']!, r2['left']!);
    double y1 = math.max(r1['top']!, r2['top']!);
    double x2 = math.min(r1['right']!, r2['right']!);
    double y2 = math.min(r1['bottom']!, r2['bottom']!);
    double intersection = math.max(0, x2 - x1) * math.max(0, y2 - y1);
    double area1 = (r1['right']! - r1['left']!) * (r1['bottom']! - r1['top']!);
    double area2 = (r2['right']! - r2['left']!) * (r2['bottom']! - r2['top']!);
    double union = area1 + area2 - intersection;
    return union > 0 ? intersection / union : 0;
  }

  // توليد صورة تحتوي على أقنعة ملونة فوق الصورة الأصلية (Mask Overlay)
  img.Image generateMaskOverlay(img.Image originalImage, List<Map<String, dynamic>> detections) {
    final overlay = originalImage.clone();
    final colors = [
      [255, 0, 0],   // أحمر
      [0, 255, 0],   // أخضر
      [0, 0, 255],   // أزرق
      [255, 255, 0], // أصفر
      [255, 0, 255], // بنفسجي
      [0, 255, 255], // سماوي
    ];

    for (int i = 0; i < detections.length; i++) {
      final detection = detections[i];
      final itemImg = detection['image'] as img.Image;
      final rect = detection['rect'] as Map<String, double>;
      final color = colors[i % colors.length];

      int startX = (rect['left']! * originalImage.width).toInt();
      int startY = (rect['top']! * originalImage.height).toInt();

      for (int y = 0; y < itemImg.height; y++) {
        for (int x = 0; x < itemImg.width; x++) {
          final pixel = itemImg.getPixel(x, y);
          if (pixel.a > 0) { // إذا كان البكسل جزءاً من القناع
            int targetX = startX + x;
            int targetY = startY + y;
            if (targetX < overlay.width && targetY < overlay.height) {
              // مزج اللون المختار بنسبة 50% مع الصورة الأصلية
              final origPixel = overlay.getPixel(targetX, targetY);
              overlay.setPixelRgba(
                targetX, targetY,
                ((origPixel.r + color[0]) ~/ 2),
                ((origPixel.g + color[1]) ~/ 2),
                ((origPixel.b + color[2]) ~/ 2),
                255
              );
            }
          }
        }
      }
    }
    return overlay;
  }

  // حفظ القطعة المكتشفة في خزانة الملابس بـ Firebase
  Future<bool> saveItemToFirestore({
    required String userId,
    required Uint8List imageBytes,
    required String category,
    required String color,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('closet')
          .doc();

      // ملاحظة: في التطبيق الحقيقي يفضل رفع الصورة لـ Firebase Storage 
      // ولكن للتبسيط سنقوم بتخزينها كـ Base64 مؤقتاً أو استخدام رابط افتراضي
      await docRef.set({
        'id': docRef.id,
        'category': category,
        'colorName': color,
        'imageUrl': 'data:image/png;base64,${base64Encode(imageBytes)}',
        'createdAt': FieldValue.serverTimestamp(),
        'isFavorite': false,
      });
      return true;
    } catch (e) {
      debugPrint('Error saving item: $e');
      return false;
    }
  }

  // دالة حساب نسبة التداخل (Intersection over Union) بين صندوقين
  double _calculateIoU(Map<String, double> r1, Map<String, double> r2) {
    double x1 = math.max(r1['left']!, r2['left']!);
    double y1 = math.max(r1['top']!, r2['top']!);
    double x2 = math.min(r1['right']!, r2['right']!);
    double y2 = math.min(r1['bottom']!, r2['bottom']!);

    double intersection = math.max(0, x2 - x1) * math.max(0, y2 - y1);
    double area1 = (r1['right']! - r1['left']!) * (r1['bottom']! - r1['top']!);
    double area2 = (r2['right']! - r2['left']!) * (r2['bottom']! - r2['top']!);
    
    double union = area1 + area2 - intersection;
    return union > 0 ? intersection / union : 0;
  }

  // معالجة صورة من الذاكرة لنموذج التصنيف (باستخدام Isolate لمنع تعليق التطبيق)
  Future<List<List<List<List<double>>>>> _processImageFromMemory(img.Image image, {int width = 224, int height = 224}) async {
    return await compute(_preprocessImageIsolate, {
      'image': image,
      'width': width,
      'height': height,
    });
  }

  // دالة ثابتة تعمل في الخلفية لتحويل بكسلات الصورة إلى Tensor
  static List<List<List<List<double>>>> _preprocessImageIsolate(Map<String, dynamic> params) {
    final img.Image image = params['image'];
    final int width = params['width'];
    final int height = params['height'];

    final resizedImage = img.copyResize(image, width: width, height: height);
    
    // إنشاء المصفوفة رباعية الأبعاد المطلوبة [1, height, width, 3]
    var input = List.generate(1, (batch) => List.generate(height, (y) => List.generate(width, (x) {
      final pixel = resizedImage.getPixel(x, y);
      return [pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble()];
    })));

    return input;
  }

  // استخراج اللون المهيمن (باستخدام Isolate لمنع التعليق)
  Future<String> _extractDominantColor(img.Image image) async {
    return await compute(_extractColorIsolate, image);
  }

  static String _extractColorIsolate(img.Image image) {
    // تعريف الألوان الأساسية ودرجاتها (Hue) بالدرجات من 0 إلى 360
    final Map<String, Map<String, double>> colorRanges = {
      'red': {'hMin': 0, 'hMax': 15, 'sMin': 0.4},
      'orange': {'hMin': 15, 'hMax': 45, 'sMin': 0.5},
      'yellow': {'hMin': 45, 'hMax': 70, 'sMin': 0.5},
      'green': {'hMin': 70, 'hMax': 155, 'sMin': 0.3},
      'blue': {'hMin': 155, 'hMax': 250, 'sMin': 0.3},
      'purple': {'hMin': 250, 'hMax': 290, 'sMin': 0.3},
      'pink': {'hMin': 290, 'hMax': 340, 'sMin': 0.3},
      'red_alt': {'hMin': 340, 'hMax': 360, 'sMin': 0.4},
      'brown': {'hMin': 0, 'hMax': 45, 'sMin': 0.15, 'lMax': 0.45},
      'navy': {'hMin': 200, 'hMax': 245, 'sMin': 0.3, 'lMax': 0.35},
      'beige': {'hMin': 30, 'hMax': 60, 'sMin': 0.1, 'lMin': 0.6},
    };

    final Map<String, double> colorScores = {
      'red': 0, 'orange': 0, 'yellow': 0, 'green': 0, 'blue': 0, 
      'purple': 0, 'pink': 0, 'brown': 0, 'navy': 0, 'black': 0, 
      'white': 0, 'grey': 0, 'beige': 0
    };

    int centerX = image.width ~/ 2;
    int centerY = image.height ~/ 2;
    double maxDist = math.sqrt(centerX * centerX + centerY * centerY);

    for (int y = 0; y < image.height; y += 2) {
      for (int x = 0; x < image.width; x += 2) {
        final pixel = image.getPixel(x, y);
        if (pixel.a < 50) continue;

        double r = pixel.r / 255.0;
        double g = pixel.g / 255.0;
        double b = pixel.b / 255.0;

        double max = math.max(r, math.max(g, b));
        double min = math.min(r, math.min(g, b));
        double l = (max + min) / 2;
        double s = (max == min) ? 0 : (l < 0.5 ? (max - min) / (max + min) : (max - min) / (2.0 - max - min));
        double h = 0;
        if (max != min) {
          if (max == r) h = (g - b) / (max - min) + (g < b ? 6 : 0);
          else if (max == g) h = (b - r) / (max - min) + 2;
          else h = (r - g) / (max - min) + 4;
          h *= 60;
        }

        double distFromCenter = math.sqrt(math.pow(x - centerX, 2) + math.pow(y - centerY, 2));
        double weight = 1.0 + (1.0 - (distFromCenter / maxDist));

        if (l < 0.12) {
          colorScores['black'] = colorScores['black']! + weight;
        } else if (l > 0.88) {
          colorScores['white'] = colorScores['white']! + weight;
        } else if (s < 0.12) {
          colorScores['grey'] = colorScores['grey']! + weight;
        } else {
          bool matched = false;
          for (var entry in colorRanges.entries) {
            var range = entry.value;
            if (h >= range['hMin']! && h <= range['hMax']!) {
              if (entry.key == 'beige' && (l < 0.6 || s > 0.4)) continue;
              if (entry.key == 'navy' && l > 0.35) continue;
              if (entry.key == 'brown' && l > 0.45) continue;
              String colorKey = entry.key == 'red_alt' ? 'red' : entry.key;
              colorScores[colorKey] = colorScores[colorKey]! + weight;
              matched = true;
              break;
            }
          }
          if (!matched) colorScores['grey'] = colorScores['grey']! + weight;
        }
      }
    }

    String bestColor = 'white';
    double maxScore = -1;
    colorScores.forEach((key, value) {
      if (value > maxScore) {
        maxScore = value;
        bestColor = key;
      }
    });
    return bestColor;
  }

  // تحضير الصورة: تغيير الحجم وتحويلها إلى مصفوفة بيانات رقمية (Tensors)
  Future<List<List<List<List<double>>>>> _processImage(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Failed to decode image');

    // تكبير/تصغير الصورة لتصبح 300 في 300 بكسل (المقاس المطلوب للنموذج الجديد)
    final resizedImage = img.copyResize(image, width: 300, height: 300);

    // تطبيع قيم البكسلات لتكون بين [0، 1]
    var input = List.generate(
      1,
      (batch) => List.generate(
        300,
        (y) => List.generate(300, (x) {
          final pixel = resizedImage.getPixel(x, y);
          // تقسيم قيم RGB على 255 للحصول على نسبة مئوية
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        }),
      ),
    );

    return input;
  }

  // إيجاد الفهرس صاحب أعلى احتمالية في مصفوفة النتائج
  int _getBestIdx(List<double> probabilities) {
    int maxIdx = 0;
    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > probabilities[maxIdx]) {
        maxIdx = i;
      }
    }
    return maxIdx;
  }

  // دالة خلفية لتجهيز مدخلات YOLO
  static Map<String, dynamic> _prepareSegmentationInput(Uint8List bytes) {
    final originalImage = img.decodeImage(bytes);
    if (originalImage == null) throw Exception('Failed to decode image');
    final resized640 = img.copyResize(originalImage, width: 640, height: 640);
    final input = List.generate(1, (b) => List.generate(640, (y) => List.generate(640, (x) {
      final pixel = resized640.getPixel(x, y);
      return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
    })));
    return {'originalImage': originalImage, 'input': input};
  }

  // إغلاق المترجمات لتحرير موارد الذاكرة
  void dispose() {
    _categoryInterpreter?.close();
    _sleeveInterpreter?.close();
    _segmentationInterpreter?.close();
  }
}

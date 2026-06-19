import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'cloudinary_service.dart';

class AITryOnService {
  static final AITryOnService _instance = AITryOnService._internal();
  factory AITryOnService() => _instance;
  AITryOnService._internal();

  // معرف موديل IDM-VTON الرسمي على Replicate
  static const String _modelAbsoluteVersion =
      "c871bb2f0dbda6606019316d3fdf2a9c3947474db1853d4ebcd6bf7db1c360b8d";

  /// تشغيل عملية الـ Try-On المحلية (لا تحتاج لمفاتيح API)
  /// [humanImage] يمكن أن يكون File (صورة شخصية مرفوعة) أو String (رابط لعارض افتراضي)
  /// [garmentImage] يمكن أن يكون File (صورة ملابس مرفوعة) أو String (رابط لقطعة ملابس)
  /// [category] الفئة: "upper_body" (علوي) أو "lower_body" (سفلي) أو "dress" (كامل)
  /// [description] وصف القطعة لمساعدة الذكاء الاصطناعي
  /// [localServerUrl] عنوان السيرفر المحلي (مثل http://localhost:8001/tryon)
  Future<Uint8List?> runLocalTryOn({
    required dynamic humanImage,
    required dynamic garmentImage,
    required String category,
    String description = "stylish fashion garment",
    required String localServerUrl,
  }) async {
    try {
      debugPrint("🚀 Starting Local Try-On request to $localServerUrl...");

      final uri = Uri.parse(localServerUrl);
      final request = http.MultipartRequest("POST", uri);
      request.headers["ngrok-skip-browser-warning"] = "true";

      // إضافة الحقول المكتوبة
      request.fields["category"] = category;
      request.fields["description"] = description;
      request.fields["steps"] = "25";
      request.fields["seed"] = "42";

      // 1. إضافة صورة الشخص
      if (humanImage is File) {
        request.files.add(
          await http.MultipartFile.fromPath("human_img", humanImage.path),
        );
      } else if (humanImage is String) {
        // إذا كان رابط إنترنت (مثل عارض افتراضي)، نقوم بتحميل البايتات وإرسالها
        final res = await http.get(Uri.parse(humanImage));
        request.files.add(
          http.MultipartFile.fromBytes(
            "human_img",
            res.bodyBytes,
            filename: "human.jpg",
          ),
        );
      }

      // 2. إضافة صورة الملابس
      if (garmentImage is File) {
        request.files.add(
          await http.MultipartFile.fromPath("garm_img", garmentImage.path),
        );
      } else if (garmentImage is String) {
        // إذا كان رابط إنترنت (مثل قطعة من الخزانة)، نقوم بتحميل البايتات وإرسالها
        final res = await http.get(Uri.parse(garmentImage));
        request.files.add(
          http.MultipartFile.fromBytes(
            "garm_img",
            res.bodyBytes,
            filename: "garment.jpg",
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        debugPrint("✅ Local Try-On generated successfully!");
        return response.bodyBytes;
      } else {
        throw Exception(
          "Server Error ${response.statusCode}: ${response.body}",
        );
      }
    } catch (e) {
      debugPrint("❌ runLocalTryOn error: $e");
      rethrow;
    }
  }

  /// تشغيل عملية الـ Try-On المحلية ببث مباشر للخطوات عبر الـ WebSocket
  Stream<Uint8List> runLocalTryOnStream({
    required dynamic humanImage,
    required dynamic garmentImage,
    required String category,
    String description = "stylish fashion garment",
    required String localServerUrl,
  }) async* {
    try {
      final wsUrl =
          "${localServerUrl.replaceAll("http://", "ws://").replaceAll("https://", "wss://")}-ws";
      debugPrint("🔌 Connecting to Local Try-On WebSocket: $wsUrl");

      final socket = await WebSocket.connect(
        wsUrl,
        headers: {"ngrok-skip-browser-warning": "true"},
      );

      // 1. إرسال الإعدادات بصيغة JSON
      final config = {
        "category": category,
        "description": description,
        "steps": 25,
        "seed": 42,
      };
      socket.add(jsonEncode(config));

      // 2. إرسال صورة الشخص كـ Binary
      Uint8List humanBytes;
      if (humanImage is File) {
        humanBytes = await humanImage.readAsBytes();
      } else if (humanImage is String) {
        final res = await http.get(Uri.parse(humanImage));
        humanBytes = res.bodyBytes;
      } else {
        throw Exception("Unknown human image type");
      }
      socket.add(humanBytes);

      // 3. إرسال صورة الملابس كـ Binary
      Uint8List garmentBytes;
      if (garmentImage is File) {
        garmentBytes = await garmentImage.readAsBytes();
      } else if (garmentImage is String) {
        final res = await http.get(Uri.parse(garmentImage));
        garmentBytes = res.bodyBytes;
      } else {
        throw Exception("Unknown garment image type");
      }
      socket.add(garmentBytes);

      // 4. الاستماع للبث المباشر للخطوات من السيرفر
      await for (final message in socket) {
        if (message is List<int>) {
          yield Uint8List.fromList(message);
        } else if (message is String) {
          // فحص إذا كان هناك رسالة خطأ مرسلة كـ JSON
          try {
            final errorData = jsonDecode(message);
            if (errorData is Map && errorData.containsKey("error")) {
              throw Exception(errorData["error"]);
            }
          } catch (_) {
            // تجاهل أخطاء فك الترميز لرسائل البث العادية
          }
        }
      }
    } catch (e) {
      debugPrint("❌ runLocalTryOnStream error: $e");
      rethrow;
    }
  }

  /// رفع بايتات الصورة الناتجة محلياً إلى Cloudinary لتخزينها في Firestore
  Future<String?> uploadResultBytes(Uint8List bytes) async {
    try {
      debugPrint("Uploading local generated result to Cloudinary...");
      return await CloudinaryService.uploadImageBytes(
        bytes,
        folder: "tryon_results",
      );
    } catch (e) {
      debugPrint("❌ uploadResultBytes error: $e");
      return null;
    }
  }

  /// تشغيل عملية الـ Try-On السحابية (عبر Replicate)
  Future<String?> runVirtualTryOn({
    required dynamic humanImage,
    required dynamic garmentImage,
    required String category,
    String description = "fashionable clothing item",
    required String replicateToken,
  }) async {
    try {
      debugPrint("🚀 Starting Cloud Replicate Try-On...");

      // 1. تجهيز رابط صورة الشخص
      String? humanUrl;
      if (humanImage is File) {
        humanUrl = await CloudinaryService.uploadImage(
          humanImage,
          folder: "tryon_humans",
        );
      } else if (humanImage is String) {
        humanUrl = humanImage;
      }

      if (humanUrl == null || humanUrl.isEmpty) {
        throw Exception("Failed to obtain human image URL.");
      }

      // 2. تجهيز رابط صورة القطعة
      String? garmentUrl;
      if (garmentImage is File) {
        garmentUrl = await CloudinaryService.uploadImage(
          garmentImage,
          folder: "tryon_garments",
        );
      } else if (garmentImage is String) {
        garmentUrl = garmentImage;
      }

      if (garmentUrl == null || garmentUrl.isEmpty) {
        throw Exception("Failed to obtain garment image URL.");
      }

      // 3. إرسال طلب البدء (Prediction) إلى Replicate API
      final startUrl = Uri.parse("https://api.replicate.com/v1/predictions");
      final response = await http.post(
        startUrl,
        headers: {
          "Authorization": "Bearer $replicateToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "version": _modelAbsoluteVersion,
          "input": {
            "crop": false,
            "seed": 42,
            "steps": 25,
            "category": category,
            "force_dc": false,
            "garm_img": garmentUrl,
            "human_img": humanUrl,
            "garment_des": description,
          },
        }),
      );

      if (response.statusCode != 201) {
        final errBody = jsonDecode(response.body);
        throw Exception(
          "Replicate API Error: ${errBody['detail'] ?? response.body}",
        );
      }

      final startData = jsonDecode(response.body);
      final String predictionId = startData['id'];
      final String pollUrlStr = startData['urls']['get'];

      // 4. عمل Polling (مراقبة الحالة كل ثانيتين) حتى يكتمل التوليد
      final pollUrl = Uri.parse(pollUrlStr);
      bool isFinished = false;
      int attempts = 0;
      const int maxAttempts = 60;

      while (!isFinished && attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 2));
        attempts++;

        final pollResponse = await http.get(
          pollUrl,
          headers: {"Authorization": "Bearer $replicateToken"},
        );

        if (pollResponse.statusCode != 200) {
          throw Exception(
            "Error polling prediction state: ${pollResponse.body}",
          );
        }

        final pollData = jsonDecode(pollResponse.body);
        final String status = pollData['status'];

        if (status == "succeeded") {
          isFinished = true;
          final dynamic output = pollData['output'];
          if (output is List && output.isNotEmpty) {
            return output.first.toString();
          } else if (output is String) {
            return output;
          }
          throw Exception("Invalid output format from model.");
        } else if (status == "failed" || status == "canceled") {
          isFinished = true;
          throw Exception("Try-On generation failed or was canceled.");
        }
      }

      throw Exception("Try-On request timed out.");
    } catch (e) {
      debugPrint("❌ runVirtualTryOn error: $e");
      rethrow;
    }
  }
}

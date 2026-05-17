import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class FirebaseTryonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Save the AI suggested Final Outfit into 'my_outfits'
  Future<void> saveFinalOutfitAI(String userId, String topUrl, String bottomUrl) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('my_outfits')
          .add({
        'topImageUrl': topUrl,
        'bottomImageUrl': bottomUrl,
        'suggestedByAI': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint("Outfit successfully saved.");
    } catch (e) {
      debugPrint("Failed to save outfit: $e");
    }
  }

  // 2. Forced Update Logic
  // Checks app_settings to verify if the client needs to update
  Future<void> checkForForcedUpdate(BuildContext context, String currentVersion) async {
    try {
      final doc = await _firestore.collection('app_settings').doc('config').get();
      if (doc.exists) {
        final requiredVersion = doc.data()?['min_required_version'] as String?;
        if (requiredVersion != null && _isVersionOlder(currentVersion, requiredVersion)) {
          showDialog(
            context: context,
            barrierDismissible: false, // Cannot be closed
            builder: (context) {
              return AlertDialog(
                title: const Text('Update Required'),
                content: const Text(
                  'A new version of the app is available. You must update to continue using the app.',
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      // Launch App Store or Google Play dynamically
                    },
                    child: const Text('Update Now'),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      debugPrint("Error checking force update: $e");
    }
  }

  bool _isVersionOlder(String current, String required) {
    // Basic version split and comparing e.g., "1.0.0" < "1.1.0"
    List<int> currParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> reqParts = required.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    for (int i = 0; i < 3; i++) {
      int c = i < currParts.length ? currParts[i] : 0;
      int r = i < reqParts.length ? reqParts[i] : 0;
      if (c < r) return true;
      if (c > r) return false;
    }
    return false;
  }

  // 3. Initialize Firebase Cloud Messaging for Push Notifications
  void initFCM() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
        // You could trigger a local flushbar/snackbar if you want in-app notifications
      }
    });
  }
}

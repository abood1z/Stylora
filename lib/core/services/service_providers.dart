import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'outfit_generator_service.dart';
import 'biometric_auth_service.dart';

import 'two_factor_service.dart';
import 'phone_auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) => BiometricAuthService());
final twoFactorServiceProvider = Provider<TwoFactorService>((ref) => TwoFactorService());
final phoneAuthServiceProvider = Provider<PhoneAuthService>((ref) => PhoneAuthService());

// إضافة خدمة التنسيقات لكي يتم استهلاكها في واجهات المستخدم
final outfitGeneratorServiceProvider = Provider<OutfitGeneratorService>((ref) => OutfitGeneratorService());

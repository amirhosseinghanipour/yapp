library;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

String get _firebaseApiKey =>
    dotenv.maybeGet('FIREBASE_API_KEY') ??
    const String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');

String get _firebaseAppId =>
    dotenv.maybeGet('FIREBASE_APP_ID') ??
    const String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');

String get _firebaseMessagingSenderId =>
    dotenv.maybeGet('FIREBASE_MESSAGING_SENDER_ID') ??
    const String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '',
    );

String get _firebaseProjectId =>
    dotenv.maybeGet('FIREBASE_PROJECT_ID') ??
    const String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');

String get _firebaseStorageBucket =>
    dotenv.maybeGet('FIREBASE_STORAGE_BUCKET') ??
    const String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: '');

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'DefaultFirebaseOptions are only configured for android.',
      );
    }
    return android;
  }

  static FirebaseOptions get android {
    if (_firebaseApiKey.isEmpty ||
        _firebaseAppId.isEmpty ||
        _firebaseMessagingSenderId.isEmpty ||
        _firebaseProjectId.isEmpty) {
      throw StateError(
        'Firebase is not configured; set the FIREBASE_* values in .env',
      );
    }
    return FirebaseOptions(
      apiKey: _firebaseApiKey,
      appId: _firebaseAppId,
      messagingSenderId: _firebaseMessagingSenderId,
      projectId: _firebaseProjectId,
      storageBucket: _firebaseStorageBucket.isEmpty
          ? null
          : _firebaseStorageBucket,
    );
  }
}

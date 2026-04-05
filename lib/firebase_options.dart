// Generated-style fallback firebase_options.dart
// Replace with `flutterfire configure` output in production.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions nao suportado para esta plataforma.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_WEB_API_KEY', defaultValue: ''),
    appId: String.fromEnvironment('FIREBASE_WEB_APP_ID', defaultValue: ''),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '',
    ),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: ''),
    authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: ''),
    storageBucket:
        String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: ''),
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_ANDROID_API_KEY', defaultValue: ''),
    appId: String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: ''),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '',
    ),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: ''),
    storageBucket:
        String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: ''),
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_IOS_API_KEY', defaultValue: ''),
    appId: String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: ''),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '',
    ),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: ''),
    iosBundleId:
        String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: ''),
    storageBucket:
        String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: ''),
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_MACOS_API_KEY', defaultValue: ''),
    appId: String.fromEnvironment('FIREBASE_MACOS_APP_ID', defaultValue: ''),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '',
    ),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: ''),
    iosBundleId:
        String.fromEnvironment('FIREBASE_MACOS_BUNDLE_ID', defaultValue: ''),
    storageBucket:
        String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: ''),
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_WINDOWS_API_KEY', defaultValue: ''),
    appId: String.fromEnvironment('FIREBASE_WINDOWS_APP_ID', defaultValue: ''),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '',
    ),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: ''),
    storageBucket:
        String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: ''),
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_LINUX_API_KEY', defaultValue: ''),
    appId: String.fromEnvironment('FIREBASE_LINUX_APP_ID', defaultValue: ''),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '',
    ),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: ''),
    storageBucket:
        String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: ''),
  );
}

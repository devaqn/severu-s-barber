// firebase_options.dart
// Sem defaults sensiveis: use --dart-define para fornecer credenciais.
// Em desktop, quando vazio, a inicializacao cai em modo offline.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

const String _kFirebaseProjectId = '';
const String _kFirebaseMessagingSenderId = '';
const String _kFirebaseStorageBucket = '';
const String _kFirebaseAuthDomain = '';
const String _kFirebaseApiKey = '';
const String _kFirebaseAndroidAppId = '';
const String _kFirebaseWebAppId = '';

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
    apiKey: String.fromEnvironment(
      'FIREBASE_WEB_API_KEY',
      defaultValue: _kFirebaseApiKey,
    ),
    appId: String.fromEnvironment(
      'FIREBASE_WEB_APP_ID',
      defaultValue: _kFirebaseWebAppId,
    ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: _kFirebaseMessagingSenderId,
    ),
    projectId: String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: _kFirebaseProjectId,
    ),
    authDomain: String.fromEnvironment(
      'FIREBASE_AUTH_DOMAIN',
      defaultValue: _kFirebaseAuthDomain,
    ),
    storageBucket: String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: _kFirebaseStorageBucket,
    ),
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_ANDROID_API_KEY',
      defaultValue: _kFirebaseApiKey,
    ),
    appId: String.fromEnvironment(
      'FIREBASE_ANDROID_APP_ID',
      defaultValue: _kFirebaseAndroidAppId,
    ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: _kFirebaseMessagingSenderId,
    ),
    projectId: String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: _kFirebaseProjectId,
    ),
    storageBucket: String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: _kFirebaseStorageBucket,
    ),
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_IOS_API_KEY',
      defaultValue: _kFirebaseApiKey,
    ),
    appId: String.fromEnvironment(
      'FIREBASE_IOS_APP_ID',
      defaultValue: _kFirebaseWebAppId,
    ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: _kFirebaseMessagingSenderId,
    ),
    projectId: String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: _kFirebaseProjectId,
    ),
    iosBundleId: String.fromEnvironment(
      'FIREBASE_IOS_BUNDLE_ID',
      defaultValue: 'com.severusbarber.app',
    ),
    storageBucket: String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: _kFirebaseStorageBucket,
    ),
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_MACOS_API_KEY',
      defaultValue: _kFirebaseApiKey,
    ),
    appId: String.fromEnvironment(
      'FIREBASE_MACOS_APP_ID',
      defaultValue: _kFirebaseWebAppId,
    ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: _kFirebaseMessagingSenderId,
    ),
    projectId: String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: _kFirebaseProjectId,
    ),
    iosBundleId: String.fromEnvironment(
      'FIREBASE_MACOS_BUNDLE_ID',
      defaultValue: 'com.severusbarber.app',
    ),
    storageBucket: String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: _kFirebaseStorageBucket,
    ),
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_WINDOWS_API_KEY',
      defaultValue: _kFirebaseApiKey,
    ),
    appId: String.fromEnvironment(
      'FIREBASE_WINDOWS_APP_ID',
      defaultValue: _kFirebaseWebAppId,
    ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: _kFirebaseMessagingSenderId,
    ),
    projectId: String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: _kFirebaseProjectId,
    ),
    storageBucket: String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: _kFirebaseStorageBucket,
    ),
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_LINUX_API_KEY',
      defaultValue: _kFirebaseApiKey,
    ),
    appId: String.fromEnvironment(
      'FIREBASE_LINUX_APP_ID',
      defaultValue: _kFirebaseWebAppId,
    ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: _kFirebaseMessagingSenderId,
    ),
    projectId: String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: _kFirebaseProjectId,
    ),
    storageBucket: String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: _kFirebaseStorageBucket,
    ),
  );
}

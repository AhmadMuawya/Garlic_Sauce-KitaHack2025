import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'secrets/firebase_keys.dart';

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return FirebaseKeys.web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return FirebaseKeys.android;
      case TargetPlatform.iOS:
        return FirebaseKeys.ios;
      case TargetPlatform.macOS:
        return FirebaseKeys.macos;
      case TargetPlatform.windows:
        return FirebaseKeys.windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
}

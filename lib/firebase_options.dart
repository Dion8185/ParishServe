// =============================================================================
// FILE: lib/firebase_options.dart
// =============================================================================

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
      default:
        return web;
    }
  }

  // 1. Web Configuration (Chrome / Edge / Browser)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDBm_9W_I45t326urqp2N0Abjt0gwfV3a0',
    appId: '1:620738454065:web:809d7fe206ac398537eb10',
    messagingSenderId: '620738454065',
    projectId: 'parishserve',
    authDomain: 'parishserve.firebaseapp.com',
    databaseURL: 'https://parishserve-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'parishserve.firebasestorage.app',
  );

  // 2. Android Configuration (Mobile Device / Emulator)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDBm_9W_I45t326urqp2N0Abjt0gwfV3a0',
    appId: '1:620738454065:web:809d7fe206ac398537eb10',
    messagingSenderId: '620738454065',
    projectId: 'parishserve',
    authDomain: 'parishserve.firebaseapp.com',
    databaseURL: 'https://parishserve-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'parishserve.firebasestorage.app',
  );
}
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCWV-BrkeIg9qG29oDyVS7ka-nRTkuxMmc',
    appId: '1:240909232949:web:194bd6d6c8f3a467387a7c',
    messagingSenderId: '240909232949',
    projectId: 'sari-89290',
    authDomain: 'sari-89290.firebaseapp.com',
    databaseURL: 'https://sari-89290-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'sari-89290.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCwy44vQAqCV1OojDtpvsxW-lXVGycYiEI',
    appId: '1:240909232949:android:d11a9ea0fe706dee387a7c',
    messagingSenderId: '240909232949',
    projectId: 'sari-89290',
    databaseURL: 'https://sari-89290-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'sari-89290.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD0Ax_8hzWFyC3Ix2fP39ZcyZAUqpfSkTg',
    appId: '1:240909232949:ios:019c7655c847cd82387a7c',
    messagingSenderId: '240909232949',
    projectId: 'sari-89290',
    databaseURL: 'https://sari-89290-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'sari-89290.firebasestorage.app',
    iosBundleId: 'com.example.sariSari',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD0Ax_8hzWFyC3Ix2fP39ZcyZAUqpfSkTg',
    appId: '1:240909232949:ios:019c7655c847cd82387a7c',
    messagingSenderId: '240909232949',
    projectId: 'sari-89290',
    databaseURL: 'https://sari-89290-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'sari-89290.firebasestorage.app',
    iosBundleId: 'com.example.sariSari',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCWV-BrkeIg9qG29oDyVS7ka-nRTkuxMmc',
    appId: '1:240909232949:web:69fa98de9c2ba8a2387a7c',
    messagingSenderId: '240909232949',
    projectId: 'sari-89290',
    authDomain: 'sari-89290.firebaseapp.com',
    databaseURL: 'https://sari-89290-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'sari-89290.firebasestorage.app',
  );
}

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCvHwJ1qyqAXyW6u7dsbgAHNRIoI80ZMRk',
    appId: '1:787119632003:web:f3f4edb35d314b5aee75b6',
    messagingSenderId: '787119632003',
    projectId: 'tvi-news',
    authDomain: 'tvi-news.firebaseapp.com',
    storageBucket: 'tvi-news.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAAqZ5f_SqNL0nZbR1Kq8FHYLDzXiyH-3E',
    appId: '1:787119632003:android:05eb8d45a643347fee75b6',
    messagingSenderId: '787119632003',
    projectId: 'tvi-news',
    storageBucket: 'tvi-news.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAAqZ5f_SqNL0nZbR1Kq8FHYLDzXiyH-3E',
    appId: '1:787119632003:ios:a3f307fd45496a30ee75b6',
    messagingSenderId: '787119632003',
    projectId: 'tvi-news',
    storageBucket: 'tvi-news.firebasestorage.app',
  );
}

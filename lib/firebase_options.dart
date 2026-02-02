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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyCQTkc3tnUKqdzqJqbNCczrMmttyHWOJ3c',
    appId: '1:220364613204:web:0bc6a5b079551c64b32fc1',
    messagingSenderId: '220364613204',
    projectId: 'hydroharvest-1bfd0',
    authDomain: 'hydroharvest-1bfd0.firebaseapp.com',
    storageBucket: 'hydroharvest-1bfd0.firebasestorage.app',
    databaseURL: 'https://hydroharvest-1bfd0-default-rtdb.firebaseio.com/',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCQTkc3tnUKqdzqJqbNCczrMmttyHWOJ3c',
    appId: '1:220364613204:android:0bc6a5b079551c64b32fc1',
    messagingSenderId: '220364613204',
    projectId: 'hydroharvest-1bfd0',
    storageBucket: 'hydroharvest-1bfd0.firebasestorage.app',
    databaseURL: 'https://hydroharvest-1bfd0-default-rtdb.firebaseio.com/',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCQTkc3tnUKqdzqJqbNCczrMmttyHWOJ3c',
    appId: '1:220364613204:ios:0bc6a5b079551c64b32fc1',
    messagingSenderId: '220364613204',
    projectId: 'hydroharvest-1bfd0',
    storageBucket: 'hydroharvest-1bfd0.firebasestorage.app',
    databaseURL: 'https://hydroharvest-1bfd0-default-rtdb.firebaseio.com/',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCQTkc3tnUKqdzqJqbNCczrMmttyHWOJ3c',
    appId: '1:220364613204:ios:0bc6a5b079551c64b32fc1',
    messagingSenderId: '220364613204',
    projectId: 'hydroharvest-1bfd0',
    storageBucket: 'hydroharvest-1bfd0.firebasestorage.app',
    databaseURL: 'https://hydroharvest-1bfd0-default-rtdb.firebaseio.com/',
  );
}

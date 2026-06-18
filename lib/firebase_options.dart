import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web não configurado');
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Plataforma não configurada para Firebase');
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBK7vAbCSArXn1BCdpIsvoDq5u-ydqAiIw',
    appId: '1:93554196521:ios:e6e81a274ce6ce29df5c38',
    messagingSenderId: '93554196521',
    projectId: 'vem-pro-parque-16f7e',
    storageBucket: 'vem-pro-parque-16f7e.firebasestorage.app',
    iosBundleId: 'com.vemproparquema',
  );
}

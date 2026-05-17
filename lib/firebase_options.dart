// Configuracion de Firebase para Web.
// Para habilitar plataformas adicionales (Android/iOS/desktop), ejecuta:
//   flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static bool get isSupportedPlatform => kIsWeb;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'Firebase esta configurado solo para Web en este proyecto. '
      'Ejecuta: flutterfire configure para habilitar esta plataforma.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCNQlCEV9jJwXYirEvxWIwMaQHaqd4EPo8',
    appId: '1:1062396228506:web:0ffa872dd0387c11a38023',
    messagingSenderId: '1062396228506',
    projectId: 'restaura-a1e34',
    authDomain: 'restaura-a1e34.firebaseapp.com',
    storageBucket: 'restaura-a1e34.firebasestorage.app',
    measurementId: 'G-6Y6XYD4P8Y',
  );
}

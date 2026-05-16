// ARCHIVO GENERADO — reemplazar ejecutando:
//   flutterfire configure
//
// Este archivo es un placeholder para que el proyecto compile.
// Sin ejecutar `flutterfire configure` Firebase NO funcionará.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'Firebase no configurado para iOS. '
          'Ejecuta: flutterfire configure',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'Firebase no configurado para macOS. '
          'Ejecuta: flutterfire configure',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'Firebase no configurado para Windows. '
          'Ejecuta: flutterfire configure',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Firebase no configurado para Linux. '
          'Ejecuta: flutterfire configure',
        );
      default:
        throw UnsupportedError(
          'Plataforma no soportada. Ejecuta: flutterfire configure',
        );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ⚠️  REEMPLAZAR ESTOS VALORES ejecutando: flutterfire configure
  //     Los valores reales se obtienen de la consola de Firebase.
  // ─────────────────────────────────────────────────────────────────────────

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REEMPLAZAR_CON_flutterfire_configure',
    appId: 'REEMPLAZAR_CON_flutterfire_configure',
    messagingSenderId: 'REEMPLAZAR_CON_flutterfire_configure',
    projectId: 'REEMPLAZAR_CON_flutterfire_configure',
    authDomain: 'REEMPLAZAR_CON_flutterfire_configure',
    storageBucket: 'REEMPLAZAR_CON_flutterfire_configure',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REEMPLAZAR_CON_flutterfire_configure',
    appId: 'REEMPLAZAR_CON_flutterfire_configure',
    messagingSenderId: 'REEMPLAZAR_CON_flutterfire_configure',
    projectId: 'REEMPLAZAR_CON_flutterfire_configure',
    storageBucket: 'REEMPLAZAR_CON_flutterfire_configure',
  );
}

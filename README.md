# restaurant_app

Aplicación Flutter para gestión de restaurante con arquitectura híbrida:

- SQLite local como fuente de verdad offline.
- Firestore como sincronización multi-dispositivo.

## Estrategia de Sync por Plataforma

Actualmente la sincronización cloud está habilitada donde Firebase está
configurado en `firebase_options.dart`.

- Plataformas soportadas por Firebase config: sincronizan SQLite <-> Firestore.
- Plataformas sin Firebase config: corren en modo local-only (SQLite),
  sin sync cloud.

Esto evita estados "a medias" en preproducción.

Para habilitar más plataformas (Android/iOS/desktop), generar configuración:

```bash
flutterfire configure
```

## Reglas de Firestore

Este repo versiona reglas en `firestore.rules` y referencia en `firebase.json`.

Despliegue:

```bash
npx firebase-tools deploy --only firestore:rules --project <tu-project-id>
```

Si no has autenticado CLI aún:

```bash
npx firebase-tools login
```

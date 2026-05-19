# restaurant_app

Aplicación Flutter para gestión de restaurante con arquitectura híbrida:

- SQLite local como fuente de verdad offline.
- Firebase Realtime Database como sincronización multi-dispositivo.

## Estrategia de Sync por Plataforma

Actualmente la sincronización cloud está habilitada cuando existe la
configuración de Realtime Database por variable de entorno.

- Plataformas con `FIREBASE_DATABASE_URL`: sincronizan SQLite <-> Realtime Database.
- Plataformas sin `FIREBASE_DATABASE_URL`: corren en modo local-only (SQLite),
  sin sync cloud.

Esto evita estados "a medias" en preproducción.

## Reglas de Realtime Database

Define reglas de Realtime Database desde Firebase Console para la ruta que uses.

En este proyecto se sincroniza bajo:

```text
restaurantes/{restaurantId}/{tabla}/{documentId}
```

Variables de entorno recomendadas:

```bash
FIREBASE_DATABASE_URL=https://<tu-proyecto>-default-rtdb.firebaseio.com
```

Si no has autenticado CLI aún:

```bash
npx firebase-tools login
```

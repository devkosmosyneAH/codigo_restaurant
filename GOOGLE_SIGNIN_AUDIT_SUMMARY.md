# Resumen de auditoría: Google Sign-In / Drive (Restaurante)

**Fecha:** 2026-07-23

## Resumen ejecutivo

Auditoría del flujo de autenticación Google Sign-In y uso de Google Drive en el proyecto **Restaurante**. Se identificó un flag de restauración único que bloqueaba reintentos (`_hasRestoredSession`) y una llamada temprana a restauración en el arranque que generaba condiciones de carrera. Aplicadas correcciones para permitir reintentos controlados y retrasar la restauración hasta post-frame.

## Cambios aplicados

- **Removido flag problemático:** Eliminé el flag `_hasRestoredSession` que impedía reintentos.
- **Corrección de flujo de restauración silenciosa:** `signInSilently()` ahora reutiliza y limpia correctamente `_restoreFuture`, maneja errores y retorna adecuadamente.
- **Inicio retrasado de restauración:** Moví la llamada de restauración de sesión a `addPostFrameCallback` en el arranque para evitar race conditions.

Archivos modificados:

- [lib/services/google_auth_service.dart](lib/services/google_auth_service.dart)
- [lib/main.dart](lib/main.dart)

## Problemas encontrados (resumen)

- `_hasRestoredSession` bloqueaba futuros intentos de restauración después del primer fallo o intento sin sesión válida.
- `restoreSession()` se invocaba muy temprano en `main()`, antes de que los plugins nativos estuvieran completamente listos, provocando restauraciones fallidas y estado inconsistente.
- Posible mismatch entre expiry de `idToken` y `accessToken` — la estrategia actual infería expiry del `idToken` y puede no reflejar la validez real del `accessToken`.

## Recomendaciones y próximos pasos

1. Ejecutar análisis y tests localmente:

```bash
flutter analyze
flutter test
```

1. Probar manualmente en las plataformas objetivo (web, móvil y desktop):
   - Iniciar la app, verificar que la restauración silenciosa no rompe el arranque.
   - En panel admin, llamar a la comprobación silenciosa y luego forzar conexión interactiva.

2. Robustecer el manejo de tokens:
   - Preferir solicitar `accessToken` por operación y, ante 401, forzar `getAccessToken(forceRefresh: true)` y reintentar la petición.
   - Evitar depender exclusivamente del `idToken` para programar refrescos; en su lugar, refrescar en fallos o pedir token por request.

3. Añadir logs temporales alrededor de:
   - `ensureDriveAuthenticated()` en [lib/services/google_auth_service.dart](lib/services/google_auth_service.dart)
   - Validación runtime de Drive en [lib/services/drive_backup_service.dart](lib/services/drive_backup_service.dart) y en [lib/features/menu/data/services/drive_menu_connection_service_io.dart](lib/features/menu/data/services/drive_menu_connection_service_io.dart)

4. Considerar pruebas E2E que simulen revocar permisos y reintentar conexión para validar reauth flow.

## Notas operativas

- Los cambios realizados están limitados y focalizados en permitir reintentos y evitar bloqueo en arranque.
- No se cambió la política de scopes ni la intención de solicitar permisos interactivos — solo la resiliencia del flujo de restauración.

Si quieres, aplico parches adicionales propuestos (p. ej. manejo de 401 con reauth centralizada), añado logs o preparo pruebas automatizadas. ¿Qué prefieres que haga a continuación?

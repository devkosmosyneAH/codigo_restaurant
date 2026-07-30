# La Peña — Sistema de gestión para restaurante

Aplicación Flutter para administrar la operación de un restaurante. Está diseñada para funcionar primero de forma local con SQLite y, cuando Firebase está disponible, sincronizar información entre dispositivos. La interfaz está en español y el proyecto se llama técnicamente `restaurant_app`.

Versión declarada: `1.0.1+2`.

## Qué hace el programa

El sistema cubre estas áreas:

| Módulo | Funcionalidad |
| --- | --- |
| Inicio | Panel principal de operación y acceso a los módulos según el rol del usuario. |
| Mesas | Crear y administrar mesas; estados libre, ocupada y reservada; generar QR para ellas y atender llamados de mesero. |
| Pedidos | Crear pedidos internos o desde una mesa, añadir productos/variantes y seguir el estado del pedido. |
| Cocina | Mostrar pedidos activos y moverlos por el flujo de preparación. |
| Menú | Crear categorías, productos, variantes, precios, disponibilidad e imágenes. Puede conectarse a Google Drive para imágenes y menú. |
| Menú y pedido público | Mostrar el menú sin iniciar sesión; desde un QR de mesa el cliente puede enviar un pedido para aprobación. |
| Reservas | Registrar reservas de mesa o de local/evento, consultar calendario y aceptar solicitudes públicas. |
| Cotizaciones | Crear cotizaciones manuales o desde el menú público, publicarlas mediante enlace, aceptarlas/rechazarlas y exportarlas a PDF. |
| Caja | Cobrar pedidos en efectivo, tarjeta o transferencia; imprimir/generar ticket y preparar facturas. |
| Clientes | Mantener un directorio de clientes para ventas y facturación. |
| Reportes | Consultar resumen de ventas, ventas por día, producto, mesero y método de pago. |
| Usuarios | Crear usuarios con rol y PIN; controlar administradores y bloqueo temporal por intentos de acceso fallidos. |
| Página pública | Configurar página del restaurante, datos de contacto, redes, ubicación/mapa, menú y reservas públicas. |
| Sincronización | Registrar cambios locales y sincronizarlos con Firebase Realtime Database cuando exista conectividad. |
| Respaldos | Crear, listar, restaurar, importar/exportar respaldos locales y respaldar en Google Drive. |

## Flujos principales

### Operación de salón y cocina

```text
Mesa o menú público → pedido pendiente de aprobación / creado
→ aceptado → en preparación → finalizado → entregado → cobro en caja
```

Un pedido público se asocia a la mesa indicada en el QR. El personal lo aprueba antes de que entre en el flujo normal de cocina. Las mesas pueden generar llamados de mesero que el personal atiende desde el módulo correspondiente.

### Venta y facturación

Al cobrar se crea una venta y sus detalles, se registra el método de pago y se puede emitir un ticket. El código también prepara el flujo de factura electrónica ecuatoriana: genera XML preliminar, clave de acceso, secuencial, RIDE en PDF y una cola de reintentos.

La autorización real ante el SRI no ocurre íntegramente en Flutter: requiere configurar y desplegar un **backend puente** para custodiar el certificado `.p12`, firmar XAdES-BES, comunicarse con SRI y enviar correos. El valor base actual del puente es de ejemplo (`https://api.tu-dominio.com/sri`), por lo que no debe considerarse una integración SRI productiva lista sin esa configuración.

### Datos y sincronización

```text
Pantallas/widgets → providers (Riverpod/ChangeNotifier)
→ casos de uso/repositorios → SQLite local
→ sync_log → Firebase Realtime Database (si está disponible)
```

- SQLite es la fuente de datos local y permite operar sin conexión.
- Cada cambio sincronizable se guarda en `sync_log`; se fusionan cambios repetidos de la misma entidad y se aplican reintentos con espera progresiva.
- Los datos se organizan por restaurante/tenant: `restaurantes/{restaurantId}/{tabla}/{documentId}`.
- Hay auditorías locales de sincronización y seguridad.
- El proyecto incluye reglas para Realtime Database y Firestore. El código de sincronización usa Realtime Database; Firestore queda como reglas/preparación de seguridad y no como la fuente principal actual.

## Roles y permisos

| Rol | Acceso principal |
| --- | --- |
| Administrador | Acceso total, incluida configuración, usuarios, menú, sincronización y respaldos. |
| Cajero | Pedidos, caja, clientes y reportes. |
| Mesero | Inicio, mesas y pedidos. |
| Cocina | Únicamente la pantalla de cocina. |

Las rutas públicas —menú, reservas, página del restaurante, cotización y pedido por mesa— no requieren autenticación ni activación de la aplicación. Las demás exigen activación y sesión válida.

## Rutas públicas

Las rutas se definen en `lib/Presentation/config/routes/app_router.dart`:

| Ruta | Uso |
| --- | --- |
| `/menu-public?mesa=<id>` | Menú público, opcionalmente asociado a una mesa. |
| `/pedido-mesa?mesa=<id>&nombre=<nombre>` | Pedido público desde QR de mesa. |
| `/reservas-public` | Solicitud pública de reserva. |
| `/restaurante` | Página pública del restaurante. |
| `/c/<id>` | Consulta pública de una cotización. |

## Arquitectura y estructura

El código se encuentra principalmente en `lib/Presentation/`, aunque la organización sigue capas separadas:

```text
lib/
├── main.dart                         Arranque de Flutter, Firebase, base local y sesión
└── Presentation/
    ├── app_startup/                  Inicialización específica por plataforma
    ├── config/routes/                Rutas, redirecciones y autorización
    ├── core/                         Base de datos, DI, tema, tenant, sync y utilidades
    ├── entities/                     Entidades del dominio
    ├── Models/                       Serialización/modelos de persistencia
    ├── data/                         Datasources y repositorios SQLite
    ├── domain/                       Contratos de repositorio y casos de uso
    ├── providers/                    Estado de la interfaz (Riverpod y ChangeNotifier)
    ├── services/                     Firebase, Drive, PDF, backup, SRI y sesión
    ├── views/                        Páginas de cada módulo
    └── widgets/                      Componentes reutilizables
```

La base local crea tablas para restaurantes, usuarios, mesas, menú (categorías, productos y variantes), pedidos e ítems, ventas y detalles, clientes, reservas, cotizaciones e ítems, ingredientes, llamados, configuración pública, sincronización/auditoría y el conjunto de tablas SRI.

## Tecnologías e integraciones

- Flutter y Dart (`SDK ^3.8.1`), con soporte para Android, iOS, web, Windows, macOS y Linux.
- `go_router` para navegación, `flutter_riverpod`/`provider` para estado y `get_it` para inyección de dependencias.
- SQLite (`sqflite`, FFI y web) como almacenamiento local.
- Firebase Auth y Firebase Realtime Database para autenticación y sincronización.
- Google Sign-In y Google Drive para imágenes y respaldos.
- PDF/Printing para tickets, cotizaciones y RIDE; QR para mesas.
- OpenStreetMap (`flutter_map`) para la ubicación pública.

## Configuración necesaria

Las credenciales de Drive/Firebase están parcialmente incorporadas en archivos de plataforma y el proyecto admite sobrescribir valores de compilación con `--dart-define`. Para una instalación propia o de producción, configurar como mínimo:

```bash
flutter run \
  --dart-define=FIREBASE_DATABASE_URL=https://<proyecto>-default-rtdb.firebaseio.com \
  --dart-define=DRIVE_ROOT_FOLDER_ID=<carpeta-raiz-drive> \
  --dart-define=GOOGLE_CLIENT_ID=<cliente-oauth> \
  --dart-define=GOOGLE_API_KEY=<api-key-restringida>
```

También deben revisarse antes de publicar:

- Reglas de Firebase en `database.rules.json` y `firestore.rules`.
- Restricciones del cliente OAuth/API key en Google Cloud.
- Identificadores de Android/iOS y los archivos de configuración Firebase.
- URL, autenticación y certificados del backend puente SRI.
- URL de actualización automática: actualmente es un marcador de posición en `app_constants.dart`.

> Importante: aunque el README antiguo describía la sincronización como opcional cuando no se definía `FIREBASE_DATABASE_URL`, el código actual tiene una URL de Firebase predeterminada. Por tanto, revisar esa configuración antes de reutilizar o desplegar el proyecto para otro restaurante.

## Ejecutar el proyecto

```bash
flutter pub get
flutter run
```

Comandos de mantenimiento:

```bash
flutter analyze
flutter test
flutter build web
```

## Pruebas y estado observado

El repositorio incluye pruebas de autenticación/sesión, multi-tenant, menú público, pedidos/cocina, cotizaciones, reservas, sincronización, respaldos, seguridad de PIN, SRI, reportes y rutas.

Revisión realizada el 30 de julio de 2026:

- `flutter analyze` termina con **6 hallazgos**: 1 advertencia por un elemento no usado y 5 informativos.
- El hallazgo más relevante está en `app_router.dart`: dentro de la redirección se compara una ruta de texto con el notifier de activación, en vez de comparar con la constante de ruta. Esto puede impedir reconocer correctamente la página de activación.
- `flutter test` no pasa completamente: se observaron **74 pruebas ejecutadas y 24 fallos**. Parte de los errores se producen porque las pruebas inicializan pantallas/servicios que acceden a Firebase sin haber inicializado Firebase, o porque el contenedor `GetIt` no tiene registrado `FirebaseAuthService` en la prueba.
- Otras pruebas del menú público esperan el botón/texto **“Cotizar”** y no lo encuentran; parece haber una diferencia entre la interfaz actual y lo que esperan esos tests. Conviene decidir si se restaura esa acción o se actualizan las pruebas según el comportamiento deseado.

## Prioridad sugerida para las correcciones

1. Corregir la comparación de la ruta de activación en el router y cubrirla con una prueba de redirección.
2. Hacer que las pruebas tengan inicialización/mocks consistentes de Firebase y registros completos de `GetIt`.
3. Resolver la discrepancia del botón/flujo “Cotizar” en el menú público.
4. Definir la configuración real de Firebase, Drive y SRI fuera de valores por defecto o marcadores de ejemplo.
5. Corregir los avisos menores de análisis: elemento sin usar, llaves en condicionales y reemplazo futuro de `withOpacity`.
6. Revisar dependencias: el análisis informó 123 paquetes con versiones nuevas incompatibles con los límites actuales; actualizar por etapas y con pruebas.

## Archivos clave para futuras modificaciones

| Archivo/directorio | Cuándo revisarlo |
| --- | --- |
| `lib/main.dart` | Para cambiar el orden de inicio de servicios. |
| `lib/Presentation/config/routes/app_router.dart` | Para rutas, login, activación y permisos. |
| `lib/Presentation/core/database/database_tables.dart` | Para tablas y migraciones SQLite. |
| `lib/Presentation/core/sync/` | Para la cola y reglas de sincronización offline/cloud. |
| `lib/Presentation/core/tenant/tenant_context.dart` | Para comportamiento multi-restaurante. |
| `lib/Presentation/services/facturacion/` | Para facturación electrónica y SRI. |
| `lib/Presentation/services/drive_backup_service.dart` | Para respaldos en Drive. |
| `lib/Presentation/views/` y `widgets/` | Para cambios visuales y de flujo de cada módulo. |
| `test/` | Para actualizar o ampliar las validaciones al corregir funcionalidades. |

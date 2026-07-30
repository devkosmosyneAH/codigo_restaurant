import 'package:get_it/get_it.dart';
import 'package:restaurant_app/Presentation/core/database/database_helper.dart';
import 'package:restaurant_app/Presentation/core/sync/hybrid_sync_orchestrator.dart';
import 'package:restaurant_app/Presentation/core/sync/sync_cloud_service.dart';
import 'package:restaurant_app/Presentation/core/sync/sync_manager.dart';
import 'package:restaurant_app/Presentation/core/tenant/tenant_context.dart';
import 'package:restaurant_app/Presentation/data/caja/caja_local_datasource.dart';
import 'package:restaurant_app/Presentation/data/caja/caja_local_datasource_impl.dart';
import 'package:restaurant_app/Presentation/data/caja/caja_repository_impl.dart';
import 'package:restaurant_app/Presentation/data/clientes/cliente_local_datasource.dart';
import 'package:restaurant_app/Presentation/data/clientes/cliente_local_datasource_impl.dart';
import 'package:restaurant_app/Presentation/data/clientes/cliente_repository_impl.dart';
import 'package:restaurant_app/Presentation/data/cotizaciones/cotizacion_local_datasource.dart';
import 'package:restaurant_app/Presentation/data/cotizaciones/cotizacion_local_datasource_impl.dart';
import 'package:restaurant_app/Presentation/data/cotizaciones/cotizacion_repository_impl.dart';
import 'package:restaurant_app/Presentation/data/menu/drive_connection_local_datasource.dart';
import 'package:restaurant_app/Presentation/data/menu/llamado_local_datasource_impl.dart';
import 'package:restaurant_app/Presentation/data/menu/menu_local_datasource.dart';
import 'package:restaurant_app/Presentation/data/menu/menu_local_datasource_impl.dart';
import 'package:restaurant_app/Presentation/data/menu/menu_repository_impl.dart';
import 'package:restaurant_app/Presentation/data/mesas/llamado_local_datasource.dart';
import 'package:restaurant_app/Presentation/data/mesas/llamado_repository_impl.dart';
import 'package:restaurant_app/Presentation/data/mesas/mesa_local_datasource.dart';
import 'package:restaurant_app/Presentation/data/mesas/mesa_local_datasource_impl.dart';
import 'package:restaurant_app/Presentation/data/mesas/mesa_repository_impl.dart';
import 'package:restaurant_app/Presentation/data/pagina_publica/public_config_datasource.dart';
import 'package:restaurant_app/Presentation/data/pagina_publica/public_config_datasource_impl.dart';
import 'package:restaurant_app/Presentation/data/pagina_publica/public_config_repository_impl.dart';
import 'package:restaurant_app/Presentation/data/pedidos/pedido_local_datasource.dart';
import 'package:restaurant_app/Presentation/data/pedidos/pedido_local_datasource_impl.dart';
import 'package:restaurant_app/Presentation/data/pedidos/pedido_repository_impl.dart';
import 'package:restaurant_app/Presentation/data/reportes/reportes_local_datasource.dart';
import 'package:restaurant_app/Presentation/data/reportes/reportes_local_datasource_impl.dart';
import 'package:restaurant_app/Presentation/data/reportes/reportes_repository_impl.dart';
import 'package:restaurant_app/Presentation/data/reservaciones/reserva_local_datasource.dart';
import 'package:restaurant_app/Presentation/data/reservaciones/reserva_local_datasource_impl.dart';
import 'package:restaurant_app/Presentation/data/reservaciones/reserva_repository_impl.dart';
import 'package:restaurant_app/Presentation/data/usuarios/usuario_local_datasource.dart';
import 'package:restaurant_app/Presentation/data/usuarios/usuario_local_datasource_impl.dart';
import 'package:restaurant_app/Presentation/data/usuarios/usuario_repository_impl.dart';
import 'package:restaurant_app/Presentation/domain/caja/repositories/caja_repository.dart';
import 'package:restaurant_app/Presentation/domain/caja/usecases/caja_usecases.dart';
import 'package:restaurant_app/Presentation/domain/clientes/repositories/cliente_repository.dart';
import 'package:restaurant_app/Presentation/domain/clientes/usecases/cliente_usecases.dart';
import 'package:restaurant_app/Presentation/domain/cotizaciones/repositories/cotizacion_repository.dart';
import 'package:restaurant_app/Presentation/domain/cotizaciones/usecases/cotizacion_usecases.dart';
import 'package:restaurant_app/Presentation/domain/menu/repositories/menu_repository.dart';
import 'package:restaurant_app/Presentation/domain/menu/usecases/menu_usecases.dart';
import 'package:restaurant_app/Presentation/domain/mesas/repositories/llamado_repository.dart';
import 'package:restaurant_app/Presentation/domain/mesas/repositories/mesa_repository.dart';
import 'package:restaurant_app/Presentation/domain/mesas/usecases/llamado_usecases.dart';
import 'package:restaurant_app/Presentation/domain/mesas/usecases/mesa_usecases.dart';
import 'package:restaurant_app/Presentation/domain/pagina_publica/repositories/public_config_repository.dart';
import 'package:restaurant_app/Presentation/domain/pagina_publica/usecases/public_config_usecases.dart';
import 'package:restaurant_app/Presentation/domain/pedidos/repositories/pedido_repository.dart';
import 'package:restaurant_app/Presentation/domain/pedidos/usecases/pedido_usecases.dart';
import 'package:restaurant_app/Presentation/domain/reportes/repositories/reportes_repository.dart';
import 'package:restaurant_app/Presentation/domain/reportes/usecases/reportes_usecases.dart';
import 'package:restaurant_app/Presentation/domain/reservaciones/repositories/reserva_repository.dart';
import 'package:restaurant_app/Presentation/domain/reservaciones/usecases/reserva_usecases.dart';
import 'package:restaurant_app/Presentation/domain/usuarios/repositories/usuario_repository.dart';
import 'package:restaurant_app/Presentation/domain/usuarios/usecases/usuario_usecases.dart';
import 'package:restaurant_app/Presentation/providers/auth/activation_provider.dart';
import 'package:restaurant_app/Presentation/providers/auth/auth_provider.dart';
import 'package:restaurant_app/Presentation/services/clientes/cliente_service.dart';
import 'package:restaurant_app/Presentation/services/clientes/cliente_service_impl.dart';
import 'package:restaurant_app/Presentation/services/drive_auth_coordinator.dart';
import 'package:restaurant_app/Presentation/services/drive_backup_service.dart';
import 'package:restaurant_app/Presentation/services/facturacion/sri_service.dart';
import 'package:restaurant_app/Presentation/services/firebase_auth_service.dart';
import 'package:restaurant_app/Presentation/services/menu/drive_image_sync_queue_service.dart';
import 'package:restaurant_app/Presentation/services/menu/drive_menu_connection_service_web.dart';
import 'package:restaurant_app/Presentation/services/menu/menu_sync_diagnostics_service.dart';

/// Service Locator global.
///
/// Usa [GetIt] para inyección de dependencias.
/// Aquí se registran todas las dependencias del sistema:
/// - Database helpers
/// - Repositorios
/// - Casos de uso
/// - Managers
final sl = GetIt.instance;

/// Inicializa todas las dependencias de la aplicación.
///
/// Se llama una vez al inicio en [main.dart].
Future<void> initDependencies() async {
  // ── Core ─────────────────────────────────────────────────────────
  sl.registerLazySingleton<DatabaseHelper>(() => DatabaseHelper.instance);
  sl.registerLazySingleton<SyncManager>(() => SyncManager());
  sl.registerLazySingleton<SyncCloudService>(() => SyncCloudService());
  sl.registerLazySingleton<TenantContext>(() => TenantContext());
  sl.registerLazySingleton<HybridSyncOrchestrator>(
    () => HybridSyncOrchestrator(
      syncManager: sl(),
      cloudService: sl(),
      dbHelper: sl(),
      tenantContext: sl(),
      beforePushHook: () async {
        if (sl.isRegistered<DriveImageSyncQueueService>()) {
          await sl<DriveImageSyncQueueService>().processPendingOperations();
        }
      },
    ),
  );
  sl.registerLazySingleton<ActivationChangeNotifier>(
    () => ActivationChangeNotifier(),
  );
  sl.registerLazySingleton<AuthChangeNotifier>(() => AuthChangeNotifier());
  sl.registerLazySingleton<SriService>(() => SriServiceImpl());

  // ── Autenticación centralizada ───────────────────────────────────
  // IMPORTANTE: DriveAuthCoordinator centraliza el acceso a Drive y al
  // token de Google, mientras que GoogleAuthService queda como implementación
  // interna delegada desde el coordinador.
  // Registramos los servicios de forma perezosa (lazy) para evitar la
  // inicialización temprana de GoogleSignIn en la web.
  sl.registerLazySingleton<DriveAuthCoordinator>(
    () => DriveAuthCoordinator.instance,
  );
  sl.registerLazySingleton<FirebaseAuthService>(
    () => FirebaseAuthService.instance,
  );
  sl.registerLazySingleton<DriveBackupService>(
    () => DriveBackupService.instance,
  );

  // ── Features ─────────────────────────────────────────────────────
  _initMesas();
  _initPedidos();
  _initMenu();
  _initCotizaciones();
  _initReservas();
  _initCaja();
  _initReportes();
  _initUsuarios();
  _initPaginaPublica();
  _initClientes();

  // No iniciar la base de datos local automáticamente.
  // Las operaciones de Firebase/Drive se usan sin conexión local SQL.
}

/// Registra las dependencias del módulo de Mesas.
void _initMesas() {
  // DataSources
  sl.registerLazySingleton<MesaLocalDataSource>(
    () => MesaLocalDataSourceImpl(
      dbHelper: sl(),
      syncManager: sl(),
      tenantContext: sl(),
    ),
  );
  sl.registerLazySingleton<LlamadoLocalDataSource>(
    () => LlamadoLocalDataSourceImpl(
      dbHelper: sl(),
      syncManager: sl(),
      tenantContext: sl(),
    ),
  );
  // Repositories
  sl.registerLazySingleton<MesaRepository>(
    () => MesaRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton<LlamadoRepository>(
    () => LlamadoRepositoryImpl(dataSource: sl()),
  );
  // Use Cases
  sl.registerLazySingleton(() => GetMesas(sl()));
  sl.registerLazySingleton(() => GetMesaById(sl()));
  sl.registerLazySingleton(() => CreateMesa(sl()));
  sl.registerLazySingleton(() => UpdateMesa(sl()));
  sl.registerLazySingleton(() => DeleteMesa(sl()));
  sl.registerLazySingleton(() => UpdateEstadoMesa(sl()));
  sl.registerLazySingleton(() => GetNextNumeroMesa(sl()));
  sl.registerLazySingleton(() => CreateLlamado(sl()));
  sl.registerLazySingleton(() => GetLlamadosPendientes(sl()));
  sl.registerLazySingleton(() => MarcarLlamadoAtendido(sl()));
}

/// Registra las dependencias del módulo de Pedidos.
void _initPedidos() {
  // DataSources
  sl.registerLazySingleton<PedidoLocalDataSource>(
    () => PedidoLocalDataSourceImpl(
      dbHelper: sl(),
      syncManager: sl(),
      tenantContext: sl(),
    ),
  );
  // Repositories
  sl.registerLazySingleton<PedidoRepository>(
    () => PedidoRepositoryImpl(localDataSource: sl()),
  );
  // Use Cases - Pedidos
  sl.registerLazySingleton(() => GetPedidos(sl()));
  sl.registerLazySingleton(() => GetPedidosActivos(sl()));
  sl.registerLazySingleton(() => GetPedidosByMesa(sl()));
  sl.registerLazySingleton(() => GetPedidoById(sl()));
  sl.registerLazySingleton(() => CreatePedido(sl()));
  sl.registerLazySingleton(() => UpdatePedido(sl()));
  sl.registerLazySingleton(() => UpdateEstadoPedido(sl()));
  sl.registerLazySingleton(() => DeletePedido(sl()));
  // Use Cases - Pedido Items
  sl.registerLazySingleton(() => GetItemsByPedido(sl()));
  sl.registerLazySingleton(() => AddPedidoItem(sl()));
  sl.registerLazySingleton(() => UpdatePedidoItem(sl()));
  sl.registerLazySingleton(() => DeletePedidoItem(sl()));
  sl.registerLazySingleton(() => UpdateEstadoItem(sl()));
}

/// Registra las dependencias del módulo de Menú.
void _initMenu() {
  sl.registerLazySingleton<MenuSyncDiagnosticsService>(
    () => MenuSyncDiagnosticsService(),
  );
  sl.registerLazySingleton<DriveConnectionLocalDatasource>(
    () => DriveConnectionLocalDatasource(dbHelper: sl()),
  );
  sl.registerLazySingleton<DriveMenuConnectionService>(
    () =>
        DriveMenuConnectionService(datasource: sl(), diagnosticsService: sl()),
  );
  sl.registerLazySingleton<DriveImageSyncQueueService>(
    () => DriveImageSyncQueueService(
      syncManager: sl(),
      driveService: sl(),
      dbHelper: sl(),
      tenantContext: sl(),
      diagnosticsService: sl(),
    ),
  );

  // DataSources
  sl.registerLazySingleton<MenuLocalDataSource>(
    () => MenuLocalDataSourceImpl(
      dbHelper: sl(),
      syncManager: sl(),
      tenantContext: sl(),
    ),
  );
  // Repositories
  sl.registerLazySingleton<MenuRepository>(
    () => MenuRepositoryImpl(dataSource: sl()),
  );
  // Use Cases - Categorías
  sl.registerLazySingleton(() => GetCategorias(sl()));
  sl.registerLazySingleton(() => GetCategoriaById(sl()));
  sl.registerLazySingleton(() => CreateCategoria(sl()));
  sl.registerLazySingleton(() => UpdateCategoria(sl()));
  sl.registerLazySingleton(() => DeleteCategoria(sl()));
  sl.registerLazySingleton(() => ReordenarCategorias(sl()));
  // Use Cases - Productos
  sl.registerLazySingleton(() => GetProductos(sl()));
  sl.registerLazySingleton(() => GetProductosByCategoria(sl()));
  sl.registerLazySingleton(() => GetProductoById(sl()));
  sl.registerLazySingleton(() => CreateProducto(sl()));
  sl.registerLazySingleton(() => UpdateProducto(sl()));
  sl.registerLazySingleton(() => DeleteProducto(sl()));
  sl.registerLazySingleton(() => ToggleDisponibilidad(sl()));
  // Use Cases - Variantes
  sl.registerLazySingleton(() => GetVariantesByProducto(sl()));
  sl.registerLazySingleton(() => CreateVariante(sl()));
  sl.registerLazySingleton(() => UpdateVariante(sl()));
  sl.registerLazySingleton(() => DeleteVariante(sl()));
}

/// Registra las dependencias del módulo de Cotizaciones.
void _initCotizaciones() {
  sl.registerLazySingleton<CotizacionLocalDataSource>(
    () => CotizacionLocalDataSourceImpl(
      dbHelper: sl(),
      syncManager: sl(),
      tenantContext: sl(),
    ),
  );
  sl.registerLazySingleton<CotizacionRepository>(
    () => CotizacionRepositoryImpl(dataSource: sl()),
  );
  sl.registerLazySingleton(() => CreateCotizacion(sl()));
  sl.registerLazySingleton(() => GetCotizaciones(sl()));
  sl.registerLazySingleton(() => UpdateCotizacionEstado(sl()));
  sl.registerLazySingleton(() => UpdateCotizacion(sl()));
  sl.registerLazySingleton(() => DeleteCotizacion(sl()));
}

/// Registra las dependencias del módulo de Reservaciones.
void _initReservas() {
  sl.registerLazySingleton<ReservaLocalDataSource>(
    () => ReservaLocalDataSourceImpl(
      dbHelper: sl(),
      syncManager: sl(),
      tenantContext: sl(),
    ),
  );
  sl.registerLazySingleton<ReservaRepository>(
    () => ReservaRepositoryImpl(dataSource: sl()),
  );
  sl.registerLazySingleton(() => CreateReserva(sl()));
  sl.registerLazySingleton(() => UpdateReserva(sl()));
  sl.registerLazySingleton(() => GetReservasByMonth(sl()));
  sl.registerLazySingleton(() => GetReservasByDate(sl()));
}

/// Registra las dependencias del módulo de Caja.
void _initCaja() {
  // DataSources
  sl.registerLazySingleton<CajaLocalDataSource>(
    () => CajaLocalDataSourceImpl(
      dbHelper: sl(),
      syncManager: sl(),
      tenantContext: sl(),
    ),
  );
  // Repositories
  sl.registerLazySingleton<CajaRepository>(
    () => CajaRepositoryImpl(dataSource: sl()),
  );
  // Use Cases
  sl.registerLazySingleton(() => RegistrarVenta(sl()));
  sl.registerLazySingleton(() => GetVentas(sl()));
  sl.registerLazySingleton(() => GetVentasByFecha(sl()));
  sl.registerLazySingleton(() => GetVentaById(sl()));
  sl.registerLazySingleton(() => GetVentaByPedido(sl()));
  sl.registerLazySingleton(() => GetPedidosParaCobrar(sl()));
  sl.registerLazySingleton(() => GetCotizacionesParaCobrar(sl()));
}

/// Registra las dependencias del módulo de Reportes.
void _initReportes() {
  // DataSources
  sl.registerLazySingleton<ReportesLocalDataSource>(
    () => ReportesLocalDataSourceImpl(dbHelper: sl()),
  );
  // Repositories
  sl.registerLazySingleton<ReportesRepository>(
    () => ReportesRepositoryImpl(dataSource: sl()),
  );
  // Use Cases
  sl.registerLazySingleton(() => GetResumenVentas(sl()));
  sl.registerLazySingleton(() => GetVentasPorDia(sl()));
  sl.registerLazySingleton(() => GetTopProductos(sl()));
  sl.registerLazySingleton(() => GetVentasPorMetodo(sl()));
  sl.registerLazySingleton(() => GetVentasPorMesero(sl()));
}

/// Registra las dependencias del módulo de Usuarios.
void _initUsuarios() {
  sl.registerLazySingleton<UsuarioLocalDataSource>(
    () => UsuarioLocalDataSourceImpl(
      dbHelper: sl(),
      syncManager: sl(),
      tenantContext: sl(),
    ),
  );
  sl.registerLazySingleton<UsuarioRepository>(
    () => UsuarioRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetUsuarios(sl()));
  sl.registerLazySingleton(() => GetUsuarioById(sl()));
  sl.registerLazySingleton(() => GetUsuariosByRol(sl()));
  sl.registerLazySingleton(() => CreateUsuario(sl()));
  sl.registerLazySingleton(() => UpdateUsuario(sl()));
  sl.registerLazySingleton(() => DeleteUsuario(sl()));
  sl.registerLazySingleton(() => VerificarPin(sl()));
}

/// Registra las dependencias del módulo de Clientes.
void _initClientes() {
  sl.registerLazySingleton<ClienteLocalDataSource>(
    () => ClienteLocalDataSourceImpl(
      dbHelper: sl(),
      syncManager: sl(),
      tenantContext: sl(),
    ),
  );
  sl.registerLazySingleton<ClienteRepository>(
    () => ClienteRepositoryImpl(dataSource: sl()),
  );
  sl.registerLazySingleton(() => GetClientes(sl()));
  sl.registerLazySingleton(() => GetClienteByCedula(sl()));
  sl.registerLazySingleton(() => BuscarClientes(sl()));
  sl.registerLazySingleton(() => CreateCliente(sl()));
  sl.registerLazySingleton(() => UpdateCliente(sl()));
  sl.registerLazySingleton(() => DeleteCliente(sl()));
  sl.registerLazySingleton(() => GetResumenCliente(sl()));
  sl.registerLazySingleton<ClienteService>(
    () => ClienteServiceImpl(
      getClienteByCedula: sl(),
      createCliente: sl(),
      updateCliente: sl(),
    ),
  );
}

/// Registra las dependencias del módulo de Página Pública.
void _initPaginaPublica() {
  sl.registerLazySingleton<PublicConfigDatasource>(
    () => PublicConfigDatasourceImpl(
      dbHelper: sl(),
      syncManager: sl(),
      tenantContext: sl(),
    ),
  );
  sl.registerLazySingleton<PublicConfigRepository>(
    () => PublicConfigRepositoryImpl(datasource: sl()),
  );
  sl.registerLazySingleton(() => GetPublicConfig(sl()));
  sl.registerLazySingleton(() => SavePublicConfig(sl()));
}

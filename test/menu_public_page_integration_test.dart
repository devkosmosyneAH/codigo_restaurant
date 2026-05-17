import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/errors/failures.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/clientes/domain/entities/cliente.dart';
import 'package:restaurant_app/features/clientes/domain/services/cliente_service.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/cotizaciones/domain/repositories/cotizacion_repository.dart';
import 'package:restaurant_app/features/cotizaciones/domain/usecases/cotizacion_usecases.dart';
import 'package:restaurant_app/features/menu/domain/entities/categoria.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/domain/entities/variante.dart';
import 'package:restaurant_app/features/menu/domain/repositories/menu_repository.dart';
import 'package:restaurant_app/features/menu/domain/usecases/menu_usecases.dart';
import 'package:restaurant_app/features/menu/presentation/pages/menu_public_page.dart';
import 'package:restaurant_app/features/menu/presentation/widgets/public_producto_card.dart';
import 'package:restaurant_app/features/pagina_publica/domain/entities/public_config.dart';
import 'package:restaurant_app/features/pagina_publica/domain/repositories/public_config_repository.dart';
import 'package:restaurant_app/features/pagina_publica/domain/usecases/public_config_usecases.dart';
import 'package:restaurant_app/features/reservaciones/domain/entities/reserva.dart';
import 'package:restaurant_app/features/reservaciones/domain/repositories/reserva_repository.dart';
import 'package:restaurant_app/features/reservaciones/domain/usecases/reserva_usecases.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MenuPublicPage integración', () {
    tearDown(() async {
      await sl.reset();
    });

    testWidgets('habilitado: carga una sola vez y muestra menú público', (
      tester,
    ) async {
      final repo = _FakeMenuRepository(
        categorias: [_categoria()],
        productos: [_productoBase()],
      );

      await _registerDependencies(
        menuRepo: repo,
        publicConfig: _publicConfig(mostrarMenu: true),
      );

      await _pumpMenuPublic(tester);

      expect(find.byType(PublicProductoCard), findsOneWidget);
      expect(find.text('Cotizar'), findsOneWidget);
      expect(repo.getCategoriasCalls, 1);
      expect(repo.getProductosCalls, 1);

      await tester.pump();
      expect(repo.getCategoriasCalls, 1);
      expect(repo.getProductosCalls, 1);
    });

    testWidgets('deshabilitado: no carga menú y muestra bloqueo público', (
      tester,
    ) async {
      final repo = _FakeMenuRepository(
        categorias: [_categoria()],
        productos: [_productoBase()],
      );

      await _registerDependencies(
        menuRepo: repo,
        publicConfig: _publicConfig(mostrarMenu: false),
      );

      await _pumpMenuPublic(tester);

      expect(
        find.text('El menú público no está disponible en este momento.'),
        findsOneWidget,
      );
      expect(find.byType(PublicProductoCard), findsNothing);
      expect(find.text('Cotizar'), findsNothing);
      expect(repo.getCategoriasCalls, 0);
      expect(repo.getProductosCalls, 0);
    });

    testWidgets('sin productos: muestra estado vacío', (tester) async {
      final repo = _FakeMenuRepository(
        categorias: [_categoria()],
        productos: [],
      );

      await _registerDependencies(
        menuRepo: repo,
        publicConfig: _publicConfig(mostrarMenu: true),
      );

      await _pumpMenuPublic(tester);

      expect(find.text('No hay productos disponibles'), findsOneWidget);
      expect(find.text('0 items'), findsOneWidget);
      expect(repo.getCategoriasCalls, 1);
      expect(repo.getProductosCalls, 1);
    });

    testWidgets('con variantes: muestra precio desde y resumen de opciones', (
      tester,
    ) async {
      final repo = _FakeMenuRepository(
        categorias: [_categoria()],
        productos: [_productoConVariantes()],
      );

      await _registerDependencies(
        menuRepo: repo,
        publicConfig: _publicConfig(mostrarMenu: true),
      );

      await _pumpMenuPublic(tester);

      expect(find.text('Desde \$2.50'), findsOneWidget);
      expect(find.textContaining('2 opciones:'), findsOneWidget);
      expect(find.textContaining('Pequeno'), findsOneWidget);
    });

    testWidgets('error de carga: muestra mensaje cuando falla productos', (
      tester,
    ) async {
      final repo = _FakeMenuRepository(
        categorias: [_categoria()],
        productos: [_productoBase()],
        productosFailure: const DatabaseFailure(
          message: 'Error cargando menú público',
        ),
      );

      await _registerDependencies(
        menuRepo: repo,
        publicConfig: _publicConfig(mostrarMenu: true),
      );

      await _pumpMenuPublic(tester);

      expect(find.text('Error cargando menú público'), findsOneWidget);
      expect(repo.getCategoriasCalls, 1);
      expect(repo.getProductosCalls, 1);
    });

    testWidgets('filtra productos al cambiar de categoría', (tester) async {
      final now = DateTime(2026, 1, 1);
      final repo = _FakeMenuRepository(
        categorias: [
          Categoria(
            id: 'cat-1',
            restaurantId: 'rest-1',
            nombre: 'Bebidas',
            createdAt: now,
            updatedAt: now,
          ),
          Categoria(
            id: 'cat-2',
            restaurantId: 'rest-1',
            nombre: 'Postres',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        productos: [
          Producto(
            id: 'prod-bebida',
            restaurantId: 'rest-1',
            categoriaId: 'cat-1',
            nombre: 'Limonada',
            precio: 4.5,
            disponible: true,
            createdAt: now,
            updatedAt: now,
          ),
          Producto(
            id: 'prod-postre',
            restaurantId: 'rest-1',
            categoriaId: 'cat-2',
            nombre: 'Brownie',
            precio: 3.0,
            disponible: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      await _registerDependencies(
        menuRepo: repo,
        publicConfig: _publicConfig(mostrarMenu: true),
      );

      await _pumpMenuPublic(tester);

      expect(find.text('2 items'), findsOneWidget);
      expect(find.text('Limonada'), findsOneWidget);
      expect(find.text('Brownie'), findsOneWidget);

      await tester.tap(find.text('Postres').first);
      await tester.pumpAndSettle();

      expect(find.text('1 items'), findsOneWidget);
      expect(find.text('Brownie'), findsOneWidget);
      expect(find.text('Limonada'), findsNothing);

      await tester.tap(find.text('Todos').first);
      await tester.pumpAndSettle();

      expect(find.text('2 items'), findsOneWidget);
      expect(find.text('Limonada'), findsOneWidget);
      expect(find.text('Brownie'), findsOneWidget);
    });

    testWidgets(
      'usuario novato toca controles y el flujo se mantiene estable',
      (tester) async {
        final now = DateTime(2026, 1, 1);
        final repo = _FakeMenuRepository(
          categorias: [
            Categoria(
              id: 'cat-1',
              restaurantId: 'rest-1',
              nombre: 'Bebidas',
              createdAt: now,
              updatedAt: now,
            ),
            Categoria(
              id: 'cat-2',
              restaurantId: 'rest-1',
              nombre: 'Postres',
              createdAt: now,
              updatedAt: now,
            ),
          ],
          productos: [
            Producto(
              id: 'prod-bebida',
              restaurantId: 'rest-1',
              categoriaId: 'cat-1',
              nombre: 'Limonada',
              precio: 4.5,
              disponible: true,
              createdAt: now,
              updatedAt: now,
            ),
            Producto(
              id: 'prod-postre',
              restaurantId: 'rest-1',
              categoriaId: 'cat-2',
              nombre: 'Brownie',
              precio: 3.0,
              disponible: true,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        );

        await _registerDependencies(
          menuRepo: repo,
          publicConfig: _publicConfig(mostrarMenu: true),
        );

        await _pumpMenuPublic(tester);

        expect(find.byType(PublicProductoCard), findsNWidgets(2));

        await tester.tap(find.text('Bebidas').first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final addBebidas = find.byTooltip('Agregar').first;
        await tester.ensureVisible(addBebidas);
        await tester.pumpAndSettle();
        await tester.tap(addBebidas);
        await tester.pumpAndSettle();
        expect(find.textContaining('Cotizar (1)'), findsOneWidget);

        await tester.tap(find.text('Postres').first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final addPostres = find.byTooltip('Agregar').first;
        await tester.ensureVisible(addPostres);
        await tester.pumpAndSettle();
        await tester.tap(addPostres);
        await tester.pumpAndSettle();
        expect(find.textContaining('Cotizar (2)'), findsOneWidget);

        final cotizarBtn = find.textContaining('Cotizar (2)').first;
        await tester.ensureVisible(cotizarBtn);
        await tester.pumpAndSettle();
        await tester.tap(cotizarBtn);
        await tester.pumpAndSettle();

        expect(find.text('Cotizacion para evento'), findsOneWidget);

        final cedulaField = find.widgetWithText(TextFormField, 'Cédula');
        await tester.enterText(cedulaField, '0102030405');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Cerrar').first);
        await tester.pumpAndSettle();
        expect(find.text('Cotizacion para evento'), findsNothing);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'usuario novato intenta generar cotización incompleta y recibe validaciones por campo',
      (tester) async {
        final repo = _FakeMenuRepository(
          categorias: [_categoria()],
          productos: [_productoBase()],
        );

        await _registerDependencies(
          menuRepo: repo,
          publicConfig: _publicConfig(mostrarMenu: true),
        );

        await _pumpMenuPublic(tester);

        final addButton = find.byTooltip('Agregar').first;
        await tester.ensureVisible(addButton);
        await tester.pumpAndSettle();
        await tester.tap(addButton);
        await tester.pumpAndSettle();
        expect(find.textContaining('Cotizar (1)'), findsOneWidget);

        final cotizarBtn = find.textContaining('Cotizar (1)').first;
        await tester.ensureVisible(cotizarBtn);
        await tester.pumpAndSettle();
        await tester.tap(cotizarBtn);
        await tester.pumpAndSettle();

        expect(find.text('Cotizacion para evento'), findsOneWidget);

        final generarBtn = find.text('Generar cotizacion').first;
        await tester.ensureVisible(generarBtn);
        await tester.pumpAndSettle();
        await tester.tap(generarBtn);
        await tester.pumpAndSettle();

        expect(find.text('Requerido'), findsAtLeastNWidgets(3));
        expect(find.text('Correo electronico invalido'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Cédula'),
          '1234567890',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre'),
          'Cliente Novato',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Telefono'),
          '0999999999',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Correo'),
          'correo_invalido',
        );
        await tester.pumpAndSettle();

        await tester.tap(generarBtn);
        await tester.pumpAndSettle();

        expect(find.text('Cédula/RUC inválido'), findsOneWidget);
        expect(find.text('Correo electronico invalido'), findsOneWidget);

        await tester.tap(find.text('Reservar local para evento').first);
        await tester.pumpAndSettle();

        await tester.tap(generarBtn);
        await tester.pumpAndSettle();

        expect(find.text('Indica la fecha del evento'), findsOneWidget);
        expect(find.text('Indica la cantidad de personas'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Cerrar').first);
        await tester.pumpAndSettle();
        expect(find.text('Cotizacion para evento'), findsNothing);
      },
    );
  });
}

Future<void> _registerDependencies({
  required _FakeMenuRepository menuRepo,
  required PublicConfig publicConfig,
}) async {
  await sl.reset();

  sl.registerSingleton<TenantContext>(
    TenantContext()..setFromSession(
      restaurantId: 'rest-1',
      userId: 'usr-test-1',
      rol: 'administrador',
    ),
  );

  final publicRepo = _FakePublicConfigRepository(config: publicConfig);
  sl.registerLazySingleton<GetPublicConfig>(() => GetPublicConfig(publicRepo));
  sl.registerLazySingleton<SavePublicConfig>(
    () => SavePublicConfig(publicRepo),
  );

  sl.registerLazySingleton<GetCategorias>(() => GetCategorias(menuRepo));
  sl.registerLazySingleton<CreateCategoria>(() => CreateCategoria(menuRepo));
  sl.registerLazySingleton<UpdateCategoria>(() => UpdateCategoria(menuRepo));
  sl.registerLazySingleton<DeleteCategoria>(() => DeleteCategoria(menuRepo));
  sl.registerLazySingleton<ReordenarCategorias>(
    () => ReordenarCategorias(menuRepo),
  );
  sl.registerLazySingleton<GetProductos>(() => GetProductos(menuRepo));
  sl.registerLazySingleton<CreateProducto>(() => CreateProducto(menuRepo));
  sl.registerLazySingleton<UpdateProducto>(() => UpdateProducto(menuRepo));
  sl.registerLazySingleton<DeleteProducto>(() => DeleteProducto(menuRepo));
  sl.registerLazySingleton<ToggleDisponibilidad>(
    () => ToggleDisponibilidad(menuRepo),
  );
  sl.registerLazySingleton<CreateVariante>(() => CreateVariante(menuRepo));
  sl.registerLazySingleton<UpdateVariante>(() => UpdateVariante(menuRepo));
  sl.registerLazySingleton<DeleteVariante>(() => DeleteVariante(menuRepo));

  final cotRepo = _FakeCotizacionRepository();
  sl.registerLazySingleton<CreateCotizacion>(() => CreateCotizacion(cotRepo));
  sl.registerLazySingleton<GetCotizaciones>(() => GetCotizaciones(cotRepo));
  sl.registerLazySingleton<UpdateCotizacionEstado>(
    () => UpdateCotizacionEstado(cotRepo),
  );

  final reservaRepo = _FakeReservaRepository();
  sl.registerLazySingleton<CreateReserva>(() => CreateReserva(reservaRepo));
  sl.registerLazySingleton<UpdateReserva>(() => UpdateReserva(reservaRepo));
  sl.registerLazySingleton<GetReservasByMonth>(
    () => GetReservasByMonth(reservaRepo),
  );
  sl.registerLazySingleton<GetReservasByDate>(
    () => GetReservasByDate(reservaRepo),
  );

  sl.registerLazySingleton<ClienteService>(() => _FakeClienteService());
}

Future<void> _pumpMenuPublic(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1080, 1920));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: MenuPublicPage())),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

PublicConfig _publicConfig({required bool mostrarMenu}) {
  return PublicConfig.defaults(
    'rest-1',
  ).copyWith(mostrarBotonMenu: mostrarMenu, nombreNegocio: 'Restaurante Test');
}

Categoria _categoria() {
  final now = DateTime(2026, 1, 1);
  return Categoria(
    id: 'cat-1',
    restaurantId: 'rest-1',
    nombre: 'Bebidas',
    createdAt: now,
    updatedAt: now,
  );
}

Producto _productoBase() {
  final now = DateTime(2026, 1, 1);
  return Producto(
    id: 'prod-1',
    restaurantId: 'rest-1',
    categoriaId: 'cat-1',
    nombre: 'Limonada',
    precio: 4.5,
    disponible: true,
    createdAt: now,
    updatedAt: now,
  );
}

Producto _productoConVariantes() {
  final now = DateTime(2026, 1, 1);
  return Producto(
    id: 'prod-var-1',
    restaurantId: 'rest-1',
    categoriaId: 'cat-1',
    nombre: 'Cafe especial',
    precio: 0,
    disponible: true,
    createdAt: now,
    updatedAt: now,
    variantes: [
      Variante(
        id: 'var-1',
        productoId: 'prod-var-1',
        nombre: 'Pequeno',
        precio: 2.5,
        createdAt: now,
        updatedAt: now,
      ),
      Variante(
        id: 'var-2',
        productoId: 'prod-var-1',
        nombre: 'Grande',
        precio: 3.75,
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );
}

class _FakePublicConfigRepository implements PublicConfigRepository {
  _FakePublicConfigRepository({required this.config});

  PublicConfig config;

  @override
  ResultFuture<PublicConfig> getConfig(String restaurantId) async =>
      Right(config);

  @override
  ResultFuture<PublicConfig> saveConfig(PublicConfig next) async {
    config = next;
    return Right(config);
  }
}

class _FakeMenuRepository implements MenuRepository {
  _FakeMenuRepository({
    required this.categorias,
    required this.productos,
    this.productosFailure,
  });

  final List<Categoria> categorias;
  final List<Producto> productos;
  final Failure? productosFailure;

  int getCategoriasCalls = 0;
  int getProductosCalls = 0;

  @override
  ResultFuture<List<Categoria>> getCategorias(String restaurantId) async {
    getCategoriasCalls++;
    return Right(categorias);
  }

  @override
  ResultFuture<List<Producto>> getProductos(String restaurantId) async {
    getProductosCalls++;
    if (productosFailure != null) return Left(productosFailure!);
    return Right(productos);
  }

  @override
  ResultFuture<Categoria?> getCategoriaById(String id) async =>
      const Right(null);

  @override
  ResultFuture<void> createCategoria(Categoria categoria) async =>
      const Right(null);

  @override
  ResultFuture<void> updateCategoria(Categoria categoria) async =>
      const Right(null);

  @override
  ResultFuture<void> deleteCategoria(String id) async => const Right(null);

  @override
  ResultFuture<void> reordenarCategorias(List<String> orderedIds) async =>
      const Right(null);

  @override
  ResultFuture<List<Producto>> getProductosByCategoria(
    String categoriaId,
  ) async =>
      Right(productos.where((p) => p.categoriaId == categoriaId).toList());

  @override
  ResultFuture<Producto?> getProductoById(String id) async =>
      Right(productos.where((p) => p.id == id).cast<Producto?>().firstOrNull);

  @override
  ResultFuture<void> createProducto(Producto producto) async =>
      const Right(null);

  @override
  ResultFuture<void> updateProducto(Producto producto) async =>
      const Right(null);

  @override
  ResultFuture<void> deleteProducto(String id) async => const Right(null);

  @override
  ResultFuture<void> toggleDisponibilidad(String id, bool disponible) async =>
      const Right(null);

  @override
  ResultFuture<List<Variante>> getVariantesByProducto(String productoId) async {
    final p = productos
        .where((it) => it.id == productoId)
        .cast<Producto?>()
        .firstOrNull;
    return Right(p?.variantes ?? const <Variante>[]);
  }

  @override
  ResultFuture<void> createVariante(Variante variante) async =>
      const Right(null);

  @override
  ResultFuture<void> updateVariante(Variante variante) async =>
      const Right(null);

  @override
  ResultFuture<void> deleteVariante(String id) async => const Right(null);
}

class _FakeCotizacionRepository implements CotizacionRepository {
  final List<Cotizacion> _items = [];

  @override
  ResultFuture<void> createCotizacion(Cotizacion cotizacion) async {
    _items.removeWhere((c) => c.id == cotizacion.id);
    _items.add(cotizacion);
    return const Right(null);
  }

  @override
  ResultFuture<void> deleteCotizacion(String cotizacionId) async {
    _items.removeWhere((c) => c.id == cotizacionId);
    return const Right(null);
  }

  @override
  ResultFuture<List<Cotizacion>> getCotizaciones(String restaurantId) async {
    return Right(_items.where((c) => c.restaurantId == restaurantId).toList());
  }

  @override
  ResultFuture<void> updateCotizacion(Cotizacion cotizacion) async {
    _items.removeWhere((c) => c.id == cotizacion.id);
    _items.add(cotizacion);
    return const Right(null);
  }

  @override
  ResultFuture<void> updateEstado(String cotizacionId, String estado) async {
    final idx = _items.indexWhere((c) => c.id == cotizacionId);
    if (idx != -1) {
      _items[idx] = _items[idx].copyWith(estado: estado);
    }
    return const Right(null);
  }
}

class _FakeReservaRepository implements ReservaRepository {
  final List<Reserva> _items = [];

  @override
  ResultFuture<void> createReserva(Reserva reserva) async {
    _items.removeWhere((r) => r.id == reserva.id);
    _items.add(reserva);
    return const Right(null);
  }

  @override
  ResultFuture<List<Reserva>> getReservasByDate(
    String restaurantId,
    String date,
  ) async {
    return Right(
      _items
          .where((r) => r.restaurantId == restaurantId && r.fecha == date)
          .toList(),
    );
  }

  @override
  ResultFuture<List<Reserva>> getReservasByMonth(
    String restaurantId,
    String startDate,
    String endDate,
  ) async {
    return Right(_items.where((r) => r.restaurantId == restaurantId).toList());
  }

  @override
  ResultFuture<void> updateReserva(Reserva reserva) async {
    _items.removeWhere((r) => r.id == reserva.id);
    _items.add(reserva);
    return const Right(null);
  }
}

class _FakeClienteService implements ClienteService {
  @override
  Future<Cliente?> buscarPorCedula(String cedula) async {
    return null;
  }

  @override
  Future<Cliente> buscarOCrear(Map<String, dynamic> datos) async {
    final now = DateTime(2026, 1, 1);
    return Cliente(
      idCliente: 1,
      cedula: (datos['cedula'] as String? ?? '').trim(),
      restaurantId: 'rest-1',
      nombre: (datos['nombres'] as String? ?? 'Cliente').trim(),
      telefono: (datos['telefono'] as String?)?.trim(),
      email: (datos['email'] as String?)?.trim(),
      direccion: (datos['direccion'] as String?)?.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<Cliente> crearCliente(Map<String, dynamic> datos) {
    return buscarOCrear(datos);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    if (this.isEmpty) return null;
    return first;
  }
}

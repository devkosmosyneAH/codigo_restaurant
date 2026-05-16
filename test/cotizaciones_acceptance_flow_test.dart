import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion_item.dart';
import 'package:restaurant_app/features/cotizaciones/domain/repositories/cotizacion_repository.dart';
import 'package:restaurant_app/features/cotizaciones/domain/usecases/cotizacion_usecases.dart';
import 'package:restaurant_app/features/pagina_publica/domain/entities/public_config.dart';
import 'package:restaurant_app/features/pagina_publica/domain/repositories/public_config_repository.dart';
import 'package:restaurant_app/features/pagina_publica/domain/usecases/public_config_usecases.dart';
import 'package:restaurant_app/features/reservaciones/domain/entities/reserva.dart';
import 'package:restaurant_app/features/reservaciones/domain/repositories/reserva_repository.dart';
import 'package:restaurant_app/features/reservaciones/domain/usecases/reserva_usecases.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/pages/cotizaciones_page.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/providers/cotizaciones_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cotizaciones acceptance flow', () {
    late _FakeCotizacionRepository repo;
    late _FakeReservaRepository reservaRepo;

    setUp(() async {
      repo = _FakeCotizacionRepository();
      reservaRepo = _FakeReservaRepository();
      await sl.reset();
      sl.registerSingleton<TenantContext>(
        TenantContext()..setFromSession(
          restaurantId: 'la_pena_001',
          userId: 'usr_admin_1',
          rol: 'administrador',
        ),
      );
      final publicConfigRepo = _FakePublicConfigRepository();
      sl.registerLazySingleton<GetPublicConfig>(
        () => GetPublicConfig(publicConfigRepo),
      );
      sl.registerLazySingleton<SavePublicConfig>(
        () => SavePublicConfig(publicConfigRepo),
      );
      sl.registerLazySingleton<UpdateCotizacionEstado>(
        () => UpdateCotizacionEstado(repo),
      );
      sl.registerLazySingleton<CreateReserva>(() => CreateReserva(reservaRepo));
      sl.registerLazySingleton<UpdateReserva>(() => UpdateReserva(reservaRepo));
      sl.registerLazySingleton<GetReservasByMonth>(
        () => GetReservasByMonth(reservaRepo),
      );
      sl.registerLazySingleton<GetReservasByDate>(
        () => GetReservasByDate(reservaRepo),
      );
    });

    tearDown(() async {
      await sl.reset();
    });

    testWidgets('allows accepting a non-reservation quote without event date', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cotizacionesProvider.overrideWith(
              (ref) async => [
                Cotizacion(
                  id: 'cot-1',
                  restaurantId: 'la_pena_001',
                  clienteNombre: 'Cliente sin fecha',
                  clienteTelefono: '0999999999',
                  clienteEmail: 'cliente@demo.com',
                  reservaLocal: false,
                  subtotal: 45,
                  total: 45,
                  createdAt: DateTime(2026, 4, 7),
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: CotizacionesPage()),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Cliente sin fecha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar').last);
      await tester.pumpAndSettle();

      expect(repo.updatedCotizacionId, 'cot-1');
      expect(repo.updatedEstado, 'aceptada');
    });

    testWidgets('shows requested food details before approving a quote', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cotizacionesProvider.overrideWith(
              (ref) async => [
                Cotizacion(
                  id: 'cot-food-1',
                  restaurantId: 'la_pena_001',
                  clienteNombre: 'Cliente con comida',
                  clienteTelefono: '0777777777',
                  clienteEmail: 'comida@demo.com',
                  reservaLocal: true,
                  fechaEvento: '2026-04-20',
                  comidaPreferida: 'Parrillada y ceviche',
                  subtotal: 60,
                  total: 60,
                  createdAt: DateTime(2026, 4, 7),
                  items: const [
                    CotizacionItem(
                      id: 'item-1',
                      cotizacionId: 'cot-food-1',
                      productoId: 'prod-1',
                      productoNombre: 'Jarra de limonada',
                      cantidad: 2,
                      precioUnitario: 5,
                      subtotal: 10,
                    ),
                  ],
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: CotizacionesPage()),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Cliente con comida'));
      await tester.pumpAndSettle();

      expect(find.text('Pedido solicitado'), findsOneWidget);
      expect(find.textContaining('Parrillada y ceviche'), findsWidgets);
      expect(find.textContaining('Jarra de limonada'), findsWidgets);
    });

    testWidgets(
      'keeps the cotizaciones screen stable after accepting a reservation quote',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cotizacionesProvider.overrideWith(
                (ref) async => [
                  Cotizacion(
                    id: 'cot-keep-1',
                    restaurantId: 'la_pena_001',
                    clienteNombre: 'Cliente estable',
                    clienteTelefono: '0666666666',
                    clienteEmail: 'estable@demo.com',
                    reservaLocal: true,
                    fechaEvento: '2026-04-20',
                    comidaPreferida: 'Cazuela y jugos',
                    subtotal: 90,
                    total: 90,
                    createdAt: DateTime(2026, 4, 7),
                  ),
                ],
              ),
            ],
            child: const MaterialApp(home: CotizacionesPage()),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.text('Cliente estable'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aceptar').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aceptar').last);
        await tester.pumpAndSettle();

        expect(find.text('Cotizaciones'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(repo.updatedCotizacionId, 'cot-keep-1');
        expect(repo.updatedEstado, 'aceptada');
      },
    );

    testWidgets('allows rejecting a pending quote after confirmation', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cotizacionesProvider.overrideWith(
              (ref) async => [
                Cotizacion(
                  id: 'cot-2',
                  restaurantId: 'la_pena_001',
                  clienteNombre: 'Cliente a rechazar',
                  clienteTelefono: '0888888888',
                  clienteEmail: 'rechazo@demo.com',
                  reservaLocal: true,
                  fechaEvento: '2026-04-20',
                  subtotal: 80,
                  total: 80,
                  createdAt: DateTime(2026, 4, 7),
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: CotizacionesPage()),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Cliente a rechazar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rechazar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rechazar').last);
      await tester.pumpAndSettle();

      expect(repo.updatedCotizacionId, 'cot-2');
      expect(repo.updatedEstado, 'rechazada');
    });
  });
}

class _FakePublicConfigRepository implements PublicConfigRepository {
  @override
  ResultFuture<PublicConfig> getConfig(String restaurantId) async =>
      Right(PublicConfig.defaults(restaurantId));

  @override
  ResultFuture<PublicConfig> saveConfig(PublicConfig config) async =>
      Right(config);
}

class _FakeCotizacionRepository implements CotizacionRepository {
  String? updatedCotizacionId;
  String? updatedEstado;

  @override
  ResultFuture<void> createCotizacion(Cotizacion cotizacion) async =>
      const Right(null);

  @override
  ResultFuture<List<Cotizacion>> getCotizaciones(String restaurantId) async =>
      const Right([]);

  @override
  ResultFuture<void> updateCotizacion(Cotizacion cotizacion) async =>
      const Right(null);

  @override
  ResultFuture<void> deleteCotizacion(String cotizacionId) async =>
      const Right(null);

  @override
  ResultFuture<void> updateEstado(String cotizacionId, String estado) async {
    updatedCotizacionId = cotizacionId;
    updatedEstado = estado;
    return const Right(null);
  }
}

class _FakeReservaRepository implements ReservaRepository {
  final List<Reserva> reservas = [];

  @override
  ResultFuture<void> createReserva(Reserva reserva) async {
    reservas.removeWhere((r) => r.id == reserva.id);
    reservas.add(reserva);
    return const Right(null);
  }

  @override
  ResultFuture<List<Reserva>> getReservasByDate(
    String restaurantId,
    String date,
  ) async => Right(
    reservas
        .where((r) => r.restaurantId == restaurantId && r.fecha == date)
        .toList(),
  );

  @override
  ResultFuture<List<Reserva>> getReservasByMonth(
    String restaurantId,
    String startDate,
    String endDate,
  ) async =>
      Right(reservas.where((r) => r.restaurantId == restaurantId).toList());

  @override
  ResultFuture<void> updateReserva(Reserva reserva) async {
    reservas.removeWhere((r) => r.id == reserva.id);
    reservas.add(reserva);
    return const Right(null);
  }
}

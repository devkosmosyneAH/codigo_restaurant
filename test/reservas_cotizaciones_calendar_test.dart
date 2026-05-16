import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/providers/cotizaciones_provider.dart';
import 'package:restaurant_app/features/mesas/domain/entities/mesa.dart';
import 'package:restaurant_app/features/mesas/domain/repositories/mesa_repository.dart';
import 'package:restaurant_app/features/mesas/domain/usecases/mesa_usecases.dart';
import 'package:restaurant_app/features/mesas/presentation/providers/mesas_provider.dart';
import 'package:restaurant_app/features/reservaciones/domain/entities/reserva.dart';
import 'package:restaurant_app/features/reservaciones/domain/repositories/reserva_repository.dart';
import 'package:restaurant_app/features/reservaciones/domain/usecases/reserva_usecases.dart';
import 'package:restaurant_app/features/reservaciones/presentation/pages/reservas_page.dart';
import 'package:restaurant_app/features/reservaciones/presentation/pages/reservas_public_page.dart';
import 'package:restaurant_app/features/reservaciones/presentation/providers/reservas_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await sl.reset();
    sl.registerSingleton<TenantContext>(
      TenantContext()..setFromSession(
        restaurantId: 'la_pena_001',
        userId: 'usr_admin_1',
        rol: 'administrador',
      ),
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<void> setLargeSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('shows pending event quotes in the reservations view', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final reservaRepo = _FakeReservaRepository();
    final mesaRepo = _FakeMesaRepository(mesas: [_mesa('mesa-1', 1)]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reservasProvider.overrideWith(
            (ref) => ReservasNotifier(
              createReserva: CreateReserva(reservaRepo),
              updateReserva: UpdateReserva(reservaRepo),
              getByMonth: GetReservasByMonth(reservaRepo),
              getByDate: GetReservasByDate(reservaRepo),
            ),
          ),
          mesasProvider.overrideWith(
            (ref) => MesasNotifier(
              getMesas: GetMesas(mesaRepo),
              createMesa: CreateMesa(mesaRepo),
              updateMesa: UpdateMesa(mesaRepo),
              deleteMesa: DeleteMesa(mesaRepo),
              updateEstadoMesa: UpdateEstadoMesa(mesaRepo),
              getNextNumeroMesa: GetNextNumeroMesa(mesaRepo),
            ),
          ),
          cotizacionesProvider.overrideWith(
            (ref) async => [
              Cotizacion(
                id: 'cot-1',
                restaurantId: 'la_pena_001',
                clienteNombre: 'Cliente Evento',
                clienteTelefono: '0999999999',
                clienteEmail: 'cliente@demo.com',
                reservaLocal: true,
                fechaEvento: today,
                personas: 30,
                notas: 'Celebración',
                subtotal: 120,
                total: 120,
                createdAt: now,
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: ReservasPage()),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('Cotización pendiente'), findsOneWidget);
    expect(find.textContaining('Cliente Evento'), findsOneWidget);
  });

  testWidgets('shows a simple availability legend in the public calendar', (
    tester,
  ) async {
    await setLargeSurface(tester);
    final reservaRepo = _FakeReservaRepository();
    final mesaRepo = _FakeMesaRepository(mesas: [_mesa('mesa-1', 1)]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reservasProvider.overrideWith(
            (ref) => ReservasNotifier(
              createReserva: CreateReserva(reservaRepo),
              updateReserva: UpdateReserva(reservaRepo),
              getByMonth: GetReservasByMonth(reservaRepo),
              getByDate: GetReservasByDate(reservaRepo),
            ),
          ),
          mesasProvider.overrideWith(
            (ref) => MesasNotifier(
              getMesas: GetMesas(mesaRepo),
              createMesa: CreateMesa(mesaRepo),
              updateMesa: UpdateMesa(mesaRepo),
              deleteMesa: DeleteMesa(mesaRepo),
              updateEstadoMesa: UpdateEstadoMesa(mesaRepo),
              getNextNumeroMesa: GetNextNumeroMesa(mesaRepo),
            ),
          ),
          cotizacionesProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: ReservasPublicPage()),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Cómo leer el calendario'), findsOneWidget);
    expect(find.text('Libre'), findsWidgets);
    expect(find.text('Ocupado'), findsOneWidget);
  });

  testWidgets('shows requested food summary on reservation cards', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final reservaRepo = _FakeReservaRepository(
      reservas: [
        Reserva(
          id: 'res-1',
          restaurantId: 'la_pena_001',
          tipo: TipoReserva.mesa,
          mesaId: 'mesa-1',
          mesaNombre: 'Mesa 1',
          fecha: today,
          horaInicio: '19:00',
          horaFin: '20:30',
          numeroPersonas: 2,
          clienteNombre: 'Cliente Comida',
          clienteTelefono: '0990000000',
          clienteEmail: 'comida@demo.com',
          requerimientos: 'Parrillada mixta y jugos naturales',
          createdAt: now,
        ),
      ],
    );
    final mesaRepo = _FakeMesaRepository(mesas: [_mesa('mesa-1', 1)]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reservasProvider.overrideWith(
            (ref) => ReservasNotifier(
              createReserva: CreateReserva(reservaRepo),
              updateReserva: UpdateReserva(reservaRepo),
              getByMonth: GetReservasByMonth(reservaRepo),
              getByDate: GetReservasByDate(reservaRepo),
            ),
          ),
          mesasProvider.overrideWith(
            (ref) => MesasNotifier(
              getMesas: GetMesas(mesaRepo),
              createMesa: CreateMesa(mesaRepo),
              updateMesa: UpdateMesa(mesaRepo),
              deleteMesa: DeleteMesa(mesaRepo),
              updateEstadoMesa: UpdateEstadoMesa(mesaRepo),
              getNextNumeroMesa: GetNextNumeroMesa(mesaRepo),
            ),
          ),
          cotizacionesProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: ReservasPage()),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('Parrillada mixta'), findsOneWidget);
  });

  testWidgets('only shows pending event requests on their real event date', (
    tester,
  ) async {
    await setLargeSurface(tester);
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final tomorrow = now.add(const Duration(days: 1));
    final reservaRepo = _FakeReservaRepository();
    final mesaRepo = _FakeMesaRepository(mesas: [_mesa('mesa-1', 1)]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reservasProvider.overrideWith(
            (ref) => ReservasNotifier(
              createReserva: CreateReserva(reservaRepo),
              updateReserva: UpdateReserva(reservaRepo),
              getByMonth: GetReservasByMonth(reservaRepo),
              getByDate: GetReservasByDate(reservaRepo),
            ),
          ),
          mesasProvider.overrideWith(
            (ref) => MesasNotifier(
              getMesas: GetMesas(mesaRepo),
              createMesa: CreateMesa(mesaRepo),
              updateMesa: UpdateMesa(mesaRepo),
              deleteMesa: DeleteMesa(mesaRepo),
              updateEstadoMesa: UpdateEstadoMesa(mesaRepo),
              getNextNumeroMesa: GetNextNumeroMesa(mesaRepo),
            ),
          ),
          cotizacionesProvider.overrideWith(
            (ref) async => [
              Cotizacion(
                id: 'cot-date-1',
                restaurantId: 'la_pena_001',
                clienteNombre: 'Evento puntual',
                clienteTelefono: '0991111111',
                clienteEmail: 'evento@demo.com',
                reservaLocal: true,
                fechaEvento: today,
                personas: 20,
                subtotal: 100,
                total: 100,
                createdAt: now,
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: ReservasPublicPage()),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Hay 1 solicitud(es) de evento'),
      findsOneWidget,
    );

    final tomorrowDay = tomorrow.day.toString();
    await tester.tap(find.text(tomorrowDay).last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Hay 1 solicitud(es) de evento'), findsNothing);
  });

  testWidgets('allows editing an existing reservation from its detail view', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final reservaRepo = _FakeReservaRepository(
      reservas: [
        Reserva(
          id: 'res-2',
          restaurantId: 'la_pena_001',
          tipo: TipoReserva.mesa,
          mesaId: 'mesa-1',
          mesaNombre: 'Mesa 1',
          fecha: today,
          horaInicio: '18:30',
          horaFin: '20:00',
          numeroPersonas: 4,
          clienteNombre: 'Cliente Editable',
          clienteTelefono: '0987654321',
          clienteEmail: 'editar@demo.com',
          requerimientos: 'Caldo de bola',
          createdAt: now,
        ),
      ],
    );
    final mesaRepo = _FakeMesaRepository(mesas: [_mesa('mesa-1', 1)]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reservasProvider.overrideWith(
            (ref) => ReservasNotifier(
              createReserva: CreateReserva(reservaRepo),
              updateReserva: UpdateReserva(reservaRepo),
              getByMonth: GetReservasByMonth(reservaRepo),
              getByDate: GetReservasByDate(reservaRepo),
            ),
          ),
          mesasProvider.overrideWith(
            (ref) => MesasNotifier(
              getMesas: GetMesas(mesaRepo),
              createMesa: CreateMesa(mesaRepo),
              updateMesa: UpdateMesa(mesaRepo),
              deleteMesa: DeleteMesa(mesaRepo),
              updateEstadoMesa: UpdateEstadoMesa(mesaRepo),
              getNextNumeroMesa: GetNextNumeroMesa(mesaRepo),
            ),
          ),
          cotizacionesProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: ReservasPage()),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cliente Editable'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Comida o preferencia del cliente'),
      'Ceviche y limonada',
    );
    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('Ceviche y limonada'), findsOneWidget);
  });
}

Mesa _mesa(String id, int numero) => Mesa(
  id: id,
  restaurantId: 'la_pena_001',
  numero: numero,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

class _FakeReservaRepository implements ReservaRepository {
  _FakeReservaRepository({this.reservas = const []});

  final List<Reserva> reservas;

  @override
  ResultFuture<void> createReserva(Reserva reserva) async {
    reservas.removeWhere((r) => r.id == reserva.id);
    reservas.add(reserva);
    return const Right(null);
  }

  @override
  ResultFuture<void> updateReserva(Reserva reserva) async {
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
}

class _FakeMesaRepository implements MesaRepository {
  _FakeMesaRepository({required this.mesas});

  final List<Mesa> mesas;

  @override
  ResultFuture<void> createMesa(Mesa mesa) async => const Right(null);

  @override
  ResultFuture<void> deleteMesa(String id) async => const Right(null);

  @override
  ResultFuture<Mesa> getMesaById(String id) async => Right(mesas.first);

  @override
  ResultFuture<List<Mesa>> getMesas(String restaurantId) async => Right(mesas);

  @override
  ResultFuture<int> getNextNumeroMesa(String restaurantId) async =>
      Right(mesas.length + 1);

  @override
  ResultFuture<void> separarMesas(String unionId) async => const Right(null);

  @override
  ResultFuture<void> unirMesas(List<String> mesaIds, String unionId) async =>
      const Right(null);

  @override
  ResultFuture<void> updateEstadoMesa(String id, String estado) async =>
      const Right(null);

  @override
  ResultFuture<void> updateMesa(Mesa mesa) async => const Right(null);
}

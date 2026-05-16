import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/errors/failures.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/clientes/data/services/cliente_service_impl.dart';
import 'package:restaurant_app/features/clientes/domain/entities/cliente.dart';
import 'package:restaurant_app/features/clientes/domain/repositories/cliente_repository.dart';
import 'package:restaurant_app/features/clientes/domain/usecases/cliente_usecases.dart';

void main() {
  group('ClienteServiceImpl', () {
    late _FakeClienteRepository repository;
    late ClienteServiceImpl service;

    setUp(() async {
      await sl.reset();
      sl.registerSingleton<TenantContext>(
        TenantContext()..setFromSession(
          restaurantId: 'restaurante_a',
          userId: 'usr_a',
          rol: 'cajero',
        ),
      );
      repository = _FakeClienteRepository();
      service = ClienteServiceImpl(
        getClienteByCedula: GetClienteByCedula(repository),
        createCliente: CreateCliente(repository),
        updateCliente: UpdateCliente(repository),
      );
    });

    tearDown(() async {
      await sl.reset();
    });

    test(
      'buscarOCrear actualiza un cliente existente sin duplicarlo',
      () async {
        final now = DateTime(2026, 5, 1);
        repository.seed(
          Cliente(
            idCliente: 12,
            cedula: '0102030400',
            restaurantId: 'restaurante_a',
            nombre: 'Ana',
            apellido: 'Lopez',
            telefono: '0990000000',
            createdAt: now,
            updatedAt: now,
          ),
        );

        final cliente = await service.buscarOCrear({
          'cedula': '010-203-0400',
          'nombres': 'Ana Lopez',
          'telefono': '0981111111',
          'email': 'ana@example.com',
          'direccion': 'Av. Central',
        });

        expect(cliente.idCliente, 12);
        expect(cliente.restaurantId, 'restaurante_a');
        expect(cliente.cedula, '0102030400');
        expect(cliente.telefono, '0981111111');
        expect(cliente.email, 'ana@example.com');
        expect(cliente.direccion, 'Av. Central');
        expect(repository.recordsFor('restaurante_a'), hasLength(1));
        expect(repository.createCalls, 0);
        expect(repository.updateCalls, 1);
      },
    );
  });
}

class _FakeClienteRepository implements ClienteRepository {
  final Map<String, Cliente> _clientes = {};
  int createCalls = 0;
  int updateCalls = 0;

  String _key(String restaurantId, String cedula) => '$restaurantId:$cedula';

  void seed(Cliente cliente) {
    _clientes[_key(cliente.restaurantId, cliente.cedula)] = cliente;
  }

  List<Cliente> recordsFor(String restaurantId) => _clientes.values
      .where((cliente) => cliente.restaurantId == restaurantId)
      .toList();

  @override
  ResultFuture<List<Cliente>> getClientes(String restaurantId) async =>
      Right(recordsFor(restaurantId));

  @override
  ResultFuture<Cliente?> getClienteByCedula(
    String restaurantId,
    String cedula,
  ) async => Right(_clientes[_key(restaurantId, cedula)]);

  @override
  ResultFuture<List<Cliente>> buscarClientes(
    String restaurantId,
    String query,
  ) async => Right(recordsFor(restaurantId));

  @override
  ResultFuture<Cliente> createCliente(Cliente cliente) async {
    createCalls++;
    if (_clientes.containsKey(_key(cliente.restaurantId, cliente.cedula))) {
      return const Left(BusinessFailure(message: 'Duplicado'));
    }
    _clientes[_key(cliente.restaurantId, cliente.cedula)] = cliente;
    return Right(cliente);
  }

  @override
  ResultFuture<Cliente> updateCliente(Cliente cliente) async {
    updateCalls++;
    _clientes[_key(cliente.restaurantId, cliente.cedula)] = cliente;
    return Right(cliente);
  }

  @override
  ResultFuture<void> deleteCliente(String restaurantId, String cedula) async {
    _clientes.remove(_key(restaurantId, cedula));
    return const Right(null);
  }

  @override
  ResultFuture<ClienteResumen> getResumenCliente(
    String cedula,
    String restaurantId,
  ) async => Right(
    ClienteResumen(
      cedula: cedula,
      totalVisitas: 0,
      totalGastado: 0,
      ticketPromedio: 0,
    ),
  );
}

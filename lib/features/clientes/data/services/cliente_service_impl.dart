import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/clientes/domain/entities/cliente.dart';
import 'package:restaurant_app/features/clientes/domain/services/cliente_service.dart';
import 'package:restaurant_app/features/clientes/domain/usecases/cliente_usecases.dart';

class ClienteServiceImpl implements ClienteService {
  const ClienteServiceImpl({
    required GetClienteByCedula getClienteByCedula,
    required CreateCliente createCliente,
    required UpdateCliente updateCliente,
  }) : _getClienteByCedula = getClienteByCedula,
       _createCliente = createCliente,
       _updateCliente = updateCliente;

  final GetClienteByCedula _getClienteByCedula;
  final CreateCliente _createCliente;
  final UpdateCliente _updateCliente;

  String? _cleanOptional(String? value) {
    final clean = value?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
    return clean.isEmpty ? null : clean;
  }

  Cliente _mergeCliente(Cliente existente, Map<String, dynamic> datos) {
    final nombres = _cleanOptional(datos['nombres'] as String?);
    var nombre = existente.nombre;
    var apellido = existente.apellido;
    if (nombres != null && nombres != existente.nombreCompleto) {
      final partes = nombres
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .toList();
      nombre = partes.isEmpty ? nombres : partes.first;
      apellido = partes.length > 1 ? partes.sublist(1).join(' ') : null;
    }

    final telefono =
        _cleanOptional(datos['telefono'] as String?) ?? existente.telefono;
    final email = _cleanOptional(datos['email'] as String?) ?? existente.email;
    final direccion =
        _cleanOptional(datos['direccion'] as String?) ?? existente.direccion;
    final notas = _cleanOptional(datos['notas'] as String?) ?? existente.notas;

    final changed =
        nombre != existente.nombre ||
        apellido != existente.apellido ||
        telefono != existente.telefono ||
        email != existente.email ||
        direccion != existente.direccion ||
        notas != existente.notas;

    if (!changed) return existente;
    return existente.copyWith(
      nombre: nombre,
      apellido: apellido,
      telefono: telefono,
      email: email,
      direccion: direccion,
      notas: notas,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<Cliente?> buscarPorCedula(String cedula) async {
    final clean = cedula.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return null;
    final result = await _getClienteByCedula(
      sl<TenantContext>().restaurantId,
      clean,
    );
    return result.fold((_) => null, (cliente) => cliente);
  }

  @override
  Future<Cliente> crearCliente(Map<String, dynamic> datos) async {
    final cedula = (datos['cedula'] as String? ?? '').replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final nombres = (datos['nombres'] as String? ?? '').trim();
    if (cedula.isEmpty || nombres.isEmpty) {
      throw const BusinessException(
        message: 'La cédula y nombres son obligatorios para registrar cliente.',
      );
    }
    if (!Cliente.esCedulaValida(cedula)) {
      throw const BusinessException(
        message: 'La cédula/RUC ingresada no es válida.',
      );
    }

    final partes = nombres
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final nombre = partes.isEmpty ? nombres : partes.first;
    final apellido = partes.length > 1 ? partes.sublist(1).join(' ') : null;
    final now = DateTime.now();

    final cliente = Cliente(
      cedula: cedula,
      restaurantId: sl<TenantContext>().restaurantId,
      nombre: nombre,
      apellido: apellido,
      telefono: (datos['telefono'] as String?)?.trim().isEmpty ?? true
          ? null
          : (datos['telefono'] as String).trim(),
      email: (datos['email'] as String?)?.trim().isEmpty ?? true
          ? null
          : (datos['email'] as String).trim(),
      direccion: (datos['direccion'] as String?)?.trim().isEmpty ?? true
          ? null
          : (datos['direccion'] as String).trim(),
      notas: (datos['notas'] as String?)?.trim().isEmpty ?? true
          ? null
          : (datos['notas'] as String).trim(),
      createdAt: now,
      updatedAt: now,
    );

    final result = await _createCliente(cliente);
    return result.fold(
      (failure) => throw BusinessException(message: failure.message),
      (created) => created,
    );
  }

  @override
  Future<Cliente> buscarOCrear(Map<String, dynamic> datos) async {
    final cedula = (datos['cedula'] as String? ?? '').trim();
    if (cedula.isEmpty) {
      throw const BusinessException(
        message: 'Debes ingresar cédula para buscar o crear cliente.',
      );
    }

    final existente = await buscarPorCedula(cedula);
    if (existente != null) {
      final merged = _mergeCliente(existente, datos);
      if (merged == existente) return existente;
      final result = await _updateCliente(merged);
      return result.fold(
        (failure) => throw BusinessException(message: failure.message),
        (updated) => updated,
      );
    }

    return crearCliente({...datos, 'cedula': cedula});
  }
}

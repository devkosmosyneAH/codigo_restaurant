import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/cotizaciones/domain/usecases/cotizacion_usecases.dart';

final cotizacionesProvider = FutureProvider.autoDispose<List<Cotizacion>>((
  ref,
) async {
  final result = await sl<GetCotizaciones>()(sl<TenantContext>().restaurantId);
  return result.fold((_) => <Cotizacion>[], (items) => items);
});

// ── Filtros de búsqueda ───────────────────────────────────────────────────────

/// Texto libre de búsqueda (nombre cliente, teléfono, empresa).
final cotizacionSearchProvider = StateProvider.autoDispose<String>((_) => '');

/// Estado seleccionado para filtrar ('todos' = sin filtro).
final cotizacionEstadoFiltroProvider = StateProvider.autoDispose<String>(
  (_) => 'todos',
);

/// Lista filtrada según búsqueda y estado.
final cotizacionesFiltadasProvider =
    Provider.autoDispose<AsyncValue<List<Cotizacion>>>((ref) {
      final all = ref.watch(cotizacionesProvider);
      final query = ref.watch(cotizacionSearchProvider).toLowerCase().trim();
      final estado = ref.watch(cotizacionEstadoFiltroProvider);

      return all.whenData((items) {
        return items.where((c) {
          final matchEstado = estado == 'todos' || c.estado == estado;
          final matchQuery =
              query.isEmpty ||
              c.clienteNombre.toLowerCase().contains(query) ||
              c.clienteTelefono.contains(query) ||
              (c.clienteEmpresa ?? '').toLowerCase().contains(query) ||
              (c.clienteEmail).toLowerCase().contains(query);
          return matchEstado && matchQuery;
        }).toList();
      });
    });

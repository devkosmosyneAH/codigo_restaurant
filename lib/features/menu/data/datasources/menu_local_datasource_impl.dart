import 'dart:async';

import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/sync/sync_manager.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/menu/data/datasources/menu_local_datasource.dart';
import 'package:restaurant_app/features/menu/data/models/categoria_model.dart';
import 'package:restaurant_app/features/menu/data/models/producto_model.dart';
import 'package:restaurant_app/features/menu/data/models/variante_model.dart';
import 'package:restaurant_app/features/menu/data/services/menu_realtime_database_service.dart';

/// Implementación del datasource local de Menú usando SQLite.
class MenuLocalDataSourceImpl implements MenuLocalDataSource {
  final DatabaseHelper _dbHelper;
  final SyncManager _syncManager;
  final TenantContext _tenantContext;
  final MenuRealtimeDatabaseService _menuRealtimeDb;

  MenuLocalDataSourceImpl({
    required DatabaseHelper dbHelper,
    required SyncManager syncManager,
    required TenantContext tenantContext,
    required MenuRealtimeDatabaseService menuRealtimeDb,
  }) : _dbHelper = dbHelper,
       _syncManager = syncManager,
       _tenantContext = tenantContext,
       _menuRealtimeDb = menuRealtimeDb;

  static const _tableCategorias = 'categorias';
  static const _tableProductos = 'productos';
  static const _tableVariantes = 'variantes';

  // ── Categorías ───────────────────────────────────────────────────

  @override
  Future<List<CategoriaModel>> getCategorias(String restaurantId) async {
    try {
      final results = await _dbHelper.query(
        _tableCategorias,
        where: 'restaurant_id = ? AND activo = 1',
        whereArgs: [restaurantId],
        orderBy: 'orden ASC, nombre ASC',
      );
      return results.map((row) => CategoriaModel.fromMap(row)).toList();
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener categorías: $e');
    }
  }

  @override
  Future<CategoriaModel?> getCategoriaById(String id) async {
    try {
      final results = await _dbHelper.query(
        _tableCategorias,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (results.isEmpty) return null;
      return CategoriaModel.fromMap(results.first);
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener categoría: $e');
    }
  }

  @override
  Future<void> createCategoria(CategoriaModel categoria) async {
    try {
      await _dbHelper.insert(_tableCategorias, categoria.toMap());
      await _syncManager.registrarOperacion(
        tabla: _tableCategorias,
        registroId: categoria.id,
        operacion: SyncOperation.insert,
        restaurantId: categoria.restaurantId,
        datos: categoria.toMap(),
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al crear categoría: $e');
    }
  }

  @override
  Future<void> updateCategoria(CategoriaModel categoria) async {
    try {
      final data = categoria.toMap();
      data['updated_at'] = DateTime.now().toIso8601String();
      await _dbHelper.update(
        _tableCategorias,
        data,
        where: 'id = ?',
        whereArgs: [categoria.id],
      );
      await _syncManager.registrarOperacion(
        tabla: _tableCategorias,
        registroId: categoria.id,
        operacion: SyncOperation.update,
        restaurantId: categoria.restaurantId,
        datos: data,
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al actualizar categoría: $e');
    }
  }

  @override
  Future<void> deleteCategoria(String id) async {
    try {
      await _dbHelper.update(
        _tableCategorias,
        {'activo': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _syncManager.registrarOperacion(
        tabla: _tableCategorias,
        registroId: id,
        operacion: SyncOperation.delete,
        restaurantId: _tenantContext.restaurantId,
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al eliminar categoría: $e');
    }
  }

  @override
  Future<void> reordenarCategorias(List<String> orderedIds) async {
    try {
      await _dbHelper.transaction((txn) async {
        for (var i = 0; i < orderedIds.length; i++) {
          await txn.update(
            _tableCategorias,
            {'orden': i, 'updated_at': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [orderedIds[i]],
          );
        }
      });
    } catch (e) {
      throw DatabaseException(message: 'Error al reordenar categorías: $e');
    }
  }

  // ── Productos ────────────────────────────────────────────────────

  @override
  Future<List<ProductoModel>> getProductos(String restaurantId) async {
    try {
      final results = await _dbHelper.query(
        _tableProductos,
        where: 'restaurant_id = ? AND activo = 1',
        whereArgs: [restaurantId],
        orderBy: 'nombre ASC',
      );

      final productoIds = results
          .map((row) => row['id'] as String)
          .toList(growable: false);
      final variantesByProducto = await _getVariantesByProductoIds(productoIds);

      return results
          .map((row) {
            final productoId = row['id'] as String;
            final variantes =
                variantesByProducto[productoId] ?? const <VarianteModel>[];
            return ProductoModel.fromMap(row, variantes: variantes);
          })
          .toList(growable: false);
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener productos: $e');
    }
  }

  @override
  Future<List<ProductoModel>> getProductosByCategoria(
    String categoriaId,
  ) async {
    try {
      final results = await _dbHelper.query(
        _tableProductos,
        where: 'categoria_id = ? AND activo = 1',
        whereArgs: [categoriaId],
        orderBy: 'nombre ASC',
      );

      final productoIds = results
          .map((row) => row['id'] as String)
          .toList(growable: false);
      final variantesByProducto = await _getVariantesByProductoIds(productoIds);

      return results
          .map((row) {
            final productoId = row['id'] as String;
            final variantes =
                variantesByProducto[productoId] ?? const <VarianteModel>[];
            return ProductoModel.fromMap(row, variantes: variantes);
          })
          .toList(growable: false);
    } catch (e) {
      throw DatabaseException(
        message: 'Error al obtener productos de categoría: $e',
      );
    }
  }

  @override
  Future<ProductoModel?> getProductoById(String id) async {
    try {
      final results = await _dbHelper.query(
        _tableProductos,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (results.isEmpty) return null;
      final variantes = await getVariantesByProducto(id);
      return ProductoModel.fromMap(results.first, variantes: variantes);
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener producto: $e');
    }
  }

  @override
  Future<void> createProducto(ProductoModel producto) async {
    try {
      final data = producto.toMap();
      await _dbHelper.transaction((txn) async {
        await txn.insert(_tableProductos, data);
        for (final vm in producto.variantesToMapList()) {
          await txn.insert(_tableVariantes, vm);
        }
      });
      await _syncManager.registrarOperacion(
        tabla: _tableProductos,
        registroId: producto.id,
        operacion: SyncOperation.insert,
        restaurantId: producto.restaurantId,
        datos: data,
      );

      unawaited(
        _menuRealtimeDb.upsertProducto(
          restaurantId: producto.restaurantId,
          productoId: producto.id,
          data: data,
        ),
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al crear producto: $e');
    }
  }

  @override
  Future<void> updateProducto(ProductoModel producto) async {
    try {
      final data = producto.toMap();
      data['updated_at'] = DateTime.now().toIso8601String();

      await _dbHelper.transaction((txn) async {
        // 1. Actualizar campos del producto
        await txn.update(
          _tableProductos,
          data,
          where: 'id = ?',
          whereArgs: [producto.id],
        );

        // 2. Soft-delete de todas las variantes existentes del producto
        await txn.update(
          _tableVariantes,
          {'activo': 0, 'updated_at': DateTime.now().toIso8601String()},
          where: 'producto_id = ?',
          whereArgs: [producto.id],
        );

        // 3. Re-insertar las variantes actuales (replace si ya existe el id)
        for (final vm in producto.variantesToMapList()) {
          await txn.insert(
            _tableVariantes,
            vm,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      await _syncManager.registrarOperacion(
        tabla: _tableProductos,
        registroId: producto.id,
        operacion: SyncOperation.update,
        restaurantId: producto.restaurantId,
        datos: data,
      );

      unawaited(
        _menuRealtimeDb.upsertProducto(
          restaurantId: producto.restaurantId,
          productoId: producto.id,
          data: data,
        ),
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al actualizar producto: $e');
    }
  }

  @override
  Future<void> deleteProducto(String id) async {
    try {
      // Soft-delete también las variantes
      await _dbHelper.transaction((txn) async {
        await txn.update(
          _tableVariantes,
          {'activo': 0, 'updated_at': DateTime.now().toIso8601String()},
          where: 'producto_id = ?',
          whereArgs: [id],
        );
        await txn.update(
          _tableProductos,
          {'activo': 0, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      await _syncManager.registrarOperacion(
        tabla: _tableProductos,
        registroId: id,
        operacion: SyncOperation.delete,
        restaurantId: _tenantContext.restaurantId,
      );

      unawaited(
        _menuRealtimeDb.deleteProducto(
          restaurantId: _tenantContext.restaurantId,
          productoId: id,
        ),
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al eliminar producto: $e');
    }
  }

  @override
  Future<void> toggleDisponibilidad(String id, bool disponible) async {
    try {
      final updatedAt = DateTime.now().toIso8601String();
      await _dbHelper.update(
        _tableProductos,
        {'disponible': disponible ? 1 : 0, 'updated_at': updatedAt},
        where: 'id = ?',
        whereArgs: [id],
      );

      unawaited(
        _menuRealtimeDb.patchProducto(
          restaurantId: _tenantContext.restaurantId,
          productoId: id,
          data: {'disponible': disponible ? 1 : 0, 'updated_at': updatedAt},
        ),
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al cambiar disponibilidad: $e');
    }
  }

  // ── Variantes ────────────────────────────────────────────────────

  Future<Map<String, List<VarianteModel>>> _getVariantesByProductoIds(
    List<String> productoIds,
  ) async {
    if (productoIds.isEmpty) return const {};

    final placeholders = List.filled(productoIds.length, '?').join(',');
    final rows = await _dbHelper.rawQuery('''
        SELECT *
        FROM $_tableVariantes
        WHERE activo = 1
          AND producto_id IN ($placeholders)
        ORDER BY producto_id ASC, precio ASC
      ''', productoIds);

    final grouped = <String, List<VarianteModel>>{};
    for (final row in rows) {
      final variante = VarianteModel.fromMap(row);
      grouped.putIfAbsent(variante.productoId, () => []).add(variante);
    }
    return grouped;
  }

  @override
  Future<List<VarianteModel>> getVariantesByProducto(String productoId) async {
    try {
      final results = await _dbHelper.query(
        _tableVariantes,
        where: 'producto_id = ? AND activo = 1',
        whereArgs: [productoId],
        orderBy: 'precio ASC',
      );
      return results.map((row) => VarianteModel.fromMap(row)).toList();
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener variantes: $e');
    }
  }

  @override
  Future<void> createVariante(VarianteModel variante) async {
    try {
      await _dbHelper.insert(_tableVariantes, variante.toMap());
      await _syncManager.registrarOperacion(
        tabla: _tableVariantes,
        registroId: variante.id,
        operacion: SyncOperation.insert,
        restaurantId: _tenantContext.restaurantId,
        datos: variante.toMap(),
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al crear variante: $e');
    }
  }

  @override
  Future<void> updateVariante(VarianteModel variante) async {
    try {
      final data = variante.toMap();
      data['updated_at'] = DateTime.now().toIso8601String();
      await _dbHelper.update(
        _tableVariantes,
        data,
        where: 'id = ?',
        whereArgs: [variante.id],
      );
      await _syncManager.registrarOperacion(
        tabla: _tableVariantes,
        registroId: variante.id,
        operacion: SyncOperation.update,
        restaurantId: _tenantContext.restaurantId,
        datos: data,
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al actualizar variante: $e');
    }
  }

  @override
  Future<void> deleteVariante(String id) async {
    try {
      await _dbHelper.update(
        _tableVariantes,
        {'activo': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _syncManager.registrarOperacion(
        tabla: _tableVariantes,
        registroId: id,
        operacion: SyncOperation.delete,
        restaurantId: _tenantContext.restaurantId,
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al eliminar variante: $e');
    }
  }
}

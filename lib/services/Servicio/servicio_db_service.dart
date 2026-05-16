import 'package:restaurant_app/Models/Servicio/Servicio.dart';
import 'package:restaurant_app/services/database_service.dart';
import 'package:sqflite/sqflite.dart';

class ServicioDBService {
  static final ServicioDBService _instance = ServicioDBService._internal();
  factory ServicioDBService() => _instance;
  ServicioDBService._internal();

  static const String _tableservicio = 'servicio';

  Future<List<Servicio>> getServicios() async {
    final db = await DatabaseService.database;
    final maps = await db.query(_tableservicio);
    return maps.map((e) => Servicio.fromMap(e)).toList();
  }

  Future<void> addServicio(Servicio servicio) async {
    final db = await DatabaseService.database;
    await db.insert(
      _tableservicio,
      servicio.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateServicio(Servicio servicio) async {
    final db = await DatabaseService.database;
    await db.update(
      _tableservicio,
      servicio.toMap(),
      where: '_key = ?',
      whereArgs: [servicio.key],
    );
  }

  Future<void> deleteServicio(String key) async {
    final db = await DatabaseService.database;
    await db.delete(_tableservicio, where: '_key = ?', whereArgs: [key]);
  }
}

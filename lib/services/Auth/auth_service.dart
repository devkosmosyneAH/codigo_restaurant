import '../database_service.dart';
import '../session_service.dart';

class AuthService {
  /// Login con verificación en SQLite y guardado de sesión
  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {

      // Buscar usuario en la base de datos SQLite
      final List<Map<String, dynamic>> users = await DatabaseService.rawQuery(
        'SELECT * FROM users WHERE email = ? LIMIT 1',
        [email],
      );

      if (users.isNotEmpty) {
        final user = users.first;

        // En un sistema real, aquí verificarías el password hasheado
        // Por ahora, simulamos que el login es exitoso si el usuario existe
        
        // Guardar TODOS los datos del usuario en la sesión, no solo los básicos
        final userData = Map<String, dynamic>.from(user);
        
        // Asegurar que el uid esté presente
        userData['uid'] = user['uid'] ?? user['_key'];
        

        // Guardar sesión del usuario
        final sessionSaved = await SessionService.saveUserSession(userData);
        if (sessionSaved) {
        } else {
        }

        return userData;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Simular registro de usuario
  Future<Map<String, dynamic>?> register(
    String email,
    String password,
    String firstName,
    String lastName,
    String permission,
    String role,
  ) async {
    try {

      // Verificar si el usuario ya existe
      final existingUsers = await DatabaseService.rawQuery(
        'SELECT * FROM users WHERE email = ? LIMIT 1',
        [email],
      );

      if (existingUsers.isNotEmpty) {
        return null;
      }

      // Generar un UID único (en un sistema real sería más seguro)
      final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';

      // Insertar usuario en la base de datos
      final result = await DatabaseService.rawInsert(
        '''INSERT INTO users (uid, email, name, lastname, role, permission) 
           VALUES (?, ?, ?, ?, ?, ?)''',
        [uid, email, firstName, lastName, role, permission],
      );

      if (result > 0) {
        return {
          'uid': uid,
          'email': email,
          'name': firstName,
          'lastName': lastName,
          'role': role,
          'permission': permission,
        };
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Obtener usuario por UID
  Future<Map<String, dynamic>?> getUserByUid(String uid) async {
    try {

      final List<Map<String, dynamic>> users = await DatabaseService.rawQuery(
        'SELECT * FROM users WHERE uid = ? LIMIT 1',
        [uid],
      );

      if (users.isNotEmpty) {
        return users.first;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Obtener usuario por email
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {

      final List<Map<String, dynamic>> users = await DatabaseService.rawQuery(
        'SELECT * FROM users WHERE email = ? LIMIT 1',
        [email],
      );

      if (users.isNotEmpty) {
        return users.first;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Actualizar datos de usuario
  Future<bool> updateUser(String uid, Map<String, dynamic> updates) async {
    try {

      final setClause = updates.keys.map((key) => '$key = ?').join(', ');
      final values = [...updates.values, uid];

      final result = await DatabaseService.rawUpdate(
        'UPDATE users SET $setClause WHERE uid = ?',
        values,
      );

      return result > 0;
    } catch (e) {
      return false;
    }
  }

  /// Obtener rol de un usuario
  Future<String?> getRole(String uid) async {
    try {
      final user = await getUserByUid(uid);
      return user?['role'];
    } catch (e) {
      return null;
    }
  }

  /// Obtener todos los usuarios
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {

      final List<Map<String, dynamic>> users = await DatabaseService.rawQuery(
        'SELECT * FROM users ORDER BY name ASC',
      );

      return users;
    } catch (e) {
      return [];
    }
  }

  /// Crear usuario completo
  Future<bool> createUser(Map<String, dynamic> userData) async {
    try {

      // Extraer campos principales
      final uid =
          userData['uid'] ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
      final email = userData['email'];
      final name = userData['name'];
      final lastname = userData['lastname'];
      final role = userData['role'];
      final permission = userData['permission'];

      // Insertar usuario base
      final result = await DatabaseService.rawInsert(
        '''INSERT INTO users (
          uid, email, name, lastname, role, permission, 
          regimen, nombreComercial, propietario, ruc,
          actividad_descripcion, actividad_detalle_0, actividad_detalle_1, actividad_detalle_2, actividad_detalle_3,
          contacto_direccion, contacto_telefono, contacto_celular_0,
          factura_tipo, factura_numero, factura_codigo,
          ubicacion, autorizacionSRI, createdAt
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          uid,
          email,
          name,
          lastname,
          role,
          permission,
          userData['regimen'],
          userData['nombreComercial'],
          userData['propietario'],
          userData['ruc'],
          userData['actividadDescripcion'],
          userData['actividadDetalle0'],
          userData['actividadDetalle1'],
          userData['actividadDetalle2'],
          userData['actividadDetalle3'],
          userData['contactoDireccion'],
          userData['contactoTelefono'],
          userData['contactoCelular0'],
          userData['facturaTipo'],
          userData['facturaNumero'],
          userData['facturaCodigo'],
          userData['ubicacion'],
          userData['autorizacionSRI'],
          userData['createdAt'],
        ],
      );

      if (result > 0) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Actualizar usuario completo
  Future<bool> updateUserComplete(
    String uid,
    Map<String, dynamic> userData,
  ) async {
    try {

      // Construir query dinámicamente
      final List<String> setFields = [];
      final List<dynamic> values = [];

      userData.forEach((key, value) {
        if (key != 'uid' && value != null) {
          setFields.add('$key = ?');
          values.add(value);
        }
      });

      if (setFields.isEmpty) {
        return false;
      }

      values.add(uid); // Agregar UID para la condición WHERE

      final String query =
          'UPDATE users SET ${setFields.join(', ')} WHERE uid = ?';

      final result = await DatabaseService.rawUpdate(query, values);

      if (result > 0) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Eliminar usuario
  Future<bool> deleteUser(String uid) async {
    try {

      final result = await DatabaseService.rawDelete(
        'DELETE FROM users WHERE uid = ?',
        [uid],
      );

      if (result > 0) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Cerrar sesión del usuario actual
  Future<bool> logout() async {
    try {

      final success = await SessionService.logout();

      if (success) {
      } else {
      }

      return success;
    } catch (e) {
      return false;
    }
  }

  /// Verificar si hay una sesión activa
  Future<bool> isLoggedIn() async {
    try {
      return await SessionService.isUserLoggedIn();
    } catch (e) {
      return false;
    }
  }

  /// Obtener usuario actual de la sesión
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      return await SessionService.getCurrentUserSession();
    } catch (e) {
      return null;
    }
  }
}
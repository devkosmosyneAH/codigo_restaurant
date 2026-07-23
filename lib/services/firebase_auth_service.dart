import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/services/Auth/auth_service.dart';
import 'package:restaurant_app/services/session_service.dart';

/// Servicio ÚNICO para autenticación con Firebase.
class FirebaseAuthService {
  FirebaseAuthService._({
    FirebaseAuth? firebaseAuth,
    DatabaseReference? databaseReference,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _database = databaseReference ?? FirebaseDatabase.instance.ref();

  static FirebaseAuthService? _instance;

  /// Obtiene la instancia única de FirebaseAuthService.
  static FirebaseAuthService get instance {
    _instance ??= FirebaseAuthService._();
    return _instance!;
  }

  /// Para pruebas: permite inyectar una instancia custom.
  @visibleForTesting
  static void setInstance(FirebaseAuthService instance) {
    _instance = instance;
  }

  /// Para pruebas: resetea la instancia.
  @visibleForTesting
  static void reset() {
    _instance = null;
  }

  final FirebaseAuth _firebaseAuth;
  final DatabaseReference _database;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;
  bool get isSignedIn => currentUser != null;

  Future<String?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _syncUserToRealtimeDatabase(credential.user);
      await _saveSessionFromFirebase(credential.user);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    } catch (e) {
      debugPrint('firebase_auth.sign_in_failed: $e');
      return 'No fue posible iniciar sesión en este momento.';
    }
  }

  Future<String?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    required String permission,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return 'No se pudo crear la cuenta.';
      }

      await user.updateDisplayName('$firstName $lastName'.trim());
      await _syncUserToRealtimeDatabase(
        user,
        extraData: {
          'name': firstName,
          'lastname': lastName,
          'role': role,
          'permission': permission,
          'restaurantId': AppConstants.defaultRestaurantId,
        },
      );
      await _saveSessionFromFirebase(user);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    } catch (e) {
      debugPrint('firebase_auth.register_failed: $e');
      return 'No fue posible crear la cuenta.';
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await SessionService.logout();
  }

  Future<Map<String, dynamic>?> restoreSessionFromFirebase() async {
    final user = currentUser ?? await _firebaseAuth
        .authStateChanges()
        .firstWhere((u) => u != null, orElse: () => null)
        .timeout(const Duration(seconds: 5), onTimeout: () => null);

    if (user == null) {
      await SessionService.logout();
      return null;
    }

    await _saveSessionFromFirebase(user);
    return await SessionService.getCurrentUserSession();
  }

  Future<Map<String, dynamic>?> getCurrentAuthenticatedUser() async {
    final user = currentUser;
    if (user == null) return null;

    final existingSession = await SessionService.getCurrentUserSession();
    if (existingSession != null) return existingSession;

    final profile = await _syncUserToRealtimeDatabase(user);
    final sessionData = {
      'uid': user.uid,
      'email': user.email,
      'name': user.displayName ?? profile?['name'] ?? 'Usuario',
      'role': profile?['role'] ?? 'administrador',
      'permission': profile?['permission'] ?? 'admin',
      'restaurantId': AppConstants.defaultRestaurantId,
    };
    await SessionService.saveUserSession(sessionData);
    return sessionData;
  }

  Future<void> _saveSessionFromFirebase(User? user) async {
    if (user == null) {
      await SessionService.logout();
      return;
    }

    final profile = await _syncUserToRealtimeDatabase(user);
    final sessionData = {
      'uid': user.uid,
      'email': user.email,
      'name': user.displayName ?? profile?['name'] ?? 'Usuario',
      'role': profile?['role'] ?? 'administrador',
      'permission': profile?['permission'] ?? 'admin',
      'restaurantId': AppConstants.defaultRestaurantId,
    };
    await SessionService.saveUserSession(sessionData);

    final localUser = await AuthService().getUserByUid(user.uid);
    if (localUser != null) {
      await AuthService().updateUser(user.uid, {
        'email': user.email ?? localUser['email'],
        'name': profile?['name'] ?? localUser['name'],
        'lastname': profile?['lastname'] ?? localUser['lastname'],
        'role': profile?['role'] ?? localUser['role'],
        'permission': profile?['permission'] ?? localUser['permission'],
      });
    }
  }

  Future<Map<String, dynamic>?> _syncUserToRealtimeDatabase(
    User? user, {
    Map<String, dynamic>? extraData,
  }) async {
    if (user == null) return null;

    final profileRef = _database.child('users').child(user.uid);
    final snapshot = await profileRef.once();
    final profile = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'updatedAt': ServerValue.timestamp,
      if (extraData != null) ...extraData,
    };

    if (snapshot.snapshot.exists) {
      final existingData = Map<String, dynamic>.from(
        (snapshot.snapshot.value as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      );
      profile.addAll(existingData);
      profile['uid'] = user.uid;
      profile['email'] = profile['email'] ?? user.email;
      profile['displayName'] = profile['displayName'] ?? user.displayName;
    }

    await profileRef.set(profile);
    return profile;
  }

  static String _mapAuthError(String code) {
    return switch (code) {
      'invalid-email' => 'El correo electrónico no es válido.',
      'user-disabled' => 'Esta cuenta está deshabilitada.',
      'user-not-found' => 'No existe una cuenta con ese correo.',
      'wrong-password' => 'La contraseña es incorrecta.',
      'email-already-in-use' => 'Ya existe una cuenta con ese correo.',
      'weak-password' => 'La contraseña debe tener al menos 6 caracteres.',
      'operation-not-allowed' =>
        'El método de autenticación no está habilitado.',
      _ => 'No fue posible completar la solicitud de autenticación.',
    };
  }
}

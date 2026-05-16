import 'dart:convert';

import 'package:get_it/get_it.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

/// Datos fiscales del emisor necesarios para generar comprobantes electrónicos.
class FiscalConfig {
  const FiscalConfig({
    this.restaurantId = '',
    this.ruc = '',
    this.razonSocial = '',
    this.nombreComercial = '',
    this.establecimiento = '001',
    this.puntoEmision = '001',
    this.autorizacionSri = '',
    this.direccion = '',
    this.ambiente = 'pruebas',
    this.obligadoContabilidad = false,
    this.regimen = '',
    this.contribuyenteEspecial = '',
    this.endpointBackend = '',
    this.activo = true,
    this.createdAt,
    this.updatedAt,
  });

  final String restaurantId;
  final String ruc;
  final String razonSocial;
  final String nombreComercial;
  final String establecimiento;
  final String puntoEmision;
  final String autorizacionSri;
  final String direccion;
  final String ambiente;
  final bool obligadoContabilidad;
  final String regimen;
  final String contribuyenteEspecial;
  final String endpointBackend;
  final bool activo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isConfigured =>
      activo &&
      ruc.isNotEmpty &&
      razonSocial.isNotEmpty &&
      establecimiento.isNotEmpty &&
      puntoEmision.isNotEmpty &&
      direccion.isNotEmpty;

  Uri get backendBaseUri {
    final value = endpointBackend.trim().isEmpty
        ? AppConstants.sriBridgeBaseUrl
        : endpointBackend.trim();
    return Uri.parse(value);
  }

  FiscalConfig copyWith({
    String? restaurantId,
    String? ruc,
    String? razonSocial,
    String? nombreComercial,
    String? establecimiento,
    String? puntoEmision,
    String? autorizacionSri,
    String? direccion,
    String? ambiente,
    bool? obligadoContabilidad,
    String? regimen,
    String? contribuyenteEspecial,
    String? endpointBackend,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FiscalConfig(
      restaurantId: restaurantId ?? this.restaurantId,
      ruc: ruc ?? this.ruc,
      razonSocial: razonSocial ?? this.razonSocial,
      nombreComercial: nombreComercial ?? this.nombreComercial,
      establecimiento: establecimiento ?? this.establecimiento,
      puntoEmision: puntoEmision ?? this.puntoEmision,
      autorizacionSri: autorizacionSri ?? this.autorizacionSri,
      direccion: direccion ?? this.direccion,
      ambiente: ambiente ?? this.ambiente,
      obligadoContabilidad: obligadoContabilidad ?? this.obligadoContabilidad,
      regimen: regimen ?? this.regimen,
      contribuyenteEspecial:
          contribuyenteEspecial ?? this.contribuyenteEspecial,
      endpointBackend: endpointBackend ?? this.endpointBackend,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'restaurantId': restaurantId,
    'ruc': ruc,
    'razonSocial': razonSocial,
    'nombreComercial': nombreComercial,
    'establecimiento': establecimiento,
    'puntoEmision': puntoEmision,
    'autorizacionSri': autorizacionSri,
    'direccion': direccion,
    'ambiente': ambiente,
    'obligadoContabilidad': obligadoContabilidad,
    'regimen': regimen,
    'contribuyenteEspecial': contribuyenteEspecial,
    'endpointBackend': endpointBackend,
    'activo': activo,
  };

  Map<String, dynamic> toMap(String scopedRestaurantId) {
    final now = DateTime.now().toIso8601String();
    return {
      'restaurant_id': scopedRestaurantId,
      'ruc': _digits(ruc),
      'razon_social': _clean(razonSocial),
      'nombre_comercial': _clean(nombreComercial),
      'direccion_matriz': _clean(direccion),
      'obligado_contabilidad': obligadoContabilidad ? 1 : 0,
      'regimen': _clean(regimen),
      'contribuyente_especial': _clean(contribuyenteEspecial),
      'establecimiento': _fixedDigits(establecimiento, 3, '001'),
      'punto_emision': _fixedDigits(puntoEmision, 3, '001'),
      'autorizacion_sri': _clean(autorizacionSri),
      'ambiente': ambiente.trim().isEmpty ? 'pruebas' : ambiente.trim(),
      'endpoint_backend': endpointBackend.trim(),
      'activo': activo ? 1 : 0,
      'created_at': createdAt?.toIso8601String() ?? now,
      'updated_at': now,
    };
  }

  factory FiscalConfig.fromJson(Map<String, dynamic> json) => FiscalConfig(
    restaurantId: (json['restaurantId'] as String?) ?? '',
    ruc: (json['ruc'] as String?) ?? '',
    razonSocial: (json['razonSocial'] as String?) ?? '',
    nombreComercial: (json['nombreComercial'] as String?) ?? '',
    establecimiento: (json['establecimiento'] as String?) ?? '001',
    puntoEmision: (json['puntoEmision'] as String?) ?? '001',
    autorizacionSri: (json['autorizacionSri'] as String?) ?? '',
    direccion: (json['direccion'] as String?) ?? '',
    ambiente: (json['ambiente'] as String?) ?? 'pruebas',
    obligadoContabilidad: (json['obligadoContabilidad'] as bool?) ?? false,
    regimen: (json['regimen'] as String?) ?? '',
    contribuyenteEspecial: (json['contribuyenteEspecial'] as String?) ?? '',
    endpointBackend: (json['endpointBackend'] as String?) ?? '',
    activo: (json['activo'] as bool?) ?? true,
  );

  factory FiscalConfig.fromMap(Map<String, dynamic> map) => FiscalConfig(
    restaurantId: map['restaurant_id'] as String? ?? '',
    ruc: map['ruc'] as String? ?? '',
    razonSocial: map['razon_social'] as String? ?? '',
    nombreComercial: map['nombre_comercial'] as String? ?? '',
    establecimiento: map['establecimiento'] as String? ?? '001',
    puntoEmision: map['punto_emision'] as String? ?? '001',
    autorizacionSri: map['autorizacion_sri'] as String? ?? '',
    direccion: map['direccion_matriz'] as String? ?? '',
    ambiente: map['ambiente'] as String? ?? 'pruebas',
    obligadoContabilidad:
        ((map['obligado_contabilidad'] as num?)?.toInt() ?? 0) == 1,
    regimen: map['regimen'] as String? ?? '',
    contribuyenteEspecial: map['contribuyente_especial'] as String? ?? '',
    endpointBackend: map['endpoint_backend'] as String? ?? '',
    activo: ((map['activo'] as num?)?.toInt() ?? 1) == 1,
    createdAt: _parseDate(map['created_at'] as String?),
    updatedAt: _parseDate(map['updated_at'] as String?),
  );
}

class SriCertificateInfo {
  const SriCertificateInfo({
    required this.restaurantId,
    required this.certificateIdBackend,
    this.subject = '',
    this.issuer = '',
    this.serial = '',
    this.validFrom,
    this.validTo,
    this.fingerprintSha256 = '',
    this.encryptedAt,
    this.status = 'no_cargado',
    this.updatedAt,
  });

  final String restaurantId;
  final String certificateIdBackend;
  final String subject;
  final String issuer;
  final String serial;
  final DateTime? validFrom;
  final DateTime? validTo;
  final String fingerprintSha256;
  final DateTime? encryptedAt;
  final String status;
  final DateTime? updatedAt;

  bool get isLoaded => certificateIdBackend.isNotEmpty && status == 'cargado';
  bool get isExpired => validTo != null && validTo!.isBefore(DateTime.now());

  Map<String, dynamic> toMap() => {
    'restaurant_id': restaurantId,
    'certificate_id_backend': certificateIdBackend,
    'subject': subject,
    'issuer': issuer,
    'serial': serial,
    'valid_from': validFrom?.toIso8601String(),
    'valid_to': validTo?.toIso8601String(),
    'fingerprint_sha256': fingerprintSha256,
    'encrypted_at': encryptedAt?.toIso8601String(),
    'status': status,
    'updated_at': DateTime.now().toIso8601String(),
  };

  factory SriCertificateInfo.fromMap(Map<String, dynamic> map) =>
      SriCertificateInfo(
        restaurantId: map['restaurant_id'] as String? ?? '',
        certificateIdBackend: map['certificate_id_backend'] as String? ?? '',
        subject: map['subject'] as String? ?? '',
        issuer: map['issuer'] as String? ?? '',
        serial: map['serial'] as String? ?? '',
        validFrom: _parseDate(map['valid_from'] as String?),
        validTo: _parseDate(map['valid_to'] as String?),
        fingerprintSha256: map['fingerprint_sha256'] as String? ?? '',
        encryptedAt: _parseDate(map['encrypted_at'] as String?),
        status: map['status'] as String? ?? 'no_cargado',
        updatedAt: _parseDate(map['updated_at'] as String?),
      );
}

/// Persiste y recupera la configuración fiscal por restaurante.
class FiscalConfigService {
  FiscalConfigService({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  static const String _legacyKey = 'fiscal_config';
  static const String _configsTable = 'sri_fiscal_configs';
  static const String _certificatesTable = 'sri_certificate_refs';

  final DatabaseHelper _dbHelper;

  Future<FiscalConfig> load({String? restaurantId}) async {
    final scopedRestaurantId = restaurantId ?? _currentRestaurantId();
    await _migrateLegacyIfNeeded(scopedRestaurantId);
    final rows = await _dbHelper.query(
      _configsTable,
      where: 'restaurant_id = ?',
      whereArgs: [scopedRestaurantId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return FiscalConfig(restaurantId: scopedRestaurantId);
    }
    return FiscalConfig.fromMap(rows.first);
  }

  Future<void> save(FiscalConfig config, {String? restaurantId}) async {
    final scopedRestaurantId = restaurantId ?? _currentRestaurantId();
    await _dbHelper.insert(
      _configsTable,
      config.toMap(scopedRestaurantId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<SriCertificateInfo?> loadCertificateInfo({
    String? restaurantId,
  }) async {
    final scopedRestaurantId = restaurantId ?? _currentRestaurantId();
    final rows = await _dbHelper.query(
      _certificatesTable,
      where: 'restaurant_id = ?',
      whereArgs: [scopedRestaurantId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SriCertificateInfo.fromMap(rows.first);
  }

  Future<void> saveCertificateInfo(SriCertificateInfo info) async {
    await _dbHelper.insert(
      _certificatesTable,
      info.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _migrateLegacyIfNeeded(String restaurantId) async {
    final existing = await _dbHelper.query(
      _configsTable,
      where: 'restaurant_id = ?',
      whereArgs: [restaurantId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_legacyKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final legacy = FiscalConfig.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      await save(legacy.copyWith(restaurantId: restaurantId));
      await prefs.remove(_legacyKey);
    } on Exception {
      return;
    }
  }

  String _currentRestaurantId() {
    final getIt = GetIt.I;
    if (getIt.isRegistered<TenantContext>()) {
      return getIt<TenantContext>().restaurantId;
    }
    return AppConstants.defaultRestaurantId;
  }
}

String _clean(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ');

String _digits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

String _fixedDigits(String value, int length, String fallback) {
  final digits = _digits(value);
  final source = digits.isEmpty ? fallback : digits;
  final trimmed = source.length > length
      ? source.substring(source.length - length)
      : source;
  return trimmed.padLeft(length, '0');
}

DateTime? _parseDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}

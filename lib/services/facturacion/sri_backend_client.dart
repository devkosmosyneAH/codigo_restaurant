import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/domain/enums.dart';

class SriBackendResponse {
  const SriBackendResponse({
    required this.success,
    required this.estado,
    required this.message,
    this.requestId,
    this.numeroAutorizacion,
    this.fechaAutorizacion,
    this.xmlFirmadoHash,
    this.ridePath,
    this.retryable = false,
    this.httpStatus,
    this.payload = const {},
  });

  final bool success;
  final EstadoComprobanteSri estado;
  final String message;
  final String? requestId;
  final String? numeroAutorizacion;
  final DateTime? fechaAutorizacion;
  final String? xmlFirmadoHash;
  final String? ridePath;
  final bool retryable;
  final int? httpStatus;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'success': success,
    'estado': estado.value,
    'message': message,
    'requestId': requestId,
    'numeroAutorizacion': numeroAutorizacion,
    'fechaAutorizacion': fechaAutorizacion?.toIso8601String(),
    'xmlFirmadoHash': xmlFirmadoHash,
    'ridePath': ridePath,
    'retryable': retryable,
    'httpStatus': httpStatus,
    'payload': payload,
  };

  factory SriBackendResponse.fromJson(
    Map<String, dynamic> json, {
    int? httpStatus,
  }) {
    final rawMessages = json['messages'] ?? json['mensajes'];
    final message = (json['message'] ?? json['mensaje'] ?? '').toString();
    final joinedMessages = rawMessages is List && rawMessages.isNotEmpty
        ? rawMessages.map((e) => e.toString()).join('\n')
        : message;
    final success =
        _readBool(json['success'] ?? json['ok']) ??
        (httpStatus != null && httpStatus >= 200 && httpStatus < 300);
    final estado = _parseEstado(
      json['estado'] ?? json['state'] ?? json['sriEstado'],
      success: success,
    );

    return SriBackendResponse(
      success: success,
      estado: estado,
      message: joinedMessages.isEmpty
          ? (success ? 'Operación SRI procesada.' : 'Operación SRI fallida.')
          : joinedMessages,
      requestId: (json['requestId'] ?? json['request_id'])?.toString(),
      numeroAutorizacion:
          (json['numeroAutorizacion'] ?? json['authorizationNumber'])
              ?.toString(),
      fechaAutorizacion: _parseDate(
        json['fechaAutorizacion'] ?? json['authorizationDate'],
      ),
      xmlFirmadoHash: (json['xmlFirmadoHash'] ?? json['signedXmlHash'])
          ?.toString(),
      ridePath: (json['ridePath'] ?? json['rideUrl'])?.toString(),
      retryable: _readBool(json['retryable']) ?? _isRetryableStatus(httpStatus),
      httpStatus: httpStatus,
      payload: json,
    );
  }
}

class SriCertificateUploadResult {
  const SriCertificateUploadResult({
    required this.certificateIdBackend,
    required this.fingerprintSha256,
    required this.subject,
    required this.issuer,
    required this.serial,
    this.validFrom,
    this.validTo,
  });

  final String certificateIdBackend;
  final String fingerprintSha256;
  final String subject;
  final String issuer;
  final String serial;
  final DateTime? validFrom;
  final DateTime? validTo;

  factory SriCertificateUploadResult.fromJson(Map<String, dynamic> json) {
    return SriCertificateUploadResult(
      certificateIdBackend:
          (json['certificateIdBackend'] ??
                  json['certificate_id'] ??
                  json['certificateId'])
              ?.toString() ??
          '',
      fingerprintSha256:
          (json['fingerprintSha256'] ?? json['fingerprint_sha256'])
              ?.toString() ??
          '',
      subject: json['subject']?.toString() ?? '',
      issuer: json['issuer']?.toString() ?? '',
      serial: json['serial']?.toString() ?? '',
      validFrom: _parseDate(json['validFrom'] ?? json['valid_from']),
      validTo: _parseDate(json['validTo'] ?? json['valid_to']),
    );
  }
}

abstract class SriBackendClient {
  Future<SriCertificateUploadResult> uploadCertificate({
    required String restaurantId,
    required Uint8List p12Bytes,
    required String password,
    String? fileName,
    Uri? endpoint,
  });

  Future<SriBackendResponse> submitInvoice(Map<String, dynamic> payload);

  Future<SriBackendResponse> queryStatus({
    required String restaurantId,
    required String comprobanteId,
    required String claveAcceso,
    Uri? endpoint,
  });

  Future<SriBackendResponse> sendEmail({
    required String restaurantId,
    required String comprobanteId,
    required String email,
    String? ridePdfBase64,
    Uri? endpoint,
  });
}

class SriBackendMockClient implements SriBackendClient {
  const SriBackendMockClient();

  @override
  Future<SriCertificateUploadResult> uploadCertificate({
    required String restaurantId,
    required Uint8List p12Bytes,
    required String password,
    String? fileName,
    Uri? endpoint,
  }) async {
    if (p12Bytes.isEmpty || password.trim().isEmpty) {
      throw ArgumentError('Certificado o contraseña inválidos.');
    }
    final fingerprint = sha256.convert(p12Bytes).toString();
    return SriCertificateUploadResult(
      certificateIdBackend: 'mock-cert-$restaurantId',
      fingerprintSha256: fingerprint,
      subject: 'CN=$restaurantId, O=Certificado mock SRI',
      issuer: 'Mock CA SRI',
      serial: 'MOCK-${DateTime.now().millisecondsSinceEpoch}',
      validFrom: DateTime.now(),
      validTo: DateTime.now().add(const Duration(days: 365)),
    );
  }

  @override
  Future<SriBackendResponse> submitInvoice(Map<String, dynamic> payload) async {
    final comprobante = _asMap(payload['comprobante']);
    final claveAcceso = comprobante['claveAcceso']?.toString() ?? '';
    final xml = payload['xmlPreview']?.toString() ?? '';
    if (claveAcceso.isEmpty || xml.isEmpty) {
      return SriBackendResponse(
        success: false,
        estado: EstadoComprobanteSri.pendienteReintento,
        requestId: 'mock-${DateTime.now().millisecondsSinceEpoch}',
        message: 'Mock SRI: falta XML o clave de acceso para firmar.',
        retryable: false,
        payload: payload,
      );
    }

    if (xml.contains('FORZAR_DEVUELTA')) {
      return SriBackendResponse(
        success: false,
        estado: EstadoComprobanteSri.devuelto,
        requestId: 'mock-${DateTime.now().millisecondsSinceEpoch}',
        message: 'Mock SRI: comprobante devuelto por validación simulada.',
        retryable: false,
        payload: payload,
      );
    }

    final signedHash = sha256
        .convert(utf8.encode('$xml|mock-xades'))
        .toString();
    final now = DateTime.now();
    return SriBackendResponse(
      success: true,
      estado: EstadoComprobanteSri.autorizado,
      requestId: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      numeroAutorizacion: claveAcceso,
      fechaAutorizacion: now,
      xmlFirmadoHash: signedHash,
      message:
          'Mock SRI: XML firmado XAdES-BES, recibido y autorizado en ambiente de pruebas simulado.',
      payload: payload,
    );
  }

  @override
  Future<SriBackendResponse> queryStatus({
    required String restaurantId,
    required String comprobanteId,
    required String claveAcceso,
    Uri? endpoint,
  }) async {
    return SriBackendResponse(
      success: true,
      estado: claveAcceso.isEmpty
          ? EstadoComprobanteSri.pendienteReintento
          : EstadoComprobanteSri.autorizado,
      requestId: 'mock-status-$comprobanteId',
      numeroAutorizacion: claveAcceso.isEmpty ? null : claveAcceso,
      fechaAutorizacion: claveAcceso.isEmpty ? null : DateTime.now(),
      message: claveAcceso.isEmpty
          ? 'Consulta mock: no hay clave de acceso para autorizar.'
          : 'Consulta mock: comprobante autorizado.',
    );
  }

  @override
  Future<SriBackendResponse> sendEmail({
    required String restaurantId,
    required String comprobanteId,
    required String email,
    String? ridePdfBase64,
    Uri? endpoint,
  }) async {
    final validEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    return SriBackendResponse(
      success: validEmail,
      estado: validEmail
          ? EstadoComprobanteSri.autorizado
          : EstadoComprobanteSri.pendienteReintento,
      requestId: 'mock-email-$comprobanteId',
      message: validEmail
          ? 'Mock SMTP: XML autorizado y RIDE enviados a $email.'
          : 'Mock SMTP: correo inválido.',
      retryable: !validEmail,
    );
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return const {};
  }
}

class SriBackendHttpClient implements SriBackendClient {
  SriBackendHttpClient({
    http.Client? httpClient,
    SriBackendClient? fallbackClient,
    this.timeout = const Duration(seconds: 30),
  }) : _httpClient = httpClient ?? http.Client(),
       _fallbackClient = fallbackClient ?? const SriBackendMockClient();

  final http.Client _httpClient;
  final SriBackendClient _fallbackClient;
  final Duration timeout;

  @override
  Future<SriCertificateUploadResult> uploadCertificate({
    required String restaurantId,
    required Uint8List p12Bytes,
    required String password,
    String? fileName,
    Uri? endpoint,
  }) async {
    final target =
        endpoint ??
        Uri.parse(
          '${AppConstants.sriBridgeBaseUrl}${AppConstants.sriBridgeCertificatePath}',
        );
    if (_shouldUseFallback(target)) {
      return _fallbackClient.uploadCertificate(
        restaurantId: restaurantId,
        p12Bytes: p12Bytes,
        password: password,
        fileName: fileName,
        endpoint: endpoint,
      );
    }

    final request = http.MultipartRequest('POST', target)
      ..fields['restaurantId'] = restaurantId
      ..fields['password'] = password
      ..files.add(
        http.MultipartFile.fromBytes(
          'certificate',
          p12Bytes,
          filename: fileName ?? 'certificado.p12',
        ),
      );

    final streamed = await request.send().timeout(timeout);
    final response = await http.Response.fromStream(streamed);
    final json = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        (json['message'] ??
                json['mensaje'] ??
                'El backend rechazó el certificado.')
            .toString(),
      );
    }
    return SriCertificateUploadResult.fromJson(json);
  }

  @override
  Future<SriBackendResponse> submitInvoice(Map<String, dynamic> payload) async {
    final endpoint =
        Uri.tryParse(payload['endpoint']?.toString() ?? '') ??
        Uri.parse(
          '${AppConstants.sriBridgeBaseUrl}${AppConstants.sriBridgeInvoicePath}',
        );
    if (_shouldUseFallback(endpoint)) {
      return _fallbackClient.submitInvoice(payload);
    }
    return _postJson(endpoint, payload);
  }

  @override
  Future<SriBackendResponse> queryStatus({
    required String restaurantId,
    required String comprobanteId,
    required String claveAcceso,
    Uri? endpoint,
  }) async {
    final target =
        endpoint ??
        Uri.parse(
          '${AppConstants.sriBridgeBaseUrl}${AppConstants.sriBridgeStatusPath}',
        );
    if (_shouldUseFallback(target)) {
      return _fallbackClient.queryStatus(
        restaurantId: restaurantId,
        comprobanteId: comprobanteId,
        claveAcceso: claveAcceso,
        endpoint: endpoint,
      );
    }
    return _postJson(target, {
      'restaurantId': restaurantId,
      'comprobanteId': comprobanteId,
      'claveAcceso': claveAcceso,
    });
  }

  @override
  Future<SriBackendResponse> sendEmail({
    required String restaurantId,
    required String comprobanteId,
    required String email,
    String? ridePdfBase64,
    Uri? endpoint,
  }) async {
    final target =
        endpoint ??
        Uri.parse(
          '${AppConstants.sriBridgeBaseUrl}${AppConstants.sriBridgeEmailPath}',
        );
    if (_shouldUseFallback(target)) {
      return _fallbackClient.sendEmail(
        restaurantId: restaurantId,
        comprobanteId: comprobanteId,
        email: email,
        ridePdfBase64: ridePdfBase64,
        endpoint: endpoint,
      );
    }
    return _postJson(target, {
      'restaurantId': restaurantId,
      'comprobanteId': comprobanteId,
      'email': email,
      if (ridePdfBase64 != null) 'ridePdfBase64': ridePdfBase64,
    });
  }

  Future<SriBackendResponse> _postJson(
    Uri endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _httpClient
          .post(
            endpoint,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
      return SriBackendResponse.fromJson(
        _decodeJson(response.body),
        httpStatus: response.statusCode,
      );
    } on TimeoutException {
      return SriBackendResponse(
        success: false,
        estado: EstadoComprobanteSri.pendienteReintento,
        message: 'Tiempo de espera agotado al contactar el backend SRI.',
        retryable: true,
      );
    } on Exception catch (error) {
      return SriBackendResponse(
        success: false,
        estado: EstadoComprobanteSri.pendienteReintento,
        message: 'No se pudo contactar el backend SRI: $error',
        retryable: true,
      );
    }
  }

  Map<String, dynamic> _decodeJson(String body) {
    if (body.trim().isEmpty) return const {};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.map((k, v) => MapEntry(k.toString(), v));
    return {'message': decoded.toString()};
  }

  bool _shouldUseFallback(Uri endpoint) {
    final host = endpoint.host.toLowerCase();
    return endpoint.scheme == 'mock' ||
        host.isEmpty ||
        host == 'api.tu-dominio.com' ||
        host == 'tu-dominio.com';
  }
}

EstadoComprobanteSri _parseEstado(Object? value, {required bool success}) {
  final raw = value?.toString().toLowerCase().trim() ?? '';
  if (raw.isEmpty) {
    return success
        ? EstadoComprobanteSri.autorizado
        : EstadoComprobanteSri.error;
  }
  final normalized = raw
      .replaceAll(' ', '_')
      .replaceAll('-', '_')
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
  if (normalized == 'recibida') return EstadoComprobanteSri.recibido;
  if (normalized == 'autorizada') return EstadoComprobanteSri.autorizado;
  if (normalized == 'no_autorizada') return EstadoComprobanteSri.noAutorizado;
  return EstadoComprobanteSri.fromString(normalized);
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

bool? _readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase().trim();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return null;
}

bool _isRetryableStatus(int? httpStatus) {
  if (httpStatus == null) return false;
  return httpStatus == 408 || httpStatus == 429 || httpStatus >= 500;
}

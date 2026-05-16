import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/caja/data/models/venta_detalle_model.dart';
import 'package:restaurant_app/features/caja/data/models/venta_model.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta.dart';
import 'package:restaurant_app/services/facturacion/fiscal_config_service.dart';
import 'package:restaurant_app/services/facturacion/sri_backend_client.dart';
import 'package:restaurant_app/services/facturacion/sri_ride_pdf_service.dart';
import 'package:restaurant_app/services/facturacion/sri_secuencial_service.dart';
import 'package:restaurant_app/services/facturacion/sri_xml_builder.dart';
import 'package:uuid/uuid.dart';

/// Estado de la configuración necesaria para facturación electrónica con SRI.
class SriConnectionStatus {
  final bool isConfigured;
  final Uri endpoint;
  final String environment;
  final String environmentCode;
  final List<String> missingFields;
  final String message;

  const SriConnectionStatus({
    required this.isConfigured,
    required this.endpoint,
    required this.environment,
    required this.environmentCode,
    required this.missingFields,
    required this.message,
  });

  bool get canPrepareInvoice => isConfigured && missingFields.isEmpty;
}

/// Borrador local de factura electrónica preparado para ser enviado por backend.
class SriInvoiceDraft {
  final SriConnectionStatus status;
  final Map<String, dynamic> payload;
  final String reference;
  final String accessKey;
  final String secuencial;
  final String xmlPreview;
  final String xmlHash;
  final Map<String, String> requestHeaders;
  final bool transmissionCommented;
  final List<String> nextSteps;

  const SriInvoiceDraft({
    required this.status,
    required this.payload,
    required this.reference,
    required this.accessKey,
    required this.secuencial,
    required this.xmlPreview,
    required this.xmlHash,
    required this.requestHeaders,
    required this.transmissionCommented,
    required this.nextSteps,
  });
}

/// Contrato para preparar la integración futura con SRI.
abstract class SriService {
  Future<SriConnectionStatus> getConnectionStatus();
  Future<SriCertificateInfo> uploadCertificate({
    required Uint8List p12Bytes,
    required String password,
    String? fileName,
  });
  Future<SriInvoiceDraft> buildInvoiceDraft(Venta venta);
  Future<Map<String, dynamic>> buildBridgeRequest(Venta venta);
  Future<Map<String, dynamic>> sendInvoiceWhenEnabled(SriInvoiceDraft draft);
  Future<Map<String, dynamic>> submitInvoiceDraft({
    required Venta venta,
    required SriInvoiceDraft draft,
  });
  Future<Map<String, dynamic>> queryStatusForVenta(Venta venta);
  Future<Map<String, dynamic>> sendAuthorizedEmail({
    required Venta venta,
    String? email,
  });
  Future<Uint8List> buildRidePdf(Venta venta, {bool mock = false});
  Future<int> processPendingQueue({int limit = 20});
}

/// Fachada local para SRI.
///
/// Flutter genera XML preliminar, clave de acceso, hashes y cola local. Firma
/// XAdES-BES, custodia de .p12, SOAP y correo quedan detrás de [SriBackendClient].
class SriServiceImpl implements SriService {
  SriServiceImpl({
    SriSecuencialService? secuencialService,
    FiscalConfigService? fiscalConfigService,
    SriBackendClient? backendClient,
    SriXmlBuilder? xmlBuilder,
    SriRidePdfService? ridePdfService,
    DatabaseHelper? dbHelper,
  }) : _secuencialService = secuencialService ?? SriSecuencialService(),
       _fiscalConfigService = fiscalConfigService ?? FiscalConfigService(),
       _backendClient = backendClient ?? SriBackendHttpClient(),
       _xmlBuilder = xmlBuilder ?? const SriXmlBuilder(),
       _ridePdfService = ridePdfService ?? const SriRidePdfService(),
       _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final SriSecuencialService _secuencialService;
  final FiscalConfigService _fiscalConfigService;
  final SriBackendClient _backendClient;
  final SriXmlBuilder _xmlBuilder;
  final SriRidePdfService _ridePdfService;
  final DatabaseHelper _dbHelper;
  static const _uuid = Uuid();

  @override
  Future<SriConnectionStatus> getConnectionStatus() async {
    final config = await _fiscalConfigService.load();
    return _buildConnectionStatus(config);
  }

  @override
  Future<SriCertificateInfo> uploadCertificate({
    required Uint8List p12Bytes,
    required String password,
    String? fileName,
  }) async {
    final config = await _fiscalConfigService.load();
    final result = await _backendClient.uploadCertificate(
      restaurantId: config.restaurantId,
      p12Bytes: p12Bytes,
      password: password,
      fileName: fileName,
      endpoint: _resolveEndpoint(config, AppConstants.sriBridgeCertificatePath),
    );
    if (result.certificateIdBackend.trim().isEmpty) {
      throw StateError('El backend no devolvió referencia de certificado.');
    }
    final info = SriCertificateInfo(
      restaurantId: config.restaurantId,
      certificateIdBackend: result.certificateIdBackend,
      subject: result.subject,
      issuer: result.issuer,
      serial: result.serial,
      validFrom: result.validFrom,
      validTo: result.validTo,
      fingerprintSha256: result.fingerprintSha256,
      encryptedAt: DateTime.now(),
      status: 'cargado',
    );
    await _fiscalConfigService.saveCertificateInfo(info);
    return info;
  }

  Future<SriConnectionStatus> _buildConnectionStatus(
    FiscalConfig config,
  ) async {
    final certificate = await _fiscalConfigService.loadCertificateInfo(
      restaurantId: config.restaurantId,
    );

    final missing = <String>[];
    if (config.ruc.isEmpty) missing.add('RUC');
    if (config.razonSocial.isEmpty) missing.add('Razón social');
    if (config.direccion.isEmpty) missing.add('Dirección matriz');
    if (config.establecimiento.isEmpty) missing.add('Establecimiento');
    if (config.puntoEmision.isEmpty) missing.add('Punto de emisión');
    if (certificate == null || !certificate.isLoaded) {
      missing.add('Certificado digital .p12');
    } else if (certificate.isExpired) {
      missing.add('Certificado digital vigente');
    }

    final environment = config.ambiente.isNotEmpty
        ? config.ambiente
        : AppConstants.sriEnvironment;
    final endpoint = _resolveEndpoint(
      config,
      AppConstants.sriBridgeInvoicePath,
    );
    final isConfigured = missing.isEmpty;

    return SriConnectionStatus(
      isConfigured: isConfigured,
      endpoint: endpoint,
      environment: environment,
      environmentCode: _resolveEnvironmentCode(environment),
      missingFields: missing,
      message: isConfigured
          ? 'Configuración SRI lista para enviar al backend puente.'
          : 'Faltan datos SRI: ${missing.join(', ')}. La factura quedará preparada localmente para homologación.',
    );
  }

  @override
  Future<SriInvoiceDraft> buildInvoiceDraft(Venta venta) async {
    final config = await _fiscalConfigService.load(
      restaurantId: venta.restaurantId,
    );
    final status = await _buildConnectionStatus(config);
    final reference = _buildReference(venta);
    final establecimiento = _xmlBuilder.normalizeDigits(
      config.establecimiento,
      3,
      fallback: '001',
    );
    final puntoEmision = _xmlBuilder.normalizeDigits(
      config.puntoEmision,
      3,
      fallback: '001',
    );
    final secuencial = status.canPrepareInvoice
        ? await _secuencialService.siguiente(
            estab: establecimiento,
            puntoEmision: puntoEmision,
            restaurantId: venta.restaurantId,
          )
        : await _peekNextSecuencial(
            estab: establecimiento,
            puntoEmision: puntoEmision,
            restaurantId: venta.restaurantId,
          );
    final accessKey = _xmlBuilder.buildAccessKey(
      venta: venta,
      config: config,
      environmentCode: status.environmentCode,
      secuencial: secuencial,
    );
    final xmlPreview = _xmlBuilder.buildInvoiceXml(
      venta: venta,
      config: config,
      accessKey: accessKey,
      reference: reference,
      environmentCode: status.environmentCode,
      secuencial: secuencial,
    );
    final xmlHash = sha256.convert(utf8.encode(xmlPreview)).toString();

    final payload = <String, dynamic>{
      'restaurantId': venta.restaurantId,
      'ambiente': status.environment,
      'codigoAmbiente': status.environmentCode,
      'endpoint': status.endpoint.toString(),
      'emisor': {
        'ruc': config.ruc,
        'razonSocial': config.razonSocial.isNotEmpty
            ? config.razonSocial
            : AppConstants.appFullName,
        'nombreComercial': config.nombreComercial,
        'establecimiento': establecimiento,
        'puntoEmision': puntoEmision,
        'direccionMatriz': config.direccion,
        'obligadoContabilidad': config.obligadoContabilidad,
        'regimen': config.regimen,
        'contribuyenteEspecial': config.contribuyenteEspecial,
      },
      'cliente': {
        'nombre': venta.clienteNombre,
        'email': venta.clienteEmail,
        'identificacion': venta.clienteIdentificacion,
      },
      'comprobante': {
        'tipo': venta.tipoComprobante.value,
        'referencia': reference,
        'claveAcceso': accessKey,
        'secuencial': secuencial,
        'pedidoId': venta.pedidoId,
        'ventaId': venta.id,
        'fechaEmision': venta.createdAt.toIso8601String(),
        'moneda': AppConstants.currencyCode,
        'metodoPago': venta.metodoPago.value,
      },
      'totales': {
        'subtotal': venta.subtotal,
        'impuestos': venta.impuestos,
        'total': venta.total,
      },
      'items': venta.detalles
          .map(
            (detalle) => {
              'productoId': detalle.productoId,
              'descripcion': detalle.varianteNombre != null
                  ? '${detalle.productoNombre ?? 'Producto'} (${detalle.varianteNombre})'
                  : (detalle.productoNombre ?? 'Producto'),
              'cantidad': detalle.cantidad,
              'precioUnitario': detalle.precioUnitario,
              'subtotal': detalle.subtotal,
            },
          )
          .toList(),
      'xmlPreview': xmlPreview,
      'xmlHash': xmlHash,
      'requiereBackend': true,
    };

    return SriInvoiceDraft(
      status: status,
      payload: payload,
      reference: reference,
      accessKey: accessKey,
      secuencial: secuencial,
      xmlPreview: xmlPreview,
      xmlHash: xmlHash,
      requestHeaders: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      transmissionCommented: false,
      nextSteps: const [
        'Configurar backend puente para firma XAdES-BES con certificado .p12 cifrado.',
        'Conectar SOAP SRI de recepción y autorización por ambiente.',
        'Mapear respuestas reales del SRI a sri_comprobantes y sri_attempts.',
      ],
    );
  }

  @override
  Future<Map<String, dynamic>> buildBridgeRequest(Venta venta) async {
    final draft = await buildInvoiceDraft(venta);
    return {
      'endpoint': draft.status.endpoint.toString(),
      'headers': draft.requestHeaders,
      'body': draft.payload,
      'mock': _backendClient is SriBackendMockClient,
      'nextSteps': draft.nextSteps,
    };
  }

  @override
  Future<Map<String, dynamic>> sendInvoiceWhenEnabled(
    SriInvoiceDraft draft,
  ) async {
    final response = await _backendClient.submitInvoice(draft.payload);
    return response.toJson();
  }

  @override
  Future<Map<String, dynamic>> submitInvoiceDraft({
    required Venta venta,
    required SriInvoiceDraft draft,
  }) async {
    final comprobanteId = venta.sriComprobanteId;
    if (comprobanteId == null || comprobanteId.isEmpty) {
      return const {
        'success': false,
        'message': 'La venta no tiene comprobante SRI asociado.',
      };
    }

    final response = draft.status.canPrepareInvoice
        ? await _backendClient.submitInvoice(draft.payload)
        : SriBackendResponse(
            success: false,
            estado: EstadoComprobanteSri.noConfigurado,
            message: draft.status.message,
          );

    await _persistBackendResponse(
      venta: venta,
      response: response,
      operation: 'envio',
      payloadHash: draft.xmlHash,
    );

    if (response.estado == EstadoComprobanteSri.autorizado &&
        _isValidEmail(venta.clienteEmail)) {
      await sendAuthorizedEmail(venta: venta);
    }

    return response.toJson();
  }

  @override
  Future<Map<String, dynamic>> queryStatusForVenta(Venta venta) async {
    final comprobanteId = venta.sriComprobanteId;
    final claveAcceso = venta.sriClaveAcceso;
    if (comprobanteId == null || comprobanteId.isEmpty || claveAcceso == null) {
      return const {
        'success': false,
        'message': 'No hay clave de acceso o comprobante SRI para consultar.',
      };
    }

    final config = await _fiscalConfigService.load(
      restaurantId: venta.restaurantId,
    );
    final response = await _backendClient.queryStatus(
      restaurantId: venta.restaurantId,
      comprobanteId: comprobanteId,
      claveAcceso: claveAcceso,
      endpoint: _resolveEndpoint(config, AppConstants.sriBridgeStatusPath),
    );
    await _persistBackendResponse(
      venta: venta,
      response: response,
      operation: 'consulta_estado',
      payloadHash: venta.sriXmlHash,
    );
    return response.toJson();
  }

  @override
  Future<Map<String, dynamic>> sendAuthorizedEmail({
    required Venta venta,
    String? email,
  }) async {
    final comprobanteId = venta.sriComprobanteId;
    final targetEmail = (email ?? venta.clienteEmail ?? '').trim();
    if (comprobanteId == null || comprobanteId.isEmpty) {
      return const {'success': false, 'message': 'No hay comprobante SRI.'};
    }
    if (!_isValidEmail(targetEmail)) {
      await _recordEmailDelivery(
        restaurantId: venta.restaurantId,
        comprobanteId: comprobanteId,
        email: targetEmail,
        success: false,
        message: 'Correo del cliente inválido o vacío.',
        retryable: false,
      );
      return const {
        'success': false,
        'message': 'Correo del cliente inválido o vacío.',
      };
    }

    final config = await _fiscalConfigService.load(
      restaurantId: venta.restaurantId,
    );
    final ridePdf = await _ridePdfService.buildFacturaRide(
      venta: venta,
      config: config,
      numeroAutorizacion: venta.sriNumeroAutorizacion,
      fechaAutorizacion: venta.sriFechaAutorizacion,
      mock: _backendClient is SriBackendMockClient,
    );
    final response = await _backendClient.sendEmail(
      restaurantId: venta.restaurantId,
      comprobanteId: comprobanteId,
      email: targetEmail,
      ridePdfBase64: base64Encode(ridePdf),
      endpoint: _resolveEndpoint(config, AppConstants.sriBridgeEmailPath),
    );
    await _recordEmailDelivery(
      restaurantId: venta.restaurantId,
      comprobanteId: comprobanteId,
      email: targetEmail,
      success: response.success,
      message: response.message,
      retryable: response.retryable,
    );
    return response.toJson();
  }

  @override
  Future<Uint8List> buildRidePdf(Venta venta, {bool mock = false}) async {
    final config = await _fiscalConfigService.load(
      restaurantId: venta.restaurantId,
    );
    return _ridePdfService.buildFacturaRide(
      venta: venta,
      config: config,
      numeroAutorizacion: venta.sriNumeroAutorizacion,
      fechaAutorizacion: venta.sriFechaAutorizacion,
      mock: mock,
    );
  }

  @override
  Future<int> processPendingQueue({int limit = 20}) async {
    final config = await _fiscalConfigService.load();
    final now = DateTime.now().toIso8601String();
    final rows = await _dbHelper.rawQuery(
      '''
      SELECT c.id, c.venta_id, c.estado, c.clave_acceso, c.secuencial,
             c.xml_local_hash,
             COALESCE(MAX(a.retry_count), 0) AS retry_count
      FROM sri_comprobantes c
      LEFT JOIN sri_attempts a
        ON a.comprobante_id = c.id AND a.restaurant_id = c.restaurant_id
      WHERE c.restaurant_id = ?
        AND c.estado IN (?, ?, ?, ?, ?)
        AND EXISTS (
          SELECT 1 FROM sri_attempts due
          WHERE due.comprobante_id = c.id
            AND due.restaurant_id = c.restaurant_id
            AND due.next_retry_at IS NOT NULL
            AND due.next_retry_at <= ?
            AND due.retry_count < 5
        )
      GROUP BY c.id
      ORDER BY MIN(a.next_retry_at) ASC
      LIMIT ?
      ''',
      [
        config.restaurantId,
        EstadoComprobanteSri.pendienteEnvio.value,
        EstadoComprobanteSri.pendienteReintento.value,
        EstadoComprobanteSri.enviado.value,
        EstadoComprobanteSri.recibido.value,
        EstadoComprobanteSri.error.value,
        now,
        limit,
      ],
    );

    var processed = 0;
    for (final row in rows) {
      final ventaId = row['venta_id'] as String?;
      if (ventaId == null || ventaId.isEmpty) continue;
      final venta = await _loadVenta(ventaId, config.restaurantId);
      if (venta == null) continue;
      final estado = EstadoComprobanteSri.fromString(row['estado'] as String);
      if (_isFinalState(estado)) continue;

      if (estado == EstadoComprobanteSri.recibido ||
          estado == EstadoComprobanteSri.enviado) {
        await queryStatusForVenta(venta);
      } else {
        final draft = await _buildDraftFromPersisted(
          venta: venta,
          config: config,
          comprobanteRow: row,
        );
        await submitInvoiceDraft(venta: venta, draft: draft);
      }
      processed++;
    }
    return processed;
  }

  Future<void> _persistBackendResponse({
    required Venta venta,
    required SriBackendResponse response,
    required String operation,
    String? payloadHash,
  }) async {
    final comprobanteId = venta.sriComprobanteId;
    if (comprobanteId == null || comprobanteId.isEmpty) return;

    await _updateSriState(venta: venta, response: response);
    await _recordAttempt(
      restaurantId: venta.restaurantId,
      comprobanteId: comprobanteId,
      operation: operation,
      response: response,
      payloadHash: payloadHash,
    );
  }

  Future<void> _updateSriState({
    required Venta venta,
    required SriBackendResponse response,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _dbHelper.update(
      'sri_comprobantes',
      {
        'estado': response.estado.value,
        'xml_firmado_hash': response.xmlFirmadoHash,
        'numero_autorizacion': response.numeroAutorizacion,
        'fecha_autorizacion': response.fechaAutorizacion?.toIso8601String(),
        'mensaje': response.message,
        'ride_path': response.ridePath,
        'updated_at': now,
      },
      where: 'id = ? AND restaurant_id = ?',
      whereArgs: [venta.sriComprobanteId, venta.restaurantId],
    );
    await _dbHelper.update(
      'ventas',
      {
        'sri_estado': response.estado.value,
        'sri_mensaje': response.message,
        'sri_numero_autorizacion': response.numeroAutorizacion,
        'sri_fecha_autorizacion': response.fechaAutorizacion?.toIso8601String(),
        'sri_ride_path': response.ridePath,
      },
      where: 'id = ? AND restaurant_id = ?',
      whereArgs: [venta.id, venta.restaurantId],
    );
  }

  Future<void> _recordAttempt({
    required String restaurantId,
    required String comprobanteId,
    required String operation,
    required SriBackendResponse response,
    String? payloadHash,
  }) async {
    final retryCount = await _nextRetryCount(
      restaurantId: restaurantId,
      comprobanteId: comprobanteId,
    );
    final retryable =
        response.retryable ||
        response.estado == EstadoComprobanteSri.pendienteReintento;
    await _dbHelper.insert('sri_attempts', {
      'id': _uuid.v4(),
      'restaurant_id': restaurantId,
      'comprobante_id': comprobanteId,
      'tipo_operacion': operation,
      'request_id': response.requestId,
      'estado': response.estado.value,
      'http_status': response.httpStatus,
      'sri_estado': response.estado.value,
      'mensaje': response.message,
      'retry_count': retryCount,
      'next_retry_at': retryable && !_isFinalState(response.estado)
          ? _retryAt(retryCount).toIso8601String()
          : null,
      'payload_hash': payloadHash,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _recordEmailDelivery({
    required String restaurantId,
    required String comprobanteId,
    required String email,
    required bool success,
    required String message,
    required bool retryable,
  }) async {
    await _dbHelper.insert('sri_email_deliveries', {
      'id': _uuid.v4(),
      'restaurant_id': restaurantId,
      'comprobante_id': comprobanteId,
      'email': email,
      'estado': success
          ? 'enviado'
          : retryable
          ? 'pendiente_reintento'
          : 'error',
      'mensaje': message,
      'sent_at': success ? DateTime.now().toIso8601String() : null,
      'retry_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> _nextRetryCount({
    required String restaurantId,
    required String comprobanteId,
  }) async {
    final rows = await _dbHelper.rawQuery(
      '''
      SELECT COALESCE(MAX(retry_count), -1) + 1 AS next_retry_count
      FROM sri_attempts
      WHERE restaurant_id = ? AND comprobante_id = ?
      ''',
      [restaurantId, comprobanteId],
    );
    return (rows.first['next_retry_count'] as num?)?.toInt() ?? 0;
  }

  DateTime _retryAt(int retryCount) {
    final bounded = retryCount.clamp(0, 5).toInt();
    final minutes = 5 * (1 << bounded);
    return DateTime.now().add(Duration(minutes: minutes));
  }

  Future<Venta?> _loadVenta(String ventaId, String restaurantId) async {
    final rows = await _dbHelper.query(
      'ventas',
      where: 'id = ? AND restaurant_id = ?',
      whereArgs: [ventaId, restaurantId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final details = await _dbHelper.query(
      'venta_detalles',
      where: 'venta_id = ?',
      whereArgs: [ventaId],
    );
    return VentaModel.fromMap(
      rows.first,
      detalles: details.map((row) => VentaDetalleModel.fromMap(row)).toList(),
    );
  }

  Future<SriInvoiceDraft> _buildDraftFromPersisted({
    required Venta venta,
    required FiscalConfig config,
    required Map<String, dynamic> comprobanteRow,
  }) async {
    final status = await _buildConnectionStatus(config);
    final secuencial = (comprobanteRow['secuencial'] as String?) ?? '000000001';
    final accessKey =
        venta.sriClaveAcceso ??
        (comprobanteRow['clave_acceso'] as String?) ??
        _xmlBuilder.buildAccessKey(
          venta: venta,
          config: config,
          environmentCode: status.environmentCode,
          secuencial: secuencial,
        );
    final reference = _buildReference(venta);
    final xmlPreview = _xmlBuilder.buildInvoiceXml(
      venta: venta,
      config: config,
      accessKey: accessKey,
      reference: reference,
      environmentCode: status.environmentCode,
      secuencial: secuencial,
    );
    final xmlHash = sha256.convert(utf8.encode(xmlPreview)).toString();
    final payload = _buildPayload(
      venta: venta,
      config: config,
      status: status,
      reference: reference,
      accessKey: accessKey,
      secuencial: secuencial,
      xmlPreview: xmlPreview,
      xmlHash: xmlHash,
    );
    return SriInvoiceDraft(
      status: status,
      payload: payload,
      reference: reference,
      accessKey: accessKey,
      secuencial: secuencial,
      xmlPreview: xmlPreview,
      xmlHash: xmlHash,
      requestHeaders: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      transmissionCommented: false,
      nextSteps: const [],
    );
  }

  Map<String, dynamic> _buildPayload({
    required Venta venta,
    required FiscalConfig config,
    required SriConnectionStatus status,
    required String reference,
    required String accessKey,
    required String secuencial,
    required String xmlPreview,
    required String xmlHash,
  }) {
    final establecimiento = _xmlBuilder.normalizeDigits(
      config.establecimiento,
      3,
      fallback: '001',
    );
    final puntoEmision = _xmlBuilder.normalizeDigits(
      config.puntoEmision,
      3,
      fallback: '001',
    );
    return <String, dynamic>{
      'restaurantId': venta.restaurantId,
      'ambiente': status.environment,
      'codigoAmbiente': status.environmentCode,
      'endpoint': status.endpoint.toString(),
      'emisor': {
        'ruc': config.ruc,
        'razonSocial': config.razonSocial.isNotEmpty
            ? config.razonSocial
            : AppConstants.appFullName,
        'nombreComercial': config.nombreComercial,
        'establecimiento': establecimiento,
        'puntoEmision': puntoEmision,
        'direccionMatriz': config.direccion,
        'obligadoContabilidad': config.obligadoContabilidad,
        'regimen': config.regimen,
        'contribuyenteEspecial': config.contribuyenteEspecial,
      },
      'cliente': {
        'nombre': venta.clienteNombre,
        'email': venta.clienteEmail,
        'identificacion': venta.clienteIdentificacion,
      },
      'comprobante': {
        'tipo': venta.tipoComprobante.value,
        'referencia': reference,
        'claveAcceso': accessKey,
        'secuencial': secuencial,
        'pedidoId': venta.pedidoId,
        'ventaId': venta.id,
        'fechaEmision': venta.createdAt.toIso8601String(),
        'moneda': AppConstants.currencyCode,
        'metodoPago': venta.metodoPago.value,
      },
      'totales': {
        'subtotal': venta.subtotal,
        'impuestos': venta.impuestos,
        'total': venta.total,
      },
      'items': venta.detalles
          .map(
            (detalle) => {
              'productoId': detalle.productoId,
              'descripcion': detalle.varianteNombre != null
                  ? '${detalle.productoNombre ?? 'Producto'} (${detalle.varianteNombre})'
                  : (detalle.productoNombre ?? 'Producto'),
              'cantidad': detalle.cantidad,
              'precioUnitario': detalle.precioUnitario,
              'subtotal': detalle.subtotal,
            },
          )
          .toList(),
      'xmlPreview': xmlPreview,
      'xmlHash': xmlHash,
      'requiereBackend': true,
    };
  }

  bool _isFinalState(EstadoComprobanteSri estado) {
    return estado == EstadoComprobanteSri.autorizado ||
        estado == EstadoComprobanteSri.noAutorizado ||
        estado == EstadoComprobanteSri.rechazado ||
        estado == EstadoComprobanteSri.devuelto ||
        estado == EstadoComprobanteSri.anulado;
  }

  bool _isValidEmail(String? value) {
    final email = value?.trim() ?? '';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<String> _peekNextSecuencial({
    required String estab,
    required String puntoEmision,
    required String restaurantId,
  }) async {
    final ultimo = await _secuencialService.ultimo(
      estab: estab,
      puntoEmision: puntoEmision,
      restaurantId: restaurantId,
    );
    return (ultimo + 1).toString().padLeft(9, '0');
  }

  Uri _resolveEndpoint(FiscalConfig config, String path) {
    final base = config.backendBaseUri.toString().replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    return Uri.parse('$base$path');
  }

  String _buildReference(Venta venta) {
    final year = venta.createdAt.year.toString();
    final month = venta.createdAt.month.toString().padLeft(2, '0');
    final day = venta.createdAt.day.toString().padLeft(2, '0');
    final compactId = venta.id.replaceAll('-', '').toUpperCase();
    final suffix = compactId.length >= 8
        ? compactId.substring(0, 8)
        : compactId;
    return 'FAC-$year$month$day-$suffix';
  }

  String _resolveEnvironmentCode(String environment) {
    final normalized = environment.toLowerCase();
    return normalized.contains('prod') ? '2' : '1';
  }
}

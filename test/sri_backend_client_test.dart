import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/services/facturacion/sri_backend_client.dart';

void main() {
  group('SriBackendMockClient', () {
    const client = SriBackendMockClient();

    test('carga certificado y devuelve solo metadatos', () async {
      final result = await client.uploadCertificate(
        restaurantId: 'tenant_a',
        p12Bytes: Uint8List.fromList([1, 2, 3, 4]),
        password: 'secreto',
      );

      expect(result.certificateIdBackend, 'mock-cert-tenant_a');
      expect(result.fingerprintSha256, isNotEmpty);
      expect(result.validTo, isNotNull);
    });

    test('autoriza una factura mock con hash firmado', () async {
      final response = await client.submitInvoice({
        'restaurantId': 'tenant_a',
        'xmlPreview': '<factura>demo</factura>',
        'comprobante': {
          'claveAcceso': '1234567890123456789012345678901234567890123456789',
        },
      });

      expect(response.success, isTrue);
      expect(response.estado, EstadoComprobanteSri.autorizado);
      expect(response.numeroAutorizacion, hasLength(49));
      expect(response.xmlFirmadoHash, isNotEmpty);
    });

    test('marca correo invalido como reintentable controlado', () async {
      final response = await client.sendEmail(
        restaurantId: 'tenant_a',
        comprobanteId: 'comp_1',
        email: 'sin-correo',
      );

      expect(response.success, isFalse);
      expect(response.estado, EstadoComprobanteSri.pendienteReintento);
      expect(response.retryable, isTrue);
    });
  });

  group('SriBackendResponse', () {
    test('parsea respuestas JSON estilo backend puente', () {
      final response = SriBackendResponse.fromJson(
        jsonDecode('''
        {
          "success": true,
          "estado": "AUTORIZADA",
          "message": "Autorizada por SRI",
          "request_id": "req-1",
          "authorizationNumber": "999",
          "authorizationDate": "2026-05-01T12:00:00.000",
          "signedXmlHash": "abc"
        }
        ''')
            as Map<String, dynamic>,
        httpStatus: 200,
      );

      expect(response.success, isTrue);
      expect(response.estado, EstadoComprobanteSri.autorizado);
      expect(response.requestId, 'req-1');
      expect(response.numeroAutorizacion, '999');
      expect(response.xmlFirmadoHash, 'abc');
    });
  });
}

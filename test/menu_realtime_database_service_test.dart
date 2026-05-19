import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:restaurant_app/features/menu/data/services/menu_realtime_database_service.dart';

void main() {
  group('MenuRealtimeDatabaseService payload sanitization', () {
    test('upsertProducto nunca envía data URI ni ruta local', () async {
      Map<String, dynamic>? sentBody;
      Uri? sentUri;
      var callCount = 0;

      final client = MockClient((request) async {
        callCount++;
        sentUri = request.url;
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      });

      final service = MenuRealtimeDatabaseService(httpClient: client);

      final ok = await service.upsertProducto(
        restaurantId: 'la_pena_001',
        productoId: 'prod_1',
        data: <String, dynamic>{
          'id': 'prod_1',
          'nombre': 'Coca Cola',
          'imagen_url': 'data:image/jpeg;base64,AAAABBBB',
          'drive_file_id': '1A2B3C',
          'drive_public_url':
              'https://drive.google.com/uc?export=view&id=1A2B3C',
          'imagen_local_cache_path': 'C:/tmp/cache.jpg',
        },
      );

      expect(ok, isTrue);
      expect(callCount, 1);
      expect(sentUri, isNotNull);
      expect(sentBody, isNotNull);
      expect(sentBody!['imagen_local_cache_path'], isNull);
      expect(sentBody!['drive_file_id'], '1A2B3C');
      expect(
        sentBody!['drive_public_url'],
        'https://drive.google.com/uc?export=view&id=1A2B3C',
      );
      expect(
        sentBody!['imagen_url'],
        'https://drive.google.com/uc?export=view&id=1A2B3C',
      );
    });

    test(
      'patchProducto omite request si payload queda vacío tras sanear',
      () async {
        var callCount = 0;

        final client = MockClient((request) async {
          callCount++;
          return http.Response('{}', 200);
        });

        final service = MenuRealtimeDatabaseService(httpClient: client);

        final ok = await service.patchProducto(
          restaurantId: 'la_pena_001',
          productoId: 'prod_2',
          data: <String, dynamic>{
            'imagen_url': 'data:image/png;base64,CCCCDDDD',
            'imagen_local_cache_path': 'C:/tmp/cache2.jpg',
          },
        );

        expect(ok, isTrue);
        expect(callCount, 0);
      },
    );

    test(
      'upsertProducto rechaza rutas locales/blob y drive_file_id inválido',
      () async {
        Map<String, dynamic>? sentBody;
        var callCount = 0;

        final client = MockClient((request) async {
          callCount++;
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        });

        final service = MenuRealtimeDatabaseService(httpClient: client);

        final ok = await service.upsertProducto(
          restaurantId: 'la_pena_001',
          productoId: 'prod_3',
          data: <String, dynamic>{
            'id': 'prod_3',
            'nombre': 'Pizza Local',
            'imagen_url': 'file:///tmp/foto.jpg',
            'drive_public_url': 'blob:https://example.com/1234',
            'drive_file_id': 'https://drive.google.com/file/d/ABC',
            'imagen_local_cache_path': r'C:\temp\foto.jpg',
          },
        );

        expect(ok, isTrue);
        expect(callCount, 1);
        expect(sentBody, isNotNull);
        expect(sentBody!['imagen_url'], isNull);
        expect(sentBody!['drive_public_url'], isNull);
        expect(sentBody!['drive_file_id'], isNull);
        expect(sentBody!['imagen_local_cache_path'], isNull);
      },
    );
  });
}

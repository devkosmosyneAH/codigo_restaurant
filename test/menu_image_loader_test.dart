import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/features/menu/presentation/widgets/menu_image_loader.dart';

void main() {
  group('buildDriveImageCandidates', () {
    test('returns public image candidates for a drive file id', () {
      final candidates = buildDriveImageCandidates('abc123_xyz');

      expect(
        candidates,
        contains('https://drive.google.com/thumbnail?id=abc123_xyz&sz=w1000'),
      );
      expect(
        candidates,
        contains('https://drive.google.com/uc?export=view&id=abc123_xyz'),
      );
    });

    test('returns an empty list for blank values', () {
      expect(buildDriveImageCandidates(null), isEmpty);
      expect(buildDriveImageCandidates('   '), isEmpty);
    });
  });
}

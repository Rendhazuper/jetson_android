import 'package:face_presensi/core/gallery/gallery_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> validJson() => {
        'formatVersion': 1,
        'model': {'id': 'sface-2021dec', 'sha256': 'abc123'},
        'preprocessing': {'version': 'aligncrop-clahe-v1'},
        'feature': {'dimensions': 128, 'dtype': 'float32'},
        'entries': [
          {'identity': 'A', 'offset': 0, 'count': 1},
        ],
        'embeddingsFile': 'embeddings.bin',
      };

  group('GalleryManifest', () {
    test('menerima gallery yang kompatibel', () {
      final manifest = GalleryManifest.fromJson(validJson());

      expect(
        manifest.incompatibility(
          expectedModelId: 'sface-2021dec',
          expectedModelSha256: 'abc123',
          expectedPreprocessingVersion: 'aligncrop-clahe-v1',
          expectedDimensions: 128,
        ),
        isNull,
      );
    });

    test('menolak gallery dengan preprocessing berbeda', () {
      final manifest = GalleryManifest.fromJson(validJson());

      expect(
        manifest.incompatibility(
          expectedModelId: 'sface-2021dec',
          expectedModelSha256: 'abc123',
          expectedPreprocessingVersion: 'versi-lain',
          expectedDimensions: 128,
        ),
        contains('preprocessingVersion'),
      );
    });

    test('menolak gallery dengan hash model berbeda', () {
      final manifest = GalleryManifest.fromJson(validJson());

      expect(
        manifest.incompatibility(
          expectedModelId: 'sface-2021dec',
          expectedModelSha256: 'hash-lain',
          expectedPreprocessingVersion: 'aligncrop-clahe-v1',
          expectedDimensions: 128,
        ),
        contains('hash model'),
      );
    });

    test('menolak manifest tanpa feature/model', () {
      expect(
        () => GalleryManifest.fromJson({'formatVersion': 1}),
        throwsFormatException,
      );
    });
  });
}

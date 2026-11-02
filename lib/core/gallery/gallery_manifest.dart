/// Metadata gallery hasil ekstraksi embedding dari tool Python.
///
/// Gallery adalah artefak versioned, bukan hasil training model. Embedding
/// hanya valid bila [modelId], [modelSha256], dan [preprocessingVersion]
/// cocok dengan runtime Android.
class GalleryManifest {
  const GalleryManifest({
    required this.formatVersion,
    required this.modelId,
    required this.modelSha256,
    required this.preprocessingVersion,
    required this.embeddingDimensions,
    required this.embeddingDtype,
    required this.entryCount,
    required this.embeddingsFile,
  });

  static const int supportedFormatVersion = 1;

  final int formatVersion;
  final String modelId;
  final String modelSha256;
  final String preprocessingVersion;
  final int embeddingDimensions;
  final String embeddingDtype;
  final int entryCount;
  final String embeddingsFile;

  factory GalleryManifest.fromJson(Map<String, dynamic> json) {
    final feature = json['feature'];
    final model = json['model'];
    if (feature is! Map || model is! Map) {
      throw const FormatException('Manifest gallery tidak lengkap');
    }
    return GalleryManifest(
      formatVersion: json['formatVersion'] as int,
      modelId: model['id'] as String,
      modelSha256: model['sha256'] as String,
      preprocessingVersion:
          (json['preprocessing'] as Map)['version'] as String,
      embeddingDimensions: feature['dimensions'] as int,
      embeddingDtype: feature['dtype'] as String,
      entryCount: (json['entries'] as List).length,
      embeddingsFile: json['embeddingsFile'] as String,
    );
  }

  /// Apakah gallery dapat dipakai oleh build aplikasi ini.
  ///
  /// Mengembalikan `null` bila kompatibel, atau alasan penolakan.
  String? incompatibility({
    required String expectedModelId,
    required String expectedModelSha256,
    required String expectedPreprocessingVersion,
    required int expectedDimensions,
  }) {
    if (formatVersion != supportedFormatVersion) {
      return 'formatVersion $formatVersion tidak didukung';
    }
    if (modelId != expectedModelId) {
      return 'modelId tidak cocok: $modelId';
    }
    if (modelSha256 != expectedModelSha256) {
      return 'hash model tidak cocok';
    }
    if (preprocessingVersion != expectedPreprocessingVersion) {
      return 'preprocessingVersion tidak cocok: $preprocessingVersion';
    }
    if (embeddingDimensions != expectedDimensions) {
      return 'dimensi embedding tidak cocok: $embeddingDimensions';
    }
    if (embeddingDtype != 'float32') {
      return 'dtype embedding tidak didukung: $embeddingDtype';
    }
    if (entryCount <= 0) {
      return 'gallery kosong';
    }
    return null;
  }
}

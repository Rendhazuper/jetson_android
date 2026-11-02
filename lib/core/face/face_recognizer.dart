import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import '../config/app_config.dart';

class RecognitionResult {
  const RecognitionResult({
    required this.name,
    this.closestName,
    required this.confidence,
    required this.distance,
    required this.threshold,
  });

  final String? name;
  final String? closestName;
  final double confidence;
  final double distance;
  final double threshold;
}

/// Modul pengenal wajah SFace — padanan langsung dari `core/recognizer.py`.
class FaceRecognizer {
  FaceRecognizer._();

  static FaceRecognizer? _instance;
  static FaceRecognizer get instance => _instance ??= FaceRecognizer._();

  OrtSession? _session;
  final List<List<double>> _knownEncodings = [];
  final List<String> _knownNames = [];
  final Set<String> _confirmedNames = {};

  bool get isReady => _session != null && _knownEncodings.isNotEmpty;
  int get knownCount => _knownNames.length;

  /// Memuat model SFace ONNX dan gallery encoding dari asset.
  Future<void> init() async {
    if (isReady) return;

    OrtEnv.instance.init();

    // 1. Muat model SFace
    final sessionOptions = OrtSessionOptions();
    final modelBytes = await rootBundle.load(AppConfig.sfaceModelAsset);
    _session = OrtSession.fromBuffer(
      modelBytes.buffer.asUint8List(
        modelBytes.offsetInBytes,
        modelBytes.lengthInBytes,
      ),
      sessionOptions,
    );
    sessionOptions.release();

    // 2. Muat galeri encodings.json
    final jsonStr = await rootBundle.loadString(AppConfig.encodingsAsset);
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    final rawEncodings = data['encodings'] as List<dynamic>;
    final rawNames = data['names'] as List<dynamic>;

    _knownEncodings.clear();
    _knownNames.clear();

    for (var i = 0; i < rawNames.length; i++) {
      final vec = (rawEncodings[i] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
      _knownEncodings.add(vec);
      _knownNames.add(rawNames[i].toString());
    }
  }

  /// Ekstraksi 128-d feature vector dari 112x112 RGB (Float32List panjang 37632 [1, 3, 112, 112]).
  List<double>? extractFeature(Float32List nchwFloats) {
    final session = _session;
    if (session == null) return null;

    final inputTensor = OrtValueTensor.createTensorWithDataList(
      nchwFloats,
      [1, 3, AppConfig.faceSize, AppConfig.faceSize],
    );

    final runOptions = OrtRunOptions();
    final outputs = session.run(runOptions, {session.inputNames[0]: inputTensor});

    inputTensor.release();
    runOptions.release();

    if (outputs.isEmpty || outputs[0] == null) return null;

    final outTensor = outputs[0] as OrtValueTensor;
    final dynamic val = outTensor.value;
    outTensor.release();

    if (val is List && val.isNotEmpty) {
      final first = val[0];
      if (first is List) {
        return first.map((e) => (e as num).toDouble()).toList();
      }
    }
    return null;
  }

  /// Komparasi cosine similarity terhadap seluruh dataset encoding.
  RecognitionResult? recognize(Float32List nchwFloats) {
    if (!isReady) return null;

    final feature = extractFeature(nchwFloats);
    if (feature == null || feature.isEmpty) return null;

    double bestDistance = 999.0;
    int bestIndex = -1;

    for (var i = 0; i < _knownEncodings.length; i++) {
      final dist = _cosineDistance(feature, _knownEncodings[i]);
      if (dist < bestDistance) {
        bestDistance = dist;
        bestIndex = i;
      }
    }

    if (bestIndex == -1) return null;

    final baseConfidence = (1.0 - bestDistance).clamp(0.0, 1.0);

    // Dynamic threshold identik dengan versi Python
    double dynamicThreshold = AppConfig.dynamicThresholdBorderline;
    if (bestDistance < AppConfig.strongDistance) {
      dynamicThreshold = AppConfig.dynamicThresholdStrong;
    } else if (bestDistance < AppConfig.mediumDistance) {
      dynamicThreshold = AppConfig.dynamicThresholdMedium;
    } else if (bestDistance < AppConfig.borderlineDistance) {
      dynamicThreshold = AppConfig.dynamicThresholdBorderline;
    } else {
      dynamicThreshold = AppConfig.dynamicThresholdMax;
    }

    if (bestDistance > dynamicThreshold) {
      return RecognitionResult(
        name: null,
        closestName: _knownNames[bestIndex],
        confidence: baseConfidence,
        distance: bestDistance,
        threshold: dynamicThreshold,
      );
    }

    final name = _knownNames[bestIndex];
    _confirmedNames.add(name);

    return RecognitionResult(
      name: name,
      closestName: name,
      confidence: baseConfidence,
      distance: bestDistance,
      threshold: dynamicThreshold,
    );
  }

  static double _cosineDistance(List<double> a, List<double> b) {
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0.0 || normB == 0.0) return 1.0;
    final sim = dot / (sqrt(normA) * sqrt(normB));
    return (1.0 - sim).clamp(-1.0, 2.0);
  }

  void dispose() {
    _session?.release();
    _session = null;
    _knownEncodings.clear();
    _knownNames.clear();
  }
}

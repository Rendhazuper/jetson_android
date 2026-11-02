/// Konfigurasi aplikasi — padanan `utils/config.py` di versi Python.
class AppConfig {
  AppConfig._();

  // ===== PATH / ASSET =====
  static const String sfaceModelAsset = 'assets/models/face_recognition_sface.onnx';
  static const String encodingsAsset = 'assets/encodings.json';
  static const String logoAsset = 'assets/images/unej_logo.png';

  // ===== FACE RECOGNITION =====
  // Kalibrasi threshold untuk kamera mobile Android (jarak dinamis dan lensa wide-angle)
  static const double strongDistance = 0.35;
  static const double mediumDistance = 0.45;
  static const double borderlineDistance = 0.55;
  static const double maxDistance = 0.60;

  static const double dynamicThresholdStrong = 0.35;
  static const double dynamicThresholdMedium = 0.45;
  static const double dynamicThresholdBorderline = 0.55;
  static const double dynamicThresholdMax = 0.60;

  // ===== TEMPORAL SMOOTHING =====
  static const int recognitionVotes = 1;
  static const double recognitionMemorySeconds = 0.0;

  // ===== FACE INPUT =====
  static const int faceSize = 112; // SFace: 112x112

  // ===== PIPELINE =====
  static const double recognitionInterval = 0.05; // detik
  static const double resultDisplaySeconds = 0.0;

  // ===== CAHAYA / CLAHE =====
  static const double claheClipLimit = 2.0;
  static const int claheTileGridX = 8;
  static const int claheTileGridY = 8;

  // ===== PERSON API =====
  // Isi URL layanan perkuliahan pada build/produk.
  // JANGAN menonaktifkan verifikasi TLS secara default.
  static const String personInfoApiUrl = String.fromEnvironment(
    'PERSON_INFO_API_URL',
    defaultValue: '',
  );
  static const int personInfoApiTimeoutSeconds = 5;

  /// Cooldown kirim ulang per orang (setara gate 30 detik di Python).
  static const int attendanceCooldownSeconds = 30;
}

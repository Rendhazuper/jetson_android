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
  // Batas terima efektif 0.45. Pada gallery 1.904 identitas, 0.60 menerima
  // ~99% wajah tak terdaftar, 0.45 menerima ~12% (terukur dari foto enrollment).
  static const double dynamicThresholdBorderline = 0.45;
  static const double dynamicThresholdMax = 0.45;

  // ===== TEMPORAL SMOOTHING =====
  // Identitas baru dikonfirmasi setelah frame berurutan memilih ID yang sama.
  static const int recognitionVotes = 3;
  static const double recognitionMemorySeconds = 0.0;

  // ===== FACE INPUT =====
  static const int faceSize = 112; // SFace: 112x112

  /// Template 5 titik SFace pada gambar 112x112 (urutan: mata kiri-gambar,
  /// mata kanan-gambar, hidung, mulut kiri-gambar, mulut kanan-gambar).
  static const List<List<double>> sfaceTemplate = [
    [38.2946, 51.6963],
    [73.5318, 51.5014],
    [56.0252, 71.7366],
    [41.5493, 92.3655],
    [70.7299, 92.2041],
  ];

  // ===== PIPELINE =====
  static const double recognitionInterval = 0.05; // detik
  static const double resultDisplaySeconds = 0.0;

  // ===== CAHAYA / CLAHE =====
  static const double claheClipLimit = 2.0;
  static const int claheTileGridX = 8;
  static const int claheTileGridY = 8;

  // ===== PERSON API =====
  // Default memakai layanan perkuliahan UNEJ. Timpa lewat
  // `--dart-define=PERSON_INFO_API_URL=<url>`; nilai kosong mengaktifkan mode
  // demo offline (tanpa mengirim apa pun).
  // JANGAN menonaktifkan verifikasi TLS secara default.
  static const String personInfoApiUrl = String.fromEnvironment(
    'PERSON_INFO_API_URL',
    defaultValue: 'https://api-sister.unej.ac.id/perkuliahan/tendik/info-person',
  );
  static const int personInfoApiTimeoutSeconds = 5;

  /// Cooldown kirim ulang per orang (setara gate 30 detik di Python).
  static const int attendanceCooldownSeconds = 30;
}

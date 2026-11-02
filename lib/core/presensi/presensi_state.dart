/// State machine eksplisit untuk alur presensi.
///
/// Aturan penting:
/// - [PresensiAccepted] hanya boleh dibuat dari respons API yang tervalidasi.
/// - State ini tidak menyimpan gambar wajah; hanya metadata hasil analisis.
/// - Transisi state tidak boleh memblokir preview kamera.
enum PresensiState {
  /// Belum ada kamera/analyzer yang berjalan.
  idle,

  /// Menunggu izin kamera dan memuat model serta gallery.
  initializing,

  /// Kamera aktif, mencari wajah.
  scanning,

  /// Wajah terdeteksi, sedang dinilai kualitas dan dicocokkan.
  verifying,

  /// Kandidat ditemukan, mengirim identitas ke layanan presensi.
  sending,

  /// Server menyatakan presensi diterima.
  accepted,

  /// Server menolak, atau kandidat tidak memenuhi kriteria lokal.
  rejected,

  /// Gagal karena kamera, model, atau galeri tidak tersedia.
  unavailable,

  /// Gagal karena jaringan/API tidak dapat dihubungi.
  networkError,
}

/// Hasil analisis satu frame dari native analyzer.
sealed class FaceAnalysis {
  const FaceAnalysis();
}

/// Tidak ada wajah pada frame.
class NoFaceDetected extends FaceAnalysis {
  const NoFaceDetected();
}

/// Wajah ada, tetapi kualitasnya belum layak diproses.
class QualityRejected extends FaceAnalysis {
  const QualityRejected(this.reason);

  /// Salah satu dari: `too_dark`, `too_blurred`, `too_small`, `multi_face`.
  final String reason;
}

/// Wajah cocok dengan salah satu identitas di gallery (masih kandidat).
class FaceCandidate extends FaceAnalysis {
  const FaceCandidate({
    required this.identity,
    required this.distance,
    required this.analyzerVersion,
    required this.preprocessingVersion,
  });

  final String identity;

  /// Cosine distance: makin kecil makin mirip.
  final double distance;

  /// Skor tampilan `1 - distance`. **Bukan** probabilitas.
  double get displayScore => (1 - distance).clamp(0.0, 1.0);

  final String analyzerVersion;
  final String preprocessingVersion;
}

/// Wajah terdeteksi tetapi tidak cocok dengan identitas mana pun.
class FaceUnknown extends FaceAnalysis {
  const FaceUnknown({required this.bestDistance, required this.reason});

  final double bestDistance;
  final String reason;
}

/// Kegagalan dari sisi native (model, kamera, memori).
class AnalyzerFailure extends FaceAnalysis {
  const AnalyzerFailure({required this.code, required this.message});

  final String code;
  final String message;
}

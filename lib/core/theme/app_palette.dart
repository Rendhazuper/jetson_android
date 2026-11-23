import 'package:flutter/material.dart';

/// Warna UI yang berbeda antara mode terang dan gelap.
///
/// Warna brand (hijau UPATIK, header gradien, merah/biru status presensi)
/// tidak diubah di kedua mode.
class AppPalette {
  const AppPalette({
    required this.pageBackground,
    required this.card,
    required this.ink,
    required this.muted,
    required this.track,
    required this.greenSoft,
    required this.logRow,
    required this.logLatestOk,
    required this.logLatestFail,
  });

  /// Latar halaman di belakang kartu.
  final Color pageBackground;

  /// Latar kartu / panel.
  final Color card;

  /// Teks utama.
  final Color ink;

  /// Teks sekunder dan ikon netral.
  final Color muted;

  /// Latar track progress bar.
  final Color track;

  /// Latar ikon hijau lembut (mis. di baris info).
  final Color greenSoft;

  /// Latar entri log presensi biasa.
  final Color logRow;

  /// Latar entri log terbaru yang berhasil.
  final Color logLatestOk;

  /// Latar entri log terbaru yang gagal.
  final Color logLatestFail;

  static const light = AppPalette(
    pageBackground: Color(0xFFE8EBEE),
    card: Colors.white,
    ink: Color(0xFF1F2937),
    muted: Color(0xFF6B7280),
    track: Color(0xFFE5E7EB),
    greenSoft: Color(0xFFE8F5E9),
    logRow: Color(0xFFF9FAFB),
    logLatestOk: Color(0xFFF0FAF1),
    logLatestFail: Color(0xFFFEF2F2),
  );

  static const dark = AppPalette(
    pageBackground: Color(0xFF111418),
    card: Color(0xFF1E2329),
    ink: Color(0xFFE5E7EB),
    muted: Color(0xFF9CA3AF),
    track: Color(0xFF374151),
    greenSoft: Color(0xFF1F3A25),
    logRow: Color(0xFF252B33),
    logLatestOk: Color(0xFF1B3324),
    logLatestFail: Color(0xFF3A1F1F),
  );

  /// Palet yang sesuai dengan brightness tema yang sedang aktif.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

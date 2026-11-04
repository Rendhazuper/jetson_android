/// Format tanggal dan jam berbahasa Indonesia untuk header dan dialog presensi.
class IndonesianDate {
  IndonesianDate._();

  static const _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  static const _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  /// Contoh: `Senin, 19 Oktober 2026`.
  static String date(DateTime t) =>
      '${_days[t.weekday - 1]}, ${t.day} ${_months[t.month - 1]} ${t.year}';

  /// Contoh: `11:32:19` atau, dengan [separator] `.`, `11.32.19`.
  static String time(DateTime t, {String separator = ':'}) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}$separator${two(t.minute)}$separator${two(t.second)}';
  }

  /// Singkatan zona waktu Indonesia dari selisih UTC perangkat.
  static String zone(Duration offset) {
    return switch (offset.inHours) {
      7 => 'WIB',
      8 => 'WITA',
      9 => 'WIT',
      final h => 'UTC${h >= 0 ? '+' : ''}$h',
    };
  }
}

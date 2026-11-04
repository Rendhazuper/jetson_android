import 'package:face_presensi/presentation/widgets/indonesian_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IndonesianDate', () {
    test('memformat tanggal dengan hari dan bulan Indonesia', () {
      // 19 Oktober 2026 adalah hari Senin.
      expect(
        IndonesianDate.date(DateTime(2026, 10, 19)),
        'Senin, 19 Oktober 2026',
      );
      expect(
        IndonesianDate.date(DateTime(2026, 11, 1)),
        'Minggu, 1 November 2026',
      );
    });

    test('memformat jam dengan pemisah pilihan dan nol di depan', () {
      final t = DateTime(2026, 1, 2, 9, 5, 7);
      expect(IndonesianDate.time(t), '09:05:07');
      expect(IndonesianDate.time(t, separator: '.'), '09.05.07');
    });

    test('memetakan selisih UTC ke zona waktu Indonesia', () {
      expect(IndonesianDate.zone(const Duration(hours: 7)), 'WIB');
      expect(IndonesianDate.zone(const Duration(hours: 8)), 'WITA');
      expect(IndonesianDate.zone(const Duration(hours: 9)), 'WIT');
      expect(IndonesianDate.zone(const Duration(hours: 5)), 'UTC+5');
      expect(IndonesianDate.zone(const Duration(hours: -3)), 'UTC-3');
    });
  });
}

import 'package:face_presensi/data/daily_log_entry.dart';
import 'package:face_presensi/presentation/widgets/attendance_log_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 420, child: child)),
);

void main() {
  group('AttendanceLogTile', () {
    testWidgets('menampilkan NIP berlabel, nama lengkap, waktu, dan Berhasil', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AttendanceLogTile(
            zone: 'WIB',
            entry: DailyLogEntry(
              time: '23:13:02',
              idPegawai: '199011212025211033',
              nama: 'Juris Vassa Ivandro S.Kom',
              status: 'Berhasil',
            ),
          ),
        ),
      );

      expect(find.text('NIP'), findsOneWidget);
      expect(find.text('199011212025211033'), findsOneWidget);
      expect(find.text('Juris Vassa Ivandro S.Kom'), findsOneWidget);
      expect(find.text('23:13:02 WIB'), findsOneWidget);
      expect(find.text('Berhasil'), findsOneWidget);
    });

    testWidgets('entri gagal menyembunyikan NIP dan menampilkan alasan', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AttendanceLogTile(
            zone: 'WIB',
            entry: DailyLogEntry(
              time: '23:20:00',
              idPegawai: '-',
              nama: 'Presensi gagal',
              status: 'Gagal',
              message: 'HTTP 500: Server Error',
            ),
          ),
        ),
      );

      expect(find.text('NIP'), findsNothing);
      expect(find.text('Presensi gagal'), findsOneWidget);
      expect(find.text('HTTP 500: Server Error'), findsOneWidget);
      expect(find.text('Gagal'), findsOneWidget);
      expect(find.text('Berhasil'), findsNothing);
    });
  });
}

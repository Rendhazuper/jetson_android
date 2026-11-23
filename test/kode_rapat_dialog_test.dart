import 'package:face_presensi/presentation/widgets/rapat_session_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinput/pinput.dart';

void main() {
  /// Membuka dialog lewat tombol, lalu menyimpan hasilnya di [results].
  Future<void> openDialog(WidgetTester tester, List<String?> results) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  final kode = await showKodeRapatDialog(
                    context,
                    title: 'Mulai Sesi Rapat',
                    actionLabel: 'Mulai',
                  );
                  results.add(kode);
                },
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Mengetik kode lewat input yang sudah difokuskan oleh Pinput.
  Future<void> typeKode(WidgetTester tester, String kode) async {
    await tester.tap(find.byType(Pinput));
    await tester.pump();
    tester.testTextInput.enterText(kode);
    await tester.pump();
  }

  VoidCallback? verifyCallback(WidgetTester tester) => tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, 'Mulai'))
      .onPressed;

  testWidgets('tombol Mulai nonaktif sampai kode lengkap', (tester) async {
    await openDialog(tester, []);
    expect(verifyCallback(tester), isNull);

    await typeKode(tester, 'R7K2Q');
    await tester.pump();
    expect(verifyCallback(tester), isNull);

    await typeKode(tester, 'R7K2QM');
    await tester.pump();
    expect(verifyCallback(tester), isNotNull);
  });

  testWidgets('kode dikembalikan dalam huruf besar', (tester) async {
    final results = <String?>[];
    await openDialog(tester, results);

    await typeKode(tester, 'r7k2qm');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Mulai'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(results, ['R7K2QM']);
  });

  testWidgets('Batal mengembalikan null', (tester) async {
    final results = <String?>[];
    await openDialog(tester, results);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Batal'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(results, [null]);
  });
}

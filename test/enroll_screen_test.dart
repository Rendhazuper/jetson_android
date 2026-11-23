import 'package:face_presensi/presentation/screens/enroll_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dialog NIP/NRP/NIK', () {
    testWidgets(
      'Lanjut nonaktif sampai diisi, lalu mengembalikan nilai yang dirapikan',
      (tester) async {
        String? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await showEnrollNipDialog(context);
                    },
                    child: const Text('Buka'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka'));
        await tester.pumpAndSettle();

        expect(_lanjutButton(tester).onPressed, isNull);

        await tester.enterText(
          find.byType(TextField),
          '  199011212025211033  ',
        );
        await tester.pump();
        expect(_lanjutButton(tester).onPressed, isNotNull);

        await tester.tap(find.text('Lanjut'));
        await tester.pumpAndSettle();

        expect(result, '199011212025211033');
      },
    );

    testWidgets('format tidak sesuai: Lanjut nonaktif dan muncul pesan', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showEnrollNipDialog(context),
                  child: const Text('Buka'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'NIP 123/');
      await tester.pump();

      expect(_lanjutButton(tester).onPressed, isNull);
      expect(find.text('Format nomor identitas belum sesuai.'), findsOneWidget);
    });

    testWidgets('Batal mengembalikan null', (tester) async {
      String? result = 'belum diisi';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showEnrollNipDialog(context);
                  },
                  child: const Text('Buka'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  group('EnrollScreen', () {
    testWidgets(
      'persetujuan: Setuju aktif hanya setelah teks digulir sampai akhir',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: EnrollScreen(nip: '199011212025211033')),
        );
        await tester.pumpAndSettle();

        expect(find.text('NIP/NRP/NIK: 199011212025211033'), findsOneWidget);
        expect(_setujuButton(tester).onPressed, isNull);
        expect(
          find.text(
            'Gulir teks persetujuan sampai akhir untuk dapat menyetujui.',
          ),
          findsOneWidget,
        );

        await tester.drag(
          find.byKey(const ValueKey('consent-scroll')),
          const Offset(0, -20000),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Gulir teks persetujuan sampai akhir untuk dapat menyetujui.',
          ),
          findsNothing,
        );

        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        expect(_setujuButton(tester).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('setelah setuju: tampil cek kamera, tombol rekam nonaktif', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _bacaDanSetujui(tester);

      expect(find.text('Cek kamera'), findsOneWidget);
      expect(_mulaiButton(tester).onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('layar sempit 360x780 tidak overflow di kedua tahap', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _bacaDanSetujui(tester);

      expect(find.text('Cek kamera'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Menggulir persetujuan sampai akhir, mencentang, lalu menekan Setuju.
Future<void> _bacaDanSetujui(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: EnrollScreen(nip: '199011212025211033')),
  );
  await tester.pumpAndSettle();

  await tester.ensureVisible(find.byKey(const ValueKey('consent-scroll')));
  await tester.drag(
    find.byKey(const ValueKey('consent-scroll')),
    const Offset(0, -20000),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pump();
  await tester.ensureVisible(find.text('Setuju & lanjut'));
  await tester.tap(find.text('Setuju & lanjut'));
  await tester.pumpAndSettle();
}

FilledButton _lanjutButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Lanjut'));

FilledButton _setujuButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, 'Setuju & lanjut'),
);

FilledButton _mulaiButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, 'Mulai merekam'),
);

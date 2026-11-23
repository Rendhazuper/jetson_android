import 'package:face_presensi/presentation/screens/enroll_screen.dart';
import 'package:face_presensi/presentation/screens/menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MenuScreen', () {
    // Ukuran tablet landscape dan ponsel portrait: tidak boleh overflow.
    const sizes = [Size(1280, 800), Size(360, 780)];

    for (final size in sizes) {
      testWidgets('menampilkan tiga menu tanpa overflow di '
          '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(const MaterialApp(home: MenuScreen()));

        expect(find.text('Enroll Wajah Baru'), findsOneWidget);
        expect(find.text('Vision'), findsOneWidget);
        expect(find.text('Pengaturan'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Enroll Wajah Baru meminta NIP dulu, belum membuka kamera', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: MenuScreen()));

      await tester.tap(find.text('Enroll Wajah Baru'));
      await tester.pumpAndSettle();

      expect(find.text('Lanjut'), findsOneWidget);
      expect(find.byType(EnrollScreen), findsNothing);
    });
  });
}

import 'package:face_presensi/presentation/screens/camera_permission_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

/// Channel yang dipakai permission_handler di Android.
const _permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

void _mockPermissionChannel(Future<Object?> Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_permissionChannel, handler);
}

/// Memberi kesempatan pada pemeriksaan async selesai. Tidak memakai
/// pumpAndSettle karena spinner pemeriksaan tidak pernah berhenti berputar.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump();
}

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionChannel, null);
  });

  group('CameraPermissionView', () {
    testWidgets('izin belum diberikan: tombol Izinkan Kamera meminta izin', (
      tester,
    ) async {
      var requested = 0;
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CameraPermissionView(
            status: PermissionStatus.denied,
            onRequest: () {
              requested++;
            },
            onOpenSettings: () {
              opened++;
            },
          ),
        ),
      );

      expect(find.text('Izin Kamera Diperlukan'), findsOneWidget);
      expect(find.text('Izinkan Kamera'), findsOneWidget);
      expect(find.text('Buka Pengaturan'), findsNothing);

      await tester.tap(find.text('Izinkan Kamera'));
      await tester.pump();

      expect(requested, 1);
      expect(opened, 0);
    });

    testWidgets('ditolak permanen: tombol Buka Pengaturan, bukan minta ulang', (
      tester,
    ) async {
      var requested = 0;
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CameraPermissionView(
            status: PermissionStatus.permanentlyDenied,
            onRequest: () {
              requested++;
            },
            onOpenSettings: () {
              opened++;
            },
          ),
        ),
      );

      expect(find.text('Buka Pengaturan'), findsOneWidget);
      expect(find.text('Izinkan Kamera'), findsNothing);

      await tester.tap(find.text('Buka Pengaturan'));
      await tester.pump();

      expect(opened, 1);
      expect(requested, 0);
    });
  });

  group('CameraPermissionGate', () {
    testWidgets('plugin tidak merespons: tampil Coba Lagi, bukan crash', (
      tester,
    ) async {
      _mockPermissionChannel((call) async {
        throw MissingPluginException('No implementation found');
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CameraPermissionGate(child: Text('ISI APLIKASI')),
        ),
      );
      await _settle(tester);

      expect(find.text('Coba Lagi'), findsOneWidget);
      expect(find.text('ISI APLIKASI'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('izin belum diberikan: tampil tombol Izinkan Kamera', (
      tester,
    ) async {
      _mockPermissionChannel((call) async {
        if (call.method == 'checkPermissionStatus') return 0; // denied
        return null;
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CameraPermissionGate(child: Text('ISI APLIKASI')),
        ),
      );
      await _settle(tester);

      expect(find.text('Izinkan Kamera'), findsOneWidget);
      expect(find.text('ISI APLIKASI'), findsNothing);
    });

    testWidgets('izin sudah diberikan: isi aplikasi ditampilkan', (
      tester,
    ) async {
      _mockPermissionChannel((call) async {
        if (call.method == 'checkPermissionStatus') return 1; // granted
        return null;
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CameraPermissionGate(child: Text('ISI APLIKASI')),
        ),
      );
      await _settle(tester);

      expect(find.text('ISI APLIKASI'), findsOneWidget);
      expect(find.text('Izinkan Kamera'), findsNothing);
    });
  });
}

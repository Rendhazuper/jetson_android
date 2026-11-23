import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_palette.dart';

/// Membatasi seluruh aplikasi sampai izin kamera diberikan. Dipasang di atas
/// Navigator (lewat `MaterialApp.builder`), jadi berlaku untuk semua layar.
/// Status diperiksa lagi saat aplikasi kembali aktif, misalnya setelah izin
/// diaktifkan dari Pengaturan aplikasi.
class CameraPermissionGate extends StatefulWidget {
  const CameraPermissionGate({super.key, required this.child});

  final Widget child;

  @override
  State<CameraPermissionGate> createState() => _CameraPermissionGateState();
}

class _CameraPermissionGateState extends State<CameraPermissionGate>
    with WidgetsBindingObserver {
  /// `null` selama status pertama kali diperiksa.
  PermissionStatus? _status;

  /// `true` bila pemeriksaan izin gagal, misalnya plugin belum termuat.
  bool _checkFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() => _check(() => Permission.camera.status);

  Future<void> _request() => _check(() => Permission.camera.request());

  /// Menjalankan pemeriksaan izin. Bila plugin tidak merespons (misalnya APK
  /// belum memuat plugin baru), layar menampilkan tombol coba lagi, bukan crash.
  Future<void> _check(Future<PermissionStatus> Function() action) async {
    try {
      final status = await action();
      if (!mounted) return;
      setState(() {
        _status = status;
        _checkFailed = false;
      });
    } catch (e) {
      debugPrint('[CAMERA PERMISSION] $e');
      if (!mounted) return;
      setState(() => _checkFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkFailed) {
      return CameraPermissionCheckFailedView(onRetry: () => _refresh());
    }
    final status = _status;
    if (status == null) {
      return const _CheckingView();
    }
    if (status.isGranted) {
      return widget.child;
    }
    return CameraPermissionView(
      status: status,
      onRequest: _request,
      onOpenSettings: () => openAppSettings(),
    );
  }
}

/// Tampilan saat izin kamera belum diberikan. Tombol berubah menjadi
/// "Buka Pengaturan" bila izin ditolak permanen (atau dibatasi perangkat).
class CameraPermissionView extends StatelessWidget {
  const CameraPermissionView({
    super.key,
    required this.status,
    required this.onRequest,
    required this.onOpenSettings,
  });

  final PermissionStatus status;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  static const _green = Color(0xFF2FA23A);
  static const _greenDark = Color(0xFF1F7F2B);

  bool get _needsSettings => status.isPermanentlyDenied || status.isRestricted;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      backgroundColor: p.pageBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_front,
                      size: 36,
                      color: _greenDark,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Izin Kamera Diperlukan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _needsSettings
                        ? 'Izin kamera ditolak. Buka Pengaturan aplikasi, '
                              'aktifkan izin Kamera, lalu kembali ke VISION UNEJ.'
                        : 'VISION UNEJ memakai kamera depan untuk mengenali '
                              'wajah saat presensi dan enroll. Izinkan akses '
                              'kamera untuk melanjutkan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _needsSettings ? onOpenSettings : onRequest,
                      child: Text(
                        _needsSettings ? 'Buka Pengaturan' : 'Izinkan Kamera',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tampilan saat izin kamera tidak bisa diperiksa, misalnya plugin permission
/// belum termuat di APK yang sedang berjalan.
class CameraPermissionCheckFailedView extends StatelessWidget {
  const CameraPermissionCheckFailedView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      backgroundColor: p.pageBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 56,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Izin kamera belum bisa diperiksa',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    kDebugMode
                        ? 'Terjadi kendala saat memeriksa izin kamera. Coba lagi.\n\n'
                              'Mode debug: setelah menambah plugin, hentikan aplikasi '
                              'lalu jalankan ulang penuh. Hot reload dan hot restart '
                              'tidak memuat plugin native baru.'
                        : 'Terjadi kendala saat memeriksa izin kamera. Coba lagi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2FA23A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: onRetry,
                      child: const Text('Coba Lagi'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckingView extends StatelessWidget {
  const _CheckingView();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.pageBackground,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

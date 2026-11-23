import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/face/face_recognizer.dart';
import 'menu_screen.dart';

/// Layar splash / loading — padanan dari `SplashScreen` di `app_tkinter.py`.
/// Memuat model SFace ONNX dan data wajah ke memori sebelum menu utama tampil.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Hijau UPATIK, sama dengan header dan layar lain.
  static const _brandGreen = Color(0xFF2FA23A);

  double _progress = 0;
  int _total = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      await FaceRecognizer.instance.init(
        onProgress: (progress, total) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _total = total;
          });
        },
      );

      if (!mounted) return;
      setState(() => _progress = 1.0);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => const MenuScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat model: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).round();
    final subtitle =
        _error ??
        (_total > 0
            ? 'Memuat data $_total wajah...'
            : 'Memuat model deteksi wajah...');

    return Scaffold(
      backgroundColor: const Color(0xFF181818),
      body: Center(
        child: Container(
          width: 340,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF242424),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF333333)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                AppConfig.logoAsset,
                width: 56,
                height: 56,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.school, color: Colors.amber, size: 48),
              ),
              const SizedBox(height: 12),
              const Text(
                'VISION UNEJ',
                style: TextStyle(
                  color: _brandGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _error != null
                      ? const Color(0xFFF87171)
                      : Colors.white,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  value: _error != null ? null : _progress,
                  backgroundColor: const Color(0xFF333333),
                  valueColor: const AlwaysStoppedAnimation<Color>(_brandGreen),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$percent%',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/face/face_recognizer.dart';
import 'home_screen.dart';

/// Layar splash / loading — padanan dari `SplashScreen` di `app_tkinter.py`.
/// Memuat model SFace ONNX dan data wajah ke memori sebelum layar utama tampil.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Memuat model deteksi wajah...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _status = 'Memuat data wajah...');

      await FaceRecognizer.instance.init();

      if (!mounted) return;
      final count = FaceRecognizer.instance.knownCount;
      setState(() => _status = 'Load $count data wajah...');

      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Gagal memuat model: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'FACE RECOGNITION',
                style: TextStyle(
                  color: Color(0xFF3B82F6),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFF333333),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

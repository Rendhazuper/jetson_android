import 'dart:async';
import 'package:flutter/material.dart';
import 'indonesian_date.dart';

/// Pop-up "Presensi Vision Berhasil". Menutup sendiri setelah [autoClose],
/// atau lebih awal lewat tombol Tutup.
class AttendanceSuccessDialog extends StatefulWidget {
  const AttendanceSuccessDialog({
    super.key,
    required this.nama,
    required this.waktu,
    this.autoClose = const Duration(seconds: 4),
  });

  final String nama;
  final DateTime waktu;
  final Duration autoClose;

  @override
  State<AttendanceSuccessDialog> createState() =>
      _AttendanceSuccessDialogState();
}

class _AttendanceSuccessDialogState extends State<AttendanceSuccessDialog> {
  static const _green = Color(0xFF2FA23A);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.autoClose, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waktu = widget.waktu;
    return Dialog(
      backgroundColor: const Color(0xFF2B2B2B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Presensi Vision Berhasil',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.nama,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                '${IndonesianDate.date(waktu)}, '
                '${IndonesianDate.time(waktu, separator: '.')} '
                '${IndonesianDate.zone(waktu.timeZoneOffset)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 14),
              const Text(
                'Anda dapat Cek Kehadiran Pada Aplikasi SFS/SFL/SFT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 150,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

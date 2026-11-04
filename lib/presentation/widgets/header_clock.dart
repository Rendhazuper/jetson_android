import 'dart:async';
import 'package:flutter/material.dart';
import 'indonesian_date.dart';

/// Tanggal dan jam berjalan di header. Memiliki timer sendiri agar layar
/// utama (termasuk preview kamera) tidak ikut dibangun ulang tiap detik.
class HeaderClock extends StatefulWidget {
  const HeaderClock({super.key});

  @override
  State<HeaderClock> createState() => _HeaderClockState();
}

class _HeaderClockState extends State<HeaderClock> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${IndonesianDate.date(_now)} • ${IndonesianDate.time(_now)} '
      '${IndonesianDate.zone(_now.timeZoneOffset)}',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

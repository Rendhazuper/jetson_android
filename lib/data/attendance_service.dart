import 'dart:core';

/// Layanan pembatas frekuensi presensi (Gate Cooldown).
/// Padanan langsung dari `services/attendance_service.py`.
class AttendanceService {
  AttendanceService({this.cooldownSeconds = 30});

  final int cooldownSeconds;
  final Map<String, DateTime> _lastAttendance = {};

  bool canAttend(String personId) {
    final now = DateTime.now();
    final last = _lastAttendance[personId];

    if (last == null || now.difference(last).inSeconds > cooldownSeconds) {
      _lastAttendance[personId] = now;
      return true;
    }

    return false;
  }

  void reset() {
    _lastAttendance.clear();
  }
}

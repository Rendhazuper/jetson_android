/// Model entri log presensi harian.
/// Padanan dari entri di `daily_log` pada `core/pipeline.py`.
class DailyLogEntry {
  const DailyLogEntry({
    required this.time,
    required this.idPegawai,
    required this.nama,
    required this.status,
    this.message,
  });

  final String time;
  final String idPegawai;
  final String nama;
  final String status;
  final String? message;
}

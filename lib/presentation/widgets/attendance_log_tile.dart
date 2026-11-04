import 'package:flutter/material.dart';
import '../../data/daily_log_entry.dart';
import 'indonesian_date.dart';

/// Satu entri "Log Presensi Hari Ini". Urutan baca: NIP (berlabel), nama
/// lengkap, waktu, lalu tanda berhasil/gagal, agar jelas bagi orang awam.
class AttendanceLogTile extends StatelessWidget {
  const AttendanceLogTile({
    super.key,
    required this.entry,
    this.isLatest = false,
    this.zone,
  });

  final DailyLogEntry entry;

  /// Entri terbaru diberi latar yang lebih menonjol.
  final bool isLatest;

  /// Singkatan zona waktu; bila kosong diambil dari zona perangkat.
  final String? zone;

  static const _green = Color(0xFF2FA23A);
  static const _red = Color(0xFFDC2626);
  static const _ink = Color(0xFF1F2937);
  static const _muted = Color(0xFF6B7280);

  bool get _isOk => entry.status == 'Berhasil';

  @override
  Widget build(BuildContext context) {
    final accent = _isOk ? _green : _red;
    final background = isLatest
        ? (_isOk ? const Color(0xFFF0FAF1) : const Color(0xFFFEF2F2))
        : const Color(0xFFF9FAFB);
    final zoneLabel =
        zone ?? IndonesianDate.zone(DateTime.now().timeZoneOffset);
    final hasNip = entry.idPegawai.isNotEmpty && entry.idPegawai != '-';
    final message = entry.message;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accent),
            Expanded(
              child: Container(
                color: background,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasNip)
                      Row(
                        children: [
                          const Text(
                            'NIP',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _muted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.idPegawai,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _ink,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (hasNip) const SizedBox(height: 3),
                    Text(
                      entry.nama,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    if (!_isOk && message != null && message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: _red),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: _muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${entry.time} $zoneLabel',
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ),
                        _StatusChip(isOk: _isOk, color: accent),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isOk, required this.color});

  final bool isOk;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.cancel,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isOk ? 'Berhasil' : 'Gagal',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

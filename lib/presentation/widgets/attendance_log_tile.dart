import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
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

  bool get _isOk => entry.status == 'Berhasil';

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final accent = _isOk ? _green : _red;
    final background = isLatest
        ? (_isOk ? p.logLatestOk : p.logLatestFail)
        : p.logRow;
    final ink = p.ink;
    final muted = p.muted;
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
                          Text(
                            'NIP',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: muted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.idPegawai,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ink,
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: ink,
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
                        Icon(Icons.schedule, size: 14, color: muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${entry.time} $zoneLabel',
                            style: TextStyle(fontSize: 12, color: muted),
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

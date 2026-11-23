import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';

/// Sesi presensi rapat yang sedang dibuka di tablet.
///
/// `idsesi` bersifat rahasia: jangan ditampilkan atau dicatat ke log.
class RapatSession {
  const RapatSession({
    required this.idsesi,
    this.judul = '-',
    this.tempat = '-',
    this.mulai = '-',
    this.selesai = '-',
  });

  final String idsesi;
  final String judul;
  final String tempat;
  final String mulai;
  final String selesai;

  /// Membaca `streams` dari jawaban `mulai` atau `info`. Mengembalikan `null`
  /// bila `idsesi` tidak ada.
  static RapatSession? fromStreams(Map<String, dynamic>? streams) {
    final id = streams?['idsesi']?.toString();
    if (streams == null || id == null || id.isEmpty) return null;
    return RapatSession(
      idsesi: id,
      judul: streams['judul']?.toString() ?? '-',
      tempat: streams['tempat']?.toString() ?? '-',
      mulai: streams['mulai']?.toString() ?? '-',
      selesai: streams['selesai']?.toString() ?? '-',
    );
  }

  factory RapatSession.fromJson(Map<String, dynamic> json) => RapatSession(
    idsesi: json['idsesi'] as String,
    judul: json['judul'] as String? ?? '-',
    tempat: json['tempat'] as String? ?? '-',
    mulai: json['mulai'] as String? ?? '-',
    selesai: json['selesai'] as String? ?? '-',
  );

  Map<String, dynamic> toJson() => {
    'idsesi': idsesi,
    'judul': judul,
    'tempat': tempat,
    'mulai': mulai,
    'selesai': selesai,
  };
}

/// Status pencatatan `hadir`: `hadir` untuk peserta, `tamu` untuk yang bukan
/// peserta, `sudah` bila orang tersebut sudah tercatat sebelumnya.
enum RapatHadirStatus { hadir, tamu, sudah }

/// Hasil pencatatan `hadir` dari `streams`. Data identitas di sini bersifat
/// rahasia: jangan dicatat ke log.
class RapatHadir {
  const RapatHadir({
    required this.status,
    this.nama = '-',
    this.nomorPegawai = '-',
    this.unit = '-',
    this.waktu,
    this.terlambat = false,
  });

  final RapatHadirStatus status;
  final String nama;
  final String nomorPegawai;
  final String unit;

  /// Waktu tercatat dari server. Untuk `sudah`, ini jam pertama kali tercatat.
  final DateTime? waktu;
  final bool terlambat;

  /// Membaca `streams` dari jawaban `hadir`. Mengembalikan `null` bila `status`
  /// tidak dikenal.
  static RapatHadir? fromStreams(Map<String, dynamic>? streams) {
    if (streams == null) return null;
    final status = switch (streams['status']?.toString()) {
      'hadir' => RapatHadirStatus.hadir,
      'tamu' => RapatHadirStatus.tamu,
      'sudah' => RapatHadirStatus.sudah,
      _ => null,
    };
    if (status == null) return null;

    return RapatHadir(
      status: status,
      nama: streams['nama']?.toString() ?? '-',
      nomorPegawai: streams['nomorpegawai']?.toString() ?? '-',
      unit: streams['nama_unit_kerja']?.toString() ?? '-',
      waktu: DateTime.tryParse(streams['waktu']?.toString() ?? '')?.toLocal(),
      terlambat: streams['terlambat'] == true,
    );
  }
}

class RapatApiResponse {
  const RapatApiResponse({
    required this.ok,
    this.status,
    required this.message,
    this.streams,
  });

  final bool ok;
  final int? status;
  final String message;
  final Map<String, dynamic>? streams;
}

/// Klien untuk API presensi rapat (`mulai`, `info`, `akhiri`).
///
/// Kode rapat hanya dikirim ke `mulai` dan `akhiri`. Setelah sesi dibuka,
/// semua pemanggilan lain cukup memakai `idsesi`.
class RapatApiService {
  RapatApiService({String? baseUrl, String? perangkat, http.Client? client})
    : _base = (baseUrl ?? AppConfig.rapatApiBaseUrl).replaceAll(
        RegExp(r'/+$'),
        '',
      ),
      _perangkat = perangkat ?? AppConfig.rapatPerangkatName,
      _client = client ?? http.Client();

  final String _base;
  final String _perangkat;
  final http.Client _client;

  Future<RapatApiResponse> mulai(String kode) =>
      _post('mulai', {'kode': kode, 'perangkat': _perangkat});

  Future<RapatApiResponse> info(String idsesi) =>
      _post('info', {'idsesi': idsesi});

  /// Mencatat kehadiran dari wajah yang dikenali. `titik` sengaja tidak dikirim,
  /// supaya server memilih sendiri (scan pertama Datang, berikutnya Pulang).
  Future<RapatApiResponse> hadir({
    required String idsesi,
    required String idpersonal,
  }) => _post('hadir', {'idsesi': idsesi, 'idpersonal': idpersonal});

  Future<RapatApiResponse> akhiri({
    required String idsesi,
    required String kode,
  }) => _post('akhiri', {'idsesi': idsesi, 'kode': kode});

  Future<RapatApiResponse> _post(String nama, Map<String, dynamic> body) async {
    if (_base.isEmpty) {
      return const RapatApiResponse(
        ok: false,
        message: 'URL API rapat belum diset.',
      );
    }

    try {
      final response = await _client
          .post(
            Uri.parse('$_base/$nama'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: AppConfig.rapatApiTimeoutSeconds));

      Map<String, dynamic>? parsed;
      if (response.body.isNotEmpty) {
        try {
          parsed = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {}
      }

      final streams = parsed?['streams'];
      final message =
          parsed?['message']?.toString() ??
          'HTTP ${response.statusCode}: ${response.reasonPhrase}';
      final ok =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          parsed?['success'] != false;

      return RapatApiResponse(
        ok: ok,
        status: response.statusCode,
        message: message,
        streams: streams is Map<String, dynamic> ? streams : null,
      );
    } on TimeoutException {
      return const RapatApiResponse(
        ok: false,
        message: 'Server rapat tidak merespons. Coba lagi.',
      );
    } on SocketException catch (e) {
      return RapatApiResponse(
        ok: false,
        message: 'Jaringan tidak dapat dihubungi: ${e.message}',
      );
    } catch (e) {
      return RapatApiResponse(ok: false, message: 'Gagal menghubungi API: $e');
    }
  }

  void dispose() => _client.close();
}

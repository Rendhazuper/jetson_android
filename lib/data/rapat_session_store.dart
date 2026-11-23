import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'rapat_api_service.dart';

/// Menyimpan sesi rapat yang sedang aktif di folder support aplikasi, supaya
/// sesi bisa dilanjutkan saat aplikasi dibuka ulang.
///
/// Kode rapat sengaja tidak disimpan: API memintanya lagi saat `akhiri`.
class RapatSessionStore {
  static const _fileName = 'rapat_session.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}/$_fileName');
  }

  /// Mengembalikan sesi tersimpan, atau `null` bila tidak ada / tidak terbaca.
  Future<RapatSession?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return null;
      return RapatSession.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(RapatSession session) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(session.toJson()));
    } catch (_) {
      // Gagal menyimpan hanya berarti sesi tidak bertahan saat app ditutup.
    }
  }

  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

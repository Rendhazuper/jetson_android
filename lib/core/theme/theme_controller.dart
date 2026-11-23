import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Menyimpan pilihan mode tema (Sistem / Terang / Gelap) dan memberi tahu
/// listener saat pilihan berubah.
///
/// Pilihan disimpan sebagai file teks kecil di folder support aplikasi, jadi
/// tetap berlaku setelah aplikasi ditutup. Kegagalan baca/tulis tidak
/// menghentikan perubahan tema untuk sesi yang sedang berjalan.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const _fileName = 'theme_mode.txt';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  /// Memuat pilihan tersimpan. Bila belum ada atau gagal dibaca, pakai Sistem.
  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        _mode = _parse(await file.readAsString());
      }
    } catch (_) {
      _mode = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final file = await _file();
      await file.writeAsString(_name(mode));
    } catch (_) {
      // Abaikan: pilihan tetap berlaku untuk sesi ini.
    }
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}/$_fileName');
  }

  static ThemeMode _parse(String raw) => switch (raw.trim()) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _name(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

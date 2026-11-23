import 'dart:math';

/// Aturan NIP/NIM/NIK dan rekaman enroll. Nilainya sama dengan halaman
/// /rekam di web, kecuali urutan arah yang di sini diacak di aplikasi.

/// Huruf, angka, titik, garis bawah, atau tanda hubung; 3–32 karakter.
final RegExp _personRefPattern = RegExp(r'^[A-Za-z0-9._-]{3,32}$');

/// `true` bila nomor identitas sesuai format di halaman /rekam.
bool isValidPersonRef(String value) => _personRefPattern.hasMatch(value.trim());

/// Hitung mundur sebelum rekaman dimulai.
const int kEnrollCountdownSeconds = 3;

/// Lama setiap perintah arah.
const Duration kEnrollStepDuration = Duration(seconds: 3);

/// Teks perintah per arah, sama dengan halaman /rekam.
const Map<String, String> kEnrollPrompts = {
  'depan': 'Lihat ke DEPAN',
  'kiri': 'Pelan-pelan menoleh ke KIRI',
  'kanan': 'Pelan-pelan menoleh ke KANAN',
  'atas': 'Pelan-pelan lihat ke ATAS',
  'bawah': 'Pelan-pelan lihat ke BAWAH',
};

/// Urutan arah untuk satu rekaman, diacak. Di web urutannya datang dari server
/// (`reg.challenge`); sampai API pendaftaran dihubungkan, diacak di sini.
List<String> enrollChallenge(Random random) =>
    kEnrollPrompts.keys.toList()..shuffle(random);

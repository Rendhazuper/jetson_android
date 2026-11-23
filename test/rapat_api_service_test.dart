import 'dart:convert';
import 'dart:io';

import 'package:face_presensi/data/rapat_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('RapatApiService', () {
    test('mulai mengirim kode dan perangkat ke endpoint /mulai', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'code': 200,
            'success': true,
            'message': 'Sesi dibuka.',
            'streams': {
              'idsesi': 'sesi-rahasia-123',
              'judul': 'Rapat Senat',
              'tempat': 'R. Sidang FT',
              'mulai': '08:00',
              'selesai': '10:00',
            },
          }),
          200,
        );
      });
      final api = RapatApiService(
        baseUrl: 'https://example.test/perkuliahan/vision/rapat/',
        perangkat: 'Tablet Uji',
        client: client,
      );

      final res = await api.mulai('R7K2QM');

      expect(
        captured.url.toString(),
        'https://example.test/perkuliahan/vision/rapat/mulai',
      );
      expect(jsonDecode(captured.body), {
        'kode': 'R7K2QM',
        'perangkat': 'Tablet Uji',
      });
      expect(res.ok, isTrue);
      final session = RapatSession.fromStreams(res.streams);
      expect(session?.idsesi, 'sesi-rahasia-123');
      expect(session?.judul, 'Rapat Senat');
    });

    test('409 dikembalikan sebagai gagal dengan message dari server', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 409,
            'success': false,
            'message': 'Sesi sudah tertutup.',
          }),
          409,
        ),
      );
      final api = RapatApiService(
        baseUrl: 'https://example.test/rapat',
        client: client,
      );

      final res = await api.info('sesi-x');

      expect(res.ok, isFalse);
      expect(res.status, 409);
      expect(res.message, 'Sesi sudah tertutup.');
    });

    test('kegagalan jaringan tidak melempar exception', () async {
      final client = MockClient(
        (_) async => throw const SocketException('no route'),
      );
      final api = RapatApiService(
        baseUrl: 'https://example.test/rapat',
        client: client,
      );

      final res = await api.akhiri(idsesi: 'sesi-x', kode: 'R7K2QM');

      expect(res.ok, isFalse);
      expect(res.status, isNull);
      expect(res.message, contains('Jaringan'));
    });

    test('URL kosong langsung gagal tanpa request', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });
      final api = RapatApiService(baseUrl: '', client: client);

      final res = await api.info('sesi-x');

      expect(res.ok, isFalse);
      expect(called, isFalse);
    });
  });

  group('hadir', () {
    test('mengirim idsesi dan idpersonal ke /hadir tanpa titik', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'code': 200,
            'success': true,
            'message': 'Tercatat sebagai tamu.',
            'streams': {
              'status': 'tamu',
              'nama': 'Tamu Uji',
              'nomorpegawai': '-',
              'nama_unit_kerja': 'Umum',
              'waktu': '2026-11-23T08:05:00+07:00',
              'terlambat': false,
            },
          }),
          200,
        );
      });
      final api = RapatApiService(
        baseUrl: 'https://example.test/rapat',
        client: client,
      );

      final res = await api.hadir(
        idsesi: 'sesi-rahasia-123',
        idpersonal: 'pegawai-1',
      );

      expect(captured.url.toString(), 'https://example.test/rapat/hadir');
      expect(jsonDecode(captured.body), {
        'idsesi': 'sesi-rahasia-123',
        'idpersonal': 'pegawai-1',
      });
      final hadir = RapatHadir.fromStreams(res.streams);
      expect(hadir?.status, RapatHadirStatus.tamu);
      expect(hadir?.nama, 'Tamu Uji');
      expect(hadir?.unit, 'Umum');
    });

    test('409 dari hadir dikembalikan sebagai gagal dengan message', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 409,
            'success': false,
            'message': 'Presensi dibuka pukul 08.00.',
          }),
          409,
        ),
      );
      final api = RapatApiService(
        baseUrl: 'https://example.test/rapat',
        client: client,
      );

      final res = await api.hadir(idsesi: 'sesi-x', idpersonal: 'pegawai-1');

      expect(res.ok, isFalse);
      expect(res.status, 409);
      expect(res.message, 'Presensi dibuka pukul 08.00.');
    });
  });

  group('RapatHadir', () {
    test('fromStreams membaca status hadir, terlambat, dan waktu', () {
      final hadir = RapatHadir.fromStreams({
        'status': 'hadir',
        'nama': 'Budi',
        'nomorpegawai': '1990',
        'nama_unit_kerja': 'UPATIK',
        'waktu': '2026-11-23T08:10:00+07:00',
        'terlambat': true,
        'menit_terlambat': 10,
      });

      expect(hadir?.status, RapatHadirStatus.hadir);
      expect(hadir?.nomorPegawai, '1990');
      expect(hadir?.terlambat, isTrue);
      expect(hadir?.waktu, isNotNull);
    });

    test('status sudah dibaca, status tidak dikenal menghasilkan null', () {
      expect(
        RapatHadir.fromStreams({'status': 'sudah'})?.status,
        RapatHadirStatus.sudah,
      );
      expect(RapatHadir.fromStreams({'status': 'entah'}), isNull);
      expect(RapatHadir.fromStreams({'nama': 'X'}), isNull);
      expect(RapatHadir.fromStreams(null), isNull);
    });
  });

  group('RapatSession', () {
    test('fromStreams mengembalikan null bila idsesi tidak ada', () {
      expect(RapatSession.fromStreams({'judul': 'X'}), isNull);
      expect(RapatSession.fromStreams(null), isNull);
    });

    test('toJson lalu fromJson menghasilkan data yang sama', () {
      const session = RapatSession(
        idsesi: 'abc',
        judul: 'Rapat',
        tempat: 'Ruang 1',
        mulai: '08:00',
        selesai: '09:00',
      );

      final back = RapatSession.fromJson(session.toJson());

      expect(back.idsesi, 'abc');
      expect(back.judul, 'Rapat');
      expect(back.tempat, 'Ruang 1');
      expect(back.mulai, '08:00');
      expect(back.selesai, '09:00');
    });
  });
}

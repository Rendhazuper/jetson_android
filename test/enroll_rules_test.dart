import 'dart:math';

import 'package:face_presensi/core/enroll/enroll_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isValidPersonRef', () {
    test('menerima huruf, angka, titik, garis bawah, dan tanda hubung', () {
      expect(isValidPersonRef('199011212025211033'), isTrue);
      expect(isValidPersonRef('NIP.123_A-9'), isTrue);
    });

    test('spasi di ujung diabaikan', () {
      expect(isValidPersonRef('  12345  '), isTrue);
    });

    test('batas 3 dan 32 karakter diterima', () {
      expect(isValidPersonRef('abc'), isTrue);
      expect(isValidPersonRef('a' * 32), isTrue);
    });

    test('menolak terlalu pendek, terlalu panjang, dan karakter lain', () {
      expect(isValidPersonRef(''), isFalse);
      expect(isValidPersonRef('ab'), isFalse);
      expect(isValidPersonRef('a' * 33), isFalse);
      expect(isValidPersonRef('NIP 123'), isFalse);
      expect(isValidPersonRef('NIP/123'), isFalse);
    });
  });

  group('enrollChallenge', () {
    test('berisi lima arah, masing-masing sekali', () {
      final challenge = enrollChallenge(Random(1));

      expect(challenge.length, 5);
      expect(challenge.toSet(), kEnrollPrompts.keys.toSet());
    });

    test('urutan berbeda untuk seed yang berbeda', () {
      final orders = {
        for (var seed = 0; seed < 20; seed++)
          enrollChallenge(Random(seed)).join(','),
      };

      expect(orders.length, greaterThan(1));
    });
  });
}

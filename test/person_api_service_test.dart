import 'dart:convert';
import 'package:face_presensi/data/person_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PersonApiService mode demo (URL kosong)', () {
    test('tidak memantulkan ID personal ke data yang ditampilkan', () async {
      const secret = '4693a230-4901-4301-9465-953c86cf59ac';

      final res = await PersonApiService(apiUrl: '').sendPersonId(secret);

      expect(res.ok, isTrue);
      expect(jsonEncode(res.data), isNot(contains(secret)));
      expect(res.message, isNot(contains(secret)));
    });
  });
}

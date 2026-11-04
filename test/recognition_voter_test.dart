import 'package:face_presensi/core/face/recognition_voter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecognitionVoter', () {
    test('mengonfirmasi setelah suara berurutan mencukupi', () {
      final voter = RecognitionVoter(3);

      expect(voter.vote('A'), isFalse);
      expect(voter.vote('A'), isFalse);
      expect(voter.vote('A'), isTrue);
    });

    test('identitas berganti mengulang hitungan', () {
      final voter = RecognitionVoter(3);

      voter.vote('A');
      voter.vote('A');
      expect(voter.vote('B'), isFalse);
      expect(voter.votes, 1);
      expect(voter.vote('B'), isFalse);
      expect(voter.vote('B'), isTrue);
    });

    test('frame tanpa kandidat memutus rangkaian', () {
      final voter = RecognitionVoter(3);

      voter.vote('A');
      voter.vote('A');
      expect(voter.vote(null), isFalse);
      expect(voter.votes, 0);
      expect(voter.vote('A'), isFalse);
    });

    test('tetap terkonfirmasi selama ID yang sama berlanjut', () {
      final voter = RecognitionVoter(2);

      voter.vote('A');
      expect(voter.vote('A'), isTrue);
      expect(voter.vote('A'), isTrue);
    });

    test('reset menghapus kandidat', () {
      final voter = RecognitionVoter(2);

      voter.vote('A');
      voter.reset();
      expect(voter.vote('A'), isFalse);
    });
  });
}

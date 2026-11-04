/// Mengonfirmasi identitas hanya bila [requiredVotes] frame berurutan memilih
/// identitas yang sama. Frame tanpa kandidat memutus rangkaian.
class RecognitionVoter {
  RecognitionVoter(this.requiredVotes);

  final int requiredVotes;
  String? _candidate;
  int _count = 0;

  /// Jumlah suara berurutan untuk kandidat saat ini.
  int get votes => _count;

  /// Mencatat satu frame. [name] `null` berarti tidak ada kandidat.
  /// Mengembalikan `true` bila [name] sudah terkonfirmasi.
  bool vote(String? name) {
    if (name == null) {
      reset();
      return false;
    }
    if (name == _candidate) {
      _count++;
    } else {
      _candidate = name;
      _count = 1;
    }
    return _count >= requiredVotes;
  }

  void reset() {
    _candidate = null;
    _count = 0;
  }
}

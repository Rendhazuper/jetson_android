/// Teks persetujuan pemrosesan data wajah, disalin dari halaman /rekam.
/// Masih DRAF dan menunggu tinjauan bagian hukum Universitas Jember.
library;

class ConsentSection {
  const ConsentSection(this.title, this.body);

  final String title;
  final String body;
}

const String kConsentDraftNotice =
    'DRAF — menunggu tinjauan bagian hukum Universitas Jember. '
    'Belum boleh dipakai untuk pendaftaran sungguhan.';

const String kConsentHeading =
    'Persetujuan Pemrosesan Data Wajah (Data Biometrik)';

const String kConsentIntro =
    'Sistem SmartDoor UPATIK Universitas Jember akan merekam dan memproses '
    'data wajah Anda. Data wajah termasuk data pribadi yang bersifat spesifik '
    'menurut Undang-Undang Nomor 27 Tahun 2022 tentang Pelindungan Data '
    'Pribadi, sehingga hanya diproses dengan persetujuan Anda.';

const List<ConsentSection> kConsentSections = [
  ConsentSection(
    '1. Pengendali data',
    'UPT Teknologi Informasi dan Komunikasi (UPATIK) Universitas Jember, '
        '[alamat kantor].',
  ),
  ConsentSection(
    '2. Dasar dan tujuan pemrosesan',
    'Dasar pemrosesan adalah persetujuan eksplisit Anda melalui halaman ini '
        '(UU PDP Pasal 20 dan 22). Tujuannya: Mengenali identitas orang yang '
        'melewati pintu gedung UPATIK untuk pencatatan keluar-masuk dan '
        'keamanan gedung. Data wajah tidak digunakan untuk presensi, penilaian '
        'kinerja, atau tujuan lain tanpa pemberitahuan dan persetujuan terpisah.',
  ),
  ConsentSection(
    '3. Data yang dikumpulkan',
    'Video wajah sekitar 18 detik tanpa suara, saat Anda menoleh mengikuti '
        'perintah di layar. Hingga 11 gambar wajah dari beberapa sudut yang '
        'diambil dari video tersebut, beserta ukuran sudutnya. Nomor identitas '
        '(NIP/NIM/NIK), waktu pendaftaran, jenis perangkat perekam, dan nama '
        'petugas yang mendampingi. Kelak, saat Anda melewati pintu: waktu lewat '
        'dan hasil pengenalan wajah.',
  ),
  ConsentSection(
    '4. Cara pemrosesan dan penyimpanan',
    'Video dihapus segera setelah gambar wajah selesai diambil, biasanya '
        'dalam beberapa menit. Gambar wajah disimpan di server penyimpanan milik '
        'Universitas Jember dan diolah menjadi data pengenal wajah untuk '
        'perangkat di pintu gedung. Data hanya dapat diakses petugas UPATIK yang '
        'berwenang dan tidak dibagikan kepada pihak ketiga, kecuali diwajibkan '
        'peraturan perundang-undangan.',
  ),
  ConsentSection(
    '5. Jangka waktu pemrosesan dan masa simpan',
    'Video: diproses sekali saat pendaftaran, lalu dihapus segera setelahnya. '
        'Gambar dan data pengenal wajah: diproses dan disimpan selama Anda '
        'berstatus aktif sebagai pegawai/mahasiswa Universitas Jember, lalu '
        'dihapus paling lambat [jangka waktu, mis. 30 hari] setelah status '
        'tersebut berakhir atau setelah Anda menarik persetujuan. Catatan '
        'pendaftaran dan bukti persetujuan: disimpan [jangka waktu] untuk '
        'keperluan pertanggungjawaban.',
  ),
  ConsentSection(
    '6. Hak Anda (UU PDP Pasal 5–15)',
    'mendapat informasi tentang pemrosesan ini, serta mengakses dan meminta '
        'salinan data Anda; melengkapi atau memperbaiki data yang keliru, '
        'misalnya nomor identitas; mengakhiri pemrosesan dan meminta data wajah '
        'Anda dihapus atau dimusnahkan; menarik kembali persetujuan kapan saja; '
        'mengajukan keberatan atas keputusan yang semata-mata didasarkan pada '
        'pemrosesan otomatis, termasuk pengenalan wajah; menunda atau membatasi '
        'pemrosesan; mendapatkan data Anda dalam format yang umum dan dapat '
        'dibaca sistem elektronik; menggugat dan menerima ganti rugi atas '
        'pelanggaran pemrosesan data Anda. Penarikan persetujuan tidak '
        'memengaruhi keabsahan pemrosesan yang telah dilakukan sebelumnya.',
  ),
  ConsentSection(
    '7. Persetujuan bersifat sukarela',
    'Anda boleh menolak tanpa konsekuensi. Bila menolak atau kelak menarik '
        'persetujuan, Anda tetap dapat masuk gedung melalui [cara alternatif, '
        'mis. kartu identitas atau pencatatan oleh petugas].',
  ),
  ConsentSection(
    '8. Kontak',
    'Pertanyaan, permintaan salinan, penghapusan data, atau penarikan '
        'persetujuan: [nama/jabatan pejabat pelindungan data], [email], '
        '[telepon], atau langsung ke kantor UPATIK.',
  ),
  ConsentSection(
    '9. Pencatatan persetujuan',
    'Persetujuan Anda dicatat secara elektronik (UU PDP Pasal 22): versi teks '
        'persetujuan ini, waktu persetujuan, nomor identitas, dan petugas yang '
        'mendampingi. Versi persetujuan: consent_v1 · [tanggal berlaku] · Dasar '
        'hukum: Undang-Undang Nomor 27 Tahun 2022 tentang Pelindungan Data '
        'Pribadi',
  ),
];

const String kConsentCheckLabel =
    'Saya, pemilik nomor identitas yang didaftarkan, telah membaca atau '
    'dibacakan ketentuan di atas, memahaminya, dan secara sukarela menyetujui '
    'perekaman serta pemrosesan data wajah saya untuk tujuan tersebut.';

import 'dart:math';

const List<Map<String, dynamic>> _marawisQuestionBank = [
  {
    'q': 'Apa tujuan utama latihan bersama?',
    'a': ['Menyamakan tempo dan kekompakan', 'Membuat anggota bersaing', 'Menghindari evaluasi', 'Mempercepat latihan tanpa arahan'],
    'c': 0,
  },
  {
    'q': 'Saat pemimpin memberi aba-aba, anggota sebaiknya...',
    'a': ['Mengabaikannya', 'Mendengarkan dan mengikuti', 'Bermain lebih cepat sendiri', 'Berbicara dengan teman'],
    'c': 1,
  },
  {
    'q': 'Setelah latihan, alat musik sebaiknya...',
    'a': ['Ditinggalkan di lantai', 'Dibersihkan seperlunya dan disimpan dengan baik', 'Dibawa pulang tanpa izin', 'Ditumpuk sembarangan'],
    'c': 1,
  },
  {
    'q': 'Apa yang perlu dijaga saat tampil bersama?',
    'a': ['Tempo, formasi, dan koordinasi', 'Hanya penampilan sendiri', 'Bermain sekeras mungkin', 'Mengubah susunan secara mendadak'],
    'c': 0,
  },
  {
    'q': 'Jika teman belum menguasai bagian lagu, tindakan terbaik adalah...',
    'a': ['Mengejeknya', 'Membiarkannya sendiri', 'Membantu latihan dengan sabar', 'Mengeluarkannya dari kelompok'],
    'c': 2,
  },
  {
    'q': 'Sebelum latihan dimulai, hal yang baik dilakukan adalah...',
    'a': ['Langsung bermain tanpa persiapan', 'Menunggu orang lain menyiapkan semuanya', 'Menyiapkan alat dan area latihan', 'Mengubah jadwal sendiri'],
    'c': 2,
  },
  {
    'q': 'Jika tempo permainan mulai tidak seragam, anggota sebaiknya...',
    'a': ['Mempercepat permainan sendiri', 'Mendengarkan ketukan dan kembali mengikuti arahan', 'Berhenti tanpa memberi tahu kelompok', 'Mengabaikan anggota lain'],
    'c': 1,
  },
  {
    'q': 'Jika tidak dapat hadir latihan, anggota sebaiknya...',
    'a': ['Tidak memberi kabar', 'Meminta teman mengisi daftar hadir', 'Memberi tahu pengurus atau pembina', 'Menghapus jadwal latihan'],
    'c': 2,
  },
  {
    'q': 'Apa manfaat evaluasi setelah penampilan?',
    'a': ['Mengetahui hal yang sudah baik dan yang perlu diperbaiki', 'Mencari kesalahan satu orang saja', 'Menghindari latihan berikutnya', 'Mengubah semua keputusan tanpa diskusi'],
    'c': 0,
  },
  {
    'q': 'Saat meminjam alat milik kelompok, kita harus...',
    'a': ['Mengambilnya tanpa izin', 'Meminta izin dan mengembalikannya dengan baik', 'Memberikannya kepada orang lain tanpa kabar', 'Menyimpannya tanpa batas waktu'],
    'c': 1,
  },
  {
    'q': 'Informasi jadwal kegiatan resmi sebaiknya diperoleh dari...',
    'a': ['Pesan yang belum jelas sumbernya', 'Tebakan teman', 'Pengumuman resmi dari pengurus atau pembina', 'Jadwal lama yang belum diperbarui'],
    'c': 2,
  },
  {
    'q': 'Agar tugas program kerja selesai tepat waktu, anggota perlu...',
    'a': ['Memahami tugas dan tenggat lalu memperbarui progres', 'Menunggu sampai diingatkan', 'Mengubah tenggat sendiri', 'Menyerahkan tugas tanpa pemeriksaan'],
    'c': 0,
  },
  {
    'q': 'Pencatatan uang kas yang baik harus...',
    'a': ['Disimpan oleh satu orang tanpa catatan', 'Jelas, jujur, dan dapat diperiksa pengurus', 'Diubah jika ada selisih', 'Diumumkan tanpa memeriksa bukti'],
    'c': 1,
  },
  {
    'q': 'Ketika ada perbedaan pendapat dalam tim, sebaiknya...',
    'a': ['Memaksakan pendapat sendiri', 'Membicarakannya di luar konteks', 'Berdiskusi dengan sopan dan mencari kesepakatan', 'Menghentikan semua kegiatan'],
    'c': 2,
  },
  {
    'q': 'Saat latihan, volume permainan sebaiknya...',
    'a': ['Disesuaikan dengan arahan dan kebutuhan kelompok', 'Selalu paling keras', 'Berbeda-beda tanpa koordinasi', 'Dinaikkan agar menutupi kesalahan'],
    'c': 0,
  },
  {
    'q': 'Saat teman melakukan kesalahan ketika latihan, sikap yang tepat adalah...',
    'a': ['Menertawakannya', 'Memberi dukungan dan membantu memperbaiki bagian tersebut', 'Menghentikan latihan untuk menyalahkannya', 'Membiarkannya tanpa arahan'],
    'c': 1,
  },
];

/// Membuat seed stabil agar anggota mendapat susunan tantangan yang sama
/// ketika membuka ulang aplikasi pada minggu yang sama.
int marawisChallengeSeed(String userId, String gameKey) {
  var hash = 0x811C9DC5;
  for (final codeUnit in '$userId|$gameKey'.codeUnits) {
    hash = ((hash ^ codeUnit) * 0x01000193) & 0x7FFFFFFF;
  }
  return hash;
}

/// Memilih pertanyaan secara acak tanpa pengulangan untuk satu tantangan.
List<Map<String, dynamic>> createRandomMarawisChallenge({
  required int seed,
  int questionCount = 5,
}) {
  if (questionCount < 1 || questionCount > _marawisQuestionBank.length) {
    throw ArgumentError.value(
      questionCount,
      'questionCount',
      'Must be between 1 and 16.',
    );
  }

  final shuffled = List<Map<String, dynamic>>.of(_marawisQuestionBank)
    ..shuffle(Random(seed));

  return shuffled.take(questionCount).map((question) {
    return Map<String, dynamic>.unmodifiable({
      'q': question['q'],
      'a': List<String>.unmodifiable(
        List<String>.from(question['a'] as List<String>),
      ),
      'c': question['c'],
    });
  }).toList(growable: false);
}

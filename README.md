# Marawis Smpn99

Aplikasi manajemen organisasi Marawis SMPN 99 Jakarta untuk periode 2026/2027.

## Modul aplikasi

- Login Google melalui Supabase Auth.
- Role Anggota, Pengurus, dan Pembina. Pengurus serta Pembina memiliki akses pengelolaan yang setara.
- Profil, foto, kelas, bio, dan direktori anggota.
- Pengumuman dan pusat notifikasi dalam aplikasi.
- Jadwal kegiatan dan pencatatan absensi.
- Uang kas, pengajuan pembayaran, verifikasi, dan pencatatan pengeluaran.
- Program kerja, penanggung jawab, tanggal mulai/tenggat, tugas, dan leaderboard.

## Persiapan Supabase

1. Pastikan project Supabase yang digunakan sesuai dengan URL dan publishable key di `lib/main.dart`.
2. Terapkan migration SQL secara berurutan: `202611090001_profiles_roles.sql` sampai `202611090005_profile_edit_and_storage.sql`. Periksa migration history terlebih dahulu agar migration yang sudah diterapkan tidak dijalankan ulang secara manual.
3. Aktifkan Google sebagai provider pada Supabase Authentication dan masukkan Google OAuth Client ID serta Client Secret langsung melalui dashboard Supabase. Jangan simpan Client Secret atau service-role key di repository.
4. Tambahkan `marawissmpn99://login-callback` ke daftar Redirect URLs Supabase Auth. OAuth redirect URI yang digunakan Google harus mengikuti callback URL yang ditampilkan oleh konfigurasi provider Supabase.
5. Workflow Android membuat platform Android saat build dan memasang intent filter untuk `marawissmpn99://login-callback`. Uji alur login di perangkat Android setelah konfigurasi provider selesai.

### Menetapkan admin pertama

Akun Google baru otomatis mendapat role `anggota`. Setelah akun pengurus/pembina pertama berhasil login dan profilnya terbentuk, admin project perlu menetapkan satu akun awal melalui Supabase SQL Editor, dengan mengganti alamat contoh berikut:

```sql
update public.profiles
set role = 'pengurus', updated_at = now()
where email = 'EMAIL_PENGURUS';
```

Setelah admin pertama tersedia, role akun lain dapat dikelola dari Direktori Anggota di aplikasi. Role tidak dapat dipilih atau dinaikkan dari layar login.

## CI dan build Android

Workflow `.github/workflows/build-apk.yml` menjalankan:

1. `flutter pub get`
2. `flutter analyze lib`
3. `flutter test`
4. `flutter build apk --release`

APK hanya diunggah sebagai artifact workflow setelah seluruh langkah berhasil. Artifact disimpan selama 14 hari.

## Batasan yang perlu diketahui

- Notifikasi saat ini adalah notifikasi dalam aplikasi, bukan push notification Android.
- Login Google dan operasi database harus diuji pada project Supabase sebenarnya setelah konfigurasi provider dan migration tersedia.
- Repository tidak menyimpan kredensial privat. Jangan pernah memasukkan service-role key, Google OAuth Client Secret, atau password ke source code maupun GitHub Actions log.

# Marawis Smpn99

Aplikasi manajemen organisasi Marawis SMPN 99 Jakarta untuk periode 2026/2027.

## Modul aplikasi

- Login Google melalui Supabase Auth.
- Tiga pilihan login: Anggota, Pengurus, dan Pembina. Pengurus serta Pembina memiliki akses pengelolaan yang setara; dua role staf memakai password kedua yang sama.
- Profil, foto, kelas, bio, dan direktori anggota.
- Pengumuman dan pusat notifikasi dalam aplikasi.
- Jadwal kegiatan dan pencatatan absensi.
- Uang kas, pengajuan pembayaran, verifikasi, dan pencatatan pengeluaran.
- Program kerja, penanggung jawab, tanggal mulai/tenggat, tugas, dan leaderboard.

## Persiapan Supabase

1. Pastikan project Supabase yang digunakan sesuai dengan URL dan publishable key di `lib/main.dart`.
2. Terapkan migration SQL sesuai urutan dan migration history Supabase: `202611090001_profiles_roles.sql` sampai `202611090005_profile_edit_and_storage.sql`, lalu migration keamanan staf `20261116122211_secure_shared_staff_password_access.sql` dan `20261116122659_grant_staff_access_function_privileges.sql`.
3. Aktifkan Google sebagai provider pada Supabase Authentication dan masukkan Google OAuth Client ID serta Client Secret langsung melalui dashboard Supabase. Jangan simpan Client Secret atau service-role key di repository.
4. Tambahkan `marawissmpn99://login-callback` ke daftar Redirect URLs Supabase Auth. OAuth redirect URI yang digunakan Google harus mengikuti callback URL yang ditampilkan oleh konfigurasi provider Supabase.
5. Workflow Android membuat platform Android saat build dan memasang intent filter untuk `marawissmpn99://login-callback`. Uji alur login di perangkat Android setelah konfigurasi provider selesai.

### Password kedua Pengurus dan Pembina

1. Deploy Edge Function `supabase/functions/marawis-staff-access/index.ts` dengan nama `marawis-staff-access` dan JWT verification tetap aktif.
2. Di Supabase Dashboard buka **Project Settings / Edge Functions / Secrets** (atau **Edge Functions / Secrets**, sesuai tampilan dashboard) dan tambahkan secret bernama `MARAWIS_STAFF_PASSWORD`.
3. Isi nilainya dengan password kuat yang hanya dibagikan kepada Pengurus dan Pembina. Gunakan password yang sama untuk kedua role. Jangan kirim password melalui chat, jangan masukkan ke APK, dan jangan commit ke GitHub.
4. Akun Google yang memilih Pengurus atau Pembina akan diminta password kedua. Server memeriksa password dan memberi batas lima percobaan per akun setiap sepuluh menit sebelum mengubah `profiles.role`.

Akun yang memilih Anggota tidak memerlukan password kedua. Semua akun tetap harus login melalui Google.

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

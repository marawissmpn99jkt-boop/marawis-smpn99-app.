# Marawis Smpn99

Aplikasi manajemen organisasi Marawis SMPN 99 Jakarta untuk periode 2026/2027.

## Modul aplikasi

- Login Google melalui Supabase Auth.
- Role Anggota, Pengurus, dan Pembina. Pengurus serta Pembina memiliki akses pengelolaan yang setara; akses staf memerlukan verifikasi password kedua di server.
- Profil, foto, kelas, bio, dan direktori anggota.
- Pengumuman dan pusat notifikasi dalam aplikasi.
- Jadwal kegiatan yang dapat dibuat, diedit, dan dihapus.
- Absensi dengan status yang harus dipilih secara eksplisit untuk setiap anggota aktif.
- Uang kas, pengajuan pembayaran, bukti transfer privat, verifikasi, dan pencatatan pengeluaran.
- Program kerja, penanggung jawab, tanggal mulai/tenggat, tugas yang dapat diperbarui statusnya oleh penanggung jawab, dan leaderboard.

## Supabase

Project Supabase yang terhubung dengan aplikasi adalah **Marawis Smpn99**. URL dan publishable key client berada di `lib/main.dart`. Publishable key memang digunakan oleh aplikasi client; jangan pernah menaruh service-role key atau kredensial privat di source code.

### Migration database

Untuk project Supabase baru, jalankan file di `supabase/migrations` menurut urutan timestamp, satu kali, setelah memeriksa target project.

**Penting untuk project produksi yang sudah berjalan:** pada pemeriksaan 17 November 2026, tabel inti, trigger, RLS, dan bucket foto profil dari migration `202611090001` sampai `202611090005` sudah ada di database, tetapi kelima versi awal tersebut tidak tercatat pada `schema_migrations`. Jangan menjalankan `db reset` atau melakukan push migration secara membabi buta ke project ini. Rekonsiliasi metadata migration terlebih dahulu dengan kondisi schema produksi dan backup yang sesuai; jangan mengulang migration dasar hanya untuk mengisi riwayat.

Migration keamanan yang tercatat di project produksi:
- `20261116121337_revoke_execute_from_trigger_functions.sql`
- `20261116122211_secure_shared_staff_password_access.sql`
- `20261116122659_grant_staff_access_function_privileges.sql`
- `20261117062422_cash_payment_proofs.sql`
- `20261117063834_assigned_task_status_updates.sql`

Migration `20261117063834_assigned_task_status_updates` sudah tercatat diterapkan pada database produksi; file sumbernya kini ikut disimpan di repository. Migration ini membatasi anggota yang ditugaskan agar hanya dapat mengubah status tugasnya sendiri.

Migration bukti transfer membuat bucket **private** `cash-payment-proofs` dengan batas 5 MB. Path objek disimpan di `cash_payments.proof_url`; aplikasi membuat signed URL sementara untuk pemilik pembayaran atau admin. Policy upload/delete membatasi anggota pada folder dengan user ID mereka sendiri, sedangkan Pengurus/Pembina dapat membaca bukti untuk verifikasi.

### Login Google dan akses staf

1. Aktifkan Google sebagai provider pada Supabase Authentication.
2. Masukkan Google OAuth Client ID dan Client Secret langsung melalui dashboard Supabase. Jangan simpan Client Secret atau service-role key di repository.
3. Tambahkan redirect berikut ke daftar Redirect URLs Supabase Auth:
   - `marawissmpn99://login-callback` untuk Android.
   - `https://marawissmpn99jkt-boop.github.io/marawis-smpn99-app./` untuk web GitHub Pages.
4. OAuth redirect URI yang digunakan pada Google Cloud harus mengikuti callback URL yang ditampilkan oleh konfigurasi provider Supabase.
5. Workflow Android memasang intent filter untuk `marawissmpn99://login-callback`.

### Password kedua Pengurus dan Pembina

1. Source Edge Function tersedia di `supabase/functions/marawis-staff-access/index.ts`. Deploy dengan nama `marawis-staff-access` dan JWT verification tetap aktif. Source tersebut disinkronkan dari versi aktif yang terpasang pada project.
2. Di Supabase Dashboard, tambahkan secret bernama `MARAWIS_STAFF_PASSWORD` pada Edge Function Secrets. Nilainya hanya boleh disimpan di dashboard Supabase.
3. Gunakan password kuat yang hanya dibagikan kepada Pengurus dan Pembina. Keduanya memakai password kedua yang sama.
4. Server membatasi lima percobaan per akun dalam sepuluh menit sebelum memperbarui role.

Akun Anggota tidak memerlukan password kedua. Semua akun tetap harus login melalui Google.

## CI, web, dan APK rilis

- Workflow web berjalan pada setiap push ke `main`; workflow ini menjalankan `flutter analyze lib`, `flutter test`, membangun Flutter Web, lalu deploy ke GitHub Pages.
- Workflow APK tidak berjalan pada setiap commit. Jalankan secara manual atau melalui GitHub Release setelah fitur utama dan pengujian siap.
- APK rilis wajib menggunakan keystore rilis yang stabil, bukan debug keystore. Siapkan GitHub Actions secrets berikut sebelum menjalankan workflow APK:
  - `ANDROID_KEYSTORE_BASE64`
  - `ANDROID_KEYSTORE_PASSWORD`
  - `ANDROID_KEY_ALIAS`
  - `ANDROID_KEY_PASSWORD`
- Simpan cadangan keystore secara aman. Keystore yang sama harus dipakai untuk pembaruan aplikasi berikutnya.

## Batasan yang perlu diketahui

- Notifikasi saat ini adalah notifikasi dalam aplikasi, bukan push notification Android.
- Project sudah memiliki identitas Google, tetapi alur login baru tetap perlu diuji pada perangkat/browser setelah redirect URL diverifikasi.
- Secret `MARAWIS_STAFF_PASSWORD` tidak dapat dibaca kembali melalui pemeriksaan project; pastikan secret sudah diatur di dashboard sebelum menguji akses Pengurus/Pembina.
- Status Google OAuth provider dan redirect allowlist belum dapat diverifikasi melalui pemeriksaan metadata project; lakukan uji login nyata pada perangkat/browser setelah konfigurasi dashboard dipastikan.
- Data produksi tidak digunakan sebagai data uji. Alur tulis setiap modul tetap perlu diuji dengan akun uji dan data uji terkontrol sebelum rilis.
- Jangan pernah memasukkan service-role key, Google OAuth Client Secret, password, atau keystore ke source code maupun log GitHub Actions.

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'auth_roles.dart';
import 'profile_edit_screen.dart';
import 'notifications_screen.dart';
import 'announcements_screen.dart';
import 'activities_screen.dart';
import 'attendance_screen.dart';
import 'cash_screen.dart';
import 'members_screen.dart';
import 'work_programs_screen.dart';
import 'community_hub_screen.dart';
import 'management_hub_screen.dart';
import 'marawis_smart_screen.dart';

const supabaseUrl = 'https://yatbnzczricrwrqhzsqr.supabase.co';
const supabasePublishableKey = 'sb_publishable_Uz6EYSbI3Nhj28uP3lEFsw_nCbEYMHS';
const authRedirectUrl = 'marawissmpn99://login-callback/';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  if (kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyDhheS0I6mMsOmQJalwCMMfQtw1Tf48TmY',
          authDomain: 'marawis-smpn-99.firebaseapp.com',
          projectId: 'marawis-smpn-99',
          storageBucket: 'marawis-smpn-99.firebasestorage.app',
          messagingSenderId: '482698289502',
          appId: '1:482698289502:web:32bc392bbdd0aa278eefcf',
          measurementId: 'G-RZQTDNW4PH',
        ),
      );
      FirebaseMessaging.onMessage.listen((message) {
        // Foreground push events can be handled by the active app UI.
      });
    } catch (error) {
      debugPrint('Firebase Messaging initialization failed: $error');
    }
  }
  runApp(const MarawisApp());
}

class MarawisApp extends StatelessWidget {
  const MarawisApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF167D68);
    return MaterialApp(
      title: 'Marawis Smpn99',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          surface: const Color(0xFFF7F9F7),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9F7),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF172A25),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
          iconTheme: IconThemeData(color: Color(0xFF263B34)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: Color(0xFFE4EBE7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: Color(0xFFE4EBE7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: seed, width: 1.6),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: seed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        dividerColor: const Color(0xFFE8EEEA),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = client.auth.currentUser;
        if (user == null) return const GuestHomeScreen();
        return _ProfileGate(user: user);
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({required this.user});
  final User user;

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<Map<String, dynamic>?> _loadProfile() async {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('full_name, email, avatar_url, role')
        .eq('id', widget.user.id)
        .maybeSingle();
    if (response == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final pendingRole = prefs.getString('marawis_pending_staff_role');
    if (pendingRole == 'pengurus' || pendingRole == 'pembina') {
      return {...response, '_pending_staff_role': pendingRole};
    }
    return response;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sync_problem_rounded, size: 42),
                    const SizedBox(height: 12),
                    const Text(
                      'Profil belum tersedia',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Database profil belum siap atau akun belum tersinkron. Pastikan migrasi database sudah dijalankan.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => _profileFuture = _loadProfile()),
                      child: const Text('Coba lagi'),
                    ),
                    TextButton(
                      onPressed: () => Supabase.instance.client.auth.signOut(),
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final profile = snapshot.data!;
        final role = (profile['role'] ?? 'anggota').toString();
        if (!['anggota', 'pengurus', 'pembina'].contains(role)) {
          return const Scaffold(
            body: Center(child: Text('Role akun tidak dikenali. Hubungi admin.')),
          );
        }
        final pendingRole = profile['_pending_staff_role']?.toString();
        final staffRole = requiredStaffVerificationRole(
          profileRole: role,
          pendingRole: pendingRole,
        );
        if (staffRole != null) {
          return StaffAccessScreen(user: widget.user, role: staffRole);
        }
        return HomeScreen(user: widget.user, role: role, profile: profile);
      },
    );
  }
}

class GuestHomeScreen extends StatelessWidget {
  const GuestHomeScreen({super.key});

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final features = <({IconData icon, String title, String detail, Color tint})>[
      (icon: Icons.calendar_month_rounded, title: 'Jadwal kegiatan', detail: 'Latihan, rapat, dan penampilan', tint: Color(0xFFE8F3EE)),
      (icon: Icons.fact_check_rounded, title: 'Absensi', detail: 'Pantau kehadiran latihan', tint: Color(0xFFEAF0FF)),
      (icon: Icons.account_balance_wallet_rounded, title: 'Uang kas', detail: 'Pembayaran dan transparansi kas', tint: Color(0xFFFFF1E4)),
      (icon: Icons.groups_rounded, title: 'Direktori anggota', detail: 'Kenali anggota dan pengurus', tint: Color(0xFFF1EAFE)),
      (icon: Icons.assignment_rounded, title: 'Program kerja', detail: 'Rencana, tugas, dan progres', tint: Color(0xFFE6F4F1)),
      (icon: Icons.campaign_rounded, title: 'Pengumuman', detail: 'Informasi resmi organisasi', tint: Color(0xFFFFF0F0)),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFE3F2EC),
              child: Icon(Icons.music_note_rounded, color: Color(0xFF167D68)),
            ),
            SizedBox(width: 10),
            Text('Marawis SMPN 99'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              tooltip: 'Masuk / akun',
              onPressed: () => _openLogin(context),
              icon: const Icon(Icons.person_outline_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 36),
              children: [
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF123F35), Color(0xFF167D68), Color(0xFF259B7C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -16,
                        top: -22,
                        child: Icon(Icons.graphic_eq_rounded, size: 150, color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Text(
                              'RUANG DIGITAL ORGANISASI',
                              style: TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Satu irama.\nSatu tujuan.\nSatu keluarga.',
                            style: TextStyle(color: Colors.white, fontSize: 32, height: 1.12, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Selamat datang di pusat informasi dan kegiatan Marawis SMPN 99 Jakarta.',
                            style: TextStyle(color: Colors.white70, height: 1.55, fontSize: 13),
                          ),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: () => _openLogin(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF145B49),
                            ),
                            icon: const Icon(Icons.login_rounded, size: 18),
                            label: const Text('Masuk ke akun'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Text('Semua kebutuhan Marawis, dalam satu tempat',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF1B3029))),
                const SizedBox(height: 7),
                const Text('Pilih menu setelah masuk untuk melihat data dan aktivitas organisasi.',
                  style: TextStyle(color: Color(0xFF74837B), height: 1.5, fontSize: 13)),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 760 ? 3 : constraints.maxWidth >= 500 ? 2 : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: features.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 112,
                      ),
                      itemBuilder: (context, index) {
                        final item = features[index];
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () => _openLogin(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE6ECE8)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(color: item.tint, borderRadius: BorderRadius.circular(15)),
                                    child: Icon(item.icon, color: const Color(0xFF167D68)),
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                        const SizedBox(height: 5),
                                        Text(item.detail, style: const TextStyle(color: Color(0xFF7B8982), fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF9AA69F)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 26),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4EF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xFF167D68), size: 25),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Akses data organisasi dilindungi. Silakan masuk menggunakan akun Google yang terdaftar.',
                          style: TextStyle(color: Color(0xFF345B4D), fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Center(
                  child: Text('MARAWIS SMPN 99 JAKARTA • 2026/2027',
                    style: TextStyle(color: Color(0xFF9AA69F), fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  Future<void> _signInWithGoogle(String role) async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    if (role == 'pengurus' || role == 'pembina') {
      await prefs.setString('marawis_pending_staff_role', role);
    } else {
      await prefs.remove('marawis_pending_staff_role');
    }
    try {
      final redirectUrl = kIsWeb ? Uri.base.toString() : authRedirectUrl;
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const AuthException('Halaman login Google gagal dibuka. Coba lagi.');
      }
    } catch (error) {
      await prefs.remove('marawis_pending_staff_role');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memulai login: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _loginChoice({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        onPressed: _loading ? null : () => _signInWithGoogle(role),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 23),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
            if (_loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            else
              const Icon(Icons.arrow_forward_rounded, size: 19),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Masuk ke akun Marawis')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2EC),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Color(0xFF167D68),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Marawis Smpn99',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Satu irama, satu tujuan, satu keluarga.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF78877F), fontSize: 13),
                ),
                const SizedBox(height: 42),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE8EEEA)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Selamat datang!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Masuk untuk mengakses informasi dan kegiatan anggota Marawis.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF78877F),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Pilih jenis akses. Semua akun masuk dengan Google. Pengurus dan Pembina wajib melewati verifikasi password kedua.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF78877F),
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _loginChoice(
                        role: 'anggota',
                        title: 'Login Anggota',
                        subtitle: 'Akses anggota Marawis',
                        icon: Icons.groups_rounded,
                        color: const Color(0xFF167D68),
                      ),
                      const SizedBox(height: 10),
                      _loginChoice(
                        role: 'pengurus',
                        title: 'Login Pengurus',
                        subtitle: 'Google + password kedua',
                        icon: Icons.admin_panel_settings_rounded,
                        color: const Color(0xFF4268C5),
                      ),
                      const SizedBox(height: 10),
                      _loginChoice(
                        role: 'pembina',
                        title: 'Login Pembina',
                        subtitle: 'Google + password kedua',
                        icon: Icons.school_rounded,
                        color: const Color(0xFFC47A25),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'MARAWIS SMPN 99 JAKARTA • 2026/2027',
                  style: TextStyle(
                    color: Color(0xFF9AA69F),
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class StaffAccessScreen extends StatefulWidget {
  const StaffAccessScreen({super.key, required this.user, required this.role});

  final User user;
  final String role;

  @override
  State<StaffAccessScreen> createState() => _StaffAccessScreenState();
}

class _StaffAccessScreenState extends State<StaffAccessScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_password.text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'marawis-staff-access',
        body: {'role': widget.role, 'password': _password.text},
      );
      if (response.status < 200 || response.status >= 300) {
        final data = response.data;
        final reason = data is Map ? data['error']?.toString() : null;
        throw Exception(reason ?? 'Verifikasi gagal. Coba lagi.');
      }
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, email, avatar_url, role')
          .eq('id', widget.user.id)
          .maybeSingle();
      if (profile == null) {
        throw Exception('Profil belum ditemukan setelah verifikasi.');
      }
      final verifiedRole = (profile['role'] ?? '').toString();
      if (verifiedRole != 'pengurus' && verifiedRole != 'pembina') {
        throw Exception('Role staf belum berhasil diperbarui. Coba lagi.');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('marawis_pending_staff_role');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            user: widget.user,
            role: verifiedRole,
            profile: profile,
          ),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('marawis_pending_staff_role');
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final isPengurus = widget.role == 'pengurus';
    final title = isPengurus ? 'Verifikasi Pengurus' : 'Verifikasi Pembina';
    final color = isPengurus ? const Color(0xFF4268C5) : const Color(0xFFC47A25);
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: _busy ? null : _cancel, child: const Text('Batal')),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(
                      isPengurus ? Icons.admin_panel_settings_rounded : Icons.school_rounded,
                      color: color,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text(
                    'Masukkan password kedua yang hanya dibagikan kepada Pengurus dan Pembina Marawis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF78877F), height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    enabled: !_busy,
                    onSubmitted: (_) => _verify(),
                    decoration: InputDecoration(
                      labelText: 'Password kedua',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _busy ? null : _verify,
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Verifikasi dan masuk', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.role,
    required this.profile,
  });

  final User user;
  final String role;
  final Map<String, dynamic> profile;

  Future<void> _signOut(BuildContext context) async {
    final client = Supabase.instance.client;
    try {
      // Clear the pending staff-verification choice so it cannot affect
      // the next sign-in after this account has been logged out.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('marawis_pending_staff_role');

      // Explicitly end the local Supabase session (also works for web).
      await client.auth.signOut(scope: SignOutScope.local);

      if (!context.mounted) return;
      if (client.auth.currentSession != null) {
        throw const AuthException('Sesi akun masih aktif. Coba keluar sekali lagi.');
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal keluar: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openProfileEditor(BuildContext context) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(user: user, profile: profile),
      ),
    );
    if (updated == true && context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => _ProfileGate(user: user)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = user.userMetadata ?? <String, dynamic>{};
    final displayName = (profile['full_name'] ??
            metadata['full_name'] ??
            metadata['name'] ??
            user.email?.split('@').first ??
            'Anggota')
        .toString();
    final avatarUrl = (profile['avatar_url'] ?? metadata['avatar_url'])?.toString();
    final roleLabel = role == 'pengurus'
        ? 'Pengurus'
        : role == 'pembina'
            ? 'Pembina'
            : 'Anggota';
    final isAdmin = role == 'pengurus' || role == 'pembina';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFE0F2EC),
              child: Icon(Icons.music_note_rounded, color: Color(0xFF167D68)),
            ),
            SizedBox(width: 10),
            Text(
              'Marawis Smpn99',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifikasi',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NotificationsScreen(role: role),
              ),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: 'Edit profil',
            onPressed: () => _openProfileEditor(context),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _LatestEmergencyBanner(role: role),
            _LatestAnnouncementBanner(role: role),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8EEEA)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: const Color(0xFFE0F2EC),
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? const Icon(Icons.person, color: Color(0xFF167D68))
                        : null,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, $displayName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$roleLabel • ${user.email ?? 'Akun Google'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF78877F),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.verified_rounded, color: Color(0xFF167D68)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (isAdmin)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF4268C5)),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Mode Admin aktif — akses Pengurus dan Pembina setara.',
                        style: TextStyle(color: Color(0xFF35549A), fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  colors: [Color(0xFF167D68), Color(0xFF229B7C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ASSALAMUALAIKUM 👋',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Selamat datang\ndi Marawis Smpn99',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Satu irama, satu tujuan, satu keluarga.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const _SectionHeading(
              title: 'Menu utama',
              subtitle: 'Akses kebutuhan kegiatan Marawis',
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.22,
              children: [
                _MenuCard(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Uang kas',
                  subtitle: 'Pembayaran & riwayat',
                  color: const Color(0xFFE7F4EE),
                  iconColor: const Color(0xFF167D68),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CashScreen(role: role))),
                ),
                _MenuCard(
                  icon: Icons.fact_check_rounded,
                  title: 'Absensi',
                  subtitle: 'Kehadiran latihan',
                  color: const Color(0xFFEAF0FF),
                  iconColor: const Color(0xFF4B6FCB),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AttendanceScreen(role: role),
                    ),
                  ),
                ),
                _MenuCard(
                  icon: Icons.event_note_rounded,
                  title: 'Jadwal',
                  subtitle: 'Latihan & kegiatan',
                  color: const Color(0xFFE7F4EE),
                  iconColor: const Color(0xFF167D68),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ActivitiesScreen(role: role),
                    ),
                  ),
                ),
                _MenuCard(
                  icon: Icons.groups_rounded,
                  title: 'Anggota',
                  subtitle: 'Data & profil anggota',
                  color: const Color(0xFFFFF2E3),
                  iconColor: const Color(0xFFC47A25),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MembersScreen(role: role))),
                ),
                _MenuCard(
                  icon: Icons.leaderboard_rounded,
                  title: 'Peringkat',
                  subtitle: 'Keaktifan & kedisiplinan',
                  color: const Color(0xFFF2EAFE),
                  iconColor: const Color(0xFF8458BD),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeaderboardScreen(role: role))),
                ),

              ],
            ),
            const SizedBox(height: 14),
            _MenuCard(
              icon: Icons.assignment_turned_in_rounded,
              title: 'Program kerja',
              subtitle: 'Rencana & pelaksanaan',
              color: const Color(0xFFE7F4EE),
              iconColor: const Color(0xFF167D68),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkProgramsScreen(role: role))),
            ),
            const SizedBox(height: 14),
            _MenuCard(
              icon: Icons.forum_rounded,
              title: 'Komunitas',
              subtitle: 'Kotak saran, Quiz & Game',
              color: const Color(0xFFEAF4EF),
              iconColor: const Color(0xFF167D68),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommunityHubScreen(role: role))),
            ),
            const SizedBox(height: 14),
            _MenuCard(
              icon: Icons.auto_awesome_rounded,
              title: 'Marawis Smart',
              subtitle: 'AI, Challenge, Reminder & Badge',
              color: const Color(0xFFEAF0FF),
              iconColor: const Color(0xFF4268C5),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MarawisSmartScreen(role: role))),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.admin_panel_settings_rounded,
                title: 'Pusat Pengurus',
                subtitle: 'Kelola kegiatan, tugas & anggota',
                color: const Color(0xFFEAF0FF),
                iconColor: const Color(0xFF4268C5),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManagementHubScreen(role: role))),
              ),
            ],
            const SizedBox(height: 26),
            const _SectionHeading(
              title: 'Informasi',
              subtitle: 'Pengumuman terbaru organisasi',
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AnnouncementsScreen(role: role),
                ),
              ),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE8EEEA)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(0xFFE7F4EE),
                      child: Icon(
                        Icons.campaign_rounded,
                        color: Color(0xFF167D68),
                      ),
                    ),
                    SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buka pengumuman',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Lihat informasi terbaru. Admin dapat membuat, mengedit, dan menghapus pengumuman.',
                            style: TextStyle(
                              color: Color(0xFF718078),
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF167D68)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Center(
              child: Text(
                'MARAWIS SMPN 99 JAKARTA • 2026/2027',
                style: TextStyle(
                  color: Color(0xFF9AA69F),
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _LatestEmergencyBanner extends StatefulWidget {
  const _LatestEmergencyBanner({required this.role});
  final String role;
  @override State<_LatestEmergencyBanner> createState() => _LatestEmergencyBannerState();
}
class _LatestEmergencyBannerState extends State<_LatestEmergencyBanner> {
  Future<List<Map<String,dynamic>>> _load() async {
    final rows=await Supabase.instance.client.from('marawis_emergency_announcements').select().eq('is_active',true).order('created_at',ascending:false);
    return List<Map<String,dynamic>>.from(rows).where((row) {
      final audience=(row['audience']??'all').toString();
      return audience=='all' || (audience=='anggota' && widget.role=='anggota') || (audience=='admin' && (widget.role=='pengurus'||widget.role=='pembina'));
    }).toList();
  }
  @override Widget build(BuildContext context) => FutureBuilder<List<Map<String,dynamic>>>(future:_load(),builder:(context,snapshot) {
    if(!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
    final row=snapshot.data!.first;
    return Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:const Color(0xFFFFEEEE),borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFFF3CACA))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Icon(Icons.warning_amber_rounded,color:Color(0xFFB3261E),size:25),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('PENGUMUMAN DARURAT',style:TextStyle(color:Color(0xFFB3261E),fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1)),
        const SizedBox(height:5),Text((row['title']??'Informasi penting').toString(),style:const TextStyle(fontWeight:FontWeight.w900,color:Color(0xFF70201C))),
        const SizedBox(height:4),Text((row['body']??'').toString(),style:const TextStyle(color:Color(0xFF70201C),fontSize:12,height:1.45)),
      ])),
    ]));
  });
}

class _LatestAnnouncementBanner extends StatefulWidget {
  const _LatestAnnouncementBanner({required this.role});

  final String role;

  @override
  State<_LatestAnnouncementBanner> createState() =>
      _LatestAnnouncementBannerState();
}

class _LatestAnnouncementBannerState
    extends State<_LatestAnnouncementBanner> {
  Timer? _refreshTimer;
  Map<String, dynamic>? _announcement;

  bool get _isAdmin =>
      widget.role == 'pengurus' || widget.role == 'pembina';

  @override
  void initState() {
    super.initState();
    _loadLatestAnnouncement();
    // Poll so updates appear even if Supabase Realtime is not enabled.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadLatestAnnouncement(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLatestAnnouncement() async {
    try {
      final rows = await Supabase.instance.client
          .from('announcements')
          .select('id,title,body,audience,is_published,created_at,updated_at,media_url,media_type')
          .eq('is_published', true)
          .order('updated_at', ascending: false)
          .limit(30);

      final now = DateTime.now().toUtc();
      final cutoff = now.subtract(const Duration(hours: 24));
      Map<String, dynamic>? latest;

      for (final raw in rows) {
        final item = Map<String, dynamic>.from(raw);
        final audience = (item['audience'] ?? 'all').toString();
        final visibleToRole = audience == 'all' ||
            (audience == 'anggota' && widget.role == 'anggota') ||
            (audience == 'admin' && _isAdmin);
        if (!visibleToRole) continue;

        final timestamp = DateTime.tryParse(
          (item['updated_at'] ?? item['created_at'] ?? '').toString(),
        )?.toUtc();
        if (timestamp == null ||
            timestamp.isBefore(cutoff) ||
            timestamp.isAfter(now.add(const Duration(minutes: 1)))) {
          continue;
        }
        latest = item;
        break;
      }

      if (!mounted) return;
      setState(() => _announcement = latest);
    } catch (_) {
      // Keep the current banner visible if a temporary refresh fails.
    }
  }

  String _timeLabel(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return 'Baru saja';
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Baru saja';
    if (difference.inHours < 1) return '${difference.inMinutes} menit lalu';
    if (difference.inHours < 24) return '${difference.inHours} jam lalu';
    return 'Hari ini';
  }

  @override
  Widget build(BuildContext context) {
    final item = _announcement;
    if (item == null) return const SizedBox.shrink();

    final timestamp = item['updated_at'] ?? item['created_at'];
    return Material(
      color: const Color(0xFFEAF5EF),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AnnouncementsScreen(role: widget.role),
          ),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFCFE5D8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.campaign_rounded,
                      color: Color(0xFF167D68), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'INFORMASI TERBARU',
                      style: TextStyle(
                        color: Color(0xFF167D68),
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    _timeLabel(timestamp),
                    style: const TextStyle(
                      color: Color(0xFF718078),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                (item['title'] ?? 'Pengumuman').toString(),
                style: const TextStyle(
                  color: Color(0xFF193B30),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                (item['body'] ?? '').toString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF52665B),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              if (item['media_url'] != null) ...[
                const SizedBox(height: 10),
                if ((item['media_type'] ?? 'image') == 'video')
                  const Row(
                    children: [
                      Icon(Icons.play_circle_outline_rounded,
                          color: Color(0xFF167D68), size: 18),
                      SizedBox(width: 6),
                      Text('Video terlampir — buka informasi untuk menonton',
                          style: TextStyle(
                            color: Color(0xFF167D68),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          )),
                    ],
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      item['media_url'].toString(),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Lihat informasi',
                    style: TextStyle(
                      color: Color(0xFF167D68),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(Icons.arrow_forward_rounded,
                      color: Color(0xFF167D68), size: 15),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF7B8981), fontSize: 12),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8EEEA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF849188),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

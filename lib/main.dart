import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_edit_screen.dart';
import 'announcements_screen.dart';
import 'activities_screen.dart';
import 'attendance_screen.dart';
import 'cash_screen.dart';
import 'members_screen.dart';
import 'work_programs_screen.dart';

const supabaseUrl = 'https://yatbnzczricrwrqhzsqr.supabase.co';
const supabasePublishableKey = 'sb_publishable_Uz6EYSbI3Nhj28uP3lEFsw_nCbEYMHS';
const authRedirectUrl = 'marawissmpn99://login-callback';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
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
          surface: const Color(0xFFF7FAF8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7FAF8),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7FAF8),
          surfaceTintColor: Colors.transparent,
        ),
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
        if (user == null) return const LoginScreen();
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
        return HomeScreen(user: widget.user, role: role, profile: profile);
      },
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
  String _selectedRole = 'anggota';

  String get _selectedRoleLabel {
    switch (_selectedRole) {
      case 'pengurus':
        return 'Pengurus';
      case 'pembina':
        return 'Pembina';
      default:
        return 'Anggota';
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: authRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const AuthException('Halaman login Google gagal dibuka. Coba lagi.');
      }
    } catch (error) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Masuk sebagai',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF7FAF8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE8EEEA)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE8EEEA)),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'anggota', child: Text('Anggota')),
                          DropdownMenuItem(value: 'pengurus', child: Text('Pengurus')),
                          DropdownMenuItem(value: 'pembina', child: Text('Pembina')),
                        ],
                        onChanged: _loading ? null : (value) {
                          if (value != null) setState(() => _selectedRole = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pilihan: $_selectedRoleLabel. Akses sebenarnya tetap mengikuti role yang terdaftar di database.',
                        style: const TextStyle(color: Color(0xFF78877F), fontSize: 11, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _loading ? null : _signInWithGoogle,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF167D68),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 21,
                                  height: 21,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login_rounded, size: 20),
                                    SizedBox(width: 10),
                                    Text(
                                      'Masuk dengan Google',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
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
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal keluar: $error')),
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

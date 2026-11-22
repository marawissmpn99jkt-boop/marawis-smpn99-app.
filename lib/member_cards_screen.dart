import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MemberCardsScreen extends StatefulWidget {
  const MemberCardsScreen({super.key, required this.role});
  final String role;
  @override
  State<MemberCardsScreen> createState() => _MemberCardsScreenState();
}

class _MemberCardsScreenState extends State<MemberCardsScreen> {
  final _db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;
  bool get _admin => widget.role == 'pengurus' || widget.role == 'pembina';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    var query = _db.from('members').select('id,display_name,avatar_url,class_name,position,membership_status,card_code');
    if (!_admin) query = query.eq('id', _db.auth.currentUser!.id);
    final rows = await query.order('display_name');
    final members = List<Map<String, dynamic>>.from(rows);
    if (members.isEmpty) return members;
    final profiles = await _db.from('profiles').select('id,role');
    final roles = {
      for (final profile in profiles)
        profile['id'].toString(): profile['role']?.toString() ?? 'anggota',
    };
    return members.map((member) => {
      ...member,
      'role': roles[member['id'].toString()] ?? 'anggota',
    }).toList();
  }

  void _refresh() => setState(() => _future = _load());

  String _roleLabel(String value) {
    switch (value) {
      case 'pengurus': return 'Pengurus';
      case 'pembina': return 'Pembina';
      default: return 'Anggota';
    }
  }

  Future<void> _showCard(Map<String, dynamic> member) async {
    final cardCode = member['card_code']?.toString() ?? '';
    if (cardCode.isEmpty) {
      _message('Kode kartu belum tersedia. Muat ulang halaman.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(18),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [Color(0xFF123F35), Color(0xFF167D68), Color(0xFF239B7C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.music_note_rounded, color: Colors.white),
              SizedBox(width: 7),
              Text('MARAWIS SMPN 99', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            ]),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 42,
              backgroundColor: Colors.white,
              backgroundImage: (member['avatar_url']?.toString().isNotEmpty ?? false) ? NetworkImage(member['avatar_url'].toString()) : null,
              child: (member['avatar_url']?.toString().isNotEmpty ?? false) ? null : const Icon(Icons.person_rounded, size: 42, color: Color(0xFF167D68)),
            ),
            const SizedBox(height: 13),
            Text(member['display_name']?.toString() ?? 'Anggota Marawis',
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(_roleLabel(member['role']?.toString() ?? 'anggota'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Text((member['position'] ?? 'Anggota').toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text((member['class_name'] ?? 'Kelas belum diisi').toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: QrImageView(data: 'MARAWIS-MEMBER|$cardCode', version: QrVersions.auto, size: 150),
            ),
            const SizedBox(height: 10),
            Text(cardCode, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
            const SizedBox(height: 5),
            const Text('KARTU IDENTITAS ANGGOTA DIGITAL', style: TextStyle(color: Colors.white70, fontSize: 9, letterSpacing: 1.1)),
            const SizedBox(height: 12),
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Tutup', style: TextStyle(color: Colors.white))),
          ]),
        ),
      ),
    );
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Kartu Identitas Digital', style: TextStyle(fontWeight: FontWeight.w800)),
      actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: TextButton(onPressed: _refresh, child: const Text('Kartu belum dapat dimuat. Coba lagi.')));
        final members = snapshot.data ?? [];
        if (members.isEmpty) return const Center(child: Text('Data anggota belum tersedia.'));
        if (!_admin) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.badge_rounded, size: 54, color: Color(0xFF167D68)),
                const SizedBox(height: 12),
                const Text('Kartu anggota kamu sudah siap', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 7),
                const Text('Tampilkan kartu digital ini saat diperlukan untuk identifikasi internal kegiatan Marawis.',
                  textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF718078), height: 1.5)),
                const SizedBox(height: 18),
                FilledButton.icon(onPressed: () => _showCard(members.first), icon: const Icon(Icons.qr_code_2_rounded), label: const Text('Tampilkan kartu saya')),
              ]),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final member = members[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFE7F4EE),
                backgroundImage: (member['avatar_url']?.toString().isNotEmpty ?? false) ? NetworkImage(member['avatar_url'].toString()) : null,
                child: (member['avatar_url']?.toString().isNotEmpty ?? false) ? null : const Icon(Icons.person_rounded, color: Color(0xFF167D68)),
              ),
              title: Text(member['display_name']?.toString() ?? 'Anggota', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${member['position'] ?? 'Anggota'} • ${member['class_name'] ?? 'Kelas belum diisi'}', style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF167D68)),
              onTap: () => _showCard(member),
            );
          },
        );
      },
    ),
  );
}

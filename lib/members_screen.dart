import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key, required this.role});
  final String role;
  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> future;
  bool get admin => widget.role == 'pengurus' || widget.role == 'pembina';
  @override
  void initState() { super.initState(); future = load(); }

  Future<List<Map<String, dynamic>>> load() async {
    final rows = await db.from('members').select('id,display_name,avatar_url,class_name,position,membership_status,bio').order('display_name');
    return List<Map<String, dynamic>>.from(rows);
  }
  void refresh() => setState(() => future = load());

  Future<void> edit(Map<String, dynamic> member) async {
    final name = TextEditingController(text: member['display_name']?.toString() ?? '');
    final klass = TextEditingController(text: member['class_name']?.toString() ?? '');
    final position = TextEditingController(text: member['position']?.toString() ?? 'Anggota');
    final bio = TextEditingController(text: member['bio']?.toString() ?? '');
    String status = (member['membership_status'] ?? 'aktif').toString();
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: const Text('Edit data anggota'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama tampilan')),
        TextField(controller: klass, decoration: const InputDecoration(labelText: 'Kelas')),
        TextField(controller: position, decoration: const InputDecoration(labelText: 'Jabatan')),
        TextField(controller: bio, maxLines: 2, decoration: const InputDecoration(labelText: 'Bio')),
        DropdownButtonFormField<String>(initialValue: status, decoration: const InputDecoration(labelText: 'Status anggota'), items: const [
          DropdownMenuItem(value: 'aktif', child: Text('Aktif')), DropdownMenuItem(value: 'nonaktif', child: Text('Nonaktif')), DropdownMenuItem(value: 'alumni', child: Text('Alumni')),
        ], onChanged: (v) { if (v != null) setDialog(() => status = v); }),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')), FilledButton(onPressed: () async {
        try {
          await db.from('members').update({'display_name': name.text.trim(), 'class_name': klass.text.trim().isEmpty ? null : klass.text.trim(), 'position': position.text.trim().isEmpty ? 'Anggota' : position.text.trim(), 'bio': bio.text.trim().isEmpty ? null : bio.text.trim(), 'membership_status': status, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', member['id']);
          if (ctx.mounted) Navigator.pop(ctx); refresh();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data anggota diperbarui.')));
        } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memperbarui: $e'))); }
      }, child: const Text('Simpan'))],
    )));
    name.dispose(); klass.dispose(); position.dispose(); bio.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Direktori anggota', style: TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))]),
    body: FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: TextButton(onPressed: refresh, child: const Text('Gagal memuat anggota. Coba lagi.')));
      final rows = snap.data ?? [];
      return RefreshIndicator(onRefresh: () async => refresh(), child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${rows.length} anggota terdaftar', style: const TextStyle(color: Color(0xFF718078), fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (rows.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Direktori masih kosong.', textAlign: TextAlign.center)),
        ...rows.map((m) => Card(color: Colors.white, child: ListTile(
          leading: CircleAvatar(backgroundColor: const Color(0xFFE7F4EE), backgroundImage: (m['avatar_url']?.toString().isNotEmpty ?? false) ? NetworkImage(m['avatar_url'].toString()) : null, child: (m['avatar_url']?.toString().isNotEmpty ?? false) ? null : const Icon(Icons.person, color: Color(0xFF167D68))),
          title: Text((m['display_name'] ?? 'Anggota').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text([m['class_name'], m['position'], m['membership_status']].where((v) => v != null && v.toString().isNotEmpty).join(' • ')),
          trailing: admin ? IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => edit(m)) : const Icon(Icons.chevron_right),
          onTap: admin ? () => edit(m) : null,
        ))),
      ]));
    }),
  );
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.role});
  final String role;
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> future;
  bool get admin => widget.role == 'pengurus' || widget.role == 'pembina';
  @override
  void initState() { super.initState(); future = load(); }
  Future<List<Map<String, dynamic>>> load() async {
    final scores = await db.from('member_scores').select('member_id,score_type,points,notes,created_at');
    final members = await db.from('members').select('id,display_name,class_name,position').eq('membership_status', 'aktif');
    final map = <String, Map<String, dynamic>>{};
    for (final m in members) { map[m['id'].toString()] = {...m, 'total': 0, 'count': 0}; }
    for (final s in scores) {
      final item = map[s['member_id'].toString()];
      if (item != null) { item['total'] = (item['total'] as int) + (s['points'] as num).toInt(); item['count'] = (item['count'] as int) + 1; }
    }
    final list = map.values.where((m) => m['count'] > 0).toList();
    list.sort((a,b) => (b['total'] as int).compareTo(a['total'] as int));
    return list;
  }
  void refresh() => setState(() => future = load());
  Future<void> assess() async {
    final members = await db.from('members').select('id,display_name').eq('membership_status', 'aktif').order('display_name');
    if (!mounted || members.isEmpty) return;
    String memberId = members.first['id'].toString();
    String type = 'keaktifan';
    final points = TextEditingController(text: '10');
    final notes = TextEditingController();
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: const Text('Beri penilaian anggota'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: memberId, items: members.map((m) => DropdownMenuItem(value: m['id'].toString(), child: Text(m['display_name']?.toString() ?? 'Anggota'))).toList(), onChanged: (v) { if (v != null) setDialog(() => memberId = v); }),
        DropdownButtonFormField<String>(initialValue: type, items: const [DropdownMenuItem(value: 'keaktifan', child: Text('Keaktifan')), DropdownMenuItem(value: 'kedisiplinan', child: Text('Kedisiplinan')), DropdownMenuItem(value: 'kontribusi', child: Text('Kontribusi')), DropdownMenuItem(value: 'prestasi', child: Text('Prestasi'))], onChanged: (v) { if (v != null) setDialog(() => type = v); }),
        TextField(controller: points, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Poin (0–100)')),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'Catatan')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')), FilledButton(onPressed: () async {
        final n = int.tryParse(points.text);
        if (n == null || n < 0 || n > 100) return;
        try {
          await db.from('member_scores').insert({'member_id': memberId, 'score_type': type, 'points': n, 'notes': notes.text.trim().isEmpty ? null : notes.text.trim(), 'assessed_by': db.auth.currentUser!.id});
          if (ctx.mounted) Navigator.pop(ctx); refresh();
        } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan penilaian: $e'))); }
      }, child: const Text('Simpan'))],
    )));
    points.dispose(); notes.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Peringkat anggota', style: TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))]),
    floatingActionButton: admin ? FloatingActionButton.extended(onPressed: assess, icon: const Icon(Icons.add), label: const Text('Beri nilai')) : null,
    body: FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: TextButton(onPressed: refresh, child: const Text('Gagal memuat peringkat. Coba lagi.')));
      final rows = snap.data ?? [];
      if (rows.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Belum ada penilaian. Peringkat akan muncul setelah pengurus memberi nilai.', textAlign: TextAlign.center)));
      return ListView.builder(padding: const EdgeInsets.all(16), itemCount: rows.length, itemBuilder: (context, i) {
        final m = rows[i];
        return Card(color: Colors.white, child: ListTile(
          leading: CircleAvatar(backgroundColor: i == 0 ? const Color(0xFFFFF2D7) : const Color(0xFFE7F4EE), child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900))),
          title: Text(m['display_name']?.toString() ?? 'Anggota', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${m['class_name'] ?? 'Kelas belum diisi'} • ${m['count']} penilaian'),
          trailing: Text('${m['total']} poin', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF167D68))),
        ));
      });
    }),
  );
}

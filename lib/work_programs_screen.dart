import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkProgramsScreen extends StatefulWidget {
  const WorkProgramsScreen({super.key, required this.role});
  final String role;
  @override
  State<WorkProgramsScreen> createState() => _WorkProgramsScreenState();
}

class _WorkProgramsScreenState extends State<WorkProgramsScreen> {
  final db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> future;
  bool busy = false;
  bool get admin => widget.role == 'pengurus' || widget.role == 'pembina';
  @override
  void initState() { super.initState(); future = load(); }
  Future<List<Map<String, dynamic>>> load() async {
    final rows = await db.from('work_programs').select('id,title,description,person_in_charge,start_date,due_date,status').order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }
  void refresh() => setState(() => future = load());

  Future<void> edit({Map<String, dynamic>? item}) async {
    final title = TextEditingController(text: item?['title']?.toString() ?? '');
    final description = TextEditingController(text: item?['description']?.toString() ?? '');
    final owner = TextEditingController(text: item?['person_in_charge']?.toString() ?? '');
    String status = (item?['status'] ?? 'rencana').toString();
    final key = GlobalKey<FormState>();
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: Text(item == null ? 'Program kerja baru' : 'Edit program kerja'),
      content: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Nama program'), validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi.' : null),
        TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Deskripsi')),
        TextField(controller: owner, decoration: const InputDecoration(labelText: 'Penanggung jawab')),
        DropdownButtonFormField<String>(initialValue: status, decoration: const InputDecoration(labelText: 'Status'), items: const [
          DropdownMenuItem(value: 'rencana', child: Text('Rencana')), DropdownMenuItem(value: 'berjalan', child: Text('Berjalan')), DropdownMenuItem(value: 'selesai', child: Text('Selesai')), DropdownMenuItem(value: 'ditunda', child: Text('Ditunda')),
        ], onChanged: (v) { if (v != null) setDialog(() => status = v); }),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')), FilledButton(onPressed: busy ? null : () async {
        if (!key.currentState!.validate()) return;
        setState(() => busy = true);
        try {
          final data = {'title': title.text.trim(), 'description': description.text.trim().isEmpty ? null : description.text.trim(), 'person_in_charge': owner.text.trim().isEmpty ? null : owner.text.trim(), 'status': status, 'updated_at': DateTime.now().toUtc().toIso8601String()};
          if (item == null) { data['created_by'] = db.auth.currentUser!.id; await db.from('work_programs').insert(data); }
          else { await db.from('work_programs').update(data).eq('id', item['id']); }
          if (ctx.mounted) Navigator.pop(ctx); refresh();
        } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e'))); }
        finally { if (mounted) setState(() => busy = false); }
      }, child: const Text('Simpan'))],
    )));
    title.dispose(); description.dispose(); owner.dispose();
  }

  Future<void> remove(Map<String, dynamic> item) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Hapus program?'), content: Text('Program "${item['title']}" akan dihapus.'), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
    ]));
    if (yes != true) return;
    try { await db.from('work_programs').delete().eq('id', item['id']); refresh(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e'))); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Program kerja', style: TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))]),
    floatingActionButton: admin ? FloatingActionButton.extended(onPressed: () => edit(), icon: const Icon(Icons.add), label: const Text('Tambah program')) : null,
    body: FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: TextButton(onPressed: refresh, child: const Text('Gagal memuat program. Coba lagi.')));
      final rows = snap.data ?? [];
      if (rows.isEmpty) return const Center(child: Text('Belum ada program kerja.'));
      return RefreshIndicator(onRefresh: () async => refresh(), child: ListView.separated(padding: const EdgeInsets.all(16), itemCount: rows.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (context, i) {
        final item = rows[i];
        return Card(color: Colors.white, child: ExpansionTile(
          leading: const CircleAvatar(backgroundColor: Color(0xFFE7F4EE), child: Icon(Icons.flag_outlined, color: Color(0xFF167D68))),
          title: Text(item['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('Status: ${item['status']} • PIC: ${item['person_in_charge'] ?? '-'}'),
          children: [
            if ((item['description'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Text(item['description'].toString())),
            if (admin) OverflowBar(alignment: MainAxisAlignment.end, children: [TextButton(onPressed: () => edit(item: item), child: const Text('Edit')), TextButton(onPressed: () => remove(item), child: const Text('Hapus'))]),
          ],
        ));
      }));
    }),
  );
}

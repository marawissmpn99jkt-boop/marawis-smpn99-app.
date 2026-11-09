import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key, required this.role});
  final String role;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;
  bool _busy = false;

  bool get _isAdmin => widget.role == 'pengurus' || widget.role == 'pembina';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await _client
        .from('announcements')
        .select('id,title,body,audience,is_published,created_at,created_by')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  void _refresh() => setState(() => _future = _load());

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openEditor({Map<String, dynamic>? item}) async {
    final title = TextEditingController(text: item?['title']?.toString() ?? '');
    final body = TextEditingController(text: item?['body']?.toString() ?? '');
    String audience = (item?['audience'] ?? 'all').toString();
    bool published = (item?['is_published'] ?? true) == true;
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(20, 22, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Color(0xFFF7FAF8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item == null ? 'Buat pengumuman' : 'Edit pengumuman',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 18),
                  const Text('Judul', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  TextFormField(
                    controller: title,
                    maxLength: 100,
                    decoration: _decoration('Contoh: Jadwal latihan pekan ini'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Judul wajib diisi.' : null,
                  ),
                  const SizedBox(height: 10),
                  const Text('Isi pengumuman', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  TextFormField(
                    controller: body,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 3000,
                    decoration: _decoration('Tulis informasi dengan jelas...'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Isi pengumuman wajib diisi.' : null,
                  ),
                  const SizedBox(height: 8),
                  const Text('Ditujukan kepada', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  DropdownButtonFormField<String>(
                    value: audience,
                    decoration: _decoration('Pilih audiens'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Semua anggota')),
                      DropdownMenuItem(value: 'anggota', child: Text('Anggota saja')),
                      DropdownMenuItem(value: 'admin', child: Text('Pengurus & Pembina')),
                    ],
                    onChanged: (v) { if (v != null) setSheetState(() => audience = v); },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Terbitkan sekarang', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Matikan untuk menyimpan sebagai draft'),
                    value: published,
                    onChanged: (v) => setSheetState(() => published = v),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _busy ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        setState(() => _busy = true);
                        try {
                          final data = {
                            'title': title.text.trim(),
                            'body': body.text.trim(),
                            'audience': audience,
                            'is_published': published,
                            'updated_at': DateTime.now().toUtc().toIso8601String(),
                          };
                          if (item == null) {
                            data['created_by'] = _client.auth.currentUser!.id;
                            await _client.from('announcements').insert(data);
                          } else {
                            await _client.from('announcements').update(data).eq('id', item['id']);
                          }
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          _refresh();
                          _message(item == null ? 'Pengumuman berhasil dibuat.' : 'Pengumuman berhasil diperbarui.');
                        } catch (e) {
                          _message('Gagal menyimpan pengumuman: $e');
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                      child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Simpan pengumuman', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    title.dispose();
    body.dispose();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus pengumuman?'),
        content: Text('“${item['title']}” akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _client.from('announcements').delete().eq('id', item['id']);
      _refresh();
      _message('Pengumuman berhasil dihapus.');
    } catch (e) {
      _message('Gagal menghapus: $e');
    }
  }

  String _audienceLabel(String value) {
    switch (value) {
      case 'anggota': return 'Anggota';
      case 'admin': return 'Pengurus & Pembina';
      default: return 'Semua anggota';
    }
  }

  String _dateLabel(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day} ${months[date.month - 1]} ${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE4EBE6))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE4EBE6))),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengumuman', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: _refresh, tooltip: 'Muat ulang', icon: const Icon(Icons.refresh_rounded)),
          if (_isAdmin) IconButton(onPressed: () => _openEditor(), tooltip: 'Buat pengumuman', icon: const Icon(Icons.add_circle_outline_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: _isAdmin ? FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: const Color(0xFF167D68),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat pengumuman'),
      ) : null,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Belum bisa memuat pengumuman',
              subtitle: 'Periksa koneksi internet, lalu coba muat ulang.',
              action: TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return _EmptyState(
              icon: Icons.campaign_outlined,
              title: 'Belum ada pengumuman',
              subtitle: _isAdmin ? 'Buat pengumuman pertama untuk anggota Marawis.' : 'Pengumuman dari pengurus akan muncul di sini.',
              action: _isAdmin ? FilledButton.icon(onPressed: () => _openEditor(), icon: const Icon(Icons.add), label: const Text('Buat pengumuman')) : null,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                final published = item['is_published'] == true;
                return Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE6ECE8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFE7F4EE), borderRadius: BorderRadius.circular(13)),
                          child: const Icon(Icons.campaign_rounded, color: Color(0xFF167D68))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_audienceLabel(item['audience'].toString()), style: const TextStyle(color: Color(0xFF167D68), fontSize: 11, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(_dateLabel(item['created_at']), style: const TextStyle(color: Color(0xFF87938C), fontSize: 10)),
                        ])),
                        if (!published) const Chip(label: Text('Draft', style: TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact),
                        if (_isAdmin) PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _openEditor(item: item);
                            if (v == 'delete') _delete(item);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Hapus')),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 13),
                      Text(item['title'].toString(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text(item['body'].toString(), style: const TextStyle(color: Color(0xFF56645C), fontSize: 13, height: 1.55)),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle, this.action});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 48, color: const Color(0xFF167D68)),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF78877F), height: 1.5)),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ]),
    ),
  );
}

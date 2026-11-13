import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key, required this.role});
  final String role;

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  final _client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;
  bool _saving = false;

  bool get _isAdmin => widget.role == 'pengurus' || widget.role == 'pembina';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await _client.from('activities')
        .select('id,title,description,location,starts_at,ends_at,activity_type')
        .order('starts_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  void _refresh() => setState(() => _future = _load());

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _createActivity() async {
    final title = TextEditingController();
    final description = TextEditingController();
    final location = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var type = 'latihan';
    var start = DateTime.now().add(const Duration(days: 1));
    var end = start.add(const Duration(hours: 2));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah kegiatan'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: title,
                      maxLength: 100,
                      decoration: const InputDecoration(labelText: 'Nama kegiatan'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi.' : null,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Jenis kegiatan'),
                      items: const [
                        DropdownMenuItem(value: 'latihan', child: Text('Latihan')),
                        DropdownMenuItem(value: 'rapat', child: Text('Rapat')),
                        DropdownMenuItem(value: 'penampilan', child: Text('Penampilan')),
                        DropdownMenuItem(value: 'acara', child: Text('Acara')),
                        DropdownMenuItem(value: 'lainnya', child: Text('Lainnya')),
                      ],
                      onChanged: (v) { if (v != null) setDialogState(() => type = v); },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Waktu mulai'),
                      subtitle: Text(_dateLabel(start)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: start,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2035),
                        );
                        if (date == null || !context.mounted) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(start),
                        );
                        if (time == null) return;
                        setDialogState(() => start = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Waktu selesai'),
                      subtitle: Text(_dateLabel(end)),
                      trailing: const Icon(Icons.event_available),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: end,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2035),
                        );
                        if (date == null || !context.mounted) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(end),
                        );
                        if (time == null) return;
                        setDialogState(() => end = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                      },
                    ),
                    TextFormField(
                      controller: location,
                      maxLength: 160,
                      decoration: const InputDecoration(labelText: 'Lokasi (opsional)'),
                    ),
                    TextFormField(
                      controller: description,
                      maxLines: 3,
                      maxLength: 1500,
                      decoration: const InputDecoration(labelText: 'Keterangan (opsional)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
            FilledButton(
              onPressed: _saving ? null : () async {
                if (!formKey.currentState!.validate()) return;
                if (end.isBefore(start)) {
                  _message('Waktu selesai tidak boleh sebelum waktu mulai.');
                  return;
                }
                setState(() => _saving = true);
                try {
                  await _client.from('activities').insert({
                    'title': title.text.trim(),
                    'description': description.text.trim().isEmpty ? null : description.text.trim(),
                    'location': location.text.trim().isEmpty ? null : location.text.trim(),
                    'activity_type': type,
                    'starts_at': start.toUtc().toIso8601String(),
                    'ends_at': end.toUtc().toIso8601String(),
                    'created_by': _client.auth.currentUser!.id,
                  });
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _refresh();
                  _message('Kegiatan berhasil ditambahkan.');
                } catch (error) {
                  _message('Gagal menambahkan kegiatan: $error');
                } finally {
                  if (mounted) setState(() => _saving = false);
                }
              },
              child: _saving ? const CircularProgressIndicator() : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    description.dispose();
    location.dispose();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus kegiatan?'),
        content: Text('Kegiatan "${item['title']}" akan dihapus beserta catatan absensinya.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _client.from('activities').delete().eq('id', item['id']);
      _refresh();
      _message('Kegiatan berhasil dihapus.');
    } catch (error) {
      _message('Gagal menghapus kegiatan: $error');
    }
  }

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} • ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'rapat': return 'Rapat';
      case 'penampilan': return 'Penampilan';
      case 'acara': return 'Acara';
      case 'lainnya': return 'Lainnya';
      default: return 'Latihan';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Kegiatan', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
      ),
      floatingActionButton: _isAdmin ? FloatingActionButton.extended(
        onPressed: _createActivity,
        backgroundColor: const Color(0xFF167D68),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah kegiatan'),
      ) : null,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Jadwal belum bisa dimuat.'),
                TextButton(onPressed: _refresh, child: const Text('Coba lagi')),
              ],
            ));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.event_note_rounded, size: 48, color: Color(0xFF167D68)),
                const SizedBox(height: 12),
                const Text('Belum ada jadwal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(_isAdmin ? 'Tambahkan jadwal latihan, rapat, atau penampilan.' : 'Jadwal kegiatan Marawis akan muncul di sini.', textAlign: TextAlign.center),
                if (_isAdmin) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(onPressed: _createActivity, icon: const Icon(Icons.add), label: const Text('Tambah jadwal')),
                ],
              ]),
            ));
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final start = DateTime.tryParse(item['starts_at'].toString())?.toLocal();
                final end = DateTime.tryParse(item['ends_at']?.toString() ?? '')?.toLocal();
                return Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.event_rounded, color: Color(0xFF167D68)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_typeLabel(item['activity_type'].toString()), style: const TextStyle(color: Color(0xFF167D68), fontWeight: FontWeight.w800))),
                        if (_isAdmin) PopupMenuButton<String>(
                          onSelected: (v) { if (v == 'delete') _delete(item); },
                          itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Hapus'))],
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text(item['title'].toString(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      if (start != null) Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Mulai: ${_dateLabel(start)}', style: const TextStyle(color: Color(0xFF64736B), fontSize: 12)),
                      ),
                      if (end != null) Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text('Selesai: ${_dateLabel(end)}', style: const TextStyle(color: Color(0xFF64736B), fontSize: 12)),
                      ),
                      if ((item['location'] ?? '').toString().isNotEmpty) Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text('Lokasi: ${item['location']}'),
                      ),
                      if ((item['description'] ?? '').toString().isNotEmpty) Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(item['description'].toString()),
                      ),
                    ]),
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

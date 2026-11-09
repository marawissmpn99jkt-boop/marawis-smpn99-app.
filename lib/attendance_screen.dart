import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.role});
  final String role;
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;
  bool _saving = false;
  bool get _admin => widget.role == 'pengurus' || widget.role == 'pembina';

  @override
  void initState() { super.initState(); _future = _load(); }

  Future<List<Map<String, dynamic>>> _load() async {
    if (_admin) {
      final rows = await _db.from('activities').select('id,title,starts_at').order('starts_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    }
    final rows = await _db.from('attendance').select('id,activity_id,status,created_at')
      .eq('member_id', _db.auth.currentUser!.id).order('created_at', ascending: false);
    final records = List<Map<String, dynamic>>.from(rows);
    if (records.isEmpty) return records;
    final ids = records.map((e) => e['activity_id']).toSet().toList();
    final activities = await _db.from('activities').select('id,title,starts_at').inFilter('id', ids);
    final byId = {for (final a in activities) a['id'].toString(): a};
    for (final record in records) { record['activity'] = byId[record['activity_id'].toString()]; }
    return records;
  }

  void _refresh() => setState(() => _future = _load());

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Waktu tidak tersedia';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'izin': return 'Izin';
      case 'sakit': return 'Sakit';
      case 'alpa': return 'Alpa';
      default: return 'Hadir';
    }
  }

  Future<void> _manageActivity(Map<String, dynamic> activity) async {
    final id = activity['id'] as int;
    final Map<String, String> statuses = {};
    try {
      final members = await _db.from('members').select('id,display_name,class_name')
        .eq('membership_status', 'aktif').order('display_name');
      final existing = await _db.from('attendance').select('member_id,status').eq('activity_id', id);
      for (final row in existing) { statuses[row['member_id'].toString()] = row['status'].toString(); }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context, isScrollControlled: true, useSafeArea: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: Column(children: [
              Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Kelola absensi', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4), Text(activity['title'].toString(), style: const TextStyle(color: Color(0xFF167D68))),
                Text(_date(activity['starts_at'])),
              ])),
              const Divider(height: 1),
              Expanded(child: ListView.separated(
                padding: const EdgeInsets.all(16), itemCount: members.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final member = members[index];
                  final memberId = member['id'].toString();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text((member['display_name'] ?? 'Anggota').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: (member['class_name'] ?? '').toString().isEmpty ? null : Text(member['class_name'].toString()),
                    trailing: DropdownButton<String>(
                      value: statuses[memberId] ?? 'hadir',
                      items: const [
                        DropdownMenuItem(value: 'hadir', child: Text('Hadir')),
                        DropdownMenuItem(value: 'izin', child: Text('Izin')),
                        DropdownMenuItem(value: 'sakit', child: Text('Sakit')),
                        DropdownMenuItem(value: 'alpa', child: Text('Alpa')),
                      ],
                      onChanged: (value) { if (value != null) {
                        setSheetState(() => statuses[memberId] = value);
                      } },
                    ),
                  );
                },
              )),
              Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 18), child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : () async {
                    setState(() => _saving = true);
                    try {
                      final rows = members.map((member) => {
                        'activity_id': id,
                        'member_id': member['id'],
                        'status': statuses[member['id'].toString()] ?? 'hadir',
                        'marked_by': _db.auth.currentUser!.id,
                      }).toList();
                      if (rows.isNotEmpty) {
                        await _db.from('attendance').upsert(rows, onConflict: 'activity_id,member_id');
                      }
                      if (sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                      }
                      _refresh();
                      _notify('Absensi berhasil disimpan.');
                    } catch (error) {
                      _notify('Gagal menyimpan absensi: $error');
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
                  child: _saving ? const CircularProgressIndicator() : const Text('Simpan absensi'),
                ),
              )),
            ]),
          ),
        ),
      );
    } catch (error) { _notify('Data anggota/absensi gagal dimuat: $error'); }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Absensi', style: TextStyle(fontWeight: FontWeight.w800)),
      actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))]),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Data absensi belum bisa dimuat.'), TextButton(onPressed: _refresh, child: const Text('Coba lagi')),
        ]));
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.fact_check_outlined, size: 48, color: Color(0xFF167D68)), const SizedBox(height: 12),
          Text(_admin ? 'Belum ada kegiatan' : 'Belum ada catatan absensi', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(_admin ? 'Buat jadwal kegiatan terlebih dahulu untuk mulai mencatat kehadiran.' : 'Catatan kehadiranmu akan muncul setelah admin mengisi absensi.', textAlign: TextAlign.center),
        ])));
        return ListView.separated(
          padding: const EdgeInsets.all(16), itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final row = rows[index];
            if (_admin) return Card(color: Colors.white, child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFE7F4EE), child: Icon(Icons.event, color: Color(0xFF167D68))),
              title: Text(row['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(_date(row['starts_at'])), trailing: const Icon(Icons.chevron_right),
              onTap: () => _manageActivity(row),
            ));
            final activity = row['activity'] as Map<String, dynamic>?;
            return Card(color: Colors.white, child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFE7F4EE), child: Icon(Icons.fact_check, color: Color(0xFF167D68))),
              title: Text(activity?['title']?.toString() ?? 'Kegiatan', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(_date(activity?['starts_at'])),
              trailing: Chip(label: Text(_statusLabel(row['status'].toString()))),
            ));
          },
        );
      },
    ),
  );
}

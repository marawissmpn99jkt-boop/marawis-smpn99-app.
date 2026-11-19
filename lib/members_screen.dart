import 'package:material_ui/material_ui.dart';
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
  void initState() {
    super.initState();
    future = load();
  }

  Future<List<Map<String, dynamic>>> load() async {
    final rows = await db
        .from('members')
        .select(
          'id,display_name,avatar_url,class_name,position,membership_status,bio',
        )
        .order('display_name');
    final members = List<Map<String, dynamic>>.from(rows);

    if (!admin) return members;

    final profiles = await db.from('profiles').select('id,role');
    final rolesById = {
      for (final profile in profiles)
        profile['id'].toString(): profile['role']?.toString() ?? 'anggota',
    };

    return members
        .map(
          (member) => {
            ...member,
            'role': rolesById[member['id'].toString()] ?? 'anggota',
          },
        )
        .toList();
  }

  void refresh() => setState(() => future = load());

  String _roleLabel(String role) {
    switch (role) {
      case 'pengurus':
        return 'Pengurus';
      case 'pembina':
        return 'Pembina';
      default:
        return 'Anggota';
    }
  }

  Future<void> edit(Map<String, dynamic> member) async {
    final memberId = member['id'].toString();
    final name = TextEditingController(
      text: member['display_name']?.toString() ?? '',
    );
    final klass = TextEditingController(
      text: member['class_name']?.toString() ?? '',
    );
    final position = TextEditingController(
      text: member['position']?.toString() ?? 'Anggota',
    );
    final bio = TextEditingController(
      text: member['bio']?.toString() ?? '',
    );
    String role = (member['role'] ?? 'anggota').toString();
    String status = (member['membership_status'] ?? 'aktif').toString();
    final canChangeRole = memberId != db.auth.currentUser?.id;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Edit data anggota'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Nama tampilan'),
                ),
                TextField(
                  controller: klass,
                  maxLength: 10,
                  decoration: const InputDecoration(labelText: 'Kelas'),
                ),
                TextField(
                  controller: position,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Jabatan'),
                ),
                TextField(
                  controller: bio,
                  maxLength: 160,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Bio'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role akun'),
                  items: const [
                    DropdownMenuItem(value: 'anggota', child: Text('Anggota')),
                    DropdownMenuItem(value: 'pengurus', child: Text('Pengurus')),
                    DropdownMenuItem(value: 'pembina', child: Text('Pembina')),
                  ],
                  onChanged: canChangeRole
                      ? (value) {
                          if (value != null) {
                            setDialog(() => role = value);
                          }
                        }
                      : null,
                ),
                if (!canChangeRole)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Role akun sendiri tidak dapat diubah dari halaman ini.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Status anggota',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'aktif', child: Text('Aktif')),
                    DropdownMenuItem(value: 'nonaktif', child: Text('Nonaktif')),
                    DropdownMenuItem(value: 'alumni', child: Text('Alumni')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialog(() => status = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nama tampilan wajib diisi.'),
                    ),
                  );
                  return;
                }

                try {
                  await db.from('profiles').update({
                    'full_name': name.text.trim(),
                    'role': role,
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  }).eq('id', memberId);

                  await db.from('members').update({
                    'class_name': klass.text.trim().isEmpty
                        ? null
                        : klass.text.trim(),
                    'position': position.text.trim().isEmpty
                        ? 'Anggota'
                        : position.text.trim(),
                    'bio': bio.text.trim().isEmpty ? null : bio.text.trim(),
                    'membership_status': status,
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  }).eq('id', memberId);

                  if (ctx.mounted) Navigator.pop(ctx);
                  refresh();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Data anggota dan role diperbarui.'),
                      ),
                    );
                  }
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal memperbarui anggota: $error'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    klass.dispose();
    position.dispose();
    bio.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Direktori anggota',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: TextButton(
                  onPressed: refresh,
                  child: const Text('Gagal memuat anggota. Coba lagi.'),
                ),
              );
            }

            final rows = snapshot.data ?? [];
            return RefreshIndicator(
              onRefresh: () async => refresh(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${rows.length} anggota terdaftar',
                    style: const TextStyle(
                      color: Color(0xFF718078),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Direktori masih kosong.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ...rows.map((member) {
                    final avatarUrl = member['avatar_url']?.toString() ?? '';
                    final details = <String>[
                      if ((member['class_name'] ?? '').toString().isNotEmpty)
                        member['class_name'].toString(),
                      (member['position'] ?? 'Anggota').toString(),
                      (member['membership_status'] ?? 'aktif').toString(),
                      if (admin)
                        'Role: ${_roleLabel((member['role'] ?? 'anggota').toString())}',
                    ];

                    return Card(
                      color: Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE7F4EE),
                          backgroundImage: avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: Color(0xFF167D68),
                                )
                              : null,
                        ),
                        title: Text(
                          (member['display_name'] ?? 'Anggota').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(details.join(' • ')),
                        trailing: admin
                            ? IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => edit(member),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: admin ? () => edit(member) : null,
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
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
  void initState() {
    super.initState();
    future = load();
  }

  Future<List<Map<String, dynamic>>> load() async {
    final scores = await db
        .from('member_scores')
        .select('id,member_id,score_type,points,notes,created_at');
    final members = await db
        .from('members')
        .select('id,display_name,class_name,position')
        .eq('membership_status', 'aktif');

    final byId = <String, Map<String, dynamic>>{};
    for (final member in members) {
      byId[member['id'].toString()] = {
        ...member,
        'total': 0,
        'count': 0,
        'scores': <Map<String, dynamic>>[],
      };
    }

    for (final score in scores) {
      final member = byId[score['member_id'].toString()];
      if (member == null) continue;
      member['total'] =
          (member['total'] as int) + (score['points'] as num).toInt();
      member['count'] = (member['count'] as int) + 1;
      (member['scores'] as List<Map<String, dynamic>>).add(Map<String, dynamic>.from(score));
    }

    final ranked = byId.values.where((member) => member['count'] > 0).toList();
    ranked.sort(
      (a, b) => (b['total'] as int).compareTo(a['total'] as int),
    );
    return ranked;
  }


  Future<void> manageScores(Map<String, dynamic> member) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final scores = List<Map<String, dynamic>>.from(member['scores'] as List);
          return AlertDialog(
            title: Text('Penilaian \${member['display_name']}'),
            content: SizedBox(width: 420, child: scores.isEmpty
              ? const Text('Belum ada penilaian.')
              : ListView.separated(
                shrinkWrap: true, itemCount: scores.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, index) {
                  final score = scores[index];
                  final type = score['score_type'].toString();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('\${type[0].toUpperCase()}\${type.substring(1)} • \${score['points']} poin'),
                    subtitle: Text((score['notes'] ?? 'Tanpa catatan').toString()),
                    trailing: admin ? PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'edit') {
                          final updated = await editScore(score);
                          if (updated && ctx.mounted) {
                            final fresh = await load();
                            if (!mounted) return;
                            setState(() => future = Future.value(fresh));
                            member['scores'] = fresh.firstWhere((m) => m['id'] == member['id'],
                              orElse: () => {'scores': <Map<String, dynamic>>[]})['scores'];
                            setDialog(() {});
                          }
                        } else if (action == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (cc) => AlertDialog(
                              title: const Text('Hapus penilaian?'),
                              content: const Text('Poin dan catatan penilaian ini akan dihapus.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(cc, false), child: const Text('Batal')),
                                FilledButton(onPressed: () => Navigator.pop(cc, true), child: const Text('Hapus')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await db.from('member_scores').delete().eq('id', score['id']);
                              final fresh = await load();
                              if (!mounted) return;
                              setState(() => future = Future.value(fresh));
                              member['scores'] = fresh.firstWhere((m) => m['id'] == member['id'],
                                orElse: () => {'scores': <Map<String, dynamic>>[]})['scores'];
                              setDialog(() {});
                            } catch (error) {
                              if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Gagal menghapus: $error')));
                            }
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Hapus')),
                      ],
                    ) : null,
                  );
                },
              )),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))],
          );
        },
      ),
    );
    refresh();
  }

  Future<bool> editScore(Map<String, dynamic> score) async {
    String type = score['score_type'].toString();
    final points = TextEditingController(text: score['points'].toString());
    final notes = TextEditingController(text: (score['notes'] ?? '').toString());
    var saved = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Edit penilaian'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: type,
              items: const [
                DropdownMenuItem(value: 'keaktifan', child: Text('Keaktifan')),
                DropdownMenuItem(value: 'kedisiplinan', child: Text('Kedisiplinan')),
                DropdownMenuItem(value: 'kontribusi', child: Text('Kontribusi')),
                DropdownMenuItem(value: 'prestasi', child: Text('Prestasi')),
              ],
              onChanged: (v) { if (v != null) setDialog(() => type = v); },
            ),
            TextField(controller: points, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Poin (0–100)')),
            TextField(controller: notes, decoration: const InputDecoration(labelText: 'Catatan')),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(onPressed: () async {
              final value = int.tryParse(points.text);
              if (value == null || value < 0 || value > 100) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Poin harus 0–100.')));
                return;
              }
              try {
                await db.from('member_scores').update({
                  'score_type': type, 'points': value,
                  'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
                }).eq('id', score['id']);
                saved = true;
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (error) {
                if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal mengedit: $error')));
              }
            }, child: const Text('Simpan perubahan')),
          ],
        ),
      ),
    );
    points.dispose();
    notes.dispose();
    return saved;
  }

  void refresh() => setState(() => future = load());

  Future<void> assess() async {
    final members = await db
        .from('members')
        .select('id,display_name')
        .eq('membership_status', 'aktif')
        .order('display_name');
    if (!mounted || members.isEmpty) return;

    String memberId = members.first['id'].toString();
    String type = 'keaktifan';
    final points = TextEditingController(text: '10');
    final notes = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Beri penilaian anggota'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: memberId,
                  items: members
                      .map(
                        (member) => DropdownMenuItem(
                          value: member['id'].toString(),
                          child: Text(
                            member['display_name']?.toString() ?? 'Anggota',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialog(() => memberId = value);
                    }
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(
                      value: 'keaktifan',
                      child: Text('Keaktifan'),
                    ),
                    DropdownMenuItem(
                      value: 'kedisiplinan',
                      child: Text('Kedisiplinan'),
                    ),
                    DropdownMenuItem(
                      value: 'kontribusi',
                      child: Text('Kontribusi'),
                    ),
                    DropdownMenuItem(
                      value: 'prestasi',
                      child: Text('Prestasi'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialog(() => type = value);
                    }
                  },
                ),
                TextField(
                  controller: points,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Poin (0–100)'),
                ),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Catatan'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final value = int.tryParse(points.text);
                if (value == null || value < 0 || value > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Poin harus berada di antara 0 dan 100.'),
                    ),
                  );
                  return;
                }
                try {
                  await db.from('member_scores').insert({
                    'member_id': memberId,
                    'score_type': type,
                    'points': value,
                    'notes': notes.text.trim().isEmpty
                        ? null
                        : notes.text.trim(),
                    'assessed_by': db.auth.currentUser!.id,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  refresh();
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal menyimpan penilaian: $error'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    points.dispose();
    notes.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Peringkat anggota',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: admin
            ? FloatingActionButton.extended(
                onPressed: assess,
                icon: const Icon(Icons.add),
                label: const Text('Beri nilai'),
              )
            : null,
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: TextButton(
                  onPressed: refresh,
                  child: const Text('Gagal memuat peringkat. Coba lagi.'),
                ),
              );
            }

            final rows = snapshot.data ?? [];
            if (rows.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Belum ada penilaian. Peringkat akan muncul setelah pengurus memberi nilai.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final member = rows[index];
                return Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: index == 0
                          ? const Color(0xFFFFF2D7)
                          : const Color(0xFFE7F4EE),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    title: Text(
                      member['display_name']?.toString() ?? 'Anggota',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${member['class_name'] ?? 'Kelas belum diisi'} • ${member['count']} penilaian',
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${member['total']} poin', style: const TextStyle(
                        fontWeight: FontWeight.w900, color: Color(0xFF167D68))),
                      if (admin) const SizedBox(width: 6),
                      if (admin) const Icon(Icons.edit_note_rounded, size: 20),
                    ]),
                    onTap: () => manageScores(member),
                  ),
                );
              },
            );
          },
        ),
      );
}

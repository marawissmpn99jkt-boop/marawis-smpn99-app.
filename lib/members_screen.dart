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

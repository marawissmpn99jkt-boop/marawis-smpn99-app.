import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgramTasksPanel extends StatefulWidget {
  const ProgramTasksPanel({
    super.key,
    required this.programId,
    required this.admin,
  });

  final int programId;
  final bool admin;

  @override
  State<ProgramTasksPanel> createState() => _ProgramTasksPanelState();
}

class _ProgramTasksPanelState extends State<ProgramTasksPanel> {
  final db = Supabase.instance.client;
  late Future<Map<String, dynamic>> future;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final results = await Future.wait([
      db
          .from('program_tasks')
          .select('id,title,assigned_to,due_date,status,notes')
          .eq('program_id', widget.programId)
          .order('created_at'),
      db.from('members').select('id,display_name').order('display_name'),
    ]);

    return {
      'tasks': List<Map<String, dynamic>>.from(results[0]),
      'members': List<Map<String, dynamic>>.from(results[1]),
    };
  }

  void _refresh() {
    if (mounted) setState(() => future = _load());
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
    );
  }

  String _dateLabel(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return 'Tanpa tenggat';
    return date.day.toString().padLeft(2, '0') +
        '/' +
        date.month.toString().padLeft(2, '0') +
        '/' +
        date.year.toString();
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'proses':
        return 'Sedang dikerjakan';
      case 'selesai':
        return 'Selesai';
      default:
        return 'Belum dikerjakan';
    }
  }

  Future<void> _editTask({
    required List<Map<String, dynamic>> members,
    Map<String, dynamic>? task,
  }) async {
    final title = TextEditingController(
      text: task?['title']?.toString() ?? '',
    );
    final notes = TextEditingController(
      text: task?['notes']?.toString() ?? '',
    );
    String assignedTo = task?['assigned_to']?.toString() ?? '';
    String status = (task?['status'] ?? 'belum').toString();
    DateTime? dueDate = DateTime.tryParse(task?['due_date']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    final memberIds = members.map((m) => m['id'].toString()).toSet();
    if (assignedTo.isNotEmpty && !memberIds.contains(assignedTo)) {
      assignedTo = '';
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: Text(task == null ? 'Tambah tugas' : 'Edit tugas'),
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
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Nama tugas',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Nama tugas wajib diisi.'
                              : null,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: assignedTo,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Penanggung jawab',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Belum ditentukan'),
                        ),
                        ...members.map(
                          (member) => DropdownMenuItem(
                            value: member['id'].toString(),
                            child: Text(
                              member['display_name']?.toString() ?? 'Anggota',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialog(() => assignedTo = value);
                        }
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                          value: 'belum',
                          child: Text('Belum dikerjakan'),
                        ),
                        DropdownMenuItem(
                          value: 'proses',
                          child: Text('Sedang dikerjakan'),
                        ),
                        DropdownMenuItem(
                          value: 'selesai',
                          child: Text('Selesai'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialog(() => status = value);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tenggat tugas'),
                      subtitle: Text(
                        dueDate == null
                            ? 'Belum ditentukan'
                            : _dateLabel(
                                dueDate!.year.toString() +
                                    '-' +
                                    dueDate!.month.toString().padLeft(2, '0') +
                                    '-' +
                                    dueDate!.day.toString().padLeft(2, '0'),
                              ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (dueDate != null)
                            IconButton(
                              tooltip: 'Hapus tenggat',
                              onPressed: () => setDialog(() => dueDate = null),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          IconButton(
                            tooltip: 'Pilih tanggal',
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: dialogContext,
                                initialDate: dueDate ?? DateTime.now(),
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setDialog(() => dueDate = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_month_rounded),
                          ),
                        ],
                      ),
                    ),
                    TextFormField(
                      controller: notes,
                      maxLines: 3,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (opsional)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => busy = true);
                      try {
                        final dateValue = dueDate == null
                            ? null
                            : dueDate!.year.toString() +
                                '-' +
                                dueDate!.month.toString().padLeft(2, '0') +
                                '-' +
                                dueDate!.day.toString().padLeft(2, '0');
                        final data = <String, dynamic>{
                          'title': title.text.trim(),
                          'assigned_to':
                              assignedTo.isEmpty ? null : assignedTo,
                          'due_date': dateValue,
                          'status': status,
                          'notes': notes.text.trim().isEmpty
                              ? null
                              : notes.text.trim(),
                          'updated_at': DateTime.now().toUtc().toIso8601String(),
                        };

                        if (task == null) {
                          data['program_id'] = widget.programId;
                          await db.from('program_tasks').insert(data);
                        } else {
                          await db
                              .from('program_tasks')
                              .update(data)
                              .eq('id', task['id'])
                              .eq('program_id', widget.programId);
                        }

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        _refresh();
                        _message(
                          task == null
                              ? 'Tugas berhasil ditambahkan.'
                              : 'Tugas berhasil diperbarui.',
                        );
                      } catch (error) {
                        _message('Gagal menyimpan tugas: ' + error.toString());
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan tugas'),
            ),
          ],
        ),
      ),
    );

    title.dispose();
    notes.dispose();
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus tugas?'),
        content: Text('Tugas "' + task['title'].toString() + '" akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yes != true) return;

    try {
      await db
          .from('program_tasks')
          .delete()
          .eq('id', task['id'])
          .eq('program_id', widget.programId);
      _refresh();
      _message('Tugas berhasil dihapus.');
    } catch (error) {
      _message('Gagal menghapus tugas: ' + error.toString());
    }
  }

  Future<void> _setTaskStatus(
    Map<String, dynamic> task,
    String status,
  ) async {
    try {
      await db
          .from('program_tasks')
          .update({
            'status': status,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', task['id'])
          .eq('program_id', widget.programId);
      _refresh();
      _message('Status tugas diperbarui.');
    } catch (error) {
      _message('Gagal memperbarui status tugas: ' + error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(14),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Row(
              children: [
                const Expanded(
                  child: Text(
                    'Daftar tugas belum bisa dimuat.',
                    style: TextStyle(color: Color(0xFF9B4B40), fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _refresh,
                  child: const Text('Coba lagi'),
                ),
              ],
            );
          }

          final tasks =
              snapshot.data?['tasks'] as List<Map<String, dynamic>>? ?? [];
          final members =
              snapshot.data?['members'] as List<Map<String, dynamic>>? ?? [];
          final names = {
            for (final member in members)
              member['id'].toString():
                  member['display_name']?.toString() ?? 'Anggota',
          };

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Daftar tugas (' + tasks.length.toString() + ')',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF167D68),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Muat ulang tugas',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 19),
                  ),
                  if (widget.admin)
                    IconButton(
                      tooltip: 'Tambah tugas',
                      onPressed: busy ? null : () => _editTask(members: members),
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Color(0xFF167D68),
                      ),
                    ),
                ],
              ),
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    widget.admin
                        ? 'Belum ada tugas. Tambahkan tugas untuk membagi pekerjaan program ini.'
                        : 'Belum ada tugas untuk program ini.',
                    style: const TextStyle(
                      color: Color(0xFF78877F),
                      fontSize: 12,
                    ),
                  ),
                ),
              ...tasks.map((task) {
                final status = task['status']?.toString() ?? 'belum';
                final assigned = task['assigned_to']?.toString();
                final assignee = assigned == null
                    ? 'Belum ditentukan'
                    : names[assigned] ?? 'Anggota tidak ditemukan';

                return Container(
                  margin: const EdgeInsets.only(top: 7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0xFFE6ECE8)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        status == 'selesai'
                            ? Icons.check_circle_rounded
                            : status == 'proses'
                                ? Icons.pending_rounded
                                : Icons.radio_button_unchecked_rounded,
                        color: const Color(0xFF167D68),
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task['title'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _statusLabel(status) +
                                  ' • ' +
                                  assignee +
                                  ' • ' +
                                  _dateLabel(task['due_date']),
                              style: const TextStyle(
                                color: Color(0xFF78877F),
                                fontSize: 10,
                              ),
                            ),
                            if ((task['notes'] ?? '').toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  task['notes'].toString(),
                                  style: const TextStyle(
                                    color: Color(0xFF56645C),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (widget.admin)
                        PopupMenuButton<String>(
                          tooltip: 'Aksi tugas',
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editTask(members: members, task: task);
                            } else if (value == 'delete') {
                              _deleteTask(task);
                            } else if (value.startsWith('status:')) {
                              _setTaskStatus(task, value.substring(7));
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'status:belum',
                              child: Text('Tandai belum dikerjakan'),
                            ),
                            PopupMenuItem(
                              value: 'status:proses',
                              child: Text('Tandai sedang dikerjakan'),
                            ),
                            PopupMenuItem(
                              value: 'status:selesai',
                              child: Text('Tandai selesai'),
                            ),
                            PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit tugas'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Hapus tugas'),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

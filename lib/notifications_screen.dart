import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.role});

  final String role;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;
  bool _busy = false;

  bool get _isAdmin => widget.role == 'pengurus' || widget.role == 'pembina';
  String get _userId => _client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await _client
        .from('notifications')
        .select('id,title,body,related_type,related_id,is_read,created_at')
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['is_read'] == true) return;
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', item['id'])
          .eq('user_id', _userId);
      _refresh();
    } catch (error) {
      _message('Gagal memperbarui notifikasi: $error');
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _busy = true);
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', _userId)
          .eq('is_read', false);
      _refresh();
      _message('Semua notifikasi sudah ditandai dibaca.');
    } catch (error) {
      _message('Gagal memperbarui notifikasi: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _compose() async {
    final title = TextEditingController();
    final body = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String audience = 'all';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Kirim notifikasi'),
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
                      maxLength: 90,
                      decoration: const InputDecoration(
                        labelText: 'Judul',
                        hintText: 'Contoh: Perubahan jadwal latihan',
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Judul wajib diisi.'
                          : null,
                    ),
                    TextFormField(
                      controller: body,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 1500,
                      decoration: const InputDecoration(
                        labelText: 'Pesan',
                        hintText: 'Tulis pesan untuk penerima...',
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Pesan wajib diisi.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: audience,
                      decoration: const InputDecoration(
                        labelText: 'Penerima',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Semua pengguna'),
                        ),
                        DropdownMenuItem(
                          value: 'anggota',
                          child: Text('Anggota saja'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Pengurus & Pembina'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => audience = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Kirim'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      title.dispose();
      body.dispose();
      return;
    }

    setState(() => _busy = true);
    try {
      final profiles = await _client.from('profiles').select('id,role');
      final recipients = List<Map<String, dynamic>>.from(profiles).where((p) {
        final role = p['role']?.toString() ?? 'anggota';
        if (audience == 'anggota') return role == 'anggota';
        if (audience == 'admin') return role == 'pengurus' || role == 'pembina';
        return true;
      }).toList();

      if (recipients.isEmpty) {
        _message('Belum ada akun yang sesuai dengan penerima tersebut.');
        return;
      }

      final rows = recipients
          .map((profile) => <String, dynamic>{
                'user_id': profile['id'],
                'title': title.text.trim(),
                'body': body.text.trim(),
                'related_type': 'broadcast',
              })
          .toList();

      await _client.from('notifications').insert(rows);
      _message('Notifikasi berhasil dikirim ke ${recipients.length} akun.');
      _refresh();
    } catch (error) {
      _message('Gagal mengirim notifikasi: $error');
    } finally {
      title.dispose();
      body.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  String _dateLabel(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year} • '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifikasi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Tandai semua dibaca',
            onPressed: _busy ? null : _markAllRead,
            icon: const Icon(Icons.done_all_rounded),
          ),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _compose,
              backgroundColor: const Color(0xFF167D68),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Kirim notifikasi'),
            )
          : null,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _NotificationEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Notifikasi belum bisa dimuat',
              subtitle: 'Periksa koneksi internet, lalu coba lagi.',
              action: TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return _NotificationEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Belum ada notifikasi',
              subtitle: _isAdmin
                  ? 'Kirim informasi penting kepada anggota melalui tombol di bawah.'
                  : 'Pemberitahuan organisasi akan muncul di sini.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final unread = item['is_read'] != true;
                return Material(
                  color: unread ? const Color(0xFFEFF8F3) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _markRead(item),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: unread
                              ? const Color(0xFFB9DDCA)
                              : const Color(0xFFE6ECE8),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: unread
                                ? const Color(0xFFD9EFE2)
                                : const Color(0xFFF0F3F1),
                            child: Icon(
                              unread
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_none_rounded,
                              color: const Color(0xFF167D68),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['title']?.toString() ?? 'Notifikasi',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (unread)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF167D68),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item['body']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: Color(0xFF56645C),
                                    height: 1.45,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _dateLabel(item['created_at']),
                                  style: const TextStyle(
                                    color: Color(0xFF87938C),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF167D68)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF78877F),
                height: 1.5,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

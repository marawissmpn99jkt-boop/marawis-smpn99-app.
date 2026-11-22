import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VotingScreen extends StatefulWidget {
  const VotingScreen({super.key, required this.role});
  final String role;

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  final db = Supabase.instance.client;
  bool busy = false;
  bool get staff => widget.role == 'pengurus' || widget.role == 'pembina';

  void message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> reload() async {
    if (mounted) setState(() {});
  }

  Future<void> createVote() async {
    final title = TextEditingController();
    final description = TextEditingController();
    final choices = TextEditingController();
    final deadline = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat voting baru'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, maxLength: 160,
                decoration: const InputDecoration(labelText: 'Judul voting')),
              TextField(controller: description, maxLines: 3,
                decoration: const InputDecoration(labelText: 'Deskripsi / konteks (opsional)')),
              TextField(controller: choices, minLines: 3, maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Pilihan (satu pilihan per baris)',
                  hintText: 'Pilihan A\nPilihan B\nPilihan C',
                )),
              TextField(controller: deadline,
                decoration: const InputDecoration(
                  labelText: 'Batas waktu ISO (opsional)',
                  hintText: '2026-12-31T23:59:00+07:00',
                )),
              const SizedBox(height: 6),
              const Text('Anggota hanya dapat memberikan satu suara dan tidak dapat mengubah pilihannya.',
                style: TextStyle(fontSize: 11, color: Color(0xFF718078))),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: busy ? null : () async {
              final labels = choices.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              if (title.text.trim().length < 3 || labels.length < 2 || labels.length > 8) {
                message('Isi judul dan 2 sampai 8 pilihan voting.');
                return;
              }
              DateTime? endAt;
              if (deadline.text.trim().isNotEmpty) {
                endAt = DateTime.tryParse(deadline.text.trim());
                if (endAt == null || !endAt.isAfter(DateTime.now())) {
                  message('Format atau waktu batas voting tidak valid.');
                  return;
                }
              }
              setState(() => busy = true);
              try {
                final row = await db.from('marawis_votes').insert({
                  'title': title.text.trim(),
                  'description': description.text.trim(),
                  'created_by': db.auth.currentUser!.id,
                  if (endAt != null) 'ends_at': endAt.toUtc().toIso8601String(),
                }).select('id').single();
                await db.from('marawis_vote_options').insert([
                  for (var i = 0; i < labels.length; i++)
                    {'vote_id': row['id'], 'label': labels[i], 'position': i}
                ]);
                if (ctx.mounted) Navigator.pop(ctx);
                message('Voting berhasil dibuat dan dibuka.');
                await reload();
              } catch (e) {
                message('Gagal membuat voting: $e');
              } finally {
                if (mounted) setState(() => busy = false);
              }
            },
            child: const Text('Terbitkan voting'),
          ),
        ],
      ),
    );
    title.dispose();
    description.dispose();
    choices.dispose();
    deadline.dispose();
  }

  Future<void> castVote(Map<String, dynamic> vote, String optionId) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await db.from('marawis_vote_ballots').insert({
        'vote_id': vote['id'],
        'option_id': optionId,
        'user_id': db.auth.currentUser!.id,
      });
      message('Suara berhasil direkam. Pilihan tidak dapat diubah.');
      await reload();
    } catch (e) {
      message('Suara tidak dapat dikirim. Pastikan voting masih dibuka dan akun belum pernah memilih. ($e)');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> closeVote(Map<String, dynamic> vote) async {
    try {
      await db.from('marawis_votes').update({
        'status': 'closed',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', vote['id']);
      message('Voting ditutup. Hasil akhir sekarang dapat dilihat.');
      await reload();
    } catch (e) {
      message('Gagal menutup voting: $e');
    }
  }

  String dateLabel(dynamic value) {
    if (value == null) return 'Tanpa batas waktu';
    final parsed = DateTime.tryParse(value.toString())?.toLocal();
    if (parsed == null) return value.toString();
    return 'Ditutup: ${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  Widget resultList(String voteId) => FutureBuilder<List<Map<String, dynamic>>>(
    future: db.from('marawis_vote_results').select().eq('vote_id', voteId),
    builder: (context, snapshot) {
      if (snapshot.hasError) return Text('Hasil tidak dapat dimuat: ${snapshot.error}');
      if (!snapshot.hasData) return const Padding(
        padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
      final rows = snapshot.data!;
      final total = rows.fold<int>(0, (sum, row) => sum + ((row['vote_count'] as num?)?.toInt() ?? 0));
      return Column(children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(row['option_label'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700))),
                Text('${row['vote_count']} suara • ${total == 0 ? 0 : ((row['vote_count'] as num).toDouble() / total * 100).round()}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 5),
              ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(
                minHeight: 8,
                value: total == 0 ? 0 : (row['vote_count'] as num).toDouble() / total,
                backgroundColor: const Color(0xFFE8EEEA),
                color: const Color(0xFF167D68),
              )),
            ]),
          ),
        const SizedBox(height: 4),
        Align(alignment: Alignment.centerRight, child: Text('Total: $total suara',
          style: const TextStyle(color: Color(0xFF718078), fontSize: 11))),
      ]);
    },
  );

  Widget voteCard(Map<String, dynamic> vote) {
    final id = vote['id'].toString();
    final isClosed = vote['status'] == 'closed' ||
      (vote['ends_at'] != null && DateTime.tryParse(vote['ends_at'].toString())?.isBefore(DateTime.now()) == true);
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        db.from('marawis_vote_options').select().eq('vote_id', id).order('position'),
        db.from('marawis_vote_ballots').select('option_id').eq('vote_id', id).eq('user_id', db.auth.currentUser!.id).maybeSingle(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Card(child: Padding(
          padding: const EdgeInsets.all(16), child: Text('Gagal memuat voting: ${snapshot.error}')));
        if (!snapshot.hasData) return const Card(
          child: Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator())));
        final options = List<Map<String, dynamic>>.from(snapshot.data![0] as List);
        final ballot = snapshot.data![1] as Map<String, dynamic>?;
        final voted = ballot != null;
        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 14),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(vote['title'].toString(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: isClosed ? const Color(0xFFF0F1F0) : const Color(0xFFE5F4EC),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text(isClosed ? 'DITUTUP' : 'DIBUKA',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                      color: isClosed ? const Color(0xFF6D7771) : const Color(0xFF167D68))),
                ),
              ]),
              if ((vote['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(vote['description'].toString(),
                  style: const TextStyle(color: Color(0xFF66756D), fontSize: 12, height: 1.45)),
              ],
              const SizedBox(height: 8),
              Text(dateLabel(vote['ends_at']),
                style: const TextStyle(fontSize: 10, color: Color(0xFF87938C))),
              const Divider(height: 22),
              if (isClosed) ...[
                const Text('HASIL VOTING', style: TextStyle(fontSize: 10,
                  letterSpacing: 1, fontWeight: FontWeight.w900, color: Color(0xFF167D68))),
                const SizedBox(height: 10),
                resultList(id),
              ] else if (voted) ...[
                const Row(children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF167D68), size: 19),
                  SizedBox(width: 7),
                  Expanded(child: Text('Suara kamu sudah tercatat. Hasil akan ditampilkan setelah voting ditutup.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                ]),
              ] else ...[
                const Text('Pilih satu jawaban:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 5),
                for (final option in options)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFF167D68)),
                    title: Text(option['label'].toString(), style: const TextStyle(fontSize: 13)),
                    onTap: busy ? null : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Konfirmasi pilihan'),
                          content: Text('Kirim suara untuk "${option['label']}"? Suara tidak dapat diubah setelah dikirim.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, pilih')),
                          ],
                        ),
                      );
                      if (confirmed == true) await castVote(vote, option['id'].toString());
                    },
                  ),
              ],
              if (staff) ...[
                const Divider(),
                Row(children: [
                  const Icon(Icons.admin_panel_settings_outlined, size: 17, color: Color(0xFF718078)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(voted ? 'Kamu sudah memilih' : 'Kelola voting',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF718078)))),
                  if (!isClosed) TextButton.icon(
                    onPressed: () => closeVote(vote),
                    icon: const Icon(Icons.lock_outline_rounded, size: 16),
                    label: const Text('Tutup voting'),
                  ),
                ]),
              ],
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Voting Digital'),
      actions: [if (staff) IconButton(
        tooltip: 'Buat voting',
        onPressed: createVote,
        icon: const Icon(Icons.add_circle_outline_rounded),
      )]),
    body: RefreshIndicator(
      onRefresh: reload,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: db.from('marawis_votes').select().order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.hasError) return ListView(children: [
            Padding(padding: const EdgeInsets.all(24), child: Text('Voting gagal dimuat: ${snapshot.error}'))]);
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final votes = snapshot.data!.where((v) => staff || v['status'] != 'draft').toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(19),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(21),
                gradient: const LinearGradient(colors: [Color(0xFF123F35), Color(0xFF229B7C)])),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SUARA ANGGOTA, KEPUTUSAN BERSAMA',
                  style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('Sampaikan pilihanmu secara langsung dan transparan.',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                SizedBox(height: 7),
                Text('Setiap akun hanya dapat memilih satu kali dalam setiap voting.',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 16),
            if (votes.isEmpty)
              const Padding(padding: EdgeInsets.all(30), child: Column(children: [
                Icon(Icons.how_to_vote_outlined, size: 42, color: Color(0xFF9AA69F)),
                SizedBox(height: 10),
                Text('Belum ada voting tersedia.', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Voting baru akan muncul di halaman ini.',
                  style: TextStyle(color: Color(0xFF7B8981), fontSize: 12)),
              ]))
            else
              for (final vote in votes) voteCard(vote),
          ]);
        },
      ),
    ),
    floatingActionButton: staff ? FloatingActionButton.extended(
      onPressed: createVote,
      icon: const Icon(Icons.add),
      label: const Text('Buat voting'),
    ) : null,
  );
}

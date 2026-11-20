import 'package:material_ui/material_ui.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:supabase_flutter/supabase_flutter.dart';

class MarawisSmartScreen extends StatefulWidget {
  const MarawisSmartScreen({super.key, required this.role});
  final String role;
  @override
  State<MarawisSmartScreen> createState() => _MarawisSmartScreenState();
}

class _MarawisSmartScreenState extends State<MarawisSmartScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs;
  @override
  void initState() { super.initState(); tabs = TabController(length: 4, vsync: this); }
  @override
  void dispose() { tabs.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Marawis Smart Center'), bottom: TabBar(
      controller: tabs, isScrollable: true,
      tabs: const [
        Tab(icon: Icon(Icons.auto_awesome), text: 'AI Assistant'),
        Tab(icon: Icon(Icons.bolt), text: 'Challenge'),
        Tab(icon: Icon(Icons.notifications_active), text: 'Reminder'),
        Tab(icon: Icon(Icons.workspace_premium), text: 'Achievement'),
      ],
    )),
    body: TabBarView(controller: tabs, children: const [
      _AiAssistantTab(), _WeeklyChallengeTab(), _SmartReminderTab(), _AchievementTab(),
    ]),
  );
}

class _AiAssistantTab extends StatefulWidget {
  const _AiAssistantTab();
  @override
  State<_AiAssistantTab> createState() => _AiAssistantTabState();
}
class _AiAssistantTabState extends State<_AiAssistantTab> {
  final db = Supabase.instance.client;
  final input = TextEditingController();
  final messages = <Map<String, String>>[
    {'role': 'assistant', 'text': 'Halo! Aku Asisten Marawis. Tanya seputar organisasi, kegiatan, program kerja, latihan, atau materi dasar Marawis.'}
  ];
  bool sending = false;
  @override
  void dispose() { input.dispose(); super.dispose(); }
  Future<void> send([String? preset]) async {
    final text = (preset ?? input.text).trim();
    if (text.isEmpty || sending) return;
    input.clear();
    setState(() { messages.add({'role': 'user', 'text': text}); sending = true; });
    try {
      final res = await db.functions.invoke('marawis-ai', body: {
        'message': text,
        'history': messages.take(messages.length - 1).map((m) => {
          'role': m['role'], 'content': m['text'],
        }).toList(),
      });
      final data = res.data;
      final reply = data is Map ? data['reply']?.toString() : null;
      if (reply == null || reply.trim().isEmpty) throw Exception('empty');
      if (mounted) setState(() => messages.add({'role': 'assistant', 'text': reply}));
    } catch (_) {
      if (mounted) setState(() => messages.add({
        'role': 'assistant',
        'text': 'Layanan AI belum aktif atau sedang tidak tersedia. Pastikan GROQ_API_KEY sudah dipasang pada Supabase Edge Function Secrets, lalu coba lagi.',
      }));
    } finally { if (mounted) setState(() => sending = false); }
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: const Color(0xFFE8F4EF), borderRadius: BorderRadius.circular(15)),
      child: const Row(children: [
        Icon(Icons.auto_awesome, color: Color(0xFF167D68), size: 28), SizedBox(width: 10),
        Expanded(child: Text('Asisten khusus Marawis SMPN 99. Jangan masukkan kata sandi, OTP, atau data pribadi.')),
      ]),
    ),
    Expanded(child: ListView.builder(
      padding: const EdgeInsets.all(12), itemCount: messages.length + (sending ? 1 : 0),
      itemBuilder: (context, i) {
        if (sending && i == messages.length) return const Padding(
          padding: EdgeInsets.all(12), child: Text('Asisten sedang berpikir...'),
        );
        final m = messages[i]; final mine = m['role'] == 'user';
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620),
            margin: const EdgeInsets.symmetric(vertical: 5), padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: mine ? const Color(0xFF167D68) : Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: mine
                ? Text(m['text'] ?? '', style: const TextStyle(color: Colors.white, height: 1.45))
                : MarkdownBody(
                    data: m['text'] ?? '',
                    selectable: true,
                    extensionSet: md.ExtensionSet.gitHubFlavored,
                    styleSheet: MarkdownStyleSheet.fromTheme(flutter.ThemeData()).copyWith(
                      p: const TextStyle(color: Color(0xFF20332D), fontSize: 14, height: 1.6),
                      h1: const TextStyle(color: Color(0xFF173D32), fontSize: 21, fontWeight: FontWeight.w900, height: 1.3),
                      h2: const TextStyle(color: Color(0xFF173D32), fontSize: 18, fontWeight: FontWeight.w800, height: 1.3),
                      h3: const TextStyle(color: Color(0xFF173D32), fontSize: 16, fontWeight: FontWeight.w800, height: 1.3),
                      strong: const TextStyle(color: Color(0xFF173D32), fontWeight: FontWeight.w900),
                      em: const TextStyle(color: Color(0xFF42574F), fontStyle: FontStyle.italic),
                      listBullet: const TextStyle(color: Color(0xFF167D68), fontSize: 14, height: 1.5),
                      code: const TextStyle(backgroundColor: Color(0xFFF0F3F1), color: Color(0xFF145B49), fontSize: 12),
                      blockquote: const TextStyle(color: Color(0xFF52645C), fontStyle: FontStyle.italic, height: 1.5),
                      tableHead: const TextStyle(color: Color(0xFF173D32), fontWeight: FontWeight.w900),
                      tableBody: const TextStyle(color: Color(0xFF20332D), fontSize: 12, height: 1.4),
                      horizontalRuleDecoration: const BoxDecoration(color: Color(0xFFE3EAE5)),
                    ),
                  ),
          ),
        );
      },
    )),
    if (messages.length == 1) Wrap(spacing: 6, children: [
      ActionChip(label: const Text('Tugas pengurus'), onPressed: () => send('Apa tugas pengurus Marawis?')),
      ActionChip(label: const Text('Tips latihan'), onPressed: () => send('Berikan tips latihan Marawis yang efektif.')),
      ActionChip(label: const Text('Alat musik'), onPressed: () => send('Jelaskan alat-alat musik Marawis.')),
    ]),
    SafeArea(top: false, child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(children: [
        Expanded(child: TextField(
          controller: input, minLines: 1, maxLines: 4,
          onSubmitted: (_) => send(),
          decoration: const InputDecoration(hintText: 'Tulis pertanyaan...', border: OutlineInputBorder()),
        )),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: sending ? null : send, icon: const Icon(Icons.send_rounded)),
      ]),
    )),
  ]);
}

class _WeeklyChallengeTab extends StatefulWidget {
  const _WeeklyChallengeTab();
  @override
  State<_WeeklyChallengeTab> createState() => _WeeklyChallengeTabState();
}
class _WeeklyChallengeTabState extends State<_WeeklyChallengeTab> {
  final db = Supabase.instance.client;
  final questions = <Map<String, dynamic>>[
    {'q':'Apa fungsi utama latihan bersama?','a':['Menyamakan tempo dan kekompakan','Membuat anggota bersaing','Menghindari evaluasi','Mempercepat selesai'],'c':0},
    {'q':'Sikap yang tepat saat pemimpin memberi aba-aba adalah...','a':['Mengabaikan','Mendengarkan dan mengikuti','Bermain lebih cepat','Berbicara sendiri'],'c':1},
    {'q':'Jika alat musik selesai digunakan, kita sebaiknya...','a':['Meninggalkannya','Menyimpannya dengan baik','Meminjamkan tanpa izin','Membiarkannya di lantai'],'c':1},
    {'q':'Apa yang perlu diperhatikan saat tampil bersama?','a':['Tempo, formasi, dan koordinasi','Hanya penampilan sendiri','Bermain sekeras mungkin','Mengubah susunan mendadak'],'c':0},
    {'q':'Jika teman belum menguasai bagian lagu, tindakan terbaik adalah...','a':['Mengejeknya','Membiarkan saja','Membantu latihan dengan sabar','Mengeluarkannya'],'c':2},
  ];
  int index = 0, score = 0;
  bool loading = true, already = false, done = false, saving = false;
  late String gameKey;
  @override
  void initState() { super.initState(); load(); }
  String makeWeekKey() {
    final now = DateTime.now();
    final week = now.difference(DateTime(now.year, 1, 1)).inDays ~/ 7 + 1;
    return 'weekly-challenge-' + now.year.toString() + '-' + week.toString();
  }
  Future<void> load() async {
    gameKey = makeWeekKey();
    try {
      final rows = await db.from('marawis_game_scores').select('id')
        .eq('user_id', db.auth.currentUser!.id).eq('game_key', gameKey).limit(1);
      already = (rows as List).isNotEmpty;
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }
  Future<void> answer(int choice) async {
    if (saving || done) return;
    if (choice == questions[index]['c']) score += 20;
    if (index < questions.length - 1) { setState(() => index++); return; }
    setState(() => saving = true);
    try {
      await db.from('marawis_game_scores').insert({
        'user_id': db.auth.currentUser!.id, 'game_key': gameKey, 'score': score,
      });
      if (mounted) setState(() { done = true; already = true; saving = false; });
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skor belum tersimpan. Coba lagi nanti.')));
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (already && !done) return const Center(child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified_rounded, size: 58, color: Color(0xFF167D68)),
        SizedBox(height: 12),
        Text('Challenge minggu ini sudah kamu selesaikan!', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        SizedBox(height: 8),
        Text('Tantangan baru tersedia pada minggu berikutnya.', textAlign: TextAlign.center),
      ]),
    ));
    if (done) return Center(child: Card(
      margin: const EdgeInsets.all(20), child: Padding(
        padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events_rounded, size: 64, color: Color(0xFFC58B2A)),
          const Text('Challenge selesai!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text('Skor kamu: ' + score.toString() + ' / 100'),
          const SizedBox(height: 8), const Text('Skor tersimpan di riwayat Game Marawis.'),
        ]),
      ),
    ));
    final q = questions[index];
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(18), children: [
        Card(color: const Color(0xFFE8F4EF), child: Padding(
          padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TANTANGAN MINGGUAN', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF167D68))),
            const SizedBox(height: 5), const Text('Selesaikan 5 pertanyaan untuk mengumpulkan skor mingguan.'),
            const SizedBox(height: 12), LinearProgressIndicator(value: (index + 1) / questions.length),
            const SizedBox(height: 5), Text('Pertanyaan ' + (index + 1).toString() + ' dari ' + questions.length.toString()),
          ]),
        )),
        const SizedBox(height: 12),
        Text(q['q'].toString(), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        for (var i = 0; i < (q['a'] as List).length; i++)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: saving ? null : () => answer(i),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text((q['a'] as List)[i].toString())),
            ),
          )),
        if (saving) const Center(child: CircularProgressIndicator()),
      ]),
    ));
  }
}

class _SmartReminderTab extends StatefulWidget {
  const _SmartReminderTab();
  @override
  State<_SmartReminderTab> createState() => _SmartReminderTabState();
}
class _SmartReminderTabState extends State<_SmartReminderTab> {
  final db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() { super.initState(); future = load(); }
  Future<List<Map<String, dynamic>>> load() async {
    final now = DateTime.now();
    final id = db.auth.currentUser!.id;
    final res = await Future.wait([
      db.from('activities').select('id,title,location,starts_at,activity_type')
        .gte('starts_at', now.toUtc().toIso8601String()).order('starts_at').limit(20),
      db.from('program_tasks').select('id,title,due_date,status')
        .eq('assigned_to', id).neq('status', 'selesai').order('due_date').limit(20),
    ]);
    final items = <Map<String, dynamic>>[];
    for (final row in List<Map<String, dynamic>>.from(res[0] as List)) { items.add({...row, '_kind':'activity'}); }
    for (final row in List<Map<String, dynamic>>.from(res[1] as List)) {
      if (row['due_date'] != null) items.add({...row, '_kind':'task'});
    }
    items.sort((a,b) {
      final ad = a['_kind'] == 'activity'
        ? DateTime.tryParse(a['starts_at'].toString()) ?? DateTime(2100)
        : DateTime.tryParse(a['due_date'].toString() + 'T00:00:00') ?? DateTime(2100);
      final bd = b['_kind'] == 'activity'
        ? DateTime.tryParse(b['starts_at'].toString()) ?? DateTime(2100)
        : DateTime.tryParse(b['due_date'].toString() + 'T00:00:00') ?? DateTime(2100);
      return ad.compareTo(bd);
    });
    return items;
  }
  String dateLabel(Map<String, dynamic> item) {
    final date = item['_kind'] == 'activity'
      ? DateTime.tryParse(item['starts_at'].toString())?.toLocal()
      : DateTime.tryParse(item['due_date'].toString() + 'T00:00:00');
    if (date == null) return 'Waktu belum tersedia';
    final day = date.day.toString().padLeft(2,'0');
    final month = date.month.toString().padLeft(2,'0');
    final time = item['_kind'] == 'activity'
      ? ' • ' + date.hour.toString().padLeft(2,'0') + ':' + date.minute.toString().padLeft(2,'0')
      : '';
    return day + '/' + month + '/' + date.year.toString() + time;
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(14), child: Row(children: [
      const Expanded(child: Text('Jadwal kegiatan dan tugas yang perlu kamu perhatikan.', style: TextStyle(fontWeight: FontWeight.w600))),
      IconButton(onPressed: () => setState(() => future = load()), icon: const Icon(Icons.refresh)),
    ])),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context,snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: TextButton(onPressed: () => setState(() => future = load()), child: const Text('Gagal memuat. Coba lagi.')));
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const Center(child: Padding(
          padding: EdgeInsets.all(24), child: Text('Belum ada jadwal mendatang atau tugas yang perlu diselesaikan.', textAlign: TextAlign.center),
        ));
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14,0,14,18), itemCount: items.length,
          itemBuilder: (context,i) {
            final item = items[i]; final activity = item['_kind'] == 'activity';
            final location = item['location'];
            return Card(child: ListTile(
              leading: CircleAvatar(
                backgroundColor: activity ? const Color(0xFFE8F4EF) : const Color(0xFFFFF1DF),
                child: Icon(activity ? Icons.event_available : Icons.assignment_late_outlined, color: activity ? const Color(0xFF167D68) : const Color(0xFFB87921)),
              ),
              title: Text(item['title']?.toString() ?? 'Tanpa judul', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text((activity ? 'Kegiatan' : 'Tugas') + ' • ' + dateLabel(item) + (location == null ? '' : '\nLokasi: ' + location.toString())),
              isThreeLine: location != null,
            ));
          },
        );
      },
    )),
    const Padding(
      padding: EdgeInsets.fromLTRB(16,0,16,12),
      child: Text('Ini pengingat di dalam aplikasi. Notifikasi otomatis saat aplikasi tertutup memerlukan integrasi push notification terpisah.', style: TextStyle(fontSize: 11, color: Colors.black54), textAlign: TextAlign.center),
    ),
  ]);
}

class _AchievementTab extends StatefulWidget {
  const _AchievementTab();
  @override
  State<_AchievementTab> createState() => _AchievementTabState();
}
class _AchievementTabState extends State<_AchievementTab> {
  final db = Supabase.instance.client;
  late Future<Map<String,int>> future;
  @override
  void initState() { super.initState(); future = load(); }
  Future<Map<String,int>> load() async {
    final id = db.auth.currentUser!.id;
    final res = await Future.wait([
      db.from('attendance').select('id').eq('member_id', id).eq('status','hadir'),
      db.from('marawis_quiz_attempts').select('id').eq('user_id', id),
      db.from('marawis_game_scores').select('id,score').eq('user_id', id),
      db.from('member_scores').select('id').eq('member_id', id),
    ]);
    final games = List<Map<String,dynamic>>.from(res[2] as List);
    return {
      'attendance': (res[0] as List).length,
      'quizzes': (res[1] as List).length,
      'games': games.length,
      'perfect': games.where((g) => (g['score'] as num? ?? 0) >= 100).length,
      'contributions': (res[3] as List).length,
    };
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String,int>>(
    future: future,
    builder: (context,snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: TextButton(onPressed: () => setState(() => future = load()), child: const Text('Gagal memuat badge. Coba lagi.')));
      final s = snapshot.data!;
      final badges = [
        ('Langkah Pertama','Hadir dalam satu kegiatan latihan.',Icons.directions_walk,s['attendance']! >= 1),
        ('Anggota Konsisten','Mengikuti minimal lima kegiatan.',Icons.event_available,s['attendance']! >= 5),
        ('Pemburu Ilmu','Menyelesaikan Quiz pertama.',Icons.menu_book,s['quizzes']! >= 1),
        ('Penjelajah Game','Menyelesaikan permainan pertama.',Icons.sports_esports,s['games']! >= 1),
        ('Skor Sempurna','Mendapatkan skor 100 dalam permainan.',Icons.stars,s['perfect']! >= 1),
        ('Kontributor','Mendapatkan penilaian kontribusi pertama.',Icons.volunteer_activism,s['contributions']! >= 1),
      ];
      final unlocked = badges.where((b) => b.$4).length;
      return ListView(padding: const EdgeInsets.all(16), children: [
        Card(color: const Color(0xFFE8F4EF), child: Padding(
          padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('KOLEKSI PENCAPAIAN', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF167D68))),
            const SizedBox(height: 6),
            Text(unlocked.toString() + ' dari ' + badges.length.toString() + ' badge terbuka', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10), LinearProgressIndicator(value: unlocked / badges.length),
          ]),
        )),
        const SizedBox(height: 8),
        for (final b in badges) Card(child: ListTile(
          leading: CircleAvatar(
            backgroundColor: b.$4 ? const Color(0xFFFFF1D6) : const Color(0xFFECEFED),
            child: Icon(b.$3, color: b.$4 ? const Color(0xFFB87921) : Colors.grey),
          ),
          title: Text(b.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(b.$2),
          trailing: Icon(b.$4 ? Icons.check_circle : Icons.lock_outline, color: b.$4 ? const Color(0xFF167D68) : Colors.grey),
        )),
        Align(alignment: Alignment.center, child: TextButton.icon(
          onPressed: () => setState(() => future = load()),
          icon: const Icon(Icons.refresh), label: const Text('Perbarui pencapaian'),
        )),
      ]);
    },
  );
}

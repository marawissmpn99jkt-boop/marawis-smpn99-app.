import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
  final chatScroll = ScrollController();
  final messages = <Map<String, String>>[
    {'role': 'assistant', 'text': 'Halo! Aku Asisten Marawis. Tanya seputar organisasi, kegiatan, program kerja, latihan, atau materi dasar Marawis.'}
  ];
  bool sending = false;
  @override
  void dispose() { input.dispose(); chatScroll.dispose(); super.dispose(); }
  void scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !chatScroll.hasClients) return;
      chatScroll.animateTo(chatScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    });
  }
  Future<void> send([String? preset]) async {
    final text = (preset ?? input.text).trim();
    if (text.isEmpty || sending) return;
    input.clear();
    setState(() { messages.add({'role': 'user', 'text': text}); sending = true; });
    scrollToLatest();
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
      if (mounted) { setState(() => messages.add({'role': 'assistant', 'text': reply})); scrollToLatest(); }
    } catch (error) {
      final diagnostic = error.toString();
      final detail = diagnostic.length > 420 ? diagnostic.substring(0, 420) + '…' : diagnostic;
      if (mounted) setState(() => messages.add({
        'role': 'assistant',
        'text': diagnostic.contains('FunctionException')
            ? 'AI belum bisa membalas. Detail dari server: $detail'
            : 'Koneksi ke layanan AI gagal. Periksa koneksi internet lalu coba lagi. Detail: $detail',
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
    Expanded(child: Container(
      width: double.infinity,
      color: const Color(0xFFF6F9F7),
      child: ListView.builder(
      controller: chatScroll,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16), itemCount: messages.length + (sending ? 1 : 0),
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
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: Color(0xFF20332D), fontSize: 14, height: 1.6),
                      h1: const TextStyle(color: Color(0xFF173D32), fontSize: 21, fontWeight: FontWeight.w900, height: 1.3),
                      h2: const TextStyle(color: Color(0xFF173D32), fontSize: 18, fontWeight: FontWeight.w800, height: 1.3),
                      h3: const TextStyle(color: Color(0xFF173D32), fontSize: 16, fontWeight: FontWeight.w800, height: 1.3),
                      strong: const TextStyle(color: Color(0xFF173D32), fontWeight: FontWeight.w900),
                      em: const TextStyle(color: Color(0xFF42574F), fontStyle: FontStyle.italic),
                      listBullet: const TextStyle(color: Color(0xFF167D68), fontSize: 14, height: 1.5),
                    ),
                  ),
          ),
        );
      },
    )),
    ),
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
  List<Map<String, dynamic>> questions = [];
  List<int> answers = [];
  List<Map<String, dynamic>> leaderboard = [];
  int index = 0, score = 0;
  bool loading = true, already = false, done = false, saving = false;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await db.rpc('get_weekly_marawis_challenge');
      final data = Map<String, dynamic>.from(result as Map);
      questions = List<Map<String, dynamic>>.from(
        (data['questions'] as List? ?? []).map((q) => Map<String, dynamic>.from(q as Map)),
      );
      already = data['completed'] == true;
      score = (data['score'] as num?)?.toInt() ?? 0;
      answers = List<int>.filled(questions.length, -1);
      if (questions.length != 5) throw Exception('Bank challenge belum lengkap.');
      if (already) await loadLeaderboard();
    } catch (e) {
      error = 'Gagal memuat challenge: $e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadLeaderboard() async {
    try {
      final rows = await db.rpc('get_weekly_marawis_leaderboard');
      leaderboard = List<Map<String, dynamic>>.from(
        (rows as List).map((r) => Map<String, dynamic>.from(r as Map)),
      );
    } catch (_) { leaderboard = []; }
  }

  Future<void> answer(int choice) async {
    if (saving || done || index >= questions.length) return;
    answers[index] = choice;
    if (index < questions.length - 1) {
      setState(() => index++);
      return;
    }
    if (answers.any((a) => a < 0)) return;
    setState(() => saving = true);
    try {
      final result = await db.rpc('submit_weekly_marawis_challenge', params: {
        'p_answers': answers,
      });
      final data = Map<String, dynamic>.from(result as Map);
      score = (data['score'] as num?)?.toInt() ?? 0;
      await loadLeaderboard();
      if (mounted) setState(() { done = true; already = true; saving = false; });
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Skor gagal disimpan: $e')),
        );
      }
    }
  }

  Widget leaderboardView() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('PAPAN PERINGKAT MINGGU INI',
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF167D68))),
        const SizedBox(height: 10),
        if (leaderboard.isEmpty)
          const Text('Belum ada anggota yang menyelesaikan challenge minggu ini.'),
        for (var i = 0; i < leaderboard.length; i++)
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: i == 0 ? const Color(0xFFFFE8B5) : const Color(0xFFE8F4EF),
              child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            title: Text(leaderboard[i]['full_name']?.toString() ?? 'Anggota'),
            trailing: Text('${leaderboard[i]['score']} / 100',
              style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(error!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
      ]),
    ));
    if (already || done) return ListView(padding: const EdgeInsets.all(18), children: [
      Card(color: const Color(0xFFE8F4EF), child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Icon(Icons.emoji_events_rounded, size: 56, color: Color(0xFFC58B2A)),
          const SizedBox(height: 8),
          Text(done ? 'Challenge selesai!' : 'Challenge minggu ini sudah selesai',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center),
          Text(done ? 'Skor kamu: $score / 100' : 'Skor kamu: $score / 100'),
          const SizedBox(height: 6),
          const Text('Tantangan berikutnya tersedia minggu depan.', textAlign: TextAlign.center),
        ]),
      )),
      leaderboardView(),
      TextButton.icon(onPressed: () async { await load(); }, icon: const Icon(Icons.refresh), label: const Text('Perbarui papan peringkat')),
    ]);
    final q = questions[index];
    final options = List<String>.from(q['options'] as List);
    return ListView(padding: const EdgeInsets.all(18), children: [
      Card(color: const Color(0xFFE8F4EF), child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('TANTANGAN MINGGUAN', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF167D68))),
          const SizedBox(height: 5),
          const Text('Lima pertanyaan acak. Skor dihitung langsung dan divalidasi oleh server.'),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: (index + 1) / questions.length),
          const SizedBox(height: 5),
          Text('Pertanyaan ${index + 1} dari ${questions.length}'),
        ]),
      )),
      const SizedBox(height: 14),
      Text(q['question'].toString(), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      for (var i = 0; i < options.length; i++)
        Padding(padding: const EdgeInsets.only(bottom: 9), child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: saving ? null : () => answer(i),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 11), child: Text(options[i])),
          ),
        )),
      if (saving) const Center(child: CircularProgressIndicator()),
    ]);
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
  bool enablingPush = false;
  bool sendingTest = false;
  String? pushStatus;
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
      db.from('marawis_reminder_queue').select('id,title,body,scheduled_for')
        .eq('user_id', id).isFilter('sent_at', null)
        .gte('scheduled_for', now.toUtc().toIso8601String())
        .order('scheduled_for').limit(30),
    ]);
    final items = <Map<String, dynamic>>[];
    for (final row in List<Map<String, dynamic>>.from(res[0] as List)) { items.add({...row, '_kind':'activity'}); }
    for (final row in List<Map<String, dynamic>>.from(res[1] as List)) {
      if (row['due_date'] != null) items.add({...row, '_kind':'task'});
    }
    for (final row in List<Map<String, dynamic>>.from(res[2] as List)) {
      items.add({...row, '_kind':'reminder'});
    }
    items.sort((a,b) {
      final ad = a['_kind'] == 'activity'
        ? DateTime.tryParse(a['starts_at'].toString()) ?? DateTime(2100)
        : a['_kind'] == 'reminder'
          ? DateTime.tryParse(a['scheduled_for'].toString()) ?? DateTime(2100)
          : DateTime.tryParse(a['due_date'].toString() + 'T00:00:00') ?? DateTime(2100);
      final bd = b['_kind'] == 'activity'
        ? DateTime.tryParse(b['starts_at'].toString()) ?? DateTime(2100)
        : b['_kind'] == 'reminder'
          ? DateTime.tryParse(b['scheduled_for'].toString()) ?? DateTime(2100)
          : DateTime.tryParse(b['due_date'].toString() + 'T00:00:00') ?? DateTime(2100);
      return ad.compareTo(bd);
    });
    return items;
  }
  Future<void> enablePush() async {
    if (!kIsWeb) {
      setState(() => pushStatus = 'Aktivasi push Android disiapkan pada tahap konfigurasi APK.');
      return;
    }
    if (db.auth.currentUser == null) {
      setState(() => pushStatus = 'Masuk ke akun terlebih dahulu untuk mengaktifkan notifikasi.');
      return;
    }
    setState(() { enablingPush = true; pushStatus = null; });
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        throw Exception('Izin notifikasi ditolak. Ubah izin situs dari pengaturan browser.');
      }
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: 'BANtcJEtmEhRskDUEO6JoePB0sRHXyTZ6a50o-7RatojSMuGyLgqf4cC4UGupPA9Id-KemF9LURcdG-hCfDOygI',
        serviceWorkerScriptPath: 'firebase-messaging-sw.js',
      );
      if (token == null || token.isEmpty) throw Exception('Token perangkat belum tersedia. Coba muat ulang situs.');
      await db.from('marawis_push_tokens').upsert({
        'user_id': db.auth.currentUser!.id,
        'token': token,
        'platform': 'web',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final user = db.auth.currentUser;
        if (user == null) return;
        await db.from('marawis_push_tokens').upsert({
          'user_id': user.id, 'token': newToken, 'platform': 'web',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'token');
      });
      if (mounted) setState(() => pushStatus = 'Notifikasi berhasil diaktifkan untuk perangkat ini.');
    } catch (error) {
      if (mounted) setState(() => pushStatus = 'Gagal mengaktifkan notifikasi: $error');
    } finally {
      if (mounted) setState(() => enablingPush = false);
    }
  }

  Future<void> sendTestPush() async {
    setState(() { sendingTest = true; pushStatus = null; });
    try {
      final result = await db.functions.invoke('send-marawis-push', body: {
        'title': 'Marawis SMPN 99',
        'body': 'Push notification berhasil terhubung ke perangkat kamu.',
      });
      final data = result.data;
      if (data is Map && (data['sent'] as num? ?? 0) > 0) {
        if (mounted) setState(() => pushStatus = 'Notifikasi uji berhasil dikirim. Periksa notifikasi perangkat.');
      } else {
        if (mounted) setState(() => pushStatus = data is Map ? (data['message']?.toString() ?? 'Belum ada perangkat terdaftar.') : 'Belum ada perangkat terdaftar.');
      }
    } catch (error) {
      if (mounted) setState(() => pushStatus = 'Pengiriman uji gagal: $error');
    } finally {
      if (mounted) setState(() => sendingTest = false);
    }
  }

  String dateLabel(Map<String, dynamic> item) {
    final date = item['_kind'] == 'activity'
      ? DateTime.tryParse(item['starts_at'].toString())?.toLocal()
      : item['_kind'] == 'reminder'
        ? DateTime.tryParse(item['scheduled_for'].toString())?.toLocal()
        : DateTime.tryParse(item['due_date'].toString() + 'T00:00:00');
    if (date == null) return 'Waktu belum tersedia';
    final day = date.day.toString().padLeft(2,'0');
    final month = date.month.toString().padLeft(2,'0');
    final time = item['_kind'] == 'activity' || item['_kind'] == 'reminder'
      ? ' • ' + date.hour.toString().padLeft(2,'0') + ':' + date.minute.toString().padLeft(2,'0')
      : '';
    return day + '/' + month + '/' + date.year.toString() + time;
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 6), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Jadwal kegiatan dan tugas yang perlu kamu perhatikan.', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 9),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: enablingPush ? null : enablePush,
          icon: enablingPush ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.notifications_active_outlined),
          label: Text(enablingPush ? 'Mengaktifkan...' : 'Aktifkan notifikasi')),
        OutlinedButton.icon(onPressed: sendingTest ? null : sendTestPush,
          icon: sendingTest ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
          label: Text(sendingTest ? 'Mengirim...' : 'Kirim tes')),
        IconButton(onPressed: () => setState(() => future = load()), icon: const Icon(Icons.refresh)),
      ]),
      if (pushStatus != null) Padding(padding: const EdgeInsets.only(top: 5),
        child: Text(pushStatus!, style: const TextStyle(fontSize: 12, color: Color(0xFF4268C5)))),
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
            final item = items[i];
            final activity = item['_kind'] == 'activity';
            final reminder = item['_kind'] == 'reminder';
            final location = item['location'];
            final category = reminder ? 'Pengingat otomatis' : activity ? 'Kegiatan' : 'Tugas';
            return Card(child: ListTile(
              leading: CircleAvatar(
                backgroundColor: reminder ? const Color(0xFFEAF0FF) : activity ? const Color(0xFFE8F4EF) : const Color(0xFFFFF1DF),
                child: Icon(reminder ? Icons.notifications_active : activity ? Icons.event_available : Icons.assignment_late_outlined,
                  color: reminder ? const Color(0xFF4268C5) : activity ? const Color(0xFF167D68) : const Color(0xFFB87921)),
              ),
              title: Text(item['title']?.toString() ?? 'Tanpa judul', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(category + ' • ' + dateLabel(item) + (location == null ? '' : '\nLokasi: ' + location.toString())),
              isThreeLine: location != null,
            ));
          },
        );
      },
    )),
    const Padding(
      padding: EdgeInsets.fromLTRB(16,0,16,12),
      child: Text('Pengingat kegiatan dan tenggat dijadwalkan oleh server dan masuk ke kotak Notifikasi aplikasi. Push web menggunakan Firebase Cloud Messaging; izinkan notifikasi pada perangkat untuk mengaktifkannya.', style: TextStyle(fontSize: 11, color: Colors.black54), textAlign: TextAlign.center),
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
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() { super.initState(); future = load(); }

  Future<List<Map<String, dynamic>>> load() async {
    final rows = await db.rpc('get_my_marawis_achievements');
    return List<Map<String, dynamic>>.from(
      (rows as List).map((r) => Map<String, dynamic>.from(r as Map)),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: TextButton(
        onPressed: () => setState(() => future = load()),
        child: const Text('Gagal memuat badge. Coba lagi.'),
      ));
      final unlocked = snapshot.data ?? [];
      const definitions = <String, (String, String, IconData)>{
        'active_member': ('Active Member', 'Hadir dalam satu kegiatan.', Icons.directions_walk),
        'consistent_member': ('Consistent Member', 'Hadir minimal lima kali.', Icons.event_available),
        'knowledge_expert': ('Knowledge Expert', 'Menyelesaikan quiz pertama.', Icons.menu_book),
        'mission_completer': ('Mission Completer', 'Menyelesaikan challenge mingguan.', Icons.flag_rounded),
        'perfect_challenger': ('Perfect Challenger', 'Meraih skor sempurna 100.', Icons.stars_rounded),
        'top_contributor': ('Top Contributor', 'Mendapat penilaian kontribusi.', Icons.volunteer_activism),
      };
      final earned = unlocked.map((e) => e['badge_key'].toString()).toSet();
      return ListView(padding: const EdgeInsets.all(16), children: [
        Card(color: const Color(0xFFE8F4EF), child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ACHIEVEMENT COLLECTION', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF167D68))),
            const SizedBox(height: 6),
            Text('${earned.length} dari ${definitions.length} badge terbuka',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: earned.length / definitions.length),
            const SizedBox(height: 6),
            const Text('Badge tersimpan di akun dan terbuka otomatis saat aktivitas tercatat.'),
          ]),
        )),
        const SizedBox(height: 10),
        for (final entry in definitions.entries)
          Card(child: ListTile(
            leading: CircleAvatar(
              backgroundColor: earned.contains(entry.key) ? const Color(0xFFFFE9B8) : const Color(0xFFF0F2F1),
              child: Icon(entry.value.$3, color: earned.contains(entry.key) ? const Color(0xFFB87921) : const Color(0xFF9AA69F)),
            ),
            title: Text(entry.value.$1, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(entry.value.$2),
            trailing: Icon(
              earned.contains(entry.key) ? Icons.verified_rounded : Icons.lock_outline_rounded,
              color: earned.contains(entry.key) ? const Color(0xFF167D68) : const Color(0xFF9AA69F),
            ),
          )),
        Align(alignment: Alignment.center, child: TextButton.icon(
          onPressed: () => setState(() => future = load()),
          icon: const Icon(Icons.refresh), label: const Text('Perbarui koleksi'),
        )),
      ]);
    },
  );
}

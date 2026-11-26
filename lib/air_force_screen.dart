import 'dart:async';
import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AirForceScreen extends StatefulWidget {
  const AirForceScreen({super.key});
  @override
  State<AirForceScreen> createState() => _AirForceScreenState();
}

class _AirForceScreenState extends State<AirForceScreen> {
  final db = Supabase.instance.client;
  final random = Random();
  Map<String, dynamic>? profile;
  List<String> owned = [];
  bool loading = true, busy = false, playing = false;
  int seconds = 25, score = 0, activeGate = 4, combo = 0, bestCombo = 0;
  String? matchId;
  Timer? timer;

  static const planes = <Map<String, dynamic>>[
    {'id':'f86','name':'F-86 Sabre','tier':1,'level':1,'price':0,'gen':'Gen 1','role':'Starter interceptor'},
    {'id':'mig15','name':'MiG-15','tier':1,'level':1,'price':350,'gen':'Gen 1','role':'Classic jet'},
    {'id':'mig21','name':'MiG-21','tier':2,'level':3,'price':1000,'gen':'Gen 2','role':'Supersonic interceptor'},
    {'id':'f5','name':'F-5 Tiger II','tier':2,'level':3,'price':1200,'gen':'Gen 2','role':'Light fighter'},
    {'id':'f4','name':'F-4 Phantom II','tier':3,'level':5,'price':2600,'gen':'Gen 3','role':'Multirole jet'},
    {'id':'mig23','name':'MiG-23','tier':3,'level':5,'price':3000,'gen':'Gen 3','role':'Variable-sweep jet'},
    {'id':'f16','name':'F-16 Fighting Falcon','tier':4,'level':8,'price':6500,'gen':'Gen 4','role':'Multirole fighter'},
    {'id':'f15','name':'F-15 Eagle','tier':4,'level':8,'price':7200,'gen':'Gen 4','role':'Air-superiority jet'},
    {'id':'su27','name':'Su-27','tier':4,'level':9,'price':7600,'gen':'Gen 4','role':'Air-superiority jet'},
    {'id':'rafale','name':'Dassault Rafale','tier':5,'level':12,'price':14000,'gen':'Gen 4.5','role':'Omnirole fighter'},
    {'id':'typhoon','name':'Eurofighter Typhoon','tier':5,'level':12,'price':15000,'gen':'Gen 4.5','role':'Multirole fighter'},
    {'id':'f22','name':'F-22 Raptor','tier':6,'level':16,'price':28000,'gen':'Gen 5','role':'Stealth fighter'},
    {'id':'f35','name':'F-35 Lightning II','tier':6,'level':16,'price':30000,'gen':'Gen 5','role':'Stealth multirole'},
  ];

  @override
  void initState() { super.initState(); load(); }

  @override
  void dispose() { timer?.cancel(); super.dispose(); }

  int get ap => (profile?['ap'] as num?)?.toInt() ?? 0;
  int get ac => (profile?['ac'] as num?)?.toInt() ?? 0;
  int get xp => (profile?['xp'] as num?)?.toInt() ?? 0;
  int get level => (profile?['level'] as num?)?.toInt() ?? 1;
  int get matches => (profile?['matches'] as num?)?.toInt() ?? 0;
  String get selected => profile?['selected_aircraft']?.toString() ?? 'f86';

  void note(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> load() async {
    try {
      final user = db.auth.currentUser;
      if (user == null) throw Exception('Silakan masuk ke akun Marawis terlebih dahulu.');
      await db.rpc('air_force_initialize');
      final p = await db.from('air_force_profiles').select().eq('user_id', user.id).single();
      final rows = await db.from('air_force_owned_aircraft').select('aircraft_id').eq('user_id', user.id);
      if (!mounted) return;
      setState(() {
        profile = Map<String, dynamic>.from(p);
        owned = rows.map<String>((e) => e['aircraft_id'].toString()).toList();
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => loading = false);
      note('Air Force belum siap: ' + e.toString());
    }
  }

  Future<void> convert() async {
    final ctl = TextEditingController(text: '100');
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konversi AP ke AC'),
        content: TextField(controller: ctl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Jumlah AP (kelipatan 10)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(ctl.text)), child: const Text('Konversi')),
        ],
      ),
    );
    ctl.dispose();
    if (amount == null) return;
    setState(() => busy = true);
    try {
      await db.rpc('air_force_convert_ap', params: {'p_amount': amount});
      await load();
      note('Konversi berhasil: ' + (amount ~/ 10).toString() + ' AC.');
    } catch (e) { note('Konversi gagal: ' + e.toString()); }
    if (mounted) setState(() => busy = false);
  }

  Future<void> buy(Map<String, dynamic> plane) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await db.rpc('air_force_buy_aircraft', params: {'p_aircraft_id': plane['id']});
      await load();
      note(plane['name'].toString() + ' berhasil dibeli!');
    } catch (e) { note('Pembelian gagal: ' + e.toString()); }
    if (mounted) setState(() => busy = false);
  }

  Future<void> selectPlane(String id) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await db.rpc('air_force_select_aircraft', params: {'p_aircraft_id': id});
      await load();
      note('Pesawat aktif berhasil diganti.');
    } catch (e) { note('Gagal memilih pesawat: ' + e.toString()); }
    if (mounted) setState(() => busy = false);
  }

  Future<void> startMatch() async {
    if (playing || busy) return;
    setState(() => busy = true);
    try {
      final result = await db.rpc('air_force_start_match');
      matchId = result.toString();
      if (!mounted) return;
      setState(() {
        busy = false;
        playing = true;
        seconds = 25;
        score = 0;
        combo = 0;
        bestCombo = 0;
        activeGate = random.nextInt(9);
      });
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        if (seconds <= 1) {
          t.cancel();
          setState(() => seconds = 0);
          finishMatch();
        } else {
          setState(() => seconds--);
        }
      });
    } catch (e) {
      if (mounted) setState(() => busy = false);
      note('Tantangan tidak bisa dimulai: ' + e.toString());
    }
  }

  void hitGate(int index) {
    if (!playing || index != activeGate) {
      if (playing) setState(() => combo = 0);
      return;
    }
    setState(() {
      score += 10 + min(combo, 5) * 2;
      combo++;
      if (combo > bestCombo) bestCombo = combo;
      activeGate = random.nextInt(9);
    });
  }

  Future<void> finishMatch() async {
    if (!mounted || !playing || matchId == null) return;
    timer?.cancel();
    final id = matchId!;
    setState(() { playing = false; busy = true; });
    try {
      await db.rpc('air_force_finish_match', params: {'p_match_id': id});
      matchId = null;
      await load();
      note('Sky Run selesai! +75 AP dan +25 XP berhasil disimpan.');
    } catch (e) {
      matchId = null;
      note('Hasil belum tersimpan: ' + e.toString());
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (profile == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off, size: 42),
        const Text('Data Air Force belum dapat dimuat.'),
        FilledButton(onPressed: load, child: const Text('Coba lagi')),
      ]));
    }
    final current = planes.firstWhere((p) => p['id'] == selected, orElse: () => planes.first);
    final xpProgress = (xp % 250) / 250;
    return Container(
      color: const Color(0xFF071522),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _hero(),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _metric('MATCHES', matches.toString(), Icons.sports_score)),
          const SizedBox(width: 8),
          Expanded(child: _metric('XP TO NEXT LEVEL', (250 - xp % 250).toString(), Icons.trending_up)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(
          value: xpProgress, minHeight: 7, backgroundColor: const Color(0xFF20394D),
          color: const Color(0xFF70E3D5),
        )),
        const SizedBox(height: 4),
        Text('LEVEL ' + level.toString() + '  •  ' + xp.toString() + ' XP TOTAL',
          style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: busy || playing ? null : convert,
          icon: const Icon(Icons.currency_exchange),
          label: const Text('Tukar AP menjadi AC  •  10 AP = 1 AC'),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF80E8E0)),
        ),
        _section('FLIGHT CHALLENGE', 'Terbang melewati gerbang energi dalam tantangan arcade 25 detik.'),
        _challenge(),
        _section('ACTIVE AIRCRAFT', 'Pesawat yang sedang kamu gunakan.'),
        _planeCard(current, active: true),
        _section('AIRCRAFT HANGAR', 'Bebas membeli pesawat selama level dan saldo AC mencukupi.'),
        for (final p in planes) _planeCard(p),
        const SizedBox(height: 16),
        const Text('Catatan: Sky Run adalah permainan arcade fiktif. Pesawat dan koleksi menggunakan nama model pesawat nyata, tanpa simulasi penggunaan senjata.',
          style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.4)),
      ]),
    );
  }

  Widget _hero() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFF102D4A), Color(0xFF176A79), Color(0xFF153D5B)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      border: Border.all(color: const Color(0xFF3C8D9A).withValues(alpha: .5)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.flight_takeoff, color: Color(0xFF80E8E0)),
        SizedBox(width: 8),
        Text('MARAWIS AIR FORCE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
      ]),
      const SizedBox(height: 10),
      const Text('YOUR SKY. YOUR SQUADRON.', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
      const Text('Build your aircraft collection. Rise through the ranks.',
        style: TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 18),
      Row(children: [
        _wallet('LEVEL', level.toString()),
        _wallet('AIR POINTS', ap.toString()),
        _wallet('AIR CREDITS', ac.toString()),
      ]),
    ]),
  );

  Widget _wallet(String label, String value) => Expanded(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w800)),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
    ],
  ));

  Widget _metric(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFF12283B), borderRadius: BorderRadius.circular(15)),
    child: Row(children: [
      Icon(icon, color: const Color(0xFF80E8E0), size: 20),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w800)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ])),
    ]),
  );

  Widget _section(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 9),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
      Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    ]),
  );

  Widget _challenge() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF10263A),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF284B64)),
    ),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(playing ? 'TIME 00:' + seconds.toString().padLeft(2, '0') : '25 SECOND SKY RUN',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        Text('SCORE ' + score.toString(), style: const TextStyle(color: Color(0xFF80E8E0), fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 12),
      if (playing) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(colors: [Color(0xFF183F5A), Color(0xFF0C2034)]),
          ),
          child: Column(children: [
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.radar, color: Color(0xFF80E8E0), size: 18),
              SizedBox(width: 6),
              Text('CHECKPOINT RADAR', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ]),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: 9,
              itemBuilder: (context, index) => InkWell(
                onTap: () => hitGate(index),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: activeGate == index ? const Color(0xFF1A8B87) : const Color(0xFF142F45),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: activeGate == index ? const Color(0xFF9AFFF0) : const Color(0xFF29465D), width: activeGate == index ? 2 : 1),
                    boxShadow: activeGate == index ? [const BoxShadow(color: Color(0x5570F5E1), blurRadius: 14)] : [],
                  ),
                  child: Icon(activeGate == index ? Icons.adjust : Icons.circle_outlined,
                    color: activeGate == index ? const Color(0xFFFFD166) : Colors.white24, size: activeGate == index ? 31 : 20),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('COMBO ' + combo.toString(), style: const TextStyle(color: Color(0xFFFFD166), fontWeight: FontWeight.w900)),
          Text('BEST ' + bestCombo.toString(), style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ]),
      ] else ...[
        const Icon(Icons.flight_takeoff, color: Color(0xFF80E8E0), size: 42),
        const SizedBox(height: 6),
        const Text('Tap the glowing checkpoint before it moves.',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        const Text('Setiap match yang tervalidasi memberi 75 AP dan 25 XP.',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 10)),
      ],
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: busy ? null : (playing ? null : startMatch),
        icon: Icon(playing ? Icons.hourglass_top : Icons.play_arrow),
        label: Text(playing ? 'CHALLENGE IN PROGRESS' : (busy ? 'MENYIAPKAN...' : 'MULAI SKY RUN')),
      )),
    ]),
  );

  Widget _planeCard(Map<String, dynamic> plane, {bool active = false}) {
    final isOwned = owned.contains(plane['id']);
    final requiredLevel = plane['level'] as int;
    final price = plane['price'] as int;
    final canBuy = level >= requiredLevel && ac >= price;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF174A55) : const Color(0xFF12283B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? const Color(0xFF80E8E0) : const Color(0xFF29465D)),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: const Color(0xFF203D55), borderRadius: BorderRadius.circular(13)),
          child: const Icon(Icons.flight, color: Color(0xFF80E8E0), size: 28),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(plane['name'].toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          Text('TIER ' + plane['tier'].toString() + '  •  ' + plane['gen'].toString(),
            style: const TextStyle(color: Color(0xFF80E8E0), fontSize: 10, fontWeight: FontWeight.w800)),
          Text(plane['role'].toString() + '  •  Lv.' + requiredLevel.toString() + '  •  ' + price.toString() + ' AC',
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ])),
        if (active) const Icon(Icons.check_circle, color: Color(0xFF80E8E0))
        else if (isOwned) TextButton(
          onPressed: busy ? null : () => selectPlane(plane['id'].toString()),
          child: const Text('PILIH'),
        )
        else FilledButton(
          onPressed: busy || !canBuy ? null : () => buy(plane),
          child: const Text('BELI'),
        ),
      ]),
    );
  }
}

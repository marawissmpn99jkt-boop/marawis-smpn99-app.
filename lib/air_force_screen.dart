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
  List<Map<String,dynamic>> raceRooms = [], racePlayers = [];
  Map<String,dynamic>? activeRoom;
  RealtimeChannel? raceChannel;

  static const planes = <Map<String, dynamic>>[
    {'id':'f86','name':'F-86 Sabre','tier':1,'level':1,'price':0,'gen':'Gen 1','role':'Early-generation jet fighter'},
    {'id':'mig15','name':'MiG-15','tier':1,'level':1,'price':350,'gen':'Gen 1','role':'Early-generation jet fighter'},
    {'id':'mig21','name':'MiG-21','tier':2,'level':3,'price':1000,'gen':'Gen 2','role':'Supersonic fighter'},
    {'id':'f5','name':'F-5 Tiger II','tier':2,'level':3,'price':1200,'gen':'Gen 2','role':'Lightweight fighter'},
    {'id':'f4','name':'F-4 Phantom II','tier':3,'level':5,'price':2600,'gen':'Gen 3','role':'Twin-engine multirole fighter'},
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
  void initState() { super.initState(); load(); loadRaceRooms(); }

  @override
  void dispose() { timer?.cancel(); raceChannel?.unsubscribe(); super.dispose(); }

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

  Future<void> loadRaceRooms() async {
    try {
      final rows = await db.from('multiplayer_rooms').select('id,room_code,host_id,status,max_players,created_at')
        .eq('game_type','air_force_race').eq('status','waiting').order('created_at',ascending:false).limit(12);
      if (mounted) setState(() => raceRooms = List<Map<String,dynamic>>.from(rows));
    } catch (_) {}
  }

  Future<String> _displayName() async {
    final uid = db.auth.currentUser!.id;
    final p = await db.from('profiles').select('full_name').eq('id',uid).maybeSingle();
    return (p?['full_name'] ?? db.auth.currentUser?.email?.split('@').first ?? 'Pilot').toString();
  }

  Future<void> createRaceRoom() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await db.rpc('air_force_create_room');
      final row = (result as List).first as Map;
      final id = row['room_id'].toString();
      await db.from('multiplayer_players').insert({
        'room_id': id, 'user_id': db.auth.currentUser!.id, 'display_name': await _displayName()
      });
      await openRaceRoom({'id':id,'room_code':row['room_code'],'host_id':db.auth.currentUser!.id,'status':'waiting','max_players':8});
      await loadRaceRooms();
    } catch (e) { note('Gagal membuat room: $e'); }
    if (mounted) setState(() => busy = false);
  }

  Future<void> joinRaceRoom(Map<String,dynamic> room) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final uid = db.auth.currentUser!.id;
      final existing = await db.from('multiplayer_players').select('id').eq('room_id',room['id']).eq('user_id',uid).maybeSingle();
      if (existing == null) {
        await db.from('multiplayer_players').insert({
          'room_id':room['id'], 'user_id':uid, 'display_name':await _displayName()
        });
      }
      await openRaceRoom(room);
    } catch (e) { note('Tidak bisa bergabung: $e'); }
    if (mounted) setState(() => busy = false);
  }

  Future<void> openRaceRoom(Map<String,dynamic> room) async {
    raceChannel?.unsubscribe();
    if (!mounted) return;
    setState(() => activeRoom = Map<String,dynamic>.from(room));
    await refreshRacePlayers();
    raceChannel = db.channel('air-force-room-${room['id']}')
      ..onPostgresChanges(event:PostgresChangeEvent.all,schema:'public',table:'multiplayer_players',
        filter:PostgresChangeFilter(type:PostgresChangeFilterType.eq,column:'room_id',value:room['id'].toString()),
        callback:(_) => refreshRacePlayers())
      ..onPostgresChanges(event:PostgresChangeEvent.all,schema:'public',table:'multiplayer_rooms',
        filter:PostgresChangeFilter(type:PostgresChangeFilterType.eq,column:'id',value:room['id'].toString()),
        callback:(_) => refreshActiveRoom())
      ..subscribe();
  }

  Future<void> refreshRacePlayers() async {
    final room = activeRoom;
    if (room == null) return;
    try {
      final rows = await db.from('multiplayer_players').select('user_id,display_name,score,joined_at')
        .eq('room_id',room['id']).order('score',ascending:false).order('joined_at');
      if (mounted) setState(() => racePlayers = List<Map<String,dynamic>>.from(rows));
    } catch (_) {}
  }

  Future<void> refreshActiveRoom() async {
    final room = activeRoom;
    if (room == null) return;
    try {
      final row = await db.from('multiplayer_rooms').select('id,room_code,host_id,status,max_players')
        .eq('id',room['id']).single();
      if (mounted) setState(() => activeRoom = Map<String,dynamic>.from(row));
    } catch (_) {}
  }

  Future<void> startRaceRoom() async {
    final room = activeRoom;
    if (room == null || busy) return;
    setState(() => busy = true);
    try {
      await db.from('multiplayer_players').update({'score':0}).eq('room_id',room['id']);
      await db.rpc('air_force_start_room',params:{'p_room_id':room['id']});
      await refreshActiveRoom();
      note('Room dimulai! Mode checkpoint race siap.');
    } catch (e) { note('Gagal memulai room: $e'); }
    if (mounted) setState(() => busy = false);
  }

  Future<void> leaveRaceRoom() async {
    final room = activeRoom;
    if (room == null) return;
    try {
      await db.from('multiplayer_players').delete().eq('room_id',room['id']).eq('user_id',db.auth.currentUser!.id);
    } catch (_) {}
    raceChannel?.unsubscribe();
    if (mounted) setState(() { activeRoom = null; racePlayers = []; });
    await loadRaceRooms();
  }

  Widget _raceLobby() {
    final room = activeRoom;
    final uid = db.auth.currentUser?.id;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF10263A),borderRadius: BorderRadius.circular(20),border: Border.all(color: const Color(0xFF31536A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[
        Row(children:[
          const Icon(Icons.groups,color:Color(0xFF80E8E0)),
          const SizedBox(width:8),
          const Expanded(child:Text('MULTIPLAYER CHECKPOINT RACE',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,letterSpacing:.6))),
          IconButton(onPressed:loadRaceRooms,icon:const Icon(Icons.refresh,color:Colors.white70)),
        ]),
        const Text('Buat room atau gabung pilot lain. Maksimal 8 pemain per room.',style:TextStyle(color:Colors.white60,fontSize:11)),
        const SizedBox(height:10),
        if (room != null) ...[
          Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFF173D50),borderRadius:BorderRadius.circular(14)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('ROOM CODE  ${room['room_code']}',style:const TextStyle(color:Color(0xFF80E8E0),fontWeight:FontWeight.w900,fontSize:18,letterSpacing:2)),
            Text('Status: ${room['status']} • ${racePlayers.length}/8 pilot',style:const TextStyle(color:Colors.white70,fontSize:11)),
            const Divider(color:Colors.white24),
            for(final p in racePlayers) Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Row(children:[
              const Icon(Icons.flight,color:Color(0xFF80E8E0),size:16),const SizedBox(width:7),
              Expanded(child:Text(p['display_name'].toString(),style:const TextStyle(color:Colors.white))),
              if(p['user_id']==room['host_id'])const Text('HOST',style:TextStyle(color:Color(0xFFFFD166),fontSize:9,fontWeight:FontWeight.w900)),
              if(p['user_id']==uid)const Text(' YOU',style:TextStyle(color:Color(0xFF80E8E0),fontSize:9,fontWeight:FontWeight.w900)),
            ])),
            const SizedBox(height:8),
            if(room['host_id']==uid && room['status']=='waiting')
              SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:busy?null:startRaceRoom,icon:const Icon(Icons.flag),label:const Text('MULAI ROOM'))),
            if(room['status']=='playing') ...[
              const Text('RACE LIVE • Mainkan Sky Run di bawah. Skor checkpoint tersinkron ke semua pilot.',style:TextStyle(color:Color(0xFF80E8E0),fontSize:11)),
              const SizedBox(height:8),
              for(var i=0;i<racePlayers.length;i++)
                Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Row(children:[
                  Text('#${i+1}',style:const TextStyle(color:Color(0xFFFFD166),fontWeight:FontWeight.w900)),
                  const SizedBox(width:8),
                  Expanded(child:Text(racePlayers[i]['display_name'].toString(),style:const TextStyle(color:Colors.white))),
                  Text('${racePlayers[i]['score']} PTS',style:const TextStyle(color:Color(0xFF80E8E0),fontWeight:FontWeight.w900)),
                ])),
            ],
            TextButton(onPressed:leaveRaceRoom,child:const Text('Keluar dari room')),
          ])),
        ] else ...[
          SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:busy?null:createRaceRoom,icon:const Icon(Icons.add),label:const Text('BUAT ROOM RACE'))),
          const SizedBox(height:8),
          if(raceRooms.isEmpty)const Text('Belum ada room terbuka. Buat room pertama!',style:TextStyle(color:Colors.white54,fontSize:11))
          else for(final r in raceRooms)Container(margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),decoration:BoxDecoration(color:const Color(0xFF142F45),borderRadius:BorderRadius.circular(12)),child:Row(children:[
            const Icon(Icons.flight_takeoff,color:Color(0xFF80E8E0)),
            const SizedBox(width:8),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('ROOM ${r['room_code']}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),
              Text('Maks. ${r['max_players']} pilot',style:const TextStyle(color:Colors.white54,fontSize:10)),
            ])),
            TextButton(onPressed:busy?null:()=>joinRaceRoom(r),child:const Text('GABUNG')),
          ])),
        ],
      ]),
    );
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
    if (activeRoom != null && activeRoom!['status'] != 'playing') {
      note('Tunggu host memulai room terlebih dahulu.');
      return;
    }
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

  Future<void> syncRaceScore(int value) async {
    final room = activeRoom;
    final uid = db.auth.currentUser?.id;
    if (room == null || uid == null || room['status'] != 'playing') return;
    try {
      await db.from('multiplayer_players').update({'score': value})
        .eq('room_id', room['id']).eq('user_id', uid);
    } catch (_) {}
  }

  void hitGate(int index) {
    if (!playing) return;
    if (index != activeGate) {
      setState(() => combo = 0);
      return;
    }
    setState(() {
      score += 100 + min(combo, 5) * 20;
      combo++;
      if (combo > bestCombo) bestCombo = combo;
      activeGate = random.nextInt(9);
    });
    syncRaceScore(score);
  }

  Future<void> finishMatch() async {
    if (!mounted || !playing || matchId == null) return;
    timer?.cancel();
    final id = matchId!;
    setState(() { playing = false; busy = true; });
    try {
      await db.rpc('air_force_finish_match', params: {'p_match_id': id});
      matchId = null;
      await syncRaceScore(score);
      await refreshRacePlayers();
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
        _section('SQUADRON NETWORK', 'Terhubung dengan pilot lain melalui room multiplayer.'),
        _raceLobby(),
        _section('SKY ROUTE CHALLENGE', 'Terbang melewati checkpoint bercahaya dan kumpulkan poin dengan ketepatan.'),
        _challenge(),
        _section('AIRCRAFT SHOWCASE', 'Jelajahi koleksi pesawat bersejarah dari berbagai generasi.'),
        _aircraftShowcase(current),
        _section('ACTIVE AIRCRAFT', 'Pesawat yang sedang kamu gunakan.'),
        _planeCard(current, active: true),
        _section('AIRCRAFT COLLECTION', 'Buka koleksi pesawat berdasarkan level dan saldo AC.'),
        for (final p in planes) _planeCard(p),
        const SizedBox(height: 16),
        const Text('Mode Sky Route adalah tantangan checkpoint non-tempur. Koleksi pesawat ditampilkan untuk edukasi dan apresiasi aviasi.',
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
        Text(playing ? 'SKY ROUTE • 00:' + seconds.toString().padLeft(2, '0') : 'SKY ROUTE • 25 SEC',
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
              Text('FLIGHT PATH RADAR', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ]),
            const SizedBox(height: 10),
            const Text('Tap the glowing checkpoint. Misses reset your combo.',style:TextStyle(color:Colors.white60,fontSize:10)),
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
        const Text('Ikuti checkpoint yang menyala untuk menjaga jalur penerbangan dan mengumpulkan skor.',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        const Text('Selesaikan rute penerbangan untuk memperoleh 75 AP dan 25 XP.',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 10)),
      ],
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: busy ? null : (playing ? null : startMatch),
        icon: Icon(playing ? Icons.hourglass_top : Icons.play_arrow),
        label: Text(playing ? 'FLIGHT IN PROGRESS' : (busy ? 'MENYIAPKAN...' : 'MULAI SKY ROUTE')),
      )),
    ]),
  );


  Widget _aircraftShowcase(Map<String, dynamic> plane) {
    final tier = plane['tier'] as int;
    final accent = tier >= 5 ? const Color(0xFFFFD166) : const Color(0xFF80E8E0);
    return Container(
      height: 238,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF173B55), Color(0xFF081725), Color(0xFF102A40)],
        ),
        border: Border.all(color: accent.withValues(alpha: .55)),
      ),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _HangarPainter(accent))),
        Positioned(left: 15, top: 13, child: Text(
          'HANGAR 01  •  TIER $tier',
          style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.1),
        )),
        Positioned.fill(
          top: 22, bottom: 44,
          child: CustomPaint(painter: _AircraftPainter(accent, plane['id'].toString().hashCode)),
        ),
        Positioned(left: 15, right: 15, bottom: 12, child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(plane['name'].toString(), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
            Text('${plane['gen']}  •  ${plane['role']}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ])),
          Icon(Icons.verified, color: accent, size: 19),
        ])),
      ]),
    );
  }

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


class _HangarPainter extends CustomPainter {
  final Color accent;
  const _HangarPainter(this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()..shader = RadialGradient(colors: [
      accent.withValues(alpha: .24), accent.withValues(alpha: .02), Colors.transparent,
    ]).createShader(Rect.fromCircle(center: Offset(size.width / 2, size.height * .52), radius: size.width * .48));
    canvas.drawRect(Offset.zero & size, glow);
    final grid = Paint()..color = accent.withValues(alpha: .15)..strokeWidth = 1;
    final horizon = size.height * .72;
    canvas.drawLine(Offset(0, horizon), Offset(size.width, horizon), grid);
    for (var i = -4; i <= 4; i++) {
      canvas.drawLine(Offset(size.width / 2 + i * 15, horizon), Offset(size.width / 2 + i * 58, size.height), grid);
    }
    for (var i = 1; i <= 4; i++) {
      final y = horizon + i * i * 5.0;
      canvas.drawLine(Offset(size.width * .12, y), Offset(size.width * .88, y), grid);
    }
  }
  @override
  bool shouldRepaint(covariant _HangarPainter old) => old.accent != accent;
}

class _AircraftPainter extends CustomPainter {
  final Color accent;
  final int variant;
  const _AircraftPainter(this.accent, this.variant);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height * .52);
    canvas.rotate((variant % 7 - 3) * .018);
    final silhouette = Path()
      ..moveTo(0, -82)..lineTo(12, -45)..lineTo(91, -8)
      ..lineTo(100, 5)..lineTo(20, -1)..lineTo(14, 43)
      ..lineTo(38, 66)..lineTo(38, 74)..lineTo(0, 65)
      ..lineTo(-38, 74)..lineTo(-38, 66)..lineTo(-14, 43)
      ..lineTo(-20, -1)..lineTo(-100, 5)..lineTo(-91, -8)
      ..lineTo(-12, -45)..close();
    canvas.drawPath(silhouette.shift(const Offset(0, 8)), Paint()
      ..color = Colors.black.withValues(alpha: .48)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawPath(silhouette, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [Color(0xFF526F82), Color(0xFFEAF5F8), Color(0xFF607F91)],
      ).createShader(const Rect.fromLTWH(-105, -90, 210, 170)));
    final cockpit = Path()
      ..moveTo(0, -69)..cubicTo(9, -59, 8, -43, 0, -34)
      ..cubicTo(-8, -43, -9, -59, 0, -69)..close();
    canvas.drawPath(cockpit, Paint()..color = const Color(0xFF153B56));
    canvas.drawPath(cockpit, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = accent);
    final stripe = Paint()..color = accent.withValues(alpha: .9)..strokeWidth = 2;
    canvas.drawLine(const Offset(-68, -5), const Offset(-29, 0), stripe);
    canvas.drawLine(const Offset(68, -5), const Offset(29, 0), stripe);
    canvas.drawCircle(const Offset(0, -3), 3, Paint()..color = accent);
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _AircraftPainter old) => old.accent != accent || old.variant != variant;
}

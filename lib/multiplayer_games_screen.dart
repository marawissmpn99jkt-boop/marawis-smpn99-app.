import 'dart:async';
import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MultiplayerGamesScreen extends StatefulWidget {
  const MultiplayerGamesScreen({super.key, required this.role, required this.soloGame});
  final String role;
  final Widget soloGame;
  @override State<MultiplayerGamesScreen> createState()=>_MultiplayerGamesScreenState();
}
class _MultiplayerGamesScreenState extends State<MultiplayerGamesScreen>{
  final db=Supabase.instance.client;
  bool get staff=>widget.role=='pengurus'||widget.role=='pembina';
  String? roomId,secretWord;
  Map<String,dynamic>? room;
  List<Map<String,dynamic>> rooms=[],players=[],events=[];
  RealtimeChannel? channel;
  bool busy=false;
  final guess=TextEditingController();
  final questions=const [
    {'q':'Apa fungsi utama hajir dalam permainan marawis?','a':['Menjaga ketukan dasar','Mengatur kostum','Membuka acara','Mengatur mikrofon'],'c':0},
    {'q':'Sikap penting saat bermain bersama?','a':['Bermain sendiri','Saling mendengarkan','Mendahului semua','Mengabaikan aba-aba'],'c':1},
    {'q':'Sebelum tampil, kelompok sebaiknya...','a':['Tidak latihan','Menyamakan tempo','Mengubah lagu','Datang terlambat'],'c':1},
    {'q':'Darbuka dimainkan dengan cara...','a':['Dipukul tangan','Ditiup','Digesek','Dipetik'],'c':0},
    {'q':'Jika tempo tidak sama, pemain harus...','a':['Tetap sendiri','Mendengarkan pemimpin tempo','Mempercepat sendiri','Berhenti mendadak'],'c':1},
  ];
  final words=['REBANA','MARAWIS','KOMPAK','HAJIR','DARBUKA','LATIHAN','PANGGUNG','IRAMA'];
  List<List<Offset>> localStrokes=[];
  List<Offset> activeStroke=[];
  @override void initState(){super.initState();loadRooms();}
  @override void dispose(){channel?.unsubscribe();guess.dispose();super.dispose();}
  void msg(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
  Future<String> displayName()async{
    final id=db.auth.currentUser!.id;
    final p=await db.from('profiles').select('full_name').eq('id',id).maybeSingle();
    return (p?['full_name']??db.auth.currentUser?.email?.split('@').first??'Pemain').toString();
  }
  Future<void> loadRooms()async{
    try{final x=await db.from('multiplayer_rooms').select('id,room_code,game_type,host_id,status,max_players').eq('status','waiting').order('created_at',ascending:false);if(mounted)setState(()=>rooms=List<Map<String,dynamic>>.from(x));}
    catch(e){msg('Room gagal dimuat: '+e.toString());}
  }
  Future<void> createRoom(String game)async{
    if(!staff)return;
    try{
      final code=List.generate(6,(_)=>Random.secure().nextInt(10)).join();
      final x=await db.from('multiplayer_rooms').insert({'room_code':code,'game_type':game,'host_id':db.auth.currentUser!.id,'max_players':10,'game_state':{}}).select().single();
      await enter(Map<String,dynamic>.from(x));
    }catch(e){msg('Gagal membuat room: '+e.toString());}
  }
  Future<void> joinCode()async{
    final c=TextEditingController();
    final value=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Masukkan kode room'),content:TextField(controller:c,maxLength:6,keyboardType:TextInputType.number,decoration:const InputDecoration(hintText:'6 digit kode')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Batal')),FilledButton(onPressed:()=>Navigator.pop(ctx,c.text.trim()),child:const Text('Gabung'))]));
    c.dispose();if(value==null||value.length!=6)return;
    try{final x=await db.from('multiplayer_rooms').select().eq('room_code',value).eq('status','waiting').maybeSingle();if(x==null){msg('Room tidak ditemukan atau sudah dimulai.');return;}await enter(Map<String,dynamic>.from(x));}
    catch(e){msg('Tidak bisa bergabung: '+e.toString());}
  }
  Future<void> enter(Map<String,dynamic> r)async{
    try{
      final uid=db.auth.currentUser!.id;
      final old=await db.from('multiplayer_players').select('id').eq('room_id',r['id']).eq('user_id',uid).maybeSingle();
      if(old==null)await db.from('multiplayer_players').insert({'room_id':r['id'],'user_id':uid,'display_name':await displayName()});
      if(!mounted)return;setState(()=>roomId=r['id'].toString());await refreshRoom();subscribeRoom();
    }catch(e){msg('Gagal masuk room: '+e.toString());}
  }
  void subscribeRoom(){
    channel?.unsubscribe();final id=roomId;if(id==null)return;
    channel=db.channel('marawis-mp-'+id)
      ..onPostgresChanges(event:PostgresChangeEvent.all,schema:'public',table:'multiplayer_rooms',filter:PostgresChangeFilter(type:PostgresChangeFilterType.eq,column:'id',value:id),callback:(_)=>refreshRoom())
      ..onPostgresChanges(event:PostgresChangeEvent.all,schema:'public',table:'multiplayer_players',filter:PostgresChangeFilter(type:PostgresChangeFilterType.eq,column:'room_id',value:id),callback:(_)=>refreshRoom())
      ..onPostgresChanges(event:PostgresChangeEvent.all,schema:'public',table:'multiplayer_events',filter:PostgresChangeFilter(type:PostgresChangeFilterType.eq,column:'room_id',value:id),callback:(_)=>refreshRoom())
      ..subscribe();
  }
  Future<void> refreshRoom()async{
    final id=roomId;if(id==null)return;
    try{
      final x=await Future.wait([db.from('multiplayer_rooms').select().eq('id',id).single(),db.from('multiplayer_players').select().eq('room_id',id).order('joined_at'),db.from('multiplayer_events').select().eq('room_id',id).order('created_at')]);
      if(!mounted)return;setState(()=>{room=Map<String,dynamic>.from(x[0] as Map),players=List<Map<String,dynamic>>.from(x[1] as List),events=List<Map<String,dynamic>>.from(x[2] as List)});
    }catch(e){msg('Sinkronisasi gagal: '+e.toString());}
  }
  bool get host=>room?['host_id']==db.auth.currentUser?.id;
  Map<String,dynamic> get state=>Map<String,dynamic>.from(room?['game_state']??{});
  Future<void> emit(String type,Map<String,dynamic> payload)async{
    try{await db.from('multiplayer_events').insert({'room_id':roomId,'actor_id':db.auth.currentUser!.id,'event_type':type,'payload':payload});}
    catch(e){msg('Aksi gagal: '+e.toString());}
  }
  Future<void> updateState(Map<String,dynamic> s,{String? status})async{
    if(!host)return;final p=<String,dynamic>{'game_state':s};if(status!=null)p['status']=status;
    try{await db.from('multiplayer_rooms').update(p).eq('id',roomId!);await refreshRoom();}catch(e){msg('Update game gagal: '+e.toString());}
  }
  Future<void> start()async{
    if(!host)return;final type=room!['game_type'];
    final s=<String,dynamic>{'round':0,'phase':type=='quiz_arena'?'quiz':type=='who_leader'?'vote':'draw'};
    if(type=='draw_guess'){secretWord=words[Random.secure().nextInt(words.length)];s['drawer_id']=db.auth.currentUser!.id;}
    await updateState(s,status:'playing');
  }
  Future<void> leave()async{
    final id=roomId;if(id==null)return;
    try{if(host)await db.from('multiplayer_rooms').update({'status':'finished','game_state':{...state,'phase':'finished'}}).eq('id',id);await db.from('multiplayer_players').delete().eq('room_id',id).eq('user_id',db.auth.currentUser!.id);}catch(_){}
    await channel?.unsubscribe();if(mounted)setState(()=>{roomId=null,room=null,players=[],events=[],secretWord=null});loadRooms();
  }
  Future<void> finish()async=>updateState({...state,'phase':'finished'},status:'finished');
  String title(String key)=>key=='quiz_arena'?'Marawis Quiz Arena':key=='who_leader'?'Who Is The Leader?':'Draw & Guess';
  Map<String,dynamic> player(String id)=>players.firstWhere((p)=>p['user_id']==id,orElse:()=>{});
  String playerName(String id)=>(player(id)['display_name']??'Pemain').toString();
  int score(String id)=>events.where((e)=>(e['event_type']=='answer'&&e['actor_id']==id&&e['payload']['correct']==true)||(e['event_type']=='guess'&&e['payload']['accepted']==true&&e['payload']['target']==id)).length*10;
  Widget cardGame(String key,String name,String detail,IconData icon){
    return Card(color:Colors.white,child:ListTile(leading:CircleAvatar(backgroundColor:const Color(0xFFE7F4EE),child:Icon(icon,color:const Color(0xFF167D68))),title:Text(name,style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text(detail),trailing:staff?IconButton.filledTonal(onPressed:()=>createRoom(key),icon:const Icon(Icons.add),tooltip:'Buat room'):null));
  }
  @override Widget build(BuildContext context){
    if(roomId!=null)return roomPage();
    return Scaffold(body:RefreshIndicator(onRefresh:loadRooms,child:ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF123F35),Color(0xFF229B7C)]),borderRadius:BorderRadius.circular(22)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('MARAWIS MULTIPLAYER ARENA',style:TextStyle(color:Colors.white70,fontWeight:FontWeight.w900,fontSize:10,letterSpacing:1.2)),const SizedBox(height:10),const Text('Main bareng,\nmenang bareng.',style:TextStyle(color:Colors.white,fontSize:26,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text(staff?'Buat room dan bagikan kode kepada anggota.':'Gabung ke room yang dibuat Pengurus/Pembina.',style:const TextStyle(color:Colors.white70)),if(!staff)Padding(padding:const EdgeInsets.only(top:12),child:FilledButton.icon(onPressed:joinCode,icon:const Icon(Icons.login),label:const Text('Gabung dengan kode'),style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:const Color(0xFF145B49)))),
      ])),
      const SizedBox(height:18),const Text('Pilih permainan',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
      cardGame('quiz_arena','Marawis Quiz Arena','Jawab pertanyaan secara serentak.',Icons.quiz),
      cardGame('who_leader','Who Is The Leader?','Voting pemimpin tim secara real-time.',Icons.groups),
      cardGame('draw_guess','Draw & Guess','Host menggambar, anggota menebak.',Icons.brush),
      const SizedBox(height:18),Row(children:[const Expanded(child:Text('Room tersedia',style:TextStyle(fontWeight:FontWeight.w900,fontSize:17))),IconButton(onPressed:loadRooms,icon:const Icon(Icons.refresh))]),
      if(rooms.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('Belum ada room yang menunggu pemain.',textAlign:TextAlign.center)) else for(final r in rooms)Card(color:Colors.white,child:ListTile(title:Text(title(r['game_type'].toString())),subtitle:Text('Kode '+r['room_code'].toString()+' • Maks. '+r['max_players'].toString()+' pemain'),trailing:FilledButton(onPressed:()=>enter(r),child:const Text('Gabung')))),
      const SizedBox(height:12),OutlinedButton.icon(onPressed:()=>showModalBottomSheet(context:context,isScrollControlled:true,builder:(_)=>SizedBox(height:500,child:widget.soloGame)),icon:const Icon(Icons.person),label:const Text('Mainkan tantangan solo')),
    ])));
  }
  Widget roomPage(){
    final r=room;if(r==null)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    final status=r['status'].toString();
    return Scaffold(appBar:AppBar(title:Text('Room '+r['room_code'].toString()),leading:IconButton(onPressed:leave,icon:const Icon(Icons.arrow_back)),actions:[IconButton(onPressed:refreshRoom,icon:const Icon(Icons.refresh))]),body:ListView(padding:const EdgeInsets.all(16),children:[
      Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title(r['game_type'].toString()),style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),Text('Kode: '+r['room_code'].toString(),style:const TextStyle(fontSize:22,color:Color(0xFF167D68),fontWeight:FontWeight.w900,letterSpacing:2)),Text(players.length.toString()+'/'+r['max_players'].toString()+' pemain • '+(status=='waiting'?'Menunggu':status=='playing'?'Berlangsung':'Selesai')),
        for(final p in players)ListTile(dense:true,leading:CircleAvatar(child:Text(p['display_name'].toString().isEmpty?'?':p['display_name'].toString()[0].toUpperCase())),title:Text(p['display_name'].toString()),trailing:p['user_id']==r['host_id']?const Chip(label:Text('HOST')):null),
        if(status=='waiting'&&host)SizedBox(width:double.infinity,child:FilledButton(onPressed:players.length<2?null:start,child:const Text('Mulai permainan • min. 2 pemain'))),
        if(status=='waiting'&&!host)const Text('Menunggu host memulai permainan...'),
      ]))),
      if(status=='playing')gamePanel(),
      if(status=='finished')results(),
    ]));
  }
  Widget gamePanel(){
    final key=room!['game_type'].toString();
    if(key=='quiz_arena')return quizPanel();
    if(key=='who_leader')return leaderPanel();
    return drawPanel();
  }
  Widget quizPanel(){
    final i=(state['round'] as num?)?.toInt()??0;if(i>=questions.length)return results();
    final q=questions[i];final uid=db.auth.currentUser!.id;
    final mine=events.any((e)=>e['actor_id']==uid&&e['event_type']=='answer'&&e['payload']['round']==i);
    final count=events.where((e)=>e['event_type']=='answer'&&e['payload']['round']==i).length;
    return Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('SOAL '+(i+1).toString()+'/'+questions.length.toString(),style:const TextStyle(color:Color(0xFF167D68),fontWeight:FontWeight.w900)),const SizedBox(height:10),Text(q['q'].toString(),style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
      if(!mine)for(var n=0;n<4;n++)SizedBox(width:double.infinity,child:Padding(padding:const EdgeInsets.only(top:7),child:OutlinedButton(onPressed:()=>emit('answer',{'round':i,'choice':n,'correct':n==q['c']}),child:Text((q['a'] as List)[n].toString())))) else const Padding(padding:EdgeInsets.all(12),child:Text('Jawaban terkirim! Menunggu pemain lain.')),
      Text(count.toString()+'/'+players.length.toString()+' pemain menjawab'),
      if(host)FilledButton(onPressed:()=>i+1<questions.length?updateState({...state,'round':i+1}):finish(),child:Text(i+1<questions.length?'Soal berikutnya':'Akhiri Quiz')),
      scoreboard(),
    ])));
  }
  Widget leaderPanel(){
    final votes=events.where((e)=>e['event_type']=='vote').toList();final uid=db.auth.currentUser!.id;final mine=votes.any((e)=>e['actor_id']==uid);
    final tally=<String,int>{};for(final e in votes){final t=e['payload']['target']?.toString();if(t!=null)tally[t]=(tally[t]??0)+1;}
    final sorted=tally.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    return Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('WHO IS THE LEADER?',style:TextStyle(fontWeight:FontWeight.w900,color:Color(0xFF4268C5))),const SizedBox(height:8),const Text('Pilih pemain yang menurutmu paling cocok memimpin tim. Setiap orang hanya punya satu suara.'),
      if(!mine)...[for(final p in players)if(p['user_id']!=uid)ListTile(title:Text(p['display_name'].toString()),trailing:IconButton(icon:const Icon(Icons.how_to_vote),onPressed:()=>emit('vote',{'target':p['user_id']}))) ] else const Text('Suaramu sudah masuk.'),
      Text(votes.length.toString()+'/'+players.length.toString()+' suara masuk'),const Divider(),for(final v in sorted)Text(playerName(v.key)+' — '+v.value.toString()+' suara'),
      if(host)FilledButton(onPressed:finish,child:const Text('Tutup voting & tampilkan hasil')),
    ])));
  }
  Widget drawPanel(){
    final uid=db.auth.currentUser!.id;final drawer=state['drawer_id']?.toString();final canDraw=uid==drawer;
    final drawEvents=events.where((e)=>e['event_type']=='draw').toList();final guesses=events.where((e)=>e['event_type']=='guess'&&e['payload']['accepted']!=true).toList();
    return Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('DRAW & GUESS',style:TextStyle(fontWeight:FontWeight.w900,color:Color(0xFFC47A25))),const SizedBox(height:5),Text(canDraw?'Kata rahasia: '+(secretWord??'MARAWIS')+' — gambarkan!':'Lihat gambar dan kirim tebakanmu.'),
      const SizedBox(height:10),
      GestureDetector(onPanStart:canDraw?(d)=>setState(()=>activeStroke=[d.localPosition]):null,onPanUpdate:canDraw?(d)=>setState(()=>activeStroke.add(d.localPosition)):null,onPanEnd:canDraw?(d)async{final pts=activeStroke.map((p)=>{'x':p.dx,'y':p.dy}).toList();setState(()=>activeStroke=[]);if(pts.length>1)await emit('draw',{'points':pts});}:null,child:Container(height:250,width:double.infinity,decoration:BoxDecoration(color:const Color(0xFFFAFCFB),border:Border.all(color:const Color(0xFFDDE7E1)),borderRadius:BorderRadius.circular(12)),child:CustomPaint(painter:_GamePainter(drawEvents,activeStroke)))),
      if(!canDraw)Row(children:[Expanded(child:TextField(controller:guess,decoration:const InputDecoration(hintText:'Tulis tebakan'))),const SizedBox(width:8),FilledButton(onPressed:()async{final v=guess.text.trim();if(v.isNotEmpty){await emit('guess',{'text':v});guess.clear();}},child:const Text('Kirim'))]),
      if(canDraw)const Text('Kamu menggambar. Host dapat menandai tebakan yang benar.',style:TextStyle(fontSize:12,color:Colors.black54)),
      const SizedBox(height:10),const Text('Tebakan',style:TextStyle(fontWeight:FontWeight.w800)),
      for(final g in guesses)ListTile(dense:true,title:Text(playerName(g['actor_id'].toString())+': '+(g['payload']['text']??'').toString()),trailing:canDraw?IconButton(icon:const Icon(Icons.check_circle,color:Colors.green),onPressed:()=>emit('guess',{'accepted':true,'target':g['actor_id']})):null),
      if(host)FilledButton(onPressed:finish,child:const Text('Akhiri permainan')),
    ])));
  }
  Widget scoreboard(){
    final sorted=players.toList()..sort((a,b)=>score(b['user_id'].toString()).compareTo(score(a['user_id'].toString())));
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const SizedBox(height:12),const Text('Papan skor',style:TextStyle(fontWeight:FontWeight.w900)),for(final p in sorted)ListTile(dense:true,title:Text(p['display_name'].toString()),trailing:Text(score(p['user_id'].toString()).toString()+' poin',style:const TextStyle(fontWeight:FontWeight.w900)))]);
  }
  Widget results()=>Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[const Icon(Icons.emoji_events,size:48,color:Color(0xFFC58B2A)),const Text('Permainan selesai!',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),scoreboard(),OutlinedButton(onPressed:leave,child:const Text('Kembali ke lobby'))])));
}
class _GamePainter extends CustomPainter{
  _GamePainter(this.events,this.current);final List<Map<String,dynamic>> events;final List<Offset> current;
  @override void paint(Canvas canvas,Size size){
    final p=Paint()..color=const Color(0xFF167D68)..strokeWidth=4..strokeCap=StrokeCap.round..style=PaintingStyle.stroke;
    for(final e in events){final raw=e['payload'] is Map?e['payload']['points']:null;if(raw is! List||raw.length<2)continue;final path=Path();for(var i=0;i<raw.length;i++){final v=raw[i];if(v is! Map)continue;final x=(v['x'] as num?)?.toDouble()??0;final y=(v['y'] as num?)?.toDouble()??0;if(i==0)path.moveTo(x,y);else path.lineTo(x,y);}canvas.drawPath(path,p);}
    if(current.length>1){final path=Path()..moveTo(current.first.dx,current.first.dy);for(final v in current.skip(1)){path.lineTo(v.dx,v.dy);}canvas.drawPath(path,p);}
  }
  @override bool shouldRepaint(covariant _GamePainter old)=>true;
}

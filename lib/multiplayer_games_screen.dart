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
  final questions=<Map<String,dynamic>>[
    {'q':'Apa fungsi utama hajir dalam permainan marawis?','a':['Menjaga ketukan dasar','Mengatur kostum','Membuka acara','Mengatur mikrofon'],'c':0},
    {'q':'Sikap penting saat bermain bersama?','a':['Bermain sendiri','Saling mendengarkan','Mendahului semua','Mengabaikan aba-aba'],'c':1},
    {'q':'Sebelum tampil, kelompok sebaiknya...','a':['Tidak latihan','Menyamakan tempo','Mengubah lagu','Datang terlambat'],'c':1},
    {'q':'Darbuka dimainkan dengan cara...','a':['Dipukul tangan','Ditiup','Digesek','Dipetik'],'c':0},
    {'q':'Jika tempo tidak sama, pemain harus...','a':['Tetap sendiri','Mendengarkan pemimpin tempo','Mempercepat sendiri','Berhenti mendadak'],'c':1},
    {'q':'Apa tujuan utama latihan bersama?','a':['Mencari siapa paling hebat','Membangun kekompakan','Mengurangi waktu tampil','Menghindari evaluasi'],'c':1},
    {'q':'Apa yang perlu dilakukan saat salah masuk ketukan?','a':['Tetap tenang dan kembali mengikuti irama','Berhenti lalu pulang','Menyalahkan pemain lain','Mempercepat semua pukulan'],'c':0},
    {'q':'Siapa yang memberi aba-aba awal dan akhir penampilan?','a':['Penonton','Pemimpin/dirigen kelompok','Petugas dokumentasi','Siapa saja secara acak'],'c':1},
    {'q':'Mengapa alat musik perlu dirawat?','a':['Agar terlihat mahal','Agar awet dan tetap layak dimainkan','Supaya lebih berat','Agar tidak dipakai latihan'],'c':1},
    {'q':'Apa sikap terbaik ketika teman sedang mendapat giliran?','a':['Mengganggu','Mendengarkan dan menghargai','Menertawakan','Berbicara keras'],'c':1},
    {'q':'Ketika jadwal latihan berubah, anggota sebaiknya...','a':['Mengabaikan kabar','Mengecek informasi resmi','Menyebarkan rumor','Datang kapan saja'],'c':1},
    {'q':'Apa arti menjaga dinamika musik?','a':['Mengatur keras-lembut permainan','Mengganti semua alat','Memainkan nada secara acak','Mempercepat lagu terus-menerus'],'c':0},
    {'q':'Apa yang harus diperhatikan saat berpindah formasi?','a':['Keamanan dan aba-aba','Kecepatan berlari','Meninggalkan alat','Berjalan tanpa melihat sekitar'],'c':0},
    {'q':'Mengapa pemain perlu memahami lagu sebelum tampil?','a':['Agar bisa mengikuti struktur dan perubahan bagian','Agar tidak perlu latihan','Agar bebas mengubah tempo','Agar tampil lebih cepat selesai'],'c':0},
    {'q':'Apa tindakan tepat jika alat mengalami kendala?','a':['Memaksakan sampai rusak','Melapor kepada penanggung jawab','Menyembunyikannya','Melempar alat'],'c':1},
    {'q':'Apa yang dimaksud kekompakan dalam tim?','a':['Semua bermain sesuka hati','Saling menyesuaikan dan bekerja sama','Hanya mengikuti pemain terkuat','Tidak perlu komunikasi'],'c':1},
    {'q':'Saat menerima kritik setelah tampil, sebaiknya...','a':['Menolak semuanya','Mendengarkan dan mengevaluasi','Menyalahkan penonton','Menghindari latihan berikutnya'],'c':1},
    {'q':'Apa manfaat pemanasan sebelum bermain?','a':['Membantu kesiapan tubuh dan tangan','Mengganti latihan inti','Membuat alat lebih keras','Mempercepat acara'],'c':0},
    {'q':'Bagaimana cara menjaga suasana latihan tetap positif?','a':['Saling menghargai dan memberi dukungan','Mengejek kesalahan','Membandingkan anggota','Mengabaikan anggota baru'],'c':0},
    {'q':'Apa yang sebaiknya dilakukan setelah penampilan selesai?','a':['Meninggalkan alat begitu saja','Merapikan alat dan melakukan evaluasi','Langsung membubarkan diri tanpa koordinasi','Menyalahkan tim'],'c':1},
    {'q':"Apa nama alat musik yang umum menjadi bagian dari kelompok marawis?",'a':["Rebana","Biola","Saksofon","Piano"],'c':0,'category':"Alat musik"},
    {'q':"Dalam kelompok, apa fungsi pemain bass?",'a':["Memberi dasar ritmis","Mengatur lampu","Membaca pengumuman","Merekam video"],'c':0,'category':"Alat musik"},
    {'q':"Apa yang dimaksud tempo dalam musik?",'a':["Kecepatan ketukan","Warna kostum","Jumlah penonton","Ukuran panggung"],'c':0,'category':"Musik"},
    {'q':"Mengapa pemain perlu menghitung ketukan?",'a':["Agar masuk dan berhenti bersama","Agar tampil lebih lama","Agar bebas mengubah lagu","Agar tidak perlu aba-aba"],'c':0,'category':"Musik"},
    {'q':"Apa arti dinamika forte?",'a':["Dimainkan keras","Dimainkan sangat pelan","Dihentikan","Dipercepat"],'c':0,'category':"Musik"},
    {'q':"Apa arti dinamika piano dalam musik?",'a':["Dimainkan lembut","Dimainkan keras","Dimainkan makin cepat","Dimainkan tanpa irama"],'c':0,'category':"Musik"},
    {'q':"Apa yang sebaiknya dilakukan sebelum meminjam alat?",'a':["Meminta izin penanggung jawab","Langsung mengambil","Menyembunyikan alat","Membawa pulang tanpa kabar"],'c':0,'category':"Peralatan"},
    {'q':"Setelah memakai alat, kita harus...",'a':["Mengembalikan dan merapikannya","Meninggalkannya di lantai","Menumpuk sembarangan","Memberikannya ke orang lain"],'c':0,'category':"Peralatan"},
    {'q':"Jika ada anggota baru belum memahami pola, sikap terbaik adalah...",'a':["Membantu menjelaskan","Mengejeknya","Mengabaikannya","Melarang ikut latihan"],'c':0,'category':"Kerja sama"},
    {'q':"Apa manfaat evaluasi setelah latihan?",'a':["Mengetahui hal yang perlu diperbaiki","Mencari kambing hitam","Mengurangi kekompakan","Mengganti semua anggota"],'c':0,'category':"Kerja sama"},
    {'q':"Ketika pemimpin memberi aba-aba, anggota sebaiknya...",'a':["Memperhatikan dan mengikuti","Tetap berbicara","Bermain sesuka hati","Mengabaikannya"],'c':0,'category':"Disiplin"},
    {'q':"Apa contoh tanggung jawab anggota?",'a':["Hadir sesuai jadwal dan memberi kabar jika berhalangan","Datang kapan saja","Meminjam alat tanpa izin","Meninggalkan tugas"],'c':0,'category':"Disiplin"},
    {'q':"Jika dua anggota berbeda pendapat, sebaiknya...",'a':["Berdiskusi dengan saling menghormati","Saling menyalahkan","Membuat kelompok sendiri","Menghentikan latihan selamanya"],'c':0,'category':"Kerja sama"},
    {'q':"Apa arti solidaritas dalam tim?",'a':["Saling mendukung dan peduli","Bersaing dengan menjatuhkan","Bekerja sendiri","Menghindari komunikasi"],'c':0,'category':"Kerja sama"},
    {'q':"Mengapa komunikasi penting saat tampil?",'a':["Agar koordinasi berjalan baik","Agar semua bermain berbeda","Agar aba-aba tidak terdengar","Agar latihan berhenti"],'c':0,'category':"Kerja sama"},
    {'q':"Apa yang harus dilakukan jika terlambat latihan?",'a':["Memberi kabar dan meminta arahan","Masuk tanpa izin lalu mengganggu","Menyalahkan teman","Tidak perlu memberi tahu"],'c':0,'category':"Disiplin"},
    {'q':"Sikap yang tepat saat menerima tugas kepanitiaan adalah...",'a':["Menjalankan tugas dengan tanggung jawab","Mengabaikan sampai diingatkan","Melimpahkan semuanya","Menghilang saat acara"],'c':0,'category':"Organisasi"},
    {'q':"Notulen rapat berguna untuk...",'a':["Mencatat pembahasan dan keputusan","Menghias ruangan","Menggantikan daftar hadir","Mengatur suara alat"],'c':0,'category':"Organisasi"},
    {'q':"Apa tujuan pembagian tugas dalam acara?",'a':["Pekerjaan lebih teratur dan jelas","Semua orang mengerjakan hal yang sama","Tidak ada yang bertanggung jawab","Acara berjalan tanpa koordinasi"],'c':0,'category':"Organisasi"},
    {'q':"Jika informasi kegiatan berubah, anggota sebaiknya...",'a':["Memeriksa pengumuman resmi terbaru","Mengikuti kabar yang belum jelas","Menyebarkan dugaan","Mengabaikan perubahan"],'c':0,'category':"Organisasi"},
    {'q':"Sikap jujur saat melakukan kesalahan adalah...",'a':["Mengakui dan memperbaikinya","Menyalahkan orang lain","Menyembunyikan semuanya","Menghapus bukti"],'c':0,'category':"Karakter"},
    {'q':"Menghargai perbedaan pendapat berarti...",'a':["Mendengarkan tanpa merendahkan","Memaksa semua setuju","Menertawakan pendapat","Tidak memberi kesempatan bicara"],'c':0,'category':"Karakter"},
    {'q':"Contoh sikap amanah adalah...",'a':["Menjaga kepercayaan dan menjalankan tugas","Mengingkari janji","Mengabaikan titipan","Menggunakan barang tanpa izin"],'c':0,'category':"Karakter"},
    {'q':"Apa makna disiplin waktu?",'a':["Menghargai waktu dan hadir sesuai jadwal","Datang sesuka hati","Menunda semua tugas","Pulang sebelum kegiatan selesai"],'c':0,'category':"Karakter"},
    {'q':"Saat teman sedang berbicara, kita sebaiknya...",'a':["Mendengarkan dengan baik","Memotong terus-menerus","Bermain sendiri","Mengejek ucapannya"],'c':0,'category':"Karakter"},
    {'q':"Apa yang dimaksud musyawarah?",'a':["Membahas persoalan untuk mencapai keputusan bersama","Memaksakan kehendak","Memilih tanpa mendengar pendapat","Menghindari masalah"],'c':0,'category':"Karakter"},
    {'q':"Berapa hasil 12 × 8?",'a':["96","86","108","ан"],'c':0,'category':"Logika"},
    {'q':"Jika latihan dimulai pukul 15.30 dan berlangsung 90 menit, selesai pukul...",'a':["17.00","16.00","16.30","17.30"],'c':0,'category':"Logika"},
    {'q':"Urutan angka 2, 4, 8, 16, ... berikutnya adalah...",'a':["32","24","18","20"],'c':0,'category':"Logika"},
    {'q':"Jika satu tim berisi 5 orang dan ada 4 tim, jumlah anggota seluruhnya...",'a':["20","15","25","10"],'c':0,'category':"Logika"},
    {'q':"Apa ibu kota Indonesia?",'a':["Jakarta","Bandung","Surabaya","Medan"],'c':0,'category':"Pengetahuan umum"},
    {'q':"Planet yang dikenal sebagai Planet Merah adalah...",'a':["Mars","Venus","Jupiter","Saturnus"],'c':0,'category':"Pengetahuan umum"},
    {'q':"Alat untuk mengukur suhu disebut...",'a':["Termometer","Barometer","Kompas","Stopwatch"],'c':0,'category':"Pengetahuan umum"},
    {'q':"Dalam satu jam terdapat berapa menit?",'a':["60","30","90","100"],'c':0,'category':"Pengetahuan umum"},
    {'q':"Apa nama proses tumbuhan membuat makanan dengan bantuan cahaya?",'a':["Fotosintesis","Evaporasi","Kondensasi","Fermentasi"],'c':0,'category':"Pengetahuan umum"},
    {'q':"Apa nama arah mata angin yang berlawanan dengan utara?",'a':["Selatan","Timur","Barat","Tenggara"],'c':0,'category':"Pengetahuan umum"},
    {'q':"Sikap tabayyun mengajarkan kita untuk...",'a':["Memeriksa kebenaran informasi","Langsung menyebarkan kabar","Memercayai semua rumor","Mengabaikan fakta"],'c':0,'category':"Keislaman"},
    {'q':"Sebelum memulai kegiatan yang baik, umat Islam dianjurkan...",'a':["Berdoa","Berlomba menyalahkan","Mengabaikan niat","Menunda tanpa alasan"],'c':0,'category':"Keislaman"},
    {'q':"Apa makna ukhuwah?",'a':["Persaudaraan","Persaingan","Perpecahan","Perdebatan"],'c':0,'category':"Keislaman"},
    {'q':"Sikap amanah dalam kehidupan sehari-hari ditunjukkan dengan...",'a':["Menjaga titipan","Membocorkan rahasia orang","Mengambil hak teman","Mengingkari tanggung jawab"],'c':0,'category':"Keislaman"},
    {'q':"Ketika berbeda pendapat, adab yang baik adalah...",'a':["Bersikap santun","Menghina","Meninggikan suara","Memutus pertemanan"],'c':0,'category':"Keislaman"},
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
      if(!mounted)return;setState(() { room=Map<String,dynamic>.from(x[0] as Map); players=List<Map<String,dynamic>>.from(x[1] as List); events=List<Map<String,dynamic>>.from(x[2] as List); });
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
    if(type=='quiz_arena'){
      final order=List<int>.generate(questions.length,(i)=>i)..shuffle(Random.secure());
      s['question_order']=order.take(20).toList();
      s['answer_orders']=(s['question_order'] as List).map((_)=>[0,1,2,3]..shuffle(Random.secure())).toList();
    }
    if(type=='draw_guess'){secretWord=words[Random.secure().nextInt(words.length)];s['drawer_id']=db.auth.currentUser!.id;}
    await updateState(s,status:'playing');
  }
  Future<void> leave()async{
    final id=roomId;if(id==null)return;
    try{if(host)await db.from('multiplayer_rooms').update({'status':'finished','game_state':{...state,'phase':'finished'}}).eq('id',id);await db.from('multiplayer_players').delete().eq('room_id',id).eq('user_id',db.auth.currentUser!.id);}catch(_){}
    await channel?.unsubscribe();if(mounted)setState(() { roomId=null; room=null; players=[]; events=[]; secretWord=null; });loadRooms();
  }
  Future<void> finish()async=>updateState({...state,'phase':'finished'},status:'finished');
  String title(String key)=>key=='quiz_arena'?'Marawis Quiz Arena':key=='who_leader'?'Who Is The Leader?':'Draw & Guess';
  Map<String,dynamic> player(String id)=>players.firstWhere((p)=>p['user_id']==id,orElse:()=>{});
  String playerName(String id)=>(player(id)['display_name']??'Pemain').toString();
  int score(String id)=>events.where((e){if(e['event_type']=='answer'&&e['actor_id']==id){final round=(e['payload']['round'] as num?)?.toInt()??-1;final choice=(e['payload']['choice'] as num?)?.toInt()??-1;final order=state['question_order'] is List?List<int>.from(state['question_order'] as List):List<int>.generate(questions.length,(i)=>i);final qIndex=round>=0&&round<order.length?order[round]:-1;final answerOrders=state['answer_orders'] is List?state['answer_orders'] as List:[];final answerOrder=round>=0&&round<answerOrders.length?List<int>.from(answerOrders[round] as List):[0,1,2,3];return qIndex>=0&&qIndex<questions.length&&choice>=0&&choice<answerOrder.length&&answerOrder[choice]==questions[qIndex]['c'];}return e['event_type']=='guess'&&e['payload']['accepted']==true&&e['payload']['target']==id;}).length*10;
  Widget cardGame(String key,String name,String detail,IconData icon){
    final colors=key=='quiz_arena'?const [Color(0xFF6B4EFF),Color(0xFFAA55E8)]:key=='who_leader'?const [Color(0xFF087E8B),Color(0xFF35B6A4)]:const [Color(0xFFE46C32),Color(0xFFF2B544)];
    return Container(
      margin:const EdgeInsets.only(bottom:12),
      decoration:BoxDecoration(gradient:LinearGradient(colors:colors),borderRadius:BorderRadius.circular(22),boxShadow:[BoxShadow(color:colors.first.withOpacity(.22),blurRadius:16,offset:const Offset(0,7))]),
      child:Material(color:Colors.transparent,borderRadius:BorderRadius.circular(22),child:InkWell(borderRadius:BorderRadius.circular(22),onTap:staff?()=>createRoom(key):joinCode,child:Padding(padding:const EdgeInsets.all(17),child:Row(children:[
        Container(width:58,height:58,decoration:BoxDecoration(color:Colors.white.withOpacity(.19),borderRadius:BorderRadius.circular(18)),child:Icon(icon,color:Colors.white,size:31)),
        const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(name,style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w900)),
          const SizedBox(height:4),Text(detail,style:const TextStyle(color:Colors.white70,fontSize:12)),
          const SizedBox(height:9),Text(staff?'BUAT ROOM  →':'LIHAT & GABUNG  →',style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.1)),
        ])),
        const Icon(Icons.play_circle_fill_rounded,color:Colors.white,size:34),
      ])))));
  }
  @override Widget build(BuildContext context){
    if(roomId!=null)return AnimatedSwitcher(duration:const Duration(milliseconds:650),switchInCurve:Curves.easeOutCubic,switchOutCurve:Curves.easeInCubic,transitionBuilder:(child,animation)=>FadeTransition(opacity:animation,child:SlideTransition(position:Tween<Offset>(begin:const Offset(0,.05),end:Offset.zero).animate(animation),child:child)),child:KeyedSubtree(key:ValueKey(roomId!+"_"+(room?["status"]??"loading").toString()),child:roomPage()));
    return Scaffold(body:RefreshIndicator(onRefresh:loadRooms,child:ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF17113D),Color(0xFF442B87),Color(0xFF147D83)]),borderRadius:BorderRadius.circular(26),boxShadow:[BoxShadow(color:const Color(0xFF33236F).withOpacity(.24),blurRadius:22,offset:const Offset(0,10))]),child:Stack(children:[
        Positioned(right:-8,top:-12,child:Icon(Icons.sports_esports_rounded,size:112,color:Colors.white.withOpacity(.08))),
        Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[const Icon(Icons.bolt_rounded,color:Color(0xFFFFD166),size:18),const SizedBox(width:6),const Text('MARAWIS MULTIPLAYER ARENA',style:TextStyle(color:Colors.white70,fontWeight:FontWeight.w900,fontSize:10,letterSpacing:1.3))]),
          const SizedBox(height:15),const Text('LET THE\nGAME BEGIN!',style:TextStyle(color:Colors.white,fontSize:31,height:1.0,fontWeight:FontWeight.w900,letterSpacing:-.5)),
          const SizedBox(height:10),Text(staff?'Buat arena, undang teman, dan mulai tantangannya.':'Masuk ke arena dan main bareng satu tim.',style:const TextStyle(color:Colors.white70,fontSize:13)),
          if(!staff)Padding(padding:const EdgeInsets.only(top:15),child:FilledButton.icon(onPressed:joinCode,icon:const Icon(Icons.key_rounded),label:const Text('Gabung pakai kode'),style:FilledButton.styleFrom(backgroundColor:const Color(0xFFFFD166),foregroundColor:const Color(0xFF211744),padding:const EdgeInsets.symmetric(horizontal:18,vertical:13)))),
        ]),
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
    final r=room;
    if(r==null)return const Scaffold(backgroundColor:Color(0xFF111329),body:Center(child:CircularProgressIndicator(color:Color(0xFFFFD166))));
    final status=r["status"].toString();
    if(status=="playing")return gameplayPage();
    if(status=="finished")return results();
    return Scaffold(
      backgroundColor:const Color(0xFF111329),
      body:Container(
        decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF17152F),Color(0xFF28204F),Color(0xFF123C43)])),
        child:SafeArea(child:Column(children:[
          Padding(padding:const EdgeInsets.all(16),child:Row(children:[
            _roundAction(Icons.close_rounded,leave),
            const SizedBox(width:12),
            const Expanded(child:Text("GAME ROOM",style:TextStyle(color:Colors.white70,fontWeight:FontWeight.w900,letterSpacing:2))),
            _livePill("LOBBY"),
          ])),
          Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(20,12,20,24),children:[
            Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF694BDF),Color(0xFF9B54D8)]),borderRadius:BorderRadius.circular(27)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(title(r["game_type"].toString()).toUpperCase(),style:const TextStyle(color:Colors.white70,fontWeight:FontWeight.w900,fontSize:10,letterSpacing:1.5)),
              const SizedBox(height:12),
              const Text("Siap-siap\nmain bareng!",style:TextStyle(color:Colors.white,fontSize:31,height:1.05,fontWeight:FontWeight.w900)),
              const SizedBox(height:18),
              Row(children:[
                Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),decoration:BoxDecoration(color:Colors.black.withOpacity(.18),borderRadius:BorderRadius.circular(14)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  const Text("KODE ROOM",style:TextStyle(color:Colors.white70,fontSize:9,fontWeight:FontWeight.w800)),
                  Text(r["room_code"].toString(),style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900,letterSpacing:4)),
                ])),
                const Spacer(),
                Text(players.length.toString()+"/"+r["max_players"].toString()+" pemain",style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800)),
              ]),
            ])),
            const SizedBox(height:24),
            Row(children:[const Expanded(child:Text("Pemain di arena",style:TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w900))),Text(players.length.toString()+" ONLINE",style:const TextStyle(color:Color(0xFF70E2B2),fontSize:10,fontWeight:FontWeight.w900))]),
            const SizedBox(height:12),
            for(final p in players)Container(margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white.withOpacity(.08),borderRadius:BorderRadius.circular(17),border:Border.all(color:Colors.white.withOpacity(.1))),child:Row(children:[
              CircleAvatar(backgroundColor:p["user_id"]==r["host_id"]?const Color(0xFFFFD166):const Color(0xFF7069D9),child:Text(p["display_name"].toString().isEmpty?"?":p["display_name"].toString()[0].toUpperCase(),style:const TextStyle(color:Color(0xFF17152F),fontWeight:FontWeight.w900))),
              const SizedBox(width:12),
              Expanded(child:Text(p["display_name"].toString(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800))),
              if(p["user_id"]==r["host_id"])const Text("HOST",style:TextStyle(color:Color(0xFFFFD166),fontSize:10,fontWeight:FontWeight.w900)),
            ])),
            const SizedBox(height:12),
            Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:Colors.white.withOpacity(.07),borderRadius:BorderRadius.circular(17)),child:Row(children:[
              const Icon(Icons.tips_and_updates_rounded,color:Color(0xFFFFD166)),
              const SizedBox(width:10),
              Expanded(child:Text(host?"Mulai permainan saat minimal dua pemain sudah masuk.":"Tunggu host memulai permainan. Layar game akan terbuka otomatis untuk semua pemain.",style:const TextStyle(color:Colors.white70,fontSize:12,height:1.4))),
            ])),
            const SizedBox(height:18),
            if(host)SizedBox(width:double.infinity,height:56,child:FilledButton.icon(onPressed:players.length<2?null:start,icon:const Icon(Icons.play_arrow_rounded,size:25),label:const Text("MULAI PERMAINAN",style:TextStyle(fontWeight:FontWeight.w900,letterSpacing:1)),style:FilledButton.styleFrom(backgroundColor:const Color(0xFFFFD166),foregroundColor:const Color(0xFF211744),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(17))))),
            if(!host)const Center(child:Text("HOST SEDANG MENYIAPKAN GAME...",style:TextStyle(color:Colors.white54,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.2))),
          ])),
        ])),
      ),
    );
  }
  Widget _roundAction(IconData icon,VoidCallback action)=>Material(color:Colors.white.withOpacity(.1),shape:const CircleBorder(),child:InkWell(customBorder:const CircleBorder(),onTap:action,child:SizedBox(width:42,height:42,child:Icon(icon,color:Colors.white,size:20))));
  Widget _livePill(String label)=>Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:7),decoration:BoxDecoration(color:const Color(0xFF70E2B2).withOpacity(.14),borderRadius:BorderRadius.circular(30),border:Border.all(color:const Color(0xFF70E2B2).withOpacity(.35))),child:Row(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.circle,size:7,color:Color(0xFF70E2B2)),const SizedBox(width:6),Text(label,style:const TextStyle(color:Color(0xFF70E2B2),fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1))]));
  Widget gameplayPage(){
    final r=room!;
    return Scaffold(backgroundColor:const Color(0xFF111329),body:Container(
      decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF17152F),Color(0xFF211D45),Color(0xFF123C43)])),
      child:SafeArea(child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(14,10,14,12),child:Row(children:[
          _roundAction(Icons.close_rounded,leave),
          const SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(title(r["game_type"].toString()),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:14)),
            Text("ROOM "+r["room_code"].toString(),style:const TextStyle(color:Colors.white54,fontSize:9,fontWeight:FontWeight.w800,letterSpacing:1.3)),
          ])),
          _livePill("LIVE"),
          const SizedBox(width:8),
          Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),decoration:BoxDecoration(color:Colors.white.withOpacity(.1),borderRadius:BorderRadius.circular(30)),child:Row(children:[const Icon(Icons.people_alt_rounded,color:Colors.white70,size:15),const SizedBox(width:5),Text(players.length.toString(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900))])),
        ])),
        Expanded(child:AnimatedSwitcher(duration:const Duration(milliseconds:420),child:KeyedSubtree(key:ValueKey(state["phase"].toString()+"_"+(state["round"]??0).toString()),child:gamePanel()))),
        _playerStrip(),
      ])),
    ));
  }
  Widget _playerStrip()=>Container(height:82,padding:const EdgeInsets.fromLTRB(14,9,14,10),decoration:BoxDecoration(color:Colors.black.withOpacity(.2),border:Border(top:BorderSide(color:Colors.white.withOpacity(.08)))),child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:players.length,separatorBuilder:(_,__)=>const SizedBox(width:12),itemBuilder:(context,index){
    final p=players[index];final name=p["display_name"].toString();final isMe=p["user_id"]==db.auth.currentUser?.id;
    return SizedBox(width:62,child:Column(children:[
      CircleAvatar(radius:21,backgroundColor:isMe?const Color(0xFFFFD166):const Color(0xFF7069D9),child:Text(name.isEmpty?"?":name[0].toUpperCase(),style:const TextStyle(color:Color(0xFF17152F),fontWeight:FontWeight.w900))),
      const SizedBox(height:5),
      Text(name,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:isMe?const Color(0xFFFFD166):Colors.white70,fontSize:9,fontWeight:FontWeight.w800)),
      Text(score(p["user_id"].toString()).toString()+" PTS",style:const TextStyle(color:Colors.white38,fontSize:8,fontWeight:FontWeight.w700)),
    ]));
  }));
  Widget gamePanel(){
    final key=room!['game_type'].toString();
    if(key=='quiz_arena')return quizPanel();
    if(key=='who_leader')return leaderPanel();
    return drawPanel();
  }
  Widget quizPanel(){
    final i=(state["round"] as num?)?.toInt()??0;
    final order=state["question_order"] is List?List<int>.from(state["question_order"] as List):List<int>.generate(questions.length,(n)=>n);
    if(i>=order.length)return results();
    final qIndex=order[i];final q=questions[qIndex];
    final answerOrders=state["answer_orders"] is List?state["answer_orders"] as List:[];
    final answerOrder=i<answerOrders.length?List<int>.from(answerOrders[i] as List):[0,1,2,3];
    final uid=db.auth.currentUser!.id;
    final mine=events.any((e)=>e["actor_id"]==uid&&e["event_type"]=="answer"&&e["payload"]["round"]==i);
    final count=events.where((e)=>e["event_type"]=="answer"&&e["payload"]["round"]==i).length;
    return SingleChildScrollView(padding:const EdgeInsets.fromLTRB(18,8,18,20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Text("ROUND "+(i+1).toString().padLeft(2,"0"),style:const TextStyle(color:Color(0xFFFFD166),fontSize:11,fontWeight:FontWeight.w900,letterSpacing:1.5)),const Spacer(),Text((i+1).toString()+"/"+order.length.toString(),style:const TextStyle(color:Colors.white70,fontWeight:FontWeight.w900))]),
      const SizedBox(height:10),
      ClipRRect(borderRadius:BorderRadius.circular(20),child:LinearProgressIndicator(value:(i+1)/order.length,minHeight:7,backgroundColor:Colors.white12,color:const Color(0xFFFFD166))),
      const SizedBox(height:22),
      Container(width:double.infinity,padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF7256D9),Color(0xFF453E9A)]),borderRadius:BorderRadius.circular(26),boxShadow:[BoxShadow(color:const Color(0xFF6D54D8).withOpacity(.2),blurRadius:24,offset:const Offset(0,10))]),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Icon(Icons.bolt_rounded,color:Color(0xFFFFD166),size:17),const SizedBox(width:6),Text((q["category"]??"MARAWIS CHALLENGE").toString().toUpperCase(),style:const TextStyle(color:Colors.white70,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1.2))]),
        const SizedBox(height:18),
        Text(q["q"].toString(),style:const TextStyle(color:Colors.white,fontSize:23,height:1.25,fontWeight:FontWeight.w900)),
        const SizedBox(height:15),
        Row(children:[const Icon(Icons.people_alt_rounded,color:Colors.white60,size:16),const SizedBox(width:6),Text(count.toString()+" dari "+players.length.toString()+" pemain sudah menjawab",style:const TextStyle(color:Colors.white70,fontSize:11,fontWeight:FontWeight.w700))]),
      ])),
      const SizedBox(height:20),
      const Text("PILIH JAWABANMU",style:TextStyle(color:Colors.white70,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.4)),
      const SizedBox(height:10),
      for(var n=0;n<answerOrder.length;n++)Padding(padding:const EdgeInsets.only(bottom:10),child:Material(color:Colors.transparent,borderRadius:BorderRadius.circular(17),child:InkWell(
        onTap:mine?null:()=>emit("answer",{"round":i,"choice":n}),
        borderRadius:BorderRadius.circular(17),
        child:Container(padding:const EdgeInsets.symmetric(horizontal:15,vertical:15),decoration:BoxDecoration(color:mine?Colors.white.withOpacity(.055):Colors.white.withOpacity(.11),borderRadius:BorderRadius.circular(17),border:Border.all(color:mine?Colors.white.withOpacity(.08):const Color(0xFF8B80E8).withOpacity(.55),width:1.2)),child:Row(children:[
          Container(width:34,height:34,alignment:Alignment.center,decoration:BoxDecoration(color:const Color(0xFF8174E6).withOpacity(.3),borderRadius:BorderRadius.circular(11)),child:Text(String.fromCharCode(65+n),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900))),
          const SizedBox(width:12),Expanded(child:Text((q["a"] as List)[answerOrder[n]].toString(),style:const TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w700))),
          Icon(mine?Icons.lock_outline_rounded:Icons.arrow_forward_rounded,color:Colors.white54,size:18),
        ])),
      ))),
      if(mine)Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFF70E2B2).withOpacity(.12),borderRadius:BorderRadius.circular(15),border:Border.all(color:const Color(0xFF70E2B2).withOpacity(.25))),child:const Row(children:[Icon(Icons.check_circle_rounded,color:Color(0xFF70E2B2)),SizedBox(width:9),Expanded(child:Text("Jawaban terkirim! Tunggu host melanjutkan ronde.",style:TextStyle(color:Color(0xFFB7F4D8),fontWeight:FontWeight.w700,fontSize:12)))])),
      const SizedBox(height:18),
      if(host)SizedBox(width:double.infinity,height:52,child:FilledButton.icon(onPressed:()=>i+1<order.length?updateState({...state,"round":i+1}):finish(),icon:const Icon(Icons.skip_next_rounded),label:Text(i+1<order.length?"RONDE BERIKUTNYA":"LIHAT HASIL AKHIR"),style:FilledButton.styleFrom(backgroundColor:const Color(0xFFFFD166),foregroundColor:const Color(0xFF211744),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))))),
      const SizedBox(height:10),scoreboard(),
    ]));
  }
  Widget leaderPanel(){
    final votes=events.where((e)=>e["event_type"]=="vote").toList();
    final uid=db.auth.currentUser!.id;final mine=votes.any((e)=>e["actor_id"]==uid);
    final tally=<String,int>{};for(final e in votes){final t=e["payload"]["target"]?.toString();if(t!=null)tally[t]=(tally[t]??0)+1;}
    final sorted=tally.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    return SingleChildScrollView(padding:const EdgeInsets.fromLTRB(18,12,18,20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Container(width:double.infinity,padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF087E8B),Color(0xFF3D72B7)]),borderRadius:BorderRadius.circular(25)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Icon(Icons.workspace_premium_rounded,color:Color(0xFFFFD166),size:34),
        const SizedBox(height:14),
        const Text("WHO IS THE\nNEXT LEADER?",style:TextStyle(color:Colors.white,fontSize:26,height:1.05,fontWeight:FontWeight.w900)),
        const SizedBox(height:8),
        const Text("Pilih teman yang paling cocok memimpin dan menjaga kekompakan tim.",style:TextStyle(color:Colors.white70,fontSize:12,height:1.45)),
        const SizedBox(height:15),
        Text(votes.length.toString()+"/"+players.length.toString()+" SUARA TERKUMPUL",style:const TextStyle(color:Color(0xFFFFD166),fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.2)),
      ])),
      const SizedBox(height:20),
      const Text("PILIH SATU PEMAIN",style:TextStyle(color:Colors.white70,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.3)),
      const SizedBox(height:10),
      if(!mine)for(final p in players)if(p["user_id"]!=uid)Padding(padding:const EdgeInsets.only(bottom:9),child:Material(color:Colors.white.withOpacity(.09),borderRadius:BorderRadius.circular(17),child:InkWell(onTap:()=>emit("vote",{"target":p["user_id"]}),borderRadius:BorderRadius.circular(17),child:Padding(padding:const EdgeInsets.all(13),child:Row(children:[
        CircleAvatar(backgroundColor:const Color(0xFF70CFC4),child:Text(p["display_name"].toString().isEmpty?"?":p["display_name"].toString()[0].toUpperCase(),style:const TextStyle(color:Color(0xFF102D35),fontWeight:FontWeight.w900))),
        const SizedBox(width:12),Expanded(child:Text(p["display_name"].toString(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800))),const Icon(Icons.how_to_vote_rounded,color:Color(0xFFFFD166)),
      ]))))),
      if(mine)Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFF70E2B2).withOpacity(.12),borderRadius:BorderRadius.circular(15)),child:const Text("SUARAMU SUDAH TERCATAT ✓",style:TextStyle(color:Color(0xFF70E2B2),fontWeight:FontWeight.w900,fontSize:11,letterSpacing:1))),
      const SizedBox(height:18),
      const Text("HASIL SEMENTARA",style:TextStyle(color:Colors.white70,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.3)),
      const SizedBox(height:8),
      for(final v in sorted)Padding(padding:const EdgeInsets.only(bottom:8),child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white.withOpacity(.07),borderRadius:BorderRadius.circular(14)),child:Row(children:[Expanded(child:Text(playerName(v.key),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700))),Text(v.value.toString()+" suara",style:const TextStyle(color:Color(0xFFFFD166),fontWeight:FontWeight.w900))]))),
      if(host)Padding(padding:const EdgeInsets.only(top:12),child:SizedBox(width:double.infinity,height:52,child:FilledButton(onPressed:finish,style:FilledButton.styleFrom(backgroundColor:const Color(0xFFFFD166),foregroundColor:const Color(0xFF211744),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),child:const Text("TUTUP VOTING & LIHAT HASIL")))),
    ]));
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

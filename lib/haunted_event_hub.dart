import 'dart:async';
import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HauntedEventHub extends StatefulWidget {
  const HauntedEventHub({super.key, required this.playerName});
  final String playerName;
  @override State<HauntedEventHub> createState()=>_HauntedEventHubState();
}
class _HauntedEventHubState extends State<HauntedEventHub>{
  int xp=0; final Set<String> done={}; String? game; bool loading=true; int tab=0;
  int streak=0; final Set<String> dailyDone={}; List<Map<String,dynamic>> leaderboard=[];
  bool leaderboardLoading=false; String? leaderboardError;
  @override void initState(){super.initState();_load();}
  String get _today => _dateKey(DateTime.now());
  String _dateKey(DateTime d) => '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  Future<void> _load()async{
    final p=await SharedPreferences.getInstance();
    final today=_today, savedDay=p.getString('rainy_daily_day_v1');
    var currentXp=p.getInt('rainy_xp_v1')??0;
    var currentStreak=p.getInt('rainy_streak_v1')??0;
    final lastVisit=p.getString('rainy_last_visit_v1');
    final daily=<String>{...(p.getStringList('rainy_daily_done_v1')??[])};
    if(savedDay!=today){
      final yesterday=_dateKey(DateTime.now().subtract(const Duration(days:1)));
      currentStreak=lastVisit==yesterday?currentStreak+1:1;
      daily..clear()..add('visit');
      currentXp+=20;
      await p.setString('rainy_daily_day_v1',today);
      await p.setString('rainy_daily_done_v1',daily.toList());
      await p.setInt('rainy_daily_xp_v1',0);
      await p.setStringList('rainy_daily_games_v1',[]);
      final lastRewardedStreak=p.getInt('rainy_streak_rewarded_v1')??0;
      if(currentStreak>=3&&currentStreak%3==0&&lastRewardedStreak<currentStreak){
        currentXp+=50;
        daily.add('streak');
        await p.setInt('rainy_streak_rewarded_v1',currentStreak);
        await p.setInt('rainy_xp_v1',currentXp);
        await p.setStringList('rainy_daily_done_v1',daily.toList());
      }
      await p.setString('rainy_last_visit_v1',today);
      await p.setInt('rainy_streak_v1',currentStreak);
      await p.setInt('rainy_xp_v1',currentXp);
    }
    if(!mounted)return;
    setState(() {
      xp=currentXp; streak=currentStreak; dailyDone..clear()..addAll(daily);
      done.addAll(p.getStringList('rainy_done_v1')??[]); loading=false;
    });
    _syncLeaderboard();
  }
  Future<void> _completeDaily(String id,int reward) async {
    if(dailyDone.contains(id))return;
    final p=await SharedPreferences.getInstance();
    if(!mounted)return;
    setState(() { dailyDone.add(id); xp+=reward; });
    await p.setStringList('rainy_daily_done_v1',dailyDone.toList());
    await p.setInt('rainy_xp_v1',xp);
    await _syncLeaderboard();
  }
  Future<void> _win(String id,int points)async{
    if(done.contains(id))return;
    final p=await SharedPreferences.getInstance();
    if(!mounted)return;
    setState(() { done.add(id); xp += points; });
    await p.setInt('rainy_xp_v1',xp);
    await p.setStringList('rainy_done_v1',done.toList());
    final todayXp=(p.getInt('rainy_daily_xp_v1')??0)+points;
    await p.setInt('rainy_daily_xp_v1',todayXp);
    if(!dailyDone.contains('play')) await _completeDaily('play',40);
    final todayGames=(p.getStringList('rainy_daily_games_v1')??[])..add(id);
    await p.setStringList('rainy_daily_games_v1',todayGames.toSet().toList());
    if(todayGames.toSet().length>=2&&!dailyDone.contains('combo')) await _completeDaily('combo',60);
    if(todayXp>=100&&!dailyDone.contains('xp')) await _completeDaily('xp',50);
    if(done.containsAll(['raindrop','quiz','memory','word'])&&!done.contains('afterrain_unlocked')){
      setState(()=>done.add('afterrain_unlocked'));
      await p.setStringList('rainy_done_v1',done.toList());
    }
    await _syncLeaderboard();
  }
  Future<void> _syncLeaderboard() async {
    final user=Supabase.instance.client.auth.currentUser;
    if(user==null)return;
    try { await Supabase.instance.client.rpc('submit_rainy_season_score',params:{'p_xp':xp}); } catch (_) {}
  }
  Future<void> _loadLeaderboard() async {
    if(Supabase.instance.client.auth.currentUser==null){
      setState(()=>leaderboardError='Masuk ke akun Marawis untuk melihat leaderboard bersama.');
      return;
    }
    setState(()=>leaderboardLoading=true);
    try {
      await _syncLeaderboard();
      final rows=await Supabase.instance.client.from('rainy_season_scores')
        .select('user_id,display_name,xp,updated_at').order('xp',ascending:false)
        .order('updated_at').limit(50);
      if(!mounted)return;
      setState(()=>leaderboard=List<Map<String,dynamic>>.from(rows));
      leaderboardError=null;
    } catch (_) {
      if(!mounted)return;
      leaderboardError='Leaderboard belum tersedia. Pastikan migrasi database Rainy Season sudah diterapkan.';
    } finally { if(mounted)setState(()=>leaderboardLoading=false); }
  }
  @override Widget build(BuildContext context){
    if(game!=null)return _ArcadeGame(id:game!,back:()=>setState(()=>game=null),win:(v)=>_win(game!,v));
    final level=((xp~/100)+1).clamp(1,10).toInt();
    final progress=(xp%100)/100;
    return Scaffold(
      backgroundColor:const Color(0xFF071522),
      appBar:AppBar(backgroundColor:const Color(0xFF0D2232),foregroundColor:Colors.white,elevation:0,
        title:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('MARAWIS EVENT WORLD',style:TextStyle(fontSize:12,fontWeight:FontWeight.w900,letterSpacing:1.3)),
          SizedBox(height:2),Text('THE RAIN HAS A RHYTHM • RAINY SEASON',style:TextStyle(fontSize:8,color:Color(0xFFA7C7D8),letterSpacing:1.1,fontWeight:FontWeight.w700)),
        ]),
        actions:[Padding(padding:const EdgeInsets.only(right:14),child:Center(child:Text('💧  $xp XP',style:const TextStyle(color:Color(0xFF9DE8F2),fontWeight:FontWeight.w900))))]),
      body:loading?const Center(child:CircularProgressIndicator()):SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(16,12,16,30),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const _RainyWorldAtmosphere(),
        const SizedBox(height:12),
        _EventHero(name:widget.playerName,xp:xp,level:level,progress:progress),
        const SizedBox(height:12),
        _RainPassRewards(level:level),
        const SizedBox(height:14),
        Row(children:[
          Expanded(child:_Stat('RAIN XP',xp.toString(),Icons.bolt_rounded)),const SizedBox(width:9),
          Expanded(child:_Stat('MISSIONS',done.where((x)=>!x.endsWith('_unlocked')).length.toString()+'/4',Icons.flag_rounded)),const SizedBox(width:9),
          Expanded(child:_Stat('RANK','LV. $level',Icons.military_tech_rounded)),
        ]),
        const SizedBox(height:20),
        Container(padding:const EdgeInsets.all(5),decoration:BoxDecoration(color:const Color(0xFF0E2231),borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xFF24485A))),
          child:Row(children:[
            _EventTab(label:'WORLD',selected:tab==0,onTap:()=>setState(()=>tab=0)),
            _EventTab(label:'DAILY',selected:tab==1,onTap:()=>setState(()=>tab=1)),
            _EventTab(label:'BADGES',selected:tab==2,onTap:()=>setState(()=>tab=2)),
            _EventTab(label:'RANK',selected:tab==3,onTap:(){setState(()=>tab=3);_loadLeaderboard();}),
            _EventTab(label:'SECRET',selected:tab==4,onTap:()=>setState(()=>tab=4)),
          ])),
        const SizedBox(height:18),
        if(tab==0)...[
          const _EventSectionTitle(eyebrow:'WELCOME TO THE RAINY SEASON',title:'Choose your adventure',subtitle:'Empat tantangan event menunggumu. Selesaikan misi untuk mengumpulkan XP dan membuka koleksi.'),
          const SizedBox(height:14),
          _StreakCard(streak:streak),
          const SizedBox(height:14),
          _Tile('01','Rain Drop Hunt','Kumpulkan 6 tetes hujan bercahaya sebelum waktu habis.',Icons.search,Color(0xFF43C6D9),done.contains('raindrop'),()=>setState(()=>game='raindrop')),
          _Tile('02','Rainy Rhythm Quiz','Jawab lima pertanyaan tentang Marawis.',Icons.quiz,Color(0xFF75B8FF),done.contains('quiz'),()=>setState(()=>game='quiz')),
          _Tile('03','Memory Maze','Cocokkan empat pasang simbol misterius.',Icons.grid_view,Color(0xFF68D9C0),done.contains('memory'),()=>setState(()=>game='memory')),
          _Tile('04','Secret Word','Pecahkan susunan huruf rahasia.',Icons.spellcheck,Color(0xFF80DCEB),done.contains('word'),()=>setState(()=>game='word')),
          const SizedBox(height:6),
          const _EventNotice(text:'XP dan progres mini-game tersimpan pada perangkat ini. Saat masuk akun, total XP terbaik dikirim ke leaderboard bersama.'),
        ],
        if(tab==1)...[
          _EventSectionTitle(eyebrow:'DAILY RAIN MISSIONS',title:'Misi hari ini',subtitle:'Misi diperbarui setiap hari. Selesaikan tantangan dan bangun streak-mu.'),
          const SizedBox(height:8),
          _StreakCard(streak:streak),
          const SizedBox(height:14),
          _MissionRow(title:'Daily Drop-in',detail:'Kunjungi dunia Rainy Season hari ini',reward:'+20 XP • otomatis',complete:dailyDone.contains('visit'),icon:Icons.wb_cloudy_rounded),
          _MissionRow(title:'One Game a Day',detail:'Selesaikan satu mini-game hari ini',reward:'+40 XP',complete:dailyDone.contains('play'),icon:Icons.sports_esports_rounded),
          _MissionRow(title:'Double Rhythm',detail:'Selesaikan dua mini-game berbeda hari ini',reward:'+60 XP',complete:dailyDone.contains('combo'),icon:Icons.bolt_rounded),
          _MissionRow(title:'Rain Collector',detail:'Kumpulkan 100 XP dari aktivitas hari ini',reward:'+50 XP',complete:dailyDone.contains('xp'),icon:Icons.water_drop_rounded),
          _MissionRow(title:'Streak Bonus',detail:'Pertahankan kunjungan selama tiga hari berturut-turut',reward:'+50 XP setiap 3 hari',complete:dailyDone.contains('streak'),icon:Icons.local_fire_department_rounded),
          const SizedBox(height:14),
          const _EventSectionTitle(eyebrow:'EVENT CHALLENGES',title:'Misi utama',subtitle:'Empat tantangan inti membuka akses ke secret event.'),
          const SizedBox(height:10),
          _MissionRow(title:'Chasing Raindrops',detail:'Selesaikan Rain Drop Hunt',reward:'+100 XP',complete:done.contains('raindrop'),icon:Icons.search),
          _MissionRow(title:'Rhythm in the Rain',detail:'Raih minimal 3 jawaban benar di Rainy Rhythm Quiz',reward:'+100 XP',complete:done.contains('quiz'),icon:Icons.quiz),
          _MissionRow(title:'Memory Keeper',detail:'Temukan seluruh empat pasang simbol',reward:'+120 XP',complete:done.contains('memory'),icon:Icons.grid_view),
          _MissionRow(title:'The Hidden Message',detail:'Pecahkan Secret Word',reward:'+100 XP',complete:done.contains('word'),icon:Icons.key),
          const SizedBox(height:12),const _EventNotice(text:'Misi harian dan streak tersimpan di perangkat. Leaderboard XP memakai akun yang masuk dan database bersama.'),
        ],
        if(tab==2)...[
          const _EventSectionTitle(eyebrow:'YOUR RAINY SEASON COLLECTION',title:'Rainy collection',subtitle:'Koleksi terbuka saat tantangan dan level Rain Pass berhasil diselesaikan.'),
          const SizedBox(height:14),
          _CollectionItem(icon:'🌦️',title:'First Rain',detail:'Masuk ke dunia event Rainy Season',unlocked:streak>0),
          _CollectionItem(icon:'⚡',title:'Rain Pass Rookie',detail:'Mencapai level 2 Rain Pass',unlocked:xp>=100),
          _CollectionItem(icon:'🌈',title:'Rainbow Keeper',detail:'Mencapai level 4 Rain Pass',unlocked:xp>=300),
          _CollectionItem(icon:'🏆',title:'Storm Champion',detail:'Mencapai level 6 Rain Pass',unlocked:xp>=500),
          _CollectionItem(icon:'💧',title:'Rain Chaser',detail:'Mengumpulkan seluruh tetes hujan',unlocked:done.contains('raindrop')),
          _CollectionItem(icon:'📜',title:'Rhythm Keeper',detail:'Menuntaskan Rainy Rhythm Quiz',unlocked:done.contains('quiz')),
          _CollectionItem(icon:'🧩',title:'Memory Keeper',detail:'Menyelesaikan Memory Maze',unlocked:done.contains('memory')),
          _CollectionItem(icon:'🗝️',title:'Rhythm Finder',detail:'Menemukan kata rahasia',unlocked:done.contains('word')),
          _CollectionItem(icon:'🌧️',title:'After the Rain',detail:'Selesaikan secret event',unlocked:done.contains('afterrain')),
          _CollectionItem(icon:'💎',title:'Cloud Nine',detail:'Mencapai level 10 Rain Pass',unlocked:xp>=900),
          const SizedBox(height:12),const _EventNotice(text:'Badge terbuka otomatis berdasarkan progres event.'),
        ],
        if(tab==3)...[
          const _EventSectionTitle(eyebrow:'GLOBAL RAIN LEADERBOARD',title:'Rainy Season Rankings',subtitle:'Peringkat XP terbaik dari anggota yang masuk ke akun Marawis.'),
          const SizedBox(height:12),
          Row(children:[const Expanded(child:Text('TOP 50 MEMBERS',style:TextStyle(color:Color(0xFF9DE8F2),fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1))),IconButton(onPressed:_loadLeaderboard,icon:const Icon(Icons.refresh,color:Color(0xFF9DE8F2)))]),
          if(leaderboardLoading) const Center(child:Padding(padding:EdgeInsets.all(24),child:CircularProgressIndicator()))
          else if(leaderboardError!=null) _EventNotice(text:leaderboardError!)
          else if(leaderboard.isEmpty) const _EventNotice(text:'Belum ada skor. Jadilah anggota pertama yang mengumpulkan Rain XP!')
          else ...List.generate(leaderboard.length,(i)=>_LeaderboardRow(rank:i+1,name:(leaderboard[i]['display_name']??'Anggota').toString(),score:(leaderboard[i]['xp'] as num?)?.toInt()??0,isMe:leaderboard[i]['user_id']==Supabase.instance.client.auth.currentUser?.id)),
        ],
        if(tab==4)...[
          _EventSectionTitle(eyebrow:'CLASSIFIED EVENT • UNLOCKED BY FOUR MAIN GAMES',title:'After the Rain',subtitle:done.contains('afterrain_unlocked')?'Kamu menemukan jalur rahasia. Selesaikan satu tantangan terakhir untuk memperoleh badge eksklusif.':'Selesaikan empat mini-game utama untuk membuka event rahasia ini.'),
          const SizedBox(height:14),
          _SecretEventCard(unlocked:done.contains('afterrain_unlocked'),completed:done.contains('afterrain'),onTap:()=>setState(()=>game='afterrain')),
        ],
      ]))),
    );
  }
}

class _RainyWorldAtmosphere extends StatefulWidget {
  const _RainyWorldAtmosphere();
  @override State<_RainyWorldAtmosphere> createState()=>_RainyWorldAtmosphereState();
}
class _RainyWorldAtmosphereState extends State<_RainyWorldAtmosphere> with SingleTickerProviderStateMixin {
  late final AnimationController motion=AnimationController(vsync:this,duration:const Duration(seconds:8))..repeat();
  @override void dispose(){motion.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:motion,builder:(context,_)=>Container(
    height:116,padding:const EdgeInsets.all(16),decoration:BoxDecoration(
      borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFF34758A)),
      gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF164A62),Color(0xFF0B293D),Color(0xFF102D3C)])),
    child:Stack(children:[
      Positioned(right:8,top:-18,child:Transform.translate(offset:Offset(math.sin(motion.value*math.pi*2)*10,0),child:Icon(Icons.cloud_rounded,size:88,color:Colors.white.withValues(alpha:.10)))),
      Positioned(right:70,bottom:2,child:Transform.translate(offset:Offset(0,(motion.value*22)%22),child:Icon(Icons.water_drop_rounded,size:20,color:const Color(0xFF8CE8F0).withValues(alpha:.55)))),
      Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[
        const Text('RAINY WORLD • LIVE ATMOSPHERE',style:TextStyle(color:Color(0xFF9DE8F2),fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1.1)),
        const SizedBox(height:7),const Text('Listen to the rhythm of rain.',style:TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.w900)),
        const SizedBox(height:4),const Text('Setiap rintik punya cerita. Setiap tantangan punya irama.',style:TextStyle(color:Color(0xFFB7D6DF),fontSize:10)),
      ]),
    ]),
  ));
}
class _RainPassRewards extends StatelessWidget {
  const _RainPassRewards({required this.level}); final int level;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFF102536),borderRadius:BorderRadius.circular(17),border:Border.all(color:const Color(0xFF28576A))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('RAIN PASS REWARDS',style:TextStyle(color:Color(0xFF9DE8F2),fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1)),
    const SizedBox(height:10),Row(children:List.generate(5,(i){final lv=(i+1)*2;final unlocked=level>=lv;return Expanded(child:Column(children:[
      Container(width:34,height:34,decoration:BoxDecoration(color:unlocked?const Color(0xFF1D7185):const Color(0xFF1B3040),shape:BoxShape.circle,border:Border.all(color:unlocked?const Color(0xFF73E1E8):const Color(0xFF426070))),child:Icon(unlocked?Icons.card_giftcard_rounded:Icons.lock_outline_rounded,color:unlocked?const Color(0xFFB7F6F4):const Color(0xFF6D8A98),size:17)),
      const SizedBox(height:5),Text('LV $lv',style:TextStyle(color:unlocked?Colors.white:const Color(0xFF7896A2),fontSize:8,fontWeight:FontWeight.w900)),
    ]));})),
  ]));
}
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak}); final int streak;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(borderRadius:BorderRadius.circular(16),gradient:const LinearGradient(colors:[Color(0xFF16465B),Color(0xFF123144)]),border:Border.all(color:const Color(0xFF39788C))),child:Row(children:[
    const Icon(Icons.local_fire_department_rounded,color:Color(0xFFFFC978),size:30),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('$streak DAY RAIN STREAK',style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w900)),
      const SizedBox(height:3),const Text('Kunjungi event setiap hari untuk menjaga streak-mu.',style:TextStyle(color:Color(0xFFB8D7E0),fontSize:9)),
    ])),const Icon(Icons.bolt_rounded,color:Color(0xFF8CE8F0)),
  ]));
}
class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.rank,required this.name,required this.score,required this.isMe});
  final int rank,score; final String name; final bool isMe;
  @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),decoration:BoxDecoration(color:isMe?const Color(0xFF16465B):const Color(0xFF102536),borderRadius:BorderRadius.circular(14),border:Border.all(color:isMe?const Color(0xFF58C9D8):const Color(0xFF24485A))),child:Row(children:[
    SizedBox(width:34,child:Text(rank<=3?['🥇','🥈','🥉'][rank-1]:'#$rank',style:const TextStyle(color:Color(0xFF9DE8F2),fontSize:14,fontWeight:FontWeight.w900))),
    Expanded(child:Text(name,style:TextStyle(color:isMe?const Color(0xFFB9F5F2):Colors.white,fontSize:12,fontWeight:FontWeight.w800))),
    Text('$score XP',style:const TextStyle(color:Color(0xFF9DE8F2),fontSize:11,fontWeight:FontWeight.w900)),
  ]));
}
class _SecretEventCard extends StatelessWidget {
  const _SecretEventCard({required this.unlocked,required this.completed,required this.onTap});
  final bool unlocked,completed; final VoidCallback onTap;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:const LinearGradient(colors:[Color(0xFF183F56),Color(0xFF0A2436)]),border:Border.all(color:const Color(0xFF4A8DA0))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Icon(Icons.wb_twilight_rounded,color:Color(0xFF9DE8F2),size:42),const SizedBox(height:12),
    const Text('AFTER THE RAIN',style:TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900,letterSpacing:1)),
    const SizedBox(height:7),Text(completed?'Rahasia berhasil dibuka. Badge After the Rain sudah menjadi milikmu.':unlocked?'Jalur rahasia terbuka. Pecahkan teka-teki terakhir untuk +200 XP.':'🔒 Selesaikan Rain Drop Hunt, Rainy Rhythm Quiz, Memory Maze, dan Secret Word untuk membuka tantangan ini.',style:const TextStyle(color:Color(0xFFB8D7E0),fontSize:11,height:1.5)),
    const SizedBox(height:14),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:unlocked&&!completed?onTap:null,icon:Icon(completed?Icons.check_circle:Icons.auto_awesome_rounded),label:Text(completed?'SECRET COMPLETED':unlocked?'ENTER SECRET EVENT':'LOCKED'),style:FilledButton.styleFrom(backgroundColor:const Color(0xFF55D2DF),foregroundColor:const Color(0xFF082331)))),
  ]));
}

class _Stat extends StatelessWidget{const _Stat(this.a,this.b,this.i);final String a,b;final IconData i;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:const Color(0xFF102536),borderRadius:BorderRadius.circular(15)),child:Row(children:[Icon(i,color:const Color(0xFF7DDCE8)),const SizedBox(width:8),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:const TextStyle(color:Color(0xFFA5BFCA),fontSize:8,fontWeight:FontWeight.w900)),Text(b,style:const TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w900))]) ]));}
class _Tile extends StatelessWidget{const _Tile(this.n,this.t,this.d,this.i,this.c,this.done,this.tap);final String n,t,d;final IconData i;final Color c;final bool done;final VoidCallback tap;@override Widget build(BuildContext x)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Material(color:const Color(0xFF102536),borderRadius:BorderRadius.circular(17),child:InkWell(onTap:tap,borderRadius:BorderRadius.circular(17),child:Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(borderRadius:BorderRadius.circular(17),border:Border.all(color:done?const Color(0xFF68D9C0):const Color(0xFF24485A))),child:Row(children:[Icon(i,color:c,size:27),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(n+' • '+(done?'COMPLETED':'ARCADE GAME'),style:TextStyle(color:done?const Color(0xFF68D9C0):c,fontSize:8,fontWeight:FontWeight.w900)),Text(t,style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w900)),Text(d,style:const TextStyle(color:Color(0xFFA5BFCA),fontSize:10))])),Icon(done?Icons.check_circle:Icons.arrow_forward,color:c)])))));
}
class _ArcadeGame extends StatefulWidget{const _ArcadeGame({required this.id,required this.back,required this.win});final String id;final VoidCallback back;final ValueChanged<int> win;@override State<_ArcadeGame> createState()=>_ArcadeGameState();}
class _ArcadeGameState extends State<_ArcadeGame>{
  static const qs=[('Alat penjaga ketukan dasar marawis?',['Hajir','Mikrofon','Kabel','Stand banner'],0),('Sikap terbaik saat tampil?',['Menonjol sendiri','Saling mendengarkan','Abaikan aba-aba','Bermain sendiri'],1),('Sebelum tampil perlu…',['Tidak latihan','Menyamakan tempo','Terlambat','Ubah lagu'],1),('Marawis mengajarkan…',['Egoisme','Kerja sama','Tidak disiplin','Perselisihan'],1),('Saat teman salah tempo…',['Mengejek','Membantu','Pergi','Marah'],1)];
  final rng=math.Random(),word=TextEditingController();final symbols=['💧','☔','🌧️','🎵','💧','☔','🌧️','🎵'];final open=<int>{},matched=<int>{};Timer? timer;int sec=25,found=0,target=0,q=0,score=0,moves=0;bool started=false,ended=false,locked=false,wordWon=false;
  @override void initState(){super.initState();target=rng.nextInt(9);}
  @override void dispose(){timer?.cancel();word.dispose();super.dispose();}
  void start(){timer?.cancel();setState(() { started = true; ended = false; sec = 25; found = 0; target = rng.nextInt(9); });timer=Timer.periodic(const Duration(seconds:1),(t){if(!mounted){t.cancel();return;}if(sec<=1){t.cancel();setState(() { sec = 0; ended = true; });}else{setState(()=>sec--);}});}
  void hunt(int i){if(!started||ended)return;if(i==target){if(found==5){timer?.cancel();setState(() { found = 6; ended = true; });widget.win(100);}else{setState(() { found++; target = rng.nextInt(9); });}}else{setState(()=>sec=math.max(0,sec-2).toInt());if(sec==0){timer?.cancel();setState(()=>ended=true);}}}
  void answer(int i){final ok=qs[q].$3==i;setState(() { if (ok) score++; q++; });if(q==qs.length&&score>=3)widget.win(100);}
  Future<void> mem(int i)async{if(locked||matched.contains(i)||open.contains(i))return;setState(()=>open.add(i));if(open.length==2){moves++;final p=open.toList();if(symbols[p[0]]==symbols[p[1]]){setState(() { matched.addAll(p); open.clear(); });if(matched.length==8)widget.win(120);}else{locked=true;await Future.delayed(const Duration(milliseconds:650));if(!mounted)return;setState(() { open.clear(); locked = false; });}}}
  @override Widget build(BuildContext c)=>Scaffold(backgroundColor:const Color(0xFF071522),appBar:AppBar(backgroundColor:const Color(0xFF0D2232),foregroundColor:Colors.white,leading:IconButton(onPressed:widget.back,icon:const Icon(Icons.arrow_back)),title:Text(widget.id.toUpperCase(),style:const TextStyle(fontSize:13,fontWeight:FontWeight.w900))),body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:560),child:SingleChildScrollView(padding:const EdgeInsets.all(18),child:Container(width:double.infinity,padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:const Color(0xFF102536),borderRadius:BorderRadius.circular(20)),child:body())))));
  Widget body(){
    if(widget.id=='raindrop')return Column(children:[const Text('CATCH THE GLOWING RAINDROPS',style:TextStyle(color:Color(0xFF7DDCE8),fontWeight:FontWeight.w900)),Text(started?'Terkumpul $found/6 • $sec detik':'Kumpulkan 6 tetes hujan dalam 25 detik.',style:const TextStyle(color:Colors.white)),if(!started||ended)...[Text(found==6?'RAIN CLEARED! +100 XP':(ended?'Waktu habis!':'Siap berburu?'),style:const TextStyle(color:Color(0xFF9DE8F2))),FilledButton(onPressed:start,child:const Text('Mulai / Ulangi'))]else GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:3,children:List.generate(9,(i)=>InkWell(onTap:()=>hunt(i),child:Container(margin:const EdgeInsets.all(4),decoration:BoxDecoration(color:i==target?const Color(0xFF176A7A):const Color(0xFF1A3B4D),borderRadius:BorderRadius.circular(12)),child:Center(child:Text(i==target?'💧✨':'💧',style:const TextStyle(fontSize:27)))))))]);
    if(widget.id=='quiz')return q>=5?Column(children:[const Text('QUIZ COMPLETE',style:TextStyle(color:Color(0xFF7DDCE8))),Text('Skor: $score / 5',style:const TextStyle(color:Colors.white,fontSize:25)),Text(score>=3?'Bonus XP didapat!':'Minimal 3 jawaban benar untuk bonus XP.',style:const TextStyle(color:Colors.white70)),TextButton(onPressed:widget.back,child:const Text('Kembali'))]):Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text('PERTANYAAN '+(q+1).toString()+'/5',style:const TextStyle(color:Color(0xFF7DDCE8))),const SizedBox(height:12),Text(qs[q].$1,style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w800)),for(var i=0;i<4;i++)Padding(padding:const EdgeInsets.only(top:8),child:OutlinedButton(onPressed:()=>answer(i),style:OutlinedButton.styleFrom(foregroundColor:Colors.white,alignment:Alignment.centerLeft),child:Text(qs[q].$2[i])))]);
    if(widget.id=='afterrain')return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const Text('AFTER THE RAIN • SECRET CHALLENGE',style:TextStyle(color:Color(0xFF7DDCE8),fontWeight:FontWeight.w900)),const SizedBox(height:10),const Text('Apa yang muncul setelah hujan dan memiliki tujuh huruf?',style:TextStyle(color:Colors.white,fontSize:15)),const SizedBox(height:12),TextField(controller:word,enabled:!wordWon,style:const TextStyle(color:Colors.white),decoration:const InputDecoration(hintText:'Tulis jawabanmu',hintStyle:TextStyle(color:Colors.white54))),if(wordWon)const Text('SECRET CLEARED! +200 XP',style:TextStyle(color:Color(0xFF68D9C0))),FilledButton(onPressed:wordWon?null:(){if(word.text.trim().toUpperCase()=='PELANGI'){setState(()=>wordWon=true);widget.win(200);}else{ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Belum tepat. Coba lagi!')));}},child:const Text('Buka rahasia'))]);
    if(widget.id=='memory')return Column(children:[const Text('MATCH ALL FOUR PAIRS',style:TextStyle(color:Color(0xFF7DDCE8))),Text('Langkah: $moves',style:const TextStyle(color:Colors.white70)),GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:4,children:List.generate(8,(i)=>InkWell(onTap:()=>mem(i),child:Container(margin:const EdgeInsets.all(4),decoration:BoxDecoration(color:matched.contains(i)?const Color(0xFF164D58):const Color(0xFF1A3B4D),borderRadius:BorderRadius.circular(12)),child:Center(child:Text(matched.contains(i)||open.contains(i)?symbols[i]:'?',style:const TextStyle(color:Colors.white,fontSize:25))))))),if(matched.length==8)const Text('MEMORY MASTER! +120 XP',style:TextStyle(color:Color(0xFF68D9C0)))]);
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const Text('SECRET WORD',style:TextStyle(color:Color(0xFF7DDCE8))),const Text('Petunjuk: seni musik islami yang menjadi identitas ekstrakurikuler kita.',style:TextStyle(color:Colors.white)),const SizedBox(height:12),const Text('A • R • M • I • S • A • W',textAlign:TextAlign.center,style:TextStyle(color:Color(0xFF7DDCE8),fontSize:20)),TextField(controller:word,enabled:!wordWon,style:const TextStyle(color:Colors.white)),if(wordWon)const Text('BENAR! +100 XP',style:TextStyle(color:Color(0xFF68D9C0))),FilledButton(onPressed:wordWon?null:(){if(word.text.trim().toUpperCase().replaceAll(' ','')=='MARAWIS'){setState(()=>wordWon=true);widget.win(100);}else{ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Belum tepat. Coba lagi!')));}},child:const Text('Periksa jawaban'))]);
  }
}


class _EventHero extends StatelessWidget {
  const _EventHero({required this.name,required this.xp,required this.level,required this.progress});
  final String name; final int xp,level; final double progress;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(
    borderRadius:BorderRadius.circular(25),gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF12465D),Color(0xFF0D2B3D),Color(0xFF081B2A)]),
    border:Border.all(color:const Color(0xFF397F91)),boxShadow:const [BoxShadow(color:Color(0x442B153D),blurRadius:26,offset:Offset(0,12))]),
    child:Stack(children:[
      Positioned(right:-8,top:-12,child:Icon(Icons.water_drop_rounded,size:112,color:Colors.white.withValues(alpha:.06))),
      Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:const Color(0x333EC6D9),borderRadius:BorderRadius.circular(30),border:Border.all(color:const Color(0x663EC6D9))),child:const Text('✦  RAINY SEASON  •  NOV 2026',style:TextStyle(color:Color(0xFF9DE8F2),fontSize:8,fontWeight:FontWeight.w900,letterSpacing:1))),
        const SizedBox(height:18),const Text('THE RAIN\nHAS A RHYTHM',style:TextStyle(color:Colors.white,fontSize:29,height:1.02,fontWeight:FontWeight.w900,letterSpacing:-.7)),
        const SizedBox(height:9),Text('Welcome back, $name',style:const TextStyle(color:Color(0xFFD8F3F5),fontSize:13,fontWeight:FontWeight.w700)),
        const SizedBox(height:18),Row(children:[Text('RAIN PASS  •  LEVEL $level',style:const TextStyle(color:Color(0xFF9DE8F2),fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1)),const Spacer(),Text('$xp XP',style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w900))]),
        const SizedBox(height:8),ClipRRect(borderRadius:BorderRadius.circular(20),child:LinearProgressIndicator(value:progress,minHeight:8,backgroundColor:const Color(0xFF31576A),valueColor:const AlwaysStoppedAnimation(Color(0xFF43C6D9)))),
        const SizedBox(height:6),Text('${(progress*100).round()}% menuju level ${level+1}',style:const TextStyle(color:Color(0xFFA8C9D4),fontSize:9)),
      ]),
    ]));
}
class _EventTab extends StatelessWidget {
  const _EventTab({required this.label,required this.selected,required this.onTap});
  final String label; final bool selected; final VoidCallback onTap;
  @override Widget build(BuildContext context)=>Expanded(child:Material(color:selected?const Color(0xFF176A7A):Colors.transparent,borderRadius:BorderRadius.circular(12),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(12),child:Padding(padding:const EdgeInsets.symmetric(vertical:12,horizontal:4),child:Text(label,textAlign:TextAlign.center,style:TextStyle(color:selected?Colors.white:const Color(0xFF91B4C2),fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.6))))));
}
class _EventSectionTitle extends StatelessWidget {
  const _EventSectionTitle({required this.eyebrow,required this.title,required this.subtitle});
  final String eyebrow,title,subtitle;
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(eyebrow,style:const TextStyle(color:Color(0xFF7DDCE8),fontSize:9,letterSpacing:1.6,fontWeight:FontWeight.w900)),
    const SizedBox(height:7),Text(title,style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900,letterSpacing:-.4)),
    const SizedBox(height:6),Text(subtitle,style:const TextStyle(color:Color(0xFFAFA5BD),fontSize:11,height:1.5)),
  ]);
}
class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.title,required this.detail,required this.reward,required this.complete,required this.icon});
  final String title,detail,reward; final bool complete; final IconData icon;
  @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:const Color(0xFF1A1725),borderRadius:BorderRadius.circular(17),border:Border.all(color:complete?const Color(0xFF477B68):const Color(0xFF382E45))),child:Row(children:[
    Container(width:42,height:42,decoration:BoxDecoration(color:const Color(0x22B78AFF),borderRadius:BorderRadius.circular(13)),child:Icon(icon,color:const Color(0xFF75B8FF))),
    const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w900)),const SizedBox(height:4),
      Text(detail,style:const TextStyle(color:Color(0xFFA5BFCA),fontSize:10,height:1.4)),const SizedBox(height:6),
      Text(reward,style:const TextStyle(color:Color(0xFF7DDCE8),fontSize:9,fontWeight:FontWeight.w900)),
    ])),Icon(complete?Icons.check_circle:Icons.radio_button_unchecked,color:complete?const Color(0xFF68D9C0):const Color(0xFF648B9A)),
  ]));
}
class _CollectionItem extends StatelessWidget {
  const _CollectionItem({required this.icon,required this.title,required this.detail,required this.unlocked});
  final String icon,title,detail; final bool unlocked;
  @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:const Color(0xFF1A1725),borderRadius:BorderRadius.circular(17),border:Border.all(color:unlocked?const Color(0xFF6C5A7D):const Color(0xFF332B40))),child:Row(children:[
    Container(width:48,height:48,decoration:BoxDecoration(color:unlocked?const Color(0x22FFB66E):const Color(0xFF252130),borderRadius:BorderRadius.circular(14)),child:Center(child:Text(unlocked?icon:'🔒',style:const TextStyle(fontSize:24)))),
    const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:TextStyle(color:unlocked?Colors.white:const Color(0xFF8F879B),fontSize:13,fontWeight:FontWeight.w900)),const SizedBox(height:4),
      Text(detail,style:const TextStyle(color:Color(0xFFA5BFCA),fontSize:10)),
    ])),Text(unlocked?'UNLOCKED':'LOCKED',style:TextStyle(color:unlocked?const Color(0xFF68D9C0):const Color(0xFF82798E),fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.6)),
  ]));
}
class _EventNotice extends StatelessWidget {
  const _EventNotice({required this.text}); final String text;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:const Color(0xFF0D2232),borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xFF342A42))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Icon(Icons.info_outline_rounded,color:Color(0xFF7DDCE8),size:17),const SizedBox(width:9),Expanded(child:Text(text,style:const TextStyle(color:Color(0xFFAFA6BA),fontSize:9,height:1.5))),
  ]));
}

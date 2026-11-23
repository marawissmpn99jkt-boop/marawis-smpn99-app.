import 'dart:async';
import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HauntedEventHub extends StatefulWidget {
  const HauntedEventHub({super.key, required this.playerName});
  final String playerName;
  @override State<HauntedEventHub> createState()=>_HauntedEventHubState();
}
class _HauntedEventHubState extends State<HauntedEventHub>{
  int xp=0; final Set<String> done={}; String? game; bool loading=true; int tab=0;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{final p=await SharedPreferences.getInstance();if(!mounted)return;setState(() { xp = p.getInt('haunted_xp_v1') ?? 0; done.addAll(p.getStringList('haunted_done_v1') ?? []); loading = false; });}
  Future<void> _win(String id,int points)async{if(done.contains(id))return;final p=await SharedPreferences.getInstance();if(!mounted)return;setState(() { done.add(id); xp += points; });await p.setInt('haunted_xp_v1',xp);await p.setStringList('haunted_done_v1',done.toList());}
  @override Widget build(BuildContext context){
    if(game!=null)return _ArcadeGame(id:game!,back:()=>setState(()=>game=null),win:(v)=>_win(game!,v));
    final level=(xp~/100)+1;
    final progress=(xp%100)/100;
    return Scaffold(
      backgroundColor:const Color(0xFF090812),
      appBar:AppBar(backgroundColor:const Color(0xFF100E1B),foregroundColor:Colors.white,elevation:0,
        title:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('MARAWIS EVENT WORLD',style:TextStyle(fontSize:12,fontWeight:FontWeight.w900,letterSpacing:1.3)),
          SizedBox(height:2),Text('HAUNTED NIGHT • SEASON 01',style:TextStyle(fontSize:8,color:Color(0xFFB4A8C9),letterSpacing:1.1,fontWeight:FontWeight.w700)),
        ]),
        actions:[Padding(padding:const EdgeInsets.only(right:14),child:Center(child:Text('🎃  $xp XP',style:const TextStyle(color:Color(0xFFFFC17C),fontWeight:FontWeight.w900))))]),
      body:loading?const Center(child:CircularProgressIndicator()):SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(16,12,16,30),children:[
        _EventHero(name:widget.playerName,xp:xp,level:level,progress:progress),
        const SizedBox(height:14),
        Row(children:[
          Expanded(child:_Stat('EVENT XP',xp.toString(),Icons.bolt_rounded)),const SizedBox(width:9),
          Expanded(child:_Stat('MISSIONS',done.length.toString()+'/4',Icons.flag_rounded)),const SizedBox(width:9),
          Expanded(child:_Stat('RANK','LV. $level',Icons.military_tech_rounded)),
        ]),
        const SizedBox(height:20),
        Container(padding:const EdgeInsets.all(5),decoration:BoxDecoration(color:const Color(0xFF171323),borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xFF352943))),
          child:Row(children:[
            _EventTab(label:'OVERVIEW',selected:tab==0,onTap:()=>setState(()=>tab=0)),
            _EventTab(label:'MISSIONS',selected:tab==1,onTap:()=>setState(()=>tab=1)),
            _EventTab(label:'COLLECTION',selected:tab==2,onTap:()=>setState(()=>tab=2)),
          ])),
        const SizedBox(height:18),
        if(tab==0)...[
          const _EventSectionTitle(eyebrow:'WELCOME TO THE OTHER SIDE',title:'Choose your adventure',subtitle:'Empat tantangan event menunggumu. Selesaikan misi untuk mengumpulkan XP dan membuka koleksi.'),
          const SizedBox(height:14),
          _Tile('01','Pumpkin Hunt','Temukan 6 labu target sebelum waktu habis.',Icons.search,Color(0xFFFFA34F),done.contains('pumpkin'),()=>setState(()=>game='pumpkin')),
          _Tile('02','Haunted Quiz','Jawab lima pertanyaan tentang Marawis.',Icons.quiz,Color(0xFFB78AFF),done.contains('quiz'),()=>setState(()=>game='quiz')),
          _Tile('03','Memory Maze','Cocokkan empat pasang simbol misterius.',Icons.grid_view,Color(0xFF68D9C0),done.contains('memory'),()=>setState(()=>game='memory')),
          _Tile('04','Secret Word','Pecahkan susunan huruf rahasia.',Icons.spellcheck,Color(0xFFFF8297),done.contains('word'),()=>setState(()=>game='word')),
          const SizedBox(height:6),const _EventNotice(text:'Progress event tersimpan di perangkat ini. Setiap game hanya memberi reward XP satu kali pada perangkat yang sama.'),
        ],
        if(tab==1)...[
          const _EventSectionTitle(eyebrow:'LIMITED EVENT TASKS',title:'Mission board',subtitle:'Selesaikan semua tantangan untuk menuntaskan Haunted Night.'),
          const SizedBox(height:14),
          _MissionRow(title:'The Pumpkin Trail',detail:'Selesaikan Pumpkin Hunt',reward:'+100 XP',complete:done.contains('pumpkin'),icon:Icons.search),
          _MissionRow(title:'Knowledge After Dark',detail:'Raih minimal 3 jawaban benar di Haunted Quiz',reward:'+100 XP',complete:done.contains('quiz'),icon:Icons.quiz),
          _MissionRow(title:'Memory Keeper',detail:'Temukan seluruh empat pasang simbol',reward:'+120 XP',complete:done.contains('memory'),icon:Icons.grid_view),
          _MissionRow(title:'The Hidden Message',detail:'Pecahkan Secret Word',reward:'+100 XP',complete:done.contains('word'),icon:Icons.key),
          const SizedBox(height:12),const _EventNotice(text:'Misi tersimpan lokal di perangkat ini. Belum ada sinkronisasi skor atau leaderboard antar-akun.'),
        ],
        if(tab==2)...[
          const _EventSectionTitle(eyebrow:'YOUR EVENT INVENTORY',title:'Night collection',subtitle:'Koleksi terbuka saat tantangan terkait berhasil diselesaikan.'),
          const SizedBox(height:14),
          _CollectionItem(icon:'🎃',title:'Pumpkin Seeker',detail:'Menemukan seluruh target labu',unlocked:done.contains('pumpkin')),
          _CollectionItem(icon:'📜',title:'Night Scholar',detail:'Menuntaskan Haunted Quiz',unlocked:done.contains('quiz')),
          _CollectionItem(icon:'🧩',title:'Memory Keeper',detail:'Menyelesaikan Memory Maze',unlocked:done.contains('memory')),
          _CollectionItem(icon:'🗝️',title:'Secret Finder',detail:'Menemukan kata rahasia',unlocked:done.contains('word')),
          const SizedBox(height:12),const _EventNotice(text:'Koleksi ini adalah pencapaian event di perangkatmu, bukan item yang bisa ditukar atau dipindahtangankan.'),
        ],
      ])),
    );
  }
}
class _Stat extends StatelessWidget{const _Stat(this.a,this.b,this.i);final String a,b;final IconData i;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:const Color(0xFF201C2D),borderRadius:BorderRadius.circular(15)),child:Row(children:[Icon(i,color:const Color(0xFFFFB66E)),const SizedBox(width:8),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:const TextStyle(color:Color(0xFFAAA1B8),fontSize:8,fontWeight:FontWeight.w900)),Text(b,style:const TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w900))]) ]));}
class _Tile extends StatelessWidget{const _Tile(this.n,this.t,this.d,this.i,this.c,this.done,this.tap);final String n,t,d;final IconData i;final Color c;final bool done;final VoidCallback tap;@override Widget build(BuildContext x)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Material(color:const Color(0xFF201C2D),borderRadius:BorderRadius.circular(17),child:InkWell(onTap:tap,borderRadius:BorderRadius.circular(17),child:Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(borderRadius:BorderRadius.circular(17),border:Border.all(color:done?const Color(0xFF68D9C0):const Color(0xFF44364F))),child:Row(children:[Icon(i,color:c,size:27),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(n+' • '+(done?'COMPLETED':'ARCADE GAME'),style:TextStyle(color:done?const Color(0xFF68D9C0):c,fontSize:8,fontWeight:FontWeight.w900)),Text(t,style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w900)),Text(d,style:const TextStyle(color:Color(0xFFB5AEC2),fontSize:10))])),Icon(done?Icons.check_circle:Icons.arrow_forward,color:c)])))));
}
class _ArcadeGame extends StatefulWidget{const _ArcadeGame({required this.id,required this.back,required this.win});final String id;final VoidCallback back;final ValueChanged<int> win;@override State<_ArcadeGame> createState()=>_ArcadeGameState();}
class _ArcadeGameState extends State<_ArcadeGame>{
  static const qs=[('Alat penjaga ketukan dasar marawis?',['Hajir','Mikrofon','Kabel','Stand banner'],0),('Sikap terbaik saat tampil?',['Menonjol sendiri','Saling mendengarkan','Abaikan aba-aba','Bermain sendiri'],1),('Sebelum tampil perlu…',['Tidak latihan','Menyamakan tempo','Terlambat','Ubah lagu'],1),('Marawis mengajarkan…',['Egoisme','Kerja sama','Tidak disiplin','Perselisihan'],1),('Saat teman salah tempo…',['Mengejek','Membantu','Pergi','Marah'],1)];
  final rng=math.Random(),word=TextEditingController();final symbols=['🎃','🦇','👻','🕸️','🎃','🦇','👻','🕸️'];final open=<int>{},matched=<int>{};Timer? timer;int sec=25,found=0,target=0,q=0,score=0,moves=0;bool started=false,ended=false,locked=false,wordWon=false;
  @override void initState(){super.initState();target=rng.nextInt(9);}
  @override void dispose(){timer?.cancel();word.dispose();super.dispose();}
  void start(){timer?.cancel();setState(() { started = true; ended = false; sec = 25; found = 0; target = rng.nextInt(9); });timer=Timer.periodic(const Duration(seconds:1),(t){if(!mounted){t.cancel();return;}if(sec<=1){t.cancel();setState(() { sec = 0; ended = true; });}else{setState(()=>sec--);}});}
  void hunt(int i){if(!started||ended)return;if(i==target){if(found==5){timer?.cancel();setState(() { found = 6; ended = true; });widget.win(100);}else{setState(() { found++; target = rng.nextInt(9); });}}else{setState(()=>sec=math.max(0,sec-2).toInt());if(sec==0){timer?.cancel();setState(()=>ended=true);}}}
  void answer(int i){final ok=qs[q].$3==i;setState(() { if (ok) score++; q++; });if(q==qs.length&&score>=3)widget.win(100);}
  Future<void> mem(int i)async{if(locked||matched.contains(i)||open.contains(i))return;setState(()=>open.add(i));if(open.length==2){moves++;final p=open.toList();if(symbols[p[0]]==symbols[p[1]]){setState(() { matched.addAll(p); open.clear(); });if(matched.length==8)widget.win(120);}else{locked=true;await Future.delayed(const Duration(milliseconds:650));if(!mounted)return;setState(() { open.clear(); locked = false; });}}}
  @override Widget build(BuildContext c)=>Scaffold(backgroundColor:const Color(0xFF0B0B16),appBar:AppBar(backgroundColor:const Color(0xFF171523),foregroundColor:Colors.white,leading:IconButton(onPressed:widget.back,icon:const Icon(Icons.arrow_back)),title:Text(widget.id.toUpperCase(),style:const TextStyle(fontSize:13,fontWeight:FontWeight.w900))),body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:560),child:SingleChildScrollView(padding:const EdgeInsets.all(18),child:Container(width:double.infinity,padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:const Color(0xFF201C2D),borderRadius:BorderRadius.circular(20)),child:body())))));
  Widget body(){
    if(widget.id=='pumpkin')return Column(children:[const Text('FIND THE GLOWING PUMPKIN',style:TextStyle(color:Color(0xFFFFB66E),fontWeight:FontWeight.w900)),Text(started?'Ditemukan $found/6 • $sec detik':'Temukan 6 target dalam 25 detik.',style:const TextStyle(color:Colors.white)),if(!started||ended)...[Text(found==6?'NIGHT CLEARED! +100 XP':(ended?'Waktu habis!':'Siap berburu?'),style:const TextStyle(color:Color(0xFFFFC17C))),FilledButton(onPressed:start,child:const Text('Mulai / Ulangi'))]else GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:3,children:List.generate(9,(i)=>InkWell(onTap:()=>hunt(i),child:Container(margin:const EdgeInsets.all(4),decoration:BoxDecoration(color:i==target?const Color(0xFF694326):const Color(0xFF302A3B),borderRadius:BorderRadius.circular(12)),child:Center(child:Text(i==target?'✨🎃':'🎃',style:const TextStyle(fontSize:27)))))))]);
    if(widget.id=='quiz')return q>=5?Column(children:[const Text('QUIZ COMPLETE',style:TextStyle(color:Color(0xFFFFB66E))),Text('Skor: $score / 5',style:const TextStyle(color:Colors.white,fontSize:25)),Text(score>=3?'Bonus XP didapat!':'Minimal 3 jawaban benar untuk bonus XP.',style:const TextStyle(color:Colors.white70)),TextButton(onPressed:widget.back,child:const Text('Kembali'))]):Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text('PERTANYAAN '+(q+1).toString()+'/5',style:const TextStyle(color:Color(0xFFFFB66E))),const SizedBox(height:12),Text(qs[q].$1,style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w800)),for(var i=0;i<4;i++)Padding(padding:const EdgeInsets.only(top:8),child:OutlinedButton(onPressed:()=>answer(i),style:OutlinedButton.styleFrom(foregroundColor:Colors.white,alignment:Alignment.centerLeft),child:Text(qs[q].$2[i])))]);
    if(widget.id=='memory')return Column(children:[const Text('MATCH ALL FOUR PAIRS',style:TextStyle(color:Color(0xFFFFB66E))),Text('Langkah: $moves',style:const TextStyle(color:Colors.white70)),GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:4,children:List.generate(8,(i)=>InkWell(onTap:()=>mem(i),child:Container(margin:const EdgeInsets.all(4),decoration:BoxDecoration(color:matched.contains(i)?const Color(0xFF25463F):const Color(0xFF302A3B),borderRadius:BorderRadius.circular(12)),child:Center(child:Text(matched.contains(i)||open.contains(i)?symbols[i]:'?',style:const TextStyle(color:Colors.white,fontSize:25))))))),if(matched.length==8)const Text('MEMORY MASTER! +120 XP',style:TextStyle(color:Color(0xFF68D9C0)))]);
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const Text('SECRET WORD',style:TextStyle(color:Color(0xFFFFB66E))),const Text('Petunjuk: seni musik islami yang menjadi identitas ekstrakurikuler kita.',style:TextStyle(color:Colors.white)),const SizedBox(height:12),const Text('A • R • M • I • S • A • W',textAlign:TextAlign.center,style:TextStyle(color:Color(0xFFFFB66E),fontSize:20)),TextField(controller:word,enabled:!wordWon,style:const TextStyle(color:Colors.white)),if(wordWon)const Text('BENAR! +100 XP',style:TextStyle(color:Color(0xFF68D9C0))),FilledButton(onPressed:wordWon?null:(){if(word.text.trim().toUpperCase().replaceAll(' ','')=='MARAWIS'){setState(()=>wordWon=true);widget.win(100);}else{ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Belum tepat. Coba lagi!')));}},child:const Text('Periksa jawaban'))]);
  }
}


class _EventHero extends StatelessWidget {
  const _EventHero({required this.name,required this.xp,required this.level,required this.progress});
  final String name; final int xp,level; final double progress;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(
    borderRadius:BorderRadius.circular(25),gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF4B285E),Color(0xFF21172F),Color(0xFF111A29)]),
    border:Border.all(color:const Color(0xFF81578B)),boxShadow:const [BoxShadow(color:Color(0x442B153D),blurRadius:26,offset:Offset(0,12))]),
    child:Stack(children:[
      Positioned(right:-8,top:-12,child:Icon(Icons.nightlight_round,size:112,color:Colors.white.withValues(alpha:.06))),
      Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:const Color(0x33FFB66E),borderRadius:BorderRadius.circular(30),border:Border.all(color:const Color(0x66FFB66E))),child:const Text('✦  LIMITED-TIME EVENT  •  NOV 2026',style:TextStyle(color:Color(0xFFFFC17C),fontSize:8,fontWeight:FontWeight.w900,letterSpacing:1))),
        const SizedBox(height:18),const Text('ENTER THE\nHAUNTED WORLD',style:TextStyle(color:Colors.white,fontSize:29,height:1.02,fontWeight:FontWeight.w900,letterSpacing:-.7)),
        const SizedBox(height:9),Text('Welcome back, $name',style:const TextStyle(color:Color(0xFFE8DDF2),fontSize:13,fontWeight:FontWeight.w700)),
        const SizedBox(height:18),Row(children:[Text('NIGHT PASS  •  LEVEL $level',style:const TextStyle(color:Color(0xFFFFC17C),fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1)),const Spacer(),Text('$xp XP',style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w900))]),
        const SizedBox(height:8),ClipRRect(borderRadius:BorderRadius.circular(20),child:LinearProgressIndicator(value:progress,minHeight:8,backgroundColor:const Color(0xFF4B4059),valueColor:const AlwaysStoppedAnimation(Color(0xFFFFA34F)))),
        const SizedBox(height:6),Text('${(progress*100).round()}% menuju level ${level+1}',style:const TextStyle(color:Color(0xFFBDB1CB),fontSize:9)),
      ]),
    ]));
}
class _EventTab extends StatelessWidget {
  const _EventTab({required this.label,required this.selected,required this.onTap});
  final String label; final bool selected; final VoidCallback onTap;
  @override Widget build(BuildContext context)=>Expanded(child:Material(color:selected?const Color(0xFF57356A):Colors.transparent,borderRadius:BorderRadius.circular(12),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(12),child:Padding(padding:const EdgeInsets.symmetric(vertical:12,horizontal:4),child:Text(label,textAlign:TextAlign.center,style:TextStyle(color:selected?Colors.white:const Color(0xFF9E93B0),fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.6))))));
}
class _EventSectionTitle extends StatelessWidget {
  const _EventSectionTitle({required this.eyebrow,required this.title,required this.subtitle});
  final String eyebrow,title,subtitle;
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(eyebrow,style:const TextStyle(color:Color(0xFFFFB66E),fontSize:9,letterSpacing:1.6,fontWeight:FontWeight.w900)),
    const SizedBox(height:7),Text(title,style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900,letterSpacing:-.4)),
    const SizedBox(height:6),Text(subtitle,style:const TextStyle(color:Color(0xFFAFA5BD),fontSize:11,height:1.5)),
  ]);
}
class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.title,required this.detail,required this.reward,required this.complete,required this.icon});
  final String title,detail,reward; final bool complete; final IconData icon;
  @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:const Color(0xFF1A1725),borderRadius:BorderRadius.circular(17),border:Border.all(color:complete?const Color(0xFF477B68):const Color(0xFF382E45))),child:Row(children:[
    Container(width:42,height:42,decoration:BoxDecoration(color:const Color(0x22B78AFF),borderRadius:BorderRadius.circular(13)),child:Icon(icon,color:const Color(0xFFB78AFF))),
    const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w900)),const SizedBox(height:4),
      Text(detail,style:const TextStyle(color:Color(0xFFAAA1B8),fontSize:10,height:1.4)),const SizedBox(height:6),
      Text(reward,style:const TextStyle(color:Color(0xFFFFB66E),fontSize:9,fontWeight:FontWeight.w900)),
    ])),Icon(complete?Icons.check_circle:Icons.radio_button_unchecked,color:complete?const Color(0xFF68D9C0):const Color(0xFF70677D)),
  ]));
}
class _CollectionItem extends StatelessWidget {
  const _CollectionItem({required this.icon,required this.title,required this.detail,required this.unlocked});
  final String icon,title,detail; final bool unlocked;
  @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:const Color(0xFF1A1725),borderRadius:BorderRadius.circular(17),border:Border.all(color:unlocked?const Color(0xFF6C5A7D):const Color(0xFF332B40))),child:Row(children:[
    Container(width:48,height:48,decoration:BoxDecoration(color:unlocked?const Color(0x22FFB66E):const Color(0xFF252130),borderRadius:BorderRadius.circular(14)),child:Center(child:Text(unlocked?icon:'🔒',style:const TextStyle(fontSize:24)))),
    const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:TextStyle(color:unlocked?Colors.white:const Color(0xFF8F879B),fontSize:13,fontWeight:FontWeight.w900)),const SizedBox(height:4),
      Text(detail,style:const TextStyle(color:Color(0xFFAAA1B8),fontSize:10)),
    ])),Text(unlocked?'UNLOCKED':'LOCKED',style:TextStyle(color:unlocked?const Color(0xFF68D9C0):const Color(0xFF82798E),fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.6)),
  ]));
}
class _EventNotice extends StatelessWidget {
  const _EventNotice({required this.text}); final String text;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:const Color(0xFF171523),borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xFF342A42))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Icon(Icons.info_outline_rounded,color:Color(0xFFFFB66E),size:17),const SizedBox(width:9),Expanded(child:Text(text,style:const TextStyle(color:Color(0xFFAFA6BA),fontSize:9,height:1.5))),
  ]));
}

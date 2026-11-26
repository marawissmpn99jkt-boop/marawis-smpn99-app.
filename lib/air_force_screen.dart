import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AirForceScreen extends StatefulWidget {
  const AirForceScreen({super.key});
  @override
  State<AirForceScreen> createState() => _AirForceScreenState();
}

class _AirForceScreenState extends State<AirForceScreen> {
  final db = Supabase.instance.client;
  Map<String,dynamic>? profile;
  List<String> owned = [];
  bool loading = true, busy = false, playing = false;
  int seconds = 25, score = 0;
  Timer? timer;
  static const planes = <Map<String,dynamic>>[
    {'id':'f86','name':'F-86 Sabre','tier':1,'level':1,'price':0,'gen':'Gen 1'},
    {'id':'mig15','name':'MiG-15','tier':1,'level':1,'price':350,'gen':'Gen 1'},
    {'id':'mig21','name':'MiG-21','tier':2,'level':3,'price':1000,'gen':'Gen 2'},
    {'id':'f5','name':'F-5 Tiger II','tier':2,'level':3,'price':1200,'gen':'Gen 2'},
    {'id':'f4','name':'F-4 Phantom II','tier':3,'level':5,'price':2600,'gen':'Gen 3'},
    {'id':'mig23','name':'MiG-23','tier':3,'level':5,'price':3000,'gen':'Gen 3'},
    {'id':'f16','name':'F-16 Fighting Falcon','tier':4,'level':8,'price':6500,'gen':'Gen 4'},
    {'id':'f15','name':'F-15 Eagle','tier':4,'level':8,'price':7200,'gen':'Gen 4'},
    {'id':'su27','name':'Su-27','tier':4,'level':9,'price':7600,'gen':'Gen 4'},
    {'id':'rafale','name':'Dassault Rafale','tier':5,'level':12,'price':14000,'gen':'Gen 4.5'},
    {'id':'typhoon','name':'Eurofighter Typhoon','tier':5,'level':12,'price':15000,'gen':'Gen 4.5'},
    {'id':'f22','name':'F-22 Raptor','tier':6,'level':16,'price':28000,'gen':'Gen 5'},
    {'id':'f35','name':'F-35 Lightning II','tier':6,'level':16,'price':30000,'gen':'Gen 5'},
  ];
  @override void initState(){super.initState();load();}
  @override void dispose(){timer?.cancel();super.dispose();}
  int get ap=>(profile?['ap'] as num?)?.toInt()??0;
  int get ac=>(profile?['ac'] as num?)?.toInt()??0;
  int get level=>(profile?['level'] as num?)?.toInt()??1;
  String get selected=>profile?['selected_aircraft']?.toString()??'f86';
  void note(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
  Future<void> load() async {
    try{
      await db.rpc('air_force_initialize');
      final p=await db.from('air_force_profiles').select().eq('user_id',db.auth.currentUser!.id).single();
      final rows=await db.from('air_force_owned_aircraft').select('aircraft_id').eq('user_id',db.auth.currentUser!.id);
      if(mounted)setState(() { profile=Map<String,dynamic>.from(p); owned=rows.map<String>((e)=>e['aircraft_id'].toString()).toList(); loading=false; });
    }catch(e){if(mounted)setState(()=>loading=false);note('Air Force belum siap: '+e.toString());}
  }
  Future<void> convert() async {
    final ctl=TextEditingController(text:'100');
    final amount=await showDialog<int>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Konversi AP ke AC'),content:TextField(controller:ctl,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Jumlah AP (kelipatan 10)')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Batal')),FilledButton(onPressed:()=>Navigator.pop(ctx,int.tryParse(ctl.text)),child:const Text('Konversi'))]));
    ctl.dispose();if(amount==null)return;
    try{await db.rpc('air_force_convert_ap',params:{'p_amount':amount});await load();note('Konversi berhasil: '+(amount~/10).toString()+' AC.');}catch(e){note('Konversi gagal: '+e.toString());}
  }
  Future<void> buy(Map<String,dynamic> p) async {
    if(busy)return;setState(()=>busy=true);
    try{await db.rpc('air_force_buy_aircraft',params:{'p_aircraft_id':p['id']});await load();note(p['name'].toString()+' berhasil dibeli!');}
    catch(e){note('Pembelian gagal: '+e.toString());}
    if(mounted)setState(()=>busy=false);
  }
  Future<void> selectPlane(String id) async {
    try{await db.rpc('air_force_select_aircraft',params:{'p_aircraft_id':id});await load();}
    catch(e){note('Gagal memilih pesawat: '+e.toString());}
  }
  void startMatch(){
    if(playing||busy)return;
    setState(() { playing=true; seconds=25; score=0; });
    timer=Timer.periodic(const Duration(seconds:1),(t){if(!mounted){t.cancel();return;}if(seconds<=1){t.cancel();finishMatch();}else{setState(()=>seconds--);}});
  }
  Future<void> finishMatch() async {
    if(!mounted)return;setState(() { playing=false; busy=true; });
    try{await db.rpc('air_force_finish_match',params:{'p_score':score});await load();note('Sky Run selesai! +75 AP.');}
    catch(e){note('Hasil gagal disimpan: '+e.toString());}
    if(mounted)setState(()=>busy=false);
  }
  @override Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator());
    if(profile==null)return Center(child:FilledButton(onPressed:load,child:const Text('Coba lagi')));
    final current=planes.firstWhere((p)=>p['id']==selected,orElse:()=>planes.first);
    return Container(color:const Color(0xFF081525),child:ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:const LinearGradient(colors:[Color(0xFF102E4D),Color(0xFF176B78)])),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Row(children:[Icon(Icons.flight_takeoff,color:Color(0xFF80E8E0)),SizedBox(width:8),Text('MARAWIS AIR FORCE',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,letterSpacing:1.3))]),
        const SizedBox(height:8),const Text('YOUR SKY. YOUR SQUADRON.',style:TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),
        const Text('Koleksi pesawat, naik level, dan tantangan udara arcade.',style:TextStyle(color:Colors.white70)),
        const SizedBox(height:16),Row(children:[stat('LEVEL',level.toString()),stat('AIR POINTS',ap.toString()),stat('AIR CREDITS',ac.toString())]),
      ])),
      const SizedBox(height:12),OutlinedButton.icon(onPressed:busy?null:convert,icon:const Icon(Icons.currency_exchange),label:const Text('Tukar AP menjadi AC • 10 AP = 1 AC')),
      section('FLIGHT CHALLENGE','Sky Run: ketuk target energi fiktif selama 25 detik.'),
      Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:const Color(0xFF13263A),borderRadius:BorderRadius.circular(18)),child:Column(children:[
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(playing?'WAKTU 00:'+seconds.toString().padLeft(2,'0'):'25 SECOND SKY RUN',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),Text('SCORE '+score.toString(),style:const TextStyle(color:Color(0xFF80E8E0),fontWeight:FontWeight.w900))]),
        const SizedBox(height:12),
        if(playing)Wrap(alignment:WrapAlignment.center,spacing:12,runSpacing:12,children:List.generate(9,(i)=>InkWell(onTap:()=>setState(()=>score+=10),borderRadius:BorderRadius.circular(40),child:Container(width:60,height:60,decoration:BoxDecoration(shape:BoxShape.circle,color:const Color(0xFF1B6574),border:Border.all(color:const Color(0xFF80E8E0),width:2)),child:const Icon(Icons.brightness_7,color:Color(0xFFFFD166),size:30)))))
        else const Text('Selesaikan tantangan untuk mendapatkan AP. Pertarungan menggunakan efek arcade fiktif, bukan simulasi senjata nyata.',style:TextStyle(color:Colors.white70)),
        const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:busy?null:(playing?(){timer?.cancel();finishMatch();}:startMatch),icon:Icon(playing?Icons.flag:Icons.play_arrow),label:Text(playing?'SELESAIKAN':'MULAI SKY RUN'))),
      ])),
      section('ACTIVE AIRCRAFT','Pesawat yang sedang digunakan.'),planeCard(current,active:true),
      section('AIRCRAFT HANGAR','Bebas membeli selama syarat level dan AC terpenuhi.'),
      for(final p in planes)planeCard(p),
    ]));
  }
  Widget stat(String label,String value)=>Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:Colors.white60,fontSize:9,fontWeight:FontWeight.w800)),Text(value,style:const TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.w900))]));
  Widget section(String title,String sub)=>Padding(padding:const EdgeInsets.only(top:20,bottom:9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,letterSpacing:1)),Text(sub,style:const TextStyle(color:Colors.white60,fontSize:12))]));
  Widget planeCard(Map<String,dynamic> p,{bool active=false}){
    final isOwned=owned.contains(p['id']);final reqLevel=p['level'] as int;final price=p['price'] as int;
    return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:active?const Color(0xFF174A55):const Color(0xFF13263A),borderRadius:BorderRadius.circular(15),border:Border.all(color:active?const Color(0xFF80E8E0):const Color(0xFF29465D))),child:Row(children:[
      Container(width:48,height:48,decoration:BoxDecoration(color:const Color(0xFF203D55),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.flight,color:Color(0xFF80E8E0),size:28)),
      const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(p['name'].toString(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),
        Text('TIER '+p['tier'].toString()+' • '+p['gen'].toString(),style:const TextStyle(color:Color(0xFF80E8E0),fontSize:10,fontWeight:FontWeight.w800)),
        Text('Level '+reqLevel.toString()+' • '+price.toString()+' AC',style:const TextStyle(color:Colors.white70,fontSize:11)),
      ])),
      if(active)const Icon(Icons.check_circle,color:Color(0xFF80E8E0))
      else if(isOwned)TextButton(onPressed:()=>selectPlane(p['id'].toString()),child:const Text('PILIH'))
      else FilledButton(onPressed:busy||level<reqLevel||ac<price?null:()=>buy(p),child:const Text('BELI')),
    ]));
  }
}

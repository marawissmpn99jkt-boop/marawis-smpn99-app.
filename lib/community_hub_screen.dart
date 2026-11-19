import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityHubScreen extends StatefulWidget {
  const CommunityHubScreen({super.key, required this.role});
  final String role;
  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen> with SingleTickerProviderStateMixin {
  final db = Supabase.instance.client;
  late final TabController tabs;
  bool get admin => widget.role == 'pengurus' || widget.role == 'pembina';
  @override void initState(){super.initState();tabs=TabController(length:3,vsync:this);}
  @override void dispose(){tabs.dispose();super.dispose();}
  void msg(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}

  Future<void> addSuggestion() async {
    final ctl=TextEditingController(); bool anon=false;
    await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(
      title:const Text('Kotak Saran'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:ctl,minLines:3,maxLines:6,maxLength:2000,decoration:const InputDecoration(labelText:'Saran atau kritik')),
        CheckboxListTile(value:anon,onChanged:(v)=>setD(()=>anon=v??false),title:const Text('Kirim anonim'),contentPadding:EdgeInsets.zero),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Batal')),FilledButton(onPressed:()async{
        if(ctl.text.trim().length<5){msg('Saran minimal 5 karakter.');return;}
        try{await db.from('member_suggestions').insert({'user_id':db.auth.currentUser!.id,'message':ctl.text.trim(),'is_anonymous':anon});if(ctx.mounted)Navigator.pop(ctx);msg('Saran berhasil dikirim.');setState((){});}catch(e){msg('Gagal mengirim: '+e.toString());}
      },child:const Text('Kirim'))],
    )));
    ctl.dispose();
  }

  Future<void> createQuiz() async {
    final title=TextEditingController(),desc=TextEditingController(),question=TextEditingController();
    final options=List.generate(4,(_)=>TextEditingController());
    final qs=<Map<String,dynamic>>[]; int correct=0,duration=10; bool publish=true;
    await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(
      title:const Text('Buat Quiz'),
      content:SizedBox(width:480,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'Judul Quiz')),
        TextField(controller:desc,decoration:const InputDecoration(labelText:'Deskripsi')),
        DropdownButtonFormField<int>(value:duration,decoration:const InputDecoration(labelText:'Batas waktu'),items:[5,10,15,20,30,45,60,90,120].map((v)=>DropdownMenuItem(value:v,child:Text('$v menit'))).toList(),onChanged:(v)=>setD(()=>duration=v??10)),
        SwitchListTile(value:publish,onChanged:(v)=>setD(()=>publish=v),title:const Text('Langsung publikasikan')),
        const Divider(),
        Text('Pertanyaan '+(qs.length+1).toString(),style:const TextStyle(fontWeight:FontWeight.w800)),
        TextField(controller:question,maxLines:2,decoration:const InputDecoration(labelText:'Pertanyaan')),
        for(var i=0;i<4;i++)TextField(controller:options[i],decoration:InputDecoration(labelText:'Pilihan '+String.fromCharCode(65+i))),
        DropdownButtonFormField<int>(value:correct,decoration:const InputDecoration(labelText:'Jawaban benar'),items:List.generate(4,(i)=>DropdownMenuItem(value:i,child:Text('Pilihan '+String.fromCharCode(65+i)))),onChanged:(v)=>setD(()=>correct=v??0)),
        OutlinedButton.icon(onPressed:(){if(question.text.trim().isEmpty||options.any((e)=>e.text.trim().isEmpty)){msg('Lengkapi pertanyaan dan empat pilihan.');return;}qs.add({'question_text':question.text.trim(),'options':options.map((e)=>e.text.trim()).toList(),'correct_index':correct,'sort_order':qs.length});question.clear();for(final e in options){e.clear();}setD(()=>correct=0);},icon:const Icon(Icons.add),label:Text('Tambah pertanyaan ('+qs.length.toString()+')')),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Batal')),FilledButton(onPressed:()async{
        if(title.text.trim().length<3||qs.isEmpty){msg('Isi judul dan minimal satu pertanyaan.');return;}
        try{
          final q=await db.from('marawis_quizzes').insert({'title':title.text.trim(),'description':desc.text.trim(),'duration_minutes':duration,'published':publish,'created_by':db.auth.currentUser!.id}).select('id').single();
          for(final item in qs){final row=await db.from('marawis_quiz_questions').insert({'quiz_id':q['id'],'question_text':item['question_text'],'options':item['options'],'sort_order':item['sort_order']}).select('id').single();await db.from('marawis_quiz_answers').insert({'question_id':row['id'],'correct_index':item['correct_index']});}
          if(ctx.mounted)Navigator.pop(ctx);msg('Quiz berhasil dibuat.');setState((){});
        }catch(e){msg('Gagal membuat Quiz: '+e.toString());}
      },child:const Text('Simpan Quiz'))],
    )));
    title.dispose();desc.dispose();question.dispose();for(final e in options){e.dispose();}
  }

  Future<void> takeQuiz(Map<String,dynamic> quiz) async {
    try{
      final prior=await db.from('marawis_quiz_attempts').select('id').eq('quiz_id',quiz['id']).eq('user_id',db.auth.currentUser!.id).maybeSingle();
      if(prior!=null){msg('Kamu sudah mengerjakan Quiz ini.');return;}
      final qs=List<Map<String,dynamic>>.from(await db.from('marawis_quiz_questions').select('id,question_text,options,sort_order').eq('quiz_id',quiz['id']).order('sort_order'));
      if(qs.isEmpty){msg('Quiz belum memiliki soal.');return;}
      final chosen=List<int?>.filled(qs.length,null);
      int index=0;
      final answers=await showDialog<List<int?>>(context:context,barrierDismissible:false,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(
        title:Text(quiz['title'].toString()),
        content:SizedBox(width:500,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Batas waktu: '+quiz['duration_minutes'].toString()+' menit'),
          Text('Soal '+(index+1).toString()+' dari '+qs.length.toString()),
          const SizedBox(height:12),
          Text(qs[index]['question_text'].toString(),style:const TextStyle(fontWeight:FontWeight.w800)),
          for(var i=0;i<4;i++)RadioListTile<int>(dense:true,value:i,groupValue:chosen[index],title:Text((qs[index]['options'] as List)[i].toString()),onChanged:(v)=>setD(()=>chosen[index]=v)),
        ])),
        actions:[
          if(index>0)TextButton(onPressed:()=>setD(()=>index--),child:const Text('Sebelumnya')),
          if(index<qs.length-1)FilledButton(onPressed:()=>setD(()=>index++),child:const Text('Berikutnya')),
          if(index==qs.length-1)FilledButton(onPressed:()=>Navigator.pop(ctx,chosen),child:const Text('Kirim jawaban')),
        ],
      )));
      if(answers==null)return;
      final keys=await db.from('marawis_quiz_answers').select('question_id,correct_index').inFilter('question_id',qs.map((e)=>e['id']).toList());
      final keyMap={for(final k in keys)k['question_id'].toString():(k['correct_index'] as num).toInt()};
      var score=0;for(var i=0;i<qs.length;i++){if(answers[i]!=null&&answers[i]==keyMap[qs[i]['id'].toString()])score++;}
      final percent=(score*100/qs.length).round();
      await db.from('marawis_quiz_attempts').insert({'quiz_id':quiz['id'],'user_id':db.auth.currentUser!.id,'answers':answers,'score':percent,'total_questions':qs.length});
      msg('Nilai Quiz: '+percent.toString()+'/100 ('+score.toString()+'/'+qs.length.toString()+')');setState((){});
    }catch(e){msg('Quiz gagal dibuka/dikirim: '+e.toString());}
  }

  Future<void> updateSuggestion(Map<String,dynamic> item)async{
    final reply=TextEditingController(text:item['admin_reply']?.toString()??'');String status=(item['status']??'baru').toString();
    await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(title:const Text('Tindak lanjut saran'),content:Column(mainAxisSize:MainAxisSize.min,children:[Text(item['message'].toString()),DropdownButtonFormField<String>(value:status,items:const [DropdownMenuItem(value:'baru',child:Text('Baru')),DropdownMenuItem(value:'diproses',child:Text('Diproses')),DropdownMenuItem(value:'selesai',child:Text('Selesai'))],onChanged:(v)=>setD(()=>status=v??'baru')),TextField(controller:reply,maxLines:3,decoration:const InputDecoration(labelText:'Tanggapan'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Batal')),FilledButton(onPressed:()async{try{await db.from('member_suggestions').update({'status':status,'admin_reply':reply.text.trim()}).eq('id',item['id']);if(ctx.mounted)Navigator.pop(ctx);setState((){});msg('Saran diperbarui.');}catch(e){msg(e.toString());}},child:const Text('Simpan'))]})));
    reply.dispose();
  }

  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Komunitas Marawis'),bottom:TabBar(controller:tabs,isScrollable:true,tabs:const [Tab(icon:Icon(Icons.lightbulb_outline),text:'Kotak Saran'),Tab(icon:Icon(Icons.quiz_outlined),text:'Quiz'),Tab(icon:Icon(Icons.sports_esports_outlined),text:'Game')])),body:TabBarView(controller:tabs,children:[suggestions(),quizzes(),games()]));

  Widget suggestions()=>Column(children:[
    Padding(padding:const EdgeInsets.all(14),child:Row(children:[const Expanded(child:Text('Sampaikan ide dan masukan untuk Marawis.')),FilledButton.icon(onPressed:addSuggestion,icon:const Icon(Icons.send),label:const Text('Kirim'))])),
    Expanded(child:FutureBuilder<List<Map<String,dynamic>>>(future:db.from('member_suggestions').select().order('created_at',ascending:false).then((v)=>List<Map<String,dynamic>>.from(v)),builder:(c,s){if(s.hasError)return Center(child:TextButton(onPressed:()=>setState((){}),child:const Text('Gagal memuat. Coba lagi')));if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.isEmpty)return const Center(child:Text('Belum ada saran.'));return ListView.builder(itemCount:s.data!.length,itemBuilder:(c,i){final x=s.data![i];return Card(color:Colors.white,child:ListTile(title:Text(x['is_anonymous']==true?'Anonim':'Saran anggota'),subtitle:Text(x['message'].toString()+'\nStatus: '+x['status'].toString()+(x['admin_reply']==null?'':'\nTanggapan: '+x['admin_reply'].toString())),isThreeLine:true,trailing:admin?IconButton(icon:const Icon(Icons.edit),onPressed:()=>updateSuggestion(x)):null));});}))
  ]);

  Widget quizzes()=>Column(children:[
    if(admin)Padding(padding:const EdgeInsets.all(14),child:SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:createQuiz,icon:const Icon(Icons.add),label:const Text('Buat Quiz')))),
    Expanded(child:FutureBuilder<List<Map<String,dynamic>>>(future:db.from('marawis_quizzes').select('id,title,description,duration_minutes,published,created_at').order('created_at',ascending:false).then((v)=>List<Map<String,dynamic>>.from(v)),builder:(c,s){if(s.hasError)return Center(child:TextButton(onPressed:()=>setState((){}),child:const Text('Gagal memuat Quiz')));if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.isEmpty)return const Center(child:Text('Belum ada Quiz.'));return ListView.builder(itemCount:s.data!.length,itemBuilder:(c,i){final q=s.data![i];return Card(color:Colors.white,child:ListTile(leading:const Icon(Icons.quiz,color:Color(0xFF167D68)),title:Text(q['title'].toString(),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(q['duration_minutes'].toString()+' menit • '+(q['published']==true?'Dipublikasikan':'Draft')+'\n'+(q['description']??'Quiz Marawis').toString()),isThreeLine:true,onTap:q['published']==true?()=>takeQuiz(q):null,trailing:admin?PopupMenuButton<String>(onSelected:(v)async{if(v=='publish')await db.from('marawis_quizzes').update({'published':true}).eq('id',q['id']);if(v=='delete')await db.from('marawis_quizzes').delete().eq('id',q['id']);setState((){});},itemBuilder:(_)=>[const PopupMenuItem(value:'publish',child:Text('Publikasikan')),const PopupMenuItem(value:'delete',child:Text('Hapus'))]):null));});}))
  ]);

  Widget games()=>_Games(db:db);
}

class _Games extends StatefulWidget{const _Games({required this.db});final SupabaseClient db;@override State<_Games> createState()=>_GamesState();}
class _GamesState extends State<_Games>{
 final qs=<Map<String,dynamic>>[
 {'q':'Alat musik yang mengatur ketukan/tempo dalam permainan marawis?','a':['Hajir','Darbuka','Keprak','Rebana'],'c':1},
 {'q':'Apa manfaat latihan rutin?','a':['Menjaga kekompakan','Mempercepat pulang','Mengurangi anggota','Menghindari tampil'],'c':0},
 {'q':'Sikap penting saat bermain kelompok?','a':['Bermain sendiri','Saling mendengarkan','Mendahului semua','Mengabaikan aba-aba'],'c':1},
 {'q':'Sebelum tampil, kelompok sebaiknya...','a':['Tidak latihan','Menyamakan tempo dan formasi','Mengubah lagu mendadak','Datang terlambat'],'c':1}];
 int index=0,score=0;bool done=false;
 Future<void> answer(int v)async{if(v==qs[index]['c'])score+=25;if(index<qs.length-1){setState(()=>index++);}else{setState(()=>done=true);try{await widget.db.from('marawis_game_scores').insert({'user_id':widget.db.auth.currentUser!.id,'game_key':'pengetahuan-marawis','score':score});}catch(_){}}}
 @override Widget build(BuildContext context)=>Center(child:SingleChildScrollView(padding:const EdgeInsets.all(18),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:520),child:Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(20),child:done?Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.emoji_events,size:55,color:Color(0xFFC58B2A)),const Text('Permainan selesai!',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),Text('Skor: '+score.toString()+'/100'),FilledButton(onPressed:()=>setState((){index=0;score=0;done=false;}),child:const Text('Main lagi'))]):Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Tantangan Pengetahuan Marawis',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),LinearProgressIndicator(value:(index+1)/qs.length),const SizedBox(height:15),Text('Soal '+(index+1).toString()+' dari '+qs.length.toString()),Text(qs[index]['q'].toString(),style:const TextStyle(fontWeight:FontWeight.w800)),for(var i=0;i<4;i++)SizedBox(width:double.infinity,child:Padding(padding:const EdgeInsets.only(top:7),child:OutlinedButton(onPressed:()=>answer(i),child:Text((qs[index]['a'] as List)[i].toString()))))]))))));
 }
}

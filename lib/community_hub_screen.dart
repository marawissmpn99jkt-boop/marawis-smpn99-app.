import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
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
    final sampleAnswer=TextEditingController(), rubric=TextEditingController();
    final qs=<Map<String,dynamic>>[]; int correct=0,duration=10,points=1; String questionType='mcq'; bool publish=true;
    await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(
      title:const Text('Buat Quiz'),
      content:SizedBox(width:480,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'Judul Quiz')),
        TextField(controller:desc,decoration:const InputDecoration(labelText:'Deskripsi')),
        DropdownButtonFormField<int>(value:duration,decoration:const InputDecoration(labelText:'Batas waktu'),items:[5,10,15,20,30,45,60,90,120].map((v)=>DropdownMenuItem(value:v,child:Text('$v menit'))).toList(),onChanged:(v)=>setD(()=>duration=v??10)),
        SwitchListTile(value:publish,onChanged:(v)=>setD(()=>publish=v),title:const Text('Langsung publikasikan')),
        const Divider(),
        OutlinedButton.icon(
          onPressed: () async {
            try {
              final file = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt'], withData: true);
              if (file == null || file.files.single.bytes == null) return;
              final raw = utf8.decode(file.files.single.bytes!);
              final rows = const CsvToListConverter(shouldParseNumbers: false).convert(raw);
              var count = 0;
              for (final row in rows) {
                final cells = row.map((e) => e.toString().trim()).toList();
                if (cells.isEmpty) continue;
                if (['pertanyaan','question','jenis'].contains(cells[0].toLowerCase())) continue;
                final extended = cells.length >= 10;
                final type = extended ? cells[0].toLowerCase() : 'mcq';
                if (type == 'essay' || type == 'esai') {
                  if (cells[1].isEmpty) continue;
                  qs.add({'question_text':cells[1],'question_type':'essay','options':<String>[],
                    'sample_answer':cells[7],'rubric':cells[8],
                    'points':(int.tryParse(cells[9])??5).clamp(1,100),'sort_order':qs.length});
                  count++;
                } else {
                  final offset = extended ? 1 : 0;
                  if (cells.length < offset + 6) continue;
                  final text = cells[offset], choices = cells.sublist(offset+1,offset+5);
                  final key = cells[offset+5].toUpperCase().replaceAll('PILIHAN ','').trim();
                  final answer = key.length==1 ? key.codeUnitAt(0)-65 : int.tryParse(key)??-1;
                  if(text.isEmpty||choices.any((e)=>e.isEmpty)||answer<0||answer>3)continue;
                  qs.add({'question_text':text,'question_type':'mcq','options':choices,'correct_index':answer,
                    'points':extended?(int.tryParse(cells[9])??1).clamp(1,100):1,'sort_order':qs.length});
                  count++;
                }
              }
              setD(() {});
              msg(count > 0 ? '$count soal berhasil diimpor.' : 'Tidak ada soal valid. Periksa format CSV.');
            } catch (e) { msg('Gagal membaca file: $e'); }
          },
          icon: const Icon(Icons.upload_file),
          label: const Text('Impor soal dari CSV'),
        ),
        const Text('Format CSV: Jenis,Pertanyaan,Pilihan A,Pilihan B,Pilihan C,Pilihan D,Kunci,Jawaban Acuan,Rubrik,Bobot. Jenis MCQ atau ESSAY. Format CSV lama 6 kolom tetap didukung.', style: TextStyle(fontSize: 11)),
        const SizedBox(height: 8),
        Text('Pertanyaan '+(qs.length+1).toString(),style:const TextStyle(fontWeight:FontWeight.w800)),
        DropdownButtonFormField<String>(value:questionType,decoration:const InputDecoration(labelText:'Jenis soal'),items:const [DropdownMenuItem(value:'mcq',child:Text('Pilihan ganda')),DropdownMenuItem(value:'essay',child:Text('Esai'))],onChanged:(v)=>setD(()=>questionType=v??'mcq')),
        TextField(controller:question,maxLines:2,decoration:const InputDecoration(labelText:'Pertanyaan')),
        if(questionType=='mcq')...[
          for(var i=0;i<4;i++)TextField(controller:options[i],decoration:InputDecoration(labelText:'Pilihan '+String.fromCharCode(65+i))),
          DropdownButtonFormField<int>(value:correct,decoration:const InputDecoration(labelText:'Jawaban benar'),items:List.generate(4,(i)=>DropdownMenuItem(value:i,child:Text('Pilihan '+String.fromCharCode(65+i)))),onChanged:(v)=>setD(()=>correct=v??0)),
        ] else ...[
          TextField(controller:sampleAnswer,maxLines:2,decoration:const InputDecoration(labelText:'Jawaban acuan (opsional)')),
          TextField(controller:rubric,maxLines:2,decoration:const InputDecoration(labelText:'Rubrik penilaian')),
        ],
        DropdownButtonFormField<int>(value:points,decoration:const InputDecoration(labelText:'Bobot nilai'),items:[1,2,3,5,10,15,20].map((v)=>DropdownMenuItem(value:v,child:Text('$v poin'))).toList(),onChanged:(v)=>setD(()=>points=v??1)),
        OutlinedButton.icon(onPressed:(){
          if(question.text.trim().isEmpty){msg('Tulis pertanyaan terlebih dahulu.');return;}
          if(questionType=='mcq'&&options.any((e)=>e.text.trim().isEmpty)){msg('Lengkapi empat pilihan jawaban.');return;}
          qs.add({'question_text':question.text.trim(),'question_type':questionType,
            'options':questionType=='mcq'?options.map((e)=>e.text.trim()).toList():<String>[],
            'correct_index':correct,'sample_answer':sampleAnswer.text.trim(),'rubric':rubric.text.trim(),
            'points':points,'sort_order':qs.length});
          question.clear();sampleAnswer.clear();rubric.clear();for(final e in options){e.clear();}
          setD((){correct=0;points=1;});
        },icon:const Icon(Icons.add),label:Text('Tambah soal ('+qs.length.toString()+')')),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Batal')),FilledButton(onPressed:()async{
        if(title.text.trim().length<3||qs.isEmpty){msg('Isi judul dan minimal satu pertanyaan.');return;}
        try{
          final q=await db.from('marawis_quizzes').insert({'title':title.text.trim(),'description':desc.text.trim(),'duration_minutes':duration,'published':publish,'created_by':db.auth.currentUser!.id}).select('id').single();
          for(final item in qs){
            final row=await db.from('marawis_quiz_questions').insert({
              'quiz_id':q['id'],'question_text':item['question_text'],'question_type':item['question_type']??'mcq',
              'options':item['options'],'sort_order':item['sort_order'],'points':item['points']??1,
              'sample_answer':item['sample_answer'],'rubric':item['rubric']
            }).select('id').single();
            if((item['question_type']??'mcq')=='mcq'){
              await db.from('marawis_quiz_answers').insert({'question_id':row['id'],'correct_index':item['correct_index']});
            }
          }
          if(ctx.mounted)Navigator.pop(ctx);msg('Quiz berhasil dibuat.');setState((){});
        }catch(e){msg('Gagal membuat Quiz: '+e.toString());}
      },child:const Text('Simpan Quiz'))],
    )));
    title.dispose();desc.dispose();question.dispose();sampleAnswer.dispose();rubric.dispose();for(final e in options){e.dispose();}
  }

  Future<void> takeQuiz(Map<String,dynamic> quiz) async {
    try {
      final prior=await db.from('marawis_quiz_attempts').select('id').eq('quiz_id',quiz['id']).eq('user_id',db.auth.currentUser!.id).maybeSingle();
      if(prior!=null){msg('Kamu sudah mengerjakan Quiz ini.');return;}
      final qs=List<Map<String,dynamic>>.from(await db.from('marawis_quiz_questions').select('id,question_text,options,sort_order,question_type,points,sample_answer,rubric').eq('quiz_id',quiz['id']).order('sort_order'));
      if(qs.isEmpty){msg('Quiz belum memiliki soal.');return;}
      final result=await showDialog<Map<String,dynamic>>(context:context,barrierDismissible:false,builder:(ctx)=>_QuizExamDialog(title:quiz['title'].toString(),questions:qs,duration:(quiz['duration_minutes'] as num).toInt()));
      if(result==null)return;
      final answers=result['answers'] as List<dynamic>;
      final response=await db.rpc('submit_marawis_quiz',params:{'p_quiz_id':quiz['id'],'p_answers':answers});
      final row=(response as List).first;
      final percent=(row['score'] as num).toInt();
      final score=(percent*qs.length/100).round();
      msg((result['review_pending']==true?'Pilihan ganda: ':'Nilai: ')+percent.toString()+'/100'+(result['review_pending']==true?' • Esai menunggu koreksi Pengurus/Pembina.':' ('+score.toString()+'/'+qs.length.toString()+')')+' • Pelanggaran: '+result['violations'].toString());
      setState((){});
    }catch(e){msg('Quiz gagal dibuka/dikirim: '+e.toString());}
  }

  Future<void> reviewEssays(Map<String,dynamic> quiz) async {
    try {
      final questions=List<Map<String,dynamic>>.from(await db.from('marawis_quiz_questions').select('id,question_text,question_type,points,sample_answer,rubric,sort_order').eq('quiz_id',quiz['id']).order('sort_order'));
      final essays=questions.where((q)=>q['question_type']=='essay').toList();
      if(essays.isEmpty){msg('Quiz ini belum memiliki soal esai.');return;}
      final attempts=List<Map<String,dynamic>>.from(await db.from('marawis_quiz_attempts').select('id,user_id,answers,score,review_status').eq('quiz_id',quiz['id']).eq('review_status','pending'));
      if(attempts.isEmpty){msg('Tidak ada jawaban esai yang menunggu koreksi.');return;}
      for(final attempt in attempts){
        final answers=List<dynamic>.from(attempt['answers'] as List);
        final essayControllers=<TextEditingController>[];
        final essayTexts=<String>[];
        for(var i=0;i<questions.length;i++){if(questions[i]['question_type']=='essay'){final saved=i<answers.length?answers[i]:null;essayTexts.add(saved is Map?saved['essay']?.toString()??'':'');essayControllers.add(TextEditingController());}}
        final awarded=await showDialog<List<int>>(context:context,barrierDismissible:false,builder:(ctx)=>AlertDialog(
          title:Text('Koreksi esai • '+quiz['title'].toString()),
          content:SizedBox(width:560,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
            for(var i=0;i<essays.length;i++)... [
              Text('Esai '+(i+1).toString()+' • Maks. '+(essays[i]['points']??1).toString()+' poin',style:const TextStyle(fontWeight:FontWeight.bold)),
              Text(essays[i]['question_text'].toString()),
              Container(width:double.infinity,padding:const EdgeInsets.all(10),margin:const EdgeInsets.symmetric(vertical:8),decoration:BoxDecoration(color:Colors.black.withOpacity(.05),borderRadius:BorderRadius.circular(8)),child:Text(essayTexts[i].isEmpty?'Tidak dijawab':essayTexts[i])),
              if((essays[i]['sample_answer']??'').toString().isNotEmpty)Text('Jawaban acuan: '+essays[i]['sample_answer'].toString()),
              if((essays[i]['rubric']??'').toString().isNotEmpty)Text('Rubrik: '+essays[i]['rubric'].toString()),
              TextField(controller:essayControllers[i],keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'Nilai 0 sampai '+(essays[i]['points']??1).toString())),
              const Divider(),
            ]
          ]))),
          actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Nanti')),FilledButton(onPressed:(){
            final values=<int>[];
            for(var i=0;i<essayControllers.length;i++){final n=int.tryParse(essayControllers[i].text.trim());final max=(essays[i]['points'] as num?)?.toInt()??1;if(n==null||n<0||n>max){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Nilai esai '+(i+1).toString()+' harus 0 sampai '+max.toString())));return;}values.add(n);}
            Navigator.pop(ctx,values);
          },child:const Text('Simpan nilai'))],
        ));
        if(awarded!=null){
          var totalPoints=0.0,objectivePoints=0.0,essayMax=0.0,essayEarned=0.0;var essayIndex=0;
          for(final q in questions){final pts=(q['points'] as num?)?.toDouble()??1;totalPoints+=pts;if(q['question_type']=='essay'){essayMax+=pts;essayEarned+=awarded[essayIndex++];}else{objectivePoints+=pts;}}
          final autoPct=(attempt['score'] as num?)?.toDouble()??0;
          final finalScore=totalPoints==0?0:(((autoPct/100*objectivePoints)+essayEarned)/totalPoints*100).round();
          final manualPct=essayMax==0?0:(essayEarned/essayMax*100).round();
          await db.from('marawis_quiz_attempts').update({'manual_score':manualPct,'final_score':finalScore,'review_status':'reviewed','reviewed_by':db.auth.currentUser!.id,'reviewed_at':DateTime.now().toUtc().toIso8601String()}).eq('id',attempt['id']);
        }
        for(final ctrl in essayControllers){ctrl.dispose();}
      }
      msg('Koreksi esai selesai disimpan.');if(mounted)setState((){});
    }catch(e){msg('Gagal memuat koreksi esai: '+e.toString());}
  }
  Future<void> updateSuggestion(Map<String,dynamic> item) async {
    final reply = TextEditingController(text: item['admin_reply']?.toString() ?? '');
    String status = (item['status'] ?? 'baru').toString();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Tindak lanjut saran'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item['message'].toString()),
              DropdownButtonFormField<String>(
                value: status,
                items: const [
                  DropdownMenuItem(value: 'baru', child: Text('Baru')),
                  DropdownMenuItem(value: 'diproses', child: Text('Diproses')),
                  DropdownMenuItem(value: 'selesai', child: Text('Selesai')),
                ],
                onChanged: (v) => setD(() => status = v ?? 'baru'),
              ),
              TextField(
                controller: reply,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Tanggapan'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await db.from('member_suggestions').update({
                    'status': status,
                    'admin_reply': reply.text.trim(),
                  }).eq('id', item['id']);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!mounted) return;
                  setState(() {});
                  msg('Saran diperbarui.');
                } catch (e) {
                  msg(e.toString());
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    reply.dispose();
  }

  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Komunitas Marawis'),bottom:TabBar(controller:tabs,isScrollable:true,tabs:const [Tab(icon:Icon(Icons.lightbulb_outline),text:'Kotak Saran'),Tab(icon:Icon(Icons.quiz_outlined),text:'Quiz'),Tab(icon:Icon(Icons.sports_esports_outlined),text:'Game')])),body:TabBarView(controller:tabs,children:[suggestions(),quizzes(),games()]));

  Widget suggestions()=>Column(children:[
    Padding(padding:const EdgeInsets.all(14),child:Row(children:[const Expanded(child:Text('Sampaikan ide dan masukan untuk Marawis.')),FilledButton.icon(onPressed:addSuggestion,icon:const Icon(Icons.send),label:const Text('Kirim'))])),
    Expanded(child:FutureBuilder<List<Map<String,dynamic>>>(future:db.from('member_suggestions').select().order('created_at',ascending:false).then((v)=>List<Map<String,dynamic>>.from(v)),builder:(c,s){if(s.hasError)return Center(child:TextButton(onPressed:()=>setState((){}),child:const Text('Gagal memuat. Coba lagi')));if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.isEmpty)return const Center(child:Text('Belum ada saran.'));return ListView.builder(itemCount:s.data!.length,itemBuilder:(c,i){final x=s.data![i];return Card(color:Colors.white,child:ListTile(title:Text(x['is_anonymous']==true?'Anonim':'Saran anggota'),subtitle:Text(x['message'].toString()+'\nStatus: '+x['status'].toString()+(x['admin_reply']==null?'':'\nTanggapan: '+x['admin_reply'].toString())),isThreeLine:true,trailing:admin?IconButton(icon:const Icon(Icons.edit),onPressed:()=>updateSuggestion(x)):null));});}))
  ]);

  Widget quizzes()=>Column(children:[
    if(admin)Padding(padding:const EdgeInsets.all(14),child:SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:createQuiz,icon:const Icon(Icons.add),label:const Text('Buat Quiz')))),
    Expanded(child:FutureBuilder<List<Map<String,dynamic>>>(future:db.from('marawis_quizzes').select('id,title,description,duration_minutes,published,created_at').order('created_at',ascending:false).then((v)=>List<Map<String,dynamic>>.from(v)),builder:(c,s){if(s.hasError)return Center(child:TextButton(onPressed:()=>setState((){}),child:const Text('Gagal memuat Quiz')));if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.isEmpty)return const Center(child:Text('Belum ada Quiz.'));return ListView.builder(itemCount:s.data!.length,itemBuilder:(c,i){final q=s.data![i];return Card(color:Colors.white,child:ListTile(leading:const Icon(Icons.quiz,color:Color(0xFF167D68)),title:Text(q['title'].toString(),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(q['duration_minutes'].toString()+' menit • '+(q['published']==true?'Dipublikasikan':'Draft')+'\n'+(q['description']??'Quiz Marawis').toString()),isThreeLine:true,onTap:q['published']==true?()=>takeQuiz(q):null,trailing:admin?PopupMenuButton<String>(onSelected:(v)async{if(v=='publish')await db.from('marawis_quizzes').update({'published':true}).eq('id',q['id']);if(v=='review')await reviewEssays(q);if(v=='delete')await db.from('marawis_quizzes').delete().eq('id',q['id']);setState((){});},itemBuilder:(_)=>[const PopupMenuItem(value:'publish',child:Text('Publikasikan')),const PopupMenuItem(value:'review',child:Text('Koreksi esai')),const PopupMenuItem(value:'delete',child:Text('Hapus'))]):null));});}))
  ]);

  Widget games()=>_Games(db:db);
}

class _QuizExamDialog extends StatefulWidget {
  const _QuizExamDialog({required this.title,required this.questions,required this.duration});
  final String title;
  final List<Map<String,dynamic>> questions;
  final int duration;
  @override State<_QuizExamDialog> createState()=>_QuizExamDialogState();
}

class _QuizExamDialogState extends State<_QuizExamDialog> {
  late final List<int?> answers;
  late final List<TextEditingController> essayControllers;
  late int seconds;
  int index=0,violations=0;
  bool sending=false,warning=false;
  Timer? clock;
  StreamSubscription<html.Event>? visibility;
  @override void initState(){
    super.initState();
    answers=List<int?>.filled(widget.questions.length,null);
    essayControllers=List.generate(widget.questions.length,(_)=>TextEditingController());
    seconds=widget.duration*60;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try { await html.document.documentElement?.requestFullscreen(); } catch (_) {}
      try { await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); } catch (_) {}
    });
    clock=Timer.periodic(const Duration(seconds:1),(t){
      if(!mounted||sending)return;
      if(seconds<=1){_submit(true);}else{setState(()=>seconds--);}
    });
    visibility=html.document.onVisibilityChange.listen((_){
      if(html.document.visibilityState=='hidden')_violation();
    });
  }
  void _violation(){
    if(!mounted||sending||warning)return;
    violations++;warning=true;
    showDialog<void>(context:context,barrierDismissible:false,builder:(ctx)=>AlertDialog(
      title:const Text('Peringatan ujian'),
      content:Text('Kamu terdeteksi berpindah tab/aplikasi. Pelanggaran: '+violations.toString()+'/3. Tetap fokus pada Quiz.'),
      actions:[FilledButton(onPressed:(){Navigator.pop(ctx);warning=false;if(violations>=3)_submit(true);},child:const Text('Kembali ke Quiz'))],
    ));
  }
  Future<void> _submit(bool automatic) async {
    if(sending||!mounted)return;
    sending=true;clock?.cancel();
    try{if(html.document.fullscreenElement!=null)html.document.exitFullscreen();}catch(_){}
    try{await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);}catch(_){}
    if(mounted)Navigator.of(context).pop({'answers':List.generate(widget.questions.length,(i)=>widget.questions[i]['question_type']=='essay'?{'type':'essay','essay':essayControllers[i].text.trim()}:{'type':'mcq','choice':answers[i]}),'violations':violations,'automatic':automatic,'review_pending':widget.questions.any((q)=>q['question_type']=='essay')});
  }
  @override void dispose(){clock?.cancel();visibility?.cancel();for(final ctrl in essayControllers){ctrl.dispose();}try{if(html.document.fullscreenElement!=null)html.document.exitFullscreen();}catch(_){}\n    try{SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);}catch(_){}\n    super.dispose();}
  String get time => (seconds~/60).toString().padLeft(2,'0')+':'+(seconds%60).toString().padLeft(2,'0');
  @override Widget build(BuildContext context){
    final q=widget.questions[index];
    final opts=List<String>.from(q['options'] as List);
    return PopScope(canPop:false,child:Dialog.fullscreen(backgroundColor:const Color(0xFFF4F7F6),child:SafeArea(child:Column(children:[
      Container(color:const Color(0xFF123C35),padding:const EdgeInsets.all(16),child:Row(children:[
        const Icon(Icons.shield_outlined,color:Colors.white),const SizedBox(width:10),
        Expanded(child:Text(widget.title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))),
        Text(time,style:TextStyle(color:seconds<60?Colors.orangeAccent:Colors.white,fontSize:20,fontWeight:FontWeight.w900))
      ])),
      LinearProgressIndicator(value:(index+1)/widget.questions.length,minHeight:5),
      Expanded(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:760),child:ListView(padding:const EdgeInsets.all(22),children:[
        Row(children:[Chip(label:Text('SOAL '+(index+1).toString()+' / '+widget.questions.length.toString())),const Spacer(),Text('Pelanggaran: '+violations.toString(),style:const TextStyle(color:Colors.deepOrange))]),
        const SizedBox(height:18),
        Text(q['question_text'].toString(),style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800)),
        const SizedBox(height:16),
        if(q['question_type']=='essay') TextField(controller:essayControllers[index],minLines:5,maxLines:10,maxLength:5000,decoration:const InputDecoration(border:OutlineInputBorder(),hintText:'Tulis jawaban esai di sini...',alignLabelWithHint:true)) else for(var i=0;i<opts.length;i++)Card(color:answers[index]==i?const Color(0xFFDCEFE9):Colors.white,child:RadioListTile<int>(value:i,groupValue:answers[index],onChanged:(v)=>setState(()=>answers[index]=v),title:Text(String.fromCharCode(65+i)+'. '+opts[i])),),
        const Text('Tetap di halaman ujian. Perpindahan tab/aplikasi dapat tercatat sebagai pelanggaran.',style:TextStyle(color:Colors.black54,fontSize:12))
      ])))),
      Container(color:Colors.white,padding:const EdgeInsets.all(14),child:Row(children:[
        OutlinedButton(onPressed:index==0?null:()=>setState(()=>index--),child:const Text('Sebelumnya')),
        const Spacer(),Text(List.generate(answers.length,(i)=>widget.questions[i]['question_type']=='essay'?essayControllers[i].text.trim().isNotEmpty:answers[i]!=null).where((e)=>e).length.toString()+'/'+answers.length.toString()+' terjawab'),const Spacer(),
        FilledButton(onPressed:(){
          if(index<widget.questions.length-1){setState(()=>index++);}
          else{showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Kumpulkan Quiz?'),content:const Text('Setelah dikumpulkan, jawaban tidak dapat diubah.'),actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Periksa lagi')),
            FilledButton(onPressed:(){Navigator.pop(ctx);_submit(false);},child:const Text('Kumpulkan'))
          ]));}
        },child:Text(index==widget.questions.length-1?'Selesai':'Berikutnya'))
      ]))
    ]))));
  }
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

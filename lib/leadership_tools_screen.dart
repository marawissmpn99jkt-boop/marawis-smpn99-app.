import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LeadershipToolsScreen extends StatefulWidget {
  const LeadershipToolsScreen({super.key, required this.role});
  final String role;
  @override
  State<LeadershipToolsScreen> createState() => _LeadershipToolsScreenState();
}

class _LeadershipToolsScreenState extends State<LeadershipToolsScreen> {
  final db = Supabase.instance.client;
  bool busy = false;
  bool get staff => widget.role == 'pengurus' || widget.role == 'pembina';
  void message(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }
  Future<void> refresh() async { if (mounted) setState(() {}); }

  Future<void> form({required String title, required String table, required List<String> fields, required List<String> labels, required Map<String,dynamic> extra}) async {
    final controllers = fields.map((_) => TextEditingController()).toList();
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i=0;i<fields.length;i++) Padding(padding: const EdgeInsets.only(bottom:10), child: TextField(controller:controllers[i], maxLines: fields[i].contains('body') || fields[i].contains('agenda') || fields[i].contains('content') ? 4 : 1, decoration:InputDecoration(labelText:labels[i], border:const OutlineInputBorder()))),
      ])),
      actions: [TextButton(onPressed:()=>Navigator.pop(ctx), child:const Text('Batal')), FilledButton(onPressed:busy?null:() async {
        if (controllers.any((c)=>c.text.trim().isEmpty)) { message('Lengkapi semua kolom.'); return; }
        setState(()=>busy=true);
        try {
          final data=<String,dynamic>{...extra};
          for(var i=0;i<fields.length;i++) { data[fields[i]]=controllers[i].text.trim(); }
          data['created_by']=db.auth.currentUser!.id;
          await db.from(table).insert(data);
          if(ctx.mounted) Navigator.pop(ctx);
          message('Data berhasil disimpan.'); await refresh();
        } catch(e) { message('Gagal menyimpan: $e'); }
        finally { if(mounted)setState(()=>busy=false); }
      }, child:const Text('Simpan'))],
    ));
    for(final c in controllers) { c.dispose(); }
  }

  Future<void> editMinutes(Map<String,dynamic> meeting) async {
    final minutes=TextEditingController(text:(meeting['minutes']??'').toString());
    final decisions=TextEditingController(text:(meeting['decisions']??'').toString());
    await showDialog(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Notulensi & keputusan rapat'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:minutes,minLines:3,maxLines:6,decoration:const InputDecoration(labelText:'Catatan / notulensi')),
        const SizedBox(height:10),
        TextField(controller:decisions,minLines:2,maxLines:5,decoration:const InputDecoration(labelText:'Keputusan rapat')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Batal')),FilledButton(onPressed:() async {
        try {
          await db.from('marawis_meetings').update({'minutes':minutes.text.trim(),'decisions':decisions.text.trim(),'updated_at':DateTime.now().toUtc().toIso8601String()}).eq('id',meeting['id']);
          if(ctx.mounted)Navigator.pop(ctx); message('Notulensi berhasil disimpan.'); await refresh();
        } catch(e){message('Gagal menyimpan notulensi: $e');}
      },child:const Text('Simpan'))],
    ));
    minutes.dispose(); decisions.dispose();
  }

  Future<void> submitLetter(Map<String,dynamic> row, String status) async {
    final note=TextEditingController();
    await showDialog(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Tindak lanjuti surat'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        Text('Status: $status'),
        TextField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'Catatan / arahan (opsional)')),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Batal')),FilledButton(onPressed:() async {
        try {
          await db.from('marawis_letters').update({'status':status,'review_note':note.text.trim(),'reviewed_by':db.auth.currentUser!.id,'updated_at':DateTime.now().toUtc().toIso8601String()}).eq('id',row['id']);
          if(ctx.mounted)Navigator.pop(ctx); message('Status surat diperbarui.'); await refresh();
        } catch(e){message('Gagal memperbarui: $e');}
      },child:const Text('Simpan'))],
    ));
    note.dispose();
  }

  Widget panel(String title, String description, IconData icon, Widget child, {Widget? action}) => Card(
    color:Colors.white, margin:const EdgeInsets.only(bottom:14),
    child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[CircleAvatar(backgroundColor:const Color(0xFFE7F4EE),child:Icon(icon,color:const Color(0xFF167D68))),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)),Text(description,style:const TextStyle(color:Color(0xFF78877F),fontSize:12))])),if(action!=null)action]),
      const SizedBox(height:12),child,
    ])));

  @override Widget build(BuildContext context) => Scaffold(
    appBar:AppBar(title:const Text('Layanan Pengurus & Pembina')),
    body:RefreshIndicator(onRefresh:refresh,child:ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),gradient:const LinearGradient(colors:[Color(0xFF123F35),Color(0xFF229B7C)])),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('LEADERSHIP WORKSPACE',style:TextStyle(color:Colors.white70,fontWeight:FontWeight.w800,letterSpacing:1)),SizedBox(height:8),Text('Administrasi, rapat, dan informasi prioritas.',style:TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w900))])),
      const SizedBox(height:14),
      panel('Surat & Disposisi Digital','Ajukan surat atau tinjau permohonan.',Icons.mail_outline_rounded,
        FutureBuilder<List<Map<String,dynamic>>>(future:db.from('marawis_letters').select().order('created_at',ascending:false),builder:(c,s){
          if(s.hasError)return Text('Gagal memuat: ${s.error}');
          if(!s.hasData)return const Center(child:CircularProgressIndicator());
          final rows=s.data!;
          if(rows.isEmpty)return const Text('Belum ada pengajuan surat.');
          return Column(children:[for(final row in rows) ListTile(contentPadding:EdgeInsets.zero,title:Text(row['subject']??'',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${row['letter_type']} • ${row['status']}\n${row['content']}',maxLines:3,overflow:TextOverflow.ellipsis),trailing:staff?PopupMenuButton<String>(onSelected:(v)=>submitLetter(row,v),itemBuilder:(_)=>const [PopupMenuItem(value:'ditinjau',child:Text('Tandai ditinjau')),PopupMenuItem(value:'disetujui',child:Text('Setujui')),PopupMenuItem(value:'perlu_revisi',child:Text('Minta revisi')),PopupMenuItem(value:'ditolak',child:Text('Tolak'))]):null, isThreeLine:true)]) ;
        }),
        action:IconButton(onPressed:()=>form(title:'Ajukan surat',table:'marawis_letters',fields:['subject','letter_type','content'],labels:['Subjek surat','Jenis surat','Isi / keperluan'],extra:{'recipient_role':'pembina'}),icon:const Icon(Icons.add_circle_outline))),
      panel('Rapat Online & Notulensi','Jadwal, tautan rapat, dan hasil keputusan.',Icons.groups_2_rounded,
        FutureBuilder<List<Map<String,dynamic>>>(future:db.from('marawis_meetings').select().order('meeting_at'),builder:(c,s){
          if(s.hasError)return Text('Gagal memuat: ${s.error}');
          if(!s.hasData)return const Center(child:CircularProgressIndicator());
          final rows=s.data!; if(rows.isEmpty)return const Text('Belum ada agenda rapat.');
          return Column(children:[for(final row in rows) ListTile(contentPadding:EdgeInsets.zero,title:Text(row['title']??'',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${row['meeting_at']}\n${row['agenda']}',maxLines:3,overflow:TextOverflow.ellipsis),trailing:staff?Wrap(children:[IconButton(tooltip:'Notulensi',icon:const Icon(Icons.edit_note_rounded),onPressed:()=>editMinutes(row)),if(row['meeting_url']!=null)IconButton(icon:const Icon(Icons.video_call),onPressed:()=>launchMeeting(context,row['meeting_url'].toString()))]):(row['meeting_url']==null?null:IconButton(icon:const Icon(Icons.video_call),onPressed:()=>launchMeeting(context,row['meeting_url'].toString()))))]);
        }),
        action:staff?IconButton(onPressed:()=>form(title:'Jadwalkan rapat',table:'marawis_meetings',fields:['title','agenda','meeting_at','meeting_url'],labels:['Nama rapat','Agenda','Waktu (ISO: 2026-12-01T15:00:00+07:00)','Link Google Meet'],extra:{}),icon:const Icon(Icons.add_circle_outline)):null),
      panel('Emergency Announcement','Informasi mendesak untuk audiens terpilih.',Icons.campaign_rounded,
        FutureBuilder<List<Map<String,dynamic>>>(future:db.from('marawis_emergency_announcements').select().eq('is_active',true).order('created_at',ascending:false),builder:(c,s){
          if(s.hasError)return Text('Gagal memuat: ${s.error}');
          if(!s.hasData)return const Center(child:CircularProgressIndicator());
          final rows=s.data!; if(rows.isEmpty)return const Text('Tidak ada pengumuman darurat aktif.');
          return Column(children:[for(final row in rows) ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.priority_high,color:Colors.red),title:Text(row['title']??'',style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('${row['body']}\nAudiens: ${row['audience']}'),trailing:staff?IconButton(icon:const Icon(Icons.check_circle_outline),tooltip:'Arsipkan',onPressed:() async {await db.from('marawis_emergency_announcements').update({'is_active':false}).eq('id',row['id']);await refresh();}):null,isThreeLine:true)]);
        }),
        action:staff?IconButton(onPressed:()=>form(title:'Buat pengumuman darurat',table:'marawis_emergency_announcements',fields:['title','body','audience'],labels:['Judul prioritas','Isi pengumuman','Audiens (all / anggota / admin)'],extra:{}),icon:const Icon(Icons.add_alert_rounded)):null),
      if(!staff) const Text('Pengajuan surat tersedia untuk akun anggota. Modul rapat dan pengumuman darurat dikelola Pengurus/Pembina.',style:TextStyle(color:Color(0xFF78877F))),
    ])),
  );

  Future<void> launchMeeting(BuildContext context,String url) async {
    final uri=Uri.tryParse(url);
    if(uri==null || !['https','http'].contains(uri.scheme)) { message('Tautan rapat tidak valid.'); return; }
    final opened=await launchUrl(uri,mode:LaunchMode.externalApplication);
    if(!opened) message('Tautan rapat tidak dapat dibuka.');
  }
}

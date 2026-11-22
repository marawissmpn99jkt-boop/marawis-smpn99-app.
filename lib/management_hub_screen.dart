import 'package:material_ui/material_ui.dart';
import 'activities_screen.dart';
import 'attendance_screen.dart';
import 'members_screen.dart';
import 'work_programs_screen.dart';
import 'cash_screen.dart';
import 'leadership_tools_screen.dart';

class ManagementHubScreen extends StatelessWidget {
  const ManagementHubScreen({super.key,required this.role});
  final String role;
  @override Widget build(BuildContext context){
    final items=<({IconData icon,String title,String detail,Widget page})>[
      (icon:Icons.mail_lock_rounded,title:'Layanan Pengurus & Pembina',detail:'Surat, disposisi, rapat, notulensi & pengumuman darurat',page:LeadershipToolsScreen(role:role)),
      (icon:Icons.event_note_rounded,title:'Kalender & kegiatan',detail:'Atur latihan, rapat, dan penampilan',page:ActivitiesScreen(role:role)),
      (icon:Icons.assignment_turned_in_rounded,title:'Program kerja & tugas',detail:'Pantau progres dan penanggung jawab',page:WorkProgramsScreen(role:role)),
      (icon:Icons.groups_rounded,title:'Direktori anggota',detail:'Lihat data dan profil anggota',page:MembersScreen(role:role)),
      (icon:Icons.fact_check_rounded,title:'Absensi & evaluasi',detail:'Pantau kehadiran anggota',page:AttendanceScreen(role:role)),
      (icon:Icons.account_balance_wallet_rounded,title:'Keuangan organisasi',detail:'Pantau kas masuk dan keluar',page:CashScreen(role:role)),
    ];
    return Scaffold(appBar:AppBar(title:const Text('Pusat Pengurus & Pembina')),body:ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:const LinearGradient(colors:[Color(0xFF123F35),Color(0xFF229B7C)])),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('RUANG KERJA PENGURUS',style:TextStyle(color:Colors.white70,fontSize:11,fontWeight:FontWeight.w800,letterSpacing:1)),SizedBox(height:8),Text('Kelola kegiatan Marawis dari satu tempat.',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),SizedBox(height:6),Text('Pilih modul untuk mengatur dan memantau jalannya organisasi.',style:TextStyle(color:Colors.white70))])),
      const SizedBox(height:16),
      for(final item in items) Card(color:Colors.white,child:ListTile(leading:CircleAvatar(backgroundColor:const Color(0xFFE7F4EE),child:Icon(item.icon,color:const Color(0xFF167D68))),title:Text(item.title,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(item.detail),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>item.page)))),
    ]));
  }
}

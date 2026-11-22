import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class OrganizationInsightsScreen extends StatefulWidget {
  const OrganizationInsightsScreen({super.key});

  @override
  State<OrganizationInsightsScreen> createState() => _OrganizationInsightsScreenState();
}

class _OrganizationInsightsScreenState extends State<OrganizationInsightsScreen> {
  final _db = Supabase.instance.client;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final results = await Future.wait([
      _db.from('activities').select('id,title,starts_at').order('starts_at', ascending: false),
      _db.from('attendance').select('activity_id,status,member_id'),
      _db.from('members').select('id').eq('membership_status', 'aktif'),
      _db.from('cash_payments').select('amount,status').eq('status', 'diterima'),
      _db.from('cash_income').select('amount'),
      _db.from('cash_expenses').select('amount'),
    ]);
    final activities = List<Map<String, dynamic>>.from(results[0] as List);
    final attendance = List<Map<String, dynamic>>.from(results[1] as List);
    final members = List<Map<String, dynamic>>.from(results[2] as List);
    final payments = List<Map<String, dynamic>>.from(results[3] as List);
    final incomes = List<Map<String, dynamic>>.from(results[4] as List);
    final expenses = List<Map<String, dynamic>>.from(results[5] as List);

    int sumAmounts(List<Map<String, dynamic>> rows) =>
        rows.fold<int>(0, (sum, row) => sum + ((row['amount'] as num?)?.toInt() ?? 0));

    final statusCounts = <String, int>{'hadir': 0, 'izin': 0, 'sakit': 0, 'alpa': 0};
    final byActivity = <String, Map<String, int>>{};
    for (final row in attendance) {
      final status = row['status']?.toString() ?? 'hadir';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      final key = row['activity_id'].toString();
      final counts = byActivity.putIfAbsent(key, () => <String, int>{});
      counts[status] = (counts[status] ?? 0) + 1;
    }

    final verifiedPayments = sumAmounts(payments);
    final manualIncome = sumAmounts(incomes);
    final totalIncome = verifiedPayments + manualIncome;
    final totalExpenses = sumAmounts(expenses);
    return {
      'activities': activities,
      'members': members,
      'status_counts': statusCounts,
      'by_activity': byActivity,
      'verified_payments': verifiedPayments,
      'manual_income': manualIncome,
      'total_income': totalIncome,
      'total_expenses': totalExpenses,
      'balance': totalIncome - totalExpenses,
    };
  }

  void _refresh() => setState(() => _future = _load());

  String _rupiah(num value) {
    final raw = value.round().toString();
    return 'Rp ${raw.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';
  }

  Future<void> _exportReport(Map<String, dynamic> data) async {
    final activities = List<Map<String, dynamic>>.from(data['activities'] as List);
    final counts = Map<String, int>.from(data['status_counts'] as Map);
    final byActivity = Map<String, Map<String, int>>.from(
      (data['by_activity'] as Map).map((key, value) => MapEntry(
        key.toString(),
        Map<String, int>.from(value as Map),
      )),
    );
    final report = pw.Document();
    final generatedAt = DateTime.now();
    report.addPage(pw.MultiPage(
      pageFormat: pw.PdfPageFormat.a4,
      build: (context) => [
        pw.Header(level: 0, text: 'Laporan Organisasi Marawis SMPN 99'),
        pw.Text('Dibuat: ${generatedAt.day.toString().padLeft(2, '0')}/${generatedAt.month.toString().padLeft(2, '0')}/${generatedAt.year}'),
        pw.SizedBox(height: 16),
        pw.Header(level: 1, text: 'Ringkasan Kehadiran'),
        pw.Bullet(text: 'Jumlah anggota aktif: ${data['members'].length}'),
        pw.Bullet(text: 'Jumlah kegiatan: ${activities.length}'),
        pw.Bullet(text: 'Hadir: ${counts['hadir'] ?? 0}'),
        pw.Bullet(text: 'Izin: ${counts['izin'] ?? 0}'),
        pw.Bullet(text: 'Sakit: ${counts['sakit'] ?? 0}'),
        pw.Bullet(text: 'Alpa: ${counts['alpa'] ?? 0}'),
        pw.SizedBox(height: 8),
        pw.Header(level: 1, text: 'Rincian per Kegiatan'),
        if (activities.isEmpty) pw.Text('Belum ada kegiatan.')
        else ...activities.map((activity) {
          final activityCounts = byActivity[activity['id'].toString()] ?? {};
          final total = activityCounts.values.fold<int>(0, (sum, value) => sum + value);
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 7),
            child: pw.Text('${activity['title']} — $total catatan | Hadir ${activityCounts['hadir'] ?? 0}, Izin ${activityCounts['izin'] ?? 0}, Sakit ${activityCounts['sakit'] ?? 0}, Alpa ${activityCounts['alpa'] ?? 0}'),
          );
        }),
        pw.SizedBox(height: 14),
        pw.Header(level: 1, text: 'Analisis Keuangan'),
        pw.Bullet(text: 'Pembayaran kas terverifikasi: ${_rupiah(data['verified_payments'] as num)}'),
        pw.Bullet(text: 'Pemasukan lainnya: ${_rupiah(data['manual_income'] as num)}'),
        pw.Bullet(text: 'Total pemasukan: ${_rupiah(data['total_income'] as num)}'),
        pw.Bullet(text: 'Total pengeluaran: ${_rupiah(data['total_expenses'] as num)}'),
        pw.Bullet(text: 'Saldo bersih: ${_rupiah(data['balance'] as num)}'),
        pw.SizedBox(height: 18),
        pw.Divider(),
        pw.Text('Dokumen ini dibuat otomatis oleh sistem Marawis SMPN 99.', style: const pw.TextStyle(fontSize: 9)),
      ],
    ));
    await Printing.layoutPdf(
      onLayout: (format) async => report.save(),
      name: 'Laporan-Marawis-SMPN99-${generatedAt.year}${generatedAt.month.toString().padLeft(2, '0')}${generatedAt.day.toString().padLeft(2, '0')}.pdf',
    );
  }

  Widget _metric(String title, String value, IconData icon, Color tint) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5ECE8))),
      child: Row(children: [
        CircleAvatar(backgroundColor: tint, child: Icon(icon, color: const Color(0xFF167D68))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Color(0xFF718078), fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1B3029))),
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Statistik & Laporan', style: TextStyle(fontWeight: FontWeight.w800)),
      actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))]),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.analytics_outlined, size: 44),
            const Text('Data statistik belum dapat dimuat.'),
            TextButton(onPressed: _refresh, child: const Text('Coba lagi')),
          ]));
        }
        final data = snapshot.data!;
        final counts = Map<String, int>.from(data['status_counts'] as Map);
        final totalAttendance = counts.values.fold<int>(0, (sum, value) => sum + value);
        final activities = List<Map<String, dynamic>>.from(data['activities'] as List);
        final byActivity = Map<String, Map<String, int>>.from(
          (data['by_activity'] as Map).map((key, value) => MapEntry(key.toString(), Map<String, int>.from(value as Map))),
        );
        return ListView(padding: const EdgeInsets.all(18), children: [
          const Text('STATISTIK KEHADIRAN', style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: Color(0xFF167D68))),
          const SizedBox(height: 12),
          _metric('Anggota aktif', '${data['members'].length}', Icons.groups_rounded, const Color(0xFFE7F4EE)),
          const SizedBox(height: 10),
          _metric('Total kegiatan', '${activities.length}', Icons.event_available_rounded, const Color(0xFFEAF0FF)),
          const SizedBox(height: 10),
          _metric('Total catatan absensi', '$totalAttendance', Icons.fact_check_rounded, const Color(0xFFFFF2E3)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5ECE8))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Komposisi kehadiran', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 14),
              for (final entry in [
                ('Hadir', counts['hadir'] ?? 0, const Color(0xFF16845F)),
                ('Izin', counts['izin'] ?? 0, const Color(0xFF4B6FCB)),
                ('Sakit', counts['sakit'] ?? 0, const Color(0xFFC47A25)),
                ('Alpa', counts['alpa'] ?? 0, const Color(0xFFB84D4D)),
              ]) ...[
                Row(children: [
                  Expanded(child: Text(entry.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  Text('${entry.$2} • ${totalAttendance == 0 ? 0 : (entry.$2 * 100 / totalAttendance).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11, color: Color(0xFF718078))),
                ]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
                  value: totalAttendance == 0 ? 0 : entry.$2 / totalAttendance,
                  minHeight: 8, backgroundColor: const Color(0xFFF0F3F1),
                  valueColor: AlwaysStoppedAnimation<Color>(entry.$3),
                )),
                const SizedBox(height: 12),
              ],
            ]),
          ),
          const SizedBox(height: 22),
          const Text('ANALISIS KEUANGAN', style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: Color(0xFF167D68))),
          const SizedBox(height: 12),
          _metric('Total pemasukan', _rupiah(data['total_income'] as num), Icons.trending_up_rounded, const Color(0xFFE7F4EE)),
          const SizedBox(height: 10),
          _metric('Total pengeluaran', _rupiah(data['total_expenses'] as num), Icons.trending_down_rounded, const Color(0xFFFFEEEE)),
          const SizedBox(height: 10),
          _metric('Saldo bersih', _rupiah(data['balance'] as num), Icons.account_balance_wallet_rounded, const Color(0xFFEAF0FF)),
          const SizedBox(height: 22),
          const Text('REKAP PER KEGIATAN', style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: Color(0xFF167D68))),
          const SizedBox(height: 10),
          if (activities.isEmpty) const Text('Belum ada kegiatan.')
          else ...activities.map((activity) {
            final values = byActivity[activity['id'].toString()] ?? {};
            final total = values.values.fold<int>(0, (sum, value) => sum + value);
            return Container(
              margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5ECE8))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(activity['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text('$total catatan • Hadir ${values['hadir'] ?? 0} • Izin ${values['izin'] ?? 0} • Sakit ${values['sakit'] ?? 0} • Alpa ${values['alpa'] ?? 0}', style: const TextStyle(fontSize: 11, color: Color(0xFF718078))),
              ]),
            );
          }),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () => _exportReport(data), icon: const Icon(Icons.picture_as_pdf_rounded), label: const Text('Buat & ekspor laporan PDF')),
          const SizedBox(height: 8),
          const Text('Laporan menggunakan data absensi, anggota aktif, pembayaran kas yang sudah diterima, pemasukan manual, dan pengeluaran.', style: TextStyle(fontSize: 11, color: Color(0xFF718078), height: 1.5)),
        ]);
      },
    ),
  );
}

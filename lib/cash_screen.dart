import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CashScreen extends StatefulWidget {
  const CashScreen({super.key, required this.role});
  final String role;
  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  final db = Supabase.instance.client;
  bool busy = false;
  bool get admin => widget.role == 'pengurus' || widget.role == 'pembina';
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() { super.initState(); future = load(); }

  Future<List<Map<String, dynamic>>> load() async {
    var query = db.from('cash_payments').select('id,member_id,amount,payment_period,payment_method,status,notes,created_at');
    if (!admin) query = query.eq('member_id', db.auth.currentUser!.id);
    final rows = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  void refresh() => setState(() => future = load());
  void message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> submitPayment() async {
    final amount = TextEditingController();
    final period = TextEditingController();
    final notes = TextEditingController();
    String method = 'tunai';
    final key = GlobalKey<FormState>();
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: const Text('Catat pembayaran kas'),
      content: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal (Rp)'), validator: (v) => int.tryParse(v ?? '') == null || int.parse(v!) <= 0 ? 'Masukkan nominal yang valid.' : null),
        TextFormField(controller: period, decoration: const InputDecoration(labelText: 'Periode (contoh: November 2026)'), validator: (v) => v == null || v.trim().isEmpty ? 'Periode wajib diisi.' : null),
        DropdownButtonFormField<String>(initialValue: method, decoration: const InputDecoration(labelText: 'Metode'), items: const [
          DropdownMenuItem(value: 'tunai', child: Text('Tunai')), DropdownMenuItem(value: 'transfer', child: Text('Transfer')), DropdownMenuItem(value: 'lainnya', child: Text('Lainnya')),
        ], onChanged: (v) { if (v != null) setDialog(() => method = v); }),
        TextFormField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')), FilledButton(onPressed: busy ? null : () async {
        if (!key.currentState!.validate()) return;
        setState(() => busy = true);
        try {
          await db.from('cash_payments').insert({'member_id': db.auth.currentUser!.id, 'amount': int.parse(amount.text), 'payment_period': period.text.trim(), 'payment_method': method, 'notes': notes.text.trim().isEmpty ? null : notes.text.trim(), 'status': 'menunggu'});
          if (ctx.mounted) Navigator.pop(ctx);
          refresh(); message('Pembayaran tercatat dan menunggu verifikasi pengurus.');
        } catch (e) { message('Gagal mencatat pembayaran: $e'); }
        finally { if (mounted) setState(() => busy = false); }
      }, child: const Text('Kirim'))],
    )));
    amount.dispose(); period.dispose(); notes.dispose();
  }

  Future<void> verify(Map<String, dynamic> row, String status) async {
    try {
      await db.from('cash_payments').update({'status': status, 'verified_by': db.auth.currentUser!.id, 'verified_at': DateTime.now().toUtc().toIso8601String()}).eq('id', row['id']);
      refresh(); message(status == 'diterima' ? 'Pembayaran diterima.' : 'Pembayaran ditolak.');
    } catch (e) { message('Gagal memperbarui status: $e'); }
  }

  Future<void> addExpense() async {
    final title = TextEditingController();
    final amount = TextEditingController();
    final notes = TextEditingController();
    final key = GlobalKey<FormState>();
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Catat pengeluaran'),
      content: Form(key: key, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Keperluan'), validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi.' : null),
        TextFormField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal (Rp)'), validator: (v) => int.tryParse(v ?? '') == null || int.parse(v!) <= 0 ? 'Nominal tidak valid.' : null),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')), FilledButton(onPressed: () async {
        if (!key.currentState!.validate()) return;
        try {
          await db.from('cash_expenses').insert({'title': title.text.trim(), 'amount': int.parse(amount.text), 'notes': notes.text.trim().isEmpty ? null : notes.text.trim(), 'recorded_by': db.auth.currentUser!.id});
          if (ctx.mounted) Navigator.pop(ctx); message('Pengeluaran tersimpan.');
        } catch (e) { message('Gagal menyimpan pengeluaran: $e'); }
      }, child: const Text('Simpan'))],
    ));
    title.dispose(); amount.dispose(); notes.dispose();
  }

  String money(dynamic value) => 'Rp ${(value as num).toInt().toString().replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (m) => '.')}';
  String date(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Uang kas', style: TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))]),
    floatingActionButton: admin ? FloatingActionButton.extended(onPressed: addExpense, icon: const Icon(Icons.remove_circle_outline), label: const Text('Pengeluaran')) : FloatingActionButton.extended(onPressed: submitPayment, icon: const Icon(Icons.add), label: const Text('Catat bayar')),
    body: FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Data kas belum bisa dimuat.'), TextButton(onPressed: refresh, child: const Text('Coba lagi'))])));
      final rows = snap.data ?? [];
      final accepted = rows.where((r) => r['status'] == 'diterima').fold<int>(0, (s, r) => s + (r['amount'] as num).toInt());
      final pending = rows.where((r) => r['status'] == 'menunggu').length;
      return RefreshIndicator(onRefresh: () async => refresh(), child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFF167D68), borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(admin ? 'TOTAL PEMBAYARAN DITERIMA' : 'PEMBAYARANMU DITERIMA', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8), Text(money(accepted), style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6), Text('$pending pembayaran menunggu verifikasi', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
        const SizedBox(height: 20), const Text('Riwayat pembayaran', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 10),
        if (rows.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Belum ada catatan pembayaran.', textAlign: TextAlign.center)),
        ...rows.map((r) => Card(color: Colors.white, child: ListTile(
          leading: CircleAvatar(backgroundColor: r['status'] == 'diterima' ? const Color(0xFFE7F4EE) : const Color(0xFFFFF2E3), child: Icon(r['status'] == 'diterima' ? Icons.check : Icons.schedule, color: const Color(0xFF167D68))),
          title: Text(money(r['amount']), style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${r['payment_period']} • ${r['payment_method']} • ${date(r['created_at'])}'),
          trailing: admin && r['status'] == 'menunggu' ? PopupMenuButton<String>(onSelected: (v) => verify(r, v), itemBuilder: (_) => const [PopupMenuItem(value: 'diterima', child: Text('Terima')), PopupMenuItem(value: 'ditolak', child: Text('Tolak'))]) : Chip(label: Text(r['status'].toString())),
        ))),
      ]));
    }),
  );
}

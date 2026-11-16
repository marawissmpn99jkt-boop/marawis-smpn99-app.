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

  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<Map<String, dynamic>> load() async {
    var paymentQuery = db
        .from('cash_payments')
        .select('id,member_id,amount,payment_period,payment_method,status,notes,created_at');
    if (!admin) {
      paymentQuery = paymentQuery.eq('member_id', db.auth.currentUser!.id);
    }

    final payments = await paymentQuery.order('created_at', ascending: false);
    final expenses = admin
        ? await db
            .from('cash_expenses')
            .select('id,title,amount,expense_date,notes,created_at')
            .order('expense_date', ascending: false)
        : <Map<String, dynamic>>[];

    return {
      'payments': List<Map<String, dynamic>>.from(payments),
      'expenses': List<Map<String, dynamic>>.from(expenses),
    };
  }

  void refresh() {
    if (mounted) setState(() => future = load());
  }

  void message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  Future<void> submitPayment() async {
    final amount = TextEditingController();
    final period = TextEditingController();
    final notes = TextEditingController();
    String method = 'tunai';
    final key = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Catat pembayaran kas'),
          content: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Nominal (Rp)'),
                    validator: (value) {
                      final parsed = int.tryParse(value ?? '');
                      return parsed == null || parsed <= 0
                          ? 'Masukkan nominal yang valid.'
                          : null;
                    },
                  ),
                  TextFormField(
                    controller: period,
                    decoration: const InputDecoration(
                      labelText: 'Periode (contoh: November 2026)',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Periode wajib diisi.'
                        : null,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(labelText: 'Metode'),
                    items: const [
                      DropdownMenuItem(value: 'tunai', child: Text('Tunai')),
                      DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                      DropdownMenuItem(value: 'lainnya', child: Text('Lainnya')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialog(() => method = value);
                    },
                  ),
                  TextFormField(
                    controller: notes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!key.currentState!.validate()) return;
                      setState(() => busy = true);
                      try {
                        await db.from('cash_payments').insert({
                          'member_id': db.auth.currentUser!.id,
                          'amount': int.parse(amount.text),
                          'payment_period': period.text.trim(),
                          'payment_method': method,
                          'notes': notes.text.trim().isEmpty
                              ? null
                              : notes.text.trim(),
                          'status': 'menunggu',
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        refresh();
                        message(
                          'Pembayaran tercatat dan menunggu verifikasi pengurus.',
                        );
                      } catch (error) {
                        message('Gagal mencatat pembayaran: $error');
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: const Text('Kirim'),
            ),
          ],
        ),
      ),
    );

    amount.dispose();
    period.dispose();
    notes.dispose();
  }

  Future<void> verify(Map<String, dynamic> row, String status) async {
    try {
      await db
          .from('cash_payments')
          .update({
            'status': status,
            'verified_by': db.auth.currentUser!.id,
            'verified_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', row['id'])
          .eq('status', 'menunggu');
      refresh();
      message(status == 'diterima'
          ? 'Pembayaran diterima.'
          : 'Pembayaran ditolak.');
    } catch (error) {
      message('Gagal memperbarui status: $error');
    }
  }

  Future<void> addExpense() async {
    final title = TextEditingController();
    final amount = TextEditingController();
    final notes = TextEditingController();
    final key = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Catat pengeluaran'),
        content: Form(
          key: key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: title,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Keperluan'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Wajib diisi.'
                          : null,
                ),
                TextFormField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Nominal (Rp)'),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    return parsed == null || parsed <= 0
                        ? 'Nominal tidak valid.'
                        : null;
                  },
                ),
                TextFormField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!key.currentState!.validate()) return;
                    setState(() => busy = true);
                    try {
                      await db.from('cash_expenses').insert({
                        'title': title.text.trim(),
                        'amount': int.parse(amount.text),
                        'notes': notes.text.trim().isEmpty
                            ? null
                            : notes.text.trim(),
                        'recorded_by': db.auth.currentUser!.id,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      refresh();
                      message('Pengeluaran tersimpan.');
                    } catch (error) {
                      message('Gagal menyimpan pengeluaran: $error');
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    title.dispose();
    amount.dispose();
    notes.dispose();
  }

  String money(dynamic value) {
    final amount = (value as num?)?.toInt() ?? 0;
    return 'Rp ${amount.toString().replaceAllMapped(
      RegExp(r'(?=(\d{3})+(?!\d))'),
      (match) => '.',
    )}';
  }

  String date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return '';
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Uang kas',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: admin
            ? FloatingActionButton.extended(
                onPressed: busy ? null : addExpense,
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Pengeluaran'),
              )
            : FloatingActionButton.extended(
                onPressed: busy ? null : submitPayment,
                icon: const Icon(Icons.add),
                label: const Text('Catat bayar'),
              ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Data kas belum bisa dimuat.'),
                      TextButton(
                        onPressed: refresh,
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data ?? const <String, dynamic>{};
            final payments = data['payments'] as List<Map<String, dynamic>>? ??
                <Map<String, dynamic>>[];
            final expenses = data['expenses'] as List<Map<String, dynamic>>? ??
                <Map<String, dynamic>>[];
            final accepted = payments
                .where((row) => row['status'] == 'diterima')
                .fold<int>(
                  0,
                  (sum, row) => sum + (row['amount'] as num).toInt(),
                );
            final pending =
                payments.where((row) => row['status'] == 'menunggu').length;
            final totalExpenses = expenses.fold<int>(
              0,
              (sum, row) => sum + (row['amount'] as num).toInt(),
            );
            final balance = accepted - totalExpenses;

            return RefreshIndicator(
              onRefresh: () async => refresh(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF167D68),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          admin
                              ? 'SALDO KAS (PEMBAYARAN TERVERIFIKASI)'
                              : 'PEMBAYARANMU DITERIMA',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          money(admin ? balance : accepted),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (admin) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Pemasukan: ${money(accepted)}  •  Pengeluaran: ${money(totalExpenses)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          '$pending pembayaran menunggu verifikasi',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Riwayat pembayaran',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  if (payments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Belum ada catatan pembayaran.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ...payments.map(
                    (row) => Card(
                      color: Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: row['status'] == 'diterima'
                              ? const Color(0xFFE7F4EE)
                              : const Color(0xFFFFF2E3),
                          child: Icon(
                            row['status'] == 'diterima'
                                ? Icons.check
                                : Icons.schedule,
                            color: const Color(0xFF167D68),
                          ),
                        ),
                        title: Text(
                          money(row['amount']),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${row['payment_period']} • ${row['payment_method']} • ${date(row['created_at'])}',
                        ),
                        trailing: admin && row['status'] == 'menunggu'
                            ? PopupMenuButton<String>(
                                onSelected: (value) => verify(row, value),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'diterima',
                                    child: Text('Terima'),
                                  ),
                                  PopupMenuItem(
                                    value: 'ditolak',
                                    child: Text('Tolak'),
                                  ),
                                ],
                              )
                            : Chip(label: Text(row['status'].toString())),
                      ),
                    ),
                  ),
                  if (admin) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Riwayat pengeluaran',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (expenses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Belum ada pengeluaran kas.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ...expenses.map(
                      (expense) => Card(
                        color: Colors.white,
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFFF0ED),
                            child: Icon(
                              Icons.remove_circle_outline,
                              color: Color(0xFFB65345),
                            ),
                          ),
                          title: Text(
                            money(expense['amount']),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            '${expense['title']} • ${date(expense['expense_date'])}'
                            '${(expense['notes'] ?? '').toString().isEmpty ? '' : '\n${expense['notes']}'}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );
}

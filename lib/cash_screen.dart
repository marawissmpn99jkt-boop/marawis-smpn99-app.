import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'formatters.dart';
import 'cash_payment_rules.dart';

class CashScreen extends StatefulWidget {
  const CashScreen({super.key, required this.role});

  final String role;

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  final db = Supabase.instance.client;
  final _picker = ImagePicker();
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
        .select('id,member_id,amount,payment_period,payment_method,proof_url,status,notes,created_at');
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

    final paymentRows = List<Map<String, dynamic>>.from(payments);
    final memberRows = <Map<String, dynamic>>[];
    if (admin) {
      final rows = await db
          .from('members')
          .select('id,display_name,class_name');
      memberRows.addAll(List<Map<String, dynamic>>.from(rows));
    }
    final membersById = {
      for (final member in memberRows) member['id'].toString(): member,
    };
    final enrichedPayments = paymentRows.map((payment) {
      final member = membersById[payment['member_id'].toString()];
      return {
        ...payment,
        if (admin) 'member_name': member?['display_name'] ?? 'Anggota',
        if (admin) 'member_class': member?['class_name'],
      };
    }).toList();

    return {
      'payments': enrichedPayments,
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
    XFile? selectedProof;
    Uint8List? proofBytes;
    String? proofExtension;
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
                      if (value == null) return;
                      setDialog(() {
                        method = value;
                        if (method != 'transfer') {
                          selectedProof = null;
                          proofBytes = null;
                          proofExtension = null;
                        }
                      });
                    },
                  ),
                  if (method == 'transfer') ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                try {
                                  final image = await _picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 80,
                                    maxWidth: 1600,
                                    maxHeight: 1600,
                                  );
                                  if (image == null) return;
                                  final name = image.name.toLowerCase();
                                  final extension = name.endsWith('.png')
                                      ? 'png'
                                      : name.endsWith('.webp')
                                          ? 'webp'
                                          : name.endsWith('.jpg') ||
                                                  name.endsWith('.jpeg')
                                              ? 'jpg'
                                              : null;
                                  if (extension == null) {
                                    message('Pilih gambar JPG, PNG, atau WebP.');
                                    return;
                                  }
                                  final bytes = await image.readAsBytes();
                                  if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
                                    message('Ukuran bukti transfer harus lebih dari 0 dan maksimal 5 MB.');
                                    return;
                                  }
                                  setDialog(() {
                                    selectedProof = image;
                                    proofBytes = bytes;
                                    proofExtension = extension;
                                  });
                                } catch (error) {
                                  message('Gagal memilih bukti transfer: $error');
                                }
                              },
                        icon: const Icon(Icons.upload_file_rounded),
                        label: Text(
                          selectedProof == null
                              ? 'Pilih bukti transfer'
                              : 'Ganti bukti transfer',
                        ),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'JPG, PNG, atau WebP • Maksimal 5 MB',
                        style: TextStyle(
                          color: Color(0xFF78877F),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (proofBytes != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          proofBytes!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setDialog(() {
                          selectedProof = null;
                          proofBytes = null;
                          proofExtension = null;
                        }),
                        icon: const Icon(Icons.close_rounded, size: 17),
                        label: const Text('Hapus lampiran'),
                      ),
                    ],
                  ],
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
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!key.currentState!.validate()) return;
                      if (cashPaymentProofIsRequired(method) && proofBytes == null) {
                        message('Bukti transfer wajib dilampirkan.');
                        return;
                      }
                      setState(() => busy = true);
                      String? proofPath;
                      try {
                        final userId = db.auth.currentUser!.id;
                        if (proofBytes != null && proofExtension != null) {
                          proofPath =
                              '$userId/${DateTime.now().microsecondsSinceEpoch}.$proofExtension';
                          final contentType = proofExtension == 'png'
                              ? 'image/png'
                              : proofExtension == 'webp'
                                  ? 'image/webp'
                                  : 'image/jpeg';
                          await db.storage.from('cash-payment-proofs').uploadBinary(
                            proofPath,
                            proofBytes!,
                            fileOptions: FileOptions(
                              contentType: contentType,
                              upsert: false,
                            ),
                          );
                        }

                        if (!cashPaymentCanBeSubmitted(
                          method: method,
                          proofPath: proofPath,
                        )) {
                          throw StateError('Metode transfer membutuhkan bukti pembayaran.');
                        }

                        await db.from('cash_payments').insert({
                          'member_id': userId,
                          'amount': int.parse(amount.text),
                          'payment_period': period.text.trim(),
                          'payment_method': method,
                          'proof_url': proofPath,
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
                        if (proofPath != null) {
                          try {
                            await db.storage
                                .from('cash-payment-proofs')
                                .remove([proofPath]);
                          } catch (_) {
                            // Jangan menutupi error utama jika pembersihan gagal.
                          }
                        }
                        message('Gagal mencatat pembayaran: $error');
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kirim'),
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
      final updated = await db
          .from('cash_payments')
          .update({
            'status': status,
            'verified_by': db.auth.currentUser!.id,
            'verified_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', row['id'])
          .eq('status', 'menunggu')
          .select('id')
          .maybeSingle();
      refresh();
      message(updated == null
          ? 'Pembayaran sudah diproses sebelumnya.'
          : status == 'diterima'
              ? 'Pembayaran diterima.'
              : 'Pembayaran ditolak.');
    } catch (error) {
      message('Gagal memperbarui status: $error');
    }
  }

  Future<void> viewProof(String path) async {
    try {
      final signedUrl = await db.storage
          .from('cash-payment-proofs')
          .createSignedUrl(path, 300);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: SizedBox(
            width: 420,
            height: 520,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Bukti transfer',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: InteractiveViewer(
                    child: Image.network(
                      signedUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('Gambar bukti tidak dapat ditampilkan.'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      message('Bukti transfer tidak dapat dibuka: $error');
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
                          formatRupiah(admin ? balance : accepted),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (admin) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Pemasukan: ${formatRupiah(accepted)}  •  Pengeluaran: ${formatRupiah(totalExpenses)}',
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
                          formatRupiah(row['amount']),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          [
                            if (admin)
                              '${row['member_name'] ?? 'Anggota'} • ${(row['member_class'] ?? '').toString().isEmpty ? 'Kelas belum diisi' : row['member_class']}',
                            '${row['payment_period']} • ${row['payment_method']} • ${date(row['created_at'])}',
                            if ((row['notes'] ?? '').toString().isNotEmpty)
                              row['notes'].toString(),
                          ].join('\n'),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if ((row['proof_url'] ?? '').toString().isNotEmpty)
                              IconButton(
                                tooltip: 'Lihat bukti transfer',
                                onPressed: () => viewProof(row['proof_url'].toString()),
                                icon: const Icon(Icons.receipt_long_rounded),
                              ),
                            if (admin && row['status'] == 'menunggu')
                              PopupMenuButton<String>(
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
                            else
                              Chip(label: Text(row['status'].toString())),
                          ],
                        ),
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
                            formatRupiah(expense['amount']),
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

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'member_cards_screen.dart';

class QrCheckinScreen extends StatefulWidget {
  const QrCheckinScreen({super.key, required this.role});
  final String role;

  @override
  State<QrCheckinScreen> createState() => _QrCheckinScreenState();
}

class _QrCheckinScreenState extends State<QrCheckinScreen> {
  final _db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;
  bool get _admin => widget.role == 'pengurus' || widget.role == 'pembina';

  @override
  void initState() {
    super.initState();
    _future = _loadActivities();
  }

  Future<List<Map<String, dynamic>>> _loadActivities() async {
    if (!_admin) return [];
    final rows = await _db
        .from('activities')
        .select('id,title,starts_at,ends_at')
        .order('starts_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  void _refresh() => setState(() => _future = _loadActivities());

  String _date(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return 'Waktu belum ditentukan';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openScanner(Map<String, dynamic> activity) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _MemberQrScannerScreen(activity: activity),
      ),
    );
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_admin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Check-in Kegiatan',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F4EE),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded,
                      size: 48, color: Color(0xFF167D68)),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Tunjukkan QR kartu anggota kamu',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Saat kegiatan berlangsung, buka Kartu Identitas Digital dan tunjukkan QR pribadi kamu kepada Pengurus atau Pembina. Mereka yang akan memindai dan mencatat kehadiran.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFF718078), height: 1.55, fontSize: 13),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MemberCardsScreen(role: widget.role),
                    ),
                  ),
                  icon: const Icon(Icons.badge_rounded),
                  label: const Text('Buka kartu anggota saya'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner QR Anggota',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: _refresh,
                child: const Text('Gagal memuat kegiatan. Coba lagi.'),
              ),
            );
          }
          final activities = snapshot.data ?? [];
          if (activities.isEmpty) {
            return const Center(
                child: Text('Belum ada kegiatan. Buat jadwal terlebih dahulu.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final activity = activities[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5ECE8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activity['title'].toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 5),
                    Text(_date(activity['starts_at']),
                        style: const TextStyle(
                            color: Color(0xFF718078), fontSize: 11)),
                    const SizedBox(height: 13),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openScanner(activity),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Scan QR anggota'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MemberQrScannerScreen extends StatefulWidget {
  const _MemberQrScannerScreen({required this.activity});
  final Map<String, dynamic> activity;

  @override
  State<_MemberQrScannerScreen> createState() => _MemberQrScannerScreenState();
}

class _MemberQrScannerScreenState extends State<_MemberQrScannerScreen> {
  final _db = Supabase.instance.client;
  bool _busy = false;
  bool _finished = false;
  String _status = 'Arahkan kamera ke QR pada kartu digital anggota.';

  Future<void> _handleScan(String? raw) async {
    if (_busy || _finished || raw == null) return;

    const prefix = 'MARAWIS-MEMBER|';
    if (!raw.startsWith(prefix)) {
      setState(() => _status = 'QR tidak dikenali. Pindai QR kartu anggota Marawis.');
      return;
    }

    final cardCode = raw.substring(prefix.length).trim();
    if (cardCode.isEmpty || cardCode.contains('|')) {
      setState(() => _status = 'Kode kartu tidak valid. Coba pindai ulang.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Memeriksa kartu anggota...';
    });

    try {
      final member = await _db
          .from('members')
          .select('id,display_name,membership_status')
          .eq('card_code', cardCode)
          .maybeSingle();

      if (member == null) {
        throw Exception('Kartu anggota tidak ditemukan.');
      }
      if (member['membership_status'] != 'aktif') {
        throw Exception('Status anggota tidak aktif. Hubungi Pengurus.');
      }

      await _db.from('attendance').insert({
        'activity_id': widget.activity['id'],
        'member_id': member['id'],
        'status': 'hadir',
        'notes': 'Check-in QR oleh petugas',
        'marked_by': _db.auth.currentUser!.id,
      });

      if (!mounted) return;
      setState(() {
        _finished = true;
        _status = 'Check-in berhasil untuk ${member['display_name']}.';
      });
    } catch (error) {
      if (!mounted) return;
      final detail = error.toString();
      final duplicate = detail.contains('duplicate key') ||
          detail.contains('23505');
      setState(() {
        _finished = true;
        _status = duplicate
            ? 'Anggota ini sudah tercatat hadir untuk kegiatan ini.'
            : detail.replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _scanNext() {
    setState(() {
      _finished = false;
      _status = 'Arahkan kamera ke QR pada kartu digital anggota berikutnya.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Anggota',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5EF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.activity['title'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(_status,
                    style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFF345B4D))),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: _finished
                    ? Container(
                        width: double.infinity,
                        color: const Color(0xFFF2F6F3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 58, color: Color(0xFF167D68)),
                            const SizedBox(height: 12),
                            const Text('Pemindaian selesai',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17)),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: _scanNext,
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              label: const Text('Scan anggota berikutnya'),
                            ),
                          ],
                        ),
                      )
                    : MobileScanner(
                        onDetect: (capture) {
                          if (capture.barcodes.isEmpty) return;
                          _handleScan(capture.barcodes.first.rawValue);
                        },
                      ),
              ),
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrCheckinScreen extends StatefulWidget {
  const QrCheckinScreen({super.key, required this.role});
  final String role;
  @override
  State<QrCheckinScreen> createState() => _QrCheckinScreenState();
}

class _QrCheckinScreenState extends State<QrCheckinScreen> {
  final _db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;
  bool _busy = false;
  String? _lastScan;
  bool get _admin => widget.role == 'pengurus' || widget.role == 'pembina';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    if (!_admin) return [];
    final activities = await _db.from('activities').select('id,title,starts_at,ends_at').order('starts_at', ascending: false);
    final codes = await _db.from('activity_checkin_codes').select('activity_id,token,enabled,expires_at');
    final byActivity = {for (final code in codes) code['activity_id'].toString(): code};
    return List<Map<String, dynamic>>.from(activities).map((activity) => {
      ...activity,
      'checkin': byActivity[activity['id'].toString()],
    }).toList();
  }

  void _refresh() => setState(() => _future = _load());

  String _date(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return 'Waktu belum ditentukan';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _newToken() {
    final random = Random.secure();
    return List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  String _payload(Map<String, dynamic> activity, String token) => 'MS99CHECKIN|${activity['id']}|$token';

  Future<void> _showQr(Map<String, dynamic> activity, String token) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('QR Check-in Kegiatan'),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(activity['title'].toString(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(_date(activity['starts_at']), style: const TextStyle(fontSize: 11, color: Color(0xFF718078))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: QrImageView(data: _payload(activity, token), version: QrVersions.auto, size: 230),
            ),
            const SizedBox(height: 12),
            const Text('Minta anggota memindai QR ini dari menu Check-in Kegiatan. Jangan bagikan QR di luar peserta kegiatan.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11, height: 1.45, color: Color(0xFF718078))),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Tutup'))],
      ),
    );
  }

  Future<void> _createOrRotate(Map<String, dynamic> activity) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final token = _newToken();
      final end = DateTime.tryParse(activity['ends_at']?.toString() ?? '') ??
          DateTime.tryParse(activity['starts_at']?.toString() ?? '')?.add(const Duration(hours: 4)) ??
          DateTime.now().add(const Duration(hours: 8));
      await _db.from('activity_checkin_codes').upsert({
        'activity_id': activity['id'],
        'token': token,
        'enabled': true,
        'expires_at': end.add(const Duration(hours: 4)).toUtc().toIso8601String(),
        'created_by': _db.auth.currentUser!.id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'activity_id');
      if (!mounted) return;
      _refresh();
      await _showQr(activity, token);
    } catch (error) {
      _message('QR gagal dibuat: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable(Map<String, dynamic> activity) async {
    try {
      await _db.from('activity_checkin_codes').update({
        'enabled': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('activity_id', activity['id']);
      _refresh();
      _message('QR check-in dinonaktifkan.');
    } catch (error) {
      _message('QR gagal dinonaktifkan: $error');
    }
  }

  Future<void> _checkIn(String raw) async {
    if (_busy || raw == _lastScan) return;
    _lastScan = raw;
    final parts = raw.split('|');
    if (parts.length != 3 || parts[0] != 'MS99CHECKIN') {
      _message('QR bukan kode check-in Marawis SMPN 99.');
      return;
    }
    final activityId = int.tryParse(parts[1]);
    if (activityId == null) {
      _message('Kode kegiatan tidak valid.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _db.rpc('marawis_check_in', params: {
        'p_activity_id': activityId,
        'p_token': parts[2],
      });
      final data = Map<String, dynamic>.from(result as Map);
      _message(data['message']?.toString() ?? 'Check-in selesai.');
    } catch (error) {
      _message('Check-in gagal: $error');
      _lastScan = null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    if (!_admin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Check-in Kegiatan', style: TextStyle(fontWeight: FontWeight.w800))),
        body: Column(children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: const Color(0xFFEAF5EF), borderRadius: BorderRadius.circular(16)),
            child: const Text('Arahkan kamera ke QR resmi yang ditampilkan Pengurus atau Pembina. Check-in hanya dapat dilakukan dalam waktu kegiatan yang ditentukan.',
              style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF345B4D))),
          ),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: MobileScanner(onDetect: (capture) {
                if (capture.barcodes.isEmpty) return;
                final value = capture.barcodes.first.rawValue;
                if (value != null) _checkIn(value);
              }),
            ),
          )),
          if (_busy) const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
        ]),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola QR Check-in', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: TextButton(onPressed: _refresh, child: const Text('Gagal memuat kegiatan. Coba lagi.')));
          final activities = snapshot.data ?? [];
          if (activities.isEmpty) return const Center(child: Text('Belum ada kegiatan. Buat jadwal terlebih dahulu.'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final activity = activities[index];
              final code = activity['checkin'] as Map<String, dynamic>?;
              final enabled = code?['enabled'] == true;
              final token = code?['token']?.toString();
              return Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5ECE8))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(activity['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 5),
                  Text(_date(activity['starts_at']), style: const TextStyle(color: Color(0xFF718078), fontSize: 11)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: Text(enabled ? 'QR aktif' : 'QR belum aktif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: enabled ? const Color(0xFF167D68) : const Color(0xFF9A6B22)))),
                    if (enabled && token != null) TextButton.icon(onPressed: () => _showQr(activity, token), icon: const Icon(Icons.qr_code_2_rounded), label: const Text('Lihat QR')),
                  ]),
                  Wrap(spacing: 8, children: [
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : () => _createOrRotate(activity),
                      icon: const Icon(Icons.qr_code_rounded, size: 18),
                      label: Text(enabled ? 'Perbarui QR' : 'Buat QR'),
                    ),
                    if (enabled) OutlinedButton.icon(
                      onPressed: () => _disable(activity),
                      icon: const Icon(Icons.block_rounded, size: 18),
                      label: const Text('Nonaktifkan'),
                    ),
                  ]),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

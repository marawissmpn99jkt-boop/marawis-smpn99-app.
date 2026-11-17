import 'formatters.dart';

Map<String, dynamic> buildCashPaymentStatusNotification({
  required String memberId,
  required int paymentId,
  required num amount,
  required String paymentPeriod,
  required String status,
}) {
  final statusLabel = switch (status) {
    'diterima' => 'diterima',
    'ditolak' => 'ditolak',
    _ => throw ArgumentError.value(status, 'status', 'Status verifikasi tidak valid.'),
  };

  return {
    'user_id': memberId,
    'title': statusLabel == 'diterima'
        ? 'Pembayaran kas diterima'
        : 'Pembayaran kas ditolak',
    'body': 'Pembayaran ${formatRupiah(amount)} untuk periode $paymentPeriod $statusLabel.',
    'related_type': 'cash_payment',
    'related_id': paymentId,
  };
}

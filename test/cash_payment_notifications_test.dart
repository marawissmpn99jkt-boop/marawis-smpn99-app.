import 'package:flutter_test/flutter_test.dart';
import 'package:marawis_smpn99/cash_payment_notifications.dart';

void main() {
  group('buildCashPaymentStatusNotification', () {
    test('creates an accepted payment notification', () {
      final row = buildCashPaymentStatusNotification(
        memberId: 'member-a',
        paymentId: 24,
        amount: 50000,
        paymentPeriod: 'November 2026',
        status: 'diterima',
      );

      expect(row['user_id'], 'member-a');
      expect(row['title'], 'Pembayaran kas diterima');
      expect(row['body'], 'Pembayaran Rp 50.000 untuk periode November 2026 diterima.');
      expect(row['related_type'], 'cash_payment');
      expect(row['related_id'], 24);
    });

    test('creates a rejected payment notification', () {
      final row = buildCashPaymentStatusNotification(
        memberId: 'member-a',
        paymentId: 24,
        amount: 50000,
        paymentPeriod: 'November 2026',
        status: 'ditolak',
      );

      expect(row['title'], 'Pembayaran kas ditolak');
      expect(row['body'], 'Pembayaran Rp 50.000 untuk periode November 2026 ditolak.');
    });

    test('rejects unsupported verification statuses', () {
      expect(
        () => buildCashPaymentStatusNotification(
          memberId: 'member-a',
          paymentId: 24,
          amount: 50000,
          paymentPeriod: 'November 2026',
          status: 'menunggu',
        ),
        throwsArgumentError,
      );
    });
  });
}

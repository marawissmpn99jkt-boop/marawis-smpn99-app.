import 'package:flutter_test/flutter_test.dart';
import 'package:marawis_smpn99/cash_payment_rules.dart';

void main() {
  group('cash payment proof rules', () {
    test('requires proof for transfer payments', () {
      expect(cashPaymentProofIsRequired('transfer'), isTrue);
      expect(
        cashPaymentCanBeSubmitted(method: 'transfer', proofPath: null),
        isFalse,
      );
      expect(
        cashPaymentCanBeSubmitted(
          method: 'transfer',
          proofPath: 'user-id/proof.jpg',
        ),
        isTrue,
      );
    });

    test('does not require proof for cash or other methods', () {
      expect(cashPaymentProofIsRequired('tunai'), isFalse);
      expect(
        cashPaymentCanBeSubmitted(method: 'tunai', proofPath: null),
        isTrue,
      );
      expect(
        cashPaymentCanBeSubmitted(method: 'lainnya', proofPath: null),
        isTrue,
      );
    });

    test('rejects unsupported methods and empty paths', () {
      expect(
        cashPaymentCanBeSubmitted(method: 'crypto', proofPath: null),
        isFalse,
      );
      expect(
        cashPaymentCanBeSubmitted(method: 'transfer', proofPath: '  '),
        isFalse,
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:marawis_smpn99/formatters.dart';

void main() {
  group('formatRupiah', () {
    test('formats zero and null values', () {
      expect(formatRupiah(0), 'Rp 0');
      expect(formatRupiah(null), 'Rp 0');
    });

    test('groups thousands using Indonesian separators', () {
      expect(formatRupiah(1250000), 'Rp 1.250.000');
      expect(formatRupiah(999), 'Rp 999');
    });

    test('preserves a negative sign', () {
      expect(formatRupiah(-2500), 'Rp -2.500');
    });
  });
}

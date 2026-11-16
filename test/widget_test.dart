import 'package:flutter_test/flutter_test.dart';
import 'package:marawis_smpn99/formatters.dart';
import 'package:marawis_smpn99/auth_roles.dart';

void main() {
  group('requiredStaffVerificationRole', () {
    test('member login does not require staff verification for a member', () {
      expect(
        requiredStaffVerificationRole(profileRole: 'anggota'),
        isNull,
      );
    });

    test('staff choice requires verification for a member account', () {
      expect(
        requiredStaffVerificationRole(
          profileRole: 'anggota',
          pendingRole: 'pengurus',
        ),
        'pengurus',
      );
    });

    test('an existing staff account cannot bypass verification via member login', () {
      expect(
        requiredStaffVerificationRole(profileRole: 'pengurus'),
        'pengurus',
      );
      expect(
        requiredStaffVerificationRole(profileRole: 'pembina'),
        'pembina',
      );
    });

    test('selected staff role is verified when changing staff role', () {
      expect(
        requiredStaffVerificationRole(
          profileRole: 'pembina',
          pendingRole: 'pengurus',
        ),
        'pengurus',
      );
    });
  });

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

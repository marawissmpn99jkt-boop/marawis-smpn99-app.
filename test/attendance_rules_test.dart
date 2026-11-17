import 'package:flutter_test/flutter_test.dart';
import 'package:marawis_smpn99/attendance_rules.dart';

void main() {
  group('hasCompleteAttendance', () {
    test('accepts an explicit valid status for every member', () {
      expect(
        hasCompleteAttendance(
          ['member-a', 'member-b'],
          {'member-a': 'hadir', 'member-b': 'sakit'},
        ),
        isTrue,
      );
    });

    test('rejects a member whose status has not been selected', () {
      expect(
        hasCompleteAttendance(
          ['member-a', 'member-b'],
          {'member-a': 'hadir'},
        ),
        isFalse,
      );
    });

    test('rejects a status outside the database constraint', () {
      expect(
        hasCompleteAttendance(
          ['member-a'],
          {'member-a': 'belum'},
        ),
        isFalse,
      );
    });
  });
}

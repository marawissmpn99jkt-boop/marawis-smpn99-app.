import 'package:flutter_test/flutter_test.dart';
import 'package:marawis_smpn99/haunted_night.dart';

void main() {
  group('Marawis Haunted Night schedule', () {
    test('is active from November 23, 2026', () {
      expect(isHauntedNightActive(DateTime(2026, 11, 23)), isTrue);
    });

    test('remains active through November 30, 2026', () {
      expect(isHauntedNightActive(DateTime(2026, 11, 30, 23, 59)), isTrue);
    });

    test('returns to the normal theme on December 1, 2026', () {
      expect(isHauntedNightActive(DateTime(2026, 12, 1)), isFalse);
    });

    test('is inactive before the event starts', () {
      expect(isHauntedNightActive(DateTime(2026, 11, 22, 23, 59)), isFalse);
    });
  });
}

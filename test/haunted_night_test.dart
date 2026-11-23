import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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

  testWidgets('cinematic event landing shows its hero and interactive entry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HauntedNightLanding(onLogin: () {})),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('MARAWIS HAUNTED NIGHT 2026'), findsOneWidget);
    expect(find.text('Mystery Pumpkin'), findsOneWidget);
  });
}

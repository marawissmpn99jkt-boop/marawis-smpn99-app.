import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:marawis_smpn99/haunted_night.dart';
import 'package:marawis_smpn99/haunted_event_hub.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Marawis Rainy Season schedule', () {
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
    expect(find.text('THE RAIN HAS A RHYTHM'), findsOneWidget);
    expect(find.text('Rainy Season Challenge'), findsOneWidget);
  });

  testWidgets('Rainy Season arcade lists all four game modes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(home: HauntedEventHub(playerName: 'Tester')),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Rain Drop Hunt'), findsOneWidget);
    expect(find.text('Rainy Rhythm Quiz'), findsOneWidget);
    expect(find.text('Memory Maze'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Secret Word'), 180);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Secret Word'), findsOneWidget);
  });

  testWidgets('Rainy Season exposes daily, badges, ranking and secret event tabs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(home: HauntedEventHub(playerName: 'Tester')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('DAILY'), findsOneWidget);
    expect(find.text('BADGES'), findsOneWidget);
    expect(find.text('RANK'), findsOneWidget);
    expect(find.text('SECRET'), findsOneWidget);
    await tester.tap(find.text('DAILY'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('One Game a Day'), findsOneWidget);
    await tester.tap(find.text('SECRET'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('After the Rain'), findsOneWidget);
  });

}
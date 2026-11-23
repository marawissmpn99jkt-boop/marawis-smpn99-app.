import 'package:flutter_test/flutter_test.dart';
import 'package:marawis_smpn99/multiplayer_guess_rules.dart';

void main() {
  group('Draw & Guess rules', () {
    test('matches answers regardless of case and whitespace', () {
      expect(drawGuessMatches('  MaRa wis\n', 'MARAWIS'), isTrue);
      expect(drawGuessMatches('Darbuka\t', ' DARBUKA '), isTrue);
    });

    test('does not match a different answer', () {
      expect(drawGuessMatches('MARAWIS', 'REBANA'), isFalse);
    });

    test('includes the active round in manual acceptance events', () {
      expect(
        acceptedDrawGuessPayload(targetId: 'player-2', round: 3),
        {'accepted': true, 'target': 'player-2', 'round': 3},
      );
    });
  });
}

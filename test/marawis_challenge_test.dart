import 'package:flutter_test/flutter_test.dart';
import 'package:marawis_smpn99/marawis_challenge.dart';

void main() {
  group('Marawis random challenge', () {
    test('selects five unique questions with valid answer options', () {
      final questions = createRandomMarawisChallenge(seed: 20261121);

      expect(questions, hasLength(5));
      expect(questions.map((question) => question['q']).toSet(), hasLength(5));

      for (final question in questions) {
        final answers = question['a'] as List<String>;
        final correctIndex = question['c'] as int;

        expect(answers, hasLength(4));
        expect(correctIndex, inInclusiveRange(0, answers.length - 1));
      }
    });

    test('returns the same question order for the same seed', () {
      final first = createRandomMarawisChallenge(seed: 99);
      final second = createRandomMarawisChallenge(seed: 99);

      expect(first, equals(second));
    });

    test('different seeds can produce different question orders', () {
      final first = createRandomMarawisChallenge(seed: 123);
      final second = createRandomMarawisChallenge(seed: 456);

      expect(
        first.map((question) => question['q']).toList(),
        isNot(equals(second.map((question) => question['q']).toList())),
      );
    });

    test('keeps a member challenge seed stable for the same week', () {
      final first = marawisChallengeSeed('member-1', 'weekly-challenge-2026-47');
      final second = marawisChallengeSeed('member-1', 'weekly-challenge-2026-47');
      final nextMember = marawisChallengeSeed('member-2', 'weekly-challenge-2026-47');
      final nextWeek = marawisChallengeSeed('member-1', 'weekly-challenge-2026-48');

      expect(first, second);
      expect(first, isNot(nextMember));
      expect(first, isNot(nextWeek));
    });

    test('rejects question counts outside the question bank', () {
      expect(
        () => createRandomMarawisChallenge(seed: 1, questionCount: 0),
        throwsArgumentError,
      );
      expect(
        () => createRandomMarawisChallenge(seed: 1, questionCount: 99),
        throwsArgumentError,
      );
    });
  });
}

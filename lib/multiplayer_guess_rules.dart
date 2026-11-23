String normalizeDrawGuess(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

bool drawGuessMatches(String guess, String answer) =>
    normalizeDrawGuess(guess) == normalizeDrawGuess(answer);

Map<String, dynamic> acceptedDrawGuessPayload({
  required String targetId,
  required int round,
}) => {
      'accepted': true,
      'target': targetId,
      'round': round,
    };

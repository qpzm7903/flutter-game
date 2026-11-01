import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_game/game/game_record.dart';
import 'package:flutter_game/game/match.dart';

void main() {
  test('history record preserves time, role, result, score and difficulty', () {
    final original = GameRecord(time: DateTime.utc(2026, 11, 1, 12, 30),
      landlord: true, won: false, score: -12, difficulty: Difficulty.easy);
    final restored = GameRecord.decode(original.encode());
    expect(restored.time, original.time);
    expect(restored.landlord, isTrue);
    expect(restored.won, isFalse);
    expect(restored.score, -12);
    expect(restored.difficulty, Difficulty.easy);
    expect(() => GameRecord.decode('bad json'), throwsFormatException);
  });
  test('easy strategy completes seeded games with legal moves', () {
    for (int seed = 0; seed < 25; seed++) {
      final match = Match(random: Random(seed), difficulty: Difficulty.easy);
      int steps = 0;
      while (match.phase != Phase.finished && steps++ < 500) { match.computerStep(); }
      expect(match.phase, Phase.finished, reason: 'seed $seed');
      expect(match.scores.reduce((a,b) => a+b), 0);
    }
  });
}

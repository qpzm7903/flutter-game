import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_game/game/practice.dart';
import 'package:flutter_game/game/match.dart';
import 'package:flutter_game/game/cards.dart';
import 'package:flutter_game/services/player_profile.dart';

void bots(Match match) {
  int steps = 0;
  while (match.phase == Phase.playing && match.turn != 0 && steps++ < 10) { match.computerStep(); }
}
void main() {
  test('every practice starts with unique cards and a fresh independent position', () {
    for (final puzzle in practicePuzzles) {
      final match = puzzle.create();
      final cards = [...match.hands.expand((h) => h), ...match.table];
      expect(cards.toSet().length, cards.length);
      expect(match.phase, Phase.playing); expect(match.turn, 0);
      final fresh = puzzle.create();
      match.hands[0].clear();
      expect(fresh.hands[0], isNotEmpty);
    }
    expect(() => Match.position(hands: [[const PlayingCard(0)], [const PlayingCard(0)], [const PlayingCard(1)]]), throwsArgumentError);
  });
  test('straight puzzle wins as a straight and loses after a small single', () {
    final puzzle = practicePuzzles[0];
    final match = puzzle.create();
    expect(match.play(0, [...match.hands[0]]), isNull);
    expect(match.humanWon, isTrue);
    final wrong = puzzle.create();
    wrong.play(0, [wrong.hands[0].last]); bots(wrong);
    expect(wrong.phase, Phase.finished); expect(wrong.humanWon, isFalse);
  });
  test('bomb must take the lead before disposing of the small card', () {
    final match = practicePuzzles[1].create();
    expect(match.play(0, match.hands[0].where((c) => c.rank == 9).toList()), isNull);
    bots(match);
    expect(match.turn, 0); expect(match.target, isNull);
    expect(match.play(0, [...match.hands[0]]), isNull); expect(match.humanWon, isTrue);
    final wrong = practicePuzzles[1].create();
    wrong.pass(0); bots(wrong);
    expect(wrong.phase, Phase.finished); expect(wrong.humanWon, isFalse);
  });
  test('cooperating with teammate wins and overtaking the teammate loses', () {
    final match = practicePuzzles[2].create();
    expect(match.suggest(0, cooperate: true), isEmpty);
    match.pass(0); bots(match);
    expect(match.humanWon, isTrue); expect(match.winner, 2);
    final wrong = practicePuzzles[2].create();
    wrong.play(0, [wrong.hands[0].first]); bots(wrong);
    wrong.play(0, [wrong.hands[0].last]); bots(wrong);
    expect(wrong.phase, Phase.finished); expect(wrong.humanWon, isFalse);
  });
  test('completion persists without adding ordinary games, scores or history', () async {
    SharedPreferences.setMockInitialValues({});
    final profile = await PlayerProfile.load();
    await profile.completePuzzle('straight'); await profile.completePuzzle('straight');
    final restored = await PlayerProfile.load();
    expect(restored.completedPuzzles, {'straight'});
    expect(restored.games, 0); expect(restored.totalScore, 0); expect(restored.history, isEmpty);
  });
}

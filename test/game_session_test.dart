import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_game/game_session.dart';
import 'package:flutter_game/game/match.dart';
import 'package:flutter_game/game/practice.dart';
import 'package:flutter_game/services/player_profile.dart';
import 'package:flutter_game/services/app_log.dart';

void finishNormal(GameSession session) {
  final match = session.match;
  match.bid(0, 3);
  match.hands[0] = [match.hands[0].first];
  expect(match.play(0, [...match.hands[0]]), isNull);
}
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('unfinished games are not counted and repeated settlement is idempotent', () async {
    final profile = await PlayerProfile.load();
    final session = GameSession(profile);
    await session.settle(); expect(profile.games, 0);
    finishNormal(session);
    await Future.wait([session.settle(), session.settle()]);
    expect(profile.games, 1); expect(profile.history.length, 1);
    final score = profile.totalScore;
    session.restart(); finishNormal(session); await session.settle();
    expect(profile.games, 2); expect(profile.totalScore, score * 2);
  });
  test('retry preserves practice and normal mode adopts pending difficulty', () async {
    final profile = await PlayerProfile.load();
    final session = GameSession(profile);
    session.startPractice(practicePuzzles.first);
    final previous = session.generation;
    final old = session.match;
    session.match.play(0, [...session.match.hands[0]]);
    await session.settle(); await session.settle();
    expect(profile.completedPuzzles, {'straight'}); expect(profile.games, 0);
    session.restart();
    expect(session.generation, previous + 1); expect(identical(session.match, old), isFalse);
    expect(session.puzzle, practicePuzzles.first); expect(session.match.hands[0].length, 5);
    await profile.setDifficulty(Difficulty.easy);
    expect(session.match.difficulty, Difficulty.standard);
    session.startNormal();
    expect(session.puzzle, isNull); expect(session.match.phase, Phase.bidding);
    expect(session.match.difficulty, Difficulty.easy); expect(profile.games, 0);
  });
  test('failed practice cannot contaminate ordinary settlement or progress', () async {
    final profile = await PlayerProfile.load();
    final session = GameSession(profile)..startPractice(practicePuzzles.first);
    session.match.play(0, [session.match.hands[0].last]); session.match.computerStep();
    await session.settle();
    expect(profile.completedPuzzles, isEmpty); expect(profile.history, isEmpty);
    session.startNormal(); finishNormal(session); await session.settle();
    session.startPractice(practicePuzzles[2]); await session.settle();
    expect(profile.games, 1); expect(profile.history.length, 1);
    expect(AppLog.text, contains('mode=team'));
    expect(AppLog.text, contains('generation='));
  });
}
